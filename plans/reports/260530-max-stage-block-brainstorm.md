# Brainstorm: Max Stage Care Block + Floating Notification

**Date:** 2026-05-30

## Ideas Explored

- **A — Plot.gd chặn, reuse FloatLabel nguyên xi**: Guard trong `_apply_item()`, hiện label vàng "ĐÃ ĐẠT LEVEL TỐI ĐA". Đơn giản nhất nhưng label cùng màu vàng với +XP → khó phân biệt.
- **B — Plot.gd chặn + color param vào FloatLabel.play()**: Thêm optional `color` param, dùng màu đỏ/cam cho max level message. Tái dụng scene sẵn, phân biệt rõ. ← **Chọn**
- **C — GardenManager emit signal `care_blocked`**: Logic tập trung ở Manager, PlotNode lắng nghe. Thừa cho UI-only feedback, thêm signal/connection không cần thiết.

## User's Direction

Chọn **B**: chặn tại `Plot.gd._apply_item()`, thêm color param vào `FloatLabel.play()` để phân biệt thông báo max level với +XP gain.

## Open Questions

- Màu cụ thể cho "max level" label: đỏ? cam? (cần quyết định khi implement)
- Text chính xác: "ĐÃ ĐẠT LEVEL TỐI ĐA" hay "MAX LEVEL!" hay viết thường?

## Risks

- FloatLabel font size 14 + text dài có thể bị cắt nếu label width không đủ — cần test trên màn hình nhỏ.
- Nếu sau này FloatLabel được dùng nhiều chỗ với color, cần đảm bảo default color giữ nguyên vàng (backward compat).
