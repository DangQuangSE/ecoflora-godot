extends Node

signal plots_updated(plots: Array[Plot])
signal plant_failed(plot_id: String, reason: String)
signal harvest_completed(plot_id: String, product_id: String)
signal plant_xp_gained(plot_id: String, xp_amount: int)
signal icons_registered

@export var use_mock: bool = false

const GARDEN_ID := "main_garden"

var _plots: Array[Plot] = []
var _templates: Dictionary = {}
var _item_cache: Dictionary = {}
var _synergy_cache: Dictionary = {}

var _http_catalog: HTTPRequest
var _http_garden: HTTPRequest
var _http_plant: HTTPRequest
var _http_harvest: HTTPRequest
var _garden_in_flight: bool = false
var _ref_svc  # ReferenceDataService instance (preloaded to avoid autoload parse-order issue)

const _RefDataScript = preload("res://services/ReferenceDataService.gd")

# World positions for 16 plots — initial 8 (2×4 grid) + zone_1 (plots 8–11) + zone_2 (plots 12–15)
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
		# Fetch catalogs + garden after login — never before
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
			plots_updated.emit(_plots)

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
	# Variant flowers — reuse base asset folder
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
		var icon_path := "res://assets/flowers/%s/%s 3.png" % [asset_name, asset_name]
		if ResourceLoader.exists(icon_path):
			ItemIconRegistry.register(tid, load(icon_path))

	# Register item icons by UUID using keyword-contains matching.
	# sickle.png is the harvest UI button — NOT an item icon.
	for iid: String in _item_cache:
		var item: Dictionary = _item_cache[iid]
		var raw_name: String = str(item.get("name", "")).to_lower()
		var icon_path: String
		if "watering can" in raw_name:
			icon_path = "res://assets/icon/watering_can.PNG"
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
	if parsed_plots.is_empty():
		push_warning("GardenManager._fetch_garden: BE returned 0 plots — keeping mock plots")
		return
	_plots = parsed_plots
	plots_updated.emit(_plots)

func _exit_tree() -> void:
	if _garden_in_flight and _http_garden != null:
		_http_garden.cancel_request()
		_garden_in_flight = false

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

func water(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		const WATER_XP := 20
		var plot: Plot = _find_plot(plot_id)
		if plot == null or not plot.is_occupied or plot.is_pending_sync:
			return
		var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
		if template == null:
			return
		plot.is_pending_sync = true
		plot.current_plant.current_xp += WATER_XP
		plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
		plant_xp_gained.emit(plot_id, WATER_XP)
		plots_updated.emit(_plots)
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		return
	await _care_action(plot_id, 0, ref_id)

func fertilize(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		const FERTILIZE_XP := 50
		var plot: Plot = _find_plot(plot_id)
		if plot == null or not plot.is_occupied or plot.is_pending_sync:
			return
		var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
		if template == null:
			return
		plot.is_pending_sync = true
		plot.current_plant.current_xp += FERTILIZE_XP
		plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
		plant_xp_gained.emit(plot_id, FERTILIZE_XP)
		plots_updated.emit(_plots)
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		return
	await _care_action(plot_id, 1, ref_id)

func pesticide(plot_id: String, ref_id: String = "") -> void:
	if use_mock:
		await fertilize(plot_id, ref_id)  # mock: same XP as fertilize
		return
	await _care_action(plot_id, 2, ref_id)

func _care_action(plot_id: String, action_value: int, ref_id: String) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	if ref_id.is_empty() or not InventoryManager.has_item(ref_id):
		return

	var snapshot_plot := plot.deep_copy()
	var inv_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(ref_id)
	if inv_item == null:
		return
	var snapshot_item_id: String = inv_item.id
	var snapshot_item_qty: int   = inv_item.quantity

	var item_data: Dictionary = _item_cache.get(ref_id, {})
	var xp_delta: int = int(item_data.get("received_exp", 0))
	if xp_delta == 0:
		match action_value:
			0: xp_delta = 20
			1: xp_delta = 50
			2: xp_delta = 50

	plot.is_pending_sync = true
	InventoryManager.consume_item(ref_id)
	plot.current_plant.current_xp += xp_delta
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plant_xp_gained.emit(plot_id, xp_delta)
	plots_updated.emit(_plots)

	var url := UserManager.base_url + "/api/garden/plots/%s/care" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	var body := JSON.stringify({ "action": action_value })
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
		return
	var raw: Variant = await http.request_completed
	http.queue_free()
	var status: int       = raw[1]
	var bytes: PackedByteArray = raw[3]

	if status == 200:
		var json := JSON.new()
		var parse_ok := json.parse(bytes.get_string_from_utf8()) == OK
		var data: Variant = HttpHelper.unwrap_envelope(json.get_data()) if parse_ok else null
		if data is Dictionary:
			var updated_plot_dict: Variant = data.get("updatedPlot", null)
			if updated_plot_dict is Dictionary:
				var pf_dict: Variant = (updated_plot_dict as Dictionary).get("plantedFlower", null)
				if pf_dict is Dictionary:
					var svc := GardenService.new()
					var auth_flower: PlantedFlower = svc.parse_planted_flower(pf_dict, _templates)
					if auth_flower != null:
						plot.current_plant.current_xp    = auth_flower.current_xp
						plot.current_plant.current_stage = auth_flower.current_stage
			var remaining: Variant = data.get("remainingQuantity", null)
			if remaining != null:
				InventoryManager.restore_item(snapshot_item_id, int(remaining))
		else:
			push_warning("GardenManager._care_action: 200 but envelope malformed — rolling back")
			_care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
	else:
		if status == 401:
			UserManager.handle_401()
		_care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)

	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func _care_rollback(plot: Plot, snapshot: Plot, item_id: String, item_qty: int) -> void:
	plot.current_plant.current_xp    = snapshot.current_plant.current_xp
	plot.current_plant.current_stage = snapshot.current_plant.current_stage
	plot.is_pending_sync = false
	InventoryManager.restore_item(item_id, item_qty)

func plant(plot_id: String, flower_template_id: String) -> void:
	var plot: Plot = _find_plot(plot_id)
	if plot == null or plot.is_occupied or plot.is_pending_sync:
		plant_failed.emit(plot_id, "not_available")
		return
	var template: FlowerTemplate = _templates.get(flower_template_id)
	if template == null:
		plant_failed.emit(plot_id, "unknown_template")
		return

	var seed_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(flower_template_id)
	if seed_item == null or seed_item.quantity <= 0:
		plant_failed.emit(plot_id, "no_seed")
		return
	var snapshot_seed_id: String = seed_item.id
	var snapshot_seed_qty: int   = seed_item.quantity

	if not InventoryManager.consume_seed(flower_template_id):
		plant_failed.emit(plot_id, "no_seed")
		return

	plot.is_pending_sync = true
	var flower := PlantedFlower.new(flower_template_id, "")
	flower.current_xp    = 0
	flower.current_stage = template.compute_stage_for_xp(0)
	plot.plant(flower)
	plots_updated.emit(_plots)

	if use_mock:
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		return

	var url := UserManager.base_url + "/api/garden/plots/%s/plant" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	var body := JSON.stringify({ "flowerTemplateId": flower_template_id })
	var err := _http_plant.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
		plot.clear()
		plot.is_pending_sync = false
		plant_failed.emit(plot_id, "request_error")
		plots_updated.emit(_plots)
		return

	var raw: Variant = await _http_plant.request_completed
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
	else:
		if status == 401:
			UserManager.handle_401()
		InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
		plot.clear()
		plant_failed.emit(plot_id, "be_error_%d" % status)

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
	var plot: Plot = _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	if plot.current_plant.current_stage < template.get_max_stage_level():
		return

	var snapshot_flower: PlantedFlower = plot.current_plant.deep_copy()
	var product_id := template.harvest_product_id

	plot.is_pending_sync = true
	plot.clear()
	plots_updated.emit(_plots)

	if use_mock:
		harvest_completed.emit(plot_id, product_id)
		InventoryManager.add_harvest_product(product_id)
		await get_tree().process_frame
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		return

	var url := UserManager.base_url + "/api/garden/plots/%s/harvest" % plot_id
	var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
	var err := _http_harvest.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		plot.plant(snapshot_flower)
		plot.is_pending_sync = false
		plots_updated.emit(_plots)
		return

	var raw: Variant = await _http_harvest.request_completed
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
				var xp_earned: Variant = data.get("xpEarned", null)
				if xp_earned != null:
					UserManager.add_harvest_xp(int(xp_earned))
		InventoryManager.add_harvest_product(product_id)
		harvest_completed.emit(plot_id, product_id)
	else:
		if status == 401:
			UserManager.handle_401()
		plot.plant(snapshot_flower)
		plots_updated.emit(_plots)

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
		plant_xp_gained.emit(plot.id, xp_delta)
	plots_updated.emit(_plots)

func _on_focus_session_completed(_minutes: int) -> void:
	pass  # XP reward replaced by item reward — handled via session_reward_received

func _on_focus_reward_received(_items: Array) -> void:
	pass  # Items granted on BE; InventoryManager handles local state

func _on_focus_session_failed() -> void:
	apply_focus_xp_bulk(-20)

func _find_plot(plot_id: String) -> Plot:
	for p: Plot in _plots:
		if p.id == plot_id:
			return p
	return null

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
		"water":      water(plot_id, data.get("ref_id", ""))
		"fertilize":  fertilize(plot_id, data.get("ref_id", ""))
		"pesticide":  pesticide(plot_id, data.get("ref_id", ""))
		"add_xp":     debug_add_xp(plot_id, data.get("amount", 500))
		"next_stage": debug_next_stage(plot_id)
