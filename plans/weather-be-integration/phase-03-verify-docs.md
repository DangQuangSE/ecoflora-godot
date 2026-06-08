# Phase 3: Verify, Docs & Spec Resolution

**Repos:** `eco-backend` + `ecoflora-godot`  
**Layer:** docs + cross-repo verification  
**Depends on:** Phase 1 + Phase 2

---

## Goal

Xác nhận end-to-end BE→Godot hoạt động; cập nhật tài liệu; đóng `[NEEDS CLARIFICATION]` trong weather-sync spec.

---

## Files

| File | Action |
|------|--------|
| `ecoflora-godot/plans/weather-sync/spec.md` | EDIT — resolve clarification, check success criteria |
| `ecoflora-godot/docs/weather-sync/godot_implement.md` | EDIT — real API setup steps |
| `eco-backend/docs/weather-api.md` | VERIFY (updated in Phase 1) |

---

## End-to-End Smoke Test Checklist

### Backend

- [ ] `dotnet build eco-backend.sln` — 0 errors
- [ ] BE running with valid `OPENWEATHER_API_KEY` + Redis
- [ ] `GET /api/weather/current` → 200, `data.condition` ∈ {sunny, cloudy, rainy, storm}
- [ ] `data.sunrise` > 0, `data.sunset` > sunrise
- [ ] `isRaining` === true iff condition ∈ {rainy, storm}

### Godot

- [ ] `godot --headless --check-only --script res://autoloads/WeatherManager.gd` — no errors
- [ ] `use_mock = false`, endpoint auto-resolved
- [ ] Game starts without WeatherService parse warnings
- [ ] `WeatherManager.get_current_state()` returns non-null with valid condition
- [ ] Visual: overlay/particles match condition (RAINY → rain, STORM → rain+wind)
- [ ] Scene change (Garden → Shop) → weather overlay persists

### Integration

- [ ] BE cache cleared after Phase 1 deploy
- [ ] Godot poll (wait 10 min or temporarily lower `POLL_INTERVAL_SEC` for test) updates state

---

## Spec Updates

In `plans/weather-sync/spec.md`:

1. Resolve `[NEEDS CLARIFICATION]` — document exact JSON contract (link to `weather-be-integration/plan.md`)
2. Mark applicable success criteria `[x]` if verified
3. Remove out-of-scope note "Backend implementation của weather API" — now in scope

---

## Godot Editor Guide Updates (`docs/weather-sync/godot_implement.md`)

Add section **"Kết nối API thật (BE)"**:

1. Đảm bảo BE chạy + OpenWeather key valid
2. Remote Inspector → `WeatherManager`:
   - `Use Mock` = **false**
   - `Weather Endpoint` = **để trống** (auto dùng `UserManager.base_url`)
3. Kiểm tra Output — không có `parse_response` warnings
4. Troubleshooting row: parse fail → kiểm tra BE response format, cache cũ

Update Inspector table: `Use Mock` default note, `Weather Endpoint` optional override.

---

## Optional Future Work (NOT in this cook)

- Godot automated test script mocking HTTP response
- BE xUnit tests for `WeatherHelper.ResolveCondition`
- `@export var use_mock = false` when BE always available
- Snow/fog dedicated game conditions
