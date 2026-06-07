extends Node

signal placements_loaded(placements: Array)
signal deco_placed(placement: DecoPlacement)
signal deco_recalled(placement_id: String)
signal batch_saved
signal batch_save_failed
signal edit_mode_changed(is_edit: bool)
signal scene_deco_ready(enabled: bool)
signal sync_state_changed(is_busy: bool)

var edit_mode: bool = false
var current_scene_name: String = ""

var _placements: Array = []
var _pending_sync: bool = false
var _service  # MockDecoService or RealDecoService

var _http_get:        HTTPRequest
var _http_place:      HTTPRequest
var _http_batch_move: HTTPRequest
var _http_recall:     HTTPRequest

func _ready() -> void:
	_http_get        = _make_http("HttpGet")
	_http_place      = _make_http("HttpPlace")
	_http_batch_move = _make_http("HttpBatchMove")
	_http_recall     = _make_http("HttpRecall")

	if UserManager.use_mock:
		_service = MockDecoService.new()
	else:
		_service = RealDecoService.new(_http_get, _http_place, _http_batch_move, _http_recall)

func set_edit_mode(value: bool) -> void:
	edit_mode = value
	edit_mode_changed.emit(value)

func exit_scene() -> void:
	current_scene_name = ""
	if edit_mode:
		set_edit_mode(false)
	_placements.clear()
	scene_deco_ready.emit(false)

func init_scene(scene_name: String) -> void:
	current_scene_name = scene_name
	if edit_mode:
		set_edit_mode(false)
	await get_tree().process_frame

	var placements: Array
	if UserManager.use_mock:
		placements = await _service.get_placements_async(scene_name)
	else:
		placements = await _service.get_placements_async(
			UserManager.base_url, UserManager.get_access_token(), scene_name)

	_placements = placements
	placements_loaded.emit(_placements)
	scene_deco_ready.emit(true)

func place_deco_async(inventory_item_id: String, x: float, y: float) -> void:
	if _pending_sync:
		return
	_set_pending(true)

	var inv_item: InventoryItem = InventoryManager.get_inventory().find_by_id(inventory_item_id)
	var original_qty: int = inv_item.quantity if inv_item != null else 0

	# 1. Local predict — decrement inventory immediately
	if inv_item != null:
		InventoryManager.consume_item(inv_item.decor_slug)

	var temp := DecoPlacement.new()
	temp.id               = "temp_%d" % Time.get_ticks_msec()
	temp.inventory_item_id = inventory_item_id
	temp.decor_slug       = inv_item.decor_slug if inv_item != null else ""
	temp.scene_name       = current_scene_name
	temp.position_x       = x
	temp.position_y       = y
	_placements.append(temp)
	deco_placed.emit(temp)

	# 2. Async sync
	var confirmed: DecoPlacement
	if UserManager.use_mock:
		confirmed = await _service.place_deco_async(inventory_item_id, current_scene_name, x, y)
	else:
		confirmed = await _service.place_deco_async(
			UserManager.base_url, UserManager.get_access_token(),
			inventory_item_id, current_scene_name, x, y)

	_set_pending(false)

	if confirmed == null or confirmed.id.is_empty():
		# 3. Rollback
		_placements.erase(temp)
		deco_recalled.emit(temp.id)
		if inv_item != null:
			InventoryManager.restore_item(inventory_item_id, original_qty)
		push_warning("DecoManager.place_deco_async: server rejected placement, rolled back")
		return

	var idx := _placements.find(temp)
	if idx >= 0:
		_placements[idx] = confirmed
	deco_placed.emit(confirmed)

func recall_deco_async(placement_id: String) -> void:
	if _pending_sync:
		return
	_set_pending(true)

	var snapshot: DecoPlacement = _find_placement(placement_id)
	_remove_placement(placement_id)
	deco_recalled.emit(placement_id)

	var ok: bool
	if UserManager.use_mock:
		ok = await _service.recall_deco_async(placement_id)
	else:
		ok = await _service.recall_deco_async(
			UserManager.base_url, UserManager.get_access_token(), placement_id)

	_set_pending(false)

	if not ok:
		if snapshot != null:
			_placements.append(snapshot)
			deco_placed.emit(snapshot)
		push_warning("DecoManager.recall_deco_async: server rejected recall, rolled back")
		return

	# BE confirmed recall → inventory quantity restored on server, sync locally
	if snapshot != null and not snapshot.inventory_item_id.is_empty():
		InventoryManager.increment_item(snapshot.inventory_item_id)

func batch_move_async(moves: Array) -> void:
	if _pending_sync:
		return
	_set_pending(true)

	var snapshot: Dictionary = {}
	for p: Variant in _placements:
		var dp := p as DecoPlacement
		snapshot[dp.id] = Vector2(dp.position_x, dp.position_y)

	for m: Variant in moves:
		var entry := m as Dictionary
		var placement := _find_placement(str(entry.get("id", "")))
		if placement != null:
			placement.position_x = float(entry.get("x", placement.position_x))
			placement.position_y = float(entry.get("y", placement.position_y))

	var ok: bool
	if UserManager.use_mock:
		ok = await _service.batch_move_async(moves)
	else:
		ok = await _service.batch_move_async(
			UserManager.base_url, UserManager.get_access_token(), moves)

	_set_pending(false)

	if ok:
		batch_saved.emit()
	else:
		for p: Variant in _placements:
			var dp := p as DecoPlacement
			if snapshot.has(dp.id):
				var orig: Vector2 = snapshot[dp.id]
				dp.position_x = orig.x
				dp.position_y = orig.y
		batch_save_failed.emit()
		push_warning("DecoManager.batch_move_async: server rejected batch move, positions restored")

func batch_move_current_async() -> void:
	var moves: Array = []
	for p: Variant in _placements:
		var dp := p as DecoPlacement
		if not dp.id.begins_with("temp_"):
			moves.append({"id": dp.id, "x": dp.position_x, "y": dp.position_y})
	await batch_move_async(moves)

func _find_placement(placement_id: String) -> DecoPlacement:
	for p: Variant in _placements:
		var dp := p as DecoPlacement
		if dp.id == placement_id:
			return dp
	return null

func _remove_placement(placement_id: String) -> void:
	for i in range(_placements.size() - 1, -1, -1):
		var dp := _placements[i] as DecoPlacement
		if dp.id == placement_id:
			_placements.remove_at(i)
			return

func _set_pending(value: bool) -> void:
	_pending_sync = value
	sync_state_changed.emit(value)

func _make_http(node_name: String) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.name = node_name
	add_child(http)
	return http
