class_name HttpHelper
extends RefCounted

# Returns [Content-Type, Authorization] headers.
# Omits Authorization when token is empty (unauthenticated requests).
static func make_headers(access_token: String) -> PackedStringArray:
	if access_token.is_empty():
		push_warning("HttpHelper.make_headers: no access token — sending unauthenticated request")
		return PackedStringArray(["Content-Type: application/json"])
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])

# Unwraps the BE ApiResponse envelope { isSuccess, message, data, metaData }.
# Returns the inner `data` value on success, null on failure or missing isSuccess.
static func unwrap_envelope(json: Dictionary) -> Variant:
	if not json.get("isSuccess", false):
		push_warning("HttpHelper.unwrap_envelope: %s" % json.get("message", "isSuccess=false"))
		return null
	return json.get("data", null)

# Serialises a Dictionary to a JSON string for request bodies.
static func encode_body(payload: Dictionary) -> String:
	return JSON.stringify(payload)

# Executes an HTTP request and automatically retries once if it encounters a 401 Unauthorized.
# Returns the raw result array from HTTPRequest.request_completed: [result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray]
static func request_with_retry_async(http: HTTPRequest, url: String, method: int, base_headers: PackedStringArray, body: String = "") -> Array:
	var err := http.request(url, base_headers, method, body)
	if err != OK:
		return [err, 0, PackedStringArray(), PackedByteArray()]
	var raw: Array = await http.request_completed
	var status: int = raw[1]
	
	if status == 401:
		push_warning("HttpHelper.request_with_retry_async: 401 detected, attempting token refresh...")
		var refreshed: bool = await UserManager.ensure_refresh_async()
		if refreshed:
			var new_headers := make_headers(UserManager.get_access_token())
			var content_type := ""
			for h in base_headers:
				if h.to_lower().begins_with("content-type:"):
					content_type = h
					break
			if not content_type.is_empty() and not content_type in new_headers:
				new_headers.append(content_type)
				
			push_warning("HttpHelper.request_with_retry_async: token refreshed, retrying request...")
			err = http.request(url, new_headers, method, body)
			if err != OK:
				return [err, 0, PackedStringArray(), PackedByteArray()]
			raw = await http.request_completed
			
	return raw
