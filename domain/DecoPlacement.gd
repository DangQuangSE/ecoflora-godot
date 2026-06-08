class_name DecoPlacement
extends RefCounted

var id: String = ""
var inventory_item_id: String = ""
var decor_id: String = ""
var decor_slug: String = ""
var decor_image_url: String = ""
var scene_name: String = ""
var position_x: float = 0.0
var position_y: float = 0.0

static func from_dict(d: Dictionary) -> DecoPlacement:
	var p := DecoPlacement.new()
	p.id               = str(d.get("id", ""))
	p.inventory_item_id = str(d.get("inventoryItemId", ""))
	p.decor_id         = str(d.get("decorId", ""))
	p.decor_slug       = str(d.get("decorSlug", ""))
	p.decor_image_url  = str(d.get("decorImageUrl", ""))
	p.scene_name       = str(d.get("sceneName", ""))
	p.position_x       = float(d.get("x", 0.0))
	p.position_y       = float(d.get("y", 0.0))
	return p
