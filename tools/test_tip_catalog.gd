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
	var categories := TipCatalogScript.get_categories()
	_assert_eq(categories.size(), 1, "category count")
	_assert_eq(str(categories[0].get("id", "")), TipCatalogScript.CATEGORY_SYNERGY, "category id")

	var tips := TipCatalogScript.get_tips_for_category(TipCatalogScript.CATEGORY_SYNERGY)
	_assert_true(tips.size() >= 4, "synergy tip count")

	for tip in tips:
		_assert_true(not tip.id.is_empty(), "tip id")
		_assert_true(not tip.title.is_empty(), "tip title")
		_assert_true(not tip.body.is_empty(), "tip body")
		_assert_eq(tip.category_id, TipCatalogScript.CATEGORY_SYNERGY, "tip category")

	var empty := TipCatalogScript.get_tips_for_category("unknown")
	_assert_eq(empty.size(), 0, "unknown category empty")
