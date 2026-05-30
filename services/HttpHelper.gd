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
