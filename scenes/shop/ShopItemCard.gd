class_name ShopItemCard
extends Control

signal tapped(item: ShopItem)

const _DEFAULT_CARD_SIZE := Vector2(195, 230)
const _DEFAULT_ICON_HEIGHT := 104.0
const _CHARACTER_CARD_SIZE := Vector2(195, 300)
const _CHARACTER_PREVIEW_HEIGHT := 174.0
const _CHARACTER_PREVIEW_SIZE := Vector2i(175, 174)
const _CHARACTER_PREVIEW_CENTER := Vector2(87, 92)
const _CHARACTER_PREVIEW_SCALE := Vector2(0.45, 0.45)

@onready var _item_icon: TextureRect = $VBoxContainer/ItemIcon
@onready var _name_label: Label      = $VBoxContainer/NameLabel
@onready var _price_label: Label     = $VBoxContainer/PriceRow/PriceLabel
@onready var _buy_btn: Button        = $VBoxContainer/BuyButton

var _item: ShopItem

func setup(item: ShopItem, balance: int = -1) -> void:
	_item = item
	_name_label.text = item.name
	_clear_char_preview()
	if item.category == "Character" and item.image_url.ends_with(".tres") \
			and ResourceLoader.exists(item.image_url):
		_apply_character_layout()
		_setup_animated_preview(item.image_url)
	else:
		_apply_default_layout()
		_load_icon(item)
	if item.owned:
		_price_label.text = "Đã sở hữu"
		_buy_btn.disabled = true
	elif not item.is_active:
		_price_label.text = str(item.price)
		modulate = Color(0.5, 0.5, 0.5, 1.0)
		_buy_btn.disabled = true
	else:
		_price_label.text = str(item.price)
		_buy_btn.disabled = balance >= 0 and balance < item.price

func _clear_char_preview() -> void:
	_item_icon.show()
	for child: Node in $VBoxContainer.get_children():
		if child.name == "CharPreview":
			child.free()
			break

func _apply_default_layout() -> void:
	custom_minimum_size = _DEFAULT_CARD_SIZE
	_item_icon.custom_minimum_size = Vector2(0, _DEFAULT_ICON_HEIGHT)

func _apply_character_layout() -> void:
	custom_minimum_size = _CHARACTER_CARD_SIZE
	_item_icon.custom_minimum_size = Vector2(0, _CHARACTER_PREVIEW_HEIGHT)

func _setup_animated_preview(tres_path: String) -> void:
	_item_icon.hide()
	var svpc := SubViewportContainer.new()
	svpc.name = "CharPreview"
	svpc.custom_minimum_size = Vector2(0, _CHARACTER_PREVIEW_HEIGHT)
	svpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svpc.stretch = true
	var sv := SubViewport.new()
	sv.size = _CHARACTER_PREVIEW_SIZE
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load(tres_path)
	sprite.play("idle_down")
	sprite.position = _CHARACTER_PREVIEW_CENTER
	sprite.scale = _CHARACTER_PREVIEW_SCALE
	sv.add_child(sprite)
	svpc.add_child(sv)
	var vbox := $VBoxContainer
	vbox.add_child(svpc)
	vbox.move_child(svpc, _item_icon.get_index())

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
	if not item.image_url.is_empty() and ItemIconRegistry.has_icon(item.image_url):
		_item_icon.texture = ItemIconRegistry.get_icon(item.image_url)
		return
	# Icons are registered by bare UUID — strip "seed:" / "item:" / "deco:" prefix
	var lookup := item.id
	for pfx: String in ["seed:", "item:", "deco:"]:
		if item.id.begins_with(pfx):
			lookup = item.id.substr(pfx.length())
			break
	_item_icon.texture = ItemIconRegistry.get_icon(lookup)

func _ready() -> void:
	_buy_btn.pressed.connect(_on_tapped)

func _on_tapped() -> void:
	if _item != null:
		tapped.emit(_item)
