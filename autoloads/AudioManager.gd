extends Node

# AudioManager singleton for handling background music (BGM) and sound effects (SFX)

signal volume_settings_changed

const _SETTINGS_PATH := "user://audio_settings.json"
const _MIN_VOLUME_DB := -80.0

const BGM_VOLUMES := {
	"res://sounds/lobby_v2.mp3": -20.0,
	"res://sounds/sunny_sound.mp3": -10.0,
	"res://sounds/night-sound.mp3": -10.0,
	"res://sounds/raining.mp3": -20.0
}

const DAY_BGM := "res://sounds/sunny_sound.mp3"
const NIGHT_BGM := "res://sounds/night-sound.mp3"
const RAIN_BGM := "res://sounds/raining.mp3"
const FOOTSTEP_PATH := "res://sounds/foot_step_v2.mp3"

const SFX_VOLUMES := {
	"res://sounds/item_bag_click.wav": -15.0,
	"res://sounds/plant.wav": -15.0,
	"res://sounds/click.wav": -15.0,
	"res://sounds/harvest.wav": -15.0,
	"res://sounds/watering.wav": -5.0,
	FOOTSTEP_PATH: -10.0
}

var _bgm_player: AudioStreamPlayer
var _current_bgm_path: String = ""
var _fade_tween: Tween
var footstep_stream: AudioStream

var _bgm_volume: float = 1.0
var _sfx_volume: float = 1.0
var _footstep_volume: float = 1.0
var _click_detected: bool = false
var _last_other_sfx_time: int = -1000

func _ready() -> void:
	_load_volume_settings()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	_init_footstep_stream()
	_connect_weather_manager.call_deferred()

func _init_footstep_stream() -> void:
	var loaded := load(FOOTSTEP_PATH) as AudioStream
	if loaded == null:
		push_error("AudioManager: Failed to load footstep from path: %s" % FOOTSTEP_PATH)
		return
	if loaded is AudioStreamMP3:
		(loaded as AudioStreamMP3).loop = true
	footstep_stream = loaded


func get_footstep_stream() -> AudioStream:
	return footstep_stream


func get_footstep_volume_db() -> float:
	return _apply_volume_factor(SFX_VOLUMES.get(FOOTSTEP_PATH, -10.0), _footstep_volume)

func get_bgm_volume_percent() -> int:
	return int(round(_bgm_volume * 100.0))


func get_sfx_volume_percent() -> int:
	return int(round(_sfx_volume * 100.0))


func get_footstep_volume_percent() -> int:
	return int(round(_footstep_volume * 100.0))


func set_bgm_volume_percent(value: int) -> void:
	_bgm_volume = clampf(float(value) / 100.0, 0.0, 1.0)
	_apply_current_bgm_volume()
	_save_volume_settings()
	volume_settings_changed.emit()


func set_sfx_volume_percent(value: int) -> void:
	_sfx_volume = clampf(float(value) / 100.0, 0.0, 1.0)
	_save_volume_settings()
	volume_settings_changed.emit()


func set_footstep_volume_percent(value: int) -> void:
	_footstep_volume = clampf(float(value) / 100.0, 0.0, 1.0)
	_save_volume_settings()
	volume_settings_changed.emit()

func play_sfx(stream_path: String, volume_db: float = 0.0) -> void:
	if stream_path != "res://sounds/click.wav" and stream_path != FOOTSTEP_PATH:
		_last_other_sfx_time = Time.get_ticks_msec()

	var stream := load(stream_path) as AudioStream
	if not stream:
		push_error("AudioManager: Failed to load SFX from path: %s" % stream_path)
		return
		
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = stream
	var target_volume: float = SFX_VOLUMES.get(stream_path, volume_db)
	sfx_player.volume_db = _apply_volume_factor(target_volume, _sfx_volume)
	sfx_player.bus = "Master"
	add_child(sfx_player)
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()

func play_bgm(stream_path: String, loop: bool = true, fade_in_duration: float = 0.0) -> void:
	if _current_bgm_path == stream_path and _bgm_player.playing:
		return
	
	var stream := load(stream_path) as AudioStream
	if not stream:
		push_error("AudioManager: Failed to load BGM from path: %s" % stream_path)
		return
	
	if loop:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	_bgm_player.stream = stream
	_current_bgm_path = stream_path
	
	var target_volume: float = _get_current_bgm_volume_db()
	
	if fade_in_duration > 0.0:
		_bgm_player.volume_db = _MIN_VOLUME_DB
		_bgm_player.play()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm_player, "volume_db", target_volume, fade_in_duration)
	else:
		_bgm_player.volume_db = target_volume
		_bgm_player.play()

func stop_bgm(fade_out_duration: float = 0.0) -> void:
	if not _bgm_player.playing:
		_current_bgm_path = ""
		return
		
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	if fade_out_duration > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm_player, "volume_db", _MIN_VOLUME_DB, fade_out_duration)
		_fade_tween.tween_callback(func() -> void:
			_bgm_player.stop()
			_bgm_player.volume_db = 0.0
			_current_bgm_path = ""
		)
	else:
		_bgm_player.stop()
		_bgm_player.volume_db = 0.0
		_current_bgm_path = ""

func is_bgm_playing() -> bool:
	return _bgm_player.playing

func get_current_bgm_path() -> String:
	return _current_bgm_path


func _get_current_bgm_volume_db() -> float:
	return _apply_volume_factor(BGM_VOLUMES.get(_current_bgm_path, 0.0), _bgm_volume)


func _apply_current_bgm_volume() -> void:
	if _bgm_player == null or _current_bgm_path.is_empty():
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_bgm_player.volume_db = _get_current_bgm_volume_db()


func _apply_volume_factor(base_db: float, factor: float) -> float:
	if factor <= 0.0:
		return _MIN_VOLUME_DB
	return base_db + linear_to_db(factor)


func _load_volume_settings() -> void:
	var file := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	var d := data as Dictionary
	_bgm_volume = clampf(float(d.get("bgm", 1.0)), 0.0, 1.0)
	_sfx_volume = clampf(float(d.get("sfx", 1.0)), 0.0, 1.0)
	_footstep_volume = clampf(float(d.get("footstep", 1.0)), 0.0, 1.0)


func _save_volume_settings() -> void:
	var file := FileAccess.open(_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("AudioManager._save_volume_settings: cannot open %s" % _SETTINGS_PATH)
		return
	file.store_string(JSON.stringify({
		"bgm": _bgm_volume,
		"sfx": _sfx_volume,
		"footstep": _footstep_volume,
	}))

func suppress_click_sfx() -> void:
	_last_other_sfx_time = Time.get_ticks_msec()

func _input(event: InputEvent) -> void:
	var is_click: bool = false
	if event is InputEventMouseButton:
		is_click = event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	elif event is InputEventScreenTouch:
		is_click = not event.pressed

	if is_click:
		if not _click_detected:
			_click_detected = true
			_play_click_deferred.call_deferred()

func _play_click_deferred() -> void:
	if _click_detected:
		var current_time := Time.get_ticks_msec()
		if current_time - _last_other_sfx_time > 250:
			play_sfx("res://sounds/click.wav")
	_click_detected = false

func _connect_weather_manager() -> void:
	var wm = get_node_or_null("/root/WeatherManager")
	if wm == null:
		return
	if not wm.weather_changed.is_connected(_on_weather_changed):
		wm.weather_changed.connect(_on_weather_changed)
	update_bgm_for_weather_state.call_deferred()


func _on_weather_changed(_state: WeatherState) -> void:
	update_bgm_for_weather_state()


func _is_clear_weather(condition: WeatherState.Condition) -> bool:
	return condition == WeatherState.Condition.SUNNY or condition == WeatherState.Condition.CLOUDY


func _is_wet_weather(condition: WeatherState.Condition) -> bool:
	return condition == WeatherState.Condition.RAINY or condition == WeatherState.Condition.STORM


func update_bgm_for_weather_state() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := current_scene.scene_file_path
	var is_auth_scene := scene_path.contains("LoginScene") or scene_path.contains("RegisterScene") or scene_path.contains("SplashScene")
	
	if is_auth_scene:
		return
		
	var wm = get_node_or_null("/root/WeatherManager")
	if wm == null:
		return

	var state: WeatherState = wm.get_current_state()
	if state == null:
		return

	if _is_wet_weather(state.condition):
		play_bgm(RAIN_BGM, true, 0.5)
	elif _is_clear_weather(state.condition):
		if state.is_day:
			play_bgm(DAY_BGM, true, 0.5)
		else:
			play_bgm(NIGHT_BGM, true, 0.5)
