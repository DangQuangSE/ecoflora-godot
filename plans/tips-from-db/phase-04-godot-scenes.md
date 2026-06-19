# Phase 4: Godot Scenes — TipsPanel (1 title + 1 paragraph per tab)

testing: default

## Layer

`scenes/`

## Files

| File | Layer | Action |
|------|-------|--------|
| `scenes/tips/TipsPanel.gd` | scenes | MODIFY — simplify content area |
| `scenes/tips/TipsPanel.tscn` | scenes | MODIFY — optional: đổi `TipsList` → `ContentArea` |
| `docs/tips-guidebook/godot_implement.md` | docs | MODIFY |

## Requirements

P1-3: Mỗi tab = một tip. Vùng nội dung chỉ hiện **tiêu đề + một đoạn văn** — không loop nhiều sub-heading như screenshot cũ.

## Steps

1. **Tab bar** (`_build_tabs`):
   - Nguồn: `TipManager.get_tips()`
   - Mỗi tip → một tab button, `btn.text = tip.title`
   - `_current_tip_id` thay `_current_category_id`

2. **Content area** (`_refresh_content` — thay `_refresh_tips_list`):
   - Tìm tip theo `_current_tip_id`
   - Xóa children cũ
   - Add **một** `TitleLabel` (font 18–20, màu header vàng/nâu)
   - Add **một** `ContentLabel` (`autowrap`, font 14)
   - **Không** add `HSeparator` giữa các sub-section

3. `_ready()`:
   - Connect `TipManager.tips_updated` → `_on_tips_updated` → rebuild tabs
   - Initial build từ `TipManager.get_tips()`

4. `show_panel()`:
   - Nếu tips rỗng → `await TipManager.refresh_async()`

5. Tab bar nhiều tips: set `Tabs` HBoxContainer hoặc wrap trong `ScrollContainer` horizontal nếu >4 tabs.

6. Cập nhật `godot_implement.md`: admin thêm tip = thêm tab mới trên Swagger.

## Success Criteria

- Tab "Hệ Sinh Thái" → **1** đoạn văn, không còn 5 tiểu mục
- Admin POST tip "Thu Hoạch" → tab mới xuất hiện
- Toggle/close/dimmer không đổi
- Smoke: portrait 720×1280, tab bar không tràn (scroll nếu cần)

## Visual reference

```
┌─ Mẹo Chơi ─────────────────────── ✕ ┐
│ [Hệ Sinh Thái] [Thu Hoạch] ...      │  ← tabs = tip.title
├─────────────────────────────────────┤
│  Hệ Sinh Thái                       │  ← title header
│                                     │
│  Vườn chia thành nhiều zone. Khi    │  ← content (1 paragraph)
│  mọi cây cùng Synergy...            │
└─────────────────────────────────────┘
```

## Risks

- Tab text dài → truncate hoặc font nhỏ hơn trên mobile
