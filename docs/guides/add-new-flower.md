# Hướng dẫn thêm hoa mới vào dự án

## Tổng quan

Mỗi loại hoa cần 3 thứ: **asset PNG**, **dữ liệu Godot** (2 file), **FlowerTemplate trên BE**.

---

## Bước 1 — Chuẩn bị asset

Tạo thư mục mới trong `res://assets/flowers/`:

```
assets/flowers/{tên_hoa}/
    {tên_hoa} 1.png   ← stage 1 (early bloom)
    {tên_hoa} 2.png   ← stage 2 (mid bloom)
    {tên_hoa} 3.png   ← stage 3 (full bloom / harvestable)
```

- `sprout.png` (stage 0) **dùng chung**, không cần tạo mới.
- Tên thư mục phải là **lowercase, dùng underscore** (ví dụ: `cherry_blossom`).
- File extension: `.png` (lowercase). Ngoại lệ: `sun_flower` dùng `.PNG` (uppercase) — tránh pattern này với hoa mới.

---

## Bước 2 — Cập nhật `GardenManager.gd`

File: `autoloads/GardenManager.gd`

Tìm const `_FLOWER_NAME_TO_ASSET` và thêm 1 dòng:

```gdscript
const _FLOWER_NAME_TO_ASSET: Dictionary = {
    # ... các hoa hiện có ...
    "cherry_blossom": "cherry_blossom",   # ← thêm vào đây
}
```

> **Quy tắc:** key = tên BE template (lowercase), value = tên thư mục asset.
> Nếu hoa dùng lại asset của hoa khác (variant), value trỏ sang thư mục hoa gốc:
> ```gdscript
> "golden_rose": "rose",   # variant — dùng asset của rose
> ```

---

## Bước 3 — Cập nhật `ReferenceDataService.gd`

File: `services/ReferenceDataService.gd`

Tìm const `_FLOWER_DEFAULTS` và thêm entry:

```gdscript
const _FLOWER_DEFAULTS: Dictionary = {
    # ... các hoa hiện có ...
    "cherry_blossom": {
        "stages": [[0, 0], [1, 50], [2, 150], [3, 300]],
        "harvest_id": "harvest_cherry_blossom_bloom"
    },
}
```

Giải thích `stages`: `[level, xp_required]`
| Level | XP | Sprite |
|---|---|---|
| 0 | 0 | sprout.png |
| 1 | 50 | {tên} 1.png |
| 2 | 150 | {tên} 2.png |
| 3 | 300 | {tên} 3.png (harvestable) |

> Hoa variant (khó trồng hơn) dùng ngưỡng cao hơn: `[[0,0],[1,80],[2,220],[3,450]]`

---

## Bước 4 — Thêm FlowerTemplate lên BE

Gọi API với SuperAdmin token:

```http
POST http://localhost:5226/api/flowertemplates
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "cherry_blossom",
  "basePrice": 80,
  "imageUrl": "",
  "synergyId": null
}
```

> **Quan trọng:** `name` phải **khớp chính xác** với key trong `_FLOWER_NAME_TO_ASSET` và `_FLOWER_DEFAULTS` (lowercase, underscore).

Lấy token bằng cách login:
```http
POST /api/auth/login
{ "account": "admin@flowflora.dev", "password": "Admin123!" }
```

---

## Bước 5 — Grant seed vào inventory test user (để kiểm tra)

```http
POST http://localhost:5226/api/admin/inventory/grant
Authorization: Bearer {token}

{
  "targetUserId": "a9e4c9a4-b715-47fc-88dd-10952fbfc156",
  "flowerTemplateId": "{id vừa tạo ở bước 4}",
  "quantity": 5
}
```

---

## Checklist nhanh

- [ ] Thư mục `assets/flowers/{tên}/` với 3 file PNG (stage 1, 2, 3)
- [ ] Thêm vào `_FLOWER_NAME_TO_ASSET` trong `GardenManager.gd`
- [ ] Thêm vào `_FLOWER_DEFAULTS` trong `ReferenceDataService.gd`
- [ ] POST lên `/api/flowertemplates` (name phải khớp)
- [ ] Grant seed vào inventory để test

---

## Các hoa hiện có trong dự án

| BE Name | Asset folder | BasePrice | XP thresholds |
|---|---|---|---|
| anthurium | anthurium | 15 | 0/50/150/300 |
| lotus | lotus | 10 | 0/50/150/300 |
| periwinkle | periwinkle | 8 | 0/50/150/300 |
| purple_bellflower | purple_bellflower | 12 | 0/50/150/300 |
| rose | rose | 20 | 0/50/150/300 |
| sun_flower | sun_flower | 18 | 0/50/150/300 |
| tulip | tulip | 14 | 0/50/150/300 |

---

## Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Fix |
|---|---|---|
| Hoa hiện `bag.png` trong inventory | `name` trong BE không khớp key trong `_FLOWER_NAME_TO_ASSET` | Sửa tên BE hoặc thêm key mới |
| Hoa hiện `sprout.png` mãi không lên stage | Thiếu entry trong `_FLOWER_DEFAULTS` | Thêm vào `ReferenceDataService.gd` |
| Push warning "unknown template" trong console | `_FLOWER_DEFAULTS` thiếu key hoặc BE trả tên khác | Kiểm tra BE template name vs key |
| Hoa trong vườn không có sprite | Asset path sai hoặc file extension sai | Kiểm tra `assets/flowers/{tên}/{tên} 1.png` có tồn tại không |
