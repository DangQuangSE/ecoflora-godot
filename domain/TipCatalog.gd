class_name TipCatalog
extends RefCounted

const OFFLINE_SYNERGY_ID: String = "offline_synergy"


static func build_offline_fallback() -> Array[GameTip]:
	var tips: Array[GameTip] = []
	tips.append(GameTip.new(
		OFFLINE_SYNERGY_ID,
		"Hệ Sinh Thái",
		"Vườn của bạn chia thành nhiều zone. Khi trong cùng một zone có từ 2 cây trở lên thuộc cùng nhóm Synergy (ô trống không tính), zone được coi là \"thuần\" và kích hoạt bonus XP. " +
		"Khi synergy đang active, tưới nước hoặc bón phân trên bất kỳ cây nào trong zone đều cộng thêm XP. " +
		"Zone đang có synergy sẽ hiện hiệu ứng lấp lánh; khi chăm sóc bạn thấy nhãn +XP và +🌿 bonus. " +
		"Bonus mất khi trộn hai nhóm Synergy, trồng cây không có Synergy, hoặc sau thu hoạch còn dưới 2 cây.",
		0
	))
	return tips
