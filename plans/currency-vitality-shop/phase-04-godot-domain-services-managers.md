# Phase 4: Godot Domain, Services & UserManager

**Codebase:** Godot project (`d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\`)

## Requirements
Update the client-side domain and service layer to reflect all new server fields, and extend UserManager to be the single source of truth for currency, XP, and vitality state — all wired through signals so no scene ever reads state directly.

## Steps
1. Update `domain/UserProfile.gd`: add `vitality_ready_at: int = 0` (unix timestamp, 0 = never claimed / immediately claimable). **Audit the existing level threshold constants** in `UserProfile.gd` (the table used by `add_xp()`) — they must exactly match the BE constants defined in Phase 1 Step 3: L2=500, L3=1500, L4=3000, L5=5000, L6=8000, L7=12000. Update them if they differ. Remove local level-up logic from `add_xp()` — in BE mode this is now dead code, but keep the method callable for mock mode compatibility. Add a `is_vitality_ready() -> bool` helper that returns `vitality_ready_at == 0 or vitality_ready_at <= Time.get_unix_time_from_system()`.
2. Create `domain/ShopItem.gd` as a `RefCounted` class with fields: `id: String`, `name: String`, `description: String`, `price: int`, `category: String`, `image_url: String`, `is_active: bool`. No methods — pure data carrier.
3. Update `services/UserService.gd`: in `parse_profile(data)`, add parsing of `vitalityReadyAt` ISO string → unix timestamp (use the same `_parse_iso_to_unix` pattern from `GardenService.gd`). Store result in `p.vitality_ready_at`.
4. Create `services/VitalityService.gd` as a `RefCounted` with `@export var base_url: String` and methods `get_status_async(http: HTTPRequest, token: String) -> Dictionary` and `claim_async(http: HTTPRequest, token: String) -> Dictionary`. **`RefCounted` cannot call `add_child()` — do NOT create `HTTPRequest.new()` inside this class.** Instead, `UserManager._ready()` creates the `HTTPRequest` nodes (`_vitality_http`, `_vitality_claim_http`) via `add_child()` and passes them as parameters to these methods. Follow the pattern in `UserManager._ready()` where `_http` and `_http_profile` are created and added as children — add two more for vitality.
5. Create `services/ShopService.gd` as a `RefCounted` with `get_catalog_async(http: HTTPRequest, token: String, category: String = "") -> Array[ShopItem]` and `purchase_async(http: HTTPRequest, token: String, prefixed_id: String, quantity: int) -> Dictionary`. Same `HTTPRequest`-as-parameter pattern as VitalityService — `UserManager._ready()` creates `_shop_http` and `_shop_purchase_http` nodes. In `purchase_async`, strip the `"item:"` or `"seed:"` prefix from `prefixed_id` and set the appropriate field in the request body (`itemId` or `flowerTemplateId`).
6. Extend `autoloads/UserManager.gd` with new signals at the top: `signal currency_changed(new_amount: int)`, `signal vitality_ready()`, `signal vitality_claimed(reward_type: String, reward_amount: int)`. Update `update_currency()` to emit `currency_changed(new_total)` after setting `_profile.currency` — **replace the existing `xp_gained.emit(0)` call in `update_currency()` with `currency_changed.emit(_profile.currency)`.** Do NOT emit `xp_gained` from `update_currency` anymore. Add `apply_server_xp(new_xp: int, new_level: int) -> void` that directly sets `_profile.current_xp = new_xp` and `_profile.level = new_level` then emits `xp_gained(0)` and `level_up(new_level)` only if level changed. **Update `GardenManager.gd`'s `_on_harvest_completed` (BE mode branch) to call `UserManager.apply_server_xp(data.get("newUserXP"), data.get("newUserLevel"))` instead of `UserManager.add_harvest_xp(int(data.get("xpEarned")))`** — both fields come from the updated `HarvestRewardDto` (Phase 1 Step 4).
7. Add vitality polling to UserManager: in `_ready()`, create a `Timer` child node (`_vitality_poll_timer`), set `wait_time = 60.0`, `autostart = true`, `one_shot = false`, connect its `timeout` signal to `_poll_vitality_status`. `_poll_vitality_status()` is `async`, calls `VitalityService.get_status_async(_vitality_http, token)`, updates `_profile.vitality_ready_at`, and emits `vitality_ready()` if `_profile.is_vitality_ready()`. Also expose `request_vitality_status_async() -> void` as a public method (wraps `_poll_vitality_status`) so VitalityBar can trigger an immediate fetch on `_ready()`. Add `claim_vitality_async() -> void` with a `_claim_in_flight: bool` guard: set guard → call `VitalityService.claim_async(_vitality_claim_http, token)` → on success call `apply_server_xp` + `update_currency` + emit `vitality_claimed(type, amount)` → clear guard in both success and failure paths. **Mobile background handling:** override `_notification(what)` in UserManager. On `NOTIFICATION_APPLICATION_FOCUS_OUT`: call `_vitality_poll_timer.stop()`. On `NOTIFICATION_APPLICATION_FOCUS_IN`: call `_vitality_poll_timer.start()` then `_poll_vitality_status()` immediately (the timer fires on next cycle but the state is stale until then).

## Success Criteria
- `UserProfile.is_vitality_ready()` returns `true` when `vitality_ready_at == 0` and `false` when set to a time 6h in the future.
- After login in BE mode: `UserManager.get_profile().vitality_ready_at` is non-zero if the server returned a `vitalityReadyAt` field.
- Harvesting a flower in BE mode: `UserManager.get_profile().current_xp` matches `newUserXP` from the server response (not the locally computed value).
- **`currency_changed` signal fires — not `xp_gained`:** connect a test listener to `UserManager.currency_changed` in a test scene, call `UserManager.update_currency(99)`, and confirm the listener fires with `new_amount = 99`. Confirm `xp_gained` does NOT fire from `update_currency` anymore.
- `vitality_ready` signal fires once when the poll detects the cooldown has elapsed.
- Calling `claim_vitality_async()` twice rapidly: the second call is dropped (the `_claim_in_flight` guard returns early, confirmed by `push_warning` in log).
- `ShopService.get_catalog_async()` returns an array of `ShopItem` objects with correct `price` and `category` fields parsed from the server response.

## Risks
- `apply_server_xp` must only be called in BE mode — in mock mode `add_harvest_xp` still handles XP. Add a guard: `if use_mock: return` at the top of `apply_server_xp`.
- `VitalityService` and `ShopService` each create their own `HTTPRequest` node — these must be added as children of the node that owns the service instance (UserManager owns VitalityService's requests). Follow the pattern in `UserManager._ready()` where `_http` and `_http_profile` are added with `add_child`.
- Vitality poll timer in background: connect `get_tree().node_added` or use `NOTIFICATION_APPLICATION_FOCUS_OUT` to pause `_vitality_poll_timer` when the app is minimized to avoid wasting mobile battery.

## Files

| File | Layer | Action |
|---|---|---|
| `domain/UserProfile.gd` | domain | Modify — add `vitality_ready_at`, `is_vitality_ready()`, keep `add_xp()` for mock mode |
| `domain/ShopItem.gd` | domain | Create — RefCounted data carrier |
| `services/UserService.gd` | services | Modify — parse `vitalityReadyAt` from profile response |
| `services/VitalityService.gd` | services | Create — `get_status_async()`, `claim_async()` |
| `services/ShopService.gd` | services | Create — `get_catalog_async()`, `purchase_async()` |
| `autoloads/UserManager.gd` | autoloads | Modify — new signals, `apply_server_xp`, `update_currency` emits signal, vitality poll Timer, `claim_vitality_async` |
