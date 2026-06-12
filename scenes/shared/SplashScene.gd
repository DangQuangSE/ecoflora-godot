extends Control

func _ready() -> void:
	var loading_screen = get_node_or_null("/root/LoadingScreen")
	if loading_screen:
		# Yêu cầu LoadingScreen nạp bất đồng bộ LoginScene
		loading_screen.load_scene_async("res://scenes/auth/LoginScene.tscn")
	else:
		# Fallback phòng hờ trường hợp không tìm thấy autoload LoadingScreen
		get_tree().change_scene_to_file("res://scenes/auth/LoginScene.tscn")
