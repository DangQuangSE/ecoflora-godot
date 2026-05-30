# Phase 2: Godot Service

## Layer
Services — `services/FocusService.gd` (GDScript, RefCounted, no Node)

## Files

| File | Status | Layer | Purpose |
|------|--------|-------|---------|
| `autoloads/UserManager.gd` | Modify | autoloads | Add `get_access_token() -> String` public getter |
| `services/FocusService.gd` | New | services | Async HTTP wrapper for the three focus-session endpoints |

## Requirements
Provide a pure-GDScript service class that the FocusManager autoload can instantiate. It must
expose `create_async`, `complete_async`, and `fail_async`, return typed Dictionaries on success
and `null` on failure, and never be called directly from any scene.

## Steps

1. Add `get_access_token() -> String` to `UserManager.gd`:
   ```gdscript
   func get_access_token() -> String:
       if use_mock:
           return "mock_token"
       return _token_store.access_token if _token_store else ""
   ```
   This is the canonical way for services to obtain the raw JWT — avoids coupling FocusService
   to UserManager's internal `_token_store` naming.

2. Declare `class_name FocusService` extending `RefCounted`. Add a constructor (`_init`) that
   accepts an `HTTPRequest` node reference and stores it — the caller (FocusManager) owns and
   passes the node so the service layer stays Node-free.

3. Implement `create_async(base_url: String, access_token: String, target_duration_minutes: int) -> Dictionary`.
   Build headers with `HttpHelper.make_headers(access_token)`. Build body with
   `HttpHelper.encode_body({"targetDuration": target_duration_minutes})`. Fire
   `POST {base_url}/api/focus-sessions`, await `request_completed`, unwrap with
   `HttpHelper.unwrap_envelope`. Return the inner data Dictionary on success, empty Dictionary
   on any error. `push_warning` with method name and status code on non-200.

4. Implement `complete_async(base_url: String, access_token: String, session_id: String, strikes: int) -> bool`.
   Build headers with `HttpHelper.make_headers(access_token)`. Send
   `PATCH {base_url}/api/focus-sessions/{session_id}/complete` with body `{ "strikes": strikes }`.
   On 401: `push_warning` only — do not call `UserManager.handle_401()` (session already
   completed locally; interrupting login mid-session destroys UX). Return `true` on 200 + isSuccess.

5. Implement `fail_async(base_url: String, access_token: String, session_id: String, strikes: int) -> bool`.
   Identical to `complete_async` but targets the `/fail` route. Same 401 policy.

6. For all methods: check `HTTPRequest.RESULT_SUCCESS` before parsing JSON; use `push_warning`
   only, never `push_error` — per project style rules.

## Success Criteria
- `godot --headless --check-only --script res://services/FocusService.gd` exits with no errors
- The file does not contain any `extends Node`, `get_tree()`, `$` child access, `print()`, or
  `yield` calls
- Class has exactly three public async methods (`create_async`, `complete_async`, `fail_async`)
  and no signals (signals belong in autoloads only)
- With `use_mock = false` and a live backend, calling `create_async` and awaiting it returns a
  Dictionary containing an `"id"` key

## Risks
- The HTTPRequest node is owned by FocusManager and passed in — if FocusManager frees the node
  before the await resolves, the signal will not fire; mitigation: FocusManager must not free
  the HTTPRequest node until `_exit_tree`
- All three methods take `access_token: String` (raw JWT); call site passes
  `UserManager.get_access_token()` — the public getter added in step 1
- 401 from complete/fail: push_warning only, not handle_401 — session is already finalized
  locally; interrupting with re-login mid-session would destroy UX and lose in-memory XP
