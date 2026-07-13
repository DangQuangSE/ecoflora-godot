# Hoàn thành: GitHub Release Asset Pack

Tính năng tải và gắn gói tài nguyên (Resource Pack `.pck`) từ GitHub Releases đã được triển khai thành công vào dự án Godot của bạn. Game của bạn giờ đây đã sẵn sàng để hoạt động với dung lượng cài đặt siêu nhẹ!

> [!TIP]
> Việc dùng GitHub Releases giúp bạn không tốn bất kỳ chi phí băng thông nào và mang lại tốc độ tải rất ổn định cho game.

## Các thay đổi kỹ thuật (Changes Made)

1. **Tạo `DownloadManager.tscn` và `download_manager.gd`**:
   - Giao diện Loading đơn giản với màn hình màu tối hiện đại (`ColorRect` màu xanh đen `#1f2431`).
   - Tích hợp `ProgressBar` tự động cập nhật tiến độ dựa trên byte đã tải (`get_downloaded_bytes()`).
   - Hai đối tượng `HTTPRequest` riêng biệt để xử lý việc gọi `version.json` và tải file `.pck`.

2. **Cơ chế xử lý mạng & an toàn dữ liệu**:
   - Nếu gọi API `version.json` bị lỗi (VD: Không có mạng), game tự động bỏ qua và nạp luôn bản `.pck` đã lưu trong máy (fallback) để người chơi vẫn có thể chơi offline.
   - Khi tải `.pck` bị lỗi giữa chừng, game tự động xoá file rác (`DirAccess.remove_absolute`) để tránh rác máy và tránh lỗi file bị hỏng ở lần mở tiếp theo.
   - Cờ `download_file = "user://assets.pck"` được cấu hình để file tải về ghi thẳng vào đĩa, tối ưu RAM cho các thiết bị điện thoại.

3. **Cấu hình `project.godot`**:
   - `run/main_scene` đã được đổi từ `SplashScene.tscn` sang `DownloadManager.tscn` để màn hình tải luôn là thứ đầu tiên người chơi thấy. 
   - Sau khi DownloadManager chạy xong xuôi, nó sẽ tự gọi `get_tree().change_scene_to_file("res://scenes/shared/SplashScene.tscn")` để trả game về luồng cũ.

## Hướng dẫn sử dụng cho bạn

Để hệ thống hoạt động thực tế, bạn cần làm theo các bước sau khi muốn cập nhật hình ảnh:

1. Thiết lập **URL version**: Mở file `download_manager.gd`, tìm hằng số `VERSION_URL` ở đầu file và đổi thành đường link dẫn tới file `version.json` trên GitHub của bạn.
   *(Lưu ý: Link này nên là dạng raw, VD: `https://raw.githubusercontent.com/username/repo/main/version.json`)*
2. Cấu trúc file `version.json` bạn đẩy lên GitHub nên như sau:
   ```json
   {
       "version_code": 2,
       "pck_url": "https://github.com/github_user/repo/releases/download/v2.0/assets.pck"
   }
   ```
3. Mỗi khi cập nhật ảnh, bạn xuất thư mục `res://assets` thành file `.pck`, up lên GitHub Releases, và sửa số `version_code` lên 1 đơn vị, game sẽ tự nhận diện và tải về!

> [!WARNING]
> Mọi hình ảnh và tài nguyên bạn để trong file `.pck` phải có đường dẫn nội bộ khớp hoàn toàn với đường dẫn mà các Scene của game đang dùng (ví dụ `res://assets/images/logo.png`). Nếu sai đường dẫn, ảnh sẽ không hiện lên sau khi mount.
