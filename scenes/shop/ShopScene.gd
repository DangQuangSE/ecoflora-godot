class_name ShopScene
extends Control

const ShopItemCardScene := preload("res://scenes/shop/ShopItemCard.tscn")
const CoinIcon := preload("res://assets/icon/coin.png")
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
	{"id": "character:0", "name": "Mặc định",   "price": 10000, "preview": "res://assets/characters/char_0.tres"},
	{"id": "character:1", "name": "Nhân vật 1", "price": 10000, "preview": "res://assets/characters/char_1.tres"},
]

@onready var _grid: GridContainer     = $ShopPanel/ScrollContainer/GridContainer
@onready var _bg_dimmer: ColorRect    = $BGDimmer
@onready var _close_btn: Button       = $CloseButton
@onready var _pagination_bar: Control = $ShopPanel/PaginationBar
@onready var _prev_btn: Button        = $ShopPanel/PaginationBar/HBox/PrevBtn
@onready var _page_label: Label       = $ShopPanel/PaginationBar/HBox/PageLabel
@onready var _next_btn: Button        = $ShopPanel/PaginationBar/HBox/NextBtn
@onready var _loading: Label          = $LoadingSpinner

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
var _pending_quantity: int = 1
var _pending_quantity_label: Label = null
var _pending_unit_price_label: Label = null
var _pending_multiplier_label: Label = null
var _pending_total_price_label: Label = null
var _pending_balance_label: Label = null
var _pending_confirm_btn: Button = null

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
	if category == "Character":
		if filtered.is_empty():
			filtered = _build_character_items()
		else:
			for item: ShopItem in filtered:
				_apply_character_metadata(item)
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

func _apply_character_metadata(item: ShopItem) -> void:
	var idx := _get_character_index_from_id(item.id)
	if idx < 0:
		return
	var fallback := _get_character_fallback(idx)
	if fallback.is_empty():
		return
	if item.name.strip_edges().is_empty():
		item.name = str(fallback.get("name", item.name))
	item.description = "Nhân vật trang trí — đổi diện mạo trong Profile"
	item.image_url = str(fallback.get("preview", item.image_url))
	item.owned = UserManager.is_character_owned(idx)

func _get_character_index_from_id(id: String) -> int:
	var parts := id.split(":")
	if parts.size() != 2:
		return -1
	return int(parts[1]) if parts[1].is_valid_int() else -1

func _get_character_fallback(idx: int) -> Dictionary:
	for entry: Dictionary in _CHARACTER_CATALOG:
		if _get_character_index_from_id(str(entry.get("id", ""))) == idx:
			return entry
	return {}

func _refresh_tab() -> void:
	var category: String = _TAB_CATEGORIES[_current_tab]
	if category == "Character":
		await _on_tab_pressed(_current_tab)

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
	_pending_quantity = 1
	var balance: int = UserManager.get_profile().currency
	var msg := _purchase_dialog_message(item)
	var dialog := BaseDialog.show_confirm(self, "Xác nhận mua %s" % item.name, msg)
	if dialog == null:
		return
	_setup_purchase_quantity_controls(dialog, item, balance)
	dialog.confirmed.connect(_on_confirm_purchase)
	dialog.cancelled.connect(_clear_pending_purchase)

func _on_confirm_purchase() -> void:
	var item := _pending_item
	if item == null:
		return
	var quantity := maxi(1, _pending_quantity)
	var balance: int = UserManager.get_profile().currency
	var total := item.price * quantity
	if total > balance:
		_show_toast("Không đủ xu!", false)
		_clear_pending_purchase()
		return
	_clear_pending_purchase()
	var result: Dictionary = await UserManager.purchase_async(item.id, quantity)
	if result.is_empty():
		_show_toast("Mua thất bại!", false)
	else:
		AudioManager.play_sfx("res://sounds/buy-successfully.wav")
		_show_toast("Đã mua %s x%d!" % [item.name, quantity], true)
		if item.category == "Character":
			await _refresh_tab()
			return
		await InventoryManager.refresh_async()
		_refresh_card_affordability()

func _clear_pending_purchase() -> void:
	_pending_item = null
	_pending_quantity = 1
	_pending_quantity_label = null
	_pending_unit_price_label = null
	_pending_multiplier_label = null
	_pending_total_price_label = null
	_pending_balance_label = null
	_pending_confirm_btn = null

func _setup_purchase_quantity_controls(dialog: BaseDialog, item: ShopItem, balance: int) -> void:
	dialog.title_label.add_theme_color_override("font_color", Color(0.34, 0.20, 0.10, 1))
	dialog.message_label.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 1))
	dialog.message_label.add_theme_font_size_override("font_size", 16)

	var layout := dialog.get_node_or_null("DialogBox/Content/Layout") as VBoxContainer
	if layout == null:
		return
	var button_row := dialog.get_node_or_null("DialogBox/Content/Layout/ButtonRow") as HBoxContainer
	_pending_confirm_btn = dialog.confirm_btn

	var quantity_box := VBoxContainer.new()
	quantity_box.add_theme_constant_override("separation", 8)
	layout.add_child(quantity_box)
	if button_row != null:
		layout.move_child(quantity_box, button_row.get_index())

	var price_row := HBoxContainer.new()
	price_row.alignment = 1
	price_row.add_theme_constant_override("separation", 5)
	quantity_box.add_child(price_row)
	price_row.add_child(_make_price_caption("Giá:"))
	price_row.add_child(_make_coin_icon())
	_pending_unit_price_label = _make_price_value_label()
	price_row.add_child(_pending_unit_price_label)
	_pending_multiplier_label = _make_price_caption("x 1 =")
	price_row.add_child(_pending_multiplier_label)
	price_row.add_child(_make_coin_icon())
	_pending_total_price_label = _make_price_value_label()
	price_row.add_child(_pending_total_price_label)

	var balance_row := HBoxContainer.new()
	balance_row.alignment = 1
	balance_row.add_theme_constant_override("separation", 5)
	quantity_box.add_child(balance_row)
	balance_row.add_child(_make_price_caption("Số dư:"))
	balance_row.add_child(_make_coin_icon())
	_pending_balance_label = _make_price_value_label()
	balance_row.add_child(_pending_balance_label)

	var controls := HBoxContainer.new()
	controls.alignment = 1
	controls.add_theme_constant_override("separation", 8)
	quantity_box.add_child(controls)

	for delta in [-10, -1]:
		controls.add_child(_make_quantity_button(delta))

	_pending_quantity_label = Label.new()
	_pending_quantity_label.custom_minimum_size = Vector2(84, 38)
	_pending_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pending_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pending_quantity_label.add_theme_font_size_override("font_size", 20)
	_pending_quantity_label.add_theme_color_override("font_color", Color(0.30, 0.17, 0.08, 1))
	controls.add_child(_pending_quantity_label)

	for delta in [1, 10]:
		controls.add_child(_make_quantity_button(delta))

	_update_purchase_quantity_ui(item, balance)

func _make_quantity_button(delta: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(58, 38)
	btn.text = "+%d" % delta if delta > 0 else str(delta)
	btn.add_theme_font_size_override("font_size", 17)
	_apply_quantity_button_style(btn, delta > 0)
	btn.pressed.connect(func() -> void:
		_change_pending_quantity(delta)
	)
	return btn

func _purchase_dialog_message(item: ShopItem) -> String:
	match item.category:
		"Seed":
			return "Chọn số lượng hạt muốn mua."
		"Consumable":
			return "Chọn số lượng vật phẩm muốn mua."
		"Character":
			return "Mở khóa nhân vật này."
	return "Chọn số lượng muốn mua."

func _make_price_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.34, 0.20, 0.10, 1))
	return label

func _make_price_value_label() -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.30, 0.17, 0.08, 1))
	return label

func _make_coin_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = CoinIcon
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _apply_quantity_button_style(btn: Button, is_increase: bool) -> void:
	var normal := _make_quantity_button_style(
		Color(0.42, 0.69, 0.28, 1) if is_increase else Color(0.83, 0.43, 0.30, 1),
		Color(0.23, 0.47, 0.15, 1) if is_increase else Color(0.58, 0.23, 0.16, 1)
	)
	var hover := _make_quantity_button_style(
		Color(0.52, 0.79, 0.35, 1) if is_increase else Color(0.91, 0.52, 0.38, 1),
		Color(0.27, 0.52, 0.18, 1) if is_increase else Color(0.64, 0.28, 0.19, 1)
	)
	var pressed := _make_quantity_button_style(
		Color(0.34, 0.59, 0.22, 1) if is_increase else Color(0.70, 0.34, 0.23, 1),
		Color(0.18, 0.37, 0.12, 1) if is_increase else Color(0.49, 0.18, 0.13, 1)
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	var text_color := Color(0.08, 0.06, 0.03, 1)
	var hover_text_color := Color(0.04, 0.03, 0.02, 1)
	var pressed_text_color := Color(0.12, 0.08, 0.04, 1)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", hover_text_color)
	btn.add_theme_color_override("font_pressed_color", pressed_text_color)
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.75))

func _make_quantity_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 7
	return style

func _change_pending_quantity(delta: int) -> void:
	if _pending_item == null:
		return
	var balance: int = UserManager.get_profile().currency
	var max_affordable := 1
	if _pending_item.price > 0:
		max_affordable = maxi(1, int(floor(float(balance) / float(_pending_item.price))))
	_pending_quantity = clampi(_pending_quantity + delta, 1, max_affordable)
	_update_purchase_quantity_ui(_pending_item, balance)

func _update_purchase_quantity_ui(item: ShopItem, balance: int) -> void:
	var total := item.price * _pending_quantity
	if _pending_quantity_label != null:
		_pending_quantity_label.text = "x%d" % _pending_quantity
	if _pending_unit_price_label != null:
		_pending_unit_price_label.text = str(item.price)
	if _pending_multiplier_label != null:
		_pending_multiplier_label.text = "x %d =" % _pending_quantity
	if _pending_total_price_label != null:
		_pending_total_price_label.text = str(total)
	if _pending_balance_label != null:
		_pending_balance_label.text = str(balance)
	if _pending_confirm_btn != null:
		_pending_confirm_btn.disabled = total > balance

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
