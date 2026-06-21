# Phase 1: Watering SFX

testing: default

## Layer

`autoloads/`

## Files

| File | Layer | Action |
|---|---|---|
| `sounds/watering.wav` | asset | EXISTS — Godot auto-import |
| `autoloads/AudioManager.gd` | autoloads | MODIFY — thêm SFX_VOLUMES entry |
| `autoloads/GardenManager.gd` | autoloads | MODIFY — play_sfx khi water optimistic |

---

## Requirements

Khi hành động tưới nước (action_type / action_value == 0) pass tất cả guard và apply optimistic state:

- Phát `AudioManager.play_sfx("res://sounds/watering.wav")`
- Không phát khi action bị reject trước optimistic apply
- Không phát cho fertilize (1) hoặc pesticide (2)

---

## Steps

### 1. AudioManager.gd — SFX_VOLUMES

Thêm entry cạnh plant/harvest:

```gdscript
const SFX_VOLUMES := {
	"res://sounds/item_bag_click.wav": -15.0,
	"res://sounds/plant.wav": -15.0,
	"res://sounds/click.wav": -15.0,
	"res://sounds/harvest.wav": -15.0,
	"res://sounds/watering.wav": -15.0,
	FOOTSTEP_PATH: -10.0
}
```

### 2. GardenManager.gd — Mock path

Trong `_mock_care`, sau guards pass, trước `plot.is_pending_sync = true`:

```gdscript
if action_type == 0:
	AudioManager.play_sfx("res://sounds/watering.wav")
plot.is_pending_sync = true
```

### 3. GardenManager.gd — BE path

Trong `_care_apply_optimistic`, gộp vào block `action_value == 0`:

```gdscript
if action_value == 0:
	plot.current_plant.last_watered_at = int(Time.get_unix_time_from_system())
	AudioManager.play_sfx("res://sounds/watering.wav")
```

`_care_apply_optimistic` chỉ được gọi từ `_care_action` sau khi pass guards — đúng chỗ phát sound.

### 4. Asset import

Không cần code — mở Godot editor một lần để tạo `watering.wav.import`.

---

## Success Criteria

- [ ] Mock mode: water occupied plot → watering.wav plays
- [ ] BE mode: water occupied plot → watering.wav plays at optimistic (before HTTP completes)
- [ ] Max stage block in Plot.gd → no sound
- [ ] Fertilize / pesticide → no watering.wav

---

## Smoke Test Checklist

1. Chạy garden scene (mock mode)
2. Chọn watering can → tap plot có hoa → nghe watering.wav
3. Thử fertilize → không nghe watering.wav
4. Thử water plot max stage (blocked in Plot.gd) → không nghe
5. (Optional BE) water với backend → sound ngay lập tức, không đợi response

---

## Risks

| Risk | Mitigation |
|---|---|
| Import missing | Open Godot once |
| Sound on BE rollback | Chấp nhận — cùng pattern plant/harvest (optimistic only) |
