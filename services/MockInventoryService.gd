class_name MockInventoryService
extends RefCounted

func get_initial_inventory() -> UserInventory:
	var inv := UserInventory.new()
	inv.items = []
	inv.items.append(_make_seed_stack("lotus", 3))
	inv.items.append(_make_seed_stack("rose", 3))
	inv.items.append(_make_seed_stack("periwinkle", 3))
	inv.items.append(_make_consumable("watering_can", 5))
	inv.items.append(_make_consumable("fertilizer", 3))
	inv.items.append(_make_consumable("sickle", 1))
	return inv

func _make_seed_stack(flower_template_id: String, quantity: int) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = "seed_%s" % flower_template_id
	item.flower_template_id = flower_template_id
	item.category = InventoryItem.Category.SEED
	item.quantity = quantity
	return item

func _make_consumable(item_id: String, quantity: int) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = "item_%s" % item_id
	item.item_id = item_id
	item.category = InventoryItem.Category.CONSUMABLE
	item.quantity = quantity
	return item
