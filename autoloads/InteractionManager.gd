extends Node

enum CurrentMode { NONE, HARVEST, DIG_UP }

signal plot_action_requested(plot_id: String, action: String, data: Dictionary)
signal show_flower_info(plot_id: String)
signal harvest_mode_changed(active: bool)
signal dig_up_mode_changed(active: bool)

var _current_mode: int = CurrentMode.NONE

func _ready() -> void:
	UserManager.login_required.connect(func(): _set_current_mode(CurrentMode.NONE))

func is_harvest_mode() -> bool:
	return _current_mode == CurrentMode.HARVEST

func is_dig_up_mode() -> bool:
	return _current_mode == CurrentMode.DIG_UP

func is_in_action_mode() -> bool:
	return _current_mode != CurrentMode.NONE

func toggle_harvest_mode() -> void:
	_set_current_mode(CurrentMode.NONE if _current_mode == CurrentMode.HARVEST else CurrentMode.HARVEST)

func toggle_dig_up_mode() -> void:
	_set_current_mode(CurrentMode.NONE if _current_mode == CurrentMode.DIG_UP else CurrentMode.DIG_UP)

func exit_action_mode() -> void:
	_set_current_mode(CurrentMode.NONE)

func _set_current_mode(mode: int) -> void:
	if _current_mode == mode:
		return
	_current_mode = mode
	if mode != CurrentMode.NONE:
		InventoryManager.deselect()
	harvest_mode_changed.emit(_current_mode == CurrentMode.HARVEST)
	dig_up_mode_changed.emit(_current_mode == CurrentMode.DIG_UP)

func request_plot_action(plot_id: String, action: String, data: Dictionary = {}) -> void:
	plot_action_requested.emit(plot_id, action, data)

func request_show_flower_info(plot_id: String) -> void:
	show_flower_info.emit(plot_id)
