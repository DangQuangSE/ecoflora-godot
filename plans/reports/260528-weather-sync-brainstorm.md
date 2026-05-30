# Brainstorm: Weather Sync & Day/Night Cycle

**Date:** 2026-05-28

## Ideas Explored

- **Full API-driven (chosen):** BE gọi weather API, trả về condition + sunrise/sunset. Game poll mỗi 10 phút, WeatherManager autoload quản lý state.
- **Device clock only:** Ngày/đêm từ giờ máy, không qua BE. Đơn giản nhưng mất sunrise/sunset chính xác theo vị trí.
- **Real-time (1 phút):** Gần live nhưng tốn request BE, không cần thiết cho visual.
- **GardenScene-only:** Nhét logic vào 1 scene, nhanh nhưng không dùng được ở SchoolScene/ClassroomScene.
- **Gọi thẳng OpenWeatherMap từ game:** Lộ API key, bỏ qua.

## User's Direction

Visual-first: đổi background tint + particle effects (mưa, gió). Gameplay effect (cây lớn nhanh khi mưa) để sau.  
Poll mỗi 10–15 phút từ BE. Ngày/đêm theo sunrise/sunset từ API.  
Dùng MockWeatherService trước, swap real API sau — giống pattern MockGardenService hiện tại.  
Visual dùng GPUParticles2D (built-in Godot) + ColorRect overlay cho ngày/đêm.

## Open Questions

- Format JSON chính xác BE trả về (condition string, sunrise/sunset format) — sẽ điền khi có endpoint.
- WeatherOverlay thêm vào từng scene thủ công hay tự add từ WeatherManager?

## Risks

- GPUParticles2D có thể ảnh hưởng FPS trên mobile low-end — cần giới hạn particle amount.
- Nếu BE offline, game phải fallback gracefully (giữ state cũ hoặc về SUNNY mặc định).
- Sunrise/sunset tính theo múi giờ: cần đảm bảo BE trả Unix timestamp (UTC) để game tự convert.
