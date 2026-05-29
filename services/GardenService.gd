class_name GardenService
extends RefCounted

# Parses BE GardenStateDto `plots` array into Plot domain objects.
# templates must be keyed by UUID string (populated from BE flower-template catalog).
func parse_plots(arr: Array, templates: Dictionary) -> Array[Plot]:
	var result: Array[Plot] = []
	for item: Variant in arr:
		if not item is Dictionary:
			continue
		var d: Dictionary = item
		var plot := Plot.new(
			str(d.get("plotId", "")),
			"",
			int(d.get("plotIndex", 0))
		)
		var pf_json: Variant = d.get("plantedFlower", null)
		if pf_json is Dictionary:
			var flower: PlantedFlower = parse_planted_flower(pf_json, templates)
			if flower != null:
				plot.plant(flower)
		result.append(plot)
	return result

# Maps a BE PlantedFlowerDto JSON to a PlantedFlower domain object.
# Returns null if flowerTemplateId is not found in templates — caller skips the plant.
func parse_planted_flower(json: Dictionary, templates: Dictionary) -> PlantedFlower:
	var template_id: String = str(json.get("flowerTemplateId", ""))
	if not templates.has(template_id):
		push_error("GardenService.parse_planted_flower: unknown flowerTemplateId '%s'" % template_id)
		return null
	var template: FlowerTemplate = templates[template_id]

	var flower := PlantedFlower.new(template_id, "")
	flower.id            = str(json.get("id", flower.id))
	flower.current_xp    = int(json.get("currentXp", 0))
	flower.current_stage = template.compute_stage_for_xp(flower.current_xp)

	flower.last_watered_at    = _parse_iso_to_unix(str(json.get("lastWateredAt", "")))
	flower.last_fertilized_at = _parse_iso_to_unix(str(json.get("lastFertilizedAt", "")))
	flower.planted_at         = _parse_iso_to_unix(str(json.get("plantedAt", "")))
	return flower

func _parse_iso_to_unix(s: String) -> int:
	if s.is_empty() or s == "null":
		return 0
	return int(Time.get_unix_time_from_datetime_string(s))
