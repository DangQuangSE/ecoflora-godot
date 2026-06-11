class_name LockInfoPopup
extends CanvasLayer

func _init() -> void:
	layer = 12

# Hiển thị thông tin khu vực bị khóa sử dụng BaseDialog mới
func show_locked(required_level: int) -> void:
	var message := "Cần đạt Level %d\nđể mở khóa khu vực này!" % required_level
	var dialog := BaseDialog.show_alert(self, "Khu vực bị khóa", message, "OK")
	if dialog:
		dialog.tree_exited.connect(queue_free)
	else:
		queue_free()
