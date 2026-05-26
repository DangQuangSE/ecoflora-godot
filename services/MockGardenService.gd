class_name MockGardenService
extends RefCounted

func get_flower_templates() -> Array[FlowerTemplate]:
	var sunflower := FlowerTemplate.new()
	sunflower.id = "sunflower"
	sunflower.name = "Sunflower"
	sunflower.harvest_product_id = "harvest_sunflower_bloom"
	sunflower.stages = _make_stages([
		{level = 1, xp = 0,   model_key = "sunflower_sprout"},
		{level = 4, xp = 100, model_key = "sunflower_bud"},
		{level = 7, xp = 300, model_key = "sunflower_bloom"},
	])

	var rose := FlowerTemplate.new()
	rose.id = "rose"
	rose.name = "Rose"
	rose.harvest_product_id = "harvest_rose_bloom"
	rose.stages = _make_stages([
		{level = 1, xp = 0,   model_key = "rose_sprout"},
		{level = 4, xp = 120, model_key = "rose_bud"},
		{level = 7, xp = 360, model_key = "rose_bloom"},
	])

	return [sunflower, rose]

func get_initial_plots(garden_id: String) -> Array[Plot]:
	var plots: Array[Plot] = []
	for i in range(8):
		plots.append(Plot.new("plot_%d" % i, garden_id, i))
	return plots

func _make_stages(data: Array) -> Array[StageDefinition]:
	var result: Array[StageDefinition] = []
	for d in data:
		var s := StageDefinition.new()
		s.level = d.level
		s.xp_required = d.xp
		s.model_key = d.model_key
		result.append(s)
	return result
