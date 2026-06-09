# Brainstorm: Focus Mode Trigger UI

**Date:** 2026-06-10

## Ideas Explored

- **Area2D trigger** (hiện tại) — player đi vào vùng tự động mở UI. Bị loại vì background là ảnh tĩnh, không có object interactable thật.
- **Button cố định trên màn hình** — CanvasLayer Button, user tự đặt vị trí trong editor. Được chọn: đơn giản, không cần player di chuyển.
- **Button gắn vào player** — hiện nút khi player đứng yên. Bị loại vì phức tạp hơn cần.
- **Tự động khi vào scene** — dialog mở ngay khi load ClassroomScene. Bị loại vì không tự nhiên.

## User's Direction

Button cố định trên CanvasLayer. Nhấn → popup dialog chọn thời gian. Vị trí user tự drag trong Godot editor.

## Open Questions

- Không có — scope rõ ràng.

## Risks

1. ClassroomTrigger bị xóa — nếu sau này muốn trigger kiểu khác phải thêm lại.
2. Slider min=10 thay vì 5 — cần đổi cả trong .gd lẫn .tscn để đồng bộ.
