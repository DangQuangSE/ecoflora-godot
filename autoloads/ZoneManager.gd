extends Node

signal zone_notification(zone_id: String)
signal zone_unlocked(zone_id: String)

enum ZoneState { LOCKED, NOTIFIED, UNLOCKED }

var _zones: Array[ZoneDefinition] = []
var _states: Dictionary = {}

func _ready() -> void:
	_zones = [
		ZoneDefinition.create("zone_1", 3,
			["plot_8", "plot_9", "plot_10", "plot_11"],
			Vector2(360.0, 80.0)),
		ZoneDefinition.create("zone_2", 6,
			["plot_12", "plot_13", "plot_14", "plot_15"],
			Vector2(360.0, 320.0)),
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

func init_from_server(zones_arr: Array) -> void:
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
		_zones.append(ZoneDefinition.create(zone_id, required_level, plot_ids, Vector2.ZERO))
		_states[zone_id] = ZoneState.UNLOCKED if is_unlocked else ZoneState.LOCKED
