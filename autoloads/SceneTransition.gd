extends CanvasLayer

const ALLOWED_SCENES: Array[String] = [
	"res://scenes/auth/LoginScene.tscn",
	"res://scenes/auth/RegisterScene.tscn",
	"res://scenes/garden/GardenScene.tscn",
	"res://scenes/school/SchoolScene.tscn",
	"res://scenes/school/ClassroomScene.tscn",
]

var _spawn_origin: String = ""

var _overlay: ColorRect
var _is_transitioning: bool = false

func set_spawn_origin(origin: String) -> void:
	_spawn_origin = origin

func is_transitioning() -> bool:
	return _is_transitioning

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	UserManager.login_required.connect(_on_login_required)

func fade_to(scene_path: String) -> void:
	if _is_transitioning:
		return
	if scene_path not in ALLOWED_SCENES:
		push_error("SceneTransition.fade_to: path not in allowlist: %s" % scene_path)
		return
	_is_transitioning = true
	
	var is_auth_scene := scene_path.contains("LoginScene") or scene_path.contains("RegisterScene")
	if not is_auth_scene and AudioManager.get_current_bgm_path() == "res://sounds/lobby_v2.mp3":
		AudioManager.stop_bgm(0.3)
	
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
		AudioManager.update_bgm_for_weather_state()
		await _fade_out()
		
	_is_transitioning = false

func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.3)
	await tween.finished

## Call from each scene's _ready() to spawn player near the portal they came from.
## Pass the root node to search for Portal children.
func apply_spawn_origin(scene_root: Node, player: Player) -> void:
	if _spawn_origin.is_empty():
		return
	for child in scene_root.get_children():
		var portal := child as Portal
		if portal != null and portal.target_scene == _spawn_origin:
			player.global_position = portal.global_position + portal.spawn_offset
			break
	_spawn_origin = ""

func force_clear() -> void:
	_overlay.color.a = 0.0
	_is_transitioning = false

func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.3)
	await tween.finished

func _on_login_required() -> void:
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://scenes/auth/LoginScene.tscn":
		return
	var loading_screen = get_node_or_null("/root/LoadingScreen")
	if loading_screen:
		loading_screen.load_scene_async("res://scenes/auth/LoginScene.tscn")
	else:
		fade_to("res://scenes/auth/LoginScene.tscn")
