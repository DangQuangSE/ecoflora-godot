# Phase 3: Godot Autoload — UserManager

## Layer
autoloads/ and services/ — UserManager.gd (autoload singleton) + UserService.gd (service layer parser)

## Files

| File Path | Layer | Change Type |
|-----------|-------|-------------|
| `autoloads/UserManager.gd` | autoloads | modify |
| `services/UserService.gd` | services | modify |

## Tasks

1. **Add `profile_updated` signal to `UserManager.gd`** — declare at the top of the class alongside the existing signals (`xp_gained`, `level_up`, etc.). This signal carries no arguments; it fires whenever avatar or any profile field changes locally.

2. **Add `_avatar_http: HTTPRequest` node** to `UserManager.gd` for the avatar-index PUT call. Initialize it in `_ready()` the same way as `_http_profile`, with `timeout = 10.0`. Add `_avatar_in_flight: bool = false` guard variable. Clean up in `_exit_tree()`.

3. **Add `save_avatar_index(idx: int) -> void`** — writes `idx` to `user://avatar_prefs.cfg` using `ConfigFile`. Section `"avatar"`, key `"index"`. Call `config.save(path)` and handle errors with `push_warning`.

4. **Add `load_avatar_index() -> int`** — reads `user://avatar_prefs.cfg`. If the file does not exist or the key is missing, returns `0`. Never errors out — always returns a valid int fallback.

5. **Call `load_avatar_index()` in `_ready()`** after all HTTPRequest nodes are set up. Apply the loaded index to `_profile.avatar_index` so it is available before `fetch_profile_async()` completes. This ensures the HUD shows the previously chosen avatar immediately on startup.

6. **Update `UserService.gd` `parse_profile()` method** to also read the three new fields from the BE JSON response:
   - `p.login_streak = int(data.get("loginStreak", 0))`
   - `p.join_date = str(data.get("createdAt", ""))` (ISO string, stored as-is for display formatting in the UI layer)
   - **Tie-breaking rule for avatar_index**: Local ConfigFile (`load_avatar_index()`) wins. Only apply BE's `avatarIndex` if `load_avatar_index()` returns 0 (meaning no local preference saved). This prevents a race where the BE response arrives after startup and overwrites a locally-chosen avatar before the fire-and-forget PUT has synced:
     ```gdscript
     var be_idx := int(data.get("avatarIndex", 0))
     var local_idx := load_avatar_index()
     p.avatar_index = local_idx if local_idx > 0 else be_idx
     ```

7. **After parsing in `fetch_profile_async()`**, emit `profile_updated` signal alongside the existing `xp_gained` and `currency_changed` emissions. This lets UserHUD and UserProfileCard react to new avatar/streak data without polling.

8. **Add `set_avatar_async(idx: int) -> void`** using the optimistic UI pattern:
   - Guard: if `_avatar_in_flight` is true, return early.
   - Clamp `idx` to range 0–5 with `clampi`.
   - **Capture rollback value FIRST**: `var prev_idx := _profile.avatar_index`
   - Set `_profile.avatar_index = idx` immediately (local predict).
   - Call `save_avatar_index(idx)` to persist locally.
   - Emit `profile_updated` so the HUD and card update instantly.
   - Set `_avatar_in_flight = true`, then fire `PUT /api/auth/avatar-index` with body `{"avatarIndex": idx}` via `_avatar_http`.
   - Await the response; on success (HTTP 200) set `_avatar_in_flight = false`.
   - On failure: `_profile.avatar_index = prev_idx`, call `save_avatar_index(prev_idx)`, emit `profile_updated`, set `_avatar_in_flight = false`, call `push_warning("set_avatar_async: BE sync failed, reverted to %d" % prev_idx)`.
   - In mock mode (`use_mock == true`): skip the HTTP call entirely — only do the local update, save, and emit.

## Acceptance
- After `UserManager.set_avatar_async(3)`, `UserManager.get_profile().avatar_index` returns `3` before any await.
- Restarting the game (or calling `load_avatar_index()` directly) returns the last saved index.
- `profile_updated` signal fires once after `set_avatar_async(2)` in mock mode.
- `fetch_profile_async()` in non-mock mode populates `login_streak`, `avatar_index`, and `join_date` from the BE JSON.
- `godot --headless --check-only --script res://autoloads/UserManager.gd` exits with no errors.
