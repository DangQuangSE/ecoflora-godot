# Brainstorm: Admin Shop Price Editing

**Date:** 2026-06-28

## Ideas Explored

- **Per-entity endpoints** — dùng `PUT /api/items/{id}`, `PUT /api/decors/{id}`, `PUT /api/flower-templates/{id}` riêng lẻ. FE phải track entity type và gọi đúng endpoint. Bị loại vì FE phức tạp không cần thiết.
- **Unified admin shop catalog + single PATCH** — `GET /api/admin/shop/catalog` trả về 1 list gộp, `PATCH /api/admin/shop/{prefixedId}/price` dùng prefix strategy có sẵn. FE chỉ cần 2 endpoints.
- **Character price hardcode** — giữ nguyên `character 1 = 10,000` trong code. Bị loại vì admin cần sửa được.
- **CharacterConfig DB table** — lưu giá character vào DB, seed dữ liệu ban đầu. Được chọn.

## User's Direction

- Chỉ sửa giá (không thêm/xóa/enable-disable sản phẩm).
- Unified endpoint — FE admin dashboard cần 1 view thống nhất.
- Character price cần lưu DB để admin sửa được.

## Open Questions

- CharacterConfig: lưu imageUrl trong DB hay vẫn hardcode trong FE/Godot?
- Khi update price, có cần audit log (ai sửa lúc nào) không?

## Risks

1. **Migration character hardcode → DB**: code hiện tại trong `ShopService.PurchaseAsync` check `prefixedId == "character:1"` hardcode → cần update để lookup từ DB.
2. **Race condition**: nếu admin đang sửa giá, user đang checkout cùng lúc → cần confirm giá lúc checkout là giá thực tế từ DB (đã đúng vì PurchaseAsync đọc từ DB cho items/seeds/decors).
3. **Character price = 0**: character 0 (girl) free, cần đảm bảo price=0 không bị admin set thành giá có phí nhầm.
