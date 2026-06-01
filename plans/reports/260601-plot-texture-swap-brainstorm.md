# Brainstorm: Plot Texture Swap

**Date:** 2026-06-01

## Ideas Explored

- **Swap texture on Sprite2D** — đổi PlotSprite từ ColorRect sang Sprite2D, swap texture trong `_refresh_visual()` dựa trên `last_watered_at`. Đơn giản, fit hoàn toàn với kiến trúc hiện tại.
- **AnimatedSprite2D** — dùng animation frames để transition giữa hai trạng thái. Thừa phức tạp cho bài toán này.
- **ShaderMaterial** — blend giữa hai texture bằng shader. Overkill, không cần thiết.

## User's Direction

Swap texture trực tiếp — `plot.png` (bình thường) / `sweet_plot.png` (có cây + vừa tưới trong 3600s).

## Open Questions

- Kích thước `plot.png` và `sweet_plot.png` là bao nhiêu? (cần set scale cho Sprite2D khớp 64×64 hoặc để texture tự scale)
- `PlotSprite` hiện là ColorRect — sau khi đổi sang Sprite2D có cần giữ lại physics collision shape không?

## Risks

- ColorRect → Sprite2D thay đổi node type trong tscn, cần reload scene trong editor
- `_refresh_visual()` chạy mỗi lần data update — nếu gọi nhiều lần liên tiếp không có cache thì tốn load texture lặp (dùng preload để tránh)
