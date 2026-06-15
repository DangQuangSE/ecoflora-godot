class_name ReferenceDataService
extends RefCounted

# Stage thresholds and harvest product IDs for known flower names.
# Keyed by lowercase template name as returned by BE.
# Format: { "name": { "stages": [[level, xp], ...], "harvest_id": "harvest_X_bloom" } }
# Stage system: 0=sprout(0xp), 1=early(50xp), 2=mid(150xp), 3=full/harvestable(300xp)
# Keys must match BE template names (lowercase) AND asset folder names exactly.
const _FLOWER_DEFAULTS: Dictionary = {
	# Base flowers
	"anthurium":           { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_anthurium_bloom" },
	"lotus":               { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_lotus_bloom" },
	"periwinkle":          { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_periwinkle_bloom" },
	"purple_bellflower":   { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_purple_bellflower_bloom" },
	"rose":                { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_rose_bloom" },
	"sun_flower":          { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_sun_flower_bloom" },
	"tulip":               { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_tulip_bloom" },
	# Variant flowers — higher XP thresholds, unique harvest ids, reuse base assets
	"golden_rose":         { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_golden_rose_bloom" },
	"blue_lotus":          { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_blue_lotus_bloom" },
	"rainbow_tulip":       { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_rainbow_tulip_bloom" },
	"midnight_periwinkle": { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_midnight_periwinkle_bloom" },
	"crimson_anthurium":   { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_crimson_anthurium_bloom" },
	"sunset_sunflower":    { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_sunset_sunflower_bloom" },
	"violet_bellflower":   { "stages": [[0, 0], [1, 80], [2, 220], [3, 450]], "harvest_id": "harvest_violet_bellflower_bloom" },
	"moonlit_rose":        { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_moonlit_rose_bloom" },
	"crystal_lotus":       { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_crystal_lotus_bloom" },
	"fire_tulip":          { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_fire_tulip_bloom" },
	"silver_anthurium":    { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_silver_anthurium_bloom" },
	"jade_periwinkle":     { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_jade_periwinkle_bloom" },
	"star_sunflower":      { "stages": [[0, 0], [1, 120], [2, 320], [3, 600]], "harvest_id": "harvest_star_sunflower_bloom" },
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
	t.sort_stages()

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
