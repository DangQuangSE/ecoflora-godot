# Spec: Zone Unlock System

**Date:** 2026-05-26
**Status:** Ready

---

## Problem Statement

Sau 8 plot ban đầu, game thiếu cơ chế progression không gian. Người chơi cần có mục tiêu dài hạn để tiếp tục chăm vườn — mở khóa khu đất mới bằng cách đạt level là phần thưởng rõ ràng và trực quan.

---

## User Stories

- **[P1]** As a player, I want to see cloud-covered zones on the map so that I know there is more land to unlock.
  Accepted when: Khi vào GardenScene, 2 zone mới hiển thị trên map với đám mây phủ kín (placeholder texture), không tương tác được với plots bên dưới.

- **[P1]** As a player, I want to receive a banner notification when I reach the required level so that I know a zone is now unlockable.
  Accepted when: Khi level_up đạt Lv3 (hoặc Lv6), một banner trung tâm hiện lên "Khu vườn mới đã mở khóa! Tap đám mây để xua tan." Player tap banner để đóng.

- **[P1]** As a player, I want to tap the cloud to dismiss it so that I feel agency in the unlock moment.
  Accepted when: Sau khi banner đóng, đám mây của zone tương ứng chuyển sang trạng thái tappable (glow/pulse animation). Tap vào đám mây → fade out trong 0.6s → plots bên dưới trở nên tương tác được.

- **[P2]** As a player, I want cloud to pulse/glow when zone is unlockable so that I know which cloud to tap.
  Accepted when: Đám mây animate nhẹ (scale pulse hoặc alpha flicker) khi zone ở trạng thái "notified but not dismissed".

- **[P3]** _(out of scope — thêm zone thứ 3+, cooldown, zone-specific rewards)_

---

## Functional Requirements

1. **FR-01:** `ZoneDefinition` domain class (RefCounted): `zone_id: String`, `required_level: int`, `world_position: Vector2` (top-left góc zone trên map).
2. **FR-02:** `ZoneManager` autoload (extends Node): giữ 2 `ZoneDefinition`, track trạng thái từng zone (`locked` / `notified` / `unlocked`). Emits `zone_notification(zone_id)` và `zone_unlocked(zone_id)`.
3. **FR-03:** ZoneManager kết nối `UserManager.level_up` trong `_ready()`. Khi new_level >= required_level của zone chưa notified → emit `zone_notification`.
4. **FR-04:** `Plot.gd` thêm `zone_id: String` (rỗng = initial plot) và `is_zone_locked: bool` (false = initial). PlotNode chặn toàn bộ gui_input khi `is_zone_locked == true`.
5. **FR-05:** `GardenManager` thêm zone plots vào `_plots` (8 zone plots mới = 2 zones × 4 plots). Zone plots có `is_zone_locked = true` khi init. Method `unlock_zone(zone_id)` set `is_zone_locked = false` cho tất cả plots thuộc zone đó.
6. **FR-06:** `ZoneNode.tscn` — Node2D chứa 4 PlotNode + `CloudOverlay` (Node2D với Sprite2D placeholder, CanvasItem layer cao hơn plots). Đặt tại `world_position` của zone.
7. **FR-07:** `CloudOverlay.gd` — lắng nghe `ZoneManager.zone_notification` để chuyển sang tappable state (pulse animation). Khi được tap: gọi `ZoneManager.request_unlock(zone_id)` → nhận `zone_unlocked` signal → fade out 0.6s → queue_free.
8. **FR-08:** `UnlockBanner.tscn/gd` — CanvasLayer layer=11 (trên HUD). Hiển thị text "Khu vườn mới đã mở khóa! Tap đám mây để xua tan." Tap banner để đóng. Auto-spawned bởi GardenScene khi nhận `zone_notification`.
9. **FR-09:** `ZoneManager.request_unlock(zone_id)` chỉ xử lý khi zone ở trạng thái `notified`. Emit `zone_unlocked`, gọi `GardenManager.unlock_zone(zone_id)`.

---

## Non-Functional Requirements

- Layer order: CloudOverlay trên PlotSprite, dưới HUD. Dùng z_index trên Node2D.
- UnlockBanner CanvasLayer layer=11 (trên HUD layer=10).
- Cloud placeholder: ColorRect lớn màu trắng/xanh xám cho đến khi có texture thực.
- ZoneManager phải đăng ký trong project.godot SAU UserManager.

---

## Success Criteria

- [ ] Chạy game → 2 zone mới hiển thị với cloud overlay, plots không tương tác được.
- [ ] Thu hoạch đủ XP để lên Lv3 → banner "Zone mới mở khóa" xuất hiện ở trung tâm màn hình.
- [ ] Tap banner → đóng lại; đám mây Zone 1 pulse/glow.
- [ ] Tap đám mây Zone 1 → fade out 0.6s → 4 plots Zone 1 có thể trồng cây bình thường.
- [ ] Zone 2 vẫn bị khóa cho đến khi đạt Lv6.
- [ ] Initial 8 plots không bị ảnh hưởng.

---

## Out of Scope

- Hình ảnh đám mây thực (user cung cấp sau, dùng placeholder)
- Lưu trạng thái unlock vào file (in-memory MVP)
- Zone thứ 3 trở lên
- Điều kiện mở khóa khác ngoài level (VD: coins, quests)

---

## Assumptions

- TileMap đã có đủ không gian cho 2 zone mới (hoặc cần mở rộng — đây là việc của Editor, không phải code).
- Zone 1 position: Vector2(360, 80) (bên phải zone ban đầu), Zone 2 position: Vector2(360, 320) — **[NEEDS CLARIFICATION: vị trí chính xác phụ thuộc vào TileMap layout]**
- `Plot.gd` thêm 2 fields mới không phá vỡ deep_copy() hay bất kỳ logic hiện tại.
- Mỗi zone có đúng 4 plots, layout 2×2 (2 cột × 2 hàng, cách nhau 120px như initial plots).
