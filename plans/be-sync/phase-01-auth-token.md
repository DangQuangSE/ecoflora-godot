# Phase 1: Auth + Token

## Layer
`services/` (AuthService, TokenStore) + `autoloads/UserManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/AuthService.gd` | services | New |
| `services/TokenStore.gd` | services | New |
| `autoloads/UserManager.gd` | autoloads | Modify |

## Requirements
Provide a login flow that calls `POST /api/auth/login`, stores the returned tokens (accessToken
in-memory, refreshToken encrypted on disk), and exposes the accessToken for subsequent requests.
When any manager receives a 401 response it must emit a signal that triggers the login screen —
no silent refresh.

## Steps
1. Create `TokenStore` (RefCounted, services layer) that writes the refreshToken to `user://tokens.dat`
   using `FileAccess.open_encrypted_with_pass()` where the key is `OS.get_unique_id()` (Godot's
   device fingerprint — deterministic per device, never hardcoded). Reads it back on startup.
   Keep accessToken as an in-memory-only property with no disk write path.
   > **Student-project note:** `OS.get_unique_id()` provides per-device obfuscation, not cryptographic
   > security. This is acceptable for a game client refresh token; document the limitation in a comment.

2. Create `AuthService` (RefCounted, services layer) that owns the login request body shape
   `{ account, password }` matching `LoginRequest`, and a `parse_login_response(json: Dictionary)`
   method that extracts `accessToken` and `refreshToken` from the BE envelope's `data` field.
   Mirror the same parse pattern as `WeatherService.parse_response()`.

3. Add `@export var use_mock: bool = true` and `@export var base_url: String = "http://localhost:5226"`
   to `UserManager`. Add signals: `login_required`, `login_succeeded`. Wire `_ready()` to
   initialize `AuthService` and `TokenStore`, and attempt to restore a saved refreshToken from disk.
   Add a boot-time guard: if `use_mock = false` and `base_url` does not start with `"https://"`,
   call `push_warning("UserManager: base_url is HTTP — tokens transmitted in plaintext")`.
   Emit `login_succeeded` after a successful login so downstream managers can start their fetches.

4. Implement `login_async(account: String, password: String) -> bool` in `UserManager` using
   its own `HTTPRequest` child node (same pattern as `WeatherManager._http`). Set
   `_request_in_flight` guard before the call, clear it after. On success store both tokens via
   `TokenStore`. On failure push_error and return false.

5. Implement `get_auth_header() -> String` on `UserManager` that returns the
   `"Authorization: Bearer <accessToken>"` string; return empty string when not logged in so callers
   can detect the unauthenticated state without crashing.

6. Implement a `handle_401()` method on `UserManager` that clears the in-memory accessToken and
   emits `login_required`. All other managers call this method whenever they receive an HTTP 401,
   then abort their current request without retrying.

7. Verify the mock path still works end-to-end: when `use_mock = true`, `login_async()` must return
   true immediately without touching HTTPRequest, and `get_auth_header()` must return a non-empty
   stub string so downstream mock services can run unchanged.

## Success Criteria
- `login_async("testuser", "password")` with `use_mock = false` and a running BE returns `true`
  and `TokenStore` holds a non-empty accessToken in memory
- `user://tokens.dat` exists on disk after a successful login and is not plain-text JSON
  (verify by opening in a hex editor — must not start with `{`)
- Calling `handle_401()` emits `login_required` exactly once and clears the in-memory accessToken
- Game boots and reaches the garden scene without crash when `use_mock = true` (no regression)
- `godot --headless --check-only --script res://autoloads/UserManager.gd` reports zero errors

## Spec Coverage
- FR-01: Login via POST /api/auth/login, store accessToken + refreshToken
- FR-02: Re-login on 401 (handle_401 + login_required signal)
