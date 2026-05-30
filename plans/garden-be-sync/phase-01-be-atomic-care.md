# Phase 1: BE Atomic Care

## Layer
`Application/Services/` (business logic) + `Domain/Repositories/` (interface) + `Infrastructure/Repositories/` (EF Core implementation)
Files live in the separate BE repo at `d:\WorkWithCorn\eco-backend\`.

## Files

| File | Layer | Change |
|---|---|---|
| `Domain/Repositories/IInventoryRepository.cs` | Domain | Add `DecrementQuantityIfPositiveAsync` signature |
| `Infrastructure/Repositories/InventoryRepository.cs` | Infrastructure | Implement with EF Core `ExecuteUpdateAsync` WHERE Quantity > 0 |
| `Application/Services/GardenService.cs` — CareForFlowerAsync | Application | Delete cooldown block; replace `careItem.Quantity--` with atomic call |
| `Application/Services/GardenService.cs` — PlantFlowerAsync | Application | Replace `seedItem.Quantity--` with atomic call |
| `Application/DTOs/Garden/HarvestRewardDto.cs` | Application | Add `NewXpTotal` field to harvest response |
| `Application/Services/GardenService.cs` — HarvestFlowerAsync | Application | Compute `newXpTotal` from profile and include in response |

## Requirements
BE inventory decrements for care and plant actions must be atomic at the database level so that
concurrent requests from multiple client sessions can never drive item quantity below zero.
The cooldown gate in `CareForFlowerAsync` is removed entirely — care is unrestricted per the spec.

## Steps

1. **Add the atomic-decrement method signature to the inventory repository interface.**
   In `IInventoryRepository.cs`, add one new method declaration:
   `Task<int> DecrementQuantityIfPositiveAsync(Guid inventoryItemId)`.
   This method returns the number of database rows affected (1 = success, 0 = qty was already 0).

2. **Implement the atomic decrement in `InventoryRepository.cs`.**
   Add the method body using EF Core's `ExecuteUpdateAsync` on the `InventoryItems` DbSet.
   The WHERE clause filters on `Id == inventoryItemId AND Quantity > 0`.
   The SET clause does `Quantity = Quantity - 1`.
   Return the integer result of `ExecuteUpdateAsync` directly — no additional query needed.
   Example:
   ```csharp
   public async Task<int> DecrementQuantityIfPositiveAsync(Guid inventoryItemId)
   {
       return await _context.InventoryItems
           .Where(ii => ii.Id == inventoryItemId && ii.Quantity > 0)
           .ExecuteUpdateAsync(s => s.SetProperty(ii => ii.Quantity, ii => ii.Quantity - 1));
   }
   ```

3. **Remove the cooldown check block from `CareForFlowerAsync`.**
   Delete the `lastCareAt` switch expression (lines ~133–139 in current file) and the entire
   `if (lastCareAt.HasValue) { ... }` block (lines ~141–146). The `LastWateredAt / LastFertilizedAt
   / LastPesticideAt` timestamp writes below it remain — keep those for analytics. No other logic
   changes in this step.

4. **Replace the race-condition decrement in `CareForFlowerAsync` with the atomic call.**
   Remove the two lines:
   ```
   careItem.Quantity--;
   if (careItem.Quantity <= 0)
       _unitOfWork.Inventories.DeleteInventoryItem(careItem);
   ```
   Replace with:
   ```csharp
   var affected = await _unitOfWork.Inventories.DecrementQuantityIfPositiveAsync(careItem.Id);
   if (affected == 0)
       return (null, ApiError.Create(400, Constant.Error.InsufficientItem));
   careItem.Quantity -= 1; // sync in-memory entity so RemainingQuantity below is correct
   ```
   The `BeginTransactionAsync` / `CommitAsync` wrapping the block remains unchanged.
   Note: do NOT call `DeleteInventoryItem` here — a quantity of 0 is still a valid row that the
   client uses to display "0 remaining". Deletion is a separate concern.

5. **Apply the same atomic replacement to `PlantFlowerAsync`.**
   In `PlantFlowerAsync`, find the equivalent read-then-write block:
   ```
   seedItem.Quantity--;
   if (seedItem.Quantity <= 0)
       _unitOfWork.Inventories.DeleteInventoryItem(seedItem);
   ```
   Replace with:
   ```csharp
   var seedAffected = await _unitOfWork.Inventories.DecrementQuantityIfPositiveAsync(seedItem.Id);
   if (seedAffected == 0)
       return (null, ApiError.Create(400, Constant.Error.FlowerTemplateNotInInventory));
   seedItem.Quantity -= 1;
   ```
   The rest of `PlantFlowerAsync` (flower creation, plot assignment, CommitAsync) is unchanged.

6. **Add `NewXpTotal` to harvest response.**
   In `Application/DTOs/Garden/HarvestRewardDto.cs` (or equivalent harvest response DTO), add:
   ```csharp
   public int NewXpTotal { get; set; }
   ```
   In `HarvestFlowerAsync`, after committing the harvest, read the player's updated `currentXp`
   from the user profile and populate the field:
   ```csharp
   var updatedUser = await _unitOfWork.Users.GetByIdAsync(userId);
   reward.NewXpTotal = updatedUser?.CurrentXp ?? 0;
   ```
   Godot reads this field from the harvest response body to update the XP bar immediately —
   no extra `fetch_profile_async()` call needed.

6. **Verify the `RemainingQuantity` field in `CareResponseDto` is populated correctly.**
   After step 4, `careItem.Quantity` is now the post-decrement value (we manually subtracted 1).
   Confirm the response construction line `RemainingQuantity = careItem.Quantity` still reads
   from the in-memory entity — it does. No change needed, but verify during code review that it
   reads the manually-updated field and not a re-queried entity.

## Success Criteria
- Sending 3 simultaneous POST `/api/garden/plots/{id}/care` requests for a plot whose item qty = 1
  results in exactly 1 HTTP 200 and 2 HTTP 400 responses with body containing `InsufficientItem`.
- Inventory row quantity never goes below 0 in the database after concurrent requests.
- POST `/api/garden/plots/{id}/care` with no cooldown restriction returns 200 immediately after
  a previous successful care call on the same plot.
- POST `/api/garden/plots/{id}/plant` with item qty = 1 under concurrent load results in exactly
  1 success and remaining requests receiving 400.

## Risks
- `ExecuteUpdateAsync` bypasses the EF change tracker — the in-memory `careItem.Quantity` is
  stale after the call. Mitigation: manually subtract 1 in code immediately after the call
  (step 4 above). If this is missed, `RemainingQuantity` in the response will be off by 1.
- `ExecuteUpdateAsync` runs outside the `BeginTransactionAsync` scope if called before it.
  Mitigation: confirm the atomic call is placed AFTER `await _unitOfWork.BeginTransactionAsync()`
  in both methods — it is, per the step ordering above.

## Testing
testing: skipped (--no-test mode)

## Story Coverage
- P1: care/plant actions now guaranteed safe under concurrent load
- P3: `RemainingQuantity` in care response is authoritative — Godot uses it to overwrite local qty
