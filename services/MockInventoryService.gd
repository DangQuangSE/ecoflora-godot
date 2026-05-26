class_name MockInventoryService
extends RefCounted

func get_initial_inventory() -> UserInventory:
	var inv := UserInventory.new()
	inv.items = []
	inv.items.append(_make_seed_stack("lotus", 3))
	inv.items.append(_make_seed_stack("rose", 3))
	inv.items.append(_make_seed_stack("periwinkle", 3))
	return inv

func _make_seed_stack(flower_template_id: String, quantity: int) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = "seed_%s" % flower_template_id
	item.flower_template_id = flower_template_id
	item.category = InventoryItem.Category.SEED
	item.quantity = quantity
	return item
