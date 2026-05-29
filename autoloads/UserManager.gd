extends Node

const _TokenStoreScript   = preload("res://services/TokenStore.gd")
const _AuthServiceScript  = preload("res://services/AuthService.gd")
const _UserServiceScript  = preload("res://services/UserService.gd")

signal xp_gained(amount: int)
signal level_up(new_level: int)
signal login_required
signal login_succeeded
signal login_failed(reason: String)

@export var use_mock: bool = false
@export var base_url: String = "https://localhost:7034"

const _XP_TABLE: Dictionary = {
	"harvest_lotus_bloom":      80,
	"harvest_rose_bloom":       120,
	"harvest_periwinkle_bloom": 60,
	"harvest_sunflower_bloom":  100,
	"harvest_daisy_bloom":      70,
	"harvest_tulip_bloom":      90,
}

var _profile: UserProfile = UserProfile.new()
var _token_store  # TokenStore
var _auth_service  # AuthService
var _user_service  # UserService
var _http: HTTPRequest
var _http_profile: HTTPRequest
var _request_in_flight: bool = false
var _profile_in_flight: bool = false

func _ready() -> void:
	_token_store  = _TokenStoreScript.new()
	_auth_service = _AuthServiceScript.new()
	_user_service = _UserServiceScript.new()

	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)

	_http_profile = HTTPRequest.new()
	_http_profile.timeout = 10.0
	add_child(_http_profile)

	if not use_mock and not base_url.begins_with("https://"):
		push_warning("UserManager: base_url is HTTP — tokens transmitted in plaintext")

	GardenManager.harvest_completed.connect(_on_harvest_completed)

func is_logged_in() -> bool:
	return use_mock or not _token_store.access_token.is_empty()

func get_access_token() -> String:
	if use_mock:
		return "mock_token"
	return _token_store.access_token if _token_store else ""

func get_auth_header() -> String:
	if use_mock:
		return "Authorization: Bearer mock_token"
	if _token_store.access_token.is_empty():
		return ""
	return "Authorization: Bearer %s" % _token_store.access_token

func login_async(account: String, password: String) -> bool:
	if use_mock:
		login_succeeded.emit()
		return true

	if _request_in_flight:
		push_warning("UserManager.login_async: request already in flight")
		return false

	var body: String = _auth_service.build_login_body(account, password)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	_request_in_flight = true

	var error: int = _http.request(
		base_url + "/api/auth/login",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_request_in_flight = false
		push_warning("UserManager.login_async: HTTPRequest.request() failed — %d" % error)
		return false

	var raw: Variant = await _http.request_completed
	_request_in_flight = false

	var http_result: int = raw[0]
	var status_code: int = raw[1]
	var body_bytes: PackedByteArray = raw[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		push_warning("UserManager.login_async: network error %d" % http_result)
		login_failed.emit("Lỗi kết nối. Kiểm tra mạng và thử lại.")
		return false

	if status_code == 401 or status_code == 403:
		login_failed.emit("Tài khoản hoặc mật khẩu không đúng.")
		return false

	if status_code == 400:
		var msg: String = _parse_error_message(body_bytes)
		login_failed.emit(msg if msg else "Thông tin đăng nhập không hợp lệ.")
		return false

	if status_code != 200:
		login_failed.emit("Lỗi máy chủ (%d). Vui lòng thử lại sau." % status_code)
		return false

	var json := JSON.new()
	if json.parse(body_bytes.get_string_from_utf8()) != OK:
		push_warning("UserManager.login_async: JSON parse error")
		login_failed.emit("Phản hồi không hợp lệ từ máy chủ.")
		return false

	var data: Variant = json.get_data()
	if not data is Dictionary:
		login_failed.emit("Phản hồi không hợp lệ từ máy chủ.")
		return false

	var tokens: Dictionary = _auth_service.parse_login_response(data)
	if tokens.is_empty():
		login_failed.emit("Đăng nhập thất bại.")
		return false

	_token_store.access_token = tokens["accessToken"]
	_token_store.save_refresh_token(tokens["refreshToken"])
	if not use_mock:
		fetch_profile_async()
	login_succeeded.emit()
	return true

func fetch_profile_async() -> void:
	if use_mock or _profile_in_flight:
		return
	_profile_in_flight = true
	var headers: PackedStringArray = HttpHelper.make_headers(
		_token_store.access_token if _token_store else "")
	var error: int = _http_profile.request(base_url + "/api/auth/profile", headers)
	if error != OK:
		_profile_in_flight = false
		push_warning("UserManager.fetch_profile_async: request error %d" % error)
		return
	var raw: Variant = await _http_profile.request_completed
	_profile_in_flight = false
	var status_code: int    = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code == 401:
		handle_401()
		return
	if status_code != 200:
		push_warning("UserManager.fetch_profile_async: HTTP %d" % status_code)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("UserManager.fetch_profile_async: JSON parse error")
		return
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if not data is Dictionary:
		return
	var old_level: int = _profile.level
	_profile = _user_service.parse_profile(data)
	xp_gained.emit(0)  # Trigger HUD refresh
	if _profile.level != old_level:
		level_up.emit(_profile.level)

func handle_401() -> void:
	_token_store.access_token = ""
	login_required.emit()

func logout() -> void:
	_token_store.clear()
	login_required.emit()

func get_profile() -> UserProfile:
	return _profile

func _on_harvest_completed(_plot_id: String, product_id: String) -> void:
	if not _XP_TABLE.has(product_id):
		push_warning("UserManager: unknown product_id '%s'" % product_id)
		return
	var xp: int = _XP_TABLE[product_id]
	_profile.harvest_count += 1
	var crossed := _profile.add_xp(xp)
	xp_gained.emit(xp)
	for new_level: int in crossed:
		level_up.emit(new_level)

func _parse_error_message(body: PackedByteArray) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return ""
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return ""
	return str((data as Dictionary).get("message", ""))

func _exit_tree() -> void:
	if _request_in_flight:
		_http.cancel_request()
		_request_in_flight = false
	if _profile_in_flight:
		_http_profile.cancel_request()
		_profile_in_flight = false
