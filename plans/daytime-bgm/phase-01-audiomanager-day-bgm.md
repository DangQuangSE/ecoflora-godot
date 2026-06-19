# Phase 1: AudioManager Day BGM

## Layer

`autoloads`

## Files

| File | Layer | Action |
|------|-------|--------|
| `autoloads/AudioManager.gd` | autoloads | modify |

## Goal

Khi `WeatherState.is_day == true` và `condition` là SUNNY hoặc CLOUDY (không phải auth scene), phát `sunny_sound.mp3` loop với fade 0.5s.

## Implementation Steps

### 1. Đăng ký volume cho sunny track

Trong `BGM_VOLUMES`, thêm:

```gdscript
"res://sounds/sunny_sound.mp3": -10.0,
```

Dùng -10 dB để khớp `night-sound.mp3`; chỉnh sau nếu cần.

### 2. Refactor `update_bgm_for_weather_state()`

Thay nhánh day hiện tại (chỉ `stop_bgm` night) bằng logic đối xứng:

```gdscript
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

	var state = wm.call("get_current_state")
	if state == null:
		return

	const DAY_BGM := "res://sounds/sunny_sound.mp3"
	const NIGHT_BGM := "res://sounds/night-sound.mp3"

	if state.is_day:
		play_bgm(DAY_BGM, true, 0.5)
	else:
		play_bgm(NIGHT_BGM, true, 0.5)
```

`play_bgm` đã có guard: nếu cùng path đang play thì return sớm — không cần check thủ công.

### 3. Không sửa file khác

- `SceneTransition.gd` — đã gọi `update_bgm_for_weather_state()` sau scene load ✓
- `WeatherManager` — đã emit `weather_changed` ✓
- `_connect_weather_manager()` — đã wire signal ✓

## Acceptance Criteria

- [ ] Vào Garden/School lúc `mock_is_day = true` → `sunny_sound.mp3` loop, fade in 0.5s
- [ ] Toggle `mock_is_day = false` → chuyển sang `night-sound.mp3` (fade 0.5s)
- [ ] Toggle lại `true` → quay về sunny
- [ ] Login/Register vẫn phát `lobby_v2.mp3`, không bị sunny chen vào
- [ ] Không có `print()` — chỉ `push_error`/`push_warning` nếu cần
- [ ] `godot --headless --check-only --script res://autoloads/AudioManager.gd` pass

## testing

Manual smoke test (không có unit test AudioManager hiện tại).
