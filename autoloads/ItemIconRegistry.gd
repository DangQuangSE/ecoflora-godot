extends Node

var _icons: Dictionary = {}
var _plant_name_by_id: Dictionary = {}  # template_id → asset folder name (for BE UUID templates)
var _fallback: Texture2D

func _ready() -> void:
	_fallback = load("res://assets/icon/bag.png")
	_try_register("lotus",        "res://assets/flowers/lotus/lotus 3.png")
	_try_register("rose",         "res://assets/flowers/rose/rose 3.png")
	_try_register("periwinkle",   "res://assets/flowers/periwinkle/periwinkle 3.png")
	_try_register("watering_can", "res://assets/icon/watering_can.png")
	_try_register("fertilizer",   "res://assets/icon/fertilizer.png")
	_try_register("sickle",       "res://assets/icon/sickle.png")
	_try_register("grass_fence",  "res://assets/shop/deco/grass_fence.png")
	_try_register("rock",         "res://assets/shop/deco/rock.png")
	_try_register("stone_fence",  "res://assets/shop/deco/stone_fence.png")
	_try_register("supper_fence", "res://assets/shop/deco/supper_fence.png")
	_try_register("warterfall",   "res://assets/shop/deco/warterfall.png")
	_try_register("warter_tower", "res://assets/shop/deco/warter_tower.png")

func register(ref_id: String, texture: Texture2D) -> void:
	_icons[ref_id] = texture

func has_icon(ref_id: String) -> bool:
	return _icons.has(ref_id)

func get_icon(ref_id: String) -> Texture2D:
	if _icons.has(ref_id):
		return _icons[ref_id]
	return _fallback

## Registers a name mapping for a BE UUID template so get_plant_texture can find the asset.
func register_plant_name(template_id: String, asset_name: String) -> void:
	_plant_name_by_id[template_id] = asset_name

func get_plant_texture(template_id: String, stage: int) -> Texture2D:
	# Stage 0 = just planted → shared sprout sprite
	if stage == 0:
		var sprout := "res://assets/flowers/sprout.png"
		if ResourceLoader.exists(sprout):
			return load(sprout)
		return null
	# Stage 1-3 → flower-specific sprite
	var img_num: int = clampi(stage, 1, 3)
	var name_key: String = _plant_name_by_id.get(template_id, template_id)
	for ext: String in ["png", "PNG"]:
		var path := "res://assets/flowers/%s/%s %d.%s" % [name_key, name_key, img_num, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

func _try_register(ref_id: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_icons[ref_id] = load(path)
	else:
		push_warning("ItemIconRegistry: icon not found at %s" % path)
