# Spec: Focus Mode Trigger Button

**Feature:** Button cố định trong ClassroomScene để mở FocusTimerUI

---

## User Stories

### P1 — Button trigger
- Khi ở ClassroomScene, có một Button hiển thị cố định trên màn hình
- Nhấn button → FocusTimerUI popup xuất hiện đè lên scene
- Nếu FocusTimerUI đã mở (session đang active), button bị disable

### P1 — Duration minimum 10 phút
- Slider trong SetupPanel: min = 10, max = 120, step = 5, default = 25
- Label hiển thị đúng giá trị đã chọn

### P1 — Xóa ClassroomTrigger
- Xóa ClassroomTrigger (Area2D) khỏi ClassroomScene.tscn
- Xóa `_trigger` onready và `_on_trigger_body_entered` khỏi ClassroomScene.gd

---

## Success Criteria

- [ ] Button visible trong ClassroomScene khi chạy game
- [ ] Nhấn button → FocusTimerUI mở, slider bắt đầu từ 10p
- [ ] Nhấn button khi đã có session → không mở thêm (button disabled)
- [ ] ClassroomTrigger Area2D không còn trong scene tree

---

## Technical Notes

- Button đặt trong CanvasLayer (layer thấp, e.g. 5) để luôn hiện trên scene nhưng dưới FocusTimerUI (layer 10)
- ClassroomScene.gd: thêm `@onready var _focus_btn: Button = $FocusLayer/FocusButton`
- Khi FocusManager state = ACTIVE: `_focus_btn.disabled = true`
- Khi session kết thúc (completed/failed/cancelled): `_focus_btn.disabled = false`
- Slider min_value = 10 trong cả FocusTimerUI.gd và FocusTimerUI.tscn
