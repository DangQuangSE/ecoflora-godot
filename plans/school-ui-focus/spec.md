# Spec: School Scene — UI Rebuild + Layer Fix + Focus Demo

**Feature:** Cải thiện School/Classroom scene và demo focus mode
**Priority order:** Phase 1 → Phase 2 → Phase 3

---

## User Stories

### P1 — Fix layer Player (Phase 2, nhưng trivial — làm sớm)
- Khi vào SchoolScene, Player phải hiển thị trên background, không bị che khuất.

### P1 — UI SchoolScene background
- Background school phải fill đúng màn hình 720×1280 portrait.
- Player đứng trên background, không bị che.
- Portal đến ClassroomScene đặt ở vị trí hợp lý (trước cửa lớp học).

### P1 — UI ClassroomScene background
- ClassroomScene phải có hình nền classroom thật thay vì ColorRect nâu.
- Background fill đúng 720×1280.

### P2 — Demo Focus Mode
- Player bước vào ClassroomTrigger → FocusTimerUI xuất hiện.
- Chọn thời gian → Bắt đầu → countdown hoạt động.
- Kết thúc session → màn hình kết quả hiển thị reward từ BE.
- `bypass_violation_detection = true` trong Inspector khi test trên PC.
- `use_mock = false` — dùng real BE.

---

## Success Criteria

- [ ] Player visible trên background trong SchoolScene (không bị che)
- [ ] SchoolScene background: ảnh fill 720×1280, không scale lệch
- [ ] ClassroomScene background: ảnh classroom thật (không phải ColorRect)
- [ ] FocusTimerUI mở khi Player enter ClassroomTrigger
- [ ] Countdown đếm ngược đúng
- [ ] Result panel hiển thị reward items từ BE sau session hoàn thành

---

## Out of Scope

- Styling/theming FocusTimerUI (chỉ functional)
- Violation detection (cần Android/mobile để test)
- DecoManager integration trong ClassroomScene

---

## Assets Required (chờ user cung cấp)

| File | Mục đích | Kích thước gợi ý |
|------|----------|-----------------|
| `assets/background/school_bg.png` | Background SchoolScene | 720×1280 hoặc lớn hơn |
| `assets/background/classroom_bg.png` | Background ClassroomScene | 720×1280 hoặc lớn hơn |

> **Chú ý:** Tên file trên là gợi ý — user sẽ cung cấp tên thực tế.

---

## Technical Notes

- SchoolScene.tscn: `DemoSchool` z_index = -1 fix layer bug
- SchoolScene.tscn: Thay Sprite2D DemoSchool bằng Sprite2D/TextureRect với ảnh mới, anchor full screen
- ClassroomScene.tscn: Thay ColorRect bằng Sprite2D/TextureRect với ảnh classroom, z_index = -2
- FocusManager.gd: `bypass_violation_detection` là @export — set trong Inspector, không cần đổi code
