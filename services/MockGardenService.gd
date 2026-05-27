class_name MockGardenService
extends RefCounted

func get_flower_templates() -> Array[FlowerTemplate]:
	var lotus := FlowerTemplate.new()
	lotus.id = "lotus"
	lotus.name = "Hoa Sen"
	lotus.harvest_product_id = "harvest_lotus_bloom"
	lotus.stages = _make_stages([
		{level = 1, xp = 0,   model_key = "lotus_1"},
		{level = 4, xp = 100, model_key = "lotus_2"},
		{level = 7, xp = 300, model_key = "lotus_3"},
	])

	var rose := FlowerTemplate.new()
	rose.id = "rose"
	rose.name = "Hoa Hồng"
	rose.harvest_product_id = "harvest_rose_bloom"
	rose.stages = _make_stages([
		{level = 1, xp = 0,   model_key = "rose_1"},
		{level = 4, xp = 120, model_key = "rose_2"},
		{level = 7, xp = 360, model_key = "rose_3"},
	])

	var periwinkle := FlowerTemplate.new()
	periwinkle.id = "periwinkle"
	periwinkle.name = "Hoa Dừa Cạn"
	periwinkle.harvest_product_id = "harvest_periwinkle_bloom"
	periwinkle.stages = _make_stages([
		{level = 1, xp = 0,   model_key = "periwinkle_1"},
		{level = 4, xp = 80,  model_key = "periwinkle_2"},
		{level = 7, xp = 240, model_key = "periwinkle_3"},
	])

	return [lotus, rose, periwinkle]

func get_initial_plots(garden_id: String) -> Array[Plot]:
	var plots: Array[Plot] = []
	for i in range(16):
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
