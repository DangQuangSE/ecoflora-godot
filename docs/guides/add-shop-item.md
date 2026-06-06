# Hướng dẫn thêm item mới vào cửa hàng

Quy trình gồm 3 bước: **asset → Godot → BE admin API**.  
Quy tắc cốt lõi: `imageUrl` trên BE **phải khớp** với key đăng ký trong `ItemIconRegistry`.

---

## Các tab hiện có và category tương ứng

| Tab trong game | Category gửi lên API |
|---|---|
| Hạt Giống | `Seed` (FlowerTemplate) |
| Công Cụ | `Consumable` (Item) |
| Trang Trí | `Decoration` (Decor) |

Tab **Coin** không hiển thị item từ API.

---

## Thêm item Trang Trí (Decor)

### Bước 1 — Đặt asset

Đặt file PNG vào:

```
assets/shop/deco/{ten_asset}.png
```

Ví dụ: `assets/shop/deco/wood_bench.png`

### Bước 2 — Đăng ký icon trong Godot

Mở [autoloads/ItemIconRegistry.gd](../../autoloads/ItemIconRegistry.gd), thêm 1 dòng vào `_ready()`:

```gdscript
_try_register("ten_asset", "res://assets/shop/deco/ten_asset.png")
```

Ví dụ:

```gdscript
_try_register("wood_bench", "res://assets/shop/deco/wood_bench.png")
```

### Bước 3 — Thêm vào BE qua admin API

1. Mở Swagger: `http://localhost:5226/swagger`
2. Đăng nhập với tài khoản Admin/SuperAdmin: `POST /api/auth/login`
3. Copy token, bấm **Authorize** trên Swagger
4. Gọi `POST /api/decors`:

```json
{
  "name": "Băng ghế gỗ",
  "price": 150,
  "imageUrl": "wood_bench"
}
```

> `imageUrl` phải **giống hệt** chuỗi đã đăng ký ở Bước 2.

Item xuất hiện ngay ở tab **Trang Trí** khi game khởi động lại — không cần sửa code khác.

---

## Thêm Hạt Giống (Seed)

Seed là `FlowerTemplate` — xem hướng dẫn riêng tại [add-new-flower.md](add-new-flower.md).

---

## Thêm Công Cụ (Consumable)

Tương tự Decor nhưng dùng entity `Item` thay vì `Decor`.

### Bước 1 — Asset

```
assets/icon/{ten_asset}.png
```

### Bước 2 — Icon

```gdscript
_try_register("ten_asset", "res://assets/icon/ten_asset.png")
```

### Bước 3 — BE admin API

`POST /api/items` (Admin):

```json
{
  "name": "Tên hiển thị",
  "price": 50,
  "imageUrl": "ten_asset",
  "type": "WATER",
  "cooldownTime": 3600,
  "receivedExp": 20
}
```

---

## Sơ đồ luồng dữ liệu

```
[asset PNG]  →  ItemIconRegistry.gd  (key = tên file)
                      ↕
[BE: Decor/Item]  →  GET /api/shop/items  →  ShopScene.gd  →  ShopItemCard
                      imageUrl = key         tab đúng          icon tự resolve
```

---

## Xóa hoặc ẩn item

- Xóa mềm: `DELETE /api/decors/{id}` — item không còn xuất hiện trong shop, dữ liệu vẫn giữ trong DB.
- Bật/tắt: với `Item` dùng `PUT /api/items/{id}` và set `isActive: false`.
