class_name InventoryItem
extends RefCounted

enum Category { SEED = 0, CONSUMABLE = 1, DECOR = 2, HARVEST_PRODUCT = 3 }

var id: String
var inventory_id: String
var flower_template_id: String
var item_id: String
var decor_id: String
var decor_slug: String
var decor_name: String
var harvest_product_id: String
var quantity: int
var category: Category

func get_reference_id() -> String:
	match category:
		Category.SEED:            return flower_template_id
		Category.CONSUMABLE:      return item_id
		Category.DECOR:           return decor_slug
		Category.HARVEST_PRODUCT: return harvest_product_id
		_:
			push_error("InventoryItem.get_reference_id: unknown category %d for item %s" % [category, id])
			return ""
