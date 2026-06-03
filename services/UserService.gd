class_name UserService
extends RefCounted

# Parses GET /api/auth/profile response (already unwrapped by HttpHelper) into UserProfile.
func parse_profile(data: Dictionary) -> UserProfile:
	if data.is_empty():
		push_warning("UserService.parse_profile: empty data")
		return UserProfile.new()
	var p := UserProfile.new()
	var total_xp: int = int(data.get("currentXp", 0))
	var lvl: int = int(data.get("level", 1))
	p.level      = lvl
	p.currency   = int(data.get("currency", 0))
	# Convert cumulative total XP to within-level XP for HUD bar display
	var level_start: int = UserProfile.get_level_start_xp(lvl)
	p.current_xp = total_xp - level_start
	# Parse vitalityReadyAt ISO string → unix timestamp
	var vitality_str: String = str(data.get("vitalityReadyAt", ""))
	if vitality_str != "" and vitality_str != "null":
		p.vitality_ready_at = _parse_iso_to_unix(vitality_str)
	return p

func _parse_iso_to_unix(iso: String) -> int:
	var dt := Time.get_datetime_dict_from_datetime_string(iso, true)
	if dt.is_empty():
		return 0
	return Time.get_unix_time_from_datetime_dict(dt)
