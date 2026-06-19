class_name GameTip
extends RefCounted

var id: String = ""
var title: String = ""
var content: String = ""
var sort_order: int = 0


func _init(p_id: String = "", p_title: String = "", p_content: String = "", p_sort_order: int = 0) -> void:
	id = p_id
	title = p_title
	content = p_content
	sort_order = p_sort_order


static func from_dict(d: Dictionary) -> GameTip:
	var tip := GameTip.new()
	tip.id = str(d.get("id", ""))
	tip.title = str(d.get("title", ""))
	tip.content = str(d.get("content", ""))
	tip.sort_order = int(d.get("sortOrder", d.get("sort_order", 0)))
	return tip


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"content": content,
		"sortOrder": sort_order,
	}
