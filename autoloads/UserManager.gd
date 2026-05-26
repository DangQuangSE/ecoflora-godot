extends Node

signal xp_gained(amount: int)
signal level_up(new_level: int)

const _XP_TABLE: Dictionary = {
	"harvest_lotus_bloom":      80,
	"harvest_rose_bloom":       120,
	"harvest_periwinkle_bloom": 60,
}

var _profile: UserProfile = UserProfile.new()

func _ready() -> void:
	GardenManager.harvest_completed.connect(_on_harvest_completed)

func get_profile() -> UserProfile:
	return _profile

func _on_harvest_completed(_plot_id: String, product_id: String) -> void:
	if not _XP_TABLE.has(product_id):
		push_warning("UserManager: unknown product_id '%s'" % product_id)
		return
	var xp: int = _XP_TABLE[product_id]
	_profile.harvest_count += 1
	var crossed := _profile.add_xp(xp)
	xp_gained.emit(xp)
	for new_level: int in crossed:
		level_up.emit(new_level)
