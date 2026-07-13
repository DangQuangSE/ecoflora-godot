extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var retry_button: Button = $VBoxContainer/RetryButton
@onready var version_request: HTTPRequest = $VersionRequest
@onready var download_request: HTTPRequest = $DownloadRequest

# URL trỏ tới file version.json trên GitHub (có thể dùng GitHub Pages hoặc raw URL)
# Ví dụ: "https://raw.githubusercontent.com/YourName/YourRepo/main/version.json"
const VERSION_URL = "https://raw.githubusercontent.com/YOUR_ACCOUNT/YOUR_REPO/main/version.json" 

const PCK_LOCAL_PATH = "user://assets.pck"
const VERSION_LOCAL_PATH = "user://version.json"
const MAIN_SCENE = "res://scenes/shared/SplashScene.tscn"

var latest_version_code: int = 0
var latest_pck_url: String = ""
var is_downloading: bool = false

func _ready() -> void:
	retry_button.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	version_request.request_completed.connect(_on_version_request_completed)
	download_request.request_completed.connect(_on_download_request_completed)
	
	download_request.download_file = PCK_LOCAL_PATH
	
	check_version()

func _process(_delta: float) -> void:
	if is_downloading and download_request.get_body_size() > 0:
		var downloaded = download_request.get_downloaded_bytes()
		var total = download_request.get_body_size()
		progress_bar.max_value = total
		progress_bar.value = downloaded

func check_version() -> void:
	status_label.text = "Đang kiểm tra dữ liệu hệ thống..."
	progress_bar.hide()
	retry_button.hide()
	
	var error = version_request.request(VERSION_URL)
	if error != OK:
		_show_error("Lỗi mạng khi kiểm tra cập nhật.")

func _on_version_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Nếu không thể gọi version.json (do sai link hoặc rớt mạng)
		# Tạm thời cứ thử load file PCK cũ nếu có để người chơi vẫn vào được game offline
		print("Version check failed, falling back to local PCK.")
		_mount_and_start()
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY or not json.has("version_code") or not json.has("pck_url"):
		_show_error("Dữ liệu cập nhật không hợp lệ.")
		return
		
	latest_version_code = int(json["version_code"])
	latest_pck_url = json["pck_url"]
	
	var local_version = _get_local_version()
	
	if latest_version_code > local_version:
		_start_download()
	else:
		_mount_and_start()

func _get_local_version() -> int:
	if not FileAccess.file_exists(VERSION_LOCAL_PATH):
		return 0
	var file = FileAccess.open(VERSION_LOCAL_PATH, FileAccess.READ)
	if not file:
		return 0
	var json = JSON.parse_string(file.get_as_text())
	if typeof(json) == TYPE_DICTIONARY and json.has("version_code"):
		return int(json["version_code"])
	return 0

func _start_download() -> void:
	status_label.text = "Đang tải dữ liệu đồ họa (PCK)..."
	progress_bar.show()
	progress_bar.value = 0
	is_downloading = true
	
	# Xóa file PCK cũ hoặc lỗi trước khi tải mới
	if FileAccess.file_exists(PCK_LOCAL_PATH):
		DirAccess.remove_absolute(PCK_LOCAL_PATH)
		
	var error = download_request.request(latest_pck_url)
	if error != OK:
		is_downloading = false
		_show_error("Lỗi khởi tạo tải dữ liệu.")

func _on_download_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_error("Lỗi tải dữ liệu. Vui lòng thử lại.")
		# Xóa file rác tải dở
		if FileAccess.file_exists(PCK_LOCAL_PATH):
			DirAccess.remove_absolute(PCK_LOCAL_PATH)
		return
		
	status_label.text = "Tải hoàn tất!"
	
	# Tải thành công mới cập nhật version.json dưới máy
	var file = FileAccess.open(VERSION_LOCAL_PATH, FileAccess.WRITE)
	if file:
		var data = {"version_code": latest_version_code}
		file.store_string(JSON.stringify(data))
		file.close()
		
	_mount_and_start()

func _mount_and_start() -> void:
	status_label.text = "Đang nạp vào hệ thống..."
	
	if FileAccess.file_exists(PCK_LOCAL_PATH):
		var success = ProjectSettings.load_resource_pack(PCK_LOCAL_PATH)
		if not success:
			_show_error("Không thể gắn dữ liệu. File có thể bị hỏng.")
			if FileAccess.file_exists(PCK_LOCAL_PATH):
				DirAccess.remove_absolute(PCK_LOCAL_PATH)
			return
			
	get_tree().change_scene_to_file(MAIN_SCENE)

func _show_error(msg: String) -> void:
	status_label.text = msg
	progress_bar.hide()
	retry_button.show()

func _on_retry_pressed() -> void:
	check_version()
