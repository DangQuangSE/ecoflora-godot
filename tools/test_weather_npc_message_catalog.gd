extends SceneTree

const WeatherNpcMessageCatalogScript := preload("res://domain/WeatherNpcMessageCatalog.gd")
const WeatherStateScript := preload("res://domain/WeatherState.gd")

var _failed := 0


func _initialize() -> void:
	_test_weather_npc_message_catalog()
	if _failed > 0:
		push_error("WeatherNpcMessageCatalog tests: %d failed" % _failed)
		quit(1)
	else:
		print("WeatherNpcMessageCatalog tests: all passed")
		quit(0)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failed += 1
		push_error("FAIL %s: expected %s got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL %s" % label)


func _assert_not_empty(text: String, label: String) -> void:
	if text.is_empty():
		_failed += 1
		push_error("FAIL %s: message is empty" % label)


func _test_weather_npc_message_catalog() -> void:
	# Test 1: All conditions have messages
	_assert_true(_has_messages_for_condition(WeatherStateScript.Condition.SUNNY),
		"SUNNY condition has message pool")
	_assert_true(_has_messages_for_condition(WeatherStateScript.Condition.CLOUDY),
		"CLOUDY condition has message pool")
	_assert_true(_has_messages_for_condition(WeatherStateScript.Condition.RAINY),
		"RAINY condition has message pool")
	_assert_true(_has_messages_for_condition(WeatherStateScript.Condition.STORM),
		"STORM condition has message pool")

	# Test 2: get_random_message returns non-empty string for valid conditions
	var sunny_msg := WeatherNpcMessageCatalogScript.get_random_message(WeatherStateScript.Condition.SUNNY)
	_assert_not_empty(sunny_msg, "SUNNY message not empty")

	var cloudy_msg := WeatherNpcMessageCatalogScript.get_random_message(WeatherStateScript.Condition.CLOUDY)
	_assert_not_empty(cloudy_msg, "CLOUDY message not empty")

	var rainy_msg := WeatherNpcMessageCatalogScript.get_random_message(WeatherStateScript.Condition.RAINY)
	_assert_not_empty(rainy_msg, "RAINY message not empty")

	var storm_msg := WeatherNpcMessageCatalogScript.get_random_message(WeatherStateScript.Condition.STORM)
	_assert_not_empty(storm_msg, "STORM message not empty")

	# Test 3: get_random_message returns fallback for invalid condition
	# Create an invalid condition value (beyond the enum range)
	var invalid_condition = 999
	var fallback_msg := WeatherNpcMessageCatalogScript.get_random_message(invalid_condition)
	_assert_not_empty(fallback_msg, "fallback message not empty for invalid condition")
	_assert_true(fallback_msg == "Thời tiết thay đổi rồi, ra vườn ngó qua cây nhé!",
		"fallback message is correct for invalid condition")

	# Test 4: Multiple calls return different messages (verify randomness)
	var messages_set: Array[String] = []
	for i in range(10):
		var msg := WeatherNpcMessageCatalogScript.get_random_message(WeatherStateScript.Condition.SUNNY)
		messages_set.append(msg)

	var unique_messages := {}
	for msg in messages_set:
		unique_messages[msg] = true
	_assert_true(unique_messages.size() > 1,
		"SUNNY condition returns multiple different messages (randomness verified)")

	# Test 5: All messages are Vietnamese and non-empty
	for condition in [WeatherStateScript.Condition.SUNNY, WeatherStateScript.Condition.CLOUDY,
		WeatherStateScript.Condition.RAINY, WeatherStateScript.Condition.STORM]:
		for i in range(5):
			var msg := WeatherNpcMessageCatalogScript.get_random_message(condition)
			_assert_not_empty(msg, "message for condition %d is not empty" % condition)
			# Basic check: messages should contain Vietnamese text (accented characters)
			var has_vietnamese = msg.contains("ơ") or msg.contains("ư") or msg.contains("ả") or \
				msg.contains("ế") or msg.contains("ỉ") or msg.contains("ỏ") or msg.contains("ụ") or \
				msg.contains("á") or msg.contains("à") or msg.contains("ã") or msg.contains("ạ") or \
				msg.contains("é") or msg.contains("è") or msg.contains("ệ") or msg.contains("í") or \
				msg.contains("ì") or msg.contains("ĩ") or msg.contains("ọ") or msg.contains("ó") or \
				msg.contains("ò") or msg.contains("ũ") or msg.contains("û") or msg.contains("ứ") or \
				msg.contains("ừ") or msg.contains("ự")
			_assert_true(has_vietnamese, "message for condition %d contains Vietnamese text" % condition)


func _has_messages_for_condition(condition: int) -> bool:
	var msg := WeatherNpcMessageCatalogScript.get_random_message(condition)
	return not msg.is_empty()
