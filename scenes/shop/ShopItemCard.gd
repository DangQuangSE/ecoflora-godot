class_name ShopItemCard
extends Control

signal tapped(item: ShopItem)

@onready var _item_icon: TextureRect = $VBoxContainer/ItemIcon
@onready var _name_label: Label      = $VBoxContainer/NameLabel
@onready var _price_label: Label     = $VBoxContainer/PriceRow/PriceLabel
@onready var _buy_btn: Button        = $VBoxContainer/BuyButton

var _item: ShopItem

func setup(item: ShopItem, balance: int = -1) -> void:
	_item = item
	_name_label.text  = item.name
	_price_label.text = str(item.price)
	_load_icon(item)
	if not item.is_active:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
		_buy_btn.disabled = true
	else:
		_buy_btn.disabled = balance >= 0 and balance < item.price

func set_affordable(affordable: bool) -> void:
	if _item == null or not _item.is_active:
		return
	_buy_btn.disabled = not affordable

func item_price() -> int:
	return _item.price if _item != null else 0

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
	_buy_btn.pressed.connect(_on_tapped)

func _on_tapped() -> void:
	if _item != null:
		tapped.emit(_item)
