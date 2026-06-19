# Plan: Daily Task System
Status: ✅ Complete
Date: 2026-06-15
Mode: Hard

## Overview
Implement a Daily/Weekly Task system that tracks player actions (garden care, harvest, focus sessions, online time), persists progress locally, and rewards currency/items/XP via a dedicated backend claim endpoint — creating a daily engagement loop without adding per-action API calls.

## Phases
- [x] Phase 1: Domain + Service — DailyTask and TaskProgress domain classes; DailyTaskService for API parsing and claim
- [x] Phase 2: Task Manager Autoload — TaskManager singleton wiring all signals, online timer, local file persistence, and care_completed signal added to GardenManager
- [x] Phase 3: UI Panel — DailyTaskPanel scene with Daily/Weekly tab switcher, task cards, progress bars, and claim button; HUD entry point
- [x] Phase 4: Backend — ASP.NET Core .NET 8 entities, migration, GET list endpoint with lazy reset, POST claim endpoint with reward grant, and supplementary cron reset

## Research Summary

**Approach chosen: Hybrid local-track + BE claim**

The client tracks all progress in-memory and persists to `user://daily_task_progress.json`. The server is never called when progress increments — only on claim (POST) and on session load (GET). This keeps the action loop snappy (< 16ms local signal handler) and battery-friendly.

Key decisions from research:

- **Timer pattern**: `_process(delta)` with `set_process(false/true)` — same pattern as FocusManager. No Timer node for the online-time accumulator (avoids battery drain on mobile).
- **Reset detection**: `last_reset_epoch` comes from the server's `serverTime` field in the GET response, not from the device clock. The local JSON stores this so comparisons survive app restarts.
- **Lazy reset on GET**: The backend's `GET /api/daily-tasks` checks whether the stored `periodStart` has expired (before 7AM UTC+7 today/this week) and resets inline — cron job is a supplementary cleanup only, not the primary reset mechanism. This prevents stale data if the cron missed a run.
- **Task definitions on BE**: Task IDs are stable strings seeded into the database via `appsettings.json` config; the Godot client never hardcodes task logic, only task IDs for offline fallback display.
- **Claim validation on BE**: The claim endpoint performs a COUNT query on existing action records (PlantedFlower care logs or FocusSession rows) to cross-validate before granting reward. Client progress is trusted for UX display only.
- **Weekly reset**: Monday 7AM UTC+7, same lazy-reset pattern as daily.
- **Offline fallback**: If `GET /api/daily-tasks` fails, TaskManager shows the last-cached tasks from local JSON. Progress continues accumulating and will sync on next successful GET.

**Signals to hook (already exist in codebase):**
- `GardenManager.harvest_completed(plot_id, product_id)` — HARVEST tasks
- `FocusManager.session_completed(minutes_focused)` — FOCUS_SESSION tasks
- `UserManager.login_succeeded` — start online timer, trigger GET
- `GardenManager.care_completed(plot_id, action_type)` — GARDEN_CARE tasks (NEW — Phase 2)

## Dependencies
- eco-backend Phase 4 must be deployed before claim rewards work end-to-end; Godot client degrades gracefully (claim button shows error toast) if endpoint is missing
- `GardenManager.care_completed` signal (Phase 2) must land before TaskManager (Phase 2) connects to it — both in same phase
- Use `InventoryManager.add_reward_item(item_id, "", qty)` for task item rewards — `add_item` does not exist; `add_reward_item` is the correct method and accepts arbitrary item IDs
- `UserManager.apply_server_xp` and `UserManager.update_currency` already exist — no changes needed

## Risks
- HIGH: Reset epoch comparison uses server time from GET response — if GET fails on login, local time drift (device clock wrong) could cause phantom resets. Mitigation: only reset when server confirms; keep local progress if GET fails.
- MEDIUM: Two simultaneous claim taps (fast double-tap) hit the endpoint twice before first response returns. Mitigation: set `_claim_in_flight` flag in TaskManager before await; disable claim button on first tap.
- MEDIUM: `care_completed` signal added to GardenManager touches the mock path and the real path at the same location as existing synergy XP emit — regression risk. Mitigation: emit AFTER plot.is_pending_sync = false in success path only, matching harvest_completed pattern.
- LOW: `user://daily_task_progress.json` grows unbounded if old period entries are not pruned. Mitigation: on each save, write only the current period's tasks (overwrite full file, not append).
- LOW: `server_time == 0` from a failed GET must not trigger a reset — Phase 2 Step 4 must guard: skip the epoch comparison entirely if `decoded_server_time == 0` (offline).
- LOW: Multiple signals firing in the same frame each call `_save_progress` — use a `_progress_dirty: bool` flag; write once per frame in `_process` instead of per-signal.
- LOW: No logout handler — connect to `UserManager.login_required` in `_ready` to call `set_process(false)` and clear in-memory task/progress state when session ends (Phase 2 Step 3 extension).
- LOW: Stable Guid contract — the 8 task Guids seeded in BE (Phase 4 Step 2) must match the offline fallback IDs in Godot (Phase 1). Create `docs/daily-task/task-stable-ids.md` in BE repo and reference it from Phase 1 before implementation starts.
