class_name UserProfile
extends RefCounted

# Cumulative XP thresholds to reach each level (index = level number)
# Matches LevelHelper.cs in eco-backend exactly
const LEVEL_THRESHOLDS: Array[int] = [0, 0, 500, 1500, 3000, 5000, 8000, 12000]
const MAX_LEVEL: int = 7

var level: int = 1
var currency: int = 0
var current_xp: int = 0     # within-level XP for HUD bar display
var total_xp_earned: int = 0
var harvest_count: int = 0
var vitality_ready_at: int = 0  # unix timestamp; 0 = ready to claim

# XP needed to go from current level to the next (for HUD bar max value)
func xp_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 1
	return LEVEL_THRESHOLDS[level + 1] - LEVEL_THRESHOLDS[level]

static func get_level_start_xp(lvl: int) -> int:
	if lvl >= 0 and lvl < LEVEL_THRESHOLDS.size():
		return LEVEL_THRESHOLDS[lvl]
	return 0

func is_vitality_ready() -> bool:
	return vitality_ready_at == 0 or vitality_ready_at <= int(Time.get_unix_time_from_system())

# Mock mode only — BE mode sets XP via UserManager.apply_server_xp()
func add_xp(amount: int) -> Array[int]:
	if amount <= 0:
		push_warning("UserProfile.add_xp: amount must be > 0, got %d" % amount)
		return []
	current_xp += amount
	total_xp_earned += amount
	var crossed: Array[int] = []
	while level < MAX_LEVEL:
		var needed := xp_to_next_level()
		if current_xp < needed:
			break
		current_xp -= needed
		level += 1
		crossed.append(level)
	return crossed
