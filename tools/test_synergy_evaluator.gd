extends SceneTree

const ZonePlotMapScript := preload("res://domain/ZonePlotMap.gd")
const SynergyEvaluatorScript := preload("res://domain/SynergyEvaluator.gd")

var _failed := 0


func _initialize() -> void:
	_test_zone_plot_map()
	_test_synergy_evaluator()
	if _failed > 0:
		push_error("SynergyEvaluator tests: %d failed" % _failed)
		quit(1)
	else:
		print("SynergyEvaluator tests: all passed")
		quit(0)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failed += 1
		push_error("FAIL %s: expected %s got %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("FAIL %s" % label)


func _make_plot(index: int, template_id: String, occupied: bool) -> Plot:
	var p := Plot.new("plot_%d" % index, "garden", index)
	if occupied:
		var flower := PlantedFlower.new(template_id, "user")
		p.plant(flower)
	return p


func _make_template(id: String, synergy_id: String) -> FlowerTemplate:
	var t := FlowerTemplate.new()
	t.id = id
	t.synergy_id = synergy_id
	return t


func _test_zone_plot_map() -> void:
	_assert_eq(ZonePlotMapScript.get_zone_id_for_plot_index(0), "zone_0", "index 0 zone")
	_assert_eq(ZonePlotMapScript.get_zone_id_for_plot_index(16), "zone_2", "index 16 zone")
	_assert_eq(ZonePlotMapScript.get_zone_id_for_plot_index(55), "zone_6", "index 55 zone")
	var z2: Array[int] = ZonePlotMapScript.get_plot_indices_for_zone("zone_2")
	_assert_eq(z2.size(), 8, "zone_2 size")
	_assert_eq(z2[0], 16, "zone_2 start")


func _test_synergy_evaluator() -> void:
	var synergy_a := "synergy_sun"
	var cache: Dictionary = {
		synergy_a: {"xp_plus": 10, "name": "Sun Chaser"},
	}
	var templates: Dictionary = {
		"flower_sun": _make_template("flower_sun", synergy_a),
		"flower_rose": _make_template("flower_rose", ""),
		"flower_lotus": _make_template("flower_lotus", "synergy_water"),
	}

	var indices: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	var plots_by_index: Dictionary = {}

	# 0 occupied → inactive
	var r0: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r0.get("active", true), false, "zero occupied")

	# 1 occupied → inactive
	plots_by_index[0] = _make_plot(0, "flower_sun", true)
	var r1: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r1.get("active", true), false, "one occupied")

	# 2 same synergy → active, xp_plus 10
	plots_by_index[1] = _make_plot(1, "flower_sun", true)
	var r2: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r2.get("active", false), true, "two same synergy active")
	_assert_eq(r2.get("xp_plus", 0), 10, "two same xp_plus")

	# 3 same synergy → still active
	plots_by_index[2] = _make_plot(2, "flower_sun", true)
	var r3: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r3.get("active", false), true, "three same synergy")

	# mixed synergy → inactive
	plots_by_index[2] = _make_plot(2, "flower_lotus", true)
	var r4: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r4.get("active", true), false, "mixed synergy")

	# null synergy flower → inactive
	plots_by_index[1] = _make_plot(1, "flower_rose", true)
	plots_by_index[2] = _make_plot(2, "flower_sun", true)
	var r5: Dictionary = SynergyEvaluatorScript.evaluate_zone(indices, plots_by_index, templates)
	_assert_eq(r5.get("active", true), false, "null synergy mix")

	# get_bonus_for_plot
	var bonus: int = SynergyEvaluatorScript.get_bonus_for_plot(
		0, plots_by_index, templates, cache)
	_assert_eq(bonus, 0, "bonus with inactive zone")

	plots_by_index[1] = _make_plot(1, "flower_sun", true)
	plots_by_index[2] = _make_plot(2, "flower_sun", true)
	bonus = SynergyEvaluatorScript.get_bonus_for_plot(0, plots_by_index, templates, cache)
	_assert_eq(bonus, 10, "bonus when active")
