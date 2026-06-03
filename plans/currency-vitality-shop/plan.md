# Plan: Currency HUD, Vitality Bar & Shop System
Status: Complete
Date: 2026-06-03
Mode: Hard

## Overview
Delivers four linked player-progression features across eco-backend (.NET 8) and the Godot 4 client: persistent XP/level on the server, a live currency coin label in the HUD, a 6-hour vitality claim loop with random rewards, and a purchasable item shop — all wired through server-authoritative data with no client-trusted state.

## Phases
- [x] Phase 1: BE Foundation — Add CurrentXP + VitalityReadyAt to User, create ShopItem entity, run migration, fix XP mapper bug, update Harvest and Care to persist XP and return newUserXP/newUserLevel
- [x] Phase 2: BE Vitality Endpoints — VitalityService + GET /api/vitality/status + POST /api/vitality/claim with 6h cooldown, random reward pool, and atomic DB write
- [x] Phase 3: BE Shop Endpoints — ShopService wrapping existing InventoryService.BuyItemAsync flow into a new ShopItem-catalog-aware endpoint, admin CRUD, and DI registration
- [x] Phase 4: Godot Domain + Services + UserManager — Update UserProfile.gd domain class, create ShopItem.gd, wire VitalityService.gd + ShopService.gd, extend UserManager with apply_server_xp, currency_changed signal, and vitality poll/claim logic
- [x] Phase 5: Godot Scenes — Add currency label to UserHUD, build VitalityBar sub-scene, build ShopScene with TabContainer and purchase confirmation dialog

## Research Summary
Architecture decisions locked before planning:
- `VitalityReadyAt` (UTC DateTime?) stored on User entity (not a separate table). Server computes remaining seconds; client never trusts its own clock for cooldown.
- Vitality logic folded into UserManager (no 9th autoload). Polling Timer added as a child node inside UserManager._ready().
- `apply_server_xp(new_xp, new_level)` replaces local add_xp() in BE mode to prevent XP drift between client and server.
- Harvest currently increments `user.Currency += template.BasePrice` (GardenService.cs line ~232) — this must be deleted; harvest earns only XP going forward.
- Shop reuses the existing `InventoryService.BuyItemAsync` transaction pattern (currency check → deduct → upsert inventory item in one EF Core transaction). No new ShopItem entity is required for the catalog; items already exist as `Item` and `FlowerTemplate` entities. The existing `ShopController` + `BuyItemRequest` already handle the purchase path — Phase 3 scope is reduced to vitality reward grant and ensuring UserXP is returned in BuyItemAsync receipt.
- `_claim_in_flight: bool` guard in UserManager prevents double-tap race on vitality claim.

## Dependencies
- eco-backend PostgreSQL database accessible for EF Core migration run
- Godot 4.x project must have `UserManager` autoload registered before any scene loads (already true per project.godot)
- No new autoload registration needed (UserManager extended, not replaced)

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-03 15:30
**Phase in progress:** complete
**Status:** All 5 phases done — BE migrated + built, Godot scripts written. Needs editor wiring (see docs/).

### Decisions made this session
- `TryCommitAsync()` added to IUnitOfWork — Infrastructure catches DbUpdateConcurrencyException, returns bool to Application (no EF Core in Application layer)
- Harvest still returns `newCurrencyTotal` (unchanged balance) for HUD sync; currency is no longer incremented
- `UserProfile.LEVEL_THRESHOLDS` exposed via `static func get_level_start_xp()` to work around cross-file const access
- `UpsertInventoryItemAsync` internal CommitAsync removed — all callers now own their own transaction boundary
- BE hook CWD issue: use PowerShell for all dotnet commands; reset CWD to Godot root before Read/Edit/Write calls
- `settings.json` hooks use relative paths — flagged for user to fix to absolute paths

### Next immediate action
User runs Godot editor to wire nodes per docs/currency-vitality-shop/godot_implement.md

## Risks
- HIGH: EF Core migration on live DB may lock the Users table briefly — run during off-peak; test on a dev DB first. Two migrations required (Phase 1: User XP+Vitality, Phase 3: Item/FlowerTemplate IsActive).
- HIGH: Harvest currently grants currency via `user.Currency += template.BasePrice`; removing this is a breaking change — confirm with team before shipping Phase 1.
- HIGH: `UpsertInventoryItemAsync` has an internal `CommitAsync` — Phase 3 PREREQUISITE refactor removes it. Both vitality claim (Phase 2) and shop purchase (Phase 3) depend on this refactor being complete.
- HIGH: `VitalityReadyAt` marked `[ConcurrencyCheck]` — concurrent claim attempts from multi-device will throw `DbUpdateConcurrencyException`. VitalityService.ClaimAsync must catch and return HTTP 409.
- MEDIUM: `VitalityReadyAt` stored as UTC DateTime? — verify server uses UTC (`DateTime.UtcNow`) consistently.
- MEDIUM: `currency_changed` signal replaces `xp_gained` as the HUD refresh trigger for currency. Ensure `UserHUD._refresh()` connects to `currency_changed` not `xp_gained` for the coin label.
- MEDIUM: Mobile background polling — `UserManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT/IN)` pauses/resumes vitality timer (Phase 4 Step 7).
- LOW: ShopScene deco tab shows "Coming Soon" — not purchasable until garden placement system is built.
