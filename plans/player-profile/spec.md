# Spec: Player Profile

**Date:** 2026-06-08
**Status:** Ready

---

## Problem Statement

`UserProfileCard` đã tồn tại nhưng không mở được (input bị block bởi CoinButton), UI plain text không phù hợp game farming, thiếu các stat quan trọng (login streak, flower count) và không có avatar system.

---

## User Stories

- **[P1]** As a player, I want to tap my avatar/name in the HUD and see a profile popup open, so I can view my stats.
  Accepted when: tap trên vùng UserHUD (ngoài CoinButton) mở UserProfileCard trong ≤0.3s.

- **[P1]** As a player, I want to see my consecutive login streak, so I know how many days in a row I've been playing.
  Accepted when: `login_streak` hiển thị đúng số ngày liên tiếp; reset về 1 nếu bỏ lỡ 1 ngày.

- **[P1]** As a player, I want to see how many flowers I currently own, so I can track my collection.
  Accepted when: flower_count = tổng số lượng items thuộc category "Flower" trong InventoryManager lúc mở card.

- **[P1]** As a player, I want a profile UI that matches the farming game aesthetic, so it feels part of the game.
  Accepted when: card dùng palette xanh/nâu/vàng ấm, có icon cho từng stat, dùng assets từ `assets/profile/`.

- **[P1]** As a player, I want to pick an avatar from preset options, so I can personalize my character.
  Accepted when: ≥6 preset avatars có thể chọn, lựa chọn persist qua session (lưu local + sync BE), avatar hiển thị trong HUD và card.

- **[P2]** As a player, I want to see my join date, so I know how long I've been playing.
  Accepted when: "Tham gia: DD/MM/YYYY" hiển thị trong card, lấy từ `created_at` của BE.

- **[P3]** _(out of scope — upload ảnh từ thiết bị, Android native file picker)_

---

## Functional Requirements

1. **FR-01** — Add invisible `ProfileButton` Control overlay trên vùng avatar+name trong UserHUD.tscn. `CoinButton` giữ nguyên. `_gui_input` trên UserHUD bị loại bỏ.
2. **FR-02** — `UserProfileCard` redesign: farming theme panel (wood/green border), avatar circle ở top-center, 5 stat rows với icon (Level, XP, Harvest, Streak, Flowers).
3. **FR-03** — `flower_count` tính client-side lúc `open()`: `InventoryManager.get_inventory()` → filter items có `category == "flower"` → sum quantities.
4. **FR-04** — Avatar preset: thêm `avatar_index: int = 0` vào `UserProfile`. UserProfileCard hiển thị avatar tương ứng từ array `assets/profile/avatars/avatar_N.png`. Tap avatar → mở picker overlay.
5. **FR-05** — Avatar picker: HBoxContainer scrollable với ≥6 avatars. Chọn xong → gọi `UserManager.set_avatar_async(index)` → lưu local + gọi BE `PUT /api/users/avatar-index`.
6. **FR-06** — BE: thêm `login_streak: int` và `last_login_date: string (ISO date)` vào profile response. Logic cập nhật streak khi GET `/api/auth/profile`: nếu `last_login_date` là hôm qua → streak++, nếu hôm nay → giữ nguyên, else → streak=1.
7. **FR-07** — `UserProfile` domain: thêm fields `login_streak: int`, `avatar_index: int`, và `join_date: String` (optional, P2).
8. **FR-08** — HUD UserHUD.tscn: AvatarRect hiển thị texture từ preset array theo `avatar_index`.

---

## Non-Functional Requirements

- Card open animation: slide-up 0.22s, không drop frame (≤16ms per frame).
- Avatar images: mỗi file ≤100KB, 128×128px, định dạng PNG.
- BE streak update: O(1), không query thêm — chỉ đọc/ghi 2 fields trên User entity.
- Avatar index sync: fire-and-forget (optimistic update local trước, sync BE async).

---

## Success Criteria

- [ ] Tap avatar/name area trong HUD → ProfileCard mở trong ≤0.3s
- [ ] `login_streak` tăng đúng khi test 2 ngày liên tiếp (mock mode: giả ngày qua `Time`)
- [ ] `flower_count` khớp với số items flower trong InventoryManager
- [ ] UI có farming palette, icon trước mỗi stat, avatar hiển thị
- [ ] Chọn avatar từ picker → avatar thay đổi ngay trong HUD + card
- [ ] Avatar lựa chọn persist sau khi restart game

---

## Out of Scope

- Upload ảnh từ thiết bị (FileDialog, Android file picker)
- Sửa username trong profile
- Achievement / badge system
- Leaderboard / bảng xếp hạng
- Social features (friends, gifts)

---

## Assumptions

- eco-backend có thể thêm `login_streak`, `last_login_date`, `avatar_index` vào User entity + migration.
- InventoryItem có field `category: String` để filter flower items.
- Sẽ tạo thư mục `assets/profile/avatars/` với ≥6 PNG preset.
- BE endpoint `PUT /api/users/avatar-index` body `{ "avatar_index": int }` — hoặc gộp vào existing profile update endpoint.

---

## Implementation Phases

| Phase | Scope | Layer |
|-------|-------|-------|
| 01 | BE: thêm login_streak + avatar_index vào User entity + migration + API response | eco-backend |
| 02 | Domain: cập nhật UserProfile.gd + UserManager.gd (parse fields, set_avatar_async) | Godot domain/autoload |
| 03 | Fix input + chuẩn bị avatar assets (≥6 PNG vào assets/profile/avatars/) | Godot assets |
| 04 | UI redesign UserProfileCard.tscn + UserProfileCard.gd (farming theme + stat rows + avatar picker) | Godot scenes |
| 05 | Wire UserHUD.tscn: AvatarRect hiển thị avatar texture theo index | Godot HUD |
