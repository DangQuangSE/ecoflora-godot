class_name UserProfile
extends RefCounted

var level: int = 1
var current_xp: int = 0
var total_xp_earned: int = 0
var harvest_count: int = 0

func xp_to_next_level() -> int:
	return 200 * level

func add_xp(amount: int) -> Array[int]:
	if amount <= 0:
		push_warning("UserProfile.add_xp: amount must be > 0, got %d" % amount)
		return []
	current_xp += amount
	total_xp_earned += amount
	var crossed: Array[int] = []
	while true:
		var threshold := xp_to_next_level()
		if current_xp < threshold:
			break
		current_xp -= threshold
		level += 1
		crossed.append(level)
	return crossed
