class_name WeatherNpcMessageCatalog
extends RefCounted

const _FALLBACK_MESSAGE: String = "Thời tiết thay đổi rồi, ra vườn ngó qua cây nhé!"

const _MESSAGE_POOL: Dictionary = {
	WeatherState.Condition.SUNNY: [
		"Nắng gắt quá! Nhớ tưới nước cho cây kẻo đất khô cằn nhé.",
		"Trời nắng đẹp ghê, nhưng đừng quên tưới nước cho hoa của bạn nha!",
		"Nắng to thế này, cây dễ mất nước lắm — tưới ngay đi bạn ơi!",
	],
	WeatherState.Condition.CLOUDY: [
		"Trời nhiều mây rồi, thời tiết mát mẻ dễ chịu cho cây phát triển đấy!",
		"Mây che kín trời, tranh thủ lúc này chăm sóc vườn cho thoải mái nhé.",
		"Trời dịu mát hơn rồi, ghé vườn kiểm tra tình hình cây một chút nào!",
	],
	WeatherState.Condition.RAINY: [
		"Mưa to rồi đó! Nhớ để ý cây kẻo bị úng nước nhé.",
		"Trời đang mưa, đất có thể bị ngập úng — kiểm tra vườn giúp mình với!",
		"Mưa nhiều quá, cây dễ úng rễ lắm, bạn nhớ theo dõi nha!",
	],
	WeatherState.Condition.STORM: [
		"Bão về rồi! Cây có thể bị ảnh hưởng mạnh, mau vào kiểm tra vườn nhé.",
		"Trời đang có bão to, hoa lá dễ bị hư hại lắm — chú ý cẩn thận nha!",
		"Gió bão mạnh quá, ghé thăm vườn xem cây có ổn không bạn ơi!",
	],
}


static func get_random_message(condition: WeatherState.Condition) -> String:
	if not _MESSAGE_POOL.has(condition):
		push_error("WeatherNpcMessageCatalog: unknown condition %s" % condition)
		return _FALLBACK_MESSAGE
	var pool: Array = _MESSAGE_POOL[condition]
	if pool.is_empty():
		push_error("WeatherNpcMessageCatalog: empty message pool for condition %s" % condition)
		return _FALLBACK_MESSAGE
	return pool[randi() % pool.size()]
