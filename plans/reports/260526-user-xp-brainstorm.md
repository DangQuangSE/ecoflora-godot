# Brainstorm: User Avatar + XP System

**Date:** 2026-05-26

## Ideas Explored

- **HUD cố định** — Avatar tròn + thanh XP nhỏ ở góc trên trái, luôn hiển thị, không có popup. Gọn nhất.
- **Avatar có thể tap** — Tap mở mini-profile card: level, tổng XP, số lần thu hoạch. Kiểu FlowerInfoCard nhưng cho user.
- **Level-up animation** — Khi đủ XP: flash hiệu ứng, text "Level Up!" bay lên, thanh XP reset về phần dư.
- **XP cố định mỗi lần harvest** — Đơn giản nhưng không phân biệt công sức chăm sóc từng loại hoa.
- **XP theo loại hoa** — Hoa khó trồng hơn (Rose) cho nhiều XP hơn. User thấy sự khác biệt rõ ràng. **(Đã chọn)**

## User's Direction

Cả 3: HUD đơn giản + tap avatar mở card + level-up animation. XP theo loại hoa (Lotus=80, Rose=120, Periwinkle=60). Level tăng dần: level n cần 200×n XP (level 1→2: 200, level 2→3: 400...). Avatar dùng placeholder icon có sẵn trước.

## Open Questions

- Max level có giới hạn không? (Để ngỏ cho plan — mặc định không giới hạn)
- Profile card hiển thị số harvest theo từng loại hoa hay chỉ tổng?

## Risks

- Level-up animation và float label (+XP) cần không chồng lên nhau về z-order.
- Nếu harvest nhiều lần liên tiếp nhanh, animation level-up có thể queue hoặc bị bỏ qua — cần xử lý.
- UserManager cần biết template_id của hoa vừa harvest để tra XP; hiện `harvest_completed` chỉ emit `product_id`.
