extends Node

signal plot_action_requested(plot_id: String, action: String, data: Dictionary)
signal show_flower_info(plot_id: String)

func request_plot_action(plot_id: String, action: String, data: Dictionary = {}) -> void:
	plot_action_requested.emit(plot_id, action, data)

func request_show_flower_info(plot_id: String) -> void:
	show_flower_info.emit(plot_id)
