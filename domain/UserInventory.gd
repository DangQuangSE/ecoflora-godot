class_name UserInventory
extends RefCounted

var id: String
var user_id: String
var current_slots: int
var items: Array[InventoryItem] = []

func find_by_id(entry_id: String) -> InventoryItem:
	for item: InventoryItem in items:
		if item.id == entry_id:
			return item
	return null

func find_by_reference_id(ref_id: String) -> InventoryItem:
	if ref_id.is_empty():
		return null
	for item: InventoryItem in items:
		if item.get_reference_id() == ref_id:
			return item
	return null

func find_harvest_product(harvest_product_id: String) -> InventoryItem:
	for item: InventoryItem in items:
		if item.category == InventoryItem.Category.HARVEST_PRODUCT \
				and item.harvest_product_id == harvest_product_id:
			return item
	return null
