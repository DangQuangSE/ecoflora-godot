# Phase 1: AudioManager Footstep Asset

## Layer

`autoloads`

## Files

| File | Layer | Action |
|------|-------|--------|
| `autoloads/AudioManager.gd` | autoloads | modify |

## Goal

Cung cấp `foot_step_v2.mp3` (loop enabled) qua `get_footstep_stream()`, xóa procedural fallback.

## Implementation Steps

### 1. Thêm constant và volume

```gdscript
const FOOTSTEP_PATH := "res://sounds/foot_step_v2.mp3"
```

Thêm vào `SFX_VOLUMES` (bắt đầu `-10.0`, chỉnh sau khi nghe thử).

### 2. Thay `_init_footstep_stream()`

- Load `FOOTSTEP_PATH`
- Nếu `AudioStreamMP3`: set `loop = true`
- Gán vào `footstep_stream`
- Nếu load fail: `push_error`, không gọi `_generate_procedural_footstep()`

### 3. Xóa dead code

- Xóa `_generate_procedural_footstep()` (~40 dòng)
- Đổi kiểu `footstep_stream` và return type `get_footstep_stream()` → `AudioStream` (không còn chỉ WAV)

### 4. Cập nhật `play_sfx` click-suppress exclusion

Đổi `footstep.wav` → `FOOTSTEP_PATH` trong điều kiện loại trừ click SFX (nếu footstep không đi qua `play_sfx` thì có thể bỏ qua).

## Acceptance Criteria

- [ ] `get_footstep_stream()` trả về `AudioStreamMP3` với `loop = true`
- [ ] Không còn procedural footstep code
- [ ] Load fail → `push_error`, stream = null

## testing

Manual — verified in Phase 2 smoke test.
