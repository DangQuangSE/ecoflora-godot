# Phase 1: BE Login Streak + Avatar Index

## Layer
eco-backend — Domain, Application (DTOs + Service), Infrastructure (Migration), API (Controller)

## Files

| File Path | Layer | Change Type |
|-----------|-------|-------------|
| `Domain/Entities/User.cs` | Domain | modify |
| `Application/DTOs/User/UserDto.cs` | Application | modify |
| `Application/DTOs/Auth/UpdateAvatarIndexRequest.cs` | Application | add |
| `Application/Interfaces/IUserService.cs` | Application | modify |
| `Application/Services/UserService.cs` | Application | modify |
| `API/Controllers/AuthController.cs` | API | modify |
| `Infrastructure/Migrations/<timestamp>_PlayerProfile.cs` | Infrastructure | add |

## Tasks

1. **Add three new fields to `User.cs`**
   - `public int LoginStreak { get; set; } = 0;`
   - `[ConcurrencyCheck] public DateTime? LastLoginDate { get; set; } = null;`
   - `public int AvatarIndex { get; set; } = 0;`
   - Place after `VitalityReadyAt`, following the same nullable DateTime? pattern already established.
   - `[ConcurrencyCheck]` on `LastLoginDate` causes EF to add it to the `WHERE` clause on update — if two concurrent profile fetches both try to increment the streak, the second will get `DbUpdateConcurrencyException`; catch it and treat as no-op (streak already updated by the first request).

2. **Extend `UserDto.cs`** to mirror the three new User entity fields:
   - `public int LoginStreak { get; set; }`
   - `public DateTime? LastLoginDate { get; set; }`
   - `public int AvatarIndex { get; set; }`
   - AutoMapper will pick these up automatically if property names match.

3. **Add streak update logic inside `UserService.GetProfileAsync()`**
   - After fetching the user entity, compare `user.LastLoginDate?.Date` against `DateTime.UtcNow.Date`.
   - If `LastLoginDate` is null or more than 1 day ago (not yesterday): set `LoginStreak = 1`.
   - If `LastLoginDate.Date == DateTime.UtcNow.Date.AddDays(-1)` (yesterday): increment `LoginStreak`.
   - If `LastLoginDate.Date == DateTime.UtcNow.Date` (today already updated): leave both fields unchanged and skip the commit.
   - When a write is needed: set `LastLoginDate = DateTime.UtcNow`, call `_unitOfWork.Users.Update(user)`, and `await _unitOfWork.CommitAsync()`.

4. **Create `UpdateAvatarIndexRequest.cs`** DTO:
   ```csharp
   public class UpdateAvatarIndexRequest {
       [Range(0, 5, ErrorMessage = "AvatarIndex must be between 0 and 5")]
       public int AvatarIndex { get; set; }
   }
   ```
   The `[Range(0, 5)]` annotation causes `[ApiController]` to return HTTP 400 automatically for values outside range — no manual validation needed in the service.

5. **Add `UpdateAvatarIndexAsync(string userId, UpdateAvatarIndexRequest request)` to `IUserService`** with the same tuple-return signature as existing methods. Implement in `UserService`: fetch user, set `user.AvatarIndex = request.AvatarIndex` (no clamping — [Range] already rejected invalid values), persist. Return error tuple if user not found.

6. **Add `PUT /api/auth/avatar-index` endpoint to `AuthController`** — `[Authorize(Roles = "Player")]`, extracts userId from JWT claim "id", calls `_userService.UpdateAvatarIndexAsync()`, returns 200 `ApiResponse<UserDto>` or appropriate error status.

7. **Generate and apply EF Core migration** named `PlayerProfile` — run `dotnet ef migrations add PlayerProfile` in the Infrastructure project, verify the generated migration creates three nullable/defaulted columns on the `Users` table, then run `dotnet ef database update`.

## Acceptance
- `GET /api/auth/profile` (with valid Player JWT) returns JSON containing `loginStreak`, `lastLoginDate`, and `avatarIndex` fields.
- Calling `GET /api/auth/profile` twice on the same UTC day returns the same `loginStreak` (idempotent).
- Calling `GET /api/auth/profile` after manually setting `LastLoginDate` to yesterday in the DB returns `loginStreak` incremented by 1.
- `PUT /api/auth/avatar-index` with body `{"avatarIndex": 3}` returns 200 and `GET /api/auth/profile` subsequently returns `avatarIndex: 3`.
- `PUT /api/auth/avatar-index` with `avatarIndex: 99` returns 400.
- `dotnet ef migrations list` shows `PlayerProfile` as applied.
