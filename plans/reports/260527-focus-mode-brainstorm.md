# Brainstorm: Focus Mode (Chế độ Học Tập Trung)

**Date:** 2026-05-27

## Ideas Explored

- **FocusManager autoload** — tách state machine tập trung ra singleton riêng; school scene độc lập với garden. ✅ *Chosen*
- **Gắn vào UserManager** — ít file hơn nhưng vi phạm clean architecture; dismissed.
- **Focus từ HUD button trong garden** — bỏ qua school scene; không khớp project_overview (player phải đi đến trường).
- **Android Foreground Service ngay** — cần Java/Kotlin plugin; deferred vì team chỉ có GDScript hiện tại.

## User's Direction

Full flow 3 lớp: School scene (FPT campus) → in-game focus timer → reward/penalty tích hợp vào garden.
Android background service viết sau, luồng GDScript trước.
- Vi phạm: 1 lần app ra background = 1 violation (đơn giản, không cần grace period).
- Reward: +1 XP/phút cho TẤT CẢ các cây đang có hoa (60 phút = 60 XP/cây).
- Penalty: khi violations > max → session fail → trừ XP (default -20 XP/cây).

## Open Questions

- Max violations mặc định là bao nhiêu? (admin config sau, hardcode = 3 tạm thời)
- School scene art: FPT campus background sẽ dùng ảnh chụp hay pixel art?
- Classroom trigger: Area2D hay NPC dialogue?
- Thời gian focus tối thiểu/tối đa cho phép là bao nhiêu? (5p–120p?)

## Risks

1. **School scene art** — full FPT map cần nhiều asset; nếu thiếu ảnh thì placeholder làm chậm demo.
2. **_notification() trên Android** — `NOTIFICATION_APPLICATION_PAUSED` hoạt động đúng khi app bị minimize nhưng KHÔNG detect khi app bị kill hoàn toàn — cần Android plugin về sau.
3. **XP batch apply** — khi apply +XP cho nhiều cây cùng lúc, phải tránh `is_pending_sync` deadlock nếu nhiều cây đang pending.
