# Brainstorm: Shop Navigation — Coin tap → Nạp Coin tab

**Date:** 2026-06-05

## Ideas Explored

- **Tab 4 trong ShopScene** vs scene riêng — chọn tab 4, ít phức tạp hơn, UX nhất quán.
- **Flag autoload** vs signal chain — chọn flag (`UserManager.shop_open_tab`), 1 dòng set trước `change_scene`, đọc trong `_ready()`.
- **CoinButton flat** vs overlay vô hình — chọn Button flat thay Label, rõ ràng hơn trong scene tree.
- **IAP vs in-game exchange** — chưa quyết định, làm placeholder UI trước.

## User's Direction

ShopScene tab 4, autoload flag, Button flat. Content "Nạp Coin" là placeholder — backend/logic sau.

## Open Questions

- Nội dung tab Nạp Coin khi có backend: IAP hay in-game exchange?
- Có cần animation/highlight khi ShopScene mở đúng tab không?

## Risks

- `UserManager.shop_open_tab` là state toàn cục — nếu scene change bị interrupt (lỗi mạng), flag không được reset → lần mở sau mở nhầm tab. Mitigation: reset ngay đầu `_ready()`.
- CoinButton flat cần cùng font/color với CoinLabel cũ, không được thay đổi visual.
