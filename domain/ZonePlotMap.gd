class_name ZonePlotMap
extends RefCounted

const _ZONE_IDS: Array[String] = [
	"zone_0", "zone_1", "zone_2", "zone_3", "zone_4", "zone_5", "zone_6",
]
const _PLOTS_PER_ZONE := 8


static func get_zone_id_for_plot_index(plot_index: int) -> String:
	if plot_index < 0:
		return ""
	var zone_idx := plot_index / _PLOTS_PER_ZONE
	if zone_idx >= _ZONE_IDS.size():
		return ""
	return _ZONE_IDS[zone_idx]


static func get_plot_indices_for_zone(zone_id: String) -> Array[int]:
	var result: Array[int] = []
	var zone_idx := _ZONE_IDS.find(zone_id)
	if zone_idx < 0:
		return result
	var start := zone_idx * _PLOTS_PER_ZONE
	for i in range(_PLOTS_PER_ZONE):
		result.append(start + i)
	return result


static func get_all_zone_ids() -> Array[String]:
	return _ZONE_IDS.duplicate()
