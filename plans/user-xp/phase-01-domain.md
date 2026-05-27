# Phase 1: Domain — UserProfile

## Layer
`domain/` — RefCounted only. Không có Node, không import autoload, không có signal.

## Files

| File | Layer |
|------|-------|
| `domain/UserProfile.gd` | domain |

## Steps

1. Tạo `domain/UserProfile.gd`:
   ```gdscript
   class_name UserProfile
   extends RefCounted

   var level: int = 1
   var current_xp: int = 0
   var total_xp_earned: int = 0
   var harvest_count: int = 0
   ```

2. Thêm helper `xp_to_next_level() -> int`:
   ```gdscript
   func xp_to_next_level() -> int:
       return 200 * level
   ```
   Level 1→2: 200 XP, Level 2→3: 400 XP, Level 3→4: 600 XP...

3. Thêm `add_xp(amount: int) -> Array[int]`:
   - Nếu amount <= 0: gọi `push_warning()` và return `[]`
   - Tích lũy vào `current_xp` và `total_xp_earned`
   - **While loop**: trong khi `current_xp >= xp_to_next_level()`:
     - Trừ threshold khỏi `current_xp` (carry-over, không reset về 0)
     - Tăng `level`
     - Append level mới vào array kết quả
   - Return array (rỗng nếu không level up)

## Success Criteria

- Trace `add_xp(250)` từ level 1 (0 XP): level=2, current_xp=50, total_xp_earned=250, return=[2]
- Trace `add_xp(700)` từ level 1: level=3, current_xp=100, total_xp_earned=700, return=[2,3]
  (Vượt 200 → level 2 còn 500, vượt 400 → level 3 còn 100)
- `add_xp(0)` return [] và push_warning
- Không có `Node`, `$`, `get_tree()`, import autoload nào trong file

## Spec Stories

- P1: UserProfile domain class với level, current_xp, total_xp_earned, harvest_count
- P1: XP-to-next-level = 200 × current_level (tăng dần)
- P1: add_xp() multi-level-up trả về Array[int] các level đã vượt

## Testing
Skipped (--no-test).
