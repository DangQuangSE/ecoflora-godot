# Phase 01 — BE: Character Fields + Endpoints

**Goal:** Add `CharacterIndex` + `OwnedCharacterIndices` to User entity, expose in profile, add `PUT /api/auth/character`, extend Shop purchase for `character:N` items.

**Covers:** FR-04, FR-05 | **Dependencies:** None

---

## Files

| File | Change |
|------|--------|
| `Domain/Entities/User.cs` | +2 properties |
| `Application/DTOs/User/UserDto.cs` | +2 DTO fields |
| `Application/DTOs/Auth/UpdateCharacterIndexRequest.cs` | New |
| `Application/Interfaces/IUserService.cs` | +method signature |
| `Application/Services/UserService.cs` | Implement + mapper |
| `API/Controllers/AuthController.cs` | `PUT /api/auth/character` |
| `Application/DTOs/Shop/ShopReceiptDto.cs` | +`OwnedCharacters` |
| `Application/Services/ShopService.cs` | Handle `character:N` |
| `Infrastructure/Migrations/` | Generated via `dotnet ef` |

---

## Steps

**1. `User.cs`** — add after `AvatarIndex`:
```csharp
public int CharacterIndex { get; set; } = 0;
public string OwnedCharacterIndices { get; set; } = "[0]";
```

**2. `UserDto.cs`** — add:
```csharp
public int CharacterIndex { get; set; }
public List<int> OwnedCharacters { get; set; } = new();
```

**3. Mapping** — wherever `User→UserDto` is mapped (AutoMapper profile or manual), add:
```csharp
dto.CharacterIndex = user.CharacterIndex;
dto.OwnedCharacters = JsonSerializer.Deserialize<List<int>>(user.OwnedCharacterIndices)
    ?? new List<int> { 0 };
```
Wrap in try/catch returning `new List<int>{0}` on parse failure.

**4. `UpdateCharacterIndexRequest.cs`** (new):
```csharp
public class UpdateCharacterIndexRequest { public int CharacterIndex { get; set; } }
```

**5. `IUserService.cs`** — add:
```csharp
Task<(ApiResponse<UserDto>? Success, ApiError? Error)> UpdateCharacterIndexAsync(string userId, UpdateCharacterIndexRequest request);
```

**6. `UserService.cs`** — mirror `UpdateAvatarIndexAsync`:
- Guid parse → GetByIdAsync → set `user.CharacterIndex` → Update → CommitAsync → return mapped UserDto

**7. `AuthController.cs`** — add `[HttpPut("character")]` endpoint, mirror `UpdateAvatarIndex` action exactly, call `UpdateCharacterIndexAsync`.

**8. `ShopReceiptDto.cs`** — add:
```csharp
public List<int>? OwnedCharacters { get; set; }
```

**9. `ShopService.PurchaseAsync`** — add branch before normal inventory path:
```
if itemId starts with "character:" →
  parse charIdx (0 or 1 only, else 400)
  load user → check currency >= 10000 (else 400)
  parse OwnedCharacterIndices → if contains charIdx → 400 "Đã sở hữu"
  append charIdx → serialize back → user.Currency -= 10000
  Update + CommitAsync
  return ShopReceiptDto { RemainingCurrency, OwnedCharacters = updated list }
```

**10. Migration:**
```bash
dotnet ef migrations add AddCharacterFields --project Infrastructure --startup-project API
dotnet ef database update --project Infrastructure --startup-project API
```

---

## Acceptance Check

- `GET /api/auth/profile` → `characterIndex: 0`, `ownedCharacters: [0]` for existing users
- `PUT /api/auth/character {"characterIndex":0}` → 200
- `POST /api/shop/purchase {"itemId":"character:1","quantity":1}` → deducts 10000, returns `ownedCharacters:[0,1]`
- Duplicate purchase → 400; insufficient coin → 400
