# Brainstorm: Cloudinary Asset Pack cho Godot

**Date:** 2026-07-13

## Ideas Explored
- **Góc nhìn 1: Tải từng ảnh lẻ (Tải file PNG/JPG):** Game tải file danh sách rồi lặp để tải từng ảnh, lưu vào `user://`. Có thể tận dụng Transform của Cloudinary nhưng tải nhiều request tốn thời gian và dễ lỗi mạng. (Bị loại)
- **Góc nhìn 2: Đóng gói thành cục (Tải file `.pck` hoặc `.zip`):** Xuất toàn bộ asset ra `.pck`, tải 1 file duy nhất và mount vào game bằng `ProjectSettings.load_resource_pack()`. (Được chọn vì tối ưu tốc độ và đơn giản)

## User's Direction
Người dùng chọn hướng đi 2: Tải 1 cục `.pck` lớn ở lần đầu mở game và bắt buộc luôn yêu cầu mạng internet. Từng có kinh nghiệm dùng Cloudinary. Giải quyết versioning bằng một file `version.json` nhỏ đặt trên Cloudinary để so sánh với phiên bản dưới local. Màn hình tải (Loading) sẽ có một scene riêng chuyên dụng có hiển thị Progress Bar tiến độ tải file.

## Open Questions
Hiện tại chưa có câu hỏi mở lớn nào, các điểm cần làm rõ về thiết kế tải và kiểm tra phiên bản đã được trả lời.

## Risks
1. File `.pck` lớn có thể bị rớt mạng giữa chừng nếu người chơi dùng mạng yếu, có thể phải cân nhắc thêm xử lý lỗi mạng hiển thị nút Retry.
2. Việc mount file `.pck` thay thế asset cũ phải đảm bảo đúng thư mục (ví dụ `res://assets/`) để script hiện tại không bị lỗi mất đường dẫn ảnh.
