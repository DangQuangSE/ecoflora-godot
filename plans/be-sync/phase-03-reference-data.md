# Phase 3: Reference Data

## Layer
`services/` (ReferenceDataService) + `autoloads/GardenManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/ReferenceDataService.gd` | services | New |
| `autoloads/GardenManager.gd` | autoloads | Modify |

## Requirements
On game boot, fetch the FlowerTemplate, Item, and Synergy catalogs from BE and cache them in
GardenManager so the game never uses hardcoded template data when `use_mock = false`. If any
fetch fails, fall back to mock data and continue — the game must not crash or block.

## Steps
1. Create `ReferenceDataService` (RefCounted, services layer). Add `parse_flower_templates(arr: Array)`
   that iterates the BE array and maps each `FlowerTemplateDto` JSON object
   (`id`, `name`, `base_price`, `image_url`, `synergy_id`) to a `FlowerTemplate` domain object.
   Note: BE `FlowerTemplateDto` does not include stage data — set an empty `stages` array and
   push_warning so the gap is visible during development.

2. Add `parse_items(arr: Array)` to `ReferenceDataService` that maps each `ItemDto`
   (`id`, `name`, `price`, `image_url`, `cooldown_time`, `type`, `received_exp`) to a Dictionary
   keyed by id. Items are not yet surfaced to a domain class — store as raw Dictionary cache for
   now and document the TODO.

3. Add `parse_synergies(arr: Array)` to `ReferenceDataService` that maps each `SynergyDto`
   (`id`, `name`, `xp_plus`, `cooldown_minus`) to a Dictionary cache. The embedded
   `flower_templates` array inside each SynergyDto can be ignored until the synergy gameplay
   feature is built.

4. Add `@export var use_mock: bool = true` to `GardenManager` (it currently has none). Do NOT
   fire fetches in `_ready()` — catalogs require a valid token. Instead, connect to
   `UserManager.login_succeeded` signal in `_ready()` and fire the three fetches only from
   `_on_login_succeeded()`. URLs must include query params to avoid pagination truncation:
   `GET /api/flowertemplates?isDeleted=false&pageSize=1000`
   `GET /api/items?isDeleted=false&pageSize=1000`
   `GET /api/synergies?pageSize=1000`
   Inject auth header via `UserManager.get_auth_header()`. On 401, fall back to mock data.

5. After all three fetches succeed, replace `_templates` with the parsed FlowerTemplate map from
   `ReferenceDataService`. Emit `plots_updated(_plots)` so any listening scenes refresh with the
   new template data. If any single fetch fails (non-200 or network error), push_warning,
   keep the mock templates already loaded, and continue — never leave `_templates` empty.

6. Ensure the mock path is unchanged: when `use_mock = true`, `_ready()` must still call
   `MockGardenService.get_flower_templates()` exactly as before. Add an integration guard so
   both paths are exercised in the Godot editor by toggling the Inspector checkbox.

## Success Criteria
- With `use_mock = false` and BE running, GardenManager's `_templates` dictionary contains
  entries whose keys match the UUIDs returned by GET /api/flowertemplates
- A push_warning containing "no stage data" appears in the Output panel for each template
  (confirming the stage gap is surfaced, not silently swallowed)
- With BE offline and `use_mock = false`, game still reaches GardenScene within 10 seconds
  (timeout) and shows mock plants — no crash, no infinite spinner
- With `use_mock = true`, no HTTPRequest is made (verify via Godot Profiler network tab showing
  zero outgoing requests to localhost)
- `godot --headless --check-only --script res://autoloads/GardenManager.gd` reports zero errors

## Spec Coverage
- FR-06: Boot-time fetch of FlowerTemplate, Item, Synergy catalogs from BE
- FR-08: Mapping layer in services/ — ReferenceDataService owns all parse logic
