# Phase 2: BE Sync — Mirror Diversity Rule (External Repo)

## Layer
`eco-backend` — Application helpers (ngoài workspace Godot)

## Files

| File | Layer | Action |
|------|-------|--------|
| `Application/Helpers/SynergyEvaluator.cs` | Application | Edit |
| `Tests/.../SynergyEvaluatorTests.cs` | Tests | Edit (nếu có) |

## Stories
P1-3

## Requirements

Mirror Godot `evaluate_zone` rule:

1. ≥ 2 occupied plots
2. All same non-empty `SynergyId`
3. **≥ 2 distinct `FlowerTemplateId`** among occupied flowers

## Steps

1. Mở `SynergyEvaluator.EvaluateZone` trong eco-backend.
2. Sau purity check, đếm distinct `FlowerTemplateId` → `< 2` return inactive.
3. Cập nhật unit tests tương tự Phase 1.
4. `dotnet test` + Swagger care trên zone 2 loài cùng synergy.

## Verification

```bash
dotnet build eco-backend.sln
dotnet test --filter SynergyEvaluator
```

## Acceptance

- [ ] BE bonus khớp Godot evaluator cho mọi edge case trong spec
- [ ] `CareResponseDto.synergyBonusXp` = 0 khi chỉ 1 loài

## Notes

Phase này **không block** Godot cook — nhưng cần làm trước release BE mode.
