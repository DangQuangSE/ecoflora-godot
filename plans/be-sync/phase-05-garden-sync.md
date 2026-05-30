# Phase 5: Garden Sync

## STATUS: BLOCKED
**Reason:** BE garden/plot/planted-flower endpoints do not yet exist.
The BE team must implement and deploy at minimum:
- `GET /api/gardens/me` (or equivalent) returning a user's plots
- Each plot object must include a nested planted-flower object when occupied

**Do not start this phase until the BE endpoints are confirmed in the `feat/imple-godot` branch.**
Leave `GardenManager.use_mock = true` in the Inspector until unblocked.

---

## Layer
`services/` (GardenService) + `autoloads/GardenManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/GardenService.gd` | services | New |
| `autoloads/GardenManager.gd` | autoloads | Modify |

## Requirements
Replace the mock plot list in `GardenManager` with data fetched from the BE garden endpoint.
The GardenScene must display the correct number of plots and each plot's occupancy and plant
stage as stored on the server. The mock path must remain fully functional.

## Steps
1. Create `GardenService` (RefCounted, services layer). Add `parse_plots(arr: Array) -> Array[Plot]`
   that maps each BE plot JSON object to a `Plot` domain object. For each occupied plot, construct
   the nested `PlantedFlower` using `flower_template_id` and `current_xp` from the BE payload;
   compute `current_stage` via `FlowerTemplate.compute_stage_for_xp()` — never trust the stage
   value from the server directly.

2. Add `parse_planted_flower(json: Dictionary) -> PlantedFlower` as a helper inside `GardenService`.
   Map BE fields to `PlantedFlower` domain properties. If `flower_template_id` from BE does not
   match any key in `GardenManager._templates`, push_error and skip that plant (leave plot empty)
   rather than crashing.

3. In `GardenManager._ready()` when `use_mock = false`, after reference data is loaded (Phase 3
   already populated `_templates`), fire `GET /api/gardens/me` with the auth header. Use the same
   `HTTPRequest` child node pattern as WeatherManager. Guard with `_request_in_flight`.

4. On a successful 200 response, call `GardenService.parse_plots()` with the unwrapped array,
   replace `_plots`, and emit `plots_updated(_plots)`. On 401, call `UserManager.handle_401()`.
   On any other error, push_warning and keep the mock-loaded plots — never leave `_plots` empty.

5. Ensure all existing write operations (plant, water, fertilize, harvest) remain purely
   optimistic-local for now — syncing mutations back to BE is out of scope for this phase.
   Add a `# TODO: sync mutation to BE` comment above each write method as a marker.

## Success Criteria
- With BE running and garden endpoint implemented, `GardenManager.get_plots()` returns plots
  whose IDs match the UUIDs from the BE response (verify count and first ID in Output)
- An occupied plot from BE shows the correct `is_occupied = true` and a non-null `current_plant`
- A plot whose BE plant has `current_xp = 150` shows the stage computed by
  `FlowerTemplate.compute_stage_for_xp(150)`, not any BE-supplied stage value
- With BE offline and `use_mock = false`, game shows mock plots and a push_warning
- `use_mock = true` in Inspector routes entirely through MockGardenService — no regression

## Spec Coverage
- FR-03: Fetch garden state (Plot + PlantedFlower) from BE
- FR-08: Mapping layer in services/ — GardenService owns all plot/plant parse logic
- [P1] Garden state loads from real server and persists across devices
