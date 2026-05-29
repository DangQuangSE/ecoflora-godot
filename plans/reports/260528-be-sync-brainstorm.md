# Brainstorm: Giải quyết không khớp domain giữa Godot và .NET BE

**Date:** 2026-05-28

## Ideas Explored

- **Option A — Mapping layer trong services/**: Giữ nguyên cả 2 domain, viết mapper ở services/ chuyển đổi BE response → Godot domain. Phù hợp nhất với Clean Architecture hiện tại.
- **Option B — Đồng bộ Godot theo BE**: Sửa Godot domain để field name/type match BE. Bị loại vì Godot domain chứa Guid, nullable FK sẽ không phải game object.
- **Option C — Vá BE cho khớp Godot**: Thêm field game-specific vào BE. Bị loại vì BE là shared server, không nên chứa game logic (harvest_product, ZoneDefinition...).

## User's Direction

Chọn **Option A (mapping layer)**, viết spec đầy đủ trước rồi quyết định thứ tự implement sau.

## Phân nhóm đồng bộ

| Nhóm | Entities | Cách xử lý |
|------|----------|------------|
| Sync 2 chiều | Plot, PlantedFlower, InventoryItem | Fetch từ BE → mapper → Godot domain. Write qua API |
| Push 1 chiều | FocusSession, UserProfile (Level, Currency) | Godot chạy local, push kết quả khi xong |
| Reference data | FlowerTemplate, Item catalog, Synergy | Fetch 1 lần lúc boot, cache local |
| Godot-only | ZoneDefinition, StageDefinition, WeatherState, CareAction | Không sync |

## Open Questions

- Thứ tự implement: UserProfile/Auth → Vườn → Inventory → FocusSession, hay theo phụ thuộc?
- `harvest_product_id` trong InventoryItem: BE chưa có — bỏ khái niệm hay thêm vào BE?
- Khi nào push FocusSession lên BE: ngay khi kết thúc session, hay batch?

## Risks

1. **BE thay đổi schema** sau khi mapper đã viết → cần test integration thường xuyên
2. **XP không tồn tại ở BE** — nếu BE muốn tính thống kê XP server-side thì cần add field sau
3. **harvest_product** là Godot-only concept hiện tại — nếu BE cần track thì phải sync về sau
