# Brainstorm: Gift Code Feature

**Date:** 2026-06-20

## Ideas Explored

- **Admin tooling**: dùng API/DB trực tiếp (Postman/script) trước, chỉ viết markdown hướng dẫn cho team FE web admin tự build UI sau — không build admin dashboard trong scope này.
- **Usage limit model**: ban đầu xét 3 dạng (unlimited-shared / quota-limited / single-use-batch) — quyết định: hỗ trợ cả unlimited và quota-limited, admin chọn lúc tạo code, KHÔNG cần batch random-generate.
- **Code format**: random-generated batch codes bị loại bỏ — admin tự đặt tên code dạng string (TET2026, WELCOME10).
- **Reward shape**: so sánh JSON blob column vs bảng con quan hệ (GiftCodeReward 1-nhiều) — chọn bảng con vì khớp pattern `InventoryItem`/`UserInventory` đã có trong eco-backend, dễ query/thống kê, đúng chuẩn EF Core.
- **Reuse pattern**: scout `DailyTaskService` cho thấy có sẵn pattern claim transaction + optimistic concurrency (`TryCommitAsync` + `DbUpdateConcurrencyException`) ở `UserTaskProgress.Claimed` — tái dùng cho gift code redemption thay vì tự nghĩ pattern mới.

## User's Direction

Admin tạo gift code và tự quy định reward + thời hạn cho từng code. Mỗi gift code có thể khác loại:
- Một số code unlimited-use (nhiều người cùng nhập, chỉ giới hạn bởi expiry).
- Một số code có quota tổng số lượt dùng giới hạn (VD: 100 người đầu).
- Reward gồm nhiều loại cùng lúc: currency + số lượng từng item hiển thị icon trên UI (bình tưới, bón phân, thuốc, hạt giống...) — admin nhập số lượng từng loại, không nhập = 0.
- Mỗi user chỉ redeem được 1 code đúng 1 lần (bất kể code còn quota hay không) — model theo `UserTaskProgress.Claimed` pattern, cần unique constraint (UserId, GiftCodeId).
- Admin UI không nằm trong scope code — chỉ cần API + markdown docs cho FE web admin team tự làm.

## Open Questions

- Reward "Item" line trỏ tới loại nào: `ItemId` (catalog item), `FlowerTemplateId` (seed/plant), hay `DecorId`? `InventoryItem` hiện có cả 3 cột — GiftCodeReward cần xác định rõ discriminator để biết gọi `UpsertInventoryItemAsync` đúng cách.
- Có cần rate-limit / chống brute-force đoán code ở endpoint redeem không (vd: code ngắn, dễ đoán nếu không giới hạn số lần thử)?
- Case-sensitivity và chuẩn hoá string code khi so khớp (trim, uppercase) — giả định: chuẩn hoá uppercase + trim khi lưu và khi so khớp.

## Risks

- **Double-claim race condition**: 2 request redeem cùng lúc từ 2 device của cùng 1 user (đã từng được hỏi trong session trước) — cần unique constraint DB-level (UserId, GiftCodeId), không chỉ check-then-insert ở application layer.
- **Quota race condition**: nhiều user redeem đồng thời 1 code limited-quota có thể vượt quota nếu không dùng transaction + optimistic concurrency giống `DailyTaskService`.
- **Reward schema cứng nhắc**: nếu chọn bảng con quan hệ mà sau này cần thêm loại reward mới (vd: vitality boost trực tiếp) thì cần thêm RewardType enum value + migration — chấp nhận được vì đổi schema ít hơn rủi ro JSON blob không validate được.
