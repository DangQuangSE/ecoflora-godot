# Spec: Max Stage Care Block + Floating Notification

**Date:** 2026-05-30
**Status:** Ready

---

## Problem Statement

Khi cây đã đạt stage tối đa (stage 3), player vẫn có thể dùng item tưới/bón phân lên cây — tiêu tốn item và gọi API không cần thiết. Cần chặn hành động này và hiện thông báo rõ ràng để player hiểu cây đã full.

---

## User Stories

- **[P1]** As a player, I want to see a notification when I try to water/fertilize a max-level plant so that I know the action is blocked and don't waste items.
  Accepted when: Floating label xuất hiện và animate lên rồi fade out, không có API call nào được gửi đi.

- **[P1]** As a player, I want the max-level notification to look different from the +XP label so that I can tell them apart at a glance.
  Accepted when: Label màu khác (đỏ hoặc cam) so với +XP label vàng.

- **[P2]** As a player, I want the notification to work for all 3 care actions (water, fertilize, pesticide) so that I'm never confused.
  Accepted when: Cả 3 action đều bị chặn và hiện label khi plant ở max stage.

---

## Functional Requirements

1. **FR-01**: `Plot.gd._apply_item()` kiểm tra `current_stage >= template.get_max_stage_level()` trước khi gọi `InteractionManager.request_plot_action()` cho CONSUMABLE category.
2. **FR-02**: Nếu điều kiện FR-01 đúng → gọi `_spawn_float_label(text, color)` với text "ĐÃ ĐẠT LEVEL TỐI ĐA" và return sớm (không call API, không consume item).
3. **FR-03**: `FloatLabel.play()` nhận thêm optional `color: Color = Color(1, 0.88, 0.1, 1)` param, áp dụng color đó cho label text. Default giữ nguyên màu vàng (backward compat).
4. **FR-04**: `PlotNode._spawn_float_label()` forward color param xuống `FloatLabel.play()`.

---

## Non-Functional Requirements

- Không có network call khi bị chặn (item không bị consume).
- FloatLabel animate giống hệt +XP: slide lên + fade out trong ~1s.
- Không thêm scene mới — tái dụng `FloatLabel.gd` hiện có.

---

## Success Criteria

- [ ] Thử dùng watering can lên cây max stage → label đỏ/cam nhảy lên, item quantity không giảm, DB không có request mới.
- [ ] Thử dùng fertilizer lên cây max stage → cùng kết quả.
- [ ] Dùng watering can lên cây chưa max stage → vẫn hoạt động bình thường (+XP vàng, item consumed).
- [ ] FloatLabel vàng (+XP) ở các chỗ khác không bị ảnh hưởng.

---

## Out of Scope

- Không thay đổi logic GardenManager (check max stage chỉ ở UI layer).
- Không thêm sound effect hay animation phức tạp hơn FloatLabel hiện có.
- Không block harvest action (harvest đã có guard riêng).

---

## Assumptions

- `template.get_max_stage_level()` trả về đúng max stage (hiện là 3) — đã verified trong code.
- `FloatLabel` dùng `Label` node bên trong để render text — có thể set `add_theme_color_override("font_color", color)`.
- Plot.gd có access `GardenManager.get_templates()` và `_current_plot.current_plant` — đã verified.
