extends Node

const GLOBAL_THEME_PATH := "res://themes/GlobalTheme.tres"

var global_theme: Theme = preload(GLOBAL_THEME_PATH)

func get_global_theme() -> Theme:
	return global_theme

func apply_to_control(control: Control) -> void:
	if control == null:
		return
	control.theme = global_theme

func apply_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		(root as Control).theme = global_theme
	for child in root.get_children():
		apply_to_tree(child)

func clear_from_control(control: Control) -> void:
	if control == null:
		return
	if control.theme == global_theme:
		control.theme = null
