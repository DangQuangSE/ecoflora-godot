# Spec: Weather NPC Reminder

**Date:** 2026-08-04
**Status:** Draft

---

## Problem Statement

Người chơi không có tín hiệu thân thiện nào khi thời tiết trong game thay đổi, dù thời tiết ảnh hưởng đến việc chăm cây (mưa to → cây có thể úng, nắng → cần tưới). Cần một NPC (`eco_npc`) xuất hiện kèm chat bubble để nhắc nhở phù hợp với từng loại thời tiết, ngay khi đang chơi trong vườn.

---

## User Stories

- **[P1]** Là người chơi đang ở GardenScene, tôi muốn thấy `eco_npc` xuất hiện kèm bong bóng thoại khi thời tiết vừa đổi (ví dụ sang RAINY) để biết cần lưu ý gì cho cây.
  Accepted when: `WeatherManager.weather_changed` báo `condition` khác với condition đã nhắc gần nhất trong phiên chơi hiện tại, và người chơi đang ở GardenScene → NPC + bubble hiện ra với 1 câu ngẫu nhiên từ pool ứng với condition đó.

- **[P1]** Là người chơi, tôi không muốn bị nhắc lại liên tục cùng một thời tiết mỗi lần ra vào GardenScene.
  Accepted when: nếu condition hiện tại trùng với condition đã nhắc gần nhất trong phiên, vào lại GardenScene không kích hoạt bubble.

- **[P1]** Là người chơi, tôi muốn bubble tự biến mất sau một khoảng thời gian, hoặc có thể tap để tắt sớm.
  Accepted when: bubble tự fade-out sau khoảng thời gian cấu hình được qua `@export` (Inspector); tap vào NPC hoặc bubble tắt ngay lập tức bất kể timer.

- **[P1]** Là người chơi, tôi muốn câu nhắc phù hợp với loại thời tiết cụ thể (mưa lo úng, nắng nhắc tưới, ...), và không nghe đúng 1 câu lặp lại mỗi lần.
  Accepted when: mỗi giá trị `WeatherState.Condition` (SUNNY, CLOUDY, RAINY, STORM) có pool 2-3 câu nhắc bằng tiếng Việt, chọn ngẫu nhiên 1 câu mỗi lần trigger.

- **[P2]** Là developer, tôi muốn vị trí/style của bubble tách biệt khỏi logic chọn message, để dễ chỉnh UI sau này mà không đụng vào nội dung.
  Accepted when: message catalog (domain, no Node) tách khỏi scene hiển thị (`scenes/`), tuân theo Clean Architecture 4 lớp của dự án.

- **[P3]** _(out of scope)_ Câu nhắc khác nhau giữa ngày/đêm (`is_day`) cho cùng 1 condition.
- **[P3]** _(out of scope)_ Mở rộng thêm loại thời tiết mới ngoài 4 giá trị enum hiện có.
- **[P3]** _(out of scope)_ Hiển thị NPC ở các scene khác ngoài GardenScene.

---

## Functional Requirements

1. FR-01: Thêm domain class (RefCounted, không Node) chứa message pool theo `WeatherState.Condition`, mỗi condition có 2-3 câu tiếng Việt thân thiện, phù hợp ngữ cảnh chăm cây (RAINY → lo úng nước; SUNNY → nhắc tưới cây; CLOUDY/STORM → nội dung tương ứng), theo pattern `TipCatalog.gd` (const Dictionary, không phải .tres/.json).
2. FR-02: KHÔNG thêm autoload mới. `GardenScene.gd` tự subscribe `WeatherManager.weather_changed` trong `_ready()` (theo đúng pattern `UnlockBanner` đã có: `_pending_notifications`, `_active_banner`, `get_tree().root.add_child()`, signal `dismissed`), so sánh `condition` mới với condition đã nhắc gần nhất trong phiên (biến in-memory trong `GardenScene.gd`, không persist); nếu khác → chọn random 1 câu từ pool, instantiate `WeatherNpcBubble.tscn`.
3. FR-03: Bỏ qua lần `weather_changed` đầu tiên nhận được sau khi `GardenScene` vào `_ready()` (do `WeatherManager._ready()` luôn emit ngay cả khi không có thay đổi thực) — dùng cờ `_is_first_weather_signal` tương tự cách xử lý boot-emit, không trigger reminder cho lần emit khởi tạo này.
4. FR-04: Thêm scene `WeatherNpcBubble.tscn` (CanvasLayer, anchor 0.5/0.0, neo dưới các HUD hiện có như VitalityBar/RecallBtn để tránh chồng lấn) chứa sprite `eco_npc` (TextureButton hoặc Sprite2D) + bubble thoại (Label trong Panel).
5. FR-05: `WeatherNpcBubble` tự ẩn (Tween fade-out modulate:a, theo pattern `FloatLabel.gd`) sau `@export var auto_hide_seconds: float`, và tắt ngay khi người chơi tap vào NPC/bubble (TextureButton.pressed, hoặc Control với mouse_filter phù hợp nếu cần bao cả bubble).
6. FR-06: Nếu người chơi rời GardenScene trong lúc bubble đang hiện, bubble phải được dọn dẹp (queue_free) không rò rỉ node khi scene unload — theo đúng cách `_active_banner` được dọn trong `UnlockBanner` flow hiện tại.

---

## Non-Functional Requirements

- Performance: không polling — hoàn toàn signal-driven qua `weather_changed`.
- Architecture: tuân thủ layer rule CLAUDE.md — domain (message pool) không import Node/autoload; không thêm autoload mới (tránh abstraction thừa khi feature chỉ dùng trong 1 scene); logic trigger/dedupe sống trong `GardenScene.gd` theo đúng pattern `UnlockBanner` đã có, `WeatherNpcBubble` chỉ nhận message qua tham số và tự quản lý vòng đời hiển thị.
- Config: `auto_hide_seconds` (và các giá trị tunable khác như fade duration) phải là `@export` để chỉnh trong Inspector, theo `feedback_export_vars`.
- Không dùng `print()` — dùng `push_warning()`/`push_error()` nếu cần log lỗi (ví dụ pool rỗng cho 1 condition).

---

## Success Criteria

- [ ] NPC + bubble hiện đúng nội dung tương ứng khi `mock_condition` trong `WeatherManager` đổi giá trị lúc đang ở GardenScene (test thủ công qua Inspector export var).
- [ ] Không hiện NPC ngay lúc app khởi động (splash/login) dù `weather_changed` emit lần đầu.
- [ ] Vào lại GardenScene với cùng condition đã nhắc trong phiên → không hiện lại bubble.
- [ ] Tap vào NPC/bubble tắt ngay lập tức, không cần chờ hết `auto_hide_seconds`.
- [ ] Mỗi condition có ít nhất 2 câu khác nhau trong pool, xác nhận bằng cách trigger nhiều lần và quan sát nội dung thay đổi.

---

## Out of Scope

- Câu nhắc phân biệt theo `is_day` (ngày/đêm) cho cùng 1 condition.
- Thêm giá trị `Condition` mới ngoài 4 loại hiện có trong `WeatherState`.
- Hiển thị NPC ở scene khác ngoài GardenScene (Shop, Classroom, ...).
- Persist "last shown weather" qua các lần mở app (chỉ cần trong phạm vi 1 phiên chơi/session hiện tại).
- Đồng bộ nội dung nhắc nhở với BE (toàn bộ message pool là local/static trong client).

---

## Assumptions

- "Thời tiết thay đổi" nghĩa là `WeatherState.Condition` đổi giá trị; không tính thay đổi `is_day` là một sự kiện đổi thời tiết riêng.
- `WeatherManager.weather_changed` là nguồn sự kiện duy nhất cần lắng nghe — không cần thêm polling riêng ở `WeatherReminderManager`.
- Vị trí neo NPC trong GardenScene sẽ do `/ck:plan` quyết định dựa trên layout HUD hiện tại (không có yêu cầu cụ thể từ user).

---

## [NEEDS CLARIFICATION]

_(none — vị trí NPC đã chốt: CanvasLayer anchor 0.5/0.0, offset_top ~150-200px, dưới VitalityBar 52×72, tránh RecallBtn 52×52 top-right, dựa theo research kiến trúc trong `/ck:plan`.)_
