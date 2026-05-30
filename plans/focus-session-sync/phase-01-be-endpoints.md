# Phase 1: BE Endpoints

## Layer
Backend — `eco-backend` (.NET 8, Clean Architecture)

## Files

| File | Status | Layer | Purpose |
|------|--------|-------|---------|
| `Application/DTOs/FocusSession/FocusSessionDto.cs` | New | Application | Response DTO returned to client |
| `Application/DTOs/FocusSession/CreateFocusSessionRequest.cs` | New | Application | Body for POST /api/focus-sessions |
| `Application/DTOs/FocusSession/UpdateFocusSessionRequest.cs` | New | Application | Body for PATCH complete/fail (carries strikes) |
| `API/FluentValidation/CreateFocusSessionRequestValidator.cs` | New | API | Validates targetDuration ≥ 1 |
| `API/FluentValidation/UpdateFocusSessionRequestValidator.cs` | New | API | Validates strikes ≥ 0 |
| `Domain/Repositories/IFocusSessionRepository.cs` | New | Domain | Repository contract (extends IGenericRepository) |
| `Infrastructure/Repositories/FocusSessionRepository.cs` | New | Infrastructure | EF Core implementation |
| `Domain/Repositories/IUnitOfWork.cs` | Modify | Domain | Add `IFocusSessionRepository FocusSessions` property |
| `Infrastructure/Repositories/UnitOfWork.cs` | Modify | Infrastructure | Wire `FocusSessionRepository` into constructor |
| `Application/Interfaces/IFocusSessionService.cs` | New | Application | Service contract |
| `Application/Services/FocusSessionService.cs` | New | Application | Business logic implementation |
| `API/Controllers/FocusSessionsController.cs` | New | API | HTTP surface (3 endpoints) |
| `Application/Mapper/MappingProfile.cs` | Modify | Application | Add FocusSession → FocusSessionDto mapping |
| `API/Program.cs` | Modify | API | Register service + validators in DI |

## Requirements
Expose three authenticated endpoints under `/api/focus-sessions` that create a session on start
and transition it to COMPLETED or FAILED on end. All endpoints require a valid Player JWT.

## Steps

1. Create `FocusSessionDto` with fields `id` (Guid), `startTime` (DateTime), `targetDuration` (int),
   `strikes` (int), `status` (string). Create `CreateFocusSessionRequest` with a single required
   `targetDuration: int` field (minutes, minimum 1). Create `UpdateFocusSessionRequest` with a
   single required `strikes: int` field (minimum 0).

2. Define `IFocusSessionService` with three method signatures matching the three endpoints:
   create (returns FocusSessionDto), complete (returns FocusSessionDto), fail (returns
   FocusSessionDto). All return `(ApiResponse<FocusSessionDto>? Success, ApiError? Error)` tuples
   following the project-wide convention.

3. Add `IFocusSessionRepository` to `Domain/Repositories/` extending `IGenericRepository<FocusSession>`.
   Add `IFocusSessionRepository FocusSessions { get; }` property to `IUnitOfWork`. Implement
   `FocusSessionRepository : GenericRepository<FocusSession>` in `Infrastructure/Repositories/` and
   wire it into `UnitOfWork`'s constructor (following the exact same pattern as `IApiConfigRepository`).
   This keeps all persistence behind `IUnitOfWork.CommitAsync()` — consistent with every other service.

4. Implement `FocusSessionService`. Inject `IUnitOfWork`. For `CreateAsync`: resolve the caller's
   UserId from the passed-in string, build a new `FocusSession` entity (`TargetDuration`,
   `Status = IN_PROGRESS`, `StartTime = DateTime.UtcNow`), add via
   `_unitOfWork.FocusSessions.Add(entity)`, call `await _unitOfWork.CommitAsync()`, return the
   mapped DTO. For `CompleteAsync` / `FailAsync`: look up via `_unitOfWork.FocusSessions.GetByIdAsync`,
   verify it belongs to the caller's UserId (return 403 on mismatch), verify current status is
   IN_PROGRESS (return 400 otherwise), update `Strikes` and `Status`, commit, return mapped DTO.

4. Register the `FocusSession → FocusSessionDto` AutoMapper mapping in `MappingProfile.cs`.
   Map `Status` as `.ToString()` so the enum renders as a string in the JSON envelope.

5. Create `CreateFocusSessionRequestValidator` in `API/FluentValidation/`:
   `RuleFor(x => x.TargetDuration).GreaterThanOrEqualTo(1)`.
   Create `UpdateFocusSessionRequestValidator`:
   `RuleFor(x => x.Strikes).GreaterThanOrEqualTo(0)`.

6. Implement `FocusSessionsController`. Apply `[Authorize(Roles = Constant.Roles.Player)]` at the
   **class level** (not per-action — consistent with `GardenController` and `InventoryController`,
   so any future actions are protected by default). Three actions: `POST /api/focus-sessions`,
   `PATCH /api/focus-sessions/{id}/complete`, `PATCH /api/focus-sessions/{id}/fail`. All extract
   `userId` from `User.FindFirst("id")`, return 401 if missing, delegate to service, map error
   codes to HTTP status codes (400 → BadRequest, 403 → StatusCode(403), 404 → NotFound).

7. In `Program.cs`: register `AddScoped<IFocusSessionService, FocusSessionService>` and
   `AddTransient<IValidator<CreateFocusSessionRequest>, CreateFocusSessionRequestValidator>` and
   `AddTransient<IValidator<UpdateFocusSessionRequest>, UpdateFocusSessionRequestValidator>`.

## Success Criteria
- `dotnet build` in `eco-backend/` exits with zero errors and zero warnings related to the new files
- Swagger UI at `/swagger` shows `POST /api/focus-sessions`,
  `PATCH /api/focus-sessions/{id}/complete`, and `PATCH /api/focus-sessions/{id}/fail`
- A valid JWT for a Player user can call `POST /api/focus-sessions` with body
  `{ "targetDuration": 25 }` and receive HTTP 200 with `isSuccess: true` and a `data.id` GUID
- The same session id can then be PATCH'd to `/complete` with `{ "strikes": 0 }` and the
  response shows `status: "COMPLETED"`
- Calling PATCH with a session id belonging to a different user returns HTTP 403

## Risks
- Status enum stored as string in DB — already configured in `AppDbContext.OnModelCreating`
  (`HasConversion<string>()`), so no extra migration is required
- `UnitOfWork` constructor already takes all repositories as positional params — adding
  `IFocusSessionRepository` requires updating the constructor signature and the DI registration;
  follow the exact pattern used when `IApiConfigRepository` was added
