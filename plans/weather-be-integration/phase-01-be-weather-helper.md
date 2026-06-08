# Phase 1: BE — WeatherHelper OpenWeather Mapping

**Repo:** `eco-backend`  
**Layer:** Application  
**Depends on:** openweather-weather-api (already implemented)  
**Covers:** P1 rain/storm/day-night, P2 cloudy vs sunny accuracy

---

## Goal

Sửa `WeatherHelper.MapToDto()` để map OpenWeather `weather[0].main` (+ precipitation) sang 4 game condition strings, đồng bộ `isRaining`, luôn trả `sunrise`/`sunset` hợp lệ.

---

## Files

| File | Layer | Action |
|------|-------|--------|
| `Application/Helpers/WeatherHelper.cs` | Application | EDIT |
| `docs/weather-api.md` | docs | EDIT — bảng map 4 condition |
| `docs/weather-api-flow.md` | docs | EDIT — mục 7 cập nhật condition rules |

---

## Implementation Steps

### 1. Refactor `WeatherHelper.cs`

Thêm constants và helpers:

```csharp
private static readonly HashSet<string> StormMains = new(StringComparer.OrdinalIgnoreCase)
{
    "Thunderstorm", "Squall", "Tornado"
};

private static readonly HashSet<string> RainMains = new(StringComparer.OrdinalIgnoreCase)
{
    "Rain", "Drizzle"
};
```

Thêm `ResolveCondition(OpenWeatherApiResponse payload)` theo thứ tự:

1. `StormMains.Contains(main)` → `"storm"`
2. `main == "Snow"` → `"cloudy"` (game không có tuyết)
3. `RainMains.Contains(main)` **hoặc** `HasPrecipitation(payload.Rain)` → `"rainy"`
   - **Không** dùng `HasPrecipitation(payload.Snow)` cho rainy
4. `ConditionMap.TryGetValue(main)` → mapped value
5. Default → `"cloudy"` (Mist, Fog, Haze, Smoke, Dust, Sand, Ash, unknown)

Cập nhật `MapToDto`:

```csharp
var condition = ResolveCondition(payload);
return new WeatherDto
{
    IsDay     = ResolveIsDay(payload),
    IsRaining = condition is "rainy" or "storm",
    Condition = condition,
    Sunrise   = payload.Sys?.Sunrise ?? 0,
    Sunset    = payload.Sys?.Sunset  ?? 0,
};
```

Giữ nguyên `ResolveIsDay()` — đã đúng (sys sunrise/sunset + icon d/n fallback).

Xóa logic `ResolveIsRaining()` độc lập hoặc giữ private chỉ nếu cần — ưu tiên derive từ `condition`.

### 2. Mapping reference (implementer checklist)

| OWM Group | `main` | `condition` |
|-----------|--------|-------------|
| 800 | Clear | sunny |
| 80x | Clouds | cloudy |
| 3xx | Drizzle | rainy |
| 5xx | Rain | rainy |
| 2xx | Thunderstorm | storm |
| 6xx | Snow | cloudy |
| 7xx | Mist, Fog, Haze, Smoke, Dust, Sand, Ash | cloudy |
| 7xx | Squall, Tornado | storm |

Edge case: `main=Clouds` + `rain.1h > 0` → **rainy** (fix bug hiện tại).

### 3. Update docs

**`docs/weather-api.md`** — thêm bảng `condition` values + OpenWeather mapping; giữ `isDay`/`isRaining` là derived fields.

**`docs/weather-api-flow.md`** — mục 7: thay flow `isRaining`-only bằng `ResolveCondition` priority diagram.

### 4. Cache invalidation

Sau deploy, chạy một trong:

- `DELETE /api/weather/cache` (Admin JWT), hoặc
- Restart Redis / đợi TTL 600s

Cache cũ có thể thiếu field hoặc logic condition cũ.

---

## Verification

```bash
cd d:\FPT\8thSemester\EXE2\eco-backend
dotnet build eco-backend.sln
```

Swagger manual matrix (sau clear cache):

| Scenario | Expected `data.condition` | Expected `isRaining` |
|----------|---------------------------|------------------------|
| Clear + icon `01d` | sunny | false |
| Clouds | cloudy | false |
| Rain | rainy | true |
| Thunderstorm | storm | true |
| Clouds + rain object | rainy | true |
| Snow | cloudy | false |
| Mist/Fog | cloudy | false |

```bash
curl http://localhost:5000/api/weather/current
```

Response phải có đủ 5 fields trong `data`.

---

## Out of Scope

- Unit test project (không tồn tại trong solution)
- Thay đổi `WeatherDto` shape
- Snow/fog visual effects trong game
