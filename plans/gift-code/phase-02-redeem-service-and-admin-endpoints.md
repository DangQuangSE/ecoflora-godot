# Phase 2: Backend Redeem Service with Concurrency Handling and Admin Endpoints

## Requirements

Implement GiftCodeService with redeemable gift code business logic (validation, atomic reward grant, quota enforcement, concurrency retry) and two admin endpoints for creating and deleting gift codes.

## Steps

1. Create `IGiftCodeRepository`/`GiftCodeRepository` (extends `IGenericRepository<GiftCode>`/`GenericRepository<GiftCode>`, mirroring `IItemRepository`/`ItemRepository`) with a `GetByCodeAsync(string code)` query (include `Rewards`). Create `IUserGiftCodeRedemptionRepository`/`UserGiftCodeRedemptionRepository` with an `ExistsAsync(Guid userId, Guid giftCodeId)` query. Add both as named properties (`GiftCodes`, `UserGiftCodeRedemptions`) on `IUnitOfWork`/`UnitOfWork`, following the exact constructor-injection pattern already used for `Items`/`Decors`/etc. Update `Application.Tests/TestSupport/SqliteUnitOfWorkFactory.cs` to construct and pass the two new repositories into `UnitOfWork`'s constructor — otherwise every existing Phase-2 test using this factory fails to compile.

2. Create GiftCodeService in Application/Services with an async Redeem method signature: RedeemAsync(userId, code) returning either a ApiResponse<GiftCodeRedeemResultDto> on success or an ApiError on failure.

3. Implement validation logic before transaction: normalize code to uppercase+trim, query GiftCode by Code, return distinct errors for NotFound, Expired (ExpiryDate < now), Inactive, and AlreadyRedeemed (query UserGiftCodeRedemption exists).

4. Implement 3–5 retry loop around the transaction: if retries exhausted, return an ApiError with conflict message. NOTE — this is an INTENTIONAL DEVIATION from `DailyTaskService`'s actual convention (single-attempt `TryCommitAsync()` call, return 409 to client on first conflict, no internal retry). Daily-task claims only contend with a single user's own duplicate requests; gift-code `TimesUsed` contention is cross-user and shared-row, much hotter during a promotional event, so an internal retry loop reduces client-visible 409s under that specific load shape. Validated in Step 4 of /ck:plan: user chose to keep the retry loop and confirm sufficiency via a 100-concurrent-request integration test rather than match the single-attempt convention.

5. Inside the retry loop, begin transaction, fetch GiftCode with tracking, re-check IsActive and ExpiryDate, validate quota (UsageLimit null or TimesUsed < UsageLimit), increment TimesUsed, mutate User.Currency, call InventoryService.UpsertInventoryItemAsync() for each GiftCodeReward line (mapping RewardType → target id column: Currency has no RefId, Item→ItemId, FlowerSeed→FlowerTemplateId, Decor→DecorId — see phase-01 step 2 mapping), insert UserGiftCodeRedemption row, call TryCommitAsync() ONCE per attempt — all mutations (TimesUsed increment, currency, every reward line, redemption row) go into the same SaveChanges/transaction so they commit or roll back together (no partial reward grant possible). On `DbUpdateConcurrencyException` from `TryCommitAsync()`, retry (re-fetch fresh GiftCode, re-check quota with up-to-date TimesUsed — the RowVersion mismatch is what makes the quota re-check race-safe: a concurrent winner's commit changes RowVersion, forcing the loser to retry against fresh data instead of stale TimesUsed). On success, return result and stop.

6. The unique-constraint violation on (UserId, GiftCodeId) is a DIFFERENT exception path from step 4's concurrency retry. `UnitOfWork.TryCommitAsync()` only catches `DbUpdateConcurrencyException` internally (rollback, return `(0, true)`) — any OTHER exception, including the `DbUpdateException` from a unique-index violation, falls into its generic catch which rolls back, disposes, and RETHROWS. So the service method must wrap its OWN `try/catch` around the call to `TryCommitAsync()`. Do NOT inspect the inner exception's provider-specific type/error code (e.g. `Npgsql.PostgresException.SqlState`) to detect the unique violation — production runs on PostgreSQL but `Application.Tests` runs against an in-memory SQLite connection (`TestSupport/SqliteUnitOfWorkFactory`), which throws a different exception type (`Microsoft.Data.Sqlite.SqliteException`) for the same constraint violation, so provider-specific inspection would pass in prod and silently fail to disambiguate in tests. Instead, on catching `DbUpdateException` from `TryCommitAsync()`, re-query (fresh, untracked) whether a `UserGiftCodeRedemption` row now exists for `(userId, giftCodeId)` — if yes, return `AlreadyRedeemed` WITHOUT entering the retry loop; if no, the exception is some other DB failure — rethrow or return a generic error. This re-query disambiguation is provider-agnostic and exercised identically by SQLite-backed unit tests and the real Postgres database.

7. Build GiftCodeRedeemResultDto with NewCurrencyTotal and a list of granted reward items (matching ClaimResultDto shape from DailyTaskService.cs lines 102–109), mirroring the structure so Godot client can apply result uniformly.

8. Create CreateGiftCodeRequest DTO: Code (string), ExpiryDate (DateTime UTC), UsageLimit (nullable int), Rewards (array of {RewardType, RefId, Quantity}).

9. Implement CreateGiftCodeAsync endpoint logic: normalize Code, validate Rewards array is non-empty, validate each Reward's RefId exists BEFORE opening any transaction (query Item/FlowerTemplate/Decor per RewardType mapping from phase-01 step 2 — reject the whole request if any RefId is invalid, never insert partial reward lines), insert GiftCode + GiftCodeReward rows, return the created GiftCode with reward lines as DTO. Status codes: 201 on success, 400 on validation failure (empty rewards, invalid RefId), 409 if Code already exists.

10. Implement DeleteGiftCodeAsync endpoint logic: query GiftCode by id (404 if not found), call SaveChangesAsync() (cascade will delete GiftCodeReward and UserGiftCodeRedemption rows per phase 1 config — this is a hard delete per spec.md, no soft-delete flag check needed beyond the lookup). Status codes: 200 with deleted id on success, 404 if not found.

11. Implement ToggleGiftCodeActiveAsync endpoint logic: query GiftCode by id (404 if not found), accept a `{ IsActive: bool }` body, set `GiftCode.IsActive` to the requested value, call SaveChangesAsync(). This is the "pause without deleting" toggle separate from hard-delete (FR-05 note in spec.md) — does not touch ExpiryDate, UsageLimit, or TimesUsed. Status codes: 200 with updated `{id, isActive}` on success, 404 if not found.

12. Register all endpoints in a new GiftCodesController (or AdminGiftCodesController for the three admin routes): `POST /admin/gift-codes` (create), `DELETE /admin/gift-codes/{id}` (delete), `PATCH /admin/gift-codes/{id}` (toggle IsActive). Decorate the controller (or all three actions) with `[Authorize(Roles = $"{Constant.Roles.Admin},{Constant.Roles.SuperAdmin}")]` — the exact pattern used by `AdminDailyTasksController` — using the existing `Constant.Roles` static class (`Player`/`Admin`/`SuperAdmin` constants), not a literal `"Admin"` string. `POST /gift-codes/redeem` stays on the standard player `[Authorize]` policy. Redeem endpoint status codes: 200 success, 400 NotFound/Expired/Inactive, 409 AlreadyRedeemed/QuotaExceeded.

13. Add GiftCodeService and repositories to DI container (Program.cs composition root, mirroring existing `AddScoped<IGiftCodeRepository, GiftCodeRepository>()`-style registrations).

## Success Criteria

- Redeem endpoint enforces all validation rules (code exists, not expired, quota not exceeded, not already redeemed by user).
- Concurrent redeem requests on same (user, code) with quota=1 result in exactly 1 successful grant; second request returns AlreadyRedeemed or QuotaExceeded.
- Admin create endpoint persists GiftCode + 1+ GiftCodeReward rows; admin can create a code with currency + 2 item types in one request.
- Admin delete endpoint cascades to GiftCodeReward and UserGiftCodeRedemption rows.
- Admin toggle endpoint flips IsActive without affecting ExpiryDate/UsageLimit/TimesUsed; a redeem attempt on a toggled-off code returns Inactive (not NotFound/Expired).
- Response DTO mirrors ClaimResultDto shape so Godot client can reuse existing reward-apply logic.

## Testing

- **Unit Test (Validation)**: Mock GiftCode queries; redeem with NotFound, Expired, InactiveCode, AlreadyRedeemed scenarios; verify correct error codes returned.
- **Unit Test (Quota)**: Create GiftCode with UsageLimit=2; mock concurrent redeem calls; verify exactly 2 succeed and 3rd returns QuotaExceeded.
- **Unit Test (Concurrency)**: Mock DbUpdateConcurrencyException on TryCommitAsync; verify retry loop re-fetches GiftCode and re-checks quota.
- **Integration Test (Double-Redeem)**: Run actual 100 concurrent redeem requests for same user+code with quota=1; verify exactly 1 success via database count.
- **Integration Test (Quota Race)**: Before shipping, run a realistic-scale integration test — 100 concurrent redeem requests from different users against a single code with UsageLimit=30 — verify exactly 30 grants issued and no over-grant; this validates the 3–5 retry budget is sufficient under expected hot-event load rather than assuming it analytically.
- **Integration Test (Unique Constraint)**: Insert two UserGiftCodeRedemption rows for same user+code outside transaction; verify exception handling maps to AlreadyRedeemed error.
- **Unit Test (Admin Create)**: Call CreateGiftCodeAsync with multi-reward payload; verify GiftCode + 3 GiftCodeReward rows inserted.
- **Unit Test (Admin Delete)**: Call DeleteGiftCodeAsync; verify cascade deletes related rows.
- **Unit Test (Admin Toggle)**: Call ToggleGiftCodeActiveAsync(id, false); verify IsActive flips and a subsequent redeem attempt returns Inactive error.

## Risks

- Concurrency retry may timeout if database is slow — Mitigation: Set retry limit to 3–5, log each retry, alert operator if repeatedly exhausted. Confirmed acceptable for MVP scale without raising the retry budget preemptively — validated empirically via the 100-concurrent-request integration test above rather than increased speculatively; revisit retry count only if that test shows under-grants.
- DbUpdateException from unique constraint vs other database errors may overlap — Mitigation: Check exception message or inner exception; document expected exception types.
- Reward RefId validation may miss edge cases (deleted item, type mismatch) — Mitigation: Add unit tests for each RefId type; consider stricter validation if abuse observed.
