# Spec: Shovel cây trồng (xúc cây khỏi ô đất, trả seed vào bag)

**Date:** 2026-06-21
**Status:** Draft

---

## Problem Statement

Người chơi trồng nhầm cây hoặc muốn đổi loại cây trên một ô đất nhưng hiện không có cách nào dỡ bỏ cây đã trồng — chỉ có thể chờ harvest ở stage cao nhất. Cần một công cụ "shovel" để xúc cây bất kỳ lúc nào, trả ô đất về trạng thái trống và hoàn lại 1 hạt giống vào túi đồ.

---

## User Stories

- **[P1]** Là người chơi, tôi muốn bấm icon shovel để vào "shovel mode" rồi tap vào ô đất có cây để xúc cây đó đi.
  Accepted when: bấm `ShovelButton` → mode highlight (giống harvest_mode); tap ô đất occupied → hiện popup confirm.

- **[P1]** Là người chơi, tôi muốn thấy popup xác nhận (dùng `BaseDialog` style hiện có) trước khi cây bị xúc, vì hành động này làm mất toàn bộ stage/XP đã trồng.
  Accepted when: popup hiện rõ tên cây + cảnh báo "cây sẽ trở về hạt giống Lv0"; có nút Xác nhận / Hủy.

- **[P1]** Là người chơi, sau khi xác nhận xúc cây, tôi muốn ô đất trống lại và nhận về 1 hạt giống đúng loại cây vào bag.
  Accepted when: plot.is_occupied = false, current_plant = null; inventory seed item của đúng flower_template_id tăng +1; đồng bộ qua API thật (optimistic UI + rollback khi lỗi).

- **[P1]** Là người chơi, tôi muốn shovel mode không tự tắt sau 1 lần xúc, để xúc liên tiếp nhiều ô khác mà không phải bấm lại icon.
  Accepted when: sau khi confirm + xúc xong 1 ô, mode vẫn active; tap ô khác có cây vẫn mở được popup confirm tiếp.

- **[P2]** Là người chơi, tôi muốn bấm Hủy trên popup để giữ lại cây, không mất gì, và vẫn ở trong shovel mode để thử ô khác.
  Accepted when: bấm Hủy → đóng dialog, plot không đổi, shovel mode vẫn active.

- **[P3]** _(out of scope)_ Hoàn lại một phần XP/currency đã đầu tư khi xúc cây ở stage cao.

---

## Functional Requirements

1. FR-01: HUD wiring — `ShovelButton` (đã có sẵn trong `HUD.tscn`, chưa nối logic) gọi `InteractionManager.toggle_dig_up_mode()`; chỉ 1 trong các mode (harvest_mode / dig_up_mode / ...) được active cùng lúc — bật mode này phải tự tắt các mode khác.
2. FR-02: `Plot.gd` (scene) — khi `dig_up_mode` active và occupied plot được tap, hiện `BaseDialog.show_confirm(...)` với nội dung cảnh báo mất stage/XP; chỉ gọi hành động xúc khi `confirmed` signal bắn.
3. FR-03: `GardenManager.gd` — thêm `func dig_up(plot_id: String) -> void` theo đúng optimistic UI pattern trong CLAUDE.md: set `is_pending_sync = true` → snapshot plant hiện tại → `plot.clear()` ngay (optimistic) → emit `plots_updated` → `await` gọi API thật → success: `is_pending_sync = false`, gọi `InventoryManager` cộng seed; lỗi: rollback `plot.plant(snapshot)`, `is_pending_sync = false`, emit lại.
4. FR-04: `InventoryManager.gd` — thêm/tái dùng hàm cộng seed (đối xứng với `consume_seed`), ví dụ `restore_seed(flower_template_id: String) -> void`, tăng `quantity` của seed item tương ứng (tạo item nếu chưa tồn tại trong bag, theo rule "HarvestProduct inventory entries must be created if they don't exist" — áp dụng tương tự cho seed).
5. FR-05: eco-backend (C#/.NET) — thêm `POST /api/garden/plots/{plotId}/dig-up` trong `GardenController.cs`, mirror đúng cấu trúc của action `harvest` hiện có (line 75–91): `[Authorize(Roles = Constant.Roles.Player)]`, lấy `User.FindFirst("id")`, ownership check `plot.Garden.UserId != userGuid` trong `GardenService`. Trong 1 transaction (`_unitOfWork.BeginTransactionAsync()` → `CommitAsync()`): clear plot (xoá `PlantedFlower` hiện tại, soft-delete giống pattern hiện có) + gọi `InventoryService.UpsertInventoryItemAsync(...)` để cộng +1 seed theo `FlowerTemplateId`. Response theo envelope hiện có: `{ isSuccess, message, data: { plotId, clearedFlowerTemplateId, seedReturned: { flowerTemplateId, quantity } }, metaData: null }`.
6. FR-06: Có thể xúc cây ở bất kỳ stage nào (không giới hạn theo `current_stage`/`current_xp`), khác với harvest yêu cầu max stage.

---

## Non-Functional Requirements

- Performance: hành động xúc cây phải optimistic — UI cập nhật plot trống ngay (<100ms cảm nhận), không chờ network trước khi clear hình ảnh.
- Security: endpoint BE phải xác thực JWT, chỉ cho phép xúc plot thuộc đúng garden của user hiện tại (ownership check) — tránh user A xúc plot của user B qua chỉnh sửa request.
- Availability: nếu API lỗi (timeout/5xx), client phải rollback plot về trạng thái có cây ban đầu, không để mất cây mà không nhận được seed.

---

## Success Criteria

- [ ] Bấm `ShovelButton` → mode active, tap occupied plot → popup confirm hiện đúng style `BaseDialog` (480×340, theme GlobalTheme).
- [ ] Xác nhận xúc → plot trống trong vòng 1 frame (optimistic), seed +1 trong bag sau khi API trả về thành công.
- [ ] Hủy popup → plot và inventory không đổi, shovel mode vẫn active.
- [ ] Xúc liên tiếp 2 ô khác nhau trong cùng 1 lần bật mode (không cần bấm lại icon shovel).
- [ ] API lỗi (simulate 500) → plot rollback về có cây như cũ, không mất cây, không có seed thừa.

---

## Out of Scope

- Hoàn lại XP/currency theo % tiến độ đã trồng khi xúc cây stage cao.
- Audit log riêng (DigUpLog) ở BE cho hành động xúc cây.
- Giới hạn số lần xúc/cooldown cho hành động shovel.

---

## Assumptions

- Xúc cây luôn trả về đúng 1 seed item của `flower_template_id` tương ứng, không phụ thuộc stage đã đạt được.
- Bấm Hủy trên popup không tắt shovel mode (giữ nguyên để thử ô khác).
- Chỉ 1 mode tương tác (harvest/dig_up/...) active tại một thời điểm trong `InteractionManager`.

---

## Resolved (was NEEDS CLARIFICATION)

- Route + shape: `POST /api/garden/plots/{plotId}/dig-up`, mirror `harvest` action — xem FR-05.
- Log table: eco-backend hiện KHÔNG có audit log pattern nào cho plot mutation (không có HarvestLog) → dig-up cũng không cần log riêng, giữ nguyên Out of Scope.
