# Spec: Weather Sync & Day/Night Cycle

**Date:** 2026-05-28
**Status:** Draft

---

## Problem Statement

Game hiện không phản ánh thời tiết và thời gian thực, khiến trải nghiệm thiếu tính sống động. Tính năng này đồng bộ thời tiết từ BE và hiển thị hiệu ứng mưa/bão/ngày/đêm trực quan trên màn hình garden.

---

## User Stories

- **[P1]** As a player, I want to see rain particles falling when it's raining outside so that the garden feels connected to the real world.
  Accepted when: MockWeatherService trả về RAINY → GardenScene hiện GPUParticles2D mưa rơi dọc.

- **[P1]** As a player, I want to see storm effects (rain + wind) when there's a storm so that severe weather feels more intense.
  Accepted when: condition = STORM → rain particles dày hơn + wind particles nghiêng ngang.

- **[P1]** As a player, I want the garden to darken at night based on real sunrise/sunset time so that the game feels alive over the course of a day.
  Accepted when: current Unix time ngoài range [sunrise, sunset] → DayNightOverlay ColorRect hiện với opacity > 0.

- **[P2]** As a player, I want weather to transition smoothly (fade in/out) when conditions change so that it doesn't feel jarring.
  Accepted when: particles/overlay fade qua tween ≥ 0.5s khi condition thay đổi.

- **[P2]** As a player, I want CLOUDY condition to have slightly dimmed lighting so that overcast days look different from sunny ones.
  Accepted when: CLOUDY → ColorRect gray tint ở opacity 0.15.

- **[P3]** _(out of scope — weather affects plant growth rate: rain = +10% XP/tick)_

---

## Functional Requirements

1. **FR-01:** `WeatherManager` autoload poll `WeatherService` mỗi 600 giây (10 phút). Kết quả được cache; nếu request fail thì giữ state cũ.
2. **FR-02:** `WeatherManager` emit signal `weather_changed(state: WeatherState)` mỗi khi condition hoặc is_day thay đổi.
3. **FR-03:** `WeatherState` chứa: `condition` (enum SUNNY/CLOUDY/RAINY/STORM), `is_day` (bool tính từ sunrise_unix/sunset_unix vs current Unix time).
4. **FR-04:** `WeatherOverlay.tscn` (CanvasLayer layer=1) chứa: `RainParticles` (CPUParticles2D), `WindParticles` (CPUParticles2D), `DayNightOverlay` (ColorRect full-screen). Layer=1 đặt overlay trên scene world nhưng dưới toàn bộ UI (HUD layer=10, FocusTimerUI layer=10).
5. **FR-05:** `MockWeatherService` cho phép set condition thủ công qua code trong `WeatherManager._ready()` để test từng loại thời tiết.
6. **FR-06:** `WeatherService` (real) gọi HTTP GET đến BE endpoint, parse JSON response — endpoint URL set qua `_weather_service.endpoint` trong WeatherManager._ready().
7. **FR-07:** WeatherOverlay được WeatherManager autoload tự thêm làm child node — không cần thêm thủ công vào từng scene.
8. **FR-08:** Particle amount tối đa: mưa ≤ 300, gió ≤ 150 — giới hạn cứng trong scene để bảo vệ FPS mobile.

---

## Non-Functional Requirements

- **Performance:** FPS không giảm quá 10% so với baseline khi STORM active trên thiết bị mid-range (test Godot mobile renderer).
- **Resilience:** Nếu BE không trả lời trong 5 giây, giữ nguyên state hiện tại (không crash, không hiện lỗi với user).
- **Extensibility:** Swap MockWeatherService → WeatherService chỉ cần đổi 1 dòng trong WeatherManager._ready().

---

## Success Criteria

- [ ] GardenScene hiện rain particles khi MockWeatherService.condition = RAINY
- [ ] STORM hiện cả rain lẫn wind particles đồng thời
- [ ] DayNightOverlay tối lên khi is_day = false (kiểm tra bằng cách set sunset_unix = current time - 1)
- [ ] WeatherManager không crash khi WeatherService trả về null/timeout
- [ ] Thay 1 dòng `MockWeatherService` → `WeatherService` trong WeatherManager là đủ để dùng real API

---

## Out of Scope

- Weather ảnh hưởng gameplay (XP, growth rate, cooldown) — P3
- SchoolScene / ClassroomScene có WeatherOverlay — thêm sau khi GardenScene ổn
- Smooth camera shake khi bão
- Snow / fog condition
- Backend implementation của weather API

---

## Assumptions

- BE sẽ trả JSON với ít nhất: `condition` (string), `sunrise` (Unix int UTC), `sunset` (Unix int UTC).
- Godot `Time.get_unix_time_from_system()` đủ chính xác để so sánh với sunrise/sunset UTC.
- GPUParticles2D hoạt động tốt trên Android với mobile renderer (đã dùng trong project).

---

## [NEEDS CLARIFICATION]

- [ ] Format JSON chính xác của BE endpoint (field names, condition string values) — điền khi BE sẵn sàng.
