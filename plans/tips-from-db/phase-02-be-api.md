# Phase 2: Backend API — GameTips CRUD + Public List

testing: default

## Layer

`eco-backend`: Application → API

## Files

| File | Layer | Action |
|------|-------|--------|
| `Application/DTOs/GameTip/GameTipDto.cs` | Application | CREATE |
| `Application/DTOs/GameTip/AddGameTipRequest.cs` | Application | CREATE |
| `Application/DTOs/GameTip/UpdateGameTipRequest.cs` | Application | CREATE |
| `Application/DTOs/GameTip/GameTipQueryParameters.cs` | Application | CREATE |
| `Application/Interfaces/IGameTipService.cs` | Application | CREATE |
| `Application/Services/GameTipService.cs` | Application | CREATE |
| `Application/Mapper/MappingProfile.cs` | Application | MODIFY |
| `API/Controllers/GameTipsController.cs` | API | CREATE |
| `API/FluentValidation/AddGameTipValidator.cs` | Application | CREATE |
| `API/FluentValidation/UpdateGameTipValidator.cs` | API | CREATE |
| `API/Program.cs` | API | MODIFY |
| `docs/tips-from-db/admin-api.md` | Docs | CREATE |

## Requirements

P1-1, P1-2: CRUD admin + GET public flat list (không nested guidebook endpoint).

## Steps

1. DTOs: `GameTipDto` (`Id`, `Title`, `Content`, `SortOrder`, `IsActive`).

2. `IGameTipService`:
   - `GetAllAsync(query)` — public list, filter `IsActive` mặc định true cho anonymous GET
   - `GetByIdAsync`, `AddAsync`, `UpdateAsync`, `DeleteAsync` (soft)

3. Validators: `Title` required max 100, `Content` required max 3000, `SortOrder >= 0`.

4. `GameTipsController` — mirror `ItemsController`:
   - GET `[AllowAnonymous]`
   - POST/PUT/DELETE `[Authorize(Roles = "Admin,SuperAdmin")]`

5. DI + `admin-api.md` (Swagger workflow).

## Success Criteria

- `GET /api/game-tips` → array flat
- Admin POST tip thứ 2 → GET trả 2 items sorted
- FluentValidation 400 on empty content

## Risks

- Route `/api/gametips` theo convention controller name — document trong admin-api
