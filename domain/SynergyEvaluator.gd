class_name SynergyEvaluator
extends RefCounted

static func evaluate_zone(
		zone_plot_indices: Array[int],
		plots_by_index: Dictionary,
		templates: Dictionary) -> Dictionary:
	var occupied_synergy_ids: Array[String] = []
	var template_ids: Dictionary = {}
	for idx: int in zone_plot_indices:
		var plot: Plot = plots_by_index.get(idx, null)
		if plot == null or not plot.is_occupied or plot.current_plant == null:
			continue
		var template: FlowerTemplate = templates.get(plot.current_plant.flower_template_id, null)
		if template == null:
			return {"active": false, "synergy_id": "", "xp_plus": 0, "synergy_name": ""}
		var sid: String = template.synergy_id
		if sid.is_empty():
			return {"active": false, "synergy_id": "", "xp_plus": 0, "synergy_name": ""}
		occupied_synergy_ids.append(sid)
		template_ids[plot.current_plant.flower_template_id] = true

	if occupied_synergy_ids.size() < 2:
		return {"active": false, "synergy_id": "", "xp_plus": 0, "synergy_name": ""}

	if template_ids.size() < 2:
		return {"active": false, "synergy_id": "", "xp_plus": 0, "synergy_name": ""}

	var first: String = occupied_synergy_ids[0]
	for sid: String in occupied_synergy_ids:
		if sid != first:
			return {"active": false, "synergy_id": "", "xp_plus": 0, "synergy_name": ""}

	return {
		"active": true,
		"synergy_id": first,
		"xp_plus": 0,
		"synergy_name": "",
	}


static func get_bonus_for_plot(
		plot_index: int,
		plots_by_index: Dictionary,
		templates: Dictionary,
		synergy_cache: Dictionary) -> int:
	var zone_id: String = ZonePlotMap.get_zone_id_for_plot_index(plot_index)
	if zone_id.is_empty():
		return 0
	var indices: Array[int] = ZonePlotMap.get_plot_indices_for_zone(zone_id)
	var result: Dictionary = evaluate_zone(indices, plots_by_index, templates)
	if not result.get("active", false):
		return 0
	var synergy_id: String = str(result.get("synergy_id", ""))
	if synergy_id.is_empty():
		return 0
	var entry: Variant = synergy_cache.get(synergy_id, null)
	if entry is Dictionary:
		return int((entry as Dictionary).get("xp_plus", 0))
	return 0


static func evaluate_zone_with_cache(
		zone_plot_indices: Array[int],
		plots_by_index: Dictionary,
		templates: Dictionary,
		synergy_cache: Dictionary) -> Dictionary:
	var result: Dictionary = evaluate_zone(zone_plot_indices, plots_by_index, templates)
	if not result.get("active", false):
		return result
	var synergy_id: String = str(result.get("synergy_id", ""))
	var entry: Variant = synergy_cache.get(synergy_id, null)
	if entry is Dictionary:
		var d: Dictionary = entry as Dictionary
		result["xp_plus"] = int(d.get("xp_plus", 0))
		result["synergy_name"] = str(d.get("name", ""))
	return result
