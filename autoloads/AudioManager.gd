extends Node

# AudioManager singleton for handling background music (BGM) and sound effects (SFX)

var _bgm_player: AudioStreamPlayer
var _current_bgm_path: String = ""
var _fade_tween: Tween

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

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
	
	if fade_in_duration > 0.0:
		_bgm_player.volume_db = -80.0
		_bgm_player.play()
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_in_duration)
	else:
		_bgm_player.volume_db = 0.0
		_bgm_player.play()

func stop_bgm(fade_out_duration: float = 0.0) -> void:
	if not _bgm_player.playing:
		_current_bgm_path = ""
		return
		
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	if fade_out_duration > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_out_duration)
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
