extends Node

signal redeem_result_received(success: bool, message: String)

const REWARD_TYPE_CURRENCY: int = 0
const REWARD_TYPE_ITEM: int = 1
const REWARD_TYPE_FLOWER_SEED: int = 2
const REWARD_TYPE_DECOR: int = 3

@export var use_mock: bool = false

var base_url: String:
	get:
		return UserManager.base_url

var _redeem_in_flight: bool = false

const _GiftCodeServiceScript = preload("res://services/GiftCodeService.gd")
var _svc: GiftCodeService

var _http_redeem: HTTPRequest

func _ready() -> void:
	_svc = _GiftCodeServiceScript.new()
	if not use_mock:
		_http_redeem = HTTPRequest.new()
		_http_redeem.timeout = 15.0
		add_child(_http_redeem)

func is_redeem_in_flight() -> bool:
	return _redeem_in_flight

# Call when reopening the dialog after a network error. A dropped connection means
# the server may have already committed the redeem, so resync from the server
# profile/inventory instead of blindly allowing an immediate retry.
func resync_after_network_error() -> void:
	if not _redeem_in_flight:
		return
	_redeem_in_flight = false
	if use_mock:
		return
	# Fire-and-forget: both managers broadcast their own update signals on completion,
	# the dialog doesn't need to block on this resync to function.
	UserManager.fetch_profile_async()
	InventoryManager.refresh_async()

func redeem_async(code: String) -> void:
	if _redeem_in_flight:
		return
	_redeem_in_flight = true

	var normalized_code := code.to_upper().strip_edges()
	if normalized_code.is_empty():
		redeem_result_received.emit(false, "Vui lòng nhập mã.")
		_redeem_in_flight = false
		return

	if use_mock:
		await get_tree().process_frame
		UserManager.update_currency(UserManager.get_profile().currency + 50)
		InventoryManager.add_reward_item("mock_seed", "Mock Seed", 1)
		Toast.show_message(self, "Phần thưởng: +50 xu, +1 vật phẩm", 2.6)
		redeem_result_received.emit(true, "Đổi mã thành công (mock).")
		_redeem_in_flight = false
		return

	var old_currency := UserManager.get_profile().currency
	var result := await _svc.redeem_async(_http_redeem, UserManager.base_url, UserManager.get_access_token(), normalized_code)

	if result.get("network_error", false):
		# Keep _redeem_in_flight=true: the server may have already committed the
		# redeem. Cleared by resync_after_network_error() when the dialog reopens.
		redeem_result_received.emit(false, "Lỗi kết nối — vui lòng kiểm tra mạng và mở lại hộp thoại.")
		return

	if int(result.get("status", 0)) == 401:
		UserManager.handle_401()
		redeem_result_received.emit(false, "Phiên đăng nhập đã hết hạn.")
		_redeem_in_flight = false
		return

	if not result.get("ok", false):
		var message: String = str(result.get("message", "Không thể đổi mã."))
		redeem_result_received.emit(false, message)
		_redeem_in_flight = false
		return

	var data: Dictionary = result.get("data", {})
	var reward_summary := _apply_redeem_result(data, old_currency)
	if not reward_summary.is_empty():
		Toast.show_message(self, reward_summary, 2.6)

	var success_message: String = str(result.get("message", ""))
	if success_message.is_empty():
		success_message = "Đổi mã thành công!"
	redeem_result_received.emit(true, success_message)
	_redeem_in_flight = false

# Applies server-granted rewards locally and returns a Toast-ready summary
# string (e.g. "Phần thưởng: +500 xu, +2 vật phẩm"), or "" if nothing to show.
func _apply_redeem_result(data: Dictionary, old_currency: int) -> String:
	var new_currency: Variant = data.get("newCurrencyTotal", null)
	if new_currency != null:
		UserManager.update_currency(int(new_currency))

	var granted_rewards: Variant = data.get("grantedRewards", [])
	var item_qty := 0
	var seed_qty := 0
	var decor_qty := 0

	if granted_rewards is Array:
		for reward: Variant in granted_rewards:
			if not reward is Dictionary:
				continue
			var reward_dict: Dictionary = reward as Dictionary
			var reward_type := int(reward_dict.get("rewardType", -1))
			var quantity := int(reward_dict.get("quantity", 0))
			var ref_id := str(reward_dict.get("refId", ""))
			if reward_type == REWARD_TYPE_CURRENCY or ref_id.is_empty() or quantity <= 0:
				continue
			InventoryManager.add_reward_item(ref_id, "", quantity)
			match reward_type:
				REWARD_TYPE_FLOWER_SEED:
					seed_qty += quantity
				REWARD_TYPE_DECOR:
					decor_qty += quantity
				REWARD_TYPE_ITEM, _:
					item_qty += quantity

	var parts: PackedStringArray = []
	if new_currency != null:
		var currency_gain := int(new_currency) - old_currency
		if currency_gain > 0:
			parts.append("+%d xu" % currency_gain)
	if item_qty > 0:
		parts.append("+%d vật phẩm" % item_qty)
	if seed_qty > 0:
		parts.append("+%d hạt giống" % seed_qty)
	if decor_qty > 0:
		parts.append("+%d trang trí" % decor_qty)

	if parts.is_empty():
		return ""
	return "Phần thưởng: " + ", ".join(parts)
