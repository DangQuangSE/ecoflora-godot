# Brainstorm: Admin-managed daily task rewards

**Date:** 2026-06-19

## Ideas Explored

- **Full admin CRUD for task definitions** — dismissed immediately by the user: title/description/type/target/cycle are defined in Godot client code (`DailyTaskService.gd` TASK_IDS + offline fallback), so the backend must treat those fields as immutable. Only reward fields can move to admin control.
- **Reward-only edit endpoint (chosen direction)** — BE exposes a GET (list current task defs + rewards) and a PATCH-per-task (edit only `RewardCurrency`/`RewardXP`/`RewardItemId`/`RewardItemQty`) under an `api/admin/daily-tasks` route, mirroring the existing `AdminRewardTierController` pattern (`Authorize(Roles = Admin,SuperAdmin)`, PATCH `{id}`, `ApiResponse<T>` envelope).
- **Bulk edit (array PATCH)** — considered, but user picked per-task single edit since FE partner will build the actual UI and a 1-task-per-call shape is simpler to integrate against (e.g. inline edit in a table row).
- **Audit log of reward changes** — considered, explicitly rejected as over-engineering for an EXE2-scope project; direct overwrite is enough.
- **Item-id validation against the `Items` table** — confirmed worth doing (cheap, via existing `IUnitOfWork.Items` repo) so admins can't silently set a `RewardItemId` that doesn't exist and break claim-time item granting.

## User's Direction

FE for this admin feature is built by a different partner — this work is backend-only. Backend must:
1. Let admin **GET** the existing task definitions (already defined client-side in Godot, just reflected/seeded in `DailyTaskDefinition`).
2. Let admin **edit only the reward fields** of a given task by id — never title, description, type, target, or cycle, since those are the contract with the Godot client (`domain/DailyTask.gd`, `TASK_IDS` stable-id map).

Confirmed via questions: Admin/SuperAdmin role required (consistent with other `Admin*Controller`s), validate `RewardItemId` exists in `Items` table before saving, one task per request (not bulk), no audit/history table.

## Open Questions

- Should the GET endpoint return inactive (`IsActive = false`) task definitions too, or only active ones? (Assumption taken in spec: return all — admin needs to see everything to manage it, even if players never see inactive tasks.)
- Should `RewardItemQty` be forced to 0 when `RewardItemId` is cleared, and required > 0 when set? (Assumption taken in spec: yes, enforce that pairing server-side.)

## Risks

- `ClaimTaskAsync` reads `taskDef.RewardCurrency`/`RewardXP`/`RewardItemId`/`RewardItemQty` live at claim time (not snapshotted into `UserTaskProgress`), so an admin edit takes effect immediately for any not-yet-claimed progress — including mid-period. This is consistent with "live config" expectations but should be called out so it isn't a surprise.
- `RewardItemId` validation needs the existing `Items` repository lookup; if that repository's read method isn't already exposed in a convenient form, a small addition may be needed (low risk, already confirmed `IUnitOfWork.Items` exists).
