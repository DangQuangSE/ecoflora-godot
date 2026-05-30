# Plan: BE Sync — Connect Godot Client to .NET 8 Backend
Status: Draft
Date: 2026-05-28
Mode: Hard

## Overview
Replace all mock service calls in the Godot game client with real HTTP calls to the .NET 8 REST backend,
implementing JWT auth, token persistence, mapping layers, and offline fallback — without breaking the
existing mock path on any manager.

## Phases
- [x] Phase 0: Login Scene UI — Professional mobile login/splash screen (scenes layer, no HTTP yet)
- [x] Phase 1: Auth + Token — Login flow, JWT storage (refreshToken encrypted on disk, accessToken in-memory), re-login on 401
- [x] Phase 2: HTTP Helper — Shared RefCounted helper for header injection and JSON envelope unwrapping
- [x] Phase 3: Reference Data — Boot-time fetch of FlowerTemplate, Item, and Synergy catalogs from BE
- [x] Phase 4: User Profile — Fetch Level + Currency from GET /api/auth/profile and surface to UserManager
- [x] Phase 5: Garden Sync — Fetch plots + planted flowers, plant/care/harvest via BE (UNBLOCKED — BE endpoints live)
- [x] Phase 6: Inventory Sync — Fetch inventory items from BE (UNBLOCKED — BE endpoint live)
- [ ] Phase 7: Focus Session Sync — [BLOCKED] No FocusSession controller in BE yet

## Research Summary
Architecture decision: **Decentralized pattern** — each autoload owns its own HTTPRequest child node,
matching the established WeatherManager pattern. A shared `services/HttpHelper.gd` (RefCounted, static
methods) handles Authorization header injection and the `{ isSuccess, message, data, metaData }` envelope
unwrapping common to all BE responses. (Note: no root-level `code` field in success responses.) No centralized ApiClient autoload is introduced to keep the load order
dependency graph flat and avoid a single point of failure.

Token strategy: `accessToken` is in-memory only (never written to disk). `refreshToken` is stored
encrypted via AES in `user://tokens.dat`. On 401, the client re-runs the login flow (shows login UI
again) rather than silently refreshing — simpler and safer for a student team operating without a
secure key store.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-05-29 18:20
**Phase in progress:** phase-06-inventory-sync
**Status:** Complete — InventoryService created, InventoryManager wired to fetch inventory after login

### Decisions made this session
- Used `GET /api/inventory` (not `/api/inventory/me`) — actual BE route from InventoryController
- Category derived strictly from non-null FK: `flowerTemplateId`→SEED, `itemId`→CONSUMABLE, `decorId`→DECOR
- `_str_or_empty()` helper handles JSON null values (`null` Variant → `""`, `"null"` string → `""`)
- After real fetch, harvest products from current session are re-appended to fetched inventory to avoid data loss
- `add_harvest_product()` marked `# BE-local only` per spec Out of Scope

### Next immediate action
Phase 7: Focus Session Sync — check if BLOCKED status has changed

## Dependencies
- BE must implement garden/plot/planted-flower endpoints before Phase 5 can start (currently blocked)
- BE must implement /api/inventory endpoint before Phase 6 can start (currently blocked)
- BE FocusSession endpoint needs verification before Phase 7 (assumed POST /api/focus-sessions)
- BE running at http://localhost:5226 (dev); URL configured via @export on UserManager or a shared config autoload

## Risks
- HIGH: Garden and Inventory endpoints do not exist in BE — Phase 5 and 6 are fully blocked until BE team delivers; mitigation: implement Phase 5/6 as mock-only stubs that are ready to wire once endpoints ship
- HIGH: accessToken expiry mid-session causes all requests to silently fail — mitigation: treat every 401 as a trigger for re-login UI, never swallow 401 silently
- MEDIUM: BE response envelope is `{ isSuccess, message, data, metaData }` — no root `code` field; HttpHelper must check `isSuccess` not a status code
- MEDIUM: All catalog endpoints paginated (default PageSize=10) — always pass `?pageSize=1000&isDeleted=false` to avoid silent truncation
- NOTED: IsBanned=true returns 400 from login (not 401) — login_async must handle non-401 failures and emit login_error(reason) for UI display
- NOTED: FocusSession TargetDuration is in minutes on BE, elapsed_seconds is in seconds on Godot — confirm unit + semantics with BE team before Phase 7
- MEDIUM: FlowerTemplateDto from BE does not include stage/XP data — mitigation: keep StageDefinition hardcoded in GardenManager until BE adds stage endpoint; log a warning during boot
- LOW: HTTPRequest node count grows with each autoload — mitigation: one node per autoload is fine for mobile; cancel requests on _exit_tree() as WeatherManager already does
- LOW: refreshToken stored in user:// could be read on rooted Android devices — mitigation: encrypt with a device-derived key using AES via GDScript Crypto class
