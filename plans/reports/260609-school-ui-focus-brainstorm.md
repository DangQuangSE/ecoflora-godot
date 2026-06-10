# Brainstorm: School Scene — UI + Layer + Focus Mode

**Date:** 2026-06-09

## Ideas Explored

- **Fix DemoSchool z_index** — DemoSchool Sprite2D và Player cùng z=0, DemoSchool ở sau trong tree → đè lên Player. Fix z_index = -1 là đủ.
- **Rebuild UI school** — thay demo_school.png (scale lệch) bằng background asset mới do user cung cấp, chỉnh anchor/position đúng cho 720×1280 portrait.
- **Rebuild UI classroom** — ClassroomScene chỉ có ColorRect nâu. User sẽ cung cấp ảnh classroom background để thay.
- **Focus mode demo** — FocusManager + FocusTimerUI + ClassroomScene.gd đã wired hoàn toàn. Test với real BE. Cần `bypass_violation_detection = true` để test trên PC vì NOTIFICATION_APPLICATION_PAUSED không fire trên desktop.
- **Placeholder artwork** — bị loại bỏ vì user có asset thật.

## User's Direction

UI school/classroom trước (chờ asset từ user) → fix layer → demo focus mode với real BE + bypass violation trên PC.

## Open Questions

- User sẽ cung cấp tên file asset background school và classroom — cần biết trước khi implement Phase 1.
- ClassroomTrigger position (360, 400) với shape 200×80: player có dễ trigger không khi đứng ở giữa màn hình không? Có thể cần test và resize.
- FocusTimerUI panel background hiện chỉ dùng default Panel theme — có cần style thêm không?

## Risks

1. Asset school/classroom có thể có kích thước không khớp 720×1280 → cần scale/crop đúng.
2. `bypass_violation_detection` phải nhớ tắt trước khi build release — nên dùng export var chứ không hardcode.
