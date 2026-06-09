extends Node

signal zone_notification(zone_id: String)
signal zone_unlocked(zone_id: String)

enum ZoneState { LOCKED, NOTIFIED, UNLOCKED }

var _zones: Array[ZoneDefinition] = []
var _states: Dictionary = {}

func _ready() -> void:
	_zones = [
		ZoneDefinition.create("zone_2", 9,
			["plot_16","plot_17","plot_18","plot_19","plot_20","plot_21","plot_22","plot_23"],
			Vector2(-324.0, 843.0)),
		ZoneDefinition.create("zone_3", 12,
			["plot_24","plot_25","plot_26","plot_27","plot_28","plot_29","plot_30","plot_31"],
			Vector2(-324.0, 1285.0)),
		ZoneDefinition.create("zone_4", 15,
			["plot_32","plot_33","plot_34","plot_35","plot_36","plot_37","plot_38","plot_39"],
			Vector2(-324.0, 1727.0)),
		ZoneDefinition.create("zone_5", 18,
			["plot_40","plot_41","plot_42","plot_43","plot_44","plot_45","plot_46","plot_47"],
			Vector2(-324.0, 2169.0)),
		ZoneDefinition.create("zone_6", 21,
			["plot_48","plot_49","plot_50","plot_51","plot_52","plot_53","plot_54","plot_55"],
			Vector2(-324.0, 2611.0)),
	]
	for z: ZoneDefinition in _zones:
		_states[z.zone_id] = ZoneState.LOCKED
	UserManager.level_up.connect(_on_level_up)

func _on_level_up(new_level: int) -> void:
	for z: ZoneDefinition in _zones:
		if _states[z.zone_id] == ZoneState.LOCKED and new_level >= z.required_level:
			_states[z.zone_id] = ZoneState.NOTIFIED
			zone_notification.emit(z.zone_id)

func request_unlock(zone_id: String) -> void:
	if _states.get(zone_id, ZoneState.LOCKED) != ZoneState.NOTIFIED:
		return
	_states[zone_id] = ZoneState.UNLOCKED
	zone_unlocked.emit(zone_id)

func is_plot_locked(plot_id: String) -> bool:
	for z: ZoneDefinition in _zones:
		if plot_id in z.plot_ids:
			return _states[z.zone_id] != ZoneState.UNLOCKED
	return false

func get_zone_state(zone_id: String) -> ZoneState:
	return _states.get(zone_id, ZoneState.LOCKED)

func get_all_zones() -> Array[ZoneDefinition]:
	return _zones

func get_zone(zone_id: String) -> ZoneDefinition:
	for z: ZoneDefinition in _zones:
		if z.zone_id == zone_id:
			return z
	return null

func init_from_server(zones_arr: Array) -> void:
	var pos_map: Dictionary = {}
	for z: ZoneDefinition in _zones:
		pos_map[z.zone_id] = z.world_position
	_zones.clear()
	_states.clear()
	for z in zones_arr:
		if not z is Dictionary:
			continue
		var zone_id: String = z.get("zoneId", "")
		var is_unlocked: bool = z.get("isUnlocked", false)
		var required_level: int = z.get("requiredLevel", 1)
		var raw_ids: Array = z.get("plotIds", [])
		if zone_id.is_empty() or raw_ids.is_empty():
			continue
		var plot_ids: Array[String] = []
		for pid in raw_ids:
			plot_ids.append(str(pid))
		var pos: Vector2 = pos_map.get(zone_id, Vector2.ZERO)
		_zones.append(ZoneDefinition.create(zone_id, required_level, plot_ids, pos))
		_states[zone_id] = ZoneState.UNLOCKED if is_unlocked else ZoneState.LOCKED
	for z: ZoneDefinition in _zones:
		if _states[z.zone_id] == ZoneState.UNLOCKED:
			zone_unlocked.emit(z.zone_id)
