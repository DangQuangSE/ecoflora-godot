class_name FlowerTemplate
extends RefCounted

var id: String
var name: String
var base_price: int
var image_url: String
var synergy_id: String
var harvest_product_id: String
# Invariant: MockGardenService must insert stages sorted ascending by xp_required.
# compute_stage_for_xp relies on this — it does NOT sort on each call (Q3 decision).
var stages: Array[StageDefinition] = []

func sort_stages() -> void:
	stages.sort_custom(func(a: StageDefinition, b: StageDefinition) -> bool:
		return a.xp_required < b.xp_required)

func get_max_stage_level() -> int:
	var max_level := 1
	for s: StageDefinition in stages:
		if s.level > max_level:
			max_level = s.level
	return max_level

func compute_stage_for_xp(current_xp: int) -> int:
	if stages.is_empty():
		return 1
	var best_level: int = stages[0].level
	var best_xp: int    = stages[0].xp_required
	for s: StageDefinition in stages:
		if s.xp_required <= current_xp and s.xp_required >= best_xp:
			best_level = s.level
			best_xp    = s.xp_required
	return best_level

func get_xp_required_for_stage(level: int) -> int:
	for s: StageDefinition in stages:
		if s.level == level:
			return s.xp_required
	return 0

func get_next_stage_xp(current_stage: int) -> int:
	var max_level := get_max_stage_level()
	if current_stage >= max_level:
		return -1
	var next_level := 999999
	var next_xp    := -1
	for s: StageDefinition in stages:
		if s.level > current_stage and s.level < next_level:
			next_level = s.level
			next_xp    = s.xp_required
	return next_xp
