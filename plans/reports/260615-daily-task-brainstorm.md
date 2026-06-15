# Brainstorm: Daily Task Feature

**Date:** 2026-06-15

## Ideas Explored

- **Battle Pack (subscription)** — gói tháng, nạp tiền nhận reward xịn hơn. User có đề cập nhưng deferred — cần payment flow phức tạp hơn.
- **Daily Task only (client-side)** — lưu local như harvest_products. Nhanh nhưng user chọn backend.
- **Daily Task (server-driven)** — mỗi action push lên BE. Secure nhưng spam request, không phù hợp scope EXE2.
- **Daily Task hybrid (local track + BE claim)** — client track bằng signals có sẵn, chỉ gọi BE lúc claim reward. ← **CHỌN**
- **Online time task** — track phút online mỗi ngày bằng timer client-side.
- **Login streak** — đăng nhập liên tiếp X ngày. Đơn giản nhưng user muốn "time in app" hơn.

## User's Direction

Daily Task với architecture Hybrid: client lắng nghe signals → track progress local → claim lên BE nhận reward.

Task types:
- Garden actions: tưới/bón phân/xịt thuốc N lần, thu hoạch N hoa
- Focus session: hoàn thành X session, hoặc Y phút focus
- Online time: online ít nhất X phút/ngày (client timer)

Cycle: Daily (reset 7:00 AM) + Weekly (reset Thứ 2 7:00 AM).
Reward: Currency, Seed/Item, XP bonus.
Backend: eco-backend — cần build từ đầu (không có endpoint nào).

## Open Questions

- Cần BE team confirm schema và reset timezone (server UTC hay UTC+7?)
- Số lượng task mỗi ngày là bao nhiêu? (3? 5?)
- Task list có hardcode client hay lấy từ /api/daily-tasks?
- Weekly task scope: định nghĩa trước hay để P2?
- Battle Pack có được integrate vào daily task reward không? (P3)

## Risks

1. **Signal gap**: GardenManager không có signal riêng cho water/fertilize/pesticide count. Cần thêm `care_completed(plot_id, action_type)` — đụng vào GardenManager, cần phối hợp với member không làm Synergy.
2. **7AM reset complexity**: Reset theo giờ server (UTC+7) yêu cầu BE trả về `serverTime` để client đồng bộ, tránh lệch múi giờ device.
3. **BE scope**: Toàn bộ DailyTask controller, entity, migration là công việc mới cho BE team — cần estimate riêng.
