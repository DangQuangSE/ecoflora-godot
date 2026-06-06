# Plan: Shop Navigation
Status: 🟡 In Progress
Date: 2026-06-05
Mode: Fast

## Overview
Add a coin-area tap shortcut in UserHUD that deep-links directly to a new "Nạp Coin" tab (tab 3) in ShopScene, using a lightweight integer flag on UserManager to carry the intent across the scene change.

## Phases
- [x] Phase 1: Autoload Flag — Add `shop_open_tab` int to UserManager so scenes can signal which tab to open
- [x] Phase 2: UserHUD Coin Button — Replace the passive coin display area with a tappable flat Button that sets the flag and navigates to ShopScene
- [x] Phase 3: ShopScene Tab 4 + Read Flag — Add the "Nạp Coin" placeholder tab and wire ShopScene._ready() to read, apply, and reset the flag

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-05
**Phase in progress:** done
**Status:** All 3 phases complete

### Decisions made this session
- CoinButton phủ toàn bộ CoinIcon+CoinLabel (21,123)→(207,152), flat=true, đặt sau cùng để nằm trên z-order
- Tab "Nạp Coin" dùng CenterContainer thay GridContainer — _cache_grids() tự bỏ qua, placeholder TSCN giữ nguyên
- flag reset ngay dòng đầu trước khi set current_tab để đảm bảo không leak

### Next immediate action
User test thực tế

## Research Summary
N/A

## Dependencies
- ShopScene must already exist with a TabContainer at the root level
- UserManager autoload must be registered and loaded before ShopScene or UserHUD are instantiated (already enforced by project.godot load order)

## Risks
- LOW: CoinButton z-order may overlap other HUD controls — mitigation: set mouse_filter correctly and verify no adjacent buttons lose input
- LOW: If ShopScene is already open when the flag is set (e.g., via back-navigation), `_ready()` will not re-run — mitigation: current UX always reaches ShopScene via change_scene, so _ready() is always called; acceptable for MVP scope
