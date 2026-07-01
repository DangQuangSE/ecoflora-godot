class_name GiftCodeService
extends RefCounted

# Returns {network_error: bool, ok: bool, status: int, message: String, data: Dictionary}.
# network_error true means no HTTP response was ever received (cannot distinguish
# "never reached server" from "succeeded but response lost") — caller must not
# treat this the same as a parsed error response.
func redeem_async(http: HTTPRequest, base_url: String, token: String, code: String) -> Dictionary:
	var url := "%s/api/gift-codes/redeem" % base_url
	var headers := HttpHelper.make_headers(token)
	var body := HttpHelper.encode_body({"code": code})
	var raw: Array = await HttpHelper.request_with_retry_async(http, url, HTTPClient.METHOD_POST, headers, body)
	var err: int = raw[0]
	if err != OK:
		push_warning("GiftCodeService.redeem_async: request error %d" % err)
		return _network_error_result()
	var http_result: int = raw[0]
	if http_result != HTTPRequest.RESULT_SUCCESS:
		push_warning("GiftCodeService.redeem_async: connection failure %d" % http_result)
		return _network_error_result()

	var status: int = raw[1]
	var bytes: PackedByteArray = raw[3]

	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		push_warning("GiftCodeService.redeem_async: JSON parse error")
		return {"network_error": false, "ok": false, "status": status, "message": "", "data": {}}

	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return {"network_error": false, "ok": false, "status": status, "message": "", "data": {}}

	var message: String = str(envelope.get("message", ""))

	if status == 200:
		var data: Variant = HttpHelper.unwrap_envelope(envelope)
		if data is Dictionary:
			return {"network_error": false, "ok": true, "status": status, "message": message, "data": data as Dictionary}

	return {"network_error": false, "ok": false, "status": status, "message": message, "data": {}}

func _network_error_result() -> Dictionary:
	return {"network_error": true, "ok": false, "status": 0, "message": "", "data": {}}
