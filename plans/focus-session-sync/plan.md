# Plan: Focus Session Sync
Status: Complete
Date: 2026-05-29
Mode: Hard

## Overview
Wire the Godot FocusManager to the .NET 8 eco-backend so that focus sessions are persisted:
created on start, marked COMPLETED or FAILED on end. Cancelled sessions produce no network traffic.

## Phases
- [x] Phase 1: BE Endpoints — build DTOs, IFocusSessionService, FocusSessionService, FocusSessionController on the .NET 8 side
- [x] Phase 2: Godot Service — create `services/FocusService.gd` with `create_async`, `complete_async`, `fail_async`
- [x] Phase 3: Manager Wiring — modify `FocusManager.gd` to call FocusService, store the BE session id, and keep the `use_mock` path intact

## Research Summary
BE entity `FocusSession` already exists with all required fields and the DbSet is registered in
AppDbContext. The project follows a strict layered pattern:
- DTOs live in `Application/DTOs/`
- Interfaces live in `Application/Interfaces/`
- Services live in `Application/Services/`
- Controllers live in `API/Controllers/`
- Repository access goes through `IUnitOfWork` (injected via constructor DI)
- `ApiResponse<T>` and `ApiError` are the standard response wrappers
- AutoMapper is used for entity-to-DTO mapping; the profile is in `Application/Mapper/MappingProfile.cs`
- DI registrations go in `API/Program.cs`

Godot services are `RefCounted`, own no Node, use `HttpHelper` static helpers, read the raw token via
`UserManager._token_store.access_token` (not the full header string), and follow the guard pattern.
Cancel requires no BE call — the in-memory session id is simply discarded.

Unit mapping: `max(1, duration_seconds / 60)` → BE `targetDuration` (clamp prevents 0 on short sessions);
Godot `violation_count` → BE `strikes`.

Concurrency design: two separate guards (`_create_in_flight`, `_terminal_in_flight`) avoid mutual
suppression. Race condition where session ends before POST returns is resolved via
`_pending_terminal_state`. The `_notification` callback cannot `await` — failure is dequeued via
`_pending_fail` flag processed in `_process`.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-05-29 19:30
**Phase in progress:** phase-03-manager-wiring
**Status:** Complete — all 3 phases done

### Decisions made this session
- Eliminated `_pending_fail` / `_process dequeue` pattern from plan: calling `_fire_terminal_async()` directly from `_notification` without `await` launches it as a GDScript 4 fire-and-forget coroutine — cleaner and equally safe
- `_fire_terminal_async` captures `_be_session_id` into local `id` before clearing — prevents double-fire if called twice
- `_exit_tree` cancels HTTPRequest if any request is in-flight on node removal

### Next immediate action
All phases complete — finalize with code review and commit

## Dependencies
- eco-backend must be running and reachable at `UserManager.base_url`
- JWT token must be present (`UserManager.is_logged_in()` must return true) before any sync call
- `FocusSession` entity and `FocusSessions` DbSet already exist — no new migration needed

## Risks
- MEDIUM: `IUnitOfWork` constructor is positional — adding `IFocusSessionRepository` requires
  updating the constructor signature and DI; follow the `IApiConfigRepository` pattern exactly
- MEDIUM: Clock skew between client and server for StartTime — BE always sets `DateTime.UtcNow`
  on creation; client never sends a timestamp
- MEDIUM: `_process` dequeue of `_pending_fail` fires one frame after the violation — acceptable
  latency for a background sync; the local state (`_state = FAILED`) is already correct by then
- LOW: `use_mock = true` accidentally left on in production — FocusManager emits a `push_warning`
  when mock path is active but a real token is present
