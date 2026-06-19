# Phase 1: Reorder VitalityBar VBox Children

testing: default

## Layer

`scenes/`

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/hud/VitalityBar.tscn` | scenes | MODIFY — đổi thứ tự node trong VBoxContainer |
| `scenes/hud/HUD.tscn` | scenes | VERIFY — chỉ sửa offset nếu layout tràn sau reorder |

---

## Requirements

Đổi thứ tự children của `VBoxContainer` trong `VitalityBar.tscn`:

**Hiện tại (sai):**
```
HeartIcon → TipsButton → CountdownLabel
```

**Mong muốn (đúng):**
```
HeartIcon → CountdownLabel → TipsButton
```

Không thay đổi tên node, script, texture, hay kích thước từng phần tử.

---

## Steps

1. Mở `scenes/hud/VitalityBar.tscn`.
2. Trong `VBoxContainer`, kéo `CountdownLabel` lên giữa `HeartIcon` và `TipsButton` (hoặc sửa thứ tự node trong file `.tscn`).
3. Xác nhận `custom_minimum_size` root `VitalityBar` vẫn `Vector2(72, 148)` — không cần đổi vì chỉ reorder, không thêm/bớt node.
4. **Không sửa** `VitalityBar.gd` — các `@onready` path vẫn hợp lệ.
5. Mở `HUD.tscn`, chạy scene garden, kiểm tra vị trí VitalityBar (`offset_top=158`, `offset_bottom=306`). Chỉ điều chỉnh offset nếu chồng UI khác.

---

## Success Criteria

- [ ] Tim ở trên cùng
- [ ] Text countdown ("Sẵn sàng!" hoặc `MM:SS`) ngay dưới tim
- [ ] Icon sách (`tip_icon_v2.png`) ở dưới cùng
- [ ] Claim vitality (tap tim khi ready) hoạt động
- [ ] Tap icon sách mở/đóng TipsPanel
- [ ] Không lỗi console khi chạy main scene

---

## Smoke Test Checklist

1. Chạy main scene (garden view)
2. Nhìn cột trái: xác nhận thứ tự tim → countdown → sách
3. Đợi hoặc mock vitality ready → tap tim → popup thưởng
4. Tap icon sách → TipsPanel mở → tap lại → đóng
5. Kiểm tra portrait không chồng coin bar / joystick

---

## Risks

- Reorder thuần túy — rủi ro thấp, không ảnh hưởng logic async/sync
