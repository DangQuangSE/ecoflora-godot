extends CanvasLayer

signal loading_completed

const TIPS: Array[String] = [
	"Mẹo: Hoàn thành nhiệm vụ mỗi ngày để nhận nhiều phần thưởng nhé!",
	"Mẹo: Tưới nước cho cây thường xuyên giúp cây mau lớn hơn.",
	"Mẹo: Sử dụng phân bón để tăng nhanh điểm kinh nghiệm cho cây.",
	"Mẹo: Hãy chú ý thời tiết, một số loại cây sẽ phát triển nhanh hơn dưới mưa.",
	"Mẹo: Ghé thăm trường học để tham gia các lớp học về môi trường.",
	"Mẹo: Bán hoa đã thu hoạch trong cửa hàng để lấy thêm tiền xu.",
	"Mẹo: Nhớ thu hoạch hoa khi chúng nở rộ để không bị lãng phí nhé."
]

@onready var main_container: Control = $MainContainer
@onready var fill_container: Control = $MainContainer/ProgressBarContainer/FillContainer
@onready var left_pill: TextureRect = $MainContainer/ProgressBarContainer/FillContainer/LeftPill
@onready var mid_pill: TextureRect = $MainContainer/ProgressBarContainer/FillContainer/MidPill
@onready var right_pill: TextureRect = $MainContainer/ProgressBarContainer/FillContainer/RightPill
@onready var percent_label: Label = $MainContainer/ProgressBarContainer/Badge/Label
@onready var tip_label: Label = $MainContainer/TipLabel

var _target_scene: String = ""
var _is_loading_scene: bool = false
var _progress_array: Array = []
var _fade_tween: Tween
var _tip_timer: Timer

func _ready() -> void:
	# Đặt lớp hiển thị cao, dưới SceneTransition (128)
	layer = 120
	visible = false
	set_process(false)
	set_progress(0.0)
	
	# Khởi tạo Timer đổi mẹo liên tục
	_tip_timer = Timer.new()
	_tip_timer.wait_time = 3.0
	_tip_timer.timeout.connect(_show_random_tip)
	add_child(_tip_timer)

func _process(_delta: float) -> void:
	if not _is_loading_scene:
		return
		
	var status: int = ResourceLoader.load_threaded_get_status(_target_scene, _progress_array)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress_val: float = _progress_array[0] if _progress_array.size() > 0 else 0.0
			set_progress(progress_val)
		ResourceLoader.THREAD_LOAD_LOADED:
			set_progress(1.0)
			_is_loading_scene = false
			set_process(false)
			_on_load_finished()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: Nạp tài nguyên thất bại: %s" % _target_scene)
			_is_loading_scene = false
			set_process(false)
			hide_loading()

func set_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 1.0)
	var max_w: float = 1390.0
	var current_w := progress * max_w
	
	fill_container.size.x = current_w
	fill_container.visible = current_w > 0
	
	if current_w > 0:
		# Tính chiều rộng phần thân gỗ (mid-pill)
		var mid_w := maxf(0.0, current_w - 75.0 - 74.0)
		mid_pill.size.x = mid_w
		
		# Cập nhật vị trí phần đuôi gỗ (right-pill)
		right_pill.position.x = 75.0 + mid_w
		
	# Cập nhật phần trăm chữ
	var percent := int(progress * 100.0)
	percent_label.text = "%d%%" % percent

func _show_random_tip() -> void:
	if TIPS.size() > 0:
		var new_tip := TIPS[randi() % TIPS.size()]
		# Tránh trùng lặp mẹo đang hiển thị
		while new_tip == tip_label.text and TIPS.size() > 1:
			new_tip = TIPS[randi() % TIPS.size()]
		tip_label.text = new_tip

func show_loading() -> void:
	# Chế độ API loading (vô định hình)
	_is_loading_scene = false
	set_process(false)
	set_progress(0.0)
	percent_label.text = "..."
	_show_random_tip()
	
	if visible and main_container.modulate.a >= 0.99:
		_tip_timer.start()
		return
		
	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	_fade_tween = create_tween()
	main_container.modulate.a = 0.0
	_fade_tween.tween_property(main_container, "modulate:a", 1.0, 0.25)
	
	_tip_timer.start()

func hide_loading() -> void:
	_tip_timer.stop()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	_fade_tween = create_tween()
	_fade_tween.tween_property(main_container, "modulate:a", 0.0, 0.25)
	await _fade_tween.finished
	visible = false

func load_scene_async(scene_path: String) -> void:
	_target_scene = scene_path
	_is_loading_scene = true
	_progress_array.clear()
	set_progress(0.0)
	_show_random_tip()
	
	if not visible or main_container.modulate.a < 0.99:
		visible = true
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
			
		_fade_tween = create_tween()
		main_container.modulate.a = 0.0
		_fade_tween.tween_property(main_container, "modulate:a", 1.0, 0.25)
		await _fade_tween.finished
	
	var err := ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("LoadingScreen: Không thể yêu cầu nạp đa luồng cho: %s" % scene_path)
		hide_loading()
		return
		
	_tip_timer.start()
	set_process(true)

func _on_load_finished() -> void:
	# Đợi một chút để người chơi kịp nhìn thấy 100% (mượt mà hơn)
	await get_tree().create_timer(0.4).timeout
	
	var loaded_resource := ResourceLoader.load_threaded_get(_target_scene)
	if loaded_resource:
		get_tree().change_scene_to_packed(loaded_resource)
		loading_completed.emit()
	
	await hide_loading()
