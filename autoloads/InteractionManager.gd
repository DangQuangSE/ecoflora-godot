extends Node

signal plot_action_requested(plot_id: String, action: String, data: Dictionary)

func request_plot_action(plot_id: String, action: String, data: Dictionary = {}) -> void:
	plot_action_requested.emit(plot_id, action, data)
