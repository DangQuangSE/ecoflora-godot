extends SceneTree

const TipServiceScript := preload("res://services/TipService.gd")

var _failed := 0


func _initialize() -> void:
	_test_parse_envelope()
	if _failed > 0:
		push_error("TipService tests: %d failed" % _failed)
		quit(1)
	else:
		print("TipService tests: all passed")
		quit(0)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failed += 1
		push_error("FAIL %s: expected %s got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL %s" % label)


func _test_parse_envelope() -> void:
	var svc := TipServiceScript.new()
	var envelope := {
		"isSuccess": true,
		"data": [
			{
				"id": "b0000000-0001-4001-8001-000000000001",
				"title": "Hệ Sinh Thái",
				"content": "Nội dung test.",
				"sortOrder": 0,
			},
			{
				"id": "b0000000-0001-4001-8001-000000000002",
				"title": "Thu Hoạch",
				"content": "Thu hoạch khi cây chín.",
				"sortOrder": 1,
			},
		],
	}
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	_assert_true(data is Array, "unwrap array")
	var tips: Array[GameTip] = svc._parse_tips(data as Array)
	_assert_eq(tips.size(), 2, "parsed count")
	_assert_eq(tips[0].title, "Hệ Sinh Thái", "first title")
	_assert_eq(tips[1].content, "Thu hoạch khi cây chín.", "second content")
