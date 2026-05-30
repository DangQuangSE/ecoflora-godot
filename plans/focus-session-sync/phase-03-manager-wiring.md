# Phase 3: Manager Wiring

## Layer
Autoloads — `autoloads/FocusManager.gd` (existing singleton, extends Node)

## Files

| File | Status | Layer | Purpose |
|------|--------|-------|---------|
| `autoloads/FocusManager.gd` | Modify | autoloads | Add use_mock export, FocusService instantiation, HTTPRequest child, session_id tracking, and BE sync calls |

## Requirements
After this phase, FocusManager persists every non-cancelled session to the backend when
`use_mock = false`. The mock path (`use_mock = true`) must remain fully functional with zero
network traffic, matching the current behaviour exactly.

## Steps

1. Add `@export var use_mock: bool = true` (confirm / add if absent). Add these private fields:
   ```
   var _be_session_id: String = ""          # GUID from POST response
   var _create_in_flight: bool = false      # guards the POST only
   var _terminal_in_flight: bool = false    # guards complete/fail calls
   var _pending_terminal_state: String = "" # "complete" | "fail" | "" — set when terminal fires while POST still in-flight
   var _pending_terminal_strikes: int = 0
   var _pending_fail: bool = false          # set by _notification when it cannot await
   var _pending_fail_strikes: int = 0
   ```
   Preload `FocusService` with a `const _FocusServiceScript = preload(...)`. In `_ready` (only when
   `not use_mock`): create `_http: HTTPRequest`, add as child, instantiate `_focus_service` passing
   `_http`. Never touch `_focus_service` or `_http` inside `if use_mock` blocks.

2. In `_ready`, add a dev-mode guard (keep outside `if not use_mock` since it fires regardless):
   `if use_mock and UserManager.is_logged_in(): push_warning("FocusManager: use_mock=true but real token present")`

3. Modify `start_session`: after existing local state mutation, when `not use_mock`:
   ```
   _create_in_flight = true
   var token: String = UserManager.get_access_token()
   var minutes: int = max(1, duration_seconds / 60)  # clamp: avoids targetDuration=0 for short sessions
   var result: Dictionary = await _focus_service.create_async(UserManager.base_url, token, minutes)
   _create_in_flight = false
   if not result.is_empty():
       var new_id: String = result.get("id", "")
       if _state == ACTIVE:
           _be_session_id = new_id  # normal case
       elif not _pending_terminal_state.is_empty():
           # Race: session ended while POST was in-flight — fire the terminal call now
           _be_session_id = new_id
           _fire_terminal_async(_pending_terminal_state, _pending_terminal_strikes)
           _pending_terminal_state = ""
           _pending_terminal_strikes = 0
       # else: session was cancelled → discard the id
   ```

4. Modify the `is_completed()` check inside `_process` (fires synchronously every frame):
   After emitting `session_completed` and capturing `var strikes := _session.violation_count`,
   when `not use_mock`:
   - If `_create_in_flight`: set `_pending_terminal_state = "complete"`, `_pending_terminal_strikes = strikes`
   - Elif `not _be_session_id.is_empty()`: call `_fire_terminal_async("complete", strikes)` (non-awaited call)
   **Do not `await` directly in `_process`** — use the helper below instead.

5. Handle `_notification` (app paused — session fails): this callback is synchronous; `await` is
   unsafe here. After emitting `session_failed` and capturing `var strikes := _session.violation_count`,
   when `not use_mock`:
   - If `_create_in_flight`: set `_pending_terminal_state = "fail"`, `_pending_terminal_strikes = strikes`
   - Elif `not _be_session_id.is_empty()`: set `_pending_fail = true`, `_pending_fail_strikes = strikes`
   Then in `_process`, on every frame, add: `if _pending_fail and not _terminal_in_flight: _pending_fail = false; _fire_terminal_async("fail", _pending_fail_strikes)`

6. Add helper `_fire_terminal_async(state: String, strikes: int) -> void`:
   ```
   func _fire_terminal_async(state: String, strikes: int) -> void:
       if _terminal_in_flight or _focus_service == null:
           return
       _terminal_in_flight = true
       var id := _be_session_id
       _be_session_id = ""
       var token: String = UserManager.get_access_token()
       if state == "complete":
           await _focus_service.complete_async(UserManager.base_url, token, id, strikes)
       else:
           await _focus_service.fail_async(UserManager.base_url, token, id, strikes)
       _terminal_in_flight = false
   ```
   The `_focus_service == null` guard prevents crashes when `use_mock = true` and the service was
   never instantiated.

7. In `cancel_session`: add `_be_session_id = ""`; `_pending_terminal_state = ""`; `_pending_fail = false`.
   No BE call — cancelled sessions are not persisted.

8. In `_exit_tree`: cancel `_http` request if `_create_in_flight or _terminal_in_flight`.

## Success Criteria
- `godot --headless --check-only --script res://autoloads/FocusManager.gd` exits with no errors
- With `use_mock = true`: starting, completing, failing, and cancelling a session produces
  zero HTTPRequest calls (verified by confirming `_http` node is never created)
- With `use_mock = false` and a live backend: after `start_session`, `_be_session_id` is
  non-empty; after `session_completed` fires, a subsequent `GET /api/focus-sessions/{id}` (or
  Swagger query) shows `status: "COMPLETED"`
- Cancelling a session at any point leaves `_be_session_id` as `""` and makes no network call
- GardenManager still receives `session_completed(minutes_focused)` and `session_failed()`
  signals exactly as before (existing connections in `_ready` are unchanged)

## Risks
- `start_session` is now async — callers that do not `await` it will not observe `_be_session_id`
  being set; local state is mutated before the await so the session timer starts immediately
- `_create_in_flight` and `_terminal_in_flight` are separate flags to avoid mutual suppression;
  the race where both could be true simultaneously is handled by `_pending_terminal_state`
- `_notification` is a synchronous engine callback — `await` inside it is unsafe; the
  `_pending_fail` flag + `_process` dequeue pattern is the only safe async exit from `_notification`
- `_fire_terminal_async` captures `_be_session_id` into a local before clearing it to prevent
  concurrent calls from firing against the same id; `_terminal_in_flight` guards re-entry
