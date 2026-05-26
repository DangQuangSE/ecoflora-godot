class_name MockInventoryService
extends RefCounted

func get_initial_inventory() -> UserInventory:
	var inv := UserInventory.new()
	inv.items = []
	inv.items.append_array(_make_seeds("sunflower", 3))
	inv.items.append_array(_make_seeds("rose", 3))
	return inv

func _make_seeds(flower_template_id: String, count: int) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for i in range(count):
		var item := InventoryItem.new()
		item.id = "seed_%s_%d" % [flower_template_id, i]
		item.flower_template_id = flower_template_id
		item.category = InventoryItem.Category.SEED
		item.quantity = 1
		result.append(item)
	return result
