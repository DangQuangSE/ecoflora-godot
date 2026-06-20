# Phase 2: Application — DTOs + service methods with FR-03 validation

**Layer:** Application

**Satisfies:** P1 stories #1, #2, #3 and P2 story (qty/itemId consistency rule).

## Requirements
Add the admin-facing DTOs and two new `IDailyTaskService` methods: one to list all task definitions with reward fields (read-only projection), one to validate and persist a reward-only update by id. Validation must exactly match FR-03: `RewardCurrency >= 0`, `RewardXP >= 0`, `RewardItemId` (if non-null) must exist in `Items`, `RewardItemQty > 0` when `RewardItemId` is set, `RewardItemQty` forced to `0` when `RewardItemId` is null.

## Files

| File | Layer | Change |
|---|---|---|
| `D:\GitHub\eco-backend\Application\DTOs\DailyTask\DailyTaskAdminDto.cs` | Application (DTO) | New file |
| `D:\GitHub\eco-backend\Application\DTOs\DailyTask\UpdateDailyTaskRewardRequest.cs` | Application (DTO) | New file |
| `D:\GitHub\eco-backend\Application\Interfaces\IDailyTaskService.cs` | Application (interface) | Add `GetAdminTaskListAsync` and `UpdateTaskRewardAsync` signatures |
| `D:\GitHub\eco-backend\Application\Services\DailyTaskService.cs` | Application | Implement both methods + a private mapper |
| `D:\GitHub\eco-backend\Application\Helpers\Constant.cs` | Application | Add 3 new error message constants under `Constant.Error` |

## Steps

1. Create `DailyTaskAdminDto.cs` mirroring the existing `DailyTaskDto.cs` shape but adding `IsActive` (per FR-01 field list: id, title, description, type, actionSubtype, target, cycle, isActive, rewardCurrency, rewardXP, rewardItemId, rewardItemQty):
   ```csharp
   namespace Application.DTOs.DailyTask
   {
       public class DailyTaskAdminDto
       {
           public string Id { get; set; } = string.Empty;
           public string Title { get; set; } = string.Empty;
           public string Description { get; set; } = string.Empty;
           public string Type { get; set; } = string.Empty;
           public string? ActionSubtype { get; set; }
           public int Target { get; set; }
           public string Cycle { get; set; } = string.Empty;
           public bool IsActive { get; set; }
           public int RewardCurrency { get; set; }
           public string? RewardItemId { get; set; }
           public int RewardItemQty { get; set; }
           public int RewardXP { get; set; }
       }
   }
   ```

2. Create `UpdateDailyTaskRewardRequest.cs` with exactly the 4 reward fields named to match FR-02 (PascalCase property names, `RewardItemId` nullable `Guid?` so a request omitting it or sending `null` clears the item):
   ```csharp
   namespace Application.DTOs.DailyTask
   {
       public class UpdateDailyTaskRewardRequest
       {
           public int RewardCurrency { get; set; }
           public int RewardXP { get; set; }
           public Guid? RewardItemId { get; set; }
           public int RewardItemQty { get; set; }
       }
   }
   ```

3. Add 3 new constants to `Constant.Error` in `Constant.cs` (place alphabetically near other `RewardX`/`Item`-prefixed entries, Vietnamese message text matching existing style):
   ```csharp
   public const string RewardCurrencyMustBeNonNegative = "RewardCurrency phải lớn hơn hoặc bằng 0.";
   public const string RewardXpMustBeNonNegative = "RewardXP phải lớn hơn hoặc bằng 0.";
   public const string RewardItemIdNotFound = "RewardItemId không tồn tại trong danh sách vật phẩm.";
   public const string RewardItemQtyMustBePositiveWhenItemSet = "RewardItemQty phải lớn hơn 0 khi đã chọn RewardItemId.";
   public const string DailyTaskNotFound = "Không tìm thấy nhiệm vụ.";
   ```

4. In `IDailyTaskService.cs`, add two signatures below the existing ones:
   ```csharp
   Task<ApiResponse<List<DailyTaskAdminDto>>> GetAdminTaskListAsync();
   Task<(ApiResponse<DailyTaskAdminDto>? Success, ApiError? Error)> UpdateTaskRewardAsync(Guid id, UpdateDailyTaskRewardRequest request);
   ```

5. In `DailyTaskService.cs`, implement `GetAdminTaskListAsync()`:
   ```csharp
   public async Task<ApiResponse<List<DailyTaskAdminDto>>> GetAdminTaskListAsync()
   {
       var tasks = await _taskRepo.GetAllTaskDefinitionsAsync();
       return ApiResponse<List<DailyTaskAdminDto>>.Create(tasks.Select(MapToAdminDto).ToList());
   }
   ```
   Add the private mapper `MapToAdminDto` alongside the existing `MapToDto`/`MapProgressToDto`, projecting all fields listed in FR-01 including `IsActive = t.IsActive`.

6. In `DailyTaskService.cs`, implement `UpdateTaskRewardAsync(Guid id, UpdateDailyTaskRewardRequest request)` enforcing FR-03 in this exact order — return the first validation failure encountered, do not save partial state:
   - Look up the task via `_taskRepo` (reuse `GetDefinitionByIdAsync`? — **no**, that method filters `IsActive`-only and would 404 on inactive tasks the admin is allowed to edit; instead add a lookup using `GetAllTaskDefinitionsAsync()` filtered by id in-memory, OR add a new unfiltered single-row lookup. Use the unfiltered `GetAllTaskDefinitionsAsync()` result filtered by `t.Id == id` for this phase to avoid adding a third repository method — acceptable given list size is ~8 rows).
   - If not found: `return (null, ApiError.Create(404, Constant.Error.DailyTaskNotFound));`
   - If `request.RewardCurrency < 0`: `return (null, ApiError.Create(400, Constant.Error.RewardCurrencyMustBeNonNegative));`
   - If `request.RewardXP < 0`: `return (null, ApiError.Create(400, Constant.Error.RewardXpMustBeNonNegative));`
   - If `request.RewardItemId.HasValue`:
     - look up `await _unitOfWork.Items.GetByIdAsync(request.RewardItemId.Value)`; if `null`, `return (null, ApiError.Create(400, Constant.Error.RewardItemIdNotFound));`
     - if `request.RewardItemQty <= 0`, `return (null, ApiError.Create(400, Constant.Error.RewardItemQtyMustBePositiveWhenItemSet));`
   - Apply mutation: set `task.RewardCurrency = request.RewardCurrency`, `task.RewardXP = request.RewardXP`, `task.RewardItemId = request.RewardItemId`, `task.RewardItemQty = request.RewardItemId.HasValue ? request.RewardItemQty : 0` (forced-to-zero rule, per FR-03 and P2 story).
   - Do **not** touch `Title`, `Description`, `Type`, `ActionSubtype`, `Target`, `Cycle`, or `IsActive` (Out of Scope).
   - Persist via `_taskRepo.SaveChangesAsync()` (matches the repository's existing `SaveChangesAsync()`-based pattern, not `_unitOfWork.CommitAsync()`, since `DailyTaskRepository` writes go through `AppDbContext` directly elsewhere in this service — confirm this is consistent before committing; if `DailyTaskDefinition` is not tracked via `_unitOfWork` elsewhere, use `_taskRepo.SaveChangesAsync()` for symmetry with `IncrementProgressAsync`).
   - Return `(ApiResponse<DailyTaskAdminDto>.Create(MapToAdminDto(task)), null)`.

7. Build the `Application` project and confirm no nullable-reference or signature warnings on the two new interface methods.

## Success Criteria
- `dotnet build` succeeds for `Application` project.
- Unit/manual check: calling `GetAdminTaskListAsync()` against seeded data returns 8 `DailyTaskAdminDto` rows with `isActive` populated correctly for any seed row currently set inactive.
- Unit/manual check: calling `UpdateTaskRewardAsync` with `RewardCurrency = -1` returns a 400 `ApiError` with `Constant.Error.RewardCurrencyMustBeNonNegative` and does not mutate the row.
- Unit/manual check: calling `UpdateTaskRewardAsync` with a random non-existent `RewardItemId` GUID returns 400 with `Constant.Error.RewardItemIdNotFound` and does not mutate the row.
- Unit/manual check: calling `UpdateTaskRewardAsync` with a valid `RewardItemId` and `RewardItemQty = 0` returns 400 with `Constant.Error.RewardItemQtyMustBePositiveWhenItemSet`.
- Unit/manual check: calling `UpdateTaskRewardAsync` with `RewardItemId = null` and `RewardItemQty = 5` in the request persists `RewardItemQty = 0` (forced), not `5`.
- Unit/manual check: calling `UpdateTaskRewardAsync` with a valid id and a non-existent task id (random GUID) returns 404 with `Constant.Error.DailyTaskNotFound`.

## Risks
- ~~Picking the wrong persistence call~~ — **Resolved during plan validation:** confirmed `DailyTaskRepository` (`_db`) and `UnitOfWork` (`_context`) both inject `AppDbContext` directly and both are registered `Scoped` (`Program.cs:122,154,185`), so within one request they resolve to the same tracked `AppDbContext` instance. `_taskRepo.SaveChangesAsync()` is safe and consistent with `IncrementProgressAsync`'s existing pattern — no further verification needed in Phase 2 implementation.
- Reusing `GetAllTaskDefinitionsAsync()` + in-memory filter for the single-row lookup in `UpdateTaskRewardAsync` is less efficient than a dedicated `GetByIdIncludingInactiveAsync(Guid id)`: acceptable for this dataset size (~8 rows) per spec's NFR (single-row lookup, p95 < 200ms); flagged here so a future dedicated method can replace it if the task table grows significantly.
