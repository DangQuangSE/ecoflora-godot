# Phase 2: Player Continuous Footstep

## Layer

`scenes`

## Files

| File | Layer | Action |
|------|-------|--------|
| `scenes/shared/Player.gd` | scenes | modify |

## Goal

Phát / dừng tiếng chân theo trạng thái di chuyển thay vì timer interval.

## Implementation Steps

### 1. Xóa timer-based logic

Xóa:
- `_footstep_timer`
- `FOOTSTEP_INTERVAL`
- `_play_footstep_sound()` (random pitch)

### 2. Thêm state tracking

```gdscript
var _was_moving: bool = false
```

### 3. Viết lại `_handle_footsteps()`

Dùng cùng ngưỡng velocity hiện có (`velocity.length() > 10.0`):

```gdscript
func _handle_footsteps(_delta: float) -> void:
	if _footstep_player == null or _footstep_player.stream == null:
		return

	var is_moving := velocity.length() > 10.0

	if is_moving:
		if not _footstep_player.playing:
			_footstep_player.play()  # từ đầu clip
	else:
		if _footstep_player.playing:
			_footstep_player.stop()

	_was_moving = is_moving
```

**Hành vi đạt được:**
| Sự kiện | Kết quả |
|---------|---------|
| Bắt đầu đi | `play()` từ đầu |
| Đang đi | player tiếp tục; stream loop khi hết |
| Dừng | `stop()` |
| Đi lại | `play()` từ đầu (vì đã stop) |

### 4. Cấu hình volume trong `_ready()`

Đọc volume từ `AudioManager` (qua `SFX_VOLUMES` constant hoặc helper mới `get_footstep_volume_db()` nếu cần — tránh hardcode `volume_db = 5`).

Không random `pitch_scale` — giữ `1.0` cho âm thanh mềm tự nhiên.

### 5. Không sửa scene `.tscn`

`AudioStreamPlayer2D` vẫn tạo trong code `_ready()` như hiện tại.

## Acceptance Criteria

- [ ] Di chuyển → tiếng chân phát liên tục
- [ ] Dừng → im lặng
- [ ] Đi lại → phát từ đầu, không resume giữa clip
- [ ] Clip loop khi đi dài
- [ ] Garden, School, Classroom — cùng behavior (shared Player)

## testing

Manual smoke test per plan.md checklist.
