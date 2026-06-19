# Brainstorm: Nạp coin trong shop qua PayOS

**Date:** 2026-06-19

## Ideas Explored

- **Hiển thị thanh toán:** QR render trong game (chosen) vs mở browser ngoài tới `checkoutUrl` PayOS — browser ngoài đơn giản hơn code nhưng "thoát app" làm gãy UX mobile game.
- **Render QR:** BE tự generate ảnh QR và trả URL/base64 (chosen) vs Godot tự encode QR từ chuỗi VietQR data bằng addon — addon thêm dependency client chưa kiểm chứng tương thích Godot 4.
- **Xác nhận thanh toán:** Client polling status mỗi 2-3s (chosen) vs SignalR/socket realtime push vs nút "Tôi đã thanh toán" thủ công — polling đơn giản nhất, không cần hạ tầng realtime mới.
- **Loại coin:** Cộng trực tiếp vào `User.Currency` hiện có (chosen) vs tách premium currency riêng (gem/diamond) — project chưa có khái niệm 2 loại tiền, tách ra là over-engineering ở giai đoạn này.
- **Gói coin:** Cố định theo tier (chosen) vs cho nhập số tiền tự do — gói cố định dễ kiểm soát tỷ giá và validate, tránh số tiền lẻ gây khó quy đổi.

## User's Direction

Nạp coin bằng tiền thật qua PayOS, hiển thị QR ngay trong game (không mở browser), tỷ giá **10 coin = 1.000đ**. Người dùng quét QR bằng app ngân hàng, client tự poll để biết khi nào coin được cộng. Coin nạp dùng chung balance (`User.Currency`) với coin đang có trong shop — không tạo loại tiền mới. PayOS merchant account chưa đăng ký (việc này nằm ngoài scope code).

Scout xác nhận: backend hiện tại **chưa có gì** liên quan (không có Order/Payment entity, không có PayOS code, không có config sandbox) — đây là tính năng mới hoàn toàn, không cần tương thích ngược.

## Open Questions

- Danh sách gói coin cụ thể (số tiền/số coin mỗi tier) — chưa chốt số thật, dùng placeholder theo tỷ giá 10 coin/1.000đ.
- Gói coin nên hard-code/seed hay admin-configurable như daily task reward (tiền lệ gần nhất trong project)? Chưa quyết định.
- Cơ chế chống credit trùng khi PayOS gọi lại webhook (retry) hoặc khi polling + webhook cùng lúc xác nhận PAID.
- Thời gian hết hạn của 1 đơn hàng chờ thanh toán (PendingOrder) — bao lâu thì coi là expired/cancelled.

## Risks

- **Chưa có PayOS merchant account** → không thể test end-to-end thật (webhook, ChecksumKey) cho đến khi đăng ký xong; có thể phát triển trước theo PayOS sandbox docs rồi wire credential sau.
- **Tiền thật → integrity risk:** phải đảm bảo cộng coin đúng-một-lần-duy-nhất cho mỗi đơn PAID, kể cả khi webhook retry hoặc client poll trùng thời điểm. Cần ràng buộc idempotency ở DB (unique `orderCode` + transition guard trên status), không phải optional.
- **Godot phía client cần load ảnh QR qua network** (HTTPRequest + decode buffer) — không khó nhưng cần xử lý trạng thái loading và trạng thái order hết hạn khi QR đang hiển thị.
