# Phase 1: Giao diện Loading Scene
testing: skipped

- **Mục tiêu:** Tạo scene `DownloadManager.tscn` và script `download_manager.gd` làm màn hình đầu tiên khi bật game.
- **Thành phần UI:** 
  - `Control` node làm gốc.
  - `ProgressBar` hiển thị % tải.
  - `Label` thông báo trạng thái hoạt động (Đang kiểm tra..., Đang tải..., Thành công!).
  - `Button` Thử lại (mặc định ẩn, hiện ra khi lỗi mạng).
- **Yêu cầu:** Giao diện này không được sử dụng các asset nằm trong file `.pck` sắp được tải. Chỉ dùng asset mặc định hoặc nhúng thẳng trong project base.
