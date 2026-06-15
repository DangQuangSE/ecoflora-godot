class_name TipCatalog
extends RefCounted

const CATEGORY_SYNERGY: String = "synergy"


static func get_categories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append({"id": CATEGORY_SYNERGY, "label": "Hệ Sinh Thái"})
	return result


static func get_tips_for_category(category_id: String) -> Array[GameTip]:
	if category_id != CATEGORY_SYNERGY:
		return []
	return _synergy_tips()


static func _synergy_tips() -> Array[GameTip]:
	var cat := CATEGORY_SYNERGY
	var tips: Array[GameTip] = []
	tips.append(GameTip.new(
		"tip_synergy_intro",
		cat,
		"Synergy Zone là gì?",
		"Vườn của bạn chia thành nhiều zone. Khi trong cùng một zone, mọi cây đang trồng thuộc cùng một nhóm Synergy, zone đó được coi là \"thuần\" và kích hoạt bonus XP."
	))
	tips.append(GameTip.new(
		"tip_synergy_min_plants",
		cat,
		"Cần ít nhất 2 cây",
		"Bonus chỉ kích hoạt khi zone có từ 2 cây trở lên cùng Synergy. Ô đất trống không tính. Chỉ có 1 cây trong zone thì chưa nhận được bonus."
	))
	tips.append(GameTip.new(
		"tip_synergy_care_bonus",
		cat,
		"Nhận thêm XP khi chăm sóc",
		"Khi synergy đang active, tưới nước, bón phân trên bất kỳ cây nào trong zone đều cộng thêm XP."
	))
	tips.append(GameTip.new(
		"tip_synergy_feedback",
		cat,
		"Nhận biết zone đang active",
		"Zone đang có synergy sẽ hiện hiệu ứng lấp lánh quanh vùng. Khi chăm sóc, bạn thấy nhãn nổi hiển thị +XP cơ bản và +🌿 bonus synergy."
	))
	tips.append(GameTip.new(
		"tip_synergy_lost",
		cat,
		"Làm sao mất bonus?",
		"Bonus dừng ngay khi: trồng thêm cây khác Synergy, trộn 2 nhóm Synergy trong cùng zone, thu hoạch còn dưới 2 cây, hoặc có cây không thuộc nhóm Synergy nào."
	))
	return tips
