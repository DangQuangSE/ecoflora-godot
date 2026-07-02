class_name FocusService
extends RefCounted

var _http_create: HTTPRequest
var _http_terminal: HTTPRequest

func _init(http_create: HTTPRequest, http_terminal: HTTPRequest) -> void:
	_http_create   = http_create
	_http_terminal = http_terminal

func create_async(base_url: String, access_token: String, target_duration_minutes: int) -> Dictionary:
	var headers: PackedStringArray = HttpHelper.make_headers(access_token)
	var body: String = HttpHelper.encode_body({"targetDuration": target_duration_minutes})
	var raw: Array = await HttpHelper.request_with_retry_async(_http_create, base_url + "/api/focus-sessions", HTTPClient.METHOD_POST, headers, body)
	var error: int                 = raw[0]
	if error != OK:
		push_warning("FocusService.create_async: request error %d" % error)
		return {}
	var status_code: int           = raw[1]
	var response_body: PackedByteArray = raw[3]
	if status_code not in [200, 201]:
		push_warning("FocusService.create_async: HTTP %d" % status_code)
		return {}
	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		push_warning("FocusService.create_async: JSON parse error")
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		push_warning("FocusService.create_async: data is not a Dictionary")
		return {}
	return data

func complete_async(base_url: String, access_token: String, session_id: String, strikes: int) -> Dictionary:
	return await _patch_terminal(base_url, access_token, session_id, "complete", strikes)

func fail_async(base_url: String, access_token: String, session_id: String, strikes: int) -> bool:
	return not (await _patch_terminal(base_url, access_token, session_id, "fail", strikes)).is_empty()

func _patch_terminal(base_url: String, access_token: String, session_id: String,
		action: String, strikes: int) -> Dictionary:
	var url: String = "%s/api/focus-sessions/%s/%s" % [base_url, session_id, action]
	var headers: PackedStringArray = HttpHelper.make_headers(access_token)
	var body: String = HttpHelper.encode_body({"strikes": strikes})
	var raw: Array = await HttpHelper.request_with_retry_async(_http_terminal, url, HTTPClient.METHOD_PATCH, headers, body)
	var error: int                 = raw[0]
	if error != OK:
		push_warning("FocusService.%s_async: request error %d" % [action, error])
		return {}
	var status_code: int               = raw[1]
	var response_body: PackedByteArray = raw[3]
	if status_code != 200:
		push_warning("FocusService.%s_async: HTTP %d" % [action, status_code])
		return {}
	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		push_warning("FocusService.%s_async: JSON parse error" % action)
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		push_warning("FocusService.%s_async: data is not a Dictionary" % action)
		return {}
	return data