# Brainstorm: Shop UI Rebuild — Asset-Driven Layout

**Date:** 2026-06-06

## Ideas Explored

- **TabContainer mặc định** — bị loại bỏ: không tùy chỉnh visual được, không dùng được TextureButton làm tab.
- **Nhiều ScrollContainer ẩn/hiện** — bị loại bỏ: tốn bộ nhớ, khó maintain khi catalog lớn.
- **Single GridContainer + swap data (chọn)** — clear & repopulate khi đổi tab. Nhẹ, data-driven, dễ wire với API thật sau.
- **NinePatchRect cho shop_card.png** — đảm bảo ảnh card không bị biến dạng khi card có kích thước khác nhau.
- **TextureButton cho tabs** — dùng shop_tab.png (normal) / shop_tab_clicked.png (pressed/active). Visual nhất quán với mockup.

## User's Direction

Single GridContainer, data-driven. Tab press → `queue_free()` children → `render_shop_items(items)` từ mock Array[Dictionary{id, name, price, icon_path}]. 3 columns. shop_card.png làm nền card. shop_bg.png làm nền ShopPanel.

## Open Questions

- Vị trí pixel chính xác của TabGroup và ScrollContainer trong shop_bg.png phụ thuộc vào kích thước thực của ảnh — cần chỉnh thủ công trong Godot editor sau khi implement.
- NinePatchRect patch margins cho shop_card.png chưa biết — cần thử trong editor.
- Khi có API thật: mock Dictionary sẽ được replace bởi `UserManager.get_shop_catalog_async()`, vẫn convert sang ShopItem trước khi setup card.

## Risks

- shop_bg.png có thể có vùng không trong suốt ở vị trí tab/grid — TabGroup và ScrollContainer cần căn chỉnh thủ công theo pixel.
- NinePatchRect yêu cầu set `patch_margin_*` đúng để không bị vỡ ảnh — cần thử sau khi chạy.
- ShopItemCard.gd hiện dùng `ShopItem` domain object — cần giữ convert layer trong ShopScene thay vì cho card nhận Dictionary trực tiếp.
