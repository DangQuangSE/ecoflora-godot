# Spec: Admin-managed daily task rewards

**Date:** 2026-06-19
**Status:** Draft

---

## Problem Statement

Daily/weekly task rewards (`RewardCurrency`, `RewardXP`, `RewardItemId`, `RewardItemQty`) are currently hard-coded in `Infrastructure/Data/Seeder.cs` with no API to change them after deploy. An admin (via a separate FE built by another partner) needs to tune reward values without a redeploy. Task content (title/description/type/target/cycle) must stay untouched since it's defined by the Godot client's stable task-id contract.

---

## User Stories

- **[P1]** As an admin, I want to GET the full list of daily/weekly task definitions with their current reward values, so I can see what exists before editing.
  Accepted when: `GET /api/admin/daily-tasks` returns all `DailyTaskDefinition` rows (including inactive) with id, title, type, target, cycle, and the 4 reward fields.

- **[P1]** As an admin, I want to update only the reward fields of one task by id, so that task content defined in Godot is never accidentally changed.
  Accepted when: `PATCH /api/admin/daily-tasks/{id}/reward` accepts only `{ rewardCurrency, rewardXP, rewardItemId, rewardItemQty }`, persists them, and the response/DB shows title/description/type/target/cycle unchanged.

- **[P1]** As an admin, I want the endpoint to reject a `rewardItemId` that doesn't exist in the `Items` table, so I can't configure a task that silently fails to grant its item reward at claim time.
  Accepted when: PATCH with an unknown `rewardItemId` returns 400 and does not save.

- **[P2]** As an admin, I want `rewardItemQty` auto-validated against `rewardItemId` (qty > 0 required when item set, forced to 0 when item cleared), so the two fields can't drift into an inconsistent state.
  Accepted when: PATCH with `rewardItemId` set and `rewardItemQty <= 0` returns 400; PATCH with `rewardItemId` null forces stored `rewardItemQty` to 0 regardless of request value.

- **[P3]** _(out of scope — noted for future)_ Audit log of who changed which reward and when.
- **[P3]** _(out of scope — noted for future)_ Bulk PATCH for multiple tasks in one call.
- **[P3]** _(out of scope — noted for future)_ Admin-side create/delete of task definitions.

---

## Functional Requirements

1. FR-01: `GET /api/admin/daily-tasks` — `[Authorize(Roles = "Admin,SuperAdmin")]`, returns `ApiResponse<List<DailyTaskAdminDto>>` with all task definitions (active and inactive), each including id, title, description, type, actionSubtype, target, cycle, isActive, rewardCurrency, rewardXP, rewardItemId, rewardItemQty.
2. FR-02: `PATCH /api/admin/daily-tasks/{id}/reward` — `[Authorize(Roles = "Admin,SuperAdmin")]`, body `UpdateDailyTaskRewardRequest { RewardCurrency, RewardXP, RewardItemId, RewardItemQty }`. Updates only those 4 columns on the matching `DailyTaskDefinition`; 404 if id not found.
3. FR-03: Server-side validation before save: `RewardCurrency >= 0`, `RewardXP >= 0`; if `RewardItemId` is non-null it must exist in `Items` (via `IUnitOfWork.Items`) and `RewardItemQty > 0`; if `RewardItemId` is null, stored `RewardItemQty` is forced to `0`.
4. FR-04: No new DB migration needed — reuses existing `DailyTaskDefinition` columns (`Domain/Entities/DailyTaskDefinition.cs:15-18`).
5. FR-05: Edits take effect immediately for any unclaimed `UserTaskProgress` in the current period, since `ClaimTaskAsync` reads reward fields live from `DailyTaskDefinition` at claim time, not from a snapshot.

---

## Non-Functional Requirements

- Performance: single-row lookup + update, no batching needed; p95 < 200ms (in line with other Admin*Controller endpoints).
- Security: both endpoints require `Admin` or `SuperAdmin` role via existing JWT role claim, matching `AdminRewardTierController`'s `[Authorize(Roles = $"{Constant.Roles.Admin},{Constant.Roles.SuperAdmin}")]` pattern.
- Availability: no new infra dependency; reuses existing `AppDbContext` / `IUnitOfWork`.

---

## Success Criteria

- [ ] Admin can list all 8 seeded tasks with current reward values via `GET /api/admin/daily-tasks`.
- [ ] Admin can change e.g. "Tưới cây 3 lần" reward from 50 xu/20 XP to any new value via one PATCH call, verified by a subsequent GET showing the new values and title/target/cycle unchanged.
- [ ] PATCH with a non-existent `rewardItemId` GUID returns 400 and leaves the row unchanged.
- [ ] A task edited mid-period (before a player claims it) grants the *new* reward values on claim, not the values that existed when progress started.

---

## Out of Scope

- Editing title, description, type, actionSubtype, target, or cycle — these are owned by the Godot client contract (`domain/DailyTask.gd`, `TASK_IDS`).
- Admin FE UI — built by another partner; this spec covers backend API only.
- Audit/history of reward changes.
- Creating or deleting task definitions via API.

---

## Assumptions

- GET returns *all* task definitions (active + inactive) — admin needs full visibility to manage rewards even for currently-inactive tasks.
- "Admin" in this context reuses the existing `Constant.Roles.Admin` / `SuperAdmin` JWT role claim already used by `AdminRewardTierController` and `AdminInventoryController` — no new role type needed.
- The FE partner will call these endpoints directly; no Swagger/contract doc beyond the existing `[ProducesResponseType]` attributes is required for this spec.

---

**Resolved:** `Description` is included read-only in the GET DTO (already specified in FR-01) — free column on the entity, no reason to omit it.
