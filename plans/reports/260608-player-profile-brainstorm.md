# Brainstorm: Player Profile Feature

**Date:** 2026-06-08

## Ideas Explored

- **Fix input only** — Tap UserHUD → open card. CoinButton likely blocks `_gui_input`; simplest fix is a dedicated invisible ProfileButton overlay on avatar+name area.
- **Bottom sheet redesign** — Keep slide-up UX but add farming theme (green/brown/wood), stat icons, farming assets from `assets/profile/`.
- **Login streak vs join date** — User confirmed they want consecutive login streak (chuỗi đăng nhập liên tiếp), not just join date. Requires BE-side tracking: `login_streak + last_login_date`.
- **Flower count client-side** — Computed from `InventoryManager` at card open time (filter items by category == "flower"). No new BE endpoint needed.
- **Avatar preset vs upload** — User wants file upload. Mobile constraint: Android has no built-in FileDialog. Decision: FileDialog for PC/Editor first, Android native plugin later.
- **Full avatar system** — Preset pool + upload. P2 scope.

## User's Direction

Bottom sheet profile card with farming theme. Stats: Level, Total XP, Harvest Count, Login Streak, Flowers Owned. Avatar: preset pool + PC file upload (Android later). Fix tap input first.

## Open Questions

1. `login_streak` — managed server-side (authoritative) or client-side (simpler but cheat-prone)?
2. What category/type string identifies "flower" items in InventoryManager?
3. Should avatar upload go to a dedicated BE endpoint or piggyback on profile update?
4. Does eco-backend already have `created_at` on User entity that could serve as join date?

## Risks

1. **Login streak accuracy**: If tracked client-side, easily manipulated. BE-side adds complexity (migration needed).
2. **Avatar upload on mobile**: FileDialog is desktop-only. Releasing to Android without a native plugin means the upload button silently does nothing — needs a clear UI guard (`OS.get_name() == "Android"` → show preset only).
3. **Input blocking**: `_gui_input` on UserHUD vs CoinButton click area overlap — must test after fix to ensure CoinButton still opens shop.
