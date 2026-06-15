class_name GameTip
extends RefCounted

var id: String = ""
var category_id: String = ""
var title: String = ""
var body: String = ""


func _init(p_id: String, p_category_id: String, p_title: String, p_body: String) -> void:
	id = p_id
	category_id = p_category_id
	title = p_title
	body = p_body
