class_name InventoryService
extends RefCounted

# Parses BE InventoryDto `items` array into a UserInventory domain object.
func parse_inventory(arr: Array) -> UserInventory:
	var inv := UserInventory.new()
	for item_json: Variant in arr:
		if not item_json is Dictionary:
			continue
		var item: InventoryItem = parse_inventory_item(item_json)
		if item != null:
			inv.items.append(item)
	return inv

# Maps a BE InventoryItemDto JSON to an InventoryItem domain object.
# Category is derived from which nullable FK is populated — never assumed client-side.
# Returns null (and push_warning) if all three FK fields are null.
func parse_inventory_item(json: Dictionary) -> InventoryItem:
	var flower_template_id: String  = _str_or_empty(json.get("flowerTemplateId", null))
	var item_id: String             = _str_or_empty(json.get("itemId", null))
	var decor_id: String            = _str_or_empty(json.get("decorId", null))
	var harvest_product_id: String  = _str_or_empty(json.get("harvestProductId", null))

	var category: InventoryItem.Category
	if not flower_template_id.is_empty():
		category = InventoryItem.Category.SEED
	elif not item_id.is_empty():
		category = InventoryItem.Category.CONSUMABLE
	elif not decor_id.is_empty():
		category = InventoryItem.Category.DECOR
	elif not harvest_product_id.is_empty():
		category = InventoryItem.Category.HARVEST_PRODUCT
	else:
		push_warning("InventoryService.parse_inventory_item: all FK fields null for id '%s'" \
			% str(json.get("id", "")))
		return null

	var item := InventoryItem.new()
	item.id                  = _str_or_empty(json.get("id", null))
	item.quantity            = int(json.get("quantity", 0))
	item.category            = category
	item.flower_template_id  = flower_template_id
	item.item_id             = item_id
	item.decor_id            = decor_id
	item.decor_slug          = _str_or_empty(json.get("decorSlug", null))
	item.decor_name          = _str_or_empty(json.get("decorName", null))
	item.harvest_product_id  = harvest_product_id
	return item

# Converts a JSON value to a non-empty String, returning "" for null/missing/"null".
func _str_or_empty(value: Variant) -> String:
	if value == null:
		return ""
	var s: String = str(value)
	return "" if s == "null" else s
