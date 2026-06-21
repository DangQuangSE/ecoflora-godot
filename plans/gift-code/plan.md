# Plan: Gift Code Redemption

Status: Complete
Date: 2026-06-20
Mode: Hard

## Overview

Implement a gift code feature enabling admins to create and manage promotional codes with configurable rewards (currency, items, seeds, decor) and usage limits, while players redeem codes once per account to receive rewards atomically in a single transaction.

## Phases

- [x] Phase 1: Backend Domain Entities and Database Schema — Create GiftCode, GiftCodeReward, and UserGiftCodeRedemption entities with EF migrations, unique constraints, and concurrency tokens for race-safe operations.
- [x] Phase 2: Backend Redeem Service with Concurrency Handling — Implement redemption business logic with 3–5 retry loop on optimistic concurrency conflicts, plus admin endpoints (create, delete, toggle IsActive) with validation.
- [x] Phase 3: Godot Client Manager and Redemption UI — Build GiftCodeManager autoload following TaskManager pattern, connect redeem endpoint, apply rewards via UserManager and InventoryManager, and create minimal input dialog UI.
- [x] Phase 4: Admin API Documentation — Document the admin create and delete endpoint contracts for the FE web admin team to build their own UI.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-21 01:20
**Phase in progress:** phase-04-admin-api-documentation (complete)
**Status:** `docs/admin-gift-code-api.md` written in eco-backend covering POST/DELETE/PATCH admin endpoints with real DTO schemas, error codes, curl examples, normalization notes, and testing checklist.

### Decisions made this session
- Used the real `Constant.Error.GiftCode*` names/messages found in `Constant.cs` instead of the plan's placeholder error names (`InvalidCode`/`InvalidReward`/`InvalidExpiryDate`/`Unauthorized`/`Conflict` don't exist as such) — docs reflect the actual implementation.
- Discovered `CreateGiftCodeAsync` does not validate `ExpiryDate` is in the future — documented as an explicit "Known gap" section with a testing-checklist item confirming the actual (non-error) behavior, rather than fabricating an `InvalidExpiryDate` error that doesn't exist in code.
- Confirmed ASP.NET Core default camelCase JSON serialization (no override in `Program.cs`) by cross-checking an existing doc (`docs/tips-from-db/admin-api.md`) that shows the same envelope shape live.
- Followed the existing repo convention of Vietnamese-language FE-facing API docs (matches `docs/api-coin-topup.md`, `docs/tips-from-db/admin-api.md` style/tone).
- Documented the PATCH-vs-redeem distinction explicitly (toggled-off code returns `Gift code không còn hoạt động.` 400, not 404 `NotFound`), per phase requirement.

### Next immediate action
Per user instruction ("tiếp tục code khi nào tôi bảo review tiếp thì review"), all 4 phases are now implementation-complete — proceed to Step 5 Finalize (project-manager, docs-manager, Spec Coverage report, git-manager) without pausing for a Review Gate unless the user asks for review first.

## Research Summary

The brainstorm report confirmed the decided architecture:
- Relational reward model (GiftCodeReward table) over JSON blob for consistency with existing InventoryItem schema and easier querying.
- Reuse DailyTaskService.cs lines 54–110 pattern: begin transaction, mutate User+progress rows, call TryCommitAsync() with DbUpdateConcurrencyException catch, retry loop around the whole method.
- Unique DB constraint (UserId, GiftCodeId) on UserGiftCodeRedemption to prevent race-condition double-claims.
- Gift code matching is case-insensitive (uppercase + trim normalization at creation and redemption).
- Godot client mirrors TaskManager.gd lines 162–184: call async service, apply result to UserManager.update_currency() and InventoryManager.add_reward_item(), emit signal for UI feedback.

## Dependencies

None. The feature reuses existing infrastructure (UnitOfWork, TryCommitAsync, InventoryManager, UserManager) without external service dependencies.

## Risks

- HIGH: Concurrent double-redeem and quota-race conditions — Mitigation: DB unique constraint on (UserId, GiftCodeId) + optimistic concurrency retry loop (3–5 attempts) with re-check of quota on each retry, matching DailyTaskService pattern. The 3–5 retry budget is validated, not assumed: phase-02 requires a 100-concurrent-request integration test against a UsageLimit=30 code before shipping to confirm no over/under-grant at expected event scale.
- MEDIUM: Code case-sensitivity and normalization inconsistency — Mitigation: Always normalize to uppercase+trim at create and redeem time; test case-insensitivity in unit tests.
- LOW: Admin UI out of scope — Mitigation: Document API contract in markdown for FE web team; no admin UI code in this feature.
