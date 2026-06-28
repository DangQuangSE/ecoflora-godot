# Phase 4: Update Shop Service

**Depends on:** Phase 1 (CharacterConfig entity + IUnitOfWork.CharacterConfigs), Phase 2 (AdminShopService for reference patterns), Phase 3 (DI registration complete)

## Requirements

Remove hardcoded `CharacterPrices` dictionary from `ShopService` and replace with DB lookup via `IUnitOfWork.CharacterConfigs`.

## Backward Compat Note

Godot client expects **HTTP 400** for missing/invalid character. Phase 4 keeps the same 400 error code to avoid breaking the Godot purchase flow. Admin FE docs (Phase 5) still get 404 from the admin PATCH endpoint (different path).

## Steps

1. Open `Application/Services/ShopService.cs` lines 15–19. Remove the hardcoded `CharacterPrices` dictionary:
   ```csharp
   // REMOVE:
   private static readonly Dictionary<int, int> CharacterPrices = new() { [0] = 0, [1] = 10000 };
   ```

2. In `PurchaseCharacterAsync`, replace dictionary lookup with DB query:
   ```csharp
   var config = await _unitOfWork.CharacterConfigs.GetByCharacterIndexAsync(charIdx);
   if (config == null)
       return (null, new ApiError { StatusCode = 400, Message = "Character not found." }); // keep 400 for Godot backward compat
   var price = config.Price;
   ```
   - `HasQueryFilter` excludes soft-deleted configs automatically → null means "not found or deleted". No explicit `IsDeleted` check needed.

3. Validate `charIdx >= 0` before DB query — return HTTP 400 if negative:
   ```csharp
   if (charIdx < 0)
       return (null, new ApiError { StatusCode = 400, Message = "Invalid character index." });
   ```

4. Keep `GetCatalogAsync` unchanged for player endpoint — it already builds character entries correctly. Once CharacterConfig is in DB, update the character section to read from `_unitOfWork.CharacterConfigs` instead of whatever it currently does. Verify player still sees correct price.

5. Write unit tests:
   - Mock `IUnitOfWork.CharacterConfigs.GetByCharacterIndexAsync(1)` → returns config with Price=10000 → purchase deducts 10000
   - Mock returns null → returns HTTP 404
   - charIdx = -1 → returns HTTP 400
   - After admin changes price to 5000 (via mock), purchase deducts 5000

## Success Criteria

- `ShopService` has no `CharacterPrices` dictionary
- Character 0 purchase costs 0 (reads DB)
- Character 1 purchase costs 10000 (reads DB) — or whatever admin set via PATCH
- charIdx < 0 → HTTP 400
- charIdx not in DB → HTTP 400 (unchanged — Godot backward compat)
- Player-facing `GET /api/shop/items` continues working correctly

## Risks

- If `GetCatalogAsync` currently hardcodes character entries too (not from DB), it must also be updated to read from `CharacterConfigs` table — check before this phase.
- Godot client currently handles character purchase failure as 400 — must update error handling to accept 404.
