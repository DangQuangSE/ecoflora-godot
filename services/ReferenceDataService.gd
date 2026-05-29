class_name ReferenceDataService
extends RefCounted

# Stage thresholds and harvest product IDs for known flower names.
# Keyed by lowercase template name as returned by BE.
# Format: { "name": { "stages": [[level, xp], ...], "harvest_id": "harvest_X_bloom" } }
const _FLOWER_DEFAULTS: Dictionary = {
	"sunflower":  { "stages": [[1, 0], [4, 100], [7, 300]], "harvest_id": "harvest_sunflower_bloom" },
	"rose":       { "stages": [[1, 0], [4, 120], [7, 360]], "harvest_id": "harvest_rose_bloom" },
	"daisy":      { "stages": [[1, 0], [4, 80],  [7, 250]], "harvest_id": "harvest_daisy_bloom" },
	"tulip":      { "stages": [[1, 0], [4, 110], [7, 320]], "harvest_id": "harvest_tulip_bloom" },
	# Keep legacy mock names for backward compatibility
	"lotus":      { "stages": [[1, 0], [4, 100], [7, 300]], "harvest_id": "harvest_lotus_bloom" },
	"periwinkle": { "stages": [[1, 0], [4, 80],  [7, 250]], "harvest_id": "harvest_periwinkle_bloom" },
}

# Parses GET /api/flowertemplates response array into FlowerTemplate domain objects.
# Injects hardcoded stage thresholds by template name when BE doesn't return stage data.
func parse_flower_templates(arr: Array) -> Dictionary:
	var result: Dictionary = {}
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var d: Dictionary = item
		var t := FlowerTemplate.new()
		t.id         = str(d.get("id", ""))
		t.name       = str(d.get("name", ""))
		t.base_price = int(d.get("basePrice", 0))
		t.image_url  = str(d.get("imageUrl", ""))
		t.synergy_id = str(d.get("synergyId", ""))
		_inject_defaults(t)
		result[t.id] = t
	return result

func _inject_defaults(t: FlowerTemplate) -> void:
	var defaults: Dictionary = _FLOWER_DEFAULTS.get(t.name.to_lower(), {})
	if defaults.is_empty():
		push_warning("ReferenceDataService: unknown template '%s' — no stage data or harvest id" % t.name)
		return
	t.harvest_product_id = defaults["harvest_id"]
	for pair: Array in defaults["stages"]:
		var s := StageDefinition.new()
		s.level       = pair[0]
		s.xp_required = pair[1]
		t.stages.append(s)

# Parses GET /api/items response array into raw Dictionary cache keyed by id.
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
			"type":         int(d.get("type", 0)),
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
