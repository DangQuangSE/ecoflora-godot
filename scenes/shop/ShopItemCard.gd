class_name ShopItemCard
extends PanelContainer

# Required nodes in ShopItemCard.tscn:
# - ItemIcon (TextureRect)
# - NameLabel (Label)
# - PriceLabel (Label)
# - TapArea (Button) — invisible, covers whole card

signal tapped(item: ShopItem)

@onready var _item_icon: TextureRect = $VBoxContainer/ItemIcon
@onready var _name_label: Label      = $VBoxContainer/NameLabel
@onready var _price_label: Label     = $VBoxContainer/PriceLabel
@onready var _tap_area: Button       = $TapArea

var _item: ShopItem

func setup(item: ShopItem) -> void:
	_item = item
	_name_label.text  = item.name
	_price_label.text = "%d 🪙" % item.price
	_load_icon(item)
	if not item.is_active:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
		_tap_area.disabled = true

func _load_icon(item: ShopItem) -> void:
	if item.image_url.begins_with("res://") and ResourceLoader.exists(item.image_url):
		_item_icon.texture = load(item.image_url)
		return
	var local_path := "res://assets/shop/%s.png" % item.id
	if ResourceLoader.exists(local_path):
		_item_icon.texture = load(local_path)
		return
	_item_icon.texture = ItemIconRegistry.get_icon(item.id)

func _ready() -> void:
	_tap_area.pressed.connect(_on_tapped)

func _on_tapped() -> void:
	if _item != null:
		tapped.emit(_item)
