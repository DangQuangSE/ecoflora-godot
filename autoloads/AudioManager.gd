extends Node

# AudioManager singleton for handling background music (BGM) and sound effects (SFX)

const BGM_VOLUMES := {
	"res://sounds/lobby.mp3": -40.0
}

const SFX_VOLUMES := {
	"res://sounds/item_bag_click.wav": -25.0
}

var _bgm_player: AudioStreamPlayer
var _current_bgm_path: String = ""
var _fade_tween: Tween
var footstep_stream: AudioStreamWAV

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	_init_footstep_stream()

func _init_footstep_stream() -> void:
	var custom_path := "res://sounds/footstep.wav"
	if FileAccess.file_exists(custom_path):
		var loaded = load(custom_path)
		if loaded is AudioStreamWAV:
			footstep_stream = loaded
			return
			
	_generate_procedural_footstep()

func _generate_procedural_footstep() -> void:
	footstep_stream = AudioStreamWAV.new()
	footstep_stream.format = AudioStreamWAV.FORMAT_16_BITS
	footstep_stream.mix_rate = 11025
	footstep_stream.stereo = false
	footstep_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var duration := 0.12 # 120 ms
	var num_samples := int(footstep_stream.mix_rate * duration)
	
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2) # 16-bit = 2 bytes per sample
	
	var lp_state := 0.0
	var alpha := 0.94 # Strong low-pass filter (only low frequencies pass)
	
	for i in range(num_samples):
		var t := float(i) / num_samples
		var envelope := exp(-t * 14.0) * (1.0 - t) # Faster decay for a softer touch
		
		var white_noise := randf() * 2.0 - 1.0
		# Muffle the sound by low-passing the white noise
		lp_state = (lp_state * alpha) + (white_noise * (1.0 - alpha))
		
		# Lower amplitude scale (10000.0 instead of 32767.0) for a quieter, gentler sound
		var sample_val := lp_state * envelope
		var sample := int(sample_val * 10000.0)
		
		# Clip sample to 16-bit range
		sample = clamp(sample, -32768, 32767)
		
		# Store 16-bit signed integer in little-endian format
		var byte_idx := i * 2
		byte_data[byte_idx] = sample & 0xFF
		byte_data[byte_idx + 1] = (sample >> 8) & 0xFF
		
	footstep_stream.data = byte_data

func get_footstep_stream() -> AudioStreamWAV:
	return footstep_stream

func play_sfx(stream_path: String, volume_db: float = 0.0) -> void:
	var stream := load(stream_path) as AudioStream
	if not stream:
		push_error("AudioManager: Failed to load SFX from path: %s" % stream_path)
		return
		
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = stream
	var target_volume: float = SFX_VOLUMES.get(stream_path, volume_db)
	sfx_player.volume_db = target_volume
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
	
	var target_volume: float = BGM_VOLUMES.get(stream_path, 0.0)
	
	if fade_in_duration > 0.0:
		_bgm_player.volume_db = -80.0
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
