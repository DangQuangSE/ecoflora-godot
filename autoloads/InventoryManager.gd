extends Node

signal inventory_updated(inventory: UserInventory)
signal item_selected(item: InventoryItem)

@export var use_mock: bool = false

var _inventory: UserInventory
var _selected_item: InventoryItem = null
var _http: HTTPRequest
var _request_in_flight: bool = false

func _ready() -> void:
	if use_mock:
		_inventory = MockInventoryService.new().get_initial_inventory()
	else:
		_inventory = UserInventory.new()
		_http = HTTPRequest.new()
		_http.timeout = 10.0
		add_child(_http)
		UserManager.login_succeeded.connect(_on_login_succeeded)
		var err := FocusManager.session_reward_received.connect(_on_focus_reward_items)
		assert(err == OK, "InventoryManager: failed to connect session_reward_received")

func _on_login_succeeded() -> void:
	await _fetch_inventory()

func _fetch_inventory() -> void:
	if _request_in_flight:
		return
	_request_in_flight = true
	var url: String = UserManager.base_url + "/api/inventory"
	var auth_header: String = UserManager.get_auth_header()
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if not auth_header.is_empty():
		headers.append(auth_header)
	var error: int = _http.request(url, headers)
	if error != OK:
		_request_in_flight = false
		push_warning("InventoryManager._fetch_inventory: request error %d" % error)
		return
	var raw: Variant = await _http.request_completed
	_request_in_flight = false
	var http_result: int      = raw[0]
	var status_code: int      = raw[1]
	var body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
		if status_code == 401:
			UserManager.handle_401()
		push_warning("InventoryManager._fetch_inventory: HTTP %d" % status_code)
		return  # keep mock inventory on any error
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("InventoryManager._fetch_inventory: JSON parse error")
		return
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if not data is Dictionary:
		push_warning("InventoryManager._fetch_inventory: data is not a Dictionary")
		return
	var items_arr: Variant = data.get("items", null)
	if not items_arr is Array:
		push_warning("InventoryManager._fetch_inventory: missing 'items' array in response")
		return
	var inv_svc := InventoryService.new()
	var fetched: UserInventory = inv_svc.parse_inventory(items_arr)
	# Preserve any locally-appended harvest products from this session
	for item: InventoryItem in _inventory.items:
		if item.category == InventoryItem.Category.HARVEST_PRODUCT:
			fetched.items.append(item)
	_inventory = fetched
	inventory_updated.emit(_inventory)

func _exit_tree() -> void:
	if _request_in_flight and _http != null:
		_http.cancel_request()
		_request_in_flight = false

func get_inventory() -> UserInventory:
	return _inventory

func get_selected_item() -> InventoryItem:
	return _selected_item

func select_item(item_id: String) -> void:
	var item: InventoryItem = _inventory.find_by_id(item_id)
	if _selected_item != null and _selected_item.id == item_id:
		_selected_item = null
	else:
		_selected_item = item
		if _selected_item != null and InteractionManager.is_harvest_mode():
			InteractionManager.toggle_harvest_mode()
	item_selected.emit(_selected_item)

func deselect() -> void:
	_selected_item = null
	item_selected.emit(null)

func has_seed(flower_template_id: String) -> bool:
	var item: InventoryItem = _inventory.find_by_reference_id(flower_template_id)
	return item != null and item.quantity > 0

func has_item(ref_id: String) -> bool:
	var item: InventoryItem = _inventory.find_by_reference_id(ref_id)
	return item != null and item.quantity > 0

func consume_item(ref_id: String) -> bool:
	var item: InventoryItem = _inventory.find_by_reference_id(ref_id)
	if item == null or item.quantity <= 0:
		return false
	item.quantity -= 1
	if item.quantity == 0 and _selected_item != null and _selected_item.id == item.id:
		_selected_item = null
		item_selected.emit(null)
	inventory_updated.emit(_inventory)
	return true

func consume_seed(flower_template_id: String) -> bool:
	var item: InventoryItem = _inventory.find_by_reference_id(flower_template_id)
	if item == null or item.quantity <= 0:
		return false
	item.quantity -= 1
	if item.quantity == 0 and _selected_item != null and _selected_item.id == item.id:
		_selected_item = null
		item_selected.emit(null)
	inventory_updated.emit(_inventory)
	return true

func restore_item(item_id: String, qty: int) -> void:
	for item: InventoryItem in _inventory.items:
		if item.id == item_id:
			item.quantity = qty
			inventory_updated.emit(_inventory)
			return
	push_warning("InventoryManager.restore_item: item_id '%s' not found" % item_id)

func remove_harvest_product(product_id: String) -> void:
	var existing: InventoryItem = _inventory.find_harvest_product(product_id)
	if existing == null:
		push_warning("InventoryManager.remove_harvest_product: product '%s' not found" % product_id)
		return
	if existing.quantity <= 1:
		_inventory.items.erase(existing)
	else:
		existing.quantity -= 1
	inventory_updated.emit(_inventory)

func add_reward_item(item_id: String, _item_name: String, quantity: int) -> void:
	var existing: InventoryItem = _inventory.find_by_reference_id(item_id)
	if existing != null:
		existing.quantity += quantity
	else:
		var new_item := InventoryItem.new()
		new_item.id = "reward_%s" % item_id
		new_item.item_id = item_id
		new_item.category = InventoryItem.Category.CONSUMABLE
		new_item.quantity = quantity
		_inventory.items.append(new_item)
	inventory_updated.emit(_inventory)

func _on_focus_reward_items(items: Array) -> void:
	for entry: Variant in items:
		if not entry is Dictionary:
			continue
		var item_id: String = str(entry.get("itemId", ""))
		var item_name: String = str(entry.get("itemName", ""))
		var qty: int = int(entry.get("quantity", 0))
		if item_id.is_empty() or qty <= 0:
			continue
		add_reward_item(item_id, item_name, qty)

# BE-local only — harvest products are appended in-memory and never synced to BE
func add_harvest_product(product_id: String) -> void:
	var existing: InventoryItem = _inventory.find_harvest_product(product_id)
	if existing != null:
		existing.quantity += 1
	else:
		var new_item := InventoryItem.new()
		new_item.id = "harvest_%s_%d" % [product_id, _inventory.items.size()]
		new_item.harvest_product_id = product_id
		new_item.category = InventoryItem.Category.HARVEST_PRODUCT
		new_item.quantity = 1
		_inventory.items.append(new_item)
	inventory_updated.emit(_inventory)
