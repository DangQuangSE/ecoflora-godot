class_name Portal
extends Area2D

@export var target_scene: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if target_scene.is_empty():
		push_warning("Portal: target_scene is empty")
		return
	if SceneTransition.is_transitioning():
		return
	SceneTransition.fade_to(target_scene)
