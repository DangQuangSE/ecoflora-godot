# Plan: Tips Guidebook (Sách Hướng Dẫn)

Status: ✅ Complete
Date: 2026-06-15
Mode: Hard

## Overview

Thêm nút sách mẹo (`tip_icon.png`) ngay dưới icon tim trong `VitalityBar`. Khi bấm, mở panel toàn màn hình giống kho đồ — tiêu đề **"Mẹo Chơi"**, tab theo chủ đề, nội dung cuộn trong tab. v1 chỉ có chủ đề **Hệ Sinh Thái** (zone synergy) giúp người chơi hiểu cách nhận thêm XP khi trồng cây cùng nhóm Synergy.

## User Decisions (2026-06-15)

| # | Quyết định |
|---|------------|
| 1 | Tiêu đề panel: **"Mẹo Chơi"** |
| 2 | Điều hướng: **tab theo chủ đề** (không Prev/Next) |
| 3 | v1 nội dung: **chỉ tips từ zone-synergy** (bonus XP khi trồng cùng Synergy) |
| 4 | **Không** migrate tips LoadingScreen (trường học, v.v.) |
| 5 | Đóng panel: **✕ + chạm dimmer + bấm lại icon sách** (toggle) |

## Phases

- [x] Phase 1: Domain — `GameTip` + `TipCatalog` (chủ đề synergy, ≥4 tips)
- [x] Phase 2: Scenes — `TipsPanel` (modal + tab chủ đề + scroll nội dung)
- [x] Phase 3: Scenes — Gắn nút Tips vào `VitalityBar` + wire `HUD` (toggle, exclusivity)

## Research Summary

**UI pattern:** Mirror `InventoryPanel` — dimmer, close, tab bar (giống `BtnAll`/`BtnSeed`), `show_panel()`/`hide_panel()`. Tab chọn chủ đề → `ScrollContainer` liệt kê các tip (title + body) trong chủ đề đó.

**Nội dung v1** (từ `plans/zone-synergy/spec.md`):
- Điều kiện: ≥2 cây cùng Synergy trong zone, mọi cây occupied cùng nhóm, ô trống bỏ qua
- Bonus: tưới/bón/phun + `xpPlus` (Sun Chaser +10, Water Lover +5)
- Feedback: particle zone + float label `+XP` / `+🌿`
- Mất bonus: mixed synergy, harvest còn <2, cây không có synergy

## Dependencies

- Asset `res://assets/icon/tip_icon.png` — đã có
- Feature zone-synergy đã implement (`SynergyEvaluator`, indicators)
- Pattern `InventoryPanel` — reference tabs + modal
- Không cần autoload mới, không cần BE

## Risks

- MEDIUM: VitalityBar cao hơn — kiểm tra portrait 720×1280
- MEDIUM: Panel exclusivity inventory/shop/tips — wire hai chiều trong HUD
- LOW: v1 chỉ 1 tab — tab bar vẫn render 1 tab để sẵn sàng mở rộng chủ đề sau
- LOW: Shop dismiss dùng `_shop_panel.hide()`, không `hide_panel()`

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-15
**Phase in progress:** complete
**Status:** All 3 phases implemented — domain, TipsPanel, HUD/VitalityBar wiring

### Decisions made this session
- Tab buttons built dynamically from `TipCatalog.get_categories()` for easy future categories
- TipsPanel uses navy StyleBoxFlat (book theme) instead of inventory parchment bg
- VitalityBar height 52×124; HUD VitalityBar offset_bottom 282
- Mutual exclusivity: inventory ↔ tips ↔ shop (bidirectional)

### Next immediate action
User smoke-tests in Godot Editor per `docs/tips-guidebook/godot_implement.md`
