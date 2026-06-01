# Brainstorm: Focus Session Item Reward + BE Sync Test

**Date:** 2026-05-31

## Ideas Explored

- **Timer Pomodoro-style (base)**: Đã implement đầy đủ — timer, violations (3 lần minimize → fail), BE sync POST/PATCH. Không cần làm lại.
- **Reward XP/phút (hiện tại)**: +1 XP/phút cho tất cả hoa khi hoàn thành, -20 XP khi fail. Bị bỏ cho success path.
- **Reward item theo thời lượng session**: Hardcode table trong BE `RewardCalculationService` theo milestone Pomodoro. ← **Chọn**
- **Reward item random mỗi phút**: Xác suất theo loại item. Bị loại — quá phức tạp, khó tune balance.
- **Admin config reward qua API**: Linh hoạt nhất nhưng cần thêm BE endpoint, table, UI admin. Để P3.
- **Android foreground service**: Giữ timer khi minimize. Bị loại khỏi scope demo — không minimize app trong lúc trình bày với hội đồng, 2 ngày công cho 0 demo value.

## User's Direction

**A + C**: Item reward theo milestone session duration (hardcode `RewardCalculationService` trong .NET, dễ swap sang DB sau) + test BE sync end-to-end trước demo.

Reward XP cho hoa bị loại khỏi success path — chỉ nhận item. Kết nối rõ ràng giữa focus session và garden gameplay (item đổi thành resource chăm hoa).

Reward table chốt:
| Session duration | Items |
|---|---|
| 25 phút | 2× Watering Can |
| 50 phút | 2× Watering Can + 1× Fertilizer |
| 75 phút | 3× Watering Can + 2× Fertilizer |
| ≥100 phút | 3× Watering Can + 2× Fertilizer + 1× Pesticide |

## Open Questions

- Khi session FAIL (-20 XP penalty hiện tại): có giữ nguyên penalty hay bỏ hẳn? Spec để `[NEEDS CLARIFICATION]`.
- `PATCH /api/focus/{id}/complete` hiện trả gì? Cần xác nhận response format trước khi Godot parse.

## Risks

- BE `FocusService` hiện chưa test end-to-end — task C phải chạy trước khi cook A.
- `InventoryManager.add_harvest_product` dùng để thêm item không có sẵn trong inventory — cần confirm nó cũng work cho items (watering can, fertilizer) chứ không chỉ harvest products.
- Reward table hardcode trong BE → nếu balance sai phải deploy lại. Acceptable cho demo.
