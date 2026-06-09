extends CanvasLayer

const ALLOWED_SCENES: Array[String] = [
	"res://scenes/auth/LoginScene.tscn",
	"res://scenes/auth/RegisterScene.tscn",
	"res://scenes/garden/GardenScene.tscn",
	"res://scenes/school/SchoolScene.tscn",
]

var _overlay: ColorRect
var _is_transitioning: bool = false

func is_transitioning() -> bool:
	return _is_transitioning

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

func fade_to(scene_path: String) -> void:
	if _is_transitioning:
		return
	if scene_path not in ALLOWED_SCENES:
		push_error("SceneTransition.fade_to: path not in allowlist: %s" % scene_path)
		return
	_is_transitioning = true
	
	var is_heavy_scene := scene_path.contains("GardenScene") or scene_path.contains("SchoolScene")
	var loading_screen = get_node_or_null("/root/LoadingScreen")
	
	if is_heavy_scene and loading_screen:
		loading_screen.load_scene_async(scene_path)
		await loading_screen.loading_completed
	else:
		await _fade_in()
		get_tree().change_scene_to_file(scene_path)
		# Wait 2 frames: first processes deferred scene change,
		# second ensures new scene's _ready() has completed.
		await get_tree().process_frame
		await get_tree().process_frame
		await _fade_out()
		
	_is_transitioning = false

func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.3)
	await tween.finished

func force_clear() -> void:
	_overlay.color.a = 0.0
	_is_transitioning = false

func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.3)
	await tween.finished
