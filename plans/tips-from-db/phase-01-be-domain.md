# Phase 1: Backend Domain — GameTip (flat)

testing: default

## Layer

`eco-backend`: Domain → Infrastructure

## Files

| File | Layer | Action |
|------|-------|--------|
| `Domain/Entities/GameTip.cs` | Domain | CREATE |
| `Domain/Repositories/IGameTipRepository.cs` | Domain | CREATE |
| `Domain/Repositories/IUnitOfWork.cs` | Domain | MODIFY |
| `Infrastructure/Data/AppDbContext.cs` | Infrastructure | MODIFY |
| `Infrastructure/Repositories/GameTipRepository.cs` | Infrastructure | CREATE |
| `Infrastructure/Repositories/UnitOfWork.cs` | Infrastructure | MODIFY |
| `Infrastructure/Migrations/{ts}_GameTips.cs` | Infrastructure | CREATE |
| `Infrastructure/Data/Seeder.cs` | Infrastructure | MODIFY |

## Requirements

P1-3, P1-4: **Một bảng** `GameTips` — không có `TipCategory`.

## Steps

1. `GameTip` entity (`BaseEntity`):
   - `Id`, `Title`, `Content`, `SortOrder`, `IsActive`

2. `IGameTipRepository` + implementation:
   - Generic CRUD
   - `GetActiveOrderedAsync()` → active tips, `OrderBy SortOrder`

3. Migration + `UnitOfWork` registration.

4. **Seeder** (idempotent — skip nếu đã có tip title "Hệ Sinh Thái"):
   - Gộp 5 mẹo synergy từ `TipCatalog.gd` thành **một** `Content` paragraph (tiếng Việt, dễ đọc, ~3–5 câu)
   - `Title = "Hệ Sinh Thái"`, `SortOrder = 0`
   - Stable Guid → `docs/tips-from-db/seed-ids.md`

## Success Criteria

- Fresh DB: 1 row trong `GameTips`
- `dotnet build` pass
- Không bảng category

## Risks

- Nội dung gộp cần review copy — seeder dùng bản draft, admin sửa qua Swagger sau
