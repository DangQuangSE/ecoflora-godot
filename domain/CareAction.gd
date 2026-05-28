class_name CareAction
extends RefCounted

const PLANT     := "PLANT"
const WATER     := "WATER"
const FERTILIZE := "FERTILIZE"
const PESTICIDE := "PESTICIDE"
const HARVEST   := "HARVEST"

var action_id: String
var plot_id: String
var action_type: String
var reference_id: String
var timestamp: int

static var _counter: int = 0

func _init(pid: String = "", atype: String = "", ref_id: String = "") -> void:
	CareAction._counter += 1
	action_id    = "%d_%d" % [Time.get_ticks_usec(), CareAction._counter]
	plot_id      = pid
	action_type  = atype
	reference_id = ref_id
	timestamp    = int(Time.get_unix_time_from_system())
