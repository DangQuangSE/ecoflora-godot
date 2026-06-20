class_name LockInfoPopup
extends CanvasLayer

func _init() -> void:
	layer = 12

func show_locked(required_level: int) -> void:
	Toast.show_message(self, "Cần đạt Level %d để mở khóa khu vực này!" % required_level, 2.8)
	queue_free()
