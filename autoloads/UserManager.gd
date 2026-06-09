extends Node

const _TokenStoreScript    = preload("res://services/TokenStore.gd")
const _AuthServiceScript   = preload("res://services/AuthService.gd")
const _UserServiceScript   = preload("res://services/UserService.gd")
const _VitalityServiceScript = preload("res://services/VitalityService.gd")
const _ShopServiceScript   = preload("res://services/ShopService.gd")

signal xp_gained(amount: int)
signal level_up(new_level: int)
signal currency_changed(new_amount: int)
signal vitality_ready()
signal vitality_claimed(reward_type: String, reward_amount: int)
signal login_required
signal login_succeeded
signal login_failed(reason: String)
signal register_succeeded
signal register_failed(reason: String)
signal profile_updated

@export var use_mock: bool = false
@export var base_url: String = "http://20.40.58.246:5000"

const _XP_TABLE: Dictionary = {
	"harvest_anthurium_bloom":         100,
	"harvest_lotus_bloom":             80,
	"harvest_periwinkle_bloom":        60,
	"harvest_purple_bellflower_bloom": 90,
	"harvest_rose_bloom":              120,
	"harvest_sun_flower_bloom":        110,
	"harvest_tulip_bloom":             70,
}

var _profile: UserProfile = UserProfile.new()
var _token_store  # TokenStore
var _auth_service  # AuthService
var _user_service  # UserService
var _vitality_service  # VitalityService
var _shop_service      # ShopService
var _http: HTTPRequest
var _http_register: HTTPRequest
var _http_profile: HTTPRequest
var _vitality_http: HTTPRequest
var _vitality_claim_http: HTTPRequest
var _shop_http: HTTPRequest
var _shop_purchase_http: HTTPRequest
var _vitality_poll_timer: Timer
var _avatar_http: HTTPRequest
var _rename_http: HTTPRequest
var _request_in_flight: bool = false
var _register_in_flight: bool = false
var _profile_in_flight: bool = false
var _profile_loaded: bool = false
var _claim_in_flight: bool = false
var _purchase_in_flight: bool = false
var _avatar_in_flight: bool = false
var _rename_in_flight: bool = false

var shop_open_tab: int = 0
var _registration_success_message: String = ""

func _ready() -> void:
	_token_store  = _TokenStoreScript.new()
	_auth_service = _AuthServiceScript.new()
	_user_service = _UserServiceScript.new()

	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)

	_http_register = HTTPRequest.new()
	_http_register.timeout = 10.0
	add_child(_http_register)

	_http_profile = HTTPRequest.new()
	_http_profile.timeout = 10.0
	add_child(_http_profile)

	_vitality_http = HTTPRequest.new()
	_vitality_http.timeout = 10.0
	add_child(_vitality_http)

	_vitality_claim_http = HTTPRequest.new()
	_vitality_claim_http.timeout = 10.0
	add_child(_vitality_claim_http)

	_shop_http = HTTPRequest.new()
	_shop_http.timeout = 15.0
	add_child(_shop_http)

	_shop_purchase_http = HTTPRequest.new()
	_shop_purchase_http.timeout = 10.0
	add_child(_shop_purchase_http)

	_avatar_http = HTTPRequest.new()
	_avatar_http.timeout = 10.0
	add_child(_avatar_http)

	_rename_http = HTTPRequest.new()
	_rename_http.timeout = 10.0
	add_child(_rename_http)

	_vitality_service = _VitalityServiceScript.new(_vitality_http, _vitality_claim_http)
	_shop_service = _ShopServiceScript.new(_shop_http, _shop_purchase_http)

	_profile.avatar_index = load_avatar_index()

	_vitality_poll_timer = Timer.new()
	_vitality_poll_timer.wait_time = 60.0
	_vitality_poll_timer.autostart = true
	_vitality_poll_timer.one_shot = false
	_vitality_poll_timer.timeout.connect(_poll_vitality_status)
	add_child(_vitality_poll_timer)

	if not use_mock and not base_url.begins_with("https://") \
			and not base_url.begins_with("http://localhost") \
			and not base_url.begins_with("http://127.") \
			and not base_url.begins_with("http://20.40.58.246"):
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

func take_registration_success_message() -> String:
	var msg := _registration_success_message
	_registration_success_message = ""
	return msg

func register_async(first_name: String, last_name: String,
		account: String, password: String) -> bool:
	if use_mock:
		_registration_success_message = "Đăng ký thành công."
		register_succeeded.emit()
		return true

	if _register_in_flight:
		push_warning("UserManager.register_async: request already in flight")
		return false

	var body: String = _auth_service.build_register_body(
		first_name, last_name, account, password)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	_register_in_flight = true

	var error: int = _http_register.request(
		base_url + "/api/auth/register",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_register_in_flight = false
		push_warning("UserManager.register_async: HTTPRequest.request() failed — %d" % error)
		return false

	var raw: Variant = await _http_register.request_completed
	_register_in_flight = false

	var http_result: int = raw[0]
	var status_code: int = raw[1]
	var body_bytes: PackedByteArray = raw[3]

	if http_result != HTTPRequest.RESULT_SUCCESS:
		push_warning("UserManager.register_async: network error %d" % http_result)
		register_failed.emit("Lỗi kết nối. Kiểm tra mạng và thử lại.")
		return false

	if status_code == 400:
		var msg: String = _parse_error_message(body_bytes)
		register_failed.emit(msg if msg else "Thông tin đăng ký không hợp lệ.")
		return false

	if status_code != 200:
		register_failed.emit("Lỗi máy chủ (%d). Vui lòng thử lại sau." % status_code)
		return false

	var json := JSON.new()
	if json.parse(body_bytes.get_string_from_utf8()) != OK:
		push_warning("UserManager.register_async: JSON parse error")
		register_failed.emit("Phản hồi không hợp lệ từ máy chủ.")
		return false

	var data: Variant = json.get_data()
	if not data is Dictionary:
		register_failed.emit("Phản hồi không hợp lệ từ máy chủ.")
		return false

	var success_msg: String = _auth_service.parse_register_success(data)
	if success_msg.is_empty():
		register_failed.emit("Đăng ký thất bại.")
		return false

	_registration_success_message = success_msg
	register_succeeded.emit()
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
	var local_idx := load_avatar_index()
	if local_idx > 0:
		_profile.avatar_index = local_idx
	xp_gained.emit(0)
	currency_changed.emit(_profile.currency)
	# Only emit level_up on subsequent syncs — initial load is not a real level-up event
	if _profile_loaded and _profile.level != old_level:
		level_up.emit(_profile.level)
	_profile_loaded = true
	profile_updated.emit()

func handle_401() -> void:
	_token_store.access_token = ""
	login_required.emit()

func logout() -> void:
	_token_store.clear()
	login_required.emit()

func get_profile() -> UserProfile:
	return _profile

func update_currency(new_total: int) -> void:
	_profile.currency = new_total
	currency_changed.emit(new_total)

func apply_server_xp(new_total_xp: int, new_level: int) -> void:
	if use_mock:
		push_warning("UserManager.apply_server_xp: ignored in mock mode — call add_harvest_xp instead")
		return
	var old_level: int = _profile.level
	var lvl := clampi(new_level, 1, UserProfile.MAX_LEVEL)
	_profile.current_xp = maxi(0, new_total_xp - UserProfile.get_level_start_xp(lvl))
	_profile.total_xp_earned = new_total_xp
	_profile.level = lvl
	xp_gained.emit(new_total_xp)
	if lvl != old_level:
		level_up.emit(lvl)

func add_harvest_xp(xp: int) -> void:
	var crossed := _profile.add_xp(xp)
	xp_gained.emit(xp)
	for new_level: int in crossed:
		level_up.emit(new_level)

func _on_harvest_completed(_plot_id: String, product_id: String) -> void:
	_profile.harvest_count += 1
	if not use_mock:
		profile_updated.emit()
		return
	if not _XP_TABLE.has(product_id):
		push_warning("UserManager: unknown product_id '%s'" % product_id)
		return
	add_harvest_xp(_XP_TABLE[product_id])

func request_vitality_status_async() -> void:
	await _poll_vitality_status()

func _poll_vitality_status() -> void:
	if use_mock or _token_store.access_token.is_empty():
		return
	var data: Dictionary = await _vitality_service.get_status_async(base_url, _token_store.access_token)
	if data.is_empty():
		return
	var seconds_until: int = int(data.get("secondsUntilReady", 0))
	_profile.vitality_ready_at = 0 if seconds_until <= 0 else int(Time.get_unix_time_from_system()) + seconds_until
	if _profile.is_vitality_ready():
		vitality_ready.emit()

func get_shop_catalog_async(category: String = "") -> Array[ShopItem]:
	if use_mock:
		return []
	return await _shop_service.get_catalog_async(base_url, _token_store.access_token, category)

func claim_vitality_async() -> void:
	if use_mock:
		if _profile.is_vitality_ready():
			_profile.vitality_ready_at = int(Time.get_unix_time_from_system()) + 6 * 3600
			vitality_claimed.emit("xp", 200)
		return
	if _claim_in_flight:
		push_warning("UserManager.claim_vitality_async: claim already in flight")
		return
	if not _profile.is_vitality_ready():
		push_warning("UserManager.claim_vitality_async: vitality not ready")
		return
	_claim_in_flight = true
	var data: Dictionary = await _vitality_service.claim_async(base_url, _token_store.access_token)
	_claim_in_flight = false
	if data.get("concurrencyError", false):
		# Another device claimed first — refresh server state to sync UI
		await _poll_vitality_status()
		return
	if data.is_empty():
		return
	var reward_type: String = str(data.get("rewardType", ""))
	var reward_amount: int = int(data.get("rewardAmount", 0))
	apply_server_xp(int(data.get("newUserXP", _profile.current_xp)), int(data.get("newUserLevel", _profile.level)))
	update_currency(int(data.get("newCurrencyTotal", _profile.currency)))
	_profile.vitality_ready_at = int(Time.get_unix_time_from_system()) + 6 * 3600
	vitality_claimed.emit(reward_type, reward_amount)

func purchase_async(prefixed_id: String, quantity: int) -> Dictionary:
	if _purchase_in_flight:
		push_warning("UserManager.purchase_async: purchase already in flight")
		return {}
	_purchase_in_flight = true
	var data: Dictionary = await _shop_service.purchase_async(base_url, _token_store.access_token, prefixed_id, quantity)
	_purchase_in_flight = false
	if data.is_empty():
		return {}
	update_currency(int(data.get("remainingCurrency", _profile.currency)))
	return data

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _vitality_poll_timer:
			_vitality_poll_timer.stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _vitality_poll_timer:
			_vitality_poll_timer.start()
			_poll_vitality_status()

func save_avatar_index(idx: int) -> void:
	var config := ConfigFile.new()
	config.set_value("avatar", "index", idx)
	var err := config.save("user://avatar_prefs.cfg")
	if err != OK:
		push_error("UserManager.save_avatar_index: failed to save ConfigFile, err=%d" % err)

func load_avatar_index() -> int:
	var config := ConfigFile.new()
	if config.load("user://avatar_prefs.cfg") != OK:
		return 0
	return int(config.get_value("avatar", "index", 0))

func set_avatar_async(idx: int) -> void:  # intentional: callers may fire-and-forget
	if _avatar_in_flight:
		return
	idx = clampi(idx, 0, 6)
	var prev_idx := _profile.avatar_index
	_profile.avatar_index = idx
	save_avatar_index(idx)
	profile_updated.emit()
	if use_mock:
		return
	_avatar_in_flight = true
	var body := JSON.stringify({"avatarIndex": idx})
	var headers := HttpHelper.make_headers(_token_store.access_token if _token_store else "")
	headers.append("Content-Type: application/json")
	var err := _avatar_http.request(base_url + "/api/auth/avatar-index", headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		_profile.avatar_index = prev_idx
		save_avatar_index(prev_idx)
		profile_updated.emit()
		_avatar_in_flight = false
		push_warning("UserManager.set_avatar_async: request error %d" % err)
		return
	var raw: Variant = await _avatar_http.request_completed
	_avatar_in_flight = false
	var status_code: int = raw[1]
	if status_code != 200:
		_profile.avatar_index = prev_idx
		save_avatar_index(prev_idx)
		profile_updated.emit()
		push_warning("UserManager.set_avatar_async: BE sync failed (HTTP %d), reverted to %d" % [status_code, prev_idx])

func set_username_async(new_name: String) -> void:
	if _rename_in_flight:
		return
	new_name = new_name.strip_edges()
	if new_name.is_empty() or new_name == _profile.username:
		return
	var prev_name := _profile.username
	_profile.username = new_name
	profile_updated.emit()
	if use_mock:
		return
	_rename_in_flight = true
	var body := JSON.stringify({"userName": new_name})
	var headers := HttpHelper.make_headers(_token_store.access_token if _token_store else "")
	headers.append("Content-Type: application/json")
	var err := _rename_http.request(base_url + "/api/auth/profile", headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		_profile.username = prev_name
		profile_updated.emit()
		_rename_in_flight = false
		push_warning("UserManager.set_username_async: request error %d" % err)
		return
	var raw: Variant = await _rename_http.request_completed
	_rename_in_flight = false
	var status_code: int = raw[1]
	if status_code != 200:
		_profile.username = prev_name
		profile_updated.emit()
		push_warning("UserManager.set_username_async: BE sync failed HTTP %d" % status_code)

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
	if _register_in_flight:
		_http_register.cancel_request()
		_register_in_flight = false
	if _profile_in_flight:
		_http_profile.cancel_request()
		_profile_in_flight = false
	if _claim_in_flight:
		_vitality_claim_http.cancel_request()
		_claim_in_flight = false
	if _purchase_in_flight:
		_shop_purchase_http.cancel_request()
		_purchase_in_flight = false
	if _avatar_in_flight:
		_avatar_http.cancel_request()
		_avatar_in_flight = false
	if _rename_in_flight:
		_rename_http.cancel_request()
		_rename_in_flight = false
	_vitality_poll_timer.stop()
