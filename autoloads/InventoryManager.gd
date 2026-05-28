extends Node

signal inventory_updated(inventory: UserInventory)
signal item_selected(item: InventoryItem)

var _inventory: UserInventory
var _selected_item: InventoryItem = null

func _ready() -> void:
	_inventory = MockInventoryService.new().get_initial_inventory()

func get_inventory() -> UserInventory:
	return _inventory

func get_selected_item() -> InventoryItem:
	return _selected_item

func select_item(item_id: String) -> void:
	var item := _inventory.find_by_id(item_id)
	if _selected_item != null and _selected_item.id == item_id:
		_selected_item = null
	else:
		_selected_item = item
	item_selected.emit(_selected_item)

func deselect() -> void:
	_selected_item = null
	item_selected.emit(null)

func has_seed(flower_template_id: String) -> bool:
	var item := _inventory.find_by_reference_id(flower_template_id)
	return item != null and item.quantity > 0

func has_item(ref_id: String) -> bool:
	var item := _inventory.find_by_reference_id(ref_id)
	return item != null and item.quantity > 0

func consume_item(ref_id: String) -> bool:
	var item := _inventory.find_by_reference_id(ref_id)
	if item == null or item.quantity <= 0:
		return false
	item.quantity -= 1
	if item.quantity == 0 and _selected_item != null and _selected_item.id == item.id:
		_selected_item = null
		item_selected.emit(null)
	inventory_updated.emit(_inventory)
	return true

func consume_seed(flower_template_id: String) -> bool:
	var item := _inventory.find_by_reference_id(flower_template_id)
	if item == null or item.quantity <= 0:
		return false
	item.quantity -= 1
	if item.quantity == 0 and _selected_item != null and _selected_item.id == item.id:
		_selected_item = null
		item_selected.emit(null)
	inventory_updated.emit(_inventory)
	return true

func add_harvest_product(product_id: String) -> void:
	var existing := _inventory.find_harvest_product(product_id)
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
