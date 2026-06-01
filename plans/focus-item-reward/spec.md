# Spec: Focus Session Item Reward

**Date:** 2026-05-31
**Status:** Ready

---

## Problem Statement

Focus session hiện chỉ thưởng +XP/phút cho hoa (abstract, không cảm nhận được). Cần thay bằng item cụ thể (watering can, fertilizer) để tạo vòng lặp rõ ràng: học → nhận item → chăm hoa. Đồng thời cần verify BE sync chạy đúng trước demo EXE2.

---

## User Stories

- **[P1]** As a player, I want to receive garden items after completing a focus session so that I have resources to care for my plants.
  Accepted when: Hoàn thành session 25 phút → inventory tăng đúng 2× Watering Can, DB `InventoryItems` ghi nhận.

- **[P1]** As a player, I want the item reward to scale with how long I focused so that longer sessions feel more rewarding.
  Accepted when: Session 50 phút → nhận 2× Watering Can + 1× Fertilizer; session 100 phút → nhận bộ full (3WC + 2F + 1P).

- **[P1]** As a player, I want the focus timer and BE to stay in sync so that my session history is recorded correctly.
  Accepted when: POST create → DB có row `FocusSessions`; PATCH complete → `CompletedAt` set, reward items granted.

- **[P2]** As a developer, I want reward logic in a separate `RewardCalculationService` so that the table can be swapped to DB-driven later without touching controller.
  Accepted when: `RewardCalculationService` là class riêng biệt, controller chỉ gọi `CalculateReward(durationMinutes)`.

- **[P3]** _(Admin-configurable reward table via API — out of scope for demo)_

---

## Functional Requirements

1. **FR-01**: BE tạo class `RewardCalculationService` với method `CalculateReward(int durationMinutes) → List<RewardItem>`. Hardcode 4 tier: <25 min = [], 25–49 = [2×WC], 50–74 = [2×WC, 1×F], 75–99 = [3×WC, 2×F], ≥100 = [3×WC, 2×F, 1×P].
2. **FR-02**: `PATCH /api/focus/{sessionId}/complete` gọi `RewardCalculationService`, grant items vào inventory của user, trả response `{ xpEarned: 0, rewardItems: [{ itemId, itemName, quantity }] }`.
3. **FR-03**: `GardenManager._on_focus_session_completed()` KHÔNG còn gọi `apply_focus_xp_bulk()`. Thay bằng đọc `rewardItems` từ response và gọi `InventoryManager` để add từng item.
4. **FR-04**: `FocusTimerUI` result panel hiển thị danh sách item nhận được (không hiện "+X XP" nữa).
5. **FR-05 (Task C)**: Chạy flow end-to-end, verify: POST create → DB row; PATCH complete → DB `CompletedAt` + `InventoryItems` updated; PATCH fail → DB `FailedAt`. Fix bug nếu có.

---

## Non-Functional Requirements

- BE: `CalculateReward()` là pure function, không gọi DB — O(1), không thêm latency.
- Godot: Nếu response thiếu `rewardItems` (old BE format) → graceful fallback, không crash.
- Reward grant dùng lại `InventoryRepository.IncrementOrCreateAsync()` đã có — không code thêm grant logic.

---

## Success Criteria

- [ ] Focus 25 phút (test mode: set timer ngắn) → inventory +2 Watering Can trong Godot UI + DB confirm
- [ ] Focus 50 phút → inventory +2 Watering Can +1 Fertilizer
- [ ] FocusTimerUI result panel hiển thị item list, không hiện "+X XP"
- [ ] POST /api/focus/start → FocusSessions row tạo; PATCH complete → CompletedAt set + InventoryItems updated
- [ ] Nếu session fail (3 violations): KHÔNG grant item, flow không crash

---

## Out of Scope

- Admin-configurable reward table (P3 — sau demo)
- Android foreground service / notification (không cần cho demo)
- UI redesign (progress ring, animation) — riêng biệt, không block feature này
- Pesticide item (nếu chưa có asset) — fallback gracefully

---

## Assumptions

- `InventoryRepository` đã có `IncrementOrCreateAsync(userId, itemId, qty)` hoặc tương đương — nếu không thì cần thêm.
- Item IDs của Watering Can, Fertilizer, Pesticide trong DB đã biết (hardcode trong `RewardCalculationService`).
- `FocusService.CompleteAsync()` hiện return void hoặc basic DTO — cần mở rộng response.

---

## Fail Penalty

Session FAIL (3 violations): giữ nguyên -20 XP penalty cho tất cả hoa (`apply_focus_xp_bulk(-20)`). Không grant item khi fail.
