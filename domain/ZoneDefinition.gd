class_name ZoneDefinition
extends RefCounted

var zone_id: String = ""
var required_level: int = 1
var plot_ids: Array[String] = []
var world_position: Vector2 = Vector2.ZERO

static func create(
		id: String,
		level_req: int,
		ids: Array[String],
		pos: Vector2) -> ZoneDefinition:
	var z := ZoneDefinition.new()
	z.zone_id = id
	z.required_level = level_req
	z.plot_ids = ids
	z.world_position = pos
	return z
