# Phase 2: Admin Shop Service

**Depends on:** Phase 1 complete (CharacterConfig entity + IUnitOfWork.CharacterConfigs)

## Requirements

Implement `IAdminShopService` and `AdminShopService` to aggregate all shop items into a unified catalog and update prices by prefixed ID.

## Steps

1. Create `Application/DTOs/Shop/AdminShopCatalogItemDto.cs`:
   - `Id: string` (prefixed: `item:`, `seed:`, `deco:`, `character:`)
   - `Name: string`
   - `Price: int`
   - `Category: string`
   - `IsActive: bool`

2. Create `Application/DTOs/Shop/UpdateShopItemPriceRequest.cs`:
   - `Price: int`

3. Create `Application/Interfaces/IAdminShopService.cs`:
   ```csharp
   Task<(ApiResponse<List<AdminShopCatalogItemDto>>? Success, ApiError? Error)> GetCatalogAsync();
   Task<(ApiResponse<AdminShopCatalogItemDto>? Success, ApiError? Error)> UpdatePriceAsync(string prefixedId, int price);
   ```

4. Create `Application/Services/AdminShopService.cs` implementing `IAdminShopService`:

   **GetCatalogAsync** — aggregate from 4 sources:
   - `_unitOfWork.Items.GetAllAsync()` → map to `AdminShopCatalogItemDto` with `id = "item:{item.Id}"`
   - `_unitOfWork.FlowerTemplates.GetAllAsync()` → prefix `seed:`
   - `_unitOfWork.Decors.GetAllAsync()` → prefix `deco:`
   - `_unitOfWork.CharacterConfigs.GetAllAsync()` → prefix `character:{config.CharacterIndex}`
   - Merge and return as single list.

   **UpdatePriceAsync** — validation + routing:
   ```
   Step 1: Validate price >= 0 → HTTP 400 if not
   Step 2: Parse prefixedId format:
     - Split on first ':' → [prefix, rawId]
     - If format invalid (no ':' found) → HTTP 400 "Invalid prefixedId format"
   Step 3: Route by prefix:
     - "item:"      → Guid.TryParse(rawId) → HTTP 400 if fails → lookup Item, update Item.Price
     - "seed:"      → Guid.TryParse(rawId) → HTTP 400 if fails → lookup FlowerTemplate, update BasePrice
     - "deco:"      → Guid.TryParse(rawId) → HTTP 400 if fails → lookup Decor, update Price
     - "character:" → int.TryParse(rawId) + validate >= 0 → HTTP 400 if fails → lookup CharacterConfig by index
     - unknown prefix → HTTP 400 "Unknown prefix"
   Step 4: Entity null → HTTP 404 "Item not found"
   Step 5: Update price field
   Step 6: Call TryCommitAsync() — if HasConcurrencyConflict → return HTTP 409 "Price was updated concurrently. Refresh and retry."
   Step 7: Return updated AdminShopCatalogItemDto with 200
   ```

5. Note: `HasQueryFilter` on CharacterConfig already excludes soft-deleted rows. A null result from `GetByCharacterIndexAsync` means not found or deleted — null-check alone is sufficient, no explicit `IsDeleted` check needed.

6. Note: Authorization is enforced at controller layer (Phase 3). No in-service auth check needed.

7. Write unit tests:
   - `GetCatalogAsync` returns items from all 4 categories with correct prefix format
   - `UpdatePriceAsync` updates `Item.Price`, `FlowerTemplate.BasePrice`, `Decor.Price`, `CharacterConfig.Price` correctly
   - `UpdatePriceAsync` returns HTTP 400 for `price = -1`
   - `UpdatePriceAsync` returns HTTP 400 for `prefixedId = "badformat"`
   - `UpdatePriceAsync` returns HTTP 400 for `prefixedId = "character:-1"`
   - `UpdatePriceAsync` returns HTTP 404 for non-existent GUID or index
   - `UpdatePriceAsync` returns HTTP 409 when `TryCommitAsync` detects concurrency conflict

## Success Criteria

- `GetCatalogAsync` returns list with all 4 category prefixes
- `UpdatePriceAsync` routes correctly for each prefix
- Price < 0 → HTTP 400
- Unknown prefix or parse failure → HTTP 400
- Missing entity → HTTP 404
- Concurrency conflict → HTTP 409
- After update, `GetCatalogAsync` reflects new price immediately

## Risks

- `TryCommitAsync` pattern must exist in IUnitOfWork — verify it exists or add before Phase 2.
- Prefix format `character:{index}` uses int, not GUID — ensure TryParse branch is explicit and validated >= 0.
