class_name ShopScene
extends Control

const ShopItemCardScene := preload("res://scenes/shop/ShopItemCard.tscn")
var _style_tab_normal  := StyleBoxFlat.new()
var _style_tab_active  := StyleBoxFlat.new()
var _style_tab_hover   := StyleBoxFlat.new()
var _style_skeleton_card := StyleBoxFlat.new()
var _style_skeleton_band := StyleBoxFlat.new()

# Tab index → API category string ("" = no API call, "Coin" = local top-up packages, no API call)
const _TAB_CATEGORIES := ["Seed", "Consumable", "Character", "Decoration", "Coin"]

# Coin top-up packages — matches eco-backend's seeded CoinPackage rows
# (10 coin = 1.000đ, no admin CRUD for MVP). Real purchase happens on the
# game's web top-up page, not in-app — see plans/coin-topup-payos/spec.md
# Out of Scope (Google Play anti-steering policy). Tapping a card only
# shows a note telling the player where to go; no link, no API call.
const _COIN_PACKAGES := [
	{"vnd": 20000,  "coin": 200},
	{"vnd": 50000,  "coin": 500},
	{"vnd": 100000, "coin": 1000},
	{"vnd": 200000, "coin": 2000},
]

const _CHARACTER_CATALOG := [
	{"id": "character:0", "name": "Mặc định",   "price": 0,     "preview": "res://assets/characters/char_0_thumb.png"},
	{"id": "character:1", "name": "Nhân vật 1", "price": 10000, "preview": "res://assets/characters/char_1_thumb.png"},
]

@onready var _grid: GridContainer        = $ShopPanel/ScrollContainer/GridContainer
@onready var _bg_dimmer: ColorRect       = $BGDimmer
@onready var _close_btn: Button          = $CloseButton
@onready var _pagination_bar: Control    = $ShopPanel/PaginationBar
@onready var _prev_btn: Button           = $ShopPanel/PaginationBar/HBox/PrevBtn
@onready var _page_label: Label          = $ShopPanel/PaginationBar/HBox/PageLabel
@onready var _next_btn: Button           = $ShopPanel/PaginationBar/HBox/NextBtn
@onready var _confirm_overlay: ColorRect = $ConfirmOverlay
@onready var _confirm_dialog: Control    = $ConfirmDialog
@onready var _confirm_name: Label        = $ConfirmDialog/VBox/ItemNameLabel
@onready var _confirm_desc: Label        = $ConfirmDialog/VBox/ItemDescLabel
@onready var _confirm_price: Label       = $ConfirmDialog/VBox/PriceRow/PriceLabel
@onready var _confirm_balance: Label     = $ConfirmDialog/VBox/PriceRow/BalanceHint
@onready var _qty_minus: Button          = $ConfirmDialog/VBox/QuantityRow/MinusButton
@onready var _qty_label: Label           = $ConfirmDialog/VBox/QuantityRow/QuantityLabel
@onready var _qty_plus: Button           = $ConfirmDialog/VBox/QuantityRow/PlusButton
@onready var _total_label: Label         = $ConfirmDialog/VBox/TotalRow/TotalLabel
@onready var _confirm_btn: Button        = $ConfirmDialog/VBox/ButtonRow/ConfirmButton
@onready var _cancel_btn: Button         = $ConfirmDialog/CancelButton
@onready var _loading: Label             = $LoadingSpinner

const _ITEMS_PER_PAGE := 6

const _SEED_NAME_VI: Dictionary = {
	"anthurium":         "Hạt Hồng Môn",
	"lotus":             "Hạt Hoa Sen",
	"periwinkle":        "Hạt Hoa Dừa Cạn",
	"purple_bellflower": "Hạt Hoa Chuông Tím",
	"rose":              "Hạt Hoa Hồng",
	"sun_flower":        "Hạt Hướng Dương",
	"tulip":             "Hạt Hoa Tulip",
}

const _TOOL_NAME_VI: Dictionary = {
	"watering can": "Bình Tưới Nước",
	"fertilizer":   "Phân Bón",
	"pesticide":    "Thuốc Trừ Sâu",
}

var _tab_btns: Array = []
var _current_items: Array[ShopItem] = []
var _current_page: int = 0
var _current_tab: int = 0
var _pending_item: ShopItem = null
var _pending_qty: int = 1

func _ready() -> void:
	_build_tab_styles()
	_build_skeleton_styles()
	_tab_btns = [
		$ShopPanel/ShopBg/TabGroup/HatGiongBtn,
		$ShopPanel/ShopBg/TabGroup/CongCuBtn,
		$ShopPanel/ShopBg/TabGroup/NhanVatBtn,
		$ShopPanel/ShopBg/TabGroup/TrangTriBtn,
		$ShopPanel/ShopBg/TabGroup/CoinBtn,
	]
	for i in _tab_btns.size():
		var idx := i
		var btn := _tab_btns[i] as Button
		btn.pressed.connect(func() -> void: _on_tab_pressed(idx))
		btn.add_theme_constant_override("outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.95))
	_close_btn.pressed.connect(_on_back)
	_bg_dimmer.gui_input.connect(_on_bg_dimmer_input)
	_prev_btn.pressed.connect(_on_prev_page)
	_next_btn.pressed.connect(_on_next_page)
	_confirm_btn.pressed.connect(_on_confirm_purchase)
	_cancel_btn.pressed.connect(_hide_dialog)
	_confirm_overlay.gui_input.connect(_on_overlay_input)
	_qty_minus.pressed.connect(_on_qty_minus)
	_qty_plus.pressed.connect(_on_qty_plus)
	_confirm_dialog.hide()
	_confirm_overlay.hide()
	_loading.hide()

func _build_tab_styles() -> void:
	for s in [_style_tab_normal, _style_tab_active, _style_tab_hover]:
		s.corner_radius_top_left  = 14
		s.corner_radius_top_right = 14
		s.border_width_left  = 2
		s.border_width_top   = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.border_color = Color(0.45, 0.27, 0.09, 1)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 8
		s.content_margin_bottom = 10
	
	_style_tab_normal.bg_color = Color(0.55, 0.32, 0.12, 1)
	_style_tab_hover.bg_color  = Color(0.68, 0.43, 0.18, 1)
	_style_tab_active.bg_color = Color(1.0, 0.93, 0.74, 1)
	_style_tab_active.border_color = Color(0.78, 0.49, 0.16, 1)

func _build_skeleton_styles() -> void:
	_style_skeleton_card.content_margin_left = 10
	_style_skeleton_card.content_margin_top = 10
	_style_skeleton_card.content_margin_right = 10
	_style_skeleton_card.content_margin_bottom = 10
	_style_skeleton_card.bg_color = Color(0.93, 0.88, 0.76, 0.92)
	_style_skeleton_card.border_width_left = 2
	_style_skeleton_card.border_width_top = 2
	_style_skeleton_card.border_width_right = 2
	_style_skeleton_card.border_width_bottom = 4
	_style_skeleton_card.border_color = Color(0.68, 0.56, 0.38, 0.65)
	_style_skeleton_card.corner_radius_top_left = 12
	_style_skeleton_card.corner_radius_top_right = 12
	_style_skeleton_card.corner_radius_bottom_right = 12
	_style_skeleton_card.corner_radius_bottom_left = 12

	_style_skeleton_band.bg_color = Color(1.0, 0.96, 0.84, 0.70)
	_style_skeleton_band.corner_radius_top_left = 12
	_style_skeleton_band.corner_radius_top_right = 12
	_style_skeleton_band.corner_radius_bottom_right = 12
	_style_skeleton_band.corner_radius_bottom_left = 12

func _on_tab_pressed(idx: int) -> void:
	_set_active_tab(idx)
	_current_tab = idx
	_current_page = 0
	var category: String = _TAB_CATEGORIES[idx]
	if category == "Coin":
		_current_items = _build_coin_packages()
		_render_page()
		return
	if category == "Character":
		_current_items = _build_character_items()
		_render_page()
		return
	if category.is_empty():
		_current_items = []
		_render_page()
		return
	_set_loading(true)
	var items: Array[ShopItem] = await UserManager.get_shop_catalog_async(category)
	_set_loading(false)
	if _current_tab != idx:
		return
	var filtered := _filter_known_seeds(items)
	for item: ShopItem in filtered:
		_localize_item(item)
	_current_items = filtered
	_render_page()

func _build_coin_packages() -> Array[ShopItem]:
	var packages: Array[ShopItem] = []
	for i in _COIN_PACKAGES.size():
		var pkg: Dictionary = _COIN_PACKAGES[i]
		var item := ShopItem.new()
		item.id = "coin:%d" % i
		item.name = "%s đ" % _format_vnd(pkg.vnd)
		item.description = "Nạp coin qua trang web của game"
		item.price = pkg.coin
		item.category = "Coin"
		item.image_url = "res://assets/icon/coin.png"
		item.is_active = true
		packages.append(item)
	return packages

func _build_character_items() -> Array[ShopItem]:
	var items: Array[ShopItem] = []
	for entry: Dictionary in _CHARACTER_CATALOG:
		var idx: int = int((entry["id"] as String).split(":")[1])
		var item := ShopItem.new()
		item.id = entry["id"]
		item.name = entry["name"]
		item.description = "Nhân vật trang trí — đổi diện mạo trong Profile"
		item.price = entry["price"]
		item.category = "Character"
		item.image_url = entry["preview"]
		item.is_active = true
		item.owned = UserManager.is_character_owned(idx)
		items.append(item)
	return items

func _refresh_tab() -> void:
	var category: String = _TAB_CATEGORIES[_current_tab]
	if category == "Character":
		_current_items = _build_character_items()
		_render_page()

func _format_vnd(amount: int) -> String:
	var digits := str(amount)
	var grouped := ""
	for i in digits.length():
		var pos_from_right := digits.length() - i
		if i > 0 and pos_from_right % 3 == 0:
			grouped += "."
		grouped += digits[i]
	return grouped

func _set_loading(on: bool) -> void:
	_loading.visible = false
	if on:
		for child in _grid.get_children():
			child.queue_free()
		_render_loading_skeleton()
		_pagination_bar.visible = false

func _render_loading_skeleton() -> void:
	for i in _ITEMS_PER_PAGE:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(195, 230)
		card.add_theme_stylebox_override("panel", _style_skeleton_card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		card.add_child(box)

		var icon := Panel.new()
		icon.custom_minimum_size = Vector2(0, 104)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.add_theme_stylebox_override("panel", _style_skeleton_band)
		box.add_child(icon)

		var name_placeholder := Panel.new()
		name_placeholder.custom_minimum_size = Vector2(118, 16)
		name_placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		name_placeholder.add_theme_stylebox_override("panel", _style_skeleton_band)
		box.add_child(name_placeholder)

		var price := Panel.new()
		price.custom_minimum_size = Vector2(58, 14)
		price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		price.add_theme_stylebox_override("panel", _style_skeleton_band)
		box.add_child(price)

		var button := Panel.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("panel", _style_skeleton_band)
		box.add_child(button)

		_grid.add_child(card)

func _render_page() -> void:
	var total: int = _current_items.size()
	var total_pages: int = maxi(1, int(ceil(float(total) / _ITEMS_PER_PAGE)))
	var start: int = _current_page * _ITEMS_PER_PAGE
	_render_items(_current_items.slice(start, start + _ITEMS_PER_PAGE))
	_page_label.text = "%d/%d" % [_current_page + 1, total_pages]
	_prev_btn.disabled = _current_page <= 0
	_next_btn.disabled = _current_page >= total_pages - 1
	_pagination_bar.visible = total_pages > 1

func _on_prev_page() -> void:
	if _current_page > 0:
		_current_page -= 1
		_render_page()

func _on_next_page() -> void:
	var total_pages: int = maxi(1, int(ceil(float(_current_items.size()) / _ITEMS_PER_PAGE)))
	if _current_page < total_pages - 1:
		_current_page += 1
		_render_page()

func _set_active_tab(idx: int) -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i] as Button
		var is_active := i == idx
		btn.add_theme_stylebox_override("normal",   _style_tab_active if is_active else _style_tab_normal)
		btn.add_theme_stylebox_override("pressed",  _style_tab_active)
		btn.add_theme_stylebox_override("hover",    _style_tab_active if is_active else _style_tab_hover)
		
		var font_color := Color(0.61, 0.31, 0.07, 1) if is_active else Color(0.97, 0.86, 0.60, 1)
		btn.add_theme_color_override("font_color", font_color)
		btn.add_theme_color_override("font_hover_color", font_color)
		btn.add_theme_color_override("font_pressed_color", font_color)
		btn.add_theme_constant_override("outline_size", 2 if is_active else 1)

func _render_items(items: Array[ShopItem]) -> void:
	for child in _grid.get_children():
		child.queue_free()
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Sắp ra mắt..." if _TAB_CATEGORIES[_current_tab].is_empty() else "Trống"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.55, 1))
		_grid.call_deferred("add_child", lbl)
		return
	# Coin packages aren't bought with in-game currency, so skip the
	# balance-affordability check that applies to every other tab.
	var is_coin_tab: bool = _TAB_CATEGORIES[_current_tab] == "Coin"
	var balance: int = -1 if is_coin_tab else UserManager.get_profile().currency
	for item: ShopItem in items:
		var card: ShopItemCard = ShopItemCardScene.instantiate()
		_grid.add_child(card)
		card.setup(item, balance)
		card.tapped.connect(_on_item_tapped)

func _refresh_card_affordability() -> void:
	var balance: int = UserManager.get_profile().currency
	for child in _grid.get_children():
		if child is ShopItemCard:
			(child as ShopItemCard).set_affordable(balance >= (child as ShopItemCard).item_price())

func _on_item_tapped(item: ShopItem) -> void:
	if item.category == "Coin":
		_show_toast("Vui lòng truy cập trang web của game để nạp coin nhé!", true)
		return
	_pending_item = item
	_pending_qty = 1
	_confirm_name.text = item.name
	_confirm_desc.text = item.description
	_confirm_price.text = str(item.price)
	_confirm_balance.text = " (số dư: %d)" % UserManager.get_profile().currency
	_qty_label.text = "1"
	_update_dialog_total()
	_confirm_overlay.show()
	_confirm_dialog.show()

func _update_dialog_total() -> void:
	if _pending_item == null:
		return
	var total: int = _pending_item.price * _pending_qty
	_total_label.text = "Tổng: %d" % total
	_confirm_btn.disabled = UserManager.get_profile().currency < total

func _on_qty_minus() -> void:
	if _pending_qty <= 1:
		return
	_pending_qty -= 1
	_qty_label.text = str(_pending_qty)
	_update_dialog_total()

func _on_qty_plus() -> void:
	_pending_qty += 1
	_qty_label.text = str(_pending_qty)
	_update_dialog_total()

func _hide_dialog() -> void:
	_confirm_dialog.hide()
	_confirm_overlay.hide()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_dialog()

func _on_confirm_purchase() -> void:
	if _pending_item == null:
		return
	var item := _pending_item
	var qty  := _pending_qty
	_hide_dialog()
	_confirm_btn.disabled = true
	var result: Dictionary = await UserManager.purchase_async(item.id, qty)
	_confirm_btn.disabled = false
	_pending_item = null
	if result.is_empty():
		_show_toast("Mua thất bại!", false)
	else:
		AudioManager.play_sfx("res://sounds/buy-successfully.wav")
		_show_toast("Đã mua %s ×%d!" % [item.name, qty], true)
		if item.category == "Character":
			_refresh_tab()
			return
		await InventoryManager.refresh_async()
		_refresh_card_affordability()

func _show_toast(message: String, success: bool) -> void:
	Toast.show_message(self, message, 2.0 if success else 2.4)

func show_panel(tab_idx: int = 0) -> void:
	show()
	_on_tab_pressed(tab_idx)
	AudioManager.play_sfx("res://sounds/item_bag_click.wav")

func _filter_known_seeds(items: Array[ShopItem]) -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for item: ShopItem in items:
		if item.category == "Seed" and not _SEED_NAME_VI.has(item.name.to_lower()):
			continue
		result.append(item)
	return result

func _localize_item(item: ShopItem) -> void:
	var name_lower := item.name.to_lower()
	match item.category:
		"Seed":
			item.name = _SEED_NAME_VI.get(name_lower, item.name)
			item.description = "Hạt giống hoa, trồng vào ô đất trống"
		"Consumable":
			item.name = _TOOL_NAME_VI.get(name_lower, item.name)
			var uuid := item.id.substr(len("item:"))
			item.description = _tool_desc(uuid)

func _tool_desc(uuid: String) -> String:
	var cache: Dictionary = GardenManager.get_item_cache().get(uuid, {})
	if cache.is_empty():
		return ""
	var xp: int = cache.get("received_exp", 0)
	var cd: int = cache.get("cooldown_time", 0)
	return "+%d XP · %s" % [xp, _fmt_cd(cd)]

func _fmt_cd(seconds: int) -> String:
	if seconds <= 0:
		return "không hồi chiêu"
	if seconds % 3600 == 0:
		return "hồi chiêu %d giờ" % int(float(seconds) / 3600.0)
	if seconds % 60 == 0:
		return "hồi chiêu %d phút" % int(float(seconds) / 60.0)
	return "hồi chiêu %d giây" % seconds

func _on_bg_dimmer_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
					or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if is_tap:
		_on_back()

func _on_back() -> void:
	AudioManager.play_sfx("res://sounds/item_bag_click.wav")
	hide()
