# Phase 4: User Profile

## Layer
`services/` (UserService) + `autoloads/UserManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/UserService.gd` | services | New |
| `autoloads/UserManager.gd` | autoloads | Modify |

## Requirements
Fetch the authenticated user's Level and Currency from `GET /api/auth/profile` after login and
populate the `UserProfile` domain object so the HUD displays real server data when
`use_mock = false`.

## Steps
1. Create `UserService` (RefCounted, services layer). Add `parse_profile(json: Dictionary) -> UserProfile`
   that reads the BE `UserDto` fields (`id`, `username`, `level`, `currency`) from the unwrapped
   envelope and maps them to `UserProfile`. The BE has no XP field — keep `current_xp = 0` and
   `total_xp_earned = 0` as Godot-local values; do not attempt to map them. Push_warning to
   document the XP gap.

2. In `UserManager._ready()`, after a successful `login_async()` returns true, immediately call a
   new `fetch_profile_async()` method. This method uses a **separate** `_http_profile: HTTPRequest`
   child node (added in this phase, NOT shared with the login `_http` node from Phase 1) so that
   profile fetch and re-login can run independently without the `_request_in_flight` guard blocking
   one another.

3. In `fetch_profile_async()`, guard with its own `_profile_in_flight: bool` before firing the GET request and
   clear it in the completion handler (success or failure path). On 401, call `handle_401()`. On
   any other non-200 or network error, push_warning and leave `_profile` unchanged so the HUD
   shows the previous (or default) values rather than crashing.

4. After `_profile` is updated with BE data, emit both `xp_gained` (amount 0) and `level_up` (if
   the fetched level differs from the current `_profile.level` before the update) so any connected
   HUD scenes refresh automatically without requiring direct coupling.

5. Ensure the mock path is unchanged: when `use_mock = true`, `_ready()` must skip
   `fetch_profile_async()` entirely and `_profile` remains the default `UserProfile.new()` object
   as before Phase 4.

## Success Criteria
- After login with real credentials and `use_mock = false`, `UserManager.get_profile().level`
  returns the integer value from the BE `UserDto.Level` field (verify by print in _ready after
  fetch, then remove the print)
- After login with real credentials, `UserManager.get_profile().level` matches the value shown in
  the BE admin panel for that account
- `UserManager.get_profile().current_xp` equals 0 (Godot-local; BE has no XP field)
- With BE offline and `use_mock = false`, game reaches HUD without crash; HUD shows level 1
  (default `UserProfile`) and a push_warning appears in Output
- With `use_mock = true`, no HTTP request fires and `get_profile()` returns default values
  (Level 1, Currency 0) — existing unit behavior unchanged

## Spec Coverage
- FR-05: Fetch user profile (Level, Currency) from BE GET /api/auth/profile
- FR-08: Mapping layer in services/ — UserService owns parse_profile, no mapper logic in autoload
