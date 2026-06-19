# Phase 1: Domain — GameTip & TipCatalog

testing: default

## Layer

`domain/` — RefCounted only, no Node, no autoload imports

## Files

| File | Layer | Action |
|---|---|---|
| `domain/GameTip.gd` | domain | CREATE |
| `domain/TipCatalog.gd` | domain | CREATE |

---

## Requirements

Model dữ liệu thuần cho mẹo chơi theo **chủ đề (category)**. v1 chỉ seed chủ đề **Hệ Sinh Thái** (`synergy`) — nội dung lấy từ `plans/zone-synergy/spec.md`, không dùng `LoadingScreen.TIPS`.

---

## Steps

1. Tạo `domain/GameTip.gd` (`extends RefCounted`, `class_name GameTip`) với: `id: String`, `category_id: String`, `title: String`, `body: String`. Constructor `_init(id, category_id, title, body)`.

2. Tạo `domain/TipCatalog.gd` (`extends RefCounted`, `class_name TipCatalog`):
   - `static func get_categories() -> Array[Dictionary]` — mỗi entry `{ "id": String, "label": String }`
   - `static func get_tips_for_category(category_id: String) -> Array[GameTip]`

3. v1 — một category: `synergy` / label **"Hệ Sinh Thái"**.

4. Seed ≥4 `GameTip` trong category `synergy` (tiếng Việt, dễ hiểu cho mobile):
   - **Synergy Zone là gì?** — zone thuần khi mọi cây đang trồng cùng một nhóm Synergy
   - **Cần ít nhất 2 cây** — ≥2 cây cùng Synergy; ô trống không tính; 1 cây chưa bonus
   - **Nhận thêm XP khi chăm sóc** — tưới/bón/phun cộng `xpPlus` (vd. Sun Chaser +10, Water Lover +5)
   - **Nhận biết & mất bonus** — hiệu ứng zone + float label; mất khi trộn Synergy, harvest còn <2, hoặc cây không có Synergy

5. Không import `LoadingScreen`, không tip trường học hay tip ngoài scope synergy.

---

## Success Criteria

- `get_categories().size() == 1` với id `synergy`
- `get_tips_for_category("synergy").size() >= 4`
- Mỗi tip có `id`, `title`, `body` không rỗng
- `godot --headless --check-only --script res://domain/TipCatalog.gd` pass
- Không `extends Node`, không autoload import, không `print()`

---

## Risks

- Số `xpPlus` hardcode trong text có thể lệch BE — dùng ví dụ định tính ("Sun Chaser +10") khớp mock seeder hiện tại
