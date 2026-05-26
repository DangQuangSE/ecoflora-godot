extends Node

signal inventory_updated(inventory: UserInventory)

var _inventory: UserInventory

func _ready() -> void:
	_inventory = MockInventoryService.new().get_initial_inventory()

func get_inventory() -> UserInventory:
	return _inventory

func has_seed(flower_template_id: String) -> bool:
	var item := _inventory.find_by_reference_id(flower_template_id)
	return item != null and item.quantity > 0

func consume_seed(flower_template_id: String) -> bool:
	var item := _inventory.find_by_reference_id(flower_template_id)
	if item == null or item.quantity <= 0:
		return false
	item.quantity -= 1
	if item.quantity == 0:
		_inventory.items.erase(item)
	inventory_updated.emit(_inventory)
	return true

func add_harvest_product(product_id: String) -> void:
	var existing := _inventory.find_harvest_product(product_id)
	if existing != null:
		existing.quantity += 1
	else:
		var item := InventoryItem.new()
		item.id = "harvest_%s_%d" % [product_id, _inventory.items.size()]
		item.harvest_product_id = product_id
		item.category = InventoryItem.Category.HARVEST_PRODUCT
		item.quantity = 1
		_inventory.items.append(item)
	inventory_updated.emit(_inventory)
