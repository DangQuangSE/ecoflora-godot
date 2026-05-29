class_name UserService
extends RefCounted

# Parses GET /api/auth/profile response (already unwrapped by HttpHelper) into UserProfile.
# BE UserDto has Level and Currency but NO XP — current_xp stays Godot-local.
func parse_profile(data: Dictionary) -> UserProfile:
	if data.is_empty():
		push_warning("UserService.parse_profile: empty data")
		return UserProfile.new()
	var p := UserProfile.new()
	p.level    = int(data.get("level", 1))
	p.currency = int(data.get("currency", 0))
	# XP gap: BE has no XP field — keeping Godot-local XP tracking
	# TODO: request BE to add XP/total_xp field to UserDto
	push_warning("UserService.parse_profile: XP not available from BE — current_xp remains 0")
	return p
