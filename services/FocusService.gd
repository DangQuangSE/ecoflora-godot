class_name FocusService
extends RefCounted

var _http_create: HTTPRequest    # used only by create_async
var _http_terminal: HTTPRequest  # used only by complete_async / fail_async

func _init(http_create: HTTPRequest, http_terminal: HTTPRequest) -> void:
	_http_create   = http_create
	_http_terminal = http_terminal

# Creates a new IN_PROGRESS focus session on BE.
# Returns the response data Dictionary (contains "id") on success, empty Dictionary on any error.
func create_async(base_url: String, access_token: String, target_duration_minutes: int) -> Dictionary:
	var headers: PackedStringArray = HttpHelper.make_headers(access_token)
	var body: String = HttpHelper.encode_body({"targetDuration": target_duration_minutes})
	var error: int = _http_create.request(
		base_url + "/api/focus-sessions", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("FocusService.create_async: request error %d" % error)
		return {}
	var raw: Variant = await _http_create.request_completed
	var http_result: int           = raw[0]
	var status_code: int           = raw[1]
	var response_body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code not in [200, 201]:
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

# Marks the session COMPLETED on BE. Returns true on success.
# On 401: push_warning only — session is already finalised locally, re-login would destroy UX.
func complete_async(base_url: String, access_token: String, session_id: String, strikes: int) -> bool:
	return await _patch_terminal(base_url, access_token, session_id, "complete", strikes)

# Marks the session FAILED on BE. Returns true on success. Same 401 policy as complete_async.
func fail_async(base_url: String, access_token: String, session_id: String, strikes: int) -> bool:
	return await _patch_terminal(base_url, access_token, session_id, "fail", strikes)

func _patch_terminal(base_url: String, access_token: String, session_id: String,
		action: String, strikes: int) -> bool:
	var url: String = "%s/api/focus-sessions/%s/%s" % [base_url, session_id, action]
	var headers: PackedStringArray = HttpHelper.make_headers(access_token)
	var body: String = HttpHelper.encode_body({"strikes": strikes})
	var error: int = _http_terminal.request(url, headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		push_warning("FocusService.%s_async: request error %d" % [action, error])
		return false
	var raw: Variant = await _http_terminal.request_completed
	var http_result: int           = raw[0]
	var status_code: int           = raw[1]
	var response_body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
		push_warning("FocusService.%s_async: HTTP %d" % [action, status_code])
		return false
	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK:
		push_warning("FocusService.%s_async: JSON parse error" % action)
		return false
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return false
	return bool(envelope.get("isSuccess", false))
