# Phase 6: Inventory Sync

## STATUS: BLOCKED
**Reason:** BE inventory endpoint does not yet exist.
The BE team must implement and deploy:
- `GET /api/inventory/me` (or equivalent) returning the authenticated user's inventory items
- Each item must include enough data to determine category (seed vs consumable vs decor) and
  the nullable foreign-key fields (`FlowerTemplateId`, `ItemId`, `DecorId`)

**Do not start this phase until the BE endpoint shape is confirmed. The FK-to-category mapping
logic depends on knowing which nullable field is populated.**
Leave `InventoryManager.use_mock = true` in the Inspector until unblocked.

---

## Layer
`services/` (InventoryService) + `autoloads/InventoryManager.gd` (modified)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/InventoryService.gd` | services | New |
| `autoloads/InventoryManager.gd` | autoloads | Modify |

## Requirements
Replace the mock inventory in `InventoryManager` with items fetched from the BE inventory
endpoint. The InventoryPanel must display the correct items and quantities as stored on the
server. Category must be derived from which nullable FK is populated — never from a client-side
assumption. The mock path must remain fully functional.

## Steps
1. Create `InventoryService` (RefCounted, services layer). Add
   `parse_inventory(arr: Array) -> UserInventory` that iterates the BE array and for each
   item JSON object determines `Category` by inspecting which nullable FK field is non-null:
   `flower_template_id` → SEED, `item_id` → CONSUMABLE, `decor_id` → DECOR. Map to
   `InventoryItem` domain objects and collect into a `UserInventory`.

2. Add `parse_inventory_item(json: Dictionary) -> InventoryItem` as a helper in `InventoryService`.
   If all three nullable FK fields are null or missing, push_warning and return null so the
   caller can skip that item rather than crashing. `harvest_product_id` items are Godot-local
   (not from BE) — do not attempt to map them from the BE response.

3. Add `@export var use_mock: bool = true` to `InventoryManager`. In `_ready()` when
   `use_mock = false`, after login completes, fire `GET /api/inventory/me` with the auth header
   using InventoryManager's own `HTTPRequest` child node. Guard with `_request_in_flight`.

4. On a successful 200 response, call `InventoryService.parse_inventory()` with the unwrapped
   array, replace `_inventory`, and emit `inventory_updated(_inventory)`. On 401, call
   `UserManager.handle_401()`. On any other error, push_warning and keep the mock inventory.

5. Ensure `add_harvest_product()` continues to work as a Godot-local operation appending to
   the in-memory `UserInventory` — harvest products are out of scope for BE sync (per spec Out
   of Scope section). Add a `# BE-local only` comment on that method.

## Success Criteria
- With BE running and inventory endpoint implemented, `InventoryManager.get_inventory().items`
  contains items whose IDs and categories match the BE response payload
- A SEED item from BE has `flower_template_id` set and `category == Category.SEED`
- A CONSUMABLE item from BE has `item_id` set and `category == Category.CONSUMABLE`
- With BE offline and `use_mock = false`, InventoryPanel shows mock items and a push_warning
- `use_mock = true` routes entirely through MockInventoryService — no regression
- `add_harvest_product()` still works after a real inventory fetch (appended locally, not sent
  to BE)

## Spec Coverage
- FR-04: Fetch inventory (InventoryItem) from BE
- FR-08: Mapping layer in services/ — InventoryService owns all item parse and category mapping
- [P1] Inventory reflects what is actually stored on the server
