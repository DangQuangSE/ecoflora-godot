# Brainstorm: Hợp nhất giao diện tải dữ liệu (LoadingScreen & DownloadManager)

**Date:** 2026-07-13

## Ideas Explored
1. **Thay thế hoàn toàn**: Loại bỏ hoàn toàn UI cũ của `DownloadManager`, tích hợp gọi `LoadingScreen` để hiển thị tiến trình khi tải file `.pck`. Không cần chức năng retry hay báo trạng thái rườm rà.
2. **Dùng LoadingScreen như một Overlay**: Vẫn giữ UI cũ để hiển thị lúc bị lỗi (Retry), nhưng lúc đang tải thì phủ LoadingScreen lên trên.
3. **Tự động Retry**: Ẩn đi hoàn toàn giao diện cũ, dùng LoadingScreen kết hợp logic tự động tải lại ngầm định nếu lỗi xảy ra.

## User's Direction
Người dùng chọn **Phương án 1 (Thay thế hoàn toàn)**: "Tôi muốn thay thế hoàn toàn, không cần retry, không cần nhãn status, chỉ cần hiện loading screen khi đang tải các tài nguyên từ assets.pck".
Lý do: Đơn giản hoá giao diện, giữ sự đồng bộ về mặt hình ảnh (visual) trong suốt vòng đời của game, không cần thiết các thao tác phức tạp xử lý lỗi từ người dùng (hoặc chấp nhận tải lỗi thì fallback về file local).

## Open Questions
- Không có câu hỏi nào bị treo. Hướng đi đã rõ ràng.

## Risks
1. Nếu việc tải tài nguyên bị thất bại, người dùng sẽ không biết nguyên nhân và không có cách thử lại thủ công (ngoại trừ việc thoát game và mở lại). Cần đảm bảo có cơ chế xử lý lỗi/fallback về dữ liệu cũ ổn định.
