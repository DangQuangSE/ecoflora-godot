# Hướng dẫn Test — Kết nối Backend (BE Sync)

Dành cho người mới dùng Godot. Làm theo từng bước theo thứ tự.
Tài liệu này bao gồm tất cả tính năng đã tích hợp với .NET 8 backend:
Login, Reference Data, User Profile, Garden Sync, Inventory Sync, Focus Session Sync.

---

## 1. Chuẩn bị môi trường

Trước khi test bất kỳ tính năng nào, phải đảm bảo:

### 1.1 Khởi động Backend

```bash
# Trong thư mục eco-backend
cd d:\WorkWithCorn\eco-backend
dotnet run --project API
```

Backend sẽ chạy tại `http://localhost:5226`.
Mở trình duyệt vào `http://localhost:5226/swagger` để kiểm tra — phải thấy danh sách endpoint.

### 1.2 Tài khoản test

Cần có tài khoản **Player** (không phải Admin/SuperAdmin) trong database.
Nếu chưa có, dùng Swagger để gọi `POST /api/auth/register` tạo tài khoản mới.

---

## 2. Cài đặt Inspector — Tắt Mock Mode

Mặc định tất cả manager đều chạy ở chế độ mock (`use_mock = true`).
Để kết nối thật với BE, phải tắt mock trên từng manager.

### 2.1 Cách mở Inspector của Autoload

1. Trong Godot Editor, nhìn menu trên → **Scene** → **Open Scene** → chọn scene bất kỳ đang dùng làm main scene (ví dụ `res://scenes/auth/LoginScene.tscn`)
2. Khi scene đang chạy, ở tab **Remote** trong Scene Tree sẽ thấy các autoload
3. **Hoặc** dùng cách nhanh hơn: menu **Project** → **Project Settings** → tab **Autoload** → click vào tên script để mở file, sau đó sửa trực tiếp giá trị export trong file `.gd`

> **Cách dễ nhất:** Sửa trực tiếp trong file `.gd` — tìm dòng `@export var use_mock: bool = true` và đổi thành `false`. Sau đó **reload** Godot.

### 2.2 Danh sách export cần sửa

| File | Dòng cần sửa | Giá trị mặc định → Giá trị test |
|------|-------------|----------------------------------|
| `autoloads/UserManager.gd` | `@export var use_mock: bool` | `true` → `false` |
| `autoloads/UserManager.gd` | `@export var base_url: String` | `"http://localhost:5226"` (giữ nguyên) |
| `autoloads/GardenManager.gd` | `@export var use_mock: bool` | `true` → `false` |
| `autoloads/InventoryManager.gd` | `@export var use_mock: bool` | `true` → `false` |
| `autoloads/FocusManager.gd` | `@export var use_mock: bool` | `true` → `false` |

> ⚠️ **Lưu ý:** Sau khi test xong, **nhớ đặt lại `use_mock = true`** trên tất cả manager trước khi commit code. Không bao giờ commit với `use_mock = false`.

---

## 3. Smoke Test từng tính năng

### 3.1 Login (Phase 0 + Phase 1)

**Mục tiêu:** Màn hình đăng nhập hiện ra, nhập đúng tài khoản → vào được GardenScene.

**Bước thực hiện:**
1. Chạy game (F5 trong Godot hoặc nút Play góc trên phải)
2. Scene đầu tiên phải là `LoginScene` — thấy form đăng nhập với ô Username và Password
3. Nhập tài khoản Player đã tạo → nhấn **Đăng nhập**
4. Quan sát **Output** tab ở dưới Godot: không được có `push_error` hay `push_warning` liên quan đến login
5. Sau 1-2 giây phải tự động chuyển sang **GardenScene**

**Kết quả mong đợi:**
- ✅ Chuyển scene thành công, không có lỗi
- ✅ `UserManager.is_logged_in()` trả `true` (có thể check qua Remote Inspector)

**Test tài khoản sai:**
- Nhập sai mật khẩu → phải hiện thông báo lỗi màu đỏ trong form, **không** crash game
- Nhập tài khoản bị ban → hiện thông báo lỗi phù hợp

---

### 3.2 Reference Data (Phase 3)

**Mục tiêu:** Sau khi login, game tự động tải FlowerTemplate, Item, Synergy từ BE.

**Bước thực hiện:**
1. Login thành công (bước 3.1)
2. Vào **GardenScene**, nhìn vào **Output** tab
3. Sẽ thấy các `push_warning` kiểu: `"ReferenceDataService: no stage data for template 'Sunflower' — keeping empty stages"` — đây là **bình thường**, BE chưa có stage data

**Kết quả mong đợi:**
- ✅ Các warning trên xuất hiện (chứng tỏ template đã được tải từ BE)
- ✅ **Không** thấy chuỗi lỗi HTTP như `HTTP 401` hay `HTTP 500`
- ✅ `GardenManager.get_templates()` trả về Dictionary không rỗng (có thể kiểm tra qua Remote → GardenManager → _templates)

---

### 3.3 User Profile (Phase 4)

**Mục tiêu:** Level và Currency của player hiển thị đúng theo dữ liệu trên server.

**Bước thực hiện:**
1. Login thành công
2. Nhìn vào **HUD** ở góc trên màn hình game — thấy hiển thị Level và số coin/currency
3. So sánh với dữ liệu trên Swagger: gọi `GET /api/auth/profile` với token JWT để xem level/currency thực tế

**Kết quả mong đợi:**
- ✅ Level trong HUD = Level trả về từ `GET /api/auth/profile`
- ✅ Currency trong HUD = Currency trả về từ `GET /api/auth/profile`
- ✅ Sau khi refresh/restart game và login lại, số liệu vẫn không thay đổi (persist trên server)

---

### 3.4 Garden Sync (Phase 5)

**Mục tiêu:** Các ô đất trong garden khớp với dữ liệu trên server (đúng số lượng plot, đúng cây đang trồng).

**Bước thực hiện:**
1. Login thành công
2. Vào GardenScene — chờ 1-2 giây cho garden load từ BE
3. Kiểm tra **Output**: tìm bất kỳ warning nào chứa `GardenManager._fetch_garden`
4. Vào Swagger → `GET /api/garden` với JWT token → xem danh sách plots
5. So sánh số plot và trạng thái chiếm dụng (is_occupied) giữa game và Swagger response

**Kết quả mong đợi:**
- ✅ Số ô đất trong game = số phần tử trong mảng `plots` của BE
- ✅ Ô đất nào có cây trên BE (`plantedFlower` không null) → game hiển thị cây đó
- ✅ XP của cây = `currentXp` từ BE, stage được tính qua `compute_stage_for_xp()` (không tin stage từ server)
- ✅ Nếu BE trả về 0 plots → game giữ nguyên mock plots và hiện `push_warning`

**Test offline:**
1. Tắt backend (Ctrl+C trong terminal dotnet run)
2. Chạy game lại với `use_mock = false`
3. Mong đợi: game vẫn hiển thị mock plots, thấy `push_warning` về `HTTP` failure, **không crash**

---

### 3.5 Inventory Sync (Phase 6)

**Mục tiêu:** Panel hàng tồn kho hiển thị đúng item từ server (seed, consumable, decor).

**Bước thực hiện:**
1. Login thành công
2. Mở Inventory Panel (nút túi/kho đồ trong HUD)
3. Kiểm tra **Output** tab: không có warning về `InventoryManager._fetch_inventory`
4. Vào Swagger → `GET /api/inventory` với JWT token
5. So sánh danh sách item trong game với response từ BE

**Kết quả mong đợi:**
- ✅ Item có `flowerTemplateId` (không null) → `category == SEED` trong game
- ✅ Item có `itemId` (không null) → `category == CONSUMABLE`
- ✅ Item có `decorId` (không null) → `category == DECOR`
- ✅ `quantity` trong game = `quantity` từ BE
- ✅ Harvest product (thu hoạch hoa) vẫn hoạt động local — thêm vào inventory sau khi harvest, **không** bị mất khi sync

**Test harvest rồi sync:**
1. Harvest một hoa đã đủ giai đoạn → `harvest_rose_bloom` xuất hiện trong inventory
2. Restart game, login lại
3. Mong đợi: harvest product cũ **biến mất** (nó chỉ lưu local, không sync lên server) — đây là behavior đúng theo thiết kế

---

### 3.6 Focus Session Sync

**Mục tiêu:** Khi hoàn thành hoặc thất bại một phiên focus, dữ liệu được lưu lên server.

**Bước thực hiện:**

**Test COMPLETED:**
1. Login thành công
2. Vào SchoolScene (nút trường học trong HUD)
3. Nhấn **Bắt đầu** để tạo phiên focus (đặt thời gian ngắn ví dụ 1 phút để test nhanh)
4. Đợi hết thời gian → phiên tự động hoàn thành
5. Sau khi phiên kết thúc, vào Swagger → `GET /api/focus-sessions` (**chưa có endpoint này**) hoặc kiểm tra database trực tiếp
6. Kiểm tra **Output**: không có `push_warning` về `FocusManager: BE terminal sync failed`

**Test FAILED (app background):**
1. Bắt đầu phiên focus
2. Chuyển sang app khác (app background) 3 lần liên tiếp — mỗi lần app bị tạm dừng là 1 vi phạm
3. Sau 3 vi phạm, phiên kết thúc với FAILED
4. Kiểm tra Output: `session_failed` được emit và không có lỗi HTTP nghiêm trọng

**Test CANCELLED:**
1. Bắt đầu phiên focus
2. Nhấn nút Hủy
3. Kiểm tra Output: **không có** bất kỳ HTTP request nào được gửi đi (cancelled session không lưu lên BE)

**Kết quả mong đợi:**
- ✅ Session COMPLETED → BE record có `status: "COMPLETED"`, `strikes` đúng
- ✅ Session FAILED → BE record có `status: "FAILED"`, `strikes = 3`
- ✅ Garden XP vẫn được cộng đúng **dù BE có online hay không**
- ✅ Cancel không gọi bất kỳ HTTP request nào

---

## 4. Kiểm tra nhanh toàn bộ (Full Flow)

Sau khi test từng tính năng riêng, chạy flow hoàn chỉnh một lần:

- [ ] Khởi động BE (`dotnet run`)
- [ ] Đặt tất cả `use_mock = false`
- [ ] Chạy game → thấy LoginScene
- [ ] Đăng nhập thành công → chuyển sang GardenScene
- [ ] HUD hiển thị đúng Level + Currency từ BE
- [ ] Garden load đúng plots từ BE (không còn mock plots)
- [ ] Mở Inventory → thấy items từ BE
- [ ] Trồng 1 hoa (nếu có seed) → hoa xuất hiện trong garden
- [ ] Vào SchoolScene → hoàn thành 1 phiên focus ngắn
- [ ] Garden XP được cộng sau khi focus xong
- [ ] Restart game → login lại → dữ liệu vẫn giữ nguyên (garden, inventory, level)

---

## 5. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| Game bắt đầu bằng GardenScene, không qua Login | `UserManager.use_mock = true` → `is_logged_in()` trả `true` ngay | Đặt `use_mock = false` trong `UserManager.gd` |
| Output: `HTTP 401` liên tục sau login | Token hết hạn hoặc sai `base_url` | Kiểm tra `UserManager.base_url = "http://localhost:5226"`, thử login lại |
| Output: `HTTP 500` khi fetch garden | BE đang lỗi server | Xem log trong terminal `dotnet run`, thường do thiếu migration hoặc lỗi DB |
| Garden hiển thị mock plots dù `use_mock = false` | BE trả về 0 plots (user mới chưa có garden) hoặc BE offline | Gọi `GET /api/garden` trên Swagger để kiểm tra — BE có thể tự tạo garden mới |
| Inventory rỗng dù BE có items | `InventoryManager.use_mock` vẫn còn `true` | Kiểm tra lại Inspector của InventoryManager |
| Focus session không sync lên BE | `FocusManager.use_mock = true` | Đặt `use_mock = false` |
| `push_warning: use_mock=true but real token present` | Vô tình có token thật trong mock mode | Bình thường khi test — chỉ là cảnh báo, không ảnh hưởng gameplay |
| Sau harvest, XP không cộng | `GardenManager.use_mock = false` nhưng `_templates` rỗng (BE không có stage data) | Tạm thời đổi `GardenManager.use_mock = true` để dùng mock templates có đủ stage |
| Game crash khi login với tài khoản Admin | BE trả về 403 cho Admin — không có garden/inventory | Dùng tài khoản Player (Role = "Player") |
