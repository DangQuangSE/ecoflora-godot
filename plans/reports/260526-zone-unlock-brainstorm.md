# Brainstorm: Zone Unlock System (Cloud Overlay)

**Date:** 2026-05-26

## Ideas Explored

- **Mở từng plot đơn lẻ** — mỗi plot có level riêng, granular nhất. Bị loại vì quá rời rạc, khó tạo cảm giác "mở được khu đất mới".
- **Mở zone riêng biệt** — nhiều plot cùng một zone, unlock cả zone cùng lúc bằng 1 tap. **(Đã chọn)** Tạo cảm giác progression rõ ràng.
- **Tự động fade khi đủ level** — đám mây tự tan không cần player tương tác. Bị loại vì mất cảm giác "hành động" của người chơi.
- **Chỉ glow trên mây, không có banner** — ít intrusive hơn nhưng dễ bỏ qua. Bị loại vì không đủ ấn tượng cho milestone level up.

## User's Direction

Nhiều zone riêng biệt (2 zone, mỗi zone 4 plot). Zone 1 yêu cầu Lv3, Zone 2 yêu cầu Lv6.

Khi đạt level → banner trung tâm xuất hiện thông báo. Người chơi tap vào đám mây → đám mây fade out, plots trong zone mở ra.

Bản thân đám mây sẽ dùng hình ảnh thực (người dùng sẽ cung cấp sau), tạm dùng placeholder.

## Open Questions

- Vị trí spatial của 2 zone trên map (bên phải? bên dưới?) — cần thiết kế tile map để có đủ không gian.
- Đám mây tap một lần xua tan cả zone hay từng plot trong zone có mây riêng?
- Cloud glow/pulse effect khi zone trở thành unlockable — cần animation.

## Risks

- **Map không đủ chỗ**: PLOT_POSITIONS hiện tại 2×4 grid từ (80,80)→(200,440). Zone mới cần area riêng trên TileMap — có thể cần mở rộng map.
- **Plot.gd cần is_zone_locked flag**: PlotNode phải chặn interaction khi zone locked; thêm field vào domain cần cẩn thận không phá vỡ logic hiện tại.
- **Thứ tự autoload**: ZoneManager phải load sau UserManager để connect level_up signal.
