class_name AuthService
extends RefCounted

func build_login_body(account: String, password: String) -> String:
	return JSON.stringify({"account": account, "password": password})

func parse_login_response(json: Dictionary) -> Dictionary:
	# BE wraps response: { isSuccess, message, data: { accessToken, refreshToken } }
	if not json.get("isSuccess", false):
		push_warning("AuthService.parse_login_response: %s" % json.get("message", "login failed"))
		return {}
	var data: Variant = json.get("data", null)
	if not data is Dictionary:
		push_warning("AuthService.parse_login_response: 'data' is not a Dictionary")
		return {}
	var typed: Dictionary = data
	if not typed.has("accessToken") or not typed.has("refreshToken"):
		push_warning("AuthService.parse_login_response: missing accessToken or refreshToken")
		return {}
	return typed
