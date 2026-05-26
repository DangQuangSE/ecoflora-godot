# Flow Flora - Project Overview

Dưới đây là tổng quan về dự án game mobile **Flow & Flora**, một ứng dụng kết hợp giữa chăm sóc vườn ảo, tập trung học tập và kết nối các giá trị thực tế.
## Mô tả sơ bộ hệ thống:
- Gồm 2 phần:
 +  1 là web admin cho phép quản lý user và một số item của user đó trong game
 +  2 là game mobile được phát triển bằng Unity engine và C#, Unity sẽ tiến hành call các API để lấy đúng số lượng item của user trên web admin và hiển thị các item đó trong game với các tính năng sau:

## 1. Lối chơi Cốt lõi (Core Gameplay)

### Quản lý Vườn hoa
- Người chơi có thể sở hữu và chăm sóc một hoặc nhiều khu vườn cùng lúc.

### Vòng đời Phát triển của Hoa
- Chia thành nhiều giai đoạn:
    - **Hạt giống (Level 1)**
    - **Cây con (Level 2 - 3)**
    - **Cây lớn (Level 4 - 5 - 6)**
    - **Trưởng thành (Level 7)**

### Hành động Chăm sóc & Cooldown
- **Các hành động:**
    - Có 1 khu đất trống gồm nhiều ô đất, khi user thực hiện hành động trồng cây, các cây hoa sẽ mọc lên từ tất cả ô đất trong khu đất, thứ tự mọc tùy theo thứ tự user vuốt đến từng ô đất.
    - Các cây hoa đều sẽ có 1 kinh nghiệm để lớn lên thành 1 cây trưởng thành hơn.
    - Tưới nước (nhận 20 XP)
    - Bón phân (50 XP)
    - Phun thuốc trừ sâu (50 XP)
- **Cơ chế Cooldown:** Áp dụng bộ đếm thời gian chờ độc lập cho từng loại hành động trên từng cây hoa (ví dụ: tưới xong 1 cây phải chờ 3 giờ mới được tưới lại cây đó).
- **Nhiệm vụ hằng ngày và hệ thống:** 
    - Sẽ có những nhiệm vụ hằng ngày như điểm danh để nhận tăng tốc - giúp giảm thời gian tưới nước hay bón phân, phun thuốc trừ sâu hay những lần tưới nước, bón phân, phun thuốc trừ sau free mà không cần chờ đợi
    - Còn những nhiệm vụ khác sẽ đơn giản hơn ví dụ như tưới nước 3 lần 1 ngày,...
    - Nhiệm vụ hệ thống là những nhiệm vụ đặc biệt hơn ví dụ như có 1 loại hoa đặt level 3, hay sở hữu 1 cây hoa Hồng, Hướng Dương,....
### Tương tác Mini-game (Tính năng Mới)
- Thay vì chỉ click, người chơi có thể:
    - Vuốt để trồng hoa
    - Vuốt để tưới nước.
    - Dọn cỏ dại ngẫu nhiên.
    - Đuổi sâu bọ để nhận thêm XP.
### Hiệu ứng Sinh thái (Synergy - Tính năng Mới)
- Đặt các loài hoa "tương sinh" cạnh nhau sẽ tạo ra buff (ví dụ: giảm thời gian cooldown chung).

---

## 2. Chế độ Học Tập Trung (Focus Mode - Tính năng Mới)

### Khu vực trường học lấy thiết kế của FPT University 
- Player sẽ được điều khiển 1 nhân vật 2D di chuyển xung quanh khu vực trong game và đến trường học => vào lớp để học.

### Gieo "Cây Tri Thức"
- Người dùng tự thiết lập bộ đếm thời gian tập trung (hẹn giờ).

### Cơ chế Ràng buộc (Background Tracking)
- Game sẽ theo dõi trạng thái ứng dụng. Nếu người dùng thoát ra màn hình chính hoặc mở app khác, nếu quá số lần nhất định do admin config thì người dùng sẽ thật bại và các cây trong khu vườn của player sẽ bị giảm exp (tùy admin config) (tính năng sẽ được điều chỉnh cho phù hợp với chính sách Store).
- Khi bắt đầu Focus, app hiện một thông báo "vĩnh viễn" trên thanh trạng thái (như trình nghe nhạc).
- Tác dụng: Thông báo này giúp app không bị hệ điều hành "kill" (đóng hoàn toàn) khi khóa máy. Nó có thể chạy một đồng hồ đếm ngược ngầm.
- Cơ chế phát hiện: Trên Android, Foreground Service có thể nhận biết được sự kiện Screen On (Mở màn hình) và Screen Off (Tắt màn hình).
- Nếu Screen On mà user không mở app Flora ngay -> Ghi nhận 1 lần vi phạm.

### Phần thưởng
- Khi hoàn thành đủ thời gian, người dùng nhận được thông báo (rung/âm thanh) và được cộng các vật phẩm giá trị (nước, phân bón, đồ decor).

---

## 3. Hệ thống Nhiệm vụ & Vật phẩm (Economy & Progression)

### Hồ sơ (Profile)
- Hiển thị level, số hoa đã trồng, thành tích cá nhân.
### Cửa hàng (Shop)
- Nơi tiêu dùng tài nguyên để mua Hạt giống, Phân bón, Vật phẩm hỗ trợ và Đồ trang trí (Furniture/Decor).

### Túi đồ (Bag/Inventory)
- Quản lý vật phẩm đã mua, cho phép lấy ra sử dụng trực tiếp vào khu vườn (được quản lý bởi admin).

---

## 4.Yếu tố Văn hóa

### Vật phẩm Văn hóa Việt (Tính năng Mới)
- Đưa các vật phẩm decor truyền thống (nhà tranh, đồ sành sứ) hoặc các loài cây trong truyền thuyết vào game để tôn vinh bản sắc của vườn hoa Tân Ba.

### GPS Check-in (Tính năng Mới)
- Tích hợp định vị để người chơi đến tận khu vườn thực tế, bật app lên check-in và nhận hạt giống độc quyền.

---

## 5. Yếu tố Môi trường (Environment Systems)

### Thời tiết Thực tế (Weather API)
- Game đồng bộ với thời tiết ngoài đời (nắng, mưa) làm ảnh hưởng đến hình ảnh vườn hoặc thay đổi các Daily Task.
- Tùy vào điều kiện thời tiết thì hoa sẽ có những trạng thái khác nhau, ví dụ như nắng quá thì hoa sẽ héo đi
- Mưa quá thì hoa sẽ úng nước, phình to
- Và tùy theo điều kiện thời tiết sẽ có noti cảnh báo gửi về app game

### Chu kỳ Ngày - Đêm
- Cảnh quan trong game tự động chuyển đổi sáng/tối theo thời gian thực tế, tạo cảm giác không gian sống động.
### 6. Thiết kế concept và bình chọn:
- Cho phép người chơi xây dựng trang trại và tham gia bình chọn. 
- Người chơi lọt trong top những trang trại đẹp nhất sẽ có cơ hội được ghi tên tại bảng vàng vườn hoa Tân Ba.

