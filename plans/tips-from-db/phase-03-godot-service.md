# Phase 3: Godot — TipService + TipManager (flat list)

testing: default

## Layer

`domain/` → `services/` → `autoloads/`

## Files

| File | Layer | Action |
|------|-------|--------|
| `domain/GameTip.gd` | domain | MODIFY — `content` thay `body`, bỏ `category_id`, `from_dict()` |
| `domain/TipCatalog.gd` | domain | MODIFY — offline fallback: 1 merged tip |
| `services/TipService.gd` | services | CREATE |
| `autoloads/TipManager.gd` | autoloads | CREATE |
| `project.godot` | config | MODIFY — register TipManager after UserManager |
| `tools/test_tip_catalog.gd` | tools | MODIFY |
| `tools/test_tip_service.gd` | tools | CREATE |

**Không tạo** `TipCategory.gd`.

## Requirements

P1-2, P2-1, P2-2: Fetch flat list từ `GET /api/game-tips`, cache, fallback.

## Steps

1. **`GameTip`** simplify:
   ```gdscript
   var id: String
   var title: String
   var content: String
   var sort_order: int = 0
   static func from_dict(d: Dictionary) -> GameTip
   ```

2. **`TipCatalog`** — offline fallback only:
   - `build_offline_fallback() -> Array[GameTip]` — 1 tip:
     - `title = "Hệ Sinh Thái"`
     - `content` = gộp 5 đoạn synergy hiện tại thành 1 paragraph
   - Bỏ `get_categories()` / `get_tips_for_category()`

3. **`TipService.gd`**:
   - `fetch_tips_async(http, base_url) -> Array[GameTip]`
   - `GET {base_url}/api/game-tips` — anonymous OK
   - Parse `data` array, map `content` field, sort `sort_order`

4. **`TipManager`** autoload (mirror `TaskManager`):
   - `signal tips_updated(tips: Array[GameTip])`
   - `get_tips() -> Array[GameTip]` — sorted copy
   - `refresh_async()` on `UserManager.login_succeeded`
   - Cache `user://tips_cache.json` on success
   - On fail: cache → `TipCatalog.build_offline_fallback()`

5. Register `TipManager` after `UserManager` in `project.godot`.

6. Tests: parse mock JSON; fallback returns 1 tip with non-empty content.

## Success Criteria

- `TipManager.get_tips().size() >= 1` offline
- No `category_id`, no `TipCategory`
- No `print()`

## Risks

- Rename `body` → `content` breaks callers — fix in phase 4 same PR
