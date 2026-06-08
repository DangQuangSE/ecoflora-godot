class_name MockDecoService
extends RefCounted

func get_placements_async(scene_name: String) -> Array:
	if scene_name == "garden":
		return [
			_make("mock-placement-1", "mock-inv-1", "rock",       "rock",       200.0, 400.0, scene_name),
			_make("mock-placement-2", "mock-inv-2", "grass_fence","grass_fence", 500.0, 600.0, scene_name),
		]
	return []

func place_deco_async(_inventory_item_id: String, _scene_name: String, x: float, y: float) -> DecoPlacement:
	var p := DecoPlacement.new()
	p.id               = "mock-placed-%d" % randi()
	p.inventory_item_id = _inventory_item_id
	p.decor_slug       = "rock"
	p.scene_name       = _scene_name
	p.position_x       = x
	p.position_y       = y
	return p

func batch_move_async(_moves: Array) -> bool:
	return true

func recall_deco_async(_placement_id: String) -> bool:
	return true

func _make(id: String, inv_id: String, decor_id: String, slug: String, x: float, y: float, scene: String) -> DecoPlacement:
	var p := DecoPlacement.new()
	p.id               = id
	p.inventory_item_id = inv_id
	p.decor_id         = decor_id
	p.decor_slug       = slug
	p.scene_name       = scene
	p.position_x       = x
	p.position_y       = y
	return p
