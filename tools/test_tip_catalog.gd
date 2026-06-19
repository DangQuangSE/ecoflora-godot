extends SceneTree

const TipCatalogScript := preload("res://domain/TipCatalog.gd")

var _failed := 0


func _initialize() -> void:
	_test_tip_catalog()
	if _failed > 0:
		push_error("TipCatalog tests: %d failed" % _failed)
		quit(1)
	else:
		print("TipCatalog tests: all passed")
		quit(0)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failed += 1
		push_error("FAIL %s: expected %s got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL %s" % label)


func _test_tip_catalog() -> void:
	var tips := TipCatalogScript.build_offline_fallback()
	_assert_eq(tips.size(), 1, "fallback tip count")
	_assert_true(not tips[0].title.is_empty(), "tip title")
	_assert_true(not tips[0].content.is_empty(), "tip content")
	_assert_eq(tips[0].title, "Hệ Sinh Thái", "synergy title")
