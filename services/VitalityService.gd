class_name VitalityService
extends RefCounted

var _http_status: HTTPRequest
var _http_claim: HTTPRequest

func _init(http_status: HTTPRequest, http_claim: HTTPRequest) -> void:
	_http_status = http_status
	_http_claim  = http_claim

func get_status_async(base_url: String, token: String) -> Dictionary:
	var headers := HttpHelper.make_headers(token)
	var raw: Array = await HttpHelper.request_with_retry_async(_http_status, base_url + "/api/vitality/status", HTTPClient.METHOD_GET, headers)
	var err: int = raw[0]
	if err != OK:
		push_warning("VitalityService.get_status_async: request error %d" % err)
		return {}
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code != 200:
		push_warning("VitalityService.get_status_async: HTTP %d" % status_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("VitalityService.get_status_async: JSON parse error")
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		return {}
	return data as Dictionary

func claim_async(base_url: String, token: String) -> Dictionary:
	var headers := HttpHelper.make_headers(token)
	headers.append("Content-Type: application/json")
	var raw: Array = await HttpHelper.request_with_retry_async(_http_claim, base_url + "/api/vitality/claim", HTTPClient.METHOD_POST, headers, "")
	var err: int = raw[0]
	if err != OK:
		push_warning("VitalityService.claim_async: request error %d" % err)
		return {}
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code == 409:
		# Concurrent claim from another device — caller should re-fetch status
		return {"concurrencyError": true}
	if status_code not in [200, 201]:
		push_warning("VitalityService.claim_async: HTTP %d" % status_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("VitalityService.claim_async: JSON parse error")
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		return {}
	return data as Dictionary
