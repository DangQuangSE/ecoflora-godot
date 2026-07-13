# Phase 2: Logic Version Check
testing: skipped

- **Mục tiêu:** Kiểm tra version trên Cloudinary để xem có cần tải file `.pck` mới không.
- **Thực thi trong `download_manager.gd`:**
  - Định nghĩa biến URL tới `version.json` trên Cloudinary.
  - Sử dụng node `HTTPRequest` (đặt tên `VersionRequest`) gửi phương thức GET tới URL này.
  - Parse JSON kết quả trả về để lấy thuộc tính `version_code` và URL file `.pck`.
  - Đọc nội dung file `user://version.json` (nếu có). So sánh:
    - Nếu `version_code` Cloud > `version_code` Local (hoặc chưa có file Local): Chuyển sang Phase 3 (Tải file).
    - Nếu bằng nhau: Chuyển thẳng tới bước Mount (Mount file `.pck` đã lưu sẵn trong máy).
  - Xử lý lỗi timeout/rớt mạng bằng cách hiện thông báo và nút "Thử lại".
