class_name ReferenceDataService
extends RefCounted

# Parses GET /api/flowertemplates response array into FlowerTemplate domain objects.
# NOTE: BE FlowerTemplateDto has no stage data — stages array will be empty.
# TODO: request BE to add stage thresholds endpoint.
func parse_flower_templates(arr: Array) -> Dictionary:
	var result: Dictionary = {}
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var d: Dictionary = item
		var t := FlowerTemplate.new()
		t.id       = str(d.get("id", ""))
		t.name     = str(d.get("name", ""))
		t.base_price = int(d.get("basePrice", 0))
		t.image_url  = str(d.get("imageUrl", ""))
		t.synergy_id = str(d.get("synergyId", ""))
		# Stages not provided by BE — push warning so gap is visible
		push_warning("ReferenceDataService: no stage data for template '%s' — keeping empty stages" % t.name)
		result[t.id] = t
	return result

# Parses GET /api/items response array into raw Dictionary cache keyed by id.
# TODO: create ItemTemplate domain class when item gameplay is implemented.
func parse_items(arr: Array) -> Dictionary:
	var result: Dictionary = {}
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var d: Dictionary = item
		var id: String = str(d.get("id", ""))
		if id.is_empty():
			continue
		result[id] = {
			"id":           id,
			"name":         str(d.get("name", "")),
			"price":        int(d.get("price", 0)),
			"image_url":    str(d.get("imageUrl", "")),
			"cooldown_time": int(d.get("cooldownTime", 0)),
			"type":         str(d.get("type", "")),
			"received_exp": int(d.get("receivedExp", 0)),
		}
	return result

# Parses GET /api/synergies response array into raw Dictionary cache keyed by id.
func parse_synergies(arr: Array) -> Dictionary:
	var result: Dictionary = {}
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var d: Dictionary = item
		var id: String = str(d.get("id", ""))
		if id.is_empty():
			continue
		result[id] = {
			"id":            id,
			"name":          str(d.get("name", "")),
			"xp_plus":       int(d.get("xpPlus", 0)),
			"cooldown_minus": int(d.get("cooldownMinus", 0)),
		}
	return result
