# Hướng dẫn tích hợp Admin Frontend với Flow Flora Backend

Tài liệu này dành cho **Frontend Admin Panel** (web/app riêng) muốn quản lý shop và coin thông qua REST API của backend. Tất cả endpoint đều yêu cầu role **Admin** hoặc **SuperAdmin**.

---

## 1. Thông tin kết nối

| Môi trường | Base URL |
|---|---|
| VPS (production) | `http://20.40.58.246:5000` |

### Đăng nhập lấy token

```http
POST /api/auth/login
Content-Type: application/json

{
  "account": "ecoadmin",
  "password": "ecoadmin"
}
```

Response:
```json
{
  "isSuccess": true,
  "data": {
    "accessToken": "<jwt>",
    "refreshToken": "<token>"
  }
}
```

Mọi request sau đó đều cần header:
```
Authorization: Bearer <accessToken>
```

---

## 2. Quản lý Shop

### 2.1 Hạt giống (Flower Templates — tab "Hạt Giống")

**Xem danh sách:**
```http
GET /api/FlowerTemplates
Authorization: Bearer <token>
```

**Thêm hoa mới:**
```http
POST /api/FlowerTemplates
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "rose",
  "basePrice": 120,
  "imageUrl": "rose"
}
```

> **Quy tắc `name`:** phải là slug chữ thường, khớp với tên thư mục asset trong Godot (`assets/flowers/{name}/`). Danh sách hợp lệ:

| `name` | Hiển thị trong game | Ảnh Godot |
|---|---|---|
| `anthurium` | Hạt Hồng Môn | `assets/flowers/anthurium/anthurium 3.png` |
| `lotus` | Hạt Hoa Sen | `assets/flowers/lotus/lotus 3.png` |
| `periwinkle` | Hạt Hoa Dừa Cạn | `assets/flowers/periwinkle/periwinkle 3.png` |
| `purple_bellflower` | Hạt Hoa Chuông Tím | `assets/flowers/purple_bellflower/purple_bellflower 3.png` |
| `rose` | Hạt Hoa Hồng | `assets/flowers/rose/rose 3.png` |
| `sun_flower` | Hạt Hướng Dương | `assets/flowers/sun_flower/sun_flower 3.png` |
| `tulip` | Hạt Hoa Tulip | `assets/flowers/tulip/tulip 3.png` |

> **Quy tắc `imageUrl`:** đặt bằng giá trị `name` (ví dụ `"rose"`). Godot dùng field này làm lookup key trong `ItemIconRegistry` → hiện ảnh stage 3.

**Cập nhật:**
```http
PUT /api/FlowerTemplates/{id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "rose",
  "basePrice": 150,
  "imageUrl": "rose"
}
```

**Xóa:**
```http
DELETE /api/FlowerTemplates/{id}
Authorization: Bearer <token>
```

---

### 2.2 Công cụ (Items — tab "Công Cụ")

**Xem danh sách:**
```http
GET /api/Items
Authorization: Bearer <token>
```

**Thêm công cụ:**
```http
POST /api/Items
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Watering Can",
  "price": 50,
  "imageUrl": "watering_can",
  "cooldownTime": 0,
  "type": 0,
  "receivedExp": 20
}
```

> **Quy tắc `type`** (enum số nguyên):

| `type` | Loại | Tên phải chứa | `imageUrl` | Asset Godot |
|---|---|---|---|---|
| `0` | WATER | `watering can` | `watering_can` | `assets/icon/watering_can.PNG` |
| `1` | FERTILIZER | `fertilizer` | `fertilizer` | `assets/icon/fertilizer.png` |
| `2` | PESTICIDE | `pesticide` | *(chưa có asset)* | — |

> **Quy tắc `name`:** phải chứa từ khóa tương ứng (không phân biệt hoa thường) để Godot tự map icon đúng. Ví dụ: `"Watering Can"`, `"Fertilizer x2"` đều hợp lệ.

> **`cooldownTime`:** truyền `0` — hệ thống hiện tại dùng số lượng (quantity-based), không dùng cooldown.

**Xóa:**
```http
DELETE /api/Items/{id}
Authorization: Bearer <token>
```

---

### 2.3 Trang trí (Decors — tab "Trang Trí")

**Xem danh sách:**
```http
GET /api/Decors
Authorization: Bearer <token>
```

**Thêm trang trí:**
```http
POST /api/Decors
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Rock",
  "price": 200,
  "imageUrl": "rock"
}
```

> **Quy tắc `imageUrl`:** phải khớp chính xác với slug đã đăng ký trong `ItemIconRegistry` của Godot. Danh sách hợp lệ:

| `imageUrl` (slug) | Tên hiển thị | Asset Godot |
|---|---|---|
| `rock` | Rock | `assets/shop/deco/rock.png` |
| `grass_fence` | Grass Fence | `assets/shop/deco/grass_fence.png` |
| `stone_fence` | Stone Fence | `assets/shop/deco/stone_fence.png` |
| `supper_fence` | Super Fence | `assets/shop/deco/supper_fence.png` |
| `warter_tower` | Water Tower | `assets/shop/deco/warter_tower.png` |
| `warterfall` | Waterfall | `assets/shop/deco/warterfall.png` |

> `imageUrl` của Decor được dùng làm `decorSlug` — Godot dùng slug này để load texture khi đặt deco ngoài vườn.

**Xóa:**
```http
DELETE /api/Decors/{id}
Authorization: Bearer <token>
```

---

## 3. Quản lý người dùng

### 3.1 Danh sách player

```http
GET /api/User
Authorization: Bearer <token>
```

### 3.2 Nạp coin cho user

```http
POST /api/User/top-up-coin
Authorization: Bearer <token>
Content-Type: application/json

{
  "email": "player@example.com",
  "amount": 10000
}
```

> `amount` là số coin **cộng thêm** vào số dư hiện tại.

### 3.3 Tạo tài khoản player (qua Admin)

```http
POST /api/User
Authorization: Bearer <token>
Content-Type: application/json

{
  "firstName": "Nguyen",
  "lastName": "Van A",
  "email": "player@example.com",
  "userName": "playerA",
  "password": "Pass@1234",
  "currency": 0,
  "level": 1
}
```

### 3.4 Ban / Unban

```http
POST /api/User/{userId}/ban
POST /api/User/{userId}/unban
Authorization: Bearer <token>
```

---

## 4. Format response chung

Mọi API đều trả về envelope:

```json
{
  "isSuccess": true | false,
  "message": "...",
  "data": { ... } | null,
  "metaData": null
}
```

Khi `isSuccess: false`, đọc `message` để hiển thị lỗi cho admin.

---

## 5. Lưu ý quan trọng

- `imageUrl` sai slug → icon không hiện trong game (hiện fallback "túi")
- `name` hoa sai slug → icon hoa không hiện trong shop (bị lọc bởi `_filter_known_seeds`)
- `name` công cụ không chứa từ khóa → icon không hiện trong inventory/HUD
- Thêm deco mới cần cập nhật **cả Godot** (`ItemIconRegistry._ready`) để đăng ký slug mới, nếu không icon sẽ trống
- Tab **Coin** trong shop không đọc từ API — do Godot quản lý riêng
