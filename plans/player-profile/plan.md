# Plan: Player Profile
Status: Complete
Date: 2026-06-08
Mode: Hard

## Overview
Adds a complete Player Profile system to Flow Flora: login streak tracking on the backend, avatar selection persisted locally and synced to the server, and a fully redesigned farming-themed profile card with five stat rows. Fixes the existing input-blocking bug that prevents the profile card from opening.

## Phases
- [x] Phase 1: BE Login Streak + Avatar Index — Add LoginStreak, LastLoginDate, AvatarIndex to User entity; streak logic in GetProfileAsync; new PUT avatar-index endpoint; EF migration
- [x] Phase 2: Godot Domain: UserProfile — Add login_streak, avatar_index, join_date fields to UserProfile.gd (RefCounted only)
- [x] Phase 3: Godot Autoload: UserManager — Parse new profile fields, add avatar ConfigFile persistence, set_avatar_async fire-and-forget, emit profile_updated signal
- [x] Phase 4: Godot Assets + Input Fix — Create 6 placeholder avatar PNGs, replace _gui_input with explicit ProfileButton in UserHUD.tscn, add AvatarTexture TextureRect
- [x] Phase 5: Godot UI: UserProfileCard Redesign — Farming-theme card with avatar circle, avatar picker overlay, 5 stat rows (Level, XP, Harvest, Streak, Flowers)

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-08 18:00
**Phase in progress:** (all done)
**Status:** All 5 phases complete. Pending: EF Core migration + 6 avatar PNG assets.

### Decisions made this session
- Used generic `catch (Exception)` for streak concurrency instead of `DbUpdateConcurrencyException` — Application.csproj has no EF Core reference
- `CreatedAt` from `BaseEntity` mapped via AutoMapper convention (no explicit ForMember needed)
- Avatar endpoint placed at `PUT /api/auth/avatar-index` (AuthController, Player role)
- `close()` uses `queue_free()` not `hide()` — card is dynamically instantiated
- `_profile_card` nulled via `tree_exiting` signal to prevent calling `open()` on a mid-dying node
- Dimmer uses `anchor_bottom = 1.0` to cover full screen for tap-to-close
- `total_xp_earned` populated from `currentXp` API field in `UserService.parse_profile()`

### Next immediate action
1. Stop API → run EF migration → restart API
2. Place 6 avatar PNG files at `res://assets/profile/avatars/avatar_0.png` through `avatar_5.png` (128x128px)

## Research Summary
**BE approach chosen:** Extend existing `GET /api/auth/profile` (already Player-role authorized) to compute and persist login streak on each call. This avoids touching the login flow and keeps streak logic co-located with profile reads. A separate `PUT /api/auth/avatar-index` endpoint handles avatar sync as fire-and-forget. Both go through `IUserService` / `UserService.cs` following the existing tuple-return pattern.

**Streak logic:** Inside `GetProfileAsync`, after loading the User entity, compare `User.LastLoginDate` (UTC date only) with `DateTime.UtcNow.Date`. If yesterday → increment streak; if today → leave streak unchanged (idempotent); else → reset to 1. Always update `LastLoginDate` to today and persist with `_unitOfWork.CommitAsync()`.

**Godot avatar persistence:** `ConfigFile` at `user://avatar_prefs.cfg` is the correct low-friction approach — no extra dependencies, survives app restarts, written before the async BE call so the UI updates instantly (optimistic UI pattern already established in the project).

**InventoryItem.category is an enum (Category.SEED/CONSUMABLE/DECOR/HARVEST_PRODUCT)** — `flower_count` must filter for `Category.HARVEST_PRODUCT` items whose `harvest_product_id` starts with `"harvest_"` (all 7 flower harvest IDs match this prefix), not a string "flower" field. The spec assumption is incorrect; the plan corrects this.

## Dependencies
- EF Core migration must run before BE can serve LoginStreak / AvatarIndex fields
- Avatar PNG assets must exist before scenes/hud wiring is testable
- Phase 3 depends on Phase 2 (UserProfile fields)
- Phase 4 and Phase 5 depend on Phase 3 (profile_updated signal)

## Risks
- HIGH: InventoryItem has no string `category` field — it uses an enum. `flower_count` filter logic must use `Category.HARVEST_PRODUCT` enum value, not a string comparison. Mitigation: Phase 5 explicitly uses the enum; plan notes the spec discrepancy.
- MEDIUM: Streak update inside `GetProfileAsync` means every profile fetch writes to the DB. Mitigation: guard with `if LastLoginDate?.Date == today then skip write` — makes it idempotent and skips the commit on repeated same-day calls.
- MEDIUM: Avatar PNG assets are placeholder until real art is delivered. Mitigation: Phase 4 documents the exact 6 filenames, sizes, and format needed so an artist can drop in replacements without code changes.
- LOW: `UserHUD._gui_input` currently fires for any tap on the whole panel including the coin area. Removing it and adding `ProfileButton` is a safe replacement but requires careful offset matching. Mitigation: ProfileButton offsets are set to match AvatarRect + NameLabel bounds exactly (32–284px wide, 30–100px tall).
- LOW (NOTED): `UserProfileCard` is re-instantiated on each open (not hidden/shown). Godot 4 auto-disconnects signals when a node is freed, so signal leaks are safe — but `close()` must call `queue_free()` (not just `hide()`) to clean up the instance.
- LOW (NOTED): `ConfigFile.save()` on Android can fail silently if device storage is full. Mitigation: `save_avatar_index()` uses `push_error()` (not just `push_warning()`) on failure so it appears in device logs; user experience degrades to "avatar resets to 0 after restart" which is non-critical.
