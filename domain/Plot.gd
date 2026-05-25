class_name Plot
extends RefCounted

var id: String
var garden_id: String
var plot_index: int
var is_occupied: bool = false
var is_pending_sync: bool = false
var current_plant: PlantedFlower = null


func _init(p_id: String = "", p_garden_id: String = "", p_index: int = 0) -> void:
	id = p_id
	garden_id = p_garden_id
	plot_index = p_index


func plant(flower: PlantedFlower) -> void:
	is_occupied = true
	current_plant = flower


func clear() -> void:
	is_occupied = false
	current_plant = null


func deep_copy() -> Plot:
	var copy := Plot.new(id, garden_id, plot_index)
	copy.is_occupied = is_occupied
	copy.is_pending_sync = is_pending_sync
	copy.current_plant = current_plant.deep_copy() if current_plant else null
	return copy
