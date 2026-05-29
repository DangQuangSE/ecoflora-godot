class_name UserService
extends RefCounted

# Parses GET /api/auth/profile response (already unwrapped by HttpHelper) into UserProfile.
func parse_profile(data: Dictionary) -> UserProfile:
	if data.is_empty():
		push_warning("UserService.parse_profile: empty data")
		return UserProfile.new()
	var p := UserProfile.new()
	p.level      = int(data.get("level", 1))
	p.currency   = int(data.get("currency", 0))
	p.current_xp = int(data.get("currentXp", 0))
	return p
