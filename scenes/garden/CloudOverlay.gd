@tool
class_name CloudOverlay
extends Node2D

var _zone_id: String = ""
var _required_level: int = 0
var _tappable: bool = false
var _pulse_tween: Tween = null
var _blink_tween: Tween = null
var _lock_sprite: Sprite2D = null
var _lock_base_scale := Vector2.ONE
var _input_ctrl: Control = null

const SIZE := Vector2(360.0, 228.0)

## Shift the entire overlay in world space to align with the zone plots.
## Adjust after changing Rotation until the cloud sits over the locked plots.
@export var pos_offset: Vector2 = Vector2(0.0, 0.0):
	set(v):
		pos_offset = v
		if Engine.is_editor_hint():
			position = v

## Lock centre inside the 360x228 bounding box (origin = zone top-left).
## Change this in the Inspector to move the lock over the cloud visually.
@export var lock_center: Vector2 = Vector2(220.0, 120.0):
	set(v):
		lock_center = v
		if is_instance_valid(_lock_sprite):
			_lock_sprite.position = v

## Lock display size in world pixels.
@export var lock_size_px: Vector2 = Vector2(80.0, 80.0):
	set(v):
		lock_size_px = v
		if is_instance_valid(_lock_sprite) and _lock_sprite.texture != null:
			var tex_sz := Vector2(_lock_sprite.texture.get_width(), _lock_sprite.texture.get_height())
			_lock_base_scale = lock_size_px / tex_sz
			_lock_sprite.scale = _lock_base_scale

## Inset the click-hit rectangle from each edge so transparent cloud corners don't receive input.
@export var hit_inset: Vector2 = Vector2(50.0, 30.0):
	set(v):
		hit_inset = v
		if is_instance_valid(_input_ctrl):
			_input_ctrl.size     = SIZE - v * 2
			_input_ctrl.position = v

func setup(zone_id: String) -> void:
	_zone_id = zone_id
	if Engine.is_editor_hint():
		return
	var zone := ZoneManager.get_zone(zone_id)
	if zone:
		_required_level = zone.required_level

func _ready() -> void:
	z_index = 5
	_build_ui()
	if Engine.is_editor_hint():
		return
	ZoneManager.zone_notification.connect(_on_notified)
	ZoneManager.zone_unlocked.connect(_on_unlocked)
	var state := ZoneManager.get_zone_state(_zone_id)
	if state == ZoneManager.ZoneState.NOTIFIED:
		_on_notified(_zone_id)
	elif state == ZoneManager.ZoneState.UNLOCKED:
		queue_free()

func _build_ui() -> void:
	# Cloud visual — always anchored at (0,0), never moves with hit_inset
	var cloud := TextureRect.new()
	cloud.texture = preload("res://assets/plot_locked/cloud.png")
	cloud.size = SIZE
	cloud.stretch_mode = TextureRect.STRETCH_SCALE
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud.position = Vector2.ZERO
	add_child(cloud)

	# Input-only control — inset so transparent cloud edges don't capture taps
	_input_ctrl = Control.new()
	_input_ctrl.size     = SIZE - hit_inset * 2
	_input_ctrl.position = hit_inset
	_input_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_input_ctrl)
	if not Engine.is_editor_hint():
		_input_ctrl.gui_input.connect(_on_rect_gui_input)

	_lock_sprite = Sprite2D.new()
	_lock_sprite.texture = preload("res://assets/plot_locked/lock.png")
	var tex_sz := Vector2(_lock_sprite.texture.get_width(), _lock_sprite.texture.get_height())
	_lock_base_scale = lock_size_px / tex_sz
	_lock_sprite.scale = _lock_base_scale
	_lock_sprite.position = lock_center
	add_child(_lock_sprite)
	if not Engine.is_editor_hint():
		_start_pulse()

func _on_notified(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = true
	_start_cloud_blink()

func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_lock_sprite, "scale", _lock_base_scale * 1.2, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_lock_sprite, "scale", _lock_base_scale, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _start_cloud_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(self, "modulate", Color(1.3, 1.15, 0.6, 1.0), 0.55).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_blink_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.55).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_unlocked(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if _blink_tween != null:
		_blink_tween.kill()
		_blink_tween = null
	if ZoneManager.zone_notification.is_connected(_on_notified):
		ZoneManager.zone_notification.disconnect(_on_notified)
	if ZoneManager.zone_unlocked.is_connected(_on_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_unlocked)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

func _on_rect_gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _tappable:
		ZoneManager.request_unlock(_zone_id)
	else:
		_show_lock_popup()

func _show_lock_popup() -> void:
	var popup := LockInfoPopup.new()
	get_tree().root.add_child(popup)
	popup.show_locked(_required_level)
