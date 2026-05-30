# Phase 7: Focus Session Sync

> ⛔ **BLOCKED** — No FocusSession controller exists in BE (`API/Controllers/` has no FocusSessionsController).
> Additionally, BE entity uses `TargetDuration` (int, **minutes**) while Godot stores `elapsed_seconds` (float) —
> unit and semantic mismatch must be resolved with BE team before implementation.
> Do not implement until BE ships and documents the endpoint with confirmed field names + units.

## Layer
`services/` (FocusSessionService) + `autoloads/FocusManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/FocusSessionService.gd` | services | New |
| `autoloads/FocusManager.gd` | autoloads | Modify |

## Requirements
When a focus session ends (completed or failed), push the result to the BE so session history
is persisted. The push is fire-and-forget — the game must not block or roll back local state
on BE failure. The mock path must remain fully functional.

## Steps
1. Verify the BE FocusSession endpoint shape before writing any service code. Check the
   `feat/imple-godot` branch for a POST endpoint (expected: `POST /api/focus-sessions`) and
   confirm the accepted body fields. If not yet present, document the assumed shape
   `{ duration_seconds: int, strikes: int, status: "completed"|"failed" }` in a comment at
   the top of `FocusSessionService` and proceed with that assumption.

2. Create `FocusSessionService` (RefCounted, services layer). Add
   `build_payload(session: FocusSession, status: String) -> Dictionary` that constructs the
   request body from `FocusSession` domain fields (`duration_seconds`, `violation_count`) plus
   the passed status string. Keep this as the only place that knows the BE field names.

3. Add `@export var use_mock: bool = true` to `FocusManager`. Add a new
   `HTTPRequest` child node in `FocusManager._ready()` for the push call, separate from any
   timer concerns. Guard with its own `_push_in_flight: bool` so a push from a previous session
   does not block a new session start.

4. Connect `session_completed` and `session_failed` signals in `FocusManager` to a new internal
   `_push_session_async(status: String)` method. This method fires the POST request when
   `use_mock = false` and `UserManager.get_auth_header()` is non-empty. On 401, call
   `UserManager.handle_401()`. On any other non-200 or network error, push_warning only —
   do not alter local session state or re-emit any signal.

5. Ensure the local garden XP reward (via `GardenManager._on_focus_session_completed`) and the
   BE push are independent: the XP is applied immediately when the signal fires; the HTTP push
   runs concurrently and its success or failure never gates the XP reward.

6. When `use_mock = true`, `_push_session_async()` must return immediately without touching
   HTTPRequest. Verify by checking that toggling the Inspector export has no visible effect on
   session behavior in the FocusScene.

## Success Criteria
- After a completed session with `use_mock = false` and BE running, the BE returns HTTP 200
  or 201 for the POST and a push_warning does NOT appear (success path is silent)
- After a failed session (3 violations), the same push fires with `status = "failed"` and
  `strikes = 3`
- Garden XP is applied in the same frame as session_completed regardless of BE push status
- Cancelling a session does NOT trigger a push to BE
- With BE offline and `use_mock = false`, session completes normally (XP applied), a
  push_warning appears, and no crash occurs
- With `use_mock = true`, no HTTP request fires — session behavior is identical to pre-Phase-7

## Spec Coverage
- FR-07: Push FocusSession result to BE when session ends
- FR-08: Mapping layer in services/ — FocusSessionService owns build_payload, no body construction in FocusManager
- [P2] Focus session result is saved to the server when the player finishes
