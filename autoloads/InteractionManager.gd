extends Node

signal plot_action_requested(plot_id: String, action: String, data: Dictionary)
signal show_flower_info(plot_id: String)
signal harvest_mode_changed(active: bool)

var _harvest_mode: bool = false

func _ready() -> void:
	UserManager.login_required.connect(func(): _set_harvest_mode(false))

func is_harvest_mode() -> bool:
	return _harvest_mode

func toggle_harvest_mode() -> void:
	_set_harvest_mode(!_harvest_mode)

func _set_harvest_mode(active: bool) -> void:
	if _harvest_mode == active:
		return
	_harvest_mode = active
	if active:
		InventoryManager.deselect()
	harvest_mode_changed.emit(_harvest_mode)

func request_plot_action(plot_id: String, action: String, data: Dictionary = {}) -> void:
	plot_action_requested.emit(plot_id, action, data)

func request_show_flower_info(plot_id: String) -> void:
	show_flower_info.emit(plot_id)
