# Hướng dẫn cấu hình Godot Editor — Weather Sync & Day/Night

Dành cho người mới dùng Godot. Làm theo từng bước theo thứ tự.

---

## 1. Mở Scene và kiểm tra cấu trúc Node

Tính năng Weather Sync dùng **hai scene chính**:

| Scene | Đường dẫn | Vai trò |
|-------|-----------|---------|
| WeatherOverlay | `res://scenes/shared/WeatherOverlay.tscn` | CanvasLayer hiển thị mưa, gió, màu ngày/đêm |
| WeatherManager | autoload (không phải scene) | Singleton quản lý polling và trạng thái thời tiết |

**Kiểm tra WeatherOverlay.tscn:**
1. Trong FileSystem panel (góc dưới trái), tìm đến `scenes/shared/`
2. Double-click `WeatherOverlay.tscn` để mở
3. Scene tree phải trông như sau:
   ```
   WeatherOverlay (CanvasLayer)
   ├── RainParticles (CPUParticles2D)
   ├── WindParticles (CPUParticles2D)
   └── DayNightOverlay (ColorRect)
   ```

---

## 2. Đăng ký WeatherManager là Autoload

> **Quan trọng:** Bước này phải làm để WeatherManager chạy tự động khi game khởi động.

1. Vào menu **Project → Project Settings**
2. Chọn tab **Autoload** (hàng tab ở trên cùng của cửa sổ)
3. Kiểm tra xem `WeatherManager` đã có trong danh sách chưa:
   - Nếu **có rồi** → bỏ qua bước này
   - Nếu **chưa có** → làm tiếp bước 4
4. Ở ô **Path**, click biểu tượng thư mục và chọn `res://autoloads/WeatherManager.gd`
5. Ô **Node Name** tự điền `WeatherManager` — giữ nguyên
6. Click **Add**
7. Đảm bảo `WeatherManager` nằm **sau** `FocusManager` trong danh sách (dùng nút mũi tên lên/xuống bên phải để sắp xếp)
8. Click **Close**

---

## 3. Cài đặt Inspector cho WeatherManager

Vì WeatherManager là autoload, Inspector của nó xuất hiện khi chọn node trong **Scene tree của scene đang chạy**, hoặc qua Remote Inspector. Trong quá trình **phát triển và test**, bạn có thể thay đổi mock condition ngay trong Editor:

1. Chạy game (F5 hoặc nút Play)
2. Chuyển sang tab **Remote** trong Scene dock (góc trên trái, cạnh tab Local)
3. Tìm node `WeatherManager` trong cây remote
4. Click vào nó → Inspector hiển thị các `@export`:

| Trường | Kiểu | Giá trị mặc định | Mô tả |
|--------|------|-----------------|-------|
| `Use Mock` | bool | `false` | `false` = gọi BE thật; `true` = dùng MockWeatherService (dev offline) |
| `Mock Condition` | Condition | `SUNNY` | Chỉ dùng khi `Use Mock = true`: SUNNY / CLOUDY / RAINY / STORM |
| `Weather Endpoint` | String | `""` | Override URL; để trống → tự dùng `{UserManager.base_url}/api/weather/current` |

**Để test từng loại thời tiết (mock):**
- Bật `Use Mock = true`
- Thay `Mock Condition` thành `RAINY` hoặc `STORM` rồi xem hiệu ứng ngay

---

## 3b. Kết nối API thật (BE)

Mặc định game đã gọi BE (`Use Mock = false`). Làm theo các bước sau:

1. Đảm bảo BE chạy và OpenWeather key hợp lệ (`OPENWEATHER_*` trong `API/.env`)
2. Kiểm tra `UserManager.base_url` trỏ đúng server (mặc định `http://20.40.58.246:5000`)
3. Chạy game (F5) — `WeatherManager` tự gọi `GET /api/weather/current` khi khởi động
4. Tab **Output**: không có warning `parse_response` hay `envelope unwrap failed`
5. Sau khi deploy BE mới mapping logic: gọi `DELETE /api/weather/cache` (Admin JWT) để xóa cache cũ

| Trường Inspector | Giá trị production |
|------------------|-------------------|
| `Use Mock` | `false` |
| `Weather Endpoint` | để trống (auto) |

---

## 4. Wiring Signals

Không cần wiring thủ công. WeatherManager phát signal `weather_changed(state: WeatherState)` và bất kỳ scene nào cần lắng nghe đều connect qua code:

```gdscript
func _ready() -> void:
    WeatherManager.weather_changed.connect(_on_weather_changed)
    var state := WeatherManager.get_current_state()
    _on_weather_changed(state)  # lấy trạng thái ban đầu

func _on_weather_changed(state: WeatherState) -> void:
    # xử lý thay đổi thời tiết
    pass
```

WeatherOverlay **không** cần connect signal — WeatherManager tự gọi `apply_state()` trực tiếp.

---

## 5. Không cần cấu hình TileSet

Tính năng này không dùng TileMapLayer. Bỏ qua bước này.

---

## 6. Smoke Test Checklist

Sau khi cấu hình xong, chạy game và kiểm tra:

- [ ] Game khởi động không có lỗi GDScript liên quan đến WeatherManager hay WeatherOverlay
- [ ] Với `Use Mock = false`: overlay phản ánh thời tiết thật từ BE (ví dụ `cloudy` → overlay xám)
- [ ] Đổi `Mock Condition = RAINY` (khi `Use Mock = true`) → thấy hạt mưa rơi trên màn hình
- [ ] Đổi `Mock Condition = STORM` → thấy mưa **và** gió (hạt nằm ngang)
- [ ] Đổi `Mock Condition = CLOUDY` → overlay màu xám nhạt (không có hạt)
- [ ] Đổi `Mock Condition = SUNNY` → overlay trong suốt hoàn toàn
- [ ] Chuyển scene (vào SchoolScene hoặc scene khác) → hiệu ứng thời tiết vẫn còn (vì WeatherOverlay là child của autoload, không bị mất khi đổi scene)

---

## 7. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| `Invalid get index 'RainParticles' on base 'null'` khi khởi động | WeatherOverlay.tscn thiếu node `RainParticles` | Mở `WeatherOverlay.tscn`, thêm node `CPUParticles2D` đặt tên đúng `RainParticles` |
| Không thấy mưa dù trời mưa thật | `Use Mock = true` hoặc parse BE fail | Tắt mock; kiểm tra Output warnings; clear Redis cache BE |
| `parse_response: envelope unwrap failed` | BE trả lỗi hoặc format sai | Gọi `GET /api/weather/current` trên Swagger, kiểm tra `isSuccess` và `data` |
| Không thấy mưa dù đã chọn RAINY (mock) | `Use Mock = false` | Bật `Use Mock = true` trong Inspector |
| `WeatherManager` không xuất hiện trong Remote tree | Chưa đăng ký autoload | Làm lại Mục 2 |
| Lỗi `Parse Error: WeatherState` không tìm thấy | `domain/WeatherState.gd` bị xóa hoặc sai đường dẫn | Kiểm tra file tồn tại tại `res://domain/WeatherState.gd` |
| Hiệu ứng thời tiết biến mất khi đổi scene | WeatherManager chưa được đăng ký autoload đúng cách | Kiểm tra autoload list trong Project Settings, đảm bảo `WeatherManager` có trong danh sách |
