class_name SettingsPanel
extends Control

@onready var _close_btn: Button = $Panel/CloseBtn
@onready var _backdrop: ColorRect = $Backdrop
@onready var _settings_tab: Button = $Panel/VBox/TabMargin/TabRow/SettingsTab
@onready var _support_tab: Button = $Panel/VBox/TabMargin/TabRow/SupportTab
@onready var _settings_page: Control = $Panel/VBox/SettingsPage
@onready var _support_page: Control = $Panel/VBox/SupportPage
@onready var _bgm_slider: HSlider = $Panel/VBox/SettingsPage/Rows/BgmRow/Slider
@onready var _bgm_value: Label = $Panel/VBox/SettingsPage/Rows/BgmRow/Value
@onready var _sfx_slider: HSlider = $Panel/VBox/SettingsPage/Rows/SfxRow/Slider
@onready var _sfx_value: Label = $Panel/VBox/SettingsPage/Rows/SfxRow/Value
@onready var _footstep_slider: HSlider = $Panel/VBox/SettingsPage/Rows/FootstepRow/Slider
@onready var _footstep_value: Label = $Panel/VBox/SettingsPage/Rows/FootstepRow/Value
@onready var _email_btn: Button = $Panel/VBox/SupportPage/Rows/EmailBtn
@onready var _facebook_btn: Button = $Panel/VBox/SupportPage/Rows/FacebookBtn
@onready var _tiktok_btn: Button = $Panel/VBox/SupportPage/Rows/TiktokBtn
@onready var _youtube_btn: Button = $Panel/VBox/SupportPage/Rows/YoutubeBtn
@onready var _terms_btn: Button = $Panel/VBox/SettingsPage/Rows/TermsBtn
@onready var _gift_code_btn: Button = $Panel/VBox/SettingsPage/Rows/GiftCodeBtn

const _EMAIL := "treesforfuture.eco@gmail.com"
const _FACEBOOK_URL := "https://www.facebook.com/profile.php?id=61581382018162"
const _TIKTOK_URL := "https://www.tiktok.com/@chamflora.eco"
const _YOUTUBE_URL := "https://www.youtube.com/@e.c.o-greentechgamification"
const _TERMS_URL := "https://eco-frontend-zeta.vercel.app/term?tab=terms"

var _syncing := false


func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(hide_panel)
	_backdrop.gui_input.connect(_on_backdrop_input)
	_settings_tab.pressed.connect(func() -> void: _show_tab(true))
	_support_tab.pressed.connect(func() -> void: _show_tab(false))
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_footstep_slider.value_changed.connect(_on_footstep_changed)
	_email_btn.pressed.connect(func() -> void: OS.shell_open("mailto:%s" % _EMAIL))
	_facebook_btn.pressed.connect(func() -> void: OS.shell_open(_FACEBOOK_URL))
	_tiktok_btn.pressed.connect(func() -> void: OS.shell_open(_TIKTOK_URL))
	_youtube_btn.pressed.connect(func() -> void: OS.shell_open(_YOUTUBE_URL))
	_terms_btn.pressed.connect(_on_terms_pressed)
	_gift_code_btn.pressed.connect(_on_gift_code_pressed)
	_sync_from_audio()
	_show_tab(true)


func show_panel() -> void:
	_sync_from_audio()
	_show_tab(true)
	visible = true


func hide_panel() -> void:
	visible = false


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			hide_panel()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		hide_panel()


func _sync_from_audio() -> void:
	_syncing = true
	_bgm_slider.value = AudioManager.get_bgm_volume_percent()
	_sfx_slider.value = AudioManager.get_sfx_volume_percent()
	_footstep_slider.value = AudioManager.get_footstep_volume_percent()
	_update_value_labels()
	_syncing = false


func _on_bgm_changed(value: float) -> void:
	if _syncing:
		return
	AudioManager.set_bgm_volume_percent(int(round(value)))
	_update_value_labels()


func _on_sfx_changed(value: float) -> void:
	if _syncing:
		return
	AudioManager.set_sfx_volume_percent(int(round(value)))
	_update_value_labels()


func _on_footstep_changed(value: float) -> void:
	if _syncing:
		return
	AudioManager.set_footstep_volume_percent(int(round(value)))
	_update_value_labels()


func _update_value_labels() -> void:
	_bgm_value.text = "%d%%" % int(round(_bgm_slider.value))
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value))
	_footstep_value.text = "%d%%" % int(round(_footstep_slider.value))


func _show_tab(show_settings: bool) -> void:
	_settings_page.visible = show_settings
	_support_page.visible = not show_settings
	_settings_tab.button_pressed = show_settings
	_support_tab.button_pressed = not show_settings


func _on_terms_pressed() -> void:
	OS.shell_open(_TERMS_URL)


func _on_gift_code_pressed() -> void:
	GiftCodeRedeemDialog.show_dialog(get_tree().root)
