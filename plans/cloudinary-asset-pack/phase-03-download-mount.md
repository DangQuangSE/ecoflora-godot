# Phase 3: Download & Mount
testing: skipped

- **Mục tiêu:** Tải file `.pck` mới từ Cloudinary (nếu cần), mount vào Godot và chuyển sang MainMenu.
- **Thực thi trong `download_manager.gd`:**
  - Sử dụng node `HTTPRequest` (đặt tên `DownloadRequest`).
  - Đặt cờ `download_file = "user://assets.pck"` để luồng dữ liệu tự động ghi vào đĩa thay vì tốn RAM.
  - Gọi `request(url)` tới URL tải file `.pck` đã lấy từ Phase 2.
  - Sử dụng hàm `_process(delta)` kiểm tra `%` hoàn thành: `DownloadRequest.get_downloaded_bytes()` chia cho `DownloadRequest.get_body_size()`. Gán vào `ProgressBar.value`.
  - Bắt signal `request_completed`. Nếu thành công:
    - Lưu (ghi đè) file `user://version.json` với nội dung version mới vừa tải.
    - Gọi hàm `ProjectSettings.load_resource_pack("user://assets.pck")`.
    - Chuyển scene tới `MainMenu` thông qua `get_tree().change_scene_to_file("res://MainMenu.tscn")` (Thay bằng scene gốc hiện tại của dự án).
  - Nếu gặp lỗi mạng: Hiện thông báo lỗi và xoá file rác đang tải dang dở để tránh lỗi file `.pck` bị hỏng.
