class_name VitalityService
extends RefCounted

var _http_status: HTTPRequest
var _http_claim: HTTPRequest

func _init(http_status: HTTPRequest, http_claim: HTTPRequest) -> void:
	_http_status = http_status
	_http_claim  = http_claim

func get_status_async(base_url: String, token: String) -> Dictionary:
	var headers := HttpHelper.make_headers(token)
	var err := _http_status.request(base_url + "/api/vitality/status", headers)
	if err != OK:
		push_warning("VitalityService.get_status_async: request error %d" % err)
		return {}
	var raw: Variant = await _http_status.request_completed
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
	var err := _http_claim.request(base_url + "/api/vitality/claim", headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		push_warning("VitalityService.claim_async: request error %d" % err)
		return {}
	var raw: Variant = await _http_claim.request_completed
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
