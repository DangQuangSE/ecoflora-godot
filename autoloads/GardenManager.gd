extends Node

signal plots_updated(plots: Array[Plot])
signal plant_failed(plot_id: String, reason: String)
signal harvest_completed(plot_id: String, product_id: String)
signal plant_xp_gained(plot_id: String, xp_amount: int)

@export var use_mock: bool = false

const GARDEN_ID := "main_garden"

var _plots: Array[Plot] = []
var _templates: Dictionary = {}
var _item_cache: Dictionary = {}
var _synergy_cache: Dictionary = {}

var _http_catalog: HTTPRequest
var _http_garden: HTTPRequest
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

	if not use_mock:
		_http_catalog = HTTPRequest.new()
		_http_catalog.timeout = 10.0
		add_child(_http_catalog)
		_http_garden = HTTPRequest.new()
		_http_garden.timeout = 10.0
		add_child(_http_garden)
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
	"anthurium":         "anthurium",
	"lotus":             "lotus",
	"periwinkle":        "periwinkle",
	"purple_bellflower": "purple_bellflower",
	"rose":              "rose",
	"sun_flower":        "sun_flower",
	"tulip":             "tulip",
}

# Maps BE item name (lowercased, stripped of "super ") to icon path.
const _ITEM_NAME_TO_ICON: Dictionary = {
	"watering can": "res://assets/icon/watering_can.PNG",
	"fertilizer":   "res://assets/icon/fertilizer.png",
	"pesticide":    "res://assets/icon/sickle.png",
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

	# Register item icons by UUID
	for iid: String in _item_cache:
		var item: Dictionary = _item_cache[iid]
		var raw_name: String = str(item.get("name", "")).to_lower()
		var base_name: String = raw_name.replace("super ", "")
		var icon_path: String = _ITEM_NAME_TO_ICON.get(base_name, "")
		if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
			continue
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

# TODO: sync mutation to BE — POST /api/garden/plots/{plot_id}/care { action: 0 }
func water(plot_id: String) -> void:
	const WATER_XP := 20
	var plot := _find_plot(plot_id)
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

# TODO: sync mutation to BE — POST /api/garden/plots/{plot_id}/care { action: 1 }
func fertilize(plot_id: String) -> void:
	const FERTILIZE_XP := 50
	var plot := _find_plot(plot_id)
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

# TODO: sync mutation to BE — POST /api/garden/plots/{plot_id}/plant { flowerTemplateId }
func plant(plot_id: String, flower_template_id: String) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or plot.is_occupied or plot.is_pending_sync:
		plant_failed.emit(plot_id, "not_available")
		return
	var template: FlowerTemplate = _templates.get(flower_template_id)
	if template == null:
		plant_failed.emit(plot_id, "unknown_template")
		return
	# Consume seed authoritatively here — after all guards pass, before optimistic update
	if not InventoryManager.consume_seed(flower_template_id):
		plant_failed.emit(plot_id, "no_seed")
		return

	plot.is_pending_sync = true
	var flower := PlantedFlower.new(flower_template_id, "")
	flower.current_xp = 0
	flower.current_stage = template.compute_stage_for_xp(0)
	plot.plant(flower)
	plots_updated.emit(_plots)

	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func debug_add_xp(plot_id: String, xp_amount: int) -> void:
	var plot := _find_plot(plot_id)
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

# TODO: sync mutation to BE — POST /api/garden/plots/{plot_id}/harvest
func harvest(plot_id: String) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	if plot.current_plant.current_stage < template.get_max_stage_level():
		return

	plot.is_pending_sync = true
	var product_id := template.harvest_product_id
	plot.clear()
	plots_updated.emit(_plots)
	harvest_completed.emit(plot_id, product_id)

	await get_tree().process_frame
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

func _on_focus_session_completed(minutes: int) -> void:
	apply_focus_xp_bulk(minutes)

func _on_focus_session_failed() -> void:
	apply_focus_xp_bulk(-20)

func _find_plot(plot_id: String) -> Plot:
	for p: Plot in _plots:
		if p.id == plot_id:
			return p
	return null

func debug_next_stage(plot_id: String) -> void:
	var plot := _find_plot(plot_id)
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
		"water":      water(plot_id)
		"fertilize":  fertilize(plot_id)
		"add_xp":     debug_add_xp(plot_id, data.get("amount", 500))
		"next_stage": debug_next_stage(plot_id)
