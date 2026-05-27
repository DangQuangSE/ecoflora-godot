# Spec: User Avatar + XP System

**Date:** 2026-05-26
**Status:** Ready

---

## Problem Statement

Người chơi cần thấy tiến trình phát triển nhân vật của mình khi chăm sóc vườn. Hiện tại chưa có cơ chế thưởng XP cho user, khiến việc thu hoạch thiếu cảm giác thành tựu.

---

## User Stories

- **[P1]** As a player, I want to see my avatar and XP bar at the top-left of the screen so that I always know my current level and progress.
  Accepted when: Avatar + XP bar hiển thị trong HUD ở mọi thời điểm khi đang ở GardenScene.

- **[P1]** As a player, I want to earn XP when I harvest a flower so that I feel rewarded for tending my garden.
  Accepted when: Mỗi lần harvest thành công, XP của user tăng đúng số (Lotus +80, Rose +120, Periwinkle +60), thanh XP cập nhật ngay.

- **[P1]** As a player, I want to level up when I accumulate enough XP so that I have a sense of long-term progression.
  Accepted when: Khi XP vượt ngưỡng 200×level hiện tại, level tăng 1, thanh XP reset về phần dư, hiệu ứng "Level Up!" xuất hiện.

- **[P2]** As a player, I want to tap my avatar to see a profile card with my stats so that I can review my progress in detail.
  Accepted when: Tap avatar → card trượt lên hiển thị: level, tổng XP tích lũy, số lần thu hoạch.

- **[P2]** As a player, I want to see a "+XP" float label when I harvest so that I get immediate visual feedback.
  Accepted when: Float label "+80 XP" (hoặc số tương ứng) bay lên từ vị trí avatar sau mỗi harvest.

- **[P3]** _(out of scope — leaderboard, XP từ các hành động khác)_

---

## Functional Requirements

1. **FR-01:** `UserProfile` domain class (RefCounted) lưu: `level: int`, `current_xp: int`, `total_xp_earned: int`, `harvest_count: int`.
2. **FR-02:** `UserManager` autoload singleton quản lý UserProfile, emit signal `xp_gained(amount)` và `level_up(new_level)`.
3. **FR-03:** `UserManager` kết nối với `GardenManager.harvest_completed` để nhận `product_id` và tra XP theo bảng: `harvest_lotus_bloom→80`, `harvest_rose_bloom→120`, `harvest_periwinkle_bloom→60`.
4. **FR-04:** XP-to-next-level = `200 × level_hiện_tại` (level 1→2: 200, level 2→3: 400...).
5. **FR-05:** HUD widget `UserHUD` (Panel nhỏ, top-left) gồm: avatar tròn (placeholder icon), Label level, ProgressBar XP.
6. **FR-06:** Tap vào UserHUD mở `UserProfileCard` (CanvasLayer, layer=9) slide up từ dưới, hiển thị: level, total_xp_earned, harvest_count. Tap ngoài card để đóng.
7. **FR-07:** Khi `level_up` emit: animation flash (modulate trắng → bình thường 0.4s) trên avatar + float label "Level Up! Lv.X" bay lên từ avatar.
8. **FR-08:** Khi `xp_gained` emit: float label "+X XP" nhỏ bay lên từ UserHUD (không từ plot).

---

## Non-Functional Requirements

- Performance: Tất cả XP update + animation hoàn thành trong 1 frame (không có async cần thiết).
- Layer order: UserProfileCard tại layer=9 (trên FlowerInfoCard layer=8, dưới inventory).

---

## Success Criteria

- [ ] Harvest 1 hoa Lotus → user XP tăng đúng 80, thanh XP cập nhật ngay.
- [ ] Harvest đủ để level up → level tăng 1, animation "Level Up!" xuất hiện, thanh XP reset về phần dư.
- [ ] Tap avatar → UserProfileCard hiện ra với đúng level, total XP, harvest count.
- [ ] Float label "+X XP" xuất hiện gần avatar sau mỗi harvest.
- [ ] Joystick và plot interaction không bị ảnh hưởng bởi UserHUD.

---

## Out of Scope

- XP từ tưới cây / bón phân (chỉ harvest mới cộng XP user)
- Lưu UserProfile vào file/server (chỉ in-memory cho MVP)
- Avatar image thực (placeholder trước, thay sau khi có design)
- Max level cap

---

## Assumptions

- `GardenManager.harvest_completed` vẫn emit `product_id` dạng `"harvest_{template_id}_bloom"` — UserManager parse từ đây.
- HUD.tscn có thể thêm UserHUD widget mà không xung đột layout hiện tại (bag button bên phải, joystick bên trái dưới).
- `UserManager` sẽ được thêm vào `project.godot` autoloads.
