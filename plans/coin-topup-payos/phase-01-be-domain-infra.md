# Phase 1: BE Domain + Infrastructure

**Repo:** `D:\GitHub\eco-backend`
**Covers spec stories:** FR-01 (`CoinPackage`), FR-02 (`PaymentOrder`) — foundational data layer underpinning all P1 stories.

## Requirements
After this phase, the database has a `CoinPackages` table seeded with the 4 fixed tiers and an empty `PaymentOrders` table with the constraints needed for idempotent crediting, both reachable through the existing `IUnitOfWork` pattern exactly like `RewardTierConfigs`/`DailyTaskDefinitions`.

## Steps
1. Define the `CoinPackage` entity (`Id`, `PriceVnd`, `CoinAmount`, `IsActive`) under `Domain/Entities`, following the existing `BaseEntity`/style of `DailyTaskDefinition.cs`.
2. Define the `PaymentOrder` entity (`Id`, `OrderCode` unique numeric, `UserId`, `CoinPackageId`, `AmountVnd`, `Status` enum, `CreatedAt`, `ExpiresAt`, `PaidAt`, `LastReconciliationAt` nullable `DateTime`) under `Domain/Entities`, with a `Status` enum (`Pending/Paid/Cancelled/Expired`) under `Domain/Enums`. `LastReconciliationAt` rate-limits the Phase 2 backup reconciliation check (only re-call PayOS's GET status API if enough time has passed since the last attempt) — see Phase 2 step 5.
3. Register both as `DbSet`s in `AppDbContext`, configure the `Status` enum as string conversion (matching `DailyTaskDefinition.Type`/`Cycle` convention), add the unique index on `PaymentOrder.OrderCode`, and wire FK relationships to `User` and `CoinPackage` (no navigation collection needed on `User`, mirroring `UserTaskProgress`'s FK-only relation).
4. Create `ICoinPackageRepository` and `IPaymentOrderRepository` (extending `IGenericRepository<T>`) with the specific lookups each service phase will need: active-package listing, a read-only get-by-orderCode (for the status-poll path, no tracking needed), and get-Pending-orders-past-expiry (for the reconciliation sweep). **Do not add a load-then-mutate-then-save method for the Paid/Expired transition** — Phase 2's webhook handler and reconciliation check must use EF Core's `ExecuteUpdateAsync` (atomic `UPDATE ... WHERE` translated directly to SQL, no load step) against `DbContext.PaymentOrders` directly, guarded by `WHERE OrderCode = @code AND Status IN (Pending, Expired)`, checking the returned affected-row count before crediting currency. This avoids the TOCTOU race a load→check-in-C#→`SaveChangesAsync()` pattern would have under concurrent/duplicate webhook delivery (no rowversion/concurrency token is being added to `PaymentOrder` — `ExecuteUpdateAsync`'s atomicity is the idempotency mechanism, not EF optimistic concurrency).
5. Implement both repositories under `Infrastructure/Repositories`, register them in `UnitOfWork`/`IUnitOfWork` (new properties `CoinPackages`, `PaymentOrders`) and in `Program.cs` DI (`AddScoped`), following the exact pattern of `IRewardTierConfigRepository`/`RewardTierConfigRepository`.
6. Add the 4 seed rows for `CoinPackage` to `Infrastructure/Data/Seeder.cs` (20.000đ/200, 50.000đ/500, 100.000đ/1.000, 200.000đ/2.000), guarded by an existence check like the existing `DailyTaskDefinitions` seed block.
7. Generate and apply the EF Core migration covering both new tables, the enum-as-string conversion, and the unique index; verify the generated SQL matches expectations before applying to the dev database.

## Success Criteria
- `dotnet ef database update` (or equivalent) applies cleanly and `CoinPackages`/`PaymentOrders` tables exist with the unique index on `OrderCode`.
- Querying the seeded data shows exactly 4 active `CoinPackage` rows with the correct price/coin pairs.
- `dotnet build` succeeds with the new entities/repositories wired into `IUnitOfWork` and `Program.cs` with no missing DI registrations.
- A throwaway integration check (e.g. temporary test query or REPL) confirms inserting two `PaymentOrder` rows with the same `OrderCode` throws a unique-constraint violation.

## Risks
- Choosing the wrong column type for `OrderCode` (must be a numeric type PayOS accepts, not a GUID) — mitigate by using `long` per spec FR-02 and confirming against PayOS's documented `orderCode` field type before the migration is finalized.
- Migration conflicts with concurrent work on `main`/other feature branches touching `AppDbContext` — mitigate by generating the migration last, right before opening the PR, and rebasing if `AppDbContextModelSnapshot.cs` has diverged.
