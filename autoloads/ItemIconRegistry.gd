extends Node

var _icons: Dictionary = {}
var _fallback: Texture2D

func _ready() -> void:
	_fallback = load("res://assets/icon/bag.png")
	_try_register("lotus",        "res://assets/flowers/lotus/lotus 3.png")
	_try_register("rose",         "res://assets/flowers/rose/rose 3.png")
	_try_register("periwinkle",   "res://assets/flowers/periwinkle/periwinkle 3.png")
	_try_register("watering_can", "res://assets/icon/watering_can.PNG")
	_try_register("fertilizer",   "res://assets/icon/fertilizer.png")
	_try_register("sickle",       "res://assets/icon/sickle.png")

func register(ref_id: String, texture: Texture2D) -> void:
	_icons[ref_id] = texture

func get_icon(ref_id: String) -> Texture2D:
	if _icons.has(ref_id):
		return _icons[ref_id]
	return _fallback

func get_plant_texture(template_id: String, stage: int) -> Texture2D:
	var img_num := 1
	if stage >= 7:
		img_num = 3
	elif stage >= 4:
		img_num = 2
	var path := "res://assets/flowers/%s/%s %d.png" % [template_id, template_id, img_num]
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _try_register(ref_id: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_icons[ref_id] = load(path)
	else:
		push_warning("ItemIconRegistry: icon not found at %s" % path)
