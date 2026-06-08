class_name AuthService
extends RefCounted

func build_login_body(account: String, password: String) -> String:
	return JSON.stringify({"account": account, "password": password})

func resolve_account_fields(account: String) -> Dictionary:
	var trimmed := account.strip_edges()
	if "@" in trimmed:
		return {"email": trimmed, "username": ""}
	return {"email": "", "username": trimmed}

func build_register_body(first_name: String, last_name: String,
		account: String, password: String) -> String:
	var fields := resolve_account_fields(account)
	return JSON.stringify({
		"firstName": first_name,
		"lastName": last_name,
		"email": fields["email"],
		"username": fields["username"],
		"password": password,
	})

func parse_register_success(json: Dictionary) -> String:
	if not json.get("isSuccess", false):
		return ""
	return str(json.get("message", "Đăng ký thành công."))

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
