# Brainstorm: Weather NPC Reminder

**Date:** 2026-08-04

## Ideas Explored

- **A. Gắn vào hệ Tips có sẵn** — thêm category "weather" vào `TipCatalog`/`TipsPanel`. Tái dùng hạ tầng có sẵn nhưng không có NPC/chat bubble, mất cảm giác thân thiện user muốn — dismissed.
- **B. NPC popup mới** — autoload `WeatherReminderManager` map `Condition → message pool`, lắng nghe `weather_changed`, một scene `WeatherNpcBubble.tscn` hiện `eco_npc` + bubble thoại trong GardenScene. — **chosen**.
- Phạm vi hiển thị: cân nhắc global overlay (mọi scene) vs chỉ trong GardenScene. Global bị loại vì `weather_changed` cũng emit lúc `_ready()` của app (splash/login), sẽ gây phiền không đúng ngữ cảnh.
- Cơ chế ẩn bubble: cân nhắc tự-ẩn-only, tap-to-dismiss-only, hoặc cả hai. Chọn cả hai (auto-hide theo `@export` timer + tap để tắt sớm), khớp rule `feedback_export_vars` (mọi giá trị tunable phải `@export`).
- Nội dung câu nhắc: 1 câu cố định/loại vs pool 2-3 câu random/loại. Chọn pool random để đỡ nhàm khi thời tiết lặp lại nhiều lần trong phiên chơi.
- Dedupe khi vào lại GardenScene: cân nhắc luôn nhắc lại theo thời tiết hiện tại mỗi lần vào scene, vs chỉ nhắc khi condition thực sự đổi so với lần nhắc gần nhất (lưu state trong session). Chọn phương án dedupe để tránh spam.

## User's Direction

Người dùng muốn NPC (`eco_npc.png`, asset có sẵn nhưng chưa dùng ở đâu) xuất hiện kèm chat bubble khi thời tiết thay đổi, với câu nhắc phù hợp và thân thiện theo từng loại thời tiết (mưa → lo cây úng, nắng → nhắc tưới cây, ...). Chọn hướng B (NPC popup mới) thay vì gắn vào hệ Tips sẵn có. Giới hạn hiển thị trong GardenScene, tự ẩn theo timer export được kèm tap-to-dismiss, và dùng pool nhiều câu random cho mỗi loại thời tiết.

## Open Questions

- Vị trí neo NPC trong GardenScene (góc màn hình nào) — để `/ck:plan` quyết định dựa trên layout HUD hiện có.
- `is_day` hiện không được dùng để phân biệt nội dung câu nhắc (chỉ dùng `Condition`) — cần xác nhận lại nếu muốn câu nhắc khác nhau giữa ngày/đêm cho cùng 1 condition.
- Cơ chế lưu "last shown weather" nên ở cấp session (reset khi restart app) hay persist qua nhiều lần mở app — spec giả định chỉ cần cấp session.

## Risks

- `Condition` enum chỉ có 4 giá trị (SUNNY/CLOUDY/RAINY/STORM) — nội dung "các loại thời tiết khác" của user bị giới hạn trong 4 loại này, không mở rộng thêm loại mới trong scope này.
- `weather_changed` không phân biệt "đổi thật" vs "app vừa khởi động" — cần logic dedupe rõ ràng ở `WeatherReminderManager`, nếu làm sai sẽ gây bug NPC hiện liên tục hoặc không hiện gì.
- Cần đảm bảo tuân thủ layer rule: `WeatherReminderManager` (autoload) chỉ được đọc `WeatherState`/`WeatherManager`, không import ngược từ `scenes/`.
