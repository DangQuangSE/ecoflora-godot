class_name InventorySlotNode
extends Button

signal slot_selected(item_id: String)

@onready var _icon: TextureRect = $Icon
@onready var _qty_label: Label = $QtyLabel
@onready var _highlight: Panel = $Highlight

var _item_id: String = ""

func _ready() -> void:
	flat = true
	pressed.connect(_on_pressed)
	InventoryManager.item_selected.connect(_on_global_selection_changed)

func setup(item: InventoryItem, icon_tex: Texture2D) -> void:
	_item_id = item.id
	_icon.texture = icon_tex
	_qty_label.text = "x%d" % item.quantity
	_refresh_highlight()

func _on_pressed() -> void:
	InventoryManager.select_item(_item_id)
	slot_selected.emit(_item_id)

func _on_global_selection_changed(_item: InventoryItem) -> void:
	_refresh_highlight()

func _refresh_highlight() -> void:
	var sel: InventoryItem = InventoryManager.get_selected_item()
	_highlight.visible = sel != null and sel.id == _item_id
