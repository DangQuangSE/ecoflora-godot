# Phase 3: BE Shop

**Codebase:** eco-backend (`d:\WorkWithCorn\eco-backend\`)

## Requirements
Expose a public shop catalog endpoint and a player-authenticated purchase endpoint. The purchase must be atomic (currency check + deduct + inventory upsert in one DB transaction) and must return the new user XP and level so the Godot client can sync progression after a purchase. Admin must be able to manage which items appear in the shop.

## Steps
1. **PREREQUISITE (do before any other step in this phase):** Audit `InventoryService.BuyItemAsync` and `UpsertInventoryItemAsync`. `UpsertInventoryItemAsync` calls `CommitAsync()` internally on the "create new inventory row" branch (line ~124). This breaks the outer transaction boundary. Refactor it: extract a `UpsertInventoryItemInternalAsync` that does all the upsert logic but does NOT call `CommitAsync`. Make `UpsertInventoryItemAsync` call `UpsertInventoryItemInternalAsync` then commit — preserving its existing callers. `BuyItemAsync` and Phase 2's `VitalityService.ClaimAsync` will both call `UpsertInventoryItemInternalAsync` within their own managed transactions. After this refactor, `BuyItemAsync` owns a single `BeginTransactionAsync`/`CommitAsync` boundary. Do NOT return `NewUserXP`/`NewUserLevel` from shop purchase — shop purchases award no XP. Return the current `user.CurrentXP` and `user.Level` values unchanged (read from the user row fetched during the currency check) so the client can sync any drift without a second DB write.
2. Add `IsActive bool` (default `true`) to both `Item` and `FlowerTemplate` entities via a new EF Core migration (`dotnet ef migrations add AddIsActiveToItems`). This is distinct from `IsDeleted` (soft-delete) — `IsActive = false` means "unlisted from shop" without being deleted. Update `OnModelCreating` to set `HasDefaultValue(true)` for both. Then add `GET /api/shop/items` to `ShopController`: create `ShopCatalogItemDto` (fields: `Id string`, `Name string`, `Description string`, `Price int`, `Category string` — "Consumable"/"Seed"/"Decoration", `ImageUrl string`, `IsActive bool`). The `Id` field must be prefixed: `"item:{guid}"` for `Item` records and `"seed:{guid}"` for `FlowerTemplate` records. This prefix is how the Godot client and `PurchaseAsync` route the ID back to the correct `BuyItemRequest.ItemId` vs `BuyItemRequest.FlowerTemplateId` field at purchase time.
3. Implement `IShopService` interface and `ShopService` class in `Application/Services/`. `GetCatalogAsync(string? category)` queries `Items` (type Water/Fertilizer/Pesticide → Consumable) and `FlowerTemplates` (→ Seed), filters `IsActive == true && IsDeleted == false`, maps to `ShopCatalogItemDto` with the `"item:"` / `"seed:"` prefixed IDs, optionally filters by category string. `PurchaseAsync(userId, prefixedId, quantity)`: strip the prefix, determine which Guid to put in `BuyItemRequest.ItemId` vs `BuyItemRequest.FlowerTemplateId`, then call `UpsertInventoryItemInternalAsync` within the existing transaction. **Shop purchases award no XP** — return `user.CurrentXP` and `user.Level` values read during the currency check (no second write).
4. Update `ShopController` to inject `IShopService` instead of (or alongside) `IInventoryService`. Wire `GET /api/shop/items` to `ShopService.GetCatalogAsync(category?)` and update `POST /api/shop/buy` (or add `POST /api/shop/purchase` alias) to call `ShopService.PurchaseAsync`.
5. Add admin shop management endpoints to `AdminInventoryController` (already exists): `PATCH /api/admin/items/{itemId}/toggle-active` and `PATCH /api/admin/flowtemplates/{templateId}/toggle-active`. These toggle the `IsActive` field (added in Step 2 migration) — NOT `IsDeleted`. Use `[Authorize(Roles = Constant.Roles.Admin)]`.
6. Register `IShopService` → `ShopService` in the DI container in `Program.cs`. Confirm `IInventoryService` is already registered (it is).
7. Test manually: `GET /api/shop/items` returns the water, fertilizer, pesticide, and seed items that exist in the database. `POST /api/shop/buy` with sufficient currency deducts currency, adds inventory, and returns `remainingCurrency` + `newUserXP` + `newUserLevel`. `POST /api/shop/buy` with zero currency returns 400.

## Success Criteria
- `GET /api/shop/items` returns HTTP 200 with an array where each item has `id`, `name`, `price`, `category`, and `isActive`.
- `GET /api/shop/items?category=Consumable` filters to only consumable items.
- `POST /api/shop/buy` with enough currency: HTTP 200 with `remainingCurrency` = prior balance minus cost, inventory count increased.
- `POST /api/shop/buy` with insufficient currency: HTTP 400 with `InsufficientCurrency` error message.
- Admin `PATCH /api/admin/items/{id}/toggle-active` returns 200 and the item no longer appears in `GET /api/shop/items` when deactivated.

## Risks
- **[Addressed in Step 1]** `UpsertInventoryItemAsync` had an internal `CommitAsync` — the prerequisite refactor removes it so all inventory upserts are now caller-transaction-managed.
- Catalog merges two entity types (Item + FlowerTemplate) — the `"item:"` / `"seed:"` prefix convention (Step 2) must be documented in `Constant.cs` so both `ShopService` and `ShopService.gd` (Godot Phase 4) use the same prefix strings.
- **New users:** `UserInventory` row is created at registration by `SeedStarterInventoryAsync`. If this path is ever skipped, the first `UpsertInventoryItemInternalAsync` call on a new account will attempt to insert a row with no parent inventory. Ensure registration always creates the inventory row before this code path is exercised.

## Files

| File | Layer | Action |
|---|---|---|
| `Domain/Entities/Item.cs` | Domain | Modify — add `IsActive bool` |
| `Domain/Entities/FlowerTemplate.cs` | Domain | Modify — add `IsActive bool` |
| `Infrastructure/Migrations/<timestamp>_AddIsActiveToItems.cs` | Infrastructure | Create — EF Core migration |
| `Application/Services/InventoryService.cs` | Application | Modify — extract `UpsertInventoryItemInternalAsync`, have `UpsertInventoryItemAsync` call it |
| `Application/DTOs/Shop/ShopCatalogItemDto.cs` | Application | Create |
| `Application/DTOs/Shop/ShopReceiptDto.cs` | Application | Modify — add `NewUserXP int`, `NewUserLevel int` |
| `Application/Interfaces/IShopService.cs` | Application | Create |
| `Application/Services/ShopService.cs` | Application | Create |
| `API/Controllers/ShopController.cs` | API | Modify — add GET /items, update POST /buy to use IShopService |
| `API/Controllers/AdminInventoryController.cs` | API | Modify — add toggle-active endpoints |
| `API/Program.cs` (or DI extension) | API | Modify — register IShopService |
