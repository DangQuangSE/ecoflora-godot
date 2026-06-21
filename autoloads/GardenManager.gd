extends Node

signal plots_updated(plots: Array[Plot])
signal plant_failed(plot_id: String, reason: String)
signal harvest_completed(plot_id: String, product_id: String)
signal care_completed(plot_id: String, action_type: int)
signal plant_xp_gained(plot_id: String, xp_amount: int, synergy_bonus: int)
signal icons_registered

@export var use_mock: bool = false
@export var focus_fail_xp_penalty: int = 20

const GARDEN_ID := "main_garden"

var _plots: Array[Plot] = []
var _templates: Dictionary = {}
var _item_cache: Dictionary = {}
var _synergy_cache: Dictionary = {}

var _http_catalog: HTTPRequest
var _http_garden: HTTPRequest
var _http_plant: HTTPRequest
var _http_harvest: HTTPRequest
var _http_dig_up: HTTPRequest
var _garden_in_flight: bool = false
var _plant_in_flight: bool = false
var _harvest_in_flight: bool = false
var _dig_up_in_flight: bool = false
var _ref_svc  # ReferenceDataService instance (preloaded to avoid autoload parse-order issue)

const _RefDataScript = preload("res://services/ReferenceDataService.gd")

const PLOT_POSITIONS: Array[Vector2] = [
	Vector2(80, 80),   Vector2(200, 80),
	Vector2(80, 200),  Vector2(200, 200),
	Vector2(80, 320),  Vector2(200, 320),
	Vector2(80, 440),  Vector2(200, 440),
	Vector2(360, 80),  Vector2(480, 80),
	Vector2(360, 200), Vector2(480, 200),
	Vector2(360, 320), Vector2(480, 320),
	Vector2(360, 440), Vector2(480, 440),
]

func _ready() -> void:
	_ref_svc = _RefDataScript.new()

	# Always load mock data first so _templates is never empty
	var garden_svc := MockGardenService.new()
	_plots = garden_svc.get_initial_plots(GARDEN_ID)
	for t: FlowerTemplate in garden_svc.get_flower_templates():
		_templates[t.id] = t
	if use_mock:
		_seed_mock_synergies()

	InteractionManager.plot_action_requested.connect(_on_plot_action)
	FocusManager.session_reward_received.connect(_on_focus_reward_received)

	if not use_mock:
		_http_catalog = HTTPRequest.new()
		_http_catalog.timeout = 10.0
		add_child(_http_catalog)
		_http_garden = HTTPRequest.new()
		_http_garden.timeout = 10.0
		add_child(_http_garden)
		_http_plant = HTTPRequest.new()
		_http_plant.timeout = 15.0
		add_child(_http_plant)
		_http_harvest = HTTPRequest.new()
		_http_harvest.timeout = 15.0
		add_child(_http_harvest)
		_http_dig_up = HTTPRequest.new()
		_http_dig_up.timeout = 15.0
		add_child(_http_dig_up)
		# Fetch catalogs + garden after login  -  never before
		UserManager.login_succeeded.connect(_on_login_succeeded)

func _on_login_succeeded() -> void:
	await _fetch_catalogs()
	await _fetch_garden()

func _fetch_catalogs() -> void:
	var base: String = UserManager.base_url
	var auth: String = UserManager.get_auth_header()

	# Flower templates
	var templates_ok := await _fetch_one(
		base + "/api/flowertemplates?isDeleted=false&pageSize=1000", auth)
	if templates_ok.size() > 0:
		var parsed: Dictionary = _ref_svc.parse_flower_templates(templates_ok)
		if not parsed.is_empty():
			_templates = parsed
	# Items catalog

	var items_ok := await _fetch_one(
		base + "/api/items?isDeleted=false&pageSize=1000", auth)
	if items_ok.size() > 0:
		_item_cache = _ref_svc.parse_items(items_ok)

	# Synergies
	var synergies_ok := await _fetch_one(
		base + "/api/synergies?pageSize=1000", auth)
	if synergies_ok.size() > 0:
		_synergy_cache = _ref_svc.parse_synergies(synergies_ok)
	elif not use_mock:
		push_warning(
			"GardenManager: synergy catalog empty — zone bonus disabled. "
			+ "Seed Synergies on BE (Admin API) or assign SynergyId to FlowerTemplates."
		)

	_register_be_icons()
	icons_registered.emit()

# Returns the parsed data Array on success, empty Array on failure (never throws).
func _fetch_one(url: String, auth_header: String) -> Array:
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if not auth_header.is_empty():
		headers.append(auth_header)
	var error: int = _http_catalog.request(url, headers)
	if error != OK:
		push_warning("GardenManager._fetch_one: request error %d for %s" % [error, url])
		return []
	var raw: Variant = await _http_catalog.request_completed
	var http_result: int = raw[0]
	var status_code: int  = raw[1]
	var body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
		if status_code == 401:
			UserManager.handle_401()
		push_warning("GardenManager._fetch_one: HTTP %d for %s" % [status_code, url])
		return []
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("GardenManager._fetch_one: JSON parse error for %s" % url)
		return []
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return []
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if data == null or not data is Array:
		push_warning("GardenManager._fetch_one: data is not an Array for %s" % url)
		return []
	return data

# Maps BE flower name to the local asset folder name.
# Keys = BE template name (lowercase), values = asset folder name.
# Names match directly since BE names were set to match asset folders.
const _FLOWER_NAME_TO_ASSET: Dictionary = {
	# Base flowers
	"anthurium":           "anthurium",
	"lotus":               "lotus",
	"periwinkle":          "periwinkle",
	"purple_bellflower":   "purple_bellflower",
	"rose":                "rose",
	"sun_flower":          "sun_flower",
	"tulip":               "tulip",
	# Variant flowers  -  reuse base asset folder
	"golden_rose":         "rose",
	"blue_lotus":          "lotus",
	"rainbow_tulip":       "tulip",
	"midnight_periwinkle": "periwinkle",
	"crimson_anthurium":   "anthurium",
	"sunset_sunflower":    "sun_flower",
	"violet_bellflower":   "purple_bellflower",
	"moonlit_rose":        "rose",
	"crystal_lotus":       "lotus",
	"fire_tulip":          "tulip",
	"silver_anthurium":    "anthurium",
	"jade_periwinkle":     "periwinkle",
	"star_sunflower":      "sun_flower",
}

func _register_be_icons() -> void:
	# Register flower template icons and plant textures by UUID
	for tid: String in _templates:
		var t: FlowerTemplate = _templates[tid]
		var name_lower: String = t.name.to_lower()
		var asset_name: String = _FLOWER_NAME_TO_ASSET.get(name_lower, "")
		if asset_name.is_empty():
			continue
		ItemIconRegistry.register_plant_name(tid, asset_name)
		for ext: String in ["png", "PNG"]:
			var icon_path := "res://assets/flowers/%s/%s 3.%s" % [asset_name, asset_name, ext]
			if ResourceLoader.exists(icon_path):
				ItemIconRegistry.register(tid, load(icon_path))
				break

	# Register item icons by UUID.
	# First try image_url as a static-key alias (e.g. watering_can already pre-registered).
	# Fall back to name-contains matching for items whose imageUrl is not set.
	# sickle.png is the harvest UI button - NOT an item icon.
	for iid: String in _item_cache:
		var item: Dictionary = _item_cache[iid]
		var image_url: String = str(item.get("image_url", ""))
		if not image_url.is_empty() and ItemIconRegistry.has_icon(image_url):
			ItemIconRegistry.register(iid, ItemIconRegistry.get_icon(image_url))
			continue
		var raw_name: String = str(item.get("name", "")).to_lower()
		var icon_path: String
		if "watering can" in raw_name:
			icon_path = "res://assets/icon/watering_can.png"
		elif "fertilizer" in raw_name:
			icon_path = "res://assets/icon/fertilizer.png"
		elif "pesticide" in raw_name:
			icon_path = "res://assets/icon/pesticide.png"
		else:
			continue
		if ResourceLoader.exists(icon_path):
			ItemIconRegistry.register(iid, load(icon_path))

func _fetch_garden() -> void:
	if _garden_in_flight:
		return
	_garden_in_flight = true
	var url: String = UserManager.base_url + "/api/garden"
	var auth_header: String = UserManager.get_auth_header()
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if not auth_header.is_empty():
		headers.append(auth_header)
	var error: int = _http_garden.request(url, headers)
	if error != OK:
		_garden_in_flight = false
		push_warning("GardenManager._fetch_garden: request error %d" % error)
		return
	var raw: Variant = await _http_garden.request_completed
	_garden_in_flight = false
	var http_result: int  = raw[0]
	var status_code: int  = raw[1]
	var body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
		if status_code == 401:
			UserManager.handle_401()
		push_warning("GardenManager._fetch_garden: HTTP %d" % status_code)
		return  # keep mock-loaded plots on any error
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("GardenManager._fetch_garden: JSON parse error")
		return
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if not data is Dictionary:
		push_warning("GardenManager._fetch_garden: data is not a Dictionary")
		return
	var plots_arr: Variant = data.get("plots", null)
	if not plots_arr is Array:
		push_warning("GardenManager._fetch_garden: missing 'plots' array in response")
		return
	var garden_svc := GardenService.new()
	var parsed_plots: Array[Plot] = garden_svc.parse_plots(plots_arr, _templates)
	parsed_plots.sort_custom(func(a: Plot, b: Plot) -> bool: return a.plot_index < b.plot_index)
	if parsed_plots.is_empty():
		push_warning("GardenManager._fetch_garden: BE returned 0 plots  -  keeping mock plots")
		return
	_plots = parsed_plots
	plots_updated.emit(_plots)

	var zones_arr: Variant = data.get("zones", null)
	if zones_arr is Array:
		ZoneManager.init_from_server(zones_arr)

func _exit_tree() -> void:
	if _garden_in_flight and _http_garden != null:
		_http_garden.cancel_request()
		_garden_in_flight = false
	if _dig_up_in_flight and _http_dig_up != null:
		_http_dig_up.cancel_request()
		_dig_up_in_flight = false

func get_item_cache() -> Dictionary:
	return _item_cache

func get_synergy_cache() -> Dictionary:
	return _synergy_cache

func get_plots() -> Array[Plot]:
	return _plots

func get_plot_position(index: int) -> Vector2:
	if index < PLOT_POSITIONS.size():
		return PLOT_POSITIONS[index]
	return Vector2.ZERO

func get_templates() -> Dictionary:
	return _templates

func get_plot(plot_id: String) -> Plot:
	return _find_plot(plot_id)

func _build_plots_by_index() -> Dictionary:
	var map: Dictionary = {}
	for p: Plot in _plots:
		map[p.plot_index] = p
	return map

func _get_synergy_bonus(plot_id: String) -> int:
	var plot: Plot = _find_plot(plot_id)
	if plot == null:
		return 0
	return SynergyEvaluator.get_bonus_for_plot(
		plot.plot_index,
		_build_plots_by_index(),
		_templates,
		_synergy_cache
	)

func water(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		await _mock_care(plot_id, 20, 0)
		return
	await _care_action(plot_id, 0, ref_id)

func fertilize(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		await _mock_care(plot_id, 50, 1)
		return
	await _care_action(plot_id, 1, ref_id)

func pesticide(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		await _mock_care(plot_id, 50, 2)
		return
	await _care_action(plot_id, 2, ref_id)

func _mock_care(plot_id: String, base_xp: int, action_type: int) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied:
		_show_toast(_care_action_name(action_type) + " thất bại.")
		return
	if plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		_show_toast("Không tìm thấy dữ liệu hoa.")
		return
	if action_type == 0:
		AudioManager.play_sfx("res://sounds/watering.wav")
	plot.is_pending_sync = true
	var bonus := _get_synergy_bonus(plot_id)
	var total := base_xp + bonus
	plot.current_plant.current_xp += total
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plant_xp_gained.emit(plot_id, total, bonus)
	plots_updated.emit(_plots)
	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)
	care_completed.emit(plot_id, action_type)
	_show_toast("%s thành công: +%d XP" % [_care_action_name(action_type), total])

func _care_action(plot_id: String, action_value: int, ref_id: String) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied:
		_show_toast(_care_action_name(action_value) + " thất bại.")
		return
	if plot.is_pending_sync:
		return
	if _templates.get(plot.current_plant.flower_template_id) == null:
		_show_toast("Không tìm thấy dữ liệu hoa.")
		return
	if ref_id.is_empty() or not InventoryManager.has_item(ref_id):
		_show_toast("Bạn chưa có vật phẩm để %s." % _care_action_verb(action_value))
		return

	var snapshot_plot := plot.deep_copy()
	var inv_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(ref_id)
	if inv_item == null:
		_show_toast("Bạn chưa có vật phẩm để %s." % _care_action_verb(action_value))
		return
	var snapshot_item_id: String = inv_item.id
	var snapshot_item_qty: int   = inv_item.quantity

	var item_data: Dictionary = _item_cache.get(ref_id, {})
	var base_xp: int = int(item_data.get("received_exp", 0))
	if base_xp == 0:
		match action_value:
			0: base_xp = 20
			1: base_xp = 50
			2: base_xp = 50
	var bonus := _get_synergy_bonus(plot_id)

	_care_apply_optimistic(plot, ref_id, base_xp, bonus, action_value)

	var url := UserManager.base_url + "/api/garden/plots/%s/care" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({"action": action_value}))
	if err != OK:
		http.queue_free()
		_care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
		_show_toast(_care_action_name(action_value) + " thất bại. Vui lòng thử lại.")
		return
	var raw: Variant = await http.request_completed
	http.queue_free()

	if _care_apply_server_response(plot, raw, action_value, snapshot_item_id):
		care_completed.emit(plot_id, action_value)
		var xp_delta := base_xp + bonus
		_show_toast("%s thành công: +%d XP" % [_care_action_name(action_value), xp_delta])
	else:
		_care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
		_show_toast(_care_action_name(action_value) + " thất bại. Vui lòng thử lại.")
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func _care_apply_optimistic(plot: Plot, ref_id: String, base_xp: int, bonus: int, action_value: int) -> void:
	var xp_delta := base_xp + bonus
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	plot.is_pending_sync = true
	InventoryManager.consume_item(ref_id)
	plot.current_plant.current_xp += xp_delta
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	if action_value == 0:
		plot.current_plant.last_watered_at = int(Time.get_unix_time_from_system())
		AudioManager.play_sfx("res://sounds/watering.wav")
	plant_xp_gained.emit(plot.id, xp_delta, bonus)
	plots_updated.emit(_plots)

func _care_apply_server_response(plot: Plot, raw: Variant, action_value: int, snapshot_item_id: String) -> bool:
	var http_result: int       = raw[0]
	var status: int            = raw[1]
	var bytes: PackedByteArray = raw[3]
	var body_text := bytes.get_string_from_utf8()
	if http_result != HTTPRequest.RESULT_SUCCESS:
		push_warning("GardenManager._care_apply_server_response: request result %d, HTTP %d, body=%s" % [http_result, status, body_text])
		return false
	if status != 200:
		if status == 401:
			UserManager.handle_401()
		push_warning("GardenManager._care_apply_server_response: HTTP %d, body=%s" % [status, body_text])
		return false
	var json := JSON.new()
	if json.parse(body_text) != OK:
		push_warning("GardenManager._care_apply_server_response: JSON parse error, body=%s" % body_text)
		return false
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		push_warning("GardenManager._care_apply_server_response: envelope malformed")
		return false
	var updated_plot_dict: Variant = (data as Dictionary).get("updatedPlot", null)
	if updated_plot_dict is Dictionary:
		var pf_dict: Variant = (updated_plot_dict as Dictionary).get("plantedFlower", null)
		if pf_dict is Dictionary:
			var svc := GardenService.new()
			var auth_flower: PlantedFlower = svc.parse_planted_flower(pf_dict, _templates)
			if auth_flower != null:
				plot.current_plant.current_xp    = auth_flower.current_xp
				plot.current_plant.current_stage = auth_flower.current_stage
				if action_value == 0 and auth_flower.last_watered_at > 0:
					plot.current_plant.last_watered_at = auth_flower.last_watered_at
	var remaining: Variant = (data as Dictionary).get("remainingQuantity", null)
	if remaining != null:
		InventoryManager.restore_item(snapshot_item_id, int(remaining))
	var care_user_xp: Variant    = (data as Dictionary).get("newUserXP", null)
	var care_user_level: Variant = (data as Dictionary).get("newUserLevel", null)
	if care_user_xp != null and care_user_level != null:
		UserManager.apply_server_xp(int(care_user_xp), int(care_user_level))
	return true

func _care_rollback(plot: Plot, snapshot: Plot, item_id: String, item_qty: int) -> void:
	plot.current_plant.current_xp    = snapshot.current_plant.current_xp
	plot.current_plant.current_stage = snapshot.current_plant.current_stage
	plot.is_pending_sync = false
	InventoryManager.restore_item(item_id, item_qty)

func plant(plot_id: String, flower_template_id: String) -> void:
	if _plant_in_flight:
		push_warning("GardenManager.plant: request already in flight, ignoring")
		_show_toast("Đang trồng hoa, vui lòng chờ.")
		return
	var plot: Plot = _find_plot(plot_id)
	if plot == null or plot.is_occupied or plot.is_pending_sync:
		plant_failed.emit(plot_id, "not_available")
		_show_toast("Ô đất này chưa thể trồng hoa.")
		return
	var template: FlowerTemplate = _templates.get(flower_template_id)
	if template == null:
		plant_failed.emit(plot_id, "unknown_template")
		_show_toast("Không tìm thấy loại hoa này.")
		return

	var seed_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(flower_template_id)
	if seed_item == null or seed_item.quantity <= 0:
		plant_failed.emit(plot_id, "no_seed")
		_show_toast("Bạn không còn hạt giống này.")
		return
	var snapshot_seed_id: String = seed_item.id
	var snapshot_seed_qty: int   = seed_item.quantity

	if not InventoryManager.consume_seed(flower_template_id):
		plant_failed.emit(plot_id, "no_seed")
		_show_toast("Bạn không còn hạt giống này.")
		return

	plot.is_pending_sync = true
	var flower := PlantedFlower.new(flower_template_id, "")
	flower.current_xp    = 0
	flower.current_stage = template.compute_stage_for_xp(0)
	plot.plant(flower)
	AudioManager.play_sfx("res://sounds/plant.wav")
	plots_updated.emit(_plots)

	if use_mock:
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		_show_toast("Đã trồng %s." % _flower_display_name(template))
		return

	var url := UserManager.base_url + "/api/garden/plots/%s/plant" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	var body := JSON.stringify({ "flowerTemplateId": flower_template_id })
	_plant_in_flight = true
	var err := _http_plant.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_plant_in_flight = false
		InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
		plot.clear()
		plot.is_pending_sync = false
		plant_failed.emit(plot_id, "request_error")
		plots_updated.emit(_plots)
		_show_toast("Trồng hoa thất bại. Vui lòng thử lại.")
		return

	var raw: Variant = await _http_plant.request_completed
	_plant_in_flight = false
	var status: int        = raw[1]
	var bytes: PackedByteArray = raw[3]

	if status == 200:
		var json := JSON.new()
		if json.parse(bytes.get_string_from_utf8()) == OK:
			var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
			if data is Dictionary:
				var svc := GardenService.new()
				var auth_plot: Plot = svc.parse_plot(data, _templates)
				if auth_plot != null and auth_plot.is_occupied:
					plot.plant(auth_plot.current_plant)
		_show_toast("Đã trồng %s." % _flower_display_name(template))
	else:
		if status == 401:
			UserManager.handle_401()
		InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
		plot.clear()
		plant_failed.emit(plot_id, "be_error_%d" % status)
		_show_toast("Trồng hoa thất bại. Vui lòng thử lại.")

	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func debug_add_xp(plot_id: String, xp_amount: int) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return

	plot.is_pending_sync = true
	plot.current_plant.current_xp += xp_amount
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plots_updated.emit(_plots)

	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func harvest(plot_id: String) -> void:
	if _harvest_in_flight:
		push_warning("GardenManager.harvest: request already in flight, ignoring")
		_show_toast("Đang thu hoạch, vui lòng chờ.")
		return
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		_show_toast("Chưa thể thu hoạch ô đất này.")
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		_show_toast("Không tìm thấy dữ liệu hoa.")
		return
	if plot.current_plant.current_stage < template.get_max_stage_level():
		_show_toast("Hoa chưa đủ lớn để thu hoạch.")
		return

	var snapshot_flower: PlantedFlower = plot.current_plant.deep_copy()
	var product_id := template.harvest_product_id

	plot.is_pending_sync = true
	plot.clear()
	AudioManager.play_sfx("res://sounds/harvest.wav")
	plots_updated.emit(_plots)

	if use_mock:
		harvest_completed.emit(plot_id, product_id)
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		_show_toast("Thu hoạch thành công: %s." % _flower_display_name(template))
		return

	var url := UserManager.base_url + "/api/garden/plots/%s/harvest" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	_harvest_in_flight = true
	var err := _http_harvest.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		_harvest_in_flight = false
		plot.plant(snapshot_flower)
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		_show_toast("Thu hoạch thất bại. Vui lòng thử lại.")
		return

	var raw: Variant = await _http_harvest.request_completed
	_harvest_in_flight = false
	var status: int        = raw[1]
	var bytes: PackedByteArray = raw[3]

	if status == 200:
		var json := JSON.new()
		if json.parse(bytes.get_string_from_utf8()) == OK:
			var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
			if data is Dictionary:
				var new_currency: Variant = data.get("newCurrencyTotal", null)
				if new_currency != null:
					UserManager.update_currency(int(new_currency))
				var new_user_xp: Variant = data.get("newUserXP", null)
				var new_user_level: Variant = data.get("newUserLevel", null)
				if new_user_xp != null and new_user_level != null:
					UserManager.apply_server_xp(int(new_user_xp), int(new_user_level))
		harvest_completed.emit(plot_id, product_id)
		_show_toast("Thu hoạch thành công: %s." % _flower_display_name(template))
	else:
		if status == 401:
			UserManager.handle_401()
		plot.plant(snapshot_flower)
		plots_updated.emit(_plots)
		_show_toast("Thu hoạch thất bại. Vui lòng thử lại.")

	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func dig_up(plot_id: String) -> void:
	if _dig_up_in_flight:
		push_warning("GardenManager.dig_up: request already in flight, ignoring")
		_show_toast("Đang xúc cây, vui lòng chờ.")
		return
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		_show_toast("Chưa thể xúc ô đất này.")
		return

	var snapshot_flower: PlantedFlower = plot.current_plant.deep_copy()
	var flower_template_id := plot.current_plant.flower_template_id

	plot.is_pending_sync = true
	plot.clear()
	plots_updated.emit(_plots)

	if use_mock:
		await get_tree().process_frame
		plot.is_pending_sync = false
		InventoryManager.restore_seed(flower_template_id)
		plots_updated.emit(_plots)
		_show_toast("Xúc cây thành công.")
		return

	var url := UserManager.base_url + "/api/garden/plots/%s/dig-up" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	_dig_up_in_flight = true
	var err := _http_dig_up.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		_dig_up_in_flight = false
		plot.plant(snapshot_flower)
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		_show_toast("Xúc cây thất bại. Vui lòng thử lại.")
		return

	var raw: Variant = await _http_dig_up.request_completed
	_dig_up_in_flight = false
	var status: int = raw[1]

	if status == 200:
		InventoryManager.restore_seed(flower_template_id)
		_show_toast("Xúc cây thành công.")
	else:
		if status == 401:
			UserManager.handle_401()
		plot.plant(snapshot_flower)
		_show_toast("Xúc cây thất bại. Vui lòng thử lại.")

	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func apply_focus_xp_bulk(xp_delta: int) -> void:
	for plot: Plot in _plots:
		if not plot.is_occupied or plot.is_pending_sync:
			push_warning("GardenManager.apply_focus_xp_bulk: skipping plot %s (pending=%s)" % [plot.id, plot.is_pending_sync])
			continue
		var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
		if template == null:
			push_warning("GardenManager.apply_focus_xp_bulk: no template for plot %s" % plot.id)
			continue
		plot.current_plant.current_xp = maxi(0, plot.current_plant.current_xp + xp_delta)
		plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
		plant_xp_gained.emit(plot.id, xp_delta, 0)
	plots_updated.emit(_plots)

func _on_focus_session_completed(_minutes: int) -> void:
	pass  # XP reward replaced by item reward  -  handled via session_reward_received

func _on_focus_reward_received(_items: Array) -> void:
	pass  # Items granted on BE; InventoryManager handles local state

func _on_focus_session_failed() -> void:
	apply_focus_xp_bulk(-focus_fail_xp_penalty)

func _find_plot(plot_id: String) -> Plot:
	for p: Plot in _plots:
		if p.id == plot_id:
			return p
	return null

func _show_toast(message: String, duration: float = 2.2) -> void:
	if is_inside_tree():
		Toast.show_message(self, message, duration)

func _care_action_name(action_type: int) -> String:
	match action_type:
		0: return "Tưới hoa"
		1: return "Bón phân"
		2: return "Diệt sâu"
		_: return "Chăm sóc hoa"

func _care_action_verb(action_type: int) -> String:
	match action_type:
		0: return "tưới hoa"
		1: return "bón phân"
		2: return "diệt sâu"
		_: return "chăm sóc hoa"

func _flower_display_name(template: FlowerTemplate) -> String:
	if template == null or template.name.is_empty():
		return "hoa"
	return template.name.replace("_", " ")


func _seed_mock_synergies() -> void:
	_synergy_cache = {
		"synergy_sun": {
			"id": "synergy_sun",
			"name": "Sun Chaser",
			"xp_plus": 10,
			"cooldown_minus": 0,
		},
		"synergy_water": {
			"id": "synergy_water",
			"name": "Water Lover",
			"xp_plus": 5,
			"cooldown_minus": 60,
		},
	}
	if _templates.has("lotus"):
		(_templates["lotus"] as FlowerTemplate).synergy_id = "synergy_water"
	if _templates.has("periwinkle"):
		(_templates["periwinkle"] as FlowerTemplate).synergy_id = "synergy_sun"

func debug_next_stage(plot_id: String) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	var next_xp := template.get_next_stage_xp(plot.current_plant.current_stage)
	if next_xp < 0:
		return
	plot.is_pending_sync = true
	plot.current_plant.current_xp = next_xp
	plot.current_plant.current_stage = template.compute_stage_for_xp(next_xp)
	plots_updated.emit(_plots)
	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func _on_plot_action(plot_id: String, action: String, data: Dictionary) -> void:
	match action:
		"plant":      plant(plot_id, data.get("template_id", ""))
		"harvest":    harvest(plot_id)
		"dig_up":     dig_up(plot_id)
		"water":      water(plot_id, data.get("ref_id", ""))
		"fertilize":  fertilize(plot_id, data.get("ref_id", ""))
		"pesticide":  pesticide(plot_id, data.get("ref_id", ""))
		"add_xp":     debug_add_xp(plot_id, data.get("amount", 500))
		"next_stage": debug_next_stage(plot_id)
