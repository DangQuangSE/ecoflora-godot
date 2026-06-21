# Phase 1: Backend Domain Entities and Database Schema

## Requirements

Create GiftCode, GiftCodeReward, and UserGiftCodeRedemption domain entities and EF Core model configuration with unique constraints and optimistic concurrency tokens, persisted via a new database migration.

## Steps

1. Create GiftCode entity in Domain/Entities with properties: Id (Guid), Code (string, normalized), ExpiryDate (DateTime UTC), UsageLimit (nullable int), TimesUsed (int, default 0), IsActive (bool). Decorate `TimesUsed` with `[ConcurrencyCheck]` for optimistic concurrency — this matches the existing codebase convention (`User.VitalityReadyAt`, `User.LastLoginDate`) of putting `[ConcurrencyCheck]` directly on the mutable field being raced over, rather than a separate RowVersion/byte[] column. EF Core picks this up automatically with no `OnModelCreating` fluent call needed.

2. Create GiftCodeReward entity in Domain/Entities as a 1-to-many child of GiftCode with properties: Id (Guid), GiftCodeId (FK), RewardType (enum: Currency/Item/FlowerSeed/Decor), RefId (nullable Guid), and Quantity (int). `RefId` is null when `RewardType=Currency`; otherwise it is a foreign key into a DIFFERENT table depending on `RewardType` — `RewardType=Item` → `ItemId`, `RewardType=FlowerSeed` → `FlowerTemplateId`, `RewardType=Decor` → `DecorId`. Document this mapping in the entity's XML doc comment since `RefId` has no single FK constraint (it's a polymorphic reference resolved by `RewardType` at the service layer, same way `InventoryItem` already carries separate nullable `ItemId`/`FlowerTemplateId`/`DecorId` columns).

3. Create UserGiftCodeRedemption entity in Domain/Entities with properties: Id (Guid), UserId (FK), GiftCodeId (FK), and RedeemedAt (DateTime UTC).

4. Register all three entities as DbSet properties in AppDbContext.

5. Configure EF Core relationships in AppDbContext.OnModelCreating: GiftCode-to-GiftCodeReward 1-to-many with cascade delete, GiftCode-to-UserGiftCodeRedemption (no nav, FK only), User-to-UserGiftCodeRedemption (no nav, FK only), and enum conversions for RewardType.

6. Create a unique index on UserGiftCodeRedemption (UserId, GiftCodeId) and a unique index on GiftCode (Code) to enforce single-redemption per user and prevent duplicate code names.

7. (Superseded by step 1 — `[ConcurrencyCheck]` on `TimesUsed` requires no separate fluent configuration in `OnModelCreating`.)

8. Create an EF Core migration (name: AddGiftCodeEntities or similar) via `dotnet ef migrations add AddGiftCodeEntities --project Infrastructure --startup-project API` to generate schema changes. Database is PostgreSQL — expect `uuid`, `text`, `boolean`, `timestamp with time zone` column types in the generated migration, consistent with existing migrations.

9. Apply migration to the database and verify table structure with a simple query (SELECT * FROM GiftCodes LIMIT 1, etc.).

## Success Criteria

- GiftCode, GiftCodeReward, and UserGiftCodeRedemption tables exist in the database with correct columns and constraints.
- Unique constraints are enforced: (UserId, GiftCodeId) on UserGiftCodeRedemption, Code on GiftCode.
- `[ConcurrencyCheck]` on GiftCode.TimesUsed causes a stale-write to throw `DbUpdateConcurrencyException` (verified by mutating the same row from two different DbContext instances loaded from the same initial state).
- EF Core entity classes compile and load without errors in DI.
- Unit test confirms that attempting to insert duplicate (UserId, GiftCodeId) raises DbUpdateException with unique constraint violation.

## Testing

- **Unit Test (EF Core)**: Create a test fixture that inserts two UserGiftCodeRedemption rows for the same user and code, verify DbUpdateException thrown.
- **Unit Test (Unique Code)**: Attempt to insert two GiftCode rows with same Code value, verify constraint violation.
- **Integration Test (Migration)**: Run migration in a fresh test database, verify all three tables and indexes are present via SQL query.

## Risks

- `[ConcurrencyCheck]` relies on EF Core comparing the original column value in the UPDATE's WHERE clause — Mitigation: confirmed working convention already in production via `User.VitalityReadyAt`/`LastLoginDate`; no new abstraction risk.
- Cascade delete on GiftCodeReward may cause issues if RewardType references are later added — Mitigation: Accept cascade behavior for MVP; document as potential migration point.
