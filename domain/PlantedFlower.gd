class_name PlantedFlower
extends RefCounted

static var _counter: int = 0

var id: String
var flower_template_id: String
var user_id: String
var current_xp: int = 0
var current_stage: int = 1
var planted_at: int = 0
var last_watered_at: int = 0
var last_fertilized_at: int = 0

func _init(template_id: String = "", uid: String = "") -> void:
	PlantedFlower._counter += 1
	id                 = "%d_%d" % [Time.get_ticks_usec(), PlantedFlower._counter]
	flower_template_id = template_id
	user_id            = uid
	planted_at = int(Time.get_unix_time_from_system())

func deep_copy() -> PlantedFlower:
	var copy := PlantedFlower.new()
	copy.id                 = id
	copy.flower_template_id = flower_template_id
	copy.user_id            = user_id
	copy.current_xp         = current_xp
	copy.current_stage      = current_stage
	copy.planted_at         = planted_at
	copy.last_watered_at    = last_watered_at
	copy.last_fertilized_at = last_fertilized_at
	return copy
