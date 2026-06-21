# Phase 1: Backend Dig-Up Endpoint & Service

## Requirements

Create a new POST endpoint in eco-backend's GardenController that digs up a planted flower, soft-deletes the PlantedFlower record, restores 1 seed to inventory, and returns the updated plot + seed item in the standard response envelope.

## Steps

1. **Add DigUpFlower controller action** — In `D:\GitHub\eco-backend\API\Controllers\GardenController.cs` (after line 91), add a new `[HttpPost("plots/{plotId}/dig-up")]` action method. Validate JWT authorization (already `[Authorize(Roles = Constant.Roles.Player)]` at class level), extract userId from `User.FindFirst("id")`, call `_gardenService.DigUpFlowerAsync(userId, plotId)`, and return standard ApiResponse/ApiError pattern matching HarvestFlower lines 75–91.

2. **Implement DigUpFlowerAsync service method** — In `D:\GitHub\eco-backend\Application\Services\GardenService.cs`, add `public async Task<(ApiResponse<DigUpRewardDto>? Success, ApiError? Error)> DigUpFlowerAsync(string userId, string plotId)`. Validate userId and plotId as GUIDs; fetch plot with flower **before** `BeginTransactionAsync` — corrected from the original plan text: direct inspection of `GardenService.cs` shows every existing mutation (Plant/Care/Harvest) fetches the plot row before opening the transaction, with no row-locking. Dig-up matches that established convention rather than introducing a unique locking strategy; the double-tap race is a pre-existing systemic risk profile, not something specific to this endpoint. Check ownership: `if (plot.Garden.UserId != userGuid) return ... 403` (reject when NOT equal — confirmed correct against the existing harvest check, this is not a typo). Verify plot is occupied via `plot.PlantedFlower == null` → 400 `PlotEmpty` (reusing the existing `Constant.Error.PlotEmpty`, same as CareForFlowerAsync/HarvestFlowerAsync).

3. **Define response DTO** — Create `DigUpRewardDto` with fields: `PlotId` (Guid), `ClearedFlowerTemplateId` (Guid), `NewSeedQuantity` (int — total seed count after restore). Simpler than originally planned: no nested `SeedReturned` object, since the client only needs the template id + resulting total.

4. **Implement transaction block** — Inside DigUpFlowerAsync, wrap in `_unitOfWork.BeginTransactionAsync()` … `CommitAsync()`. Within the transaction: (a) soft-delete the PlantedFlower (set `IsDeleted = true`, `DeletedAt = DateTime.UtcNow`); (b) clear the plot reference (`plot.PlantedFlowerId = null`); (c) inline upsert the seed inventory item (see step 5 — no new repository method needed).

5. **Corrected: no `UpsertSeedAsync` method, no Category field — inline upsert using existing public repository primitives.** Direct inspection of `Domain/Entities/InventoryItem.cs` confirms there is **no Category field on InventoryItem at all** — item type is disambiguated purely by which nullable FK is populated (`FlowerTemplateId` for seeds, `ItemId` for consumables, `DecorId` for decor). There is also no "HarvestProduct" inventory concept: `HarvestFlowerAsync` never touches inventory, it only grants XP/currency. `UpsertInventoryItemAsync` in `InventoryService.cs` is **private** and not exposed on `IInventoryRepository` — it cannot be called from `GardenService` and does not need a sibling method. Implemented instead as plain inline logic in `DigUpFlowerAsync` using already-public `IInventoryRepository` methods: `GetInventoryItemByFlowerTemplateIdAsync(inventory.Id, flowerTemplateId)` → if found, `item.Quantity += 1` + `UpdateInventoryItem(item)`; else construct a new `InventoryItem { InventoryId, FlowerTemplateId, Quantity = 1 }` + `AddInventoryItemAsync(item)`. Zero risk to other call sites since no shared code is touched.

6. **Build response DTO** — After commit succeeds (no extra re-fetch needed — values are already known from the upsert), construct `DigUpRewardDto` with `PlotId`, `ClearedFlowerTemplateId` (captured before soft-delete), and `NewSeedQuantity`. Return `ApiResponse<DigUpRewardDto>.Create(reward, Constant.Success.FlowerDugUp)` — new constant added to `Constant.Success`.

7. **Handle errors gracefully** — If plot not found → 404. If not owned by user → 403. If plot empty (no PlantedFlower) → 400. If transaction fails → 500. Match error codes and messages to existing pattern in HarvestFlowerAsync lines 224–280.

8. **No XP or currency mutation** — Unlike harvest, do NOT increment user.CurrentXP or user.Currency. Return only the plot and seed item in the response.

## Success Criteria

- Endpoint `POST /api/garden/plots/{plotId}/dig-up` exists and is decorated with `[Authorize(Roles = Constant.Roles.Player)]` (class-level) and `[HttpPost]`.
- Calling the endpoint with valid userId, plotId, and authorization header returns HTTP 200 with DigUpRewardDto payload.
- PlantedFlower record is marked IsDeleted = true; plot.PlantedFlowerId is set to null.
- InventoryItem for the flower template has quantity incremented by 1 (or created if absent).
- No user XP or currency changes occur.
- Error cases (404 plot not found, 403 unauthorized, 400 plot empty) return correct status codes and ApiError messages.
- Transaction rollback works: if the inline seed upsert throws, flower deletion and plot update are not committed (same atomicity guarantee as harvest).
- Inline seed-upsert logic touches only `InventoryItem` rows identified by `FlowerTemplateId`; no shared method (`UpsertInventoryItemAsync`, used by `BuyItemAsync`/`GrantItemAsync`) is modified, so those call sites are provably unaffected.

## Risks

- **Response DTO shape mismatch** — If DigUpRewardDto fields don't match Godot's JSON parsing assumptions. Mitigation: kept deliberately flat/minimal (PlotId, ClearedFlowerTemplateId, NewSeedQuantity); client reads fields defensively per Phase 3.
- **Soft-delete flag not honored in queries** — If subsequent queries still fetch deleted PlantedFlowers. Mitigation: Verify repository queries use `.Where(pf => !pf.IsDeleted)` filter already in place (check GetPlotByIdWithFlowerAsync).
- **Double-tap / duplicate request on same plot** — Two near-simultaneous dig-up requests for the same plot before either commits. Accepted as the same systemic risk profile as Plant/Care/Harvest (fetch-before-transaction, no row lock) — not a regression introduced by this phase; not fixed here, consistent with codebase convention.

## Build Verification

`dotnet build` at repo root (D:\GitHub\eco-backend) succeeded with 0 warnings / 0 errors after implementation.
