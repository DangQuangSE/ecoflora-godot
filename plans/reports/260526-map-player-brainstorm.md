# Brainstorm: Map + Player Movement

**Date:** 2026-05-26

## Ideas Explored

- **Scene tĩnh (tap-only)** — dismissed, user muốn player di chuyển thực sự
- **Side-scroll** — dismissed, không phù hợp garden game
- **1 TileMap lớn gộp garden + school** — loại bỏ vì overkill cho MVP, khó quản lý 2 domain logic trên 1 scene
- **Tap-to-move** — đơn giản nhưng user muốn joystick trải nghiệm tốt hơn
- **Static joystick góc trái** — ổn nhưng chiếm diện tích màn hình dọc
- **2 Scene riêng (Garden + School)** → **CHOSEN** — sạch, đúng kiến trúc, dễ mở rộng
- **Dynamic floating joystick (hold 1s)** → **CHOSEN** — UX tốt cho portrait, không chiếm diện tích cố định

## User's Direction

> "Top-down, vườn + khu school, tileset free Itch.io/OpenGameArt, virtual joystick nhấn giữ 1 giây ở phần dưới màn hình thì xuất hiện, animation đơn giản kiểu Retrotopia NPC"

2 Scene riêng, Kenney assets (CC0), dynamic joystick appear-on-hold, 4-directional pixel art animation.

## Open Questions

- **Interaction zone:** Khi player đứng gần PlotView, tương tác bằng tap riêng hay auto-prompt? (chưa giải quyết — thuộc feature garden interaction, không phải movement MVP)
- **Camera bounds:** Garden scene có giới hạn scroll không hay để free follow player?
- **Portal visual:** Transition giữa 2 scene dùng fade/cut hay animated door?

## Risks

1. **Dynamic joystick + swipe garden interaction:** Cả 2 đều dùng `InputEventScreenDrag`. Cần phân biệt touch ở vùng dưới (joystick zone) vs touch ở vùng garden (swipe care action). Giải pháp: chia screen thành 2 vùng input bằng `Rect2`.
2. **Tileset Kenney style không match design Vi t Nam:** CC0 là placeholder — final art cần replace. Không phải vấn đề cho MVP demo.
3. **AnimatedSprite2D spritesheet format:** Kenney RPG Characters có sẵn 4-directional walk, cần kiểm tra frame size trước khi import.
