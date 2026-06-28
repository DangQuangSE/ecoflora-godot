# Spec: Admin Shop Price Editing

**Date:** 2026-06-28
**Status:** Ready

---

## Problem Statement

Admin dashboard cần xem danh sách tất cả sản phẩm trong shop và chỉnh sửa giá của từng sản phẩm. Hiện tại giá nằm rải rác ở 3 bảng (`Item`, `Decor`, `FlowerTemplate`) và character price hardcode trong code — admin không sửa được.

---

## User Stories

- **[P1]** As an admin, I want to see all shop items in one list so that I can manage prices from a single view.
  Accepted when: `GET /api/admin/shop/catalog` trả về tất cả Items + Seeds + Decors + Characters với đúng giá hiện tại.

- **[P1]** As an admin, I want to update the price of any shop item so that I can adjust pricing without code changes.
  Accepted when: `PATCH /api/admin/shop/{prefixedId}/price` với body `{ "price": 500 }` cập nhật đúng bảng tương ứng và player thấy giá mới ngay khi gọi `GET /api/shop/items`.

- **[P1]** As an admin, I want character prices stored in DB so that I can edit character purchase prices.
  Accepted when: `CharacterConfig` table có seed data cho character 0 (price=0) và character 1 (price=10000); `PurchaseAsync` đọc từ DB thay vì hardcode.

- **[P2]** As an admin, I want price validation so that I cannot accidentally set a negative price.
  Accepted when: Request với `price < 0` trả về HTTP 400.

- **[P3]** _(out of scope — audit log: ai sửa giá lúc nào)_
- **[P3]** _(out of scope — enable/disable item)_
- **[P3]** _(out of scope — change item name/image)_

---

## Functional Requirements

1. **FR-01**: `GET /api/admin/shop/catalog` trả về list `AdminShopCatalogItemDto[]` gộp từ Item + FlowerTemplate + Decor + CharacterConfig. Yêu cầu role `Admin` hoặc `SuperAdmin`.

2. **FR-02**: Response mỗi item có `id` dạng prefixed string (`item:{guid}`, `seed:{guid}`, `deco:{guid}`, `character:{index}`), `name`, `price`, `category`, `imageUrl`, `isActive`.

3. **FR-03**: `PATCH /api/admin/shop/{prefixedId}/price` nhận body `{ "price": int }`, validate `price >= 0`, update đúng bảng dựa theo prefix, trả về `AdminShopCatalogItemDto` sau update.

4. **FR-04**: Tạo entity `CharacterConfig` với fields: `Id (Guid)`, `CharacterIndex (int)`, `Name (string)`, `Price (int)`, `ImageUrl (string)`, `IsActive (bool)`. Seed 2 records: character 0 (free) và character 1 (10,000).

5. **FR-05**: `ShopService.PurchaseAsync` update để lookup `CharacterConfig` từ DB thay vì hardcode price 10,000.

6. **FR-06**: `ShopService.GetCatalogAsync` (player endpoint) tiếp tục hoạt động bình thường — không thay đổi behavior, chỉ character price đọc từ DB.

7. **FR-07**: Player endpoint `GET /api/shop/items` **không** bị ảnh hưởng — vẫn trả về `ShopCatalogItemDto` như cũ.

---

## Non-Functional Requirements

- **Security**: Tất cả admin endpoints phải có `[Authorize(Roles = "Admin,SuperAdmin")]`. Player không được gọi admin catalog.
- **Validation**: `price >= 0` (int). Không validate max price.
- **Backward compat**: Player-facing `GET /api/shop/items` và `POST /api/shop/purchase` không thay đổi interface.

---

## Success Criteria

- [ ] Admin gọi `GET /api/admin/shop/catalog` → nhận đủ items từ cả 4 categories (Consumable, Seed, Decoration, Character)
- [ ] Admin gọi `PATCH /api/admin/shop/item:{id}/price` với `price: 999` → player gọi `GET /api/shop/items` thấy giá 999
- [ ] Admin gọi `PATCH /api/admin/shop/character:1/price` với `price: 5000` → player mua character 1 tốn 5000 currency
- [ ] Request `price: -1` → HTTP 400
- [ ] Player không có role Admin gọi `GET /api/admin/shop/catalog` → HTTP 403

---

## Out of Scope

- Thêm/xóa sản phẩm
- Enable/disable sản phẩm
- Sửa tên, ảnh, description
- Audit log
- Bulk price update
- CharacterConfig imageUrl trong DB (FE/Godot hardcode map index → sprite)

---

## Assumptions

- `CharacterConfig.ImageUrl` không dùng từ DB — Godot hardcode theo `character_index`. DB chỉ cần lưu `CharacterIndex`, `Name`, `Price`, `IsActive`.
- Character 0 (girl) luôn free (price=0), nhưng admin vẫn có thể edit nếu muốn — không lock.
- Admin FE dashboard là web app riêng biệt, không phải Godot client.
- Prefix format giữ nguyên: `item:`, `seed:`, `deco:`, `character:`.
