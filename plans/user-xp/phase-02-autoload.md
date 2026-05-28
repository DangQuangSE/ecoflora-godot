# Phase 2: Autoload — UserManager

## Layer
`autoloads/` — extends Node. Import domain only. Emit signals cho scenes.

## Files

| File | Layer |
|------|-------|
| `autoloads/UserManager.gd` | autoloads |
| `project.godot` | config |

## Steps

1. Tạo `autoloads/UserManager.gd`:
   ```gdscript
   class_name UserManager
   extends Node

   signal xp_gained(amount: int)
   signal level_up(new_level: int)

   var _profile: UserProfile = UserProfile.new()

   # XP table: keyed on FULL product_id string — NO string parsing
   const _XP_TABLE: Dictionary = {
       "harvest_lotus_bloom":      80,
       "harvest_rose_bloom":       120,
       "harvest_periwinkle_bloom": 60,
   }
   ```

2. Trong `_ready()` — kết nối tại đây, KHÔNG phải trong GardenScene:
   ```gdscript
   func _ready() -> void:
       GardenManager.harvest_completed.connect(_on_harvest_completed)
   ```

3. Implement `_on_harvest_completed(plot_id: String, product_id: String) -> void`:
   - Lookup: `var xp: int = _XP_TABLE.get(product_id, -1)`
   - Nếu `xp == -1`: `push_warning("UserManager: unknown product_id '%s'" % product_id)` → return
   - `_profile.harvest_count += 1`
   - `var crossed := _profile.add_xp(xp)`
   - `xp_gained.emit(xp)`
   - For each level in crossed: `level_up.emit(level)`
   - **QUAN TRỌNG**: Không được gọi lại bất kỳ hàm nào của GardenManager từ đây (tránh re-entrant trong lúc is_pending_sync=true)

4. Expose accessor:
   ```gdscript
   func get_profile() -> UserProfile:
       return _profile
   ```

5. Đăng ký trong `project.godot` — thêm vào section `[autoload]` SAU `InteractionManager`:
   ```
   UserManager="*res://autoloads/UserManager.gd"
   ```
   Thứ tự quan trọng: GardenManager phải được load trước UserManager để `_ready()` kết nối thành công.

## Success Criteria

- `UserManager` xuất hiện trong Remote scene tree khi chạy game
- Harvest 1 hoa Rose → `xp_gained` emit với value 120
- Harvest hoa không có trong table → push_warning, không crash
- Harvest đủ XP để level up → `level_up` emit với new_level đúng
- Không có import `scenes/` hay gọi hàm View trực tiếp

## Spec Stories

- P1: UserManager connects to GardenManager.harvest_completed
- P1: product_id → XP map (lotus 80, rose 120, periwinkle 60)
- P1: emit xp_gained(amount) và level_up(new_level)
- P1: harvest_count tăng mỗi lần harvest

## Testing
Skipped (--no-test).
