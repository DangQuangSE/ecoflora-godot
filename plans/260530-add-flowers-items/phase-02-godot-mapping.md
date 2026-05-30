# Phase 2: Godot Data Mapping

## Layer
Autoloads (`autoloads/GardenManager.gd`) and Services (`services/ReferenceDataService.gd`)

## Files
| File | Layer | Action |
|------|-------|--------|
| `autoloads/GardenManager.gd` | Autoloads | Extend `_FLOWER_NAME_TO_ASSET`; replace item icon strip-logic |
| `services/ReferenceDataService.gd` | Services | Extend `_FLOWER_DEFAULTS` with 13 variant entries |

## Requirements
After login, the Godot inventory UI displays correct icons and growth stage data for all 20 flowers (including all 13 variants) and all 20 items across all tier prefixes (Basic / Standard / Premium / Super / Enchanted / Legendary / Crystal).

## Steps

1. **Extend `_FLOWER_NAME_TO_ASSET` in `GardenManager.gd`** — add 13 entries mapping variant BE names to the base asset folder they share. The key must exactly match the lowercase name stored in the BE database:
   ```gdscript
   const _FLOWER_NAME_TO_ASSET: Dictionary = {
       # 7 originals (unchanged)
       "anthurium":            "anthurium",
       "lotus":                "lotus",
       "periwinkle":           "periwinkle",
       "purple_bellflower":    "purple_bellflower",
       "rose":                 "rose",
       "sun_flower":           "sun_flower",
       "tulip":                "tulip",
       # 13 variants — reuse base asset folders
       "golden_rose":          "rose",
       "blue_lotus":           "lotus",
       "rainbow_tulip":        "tulip",
       "midnight_periwinkle":  "periwinkle",
       "crimson_anthurium":    "anthurium",
       "sunset_sunflower":     "sun_flower",
       "violet_bellflower":    "purple_bellflower",
       "moonlit_rose":         "rose",
       "crystal_lotus":        "lotus",
       "fire_tulip":           "tulip",
       "silver_anthurium":     "anthurium",
       "jade_periwinkle":      "periwinkle",
       "star_sunflower":       "sun_flower",
   }
   ```

2. **Replace item icon strip-logic in `GardenManager.gd`** — delete the current `raw_name.replace("super ", "")` approach and replace the entire item-icon loop inside `_register_be_icons()` with a keyword-contains scan. The new logic checks whether the lowercased item name contains one of the three keyword substrings:
   ```gdscript
   # Replace only the item-icon block inside _register_be_icons():
   for iid: String in _item_cache:
       var item: Dictionary = _item_cache[iid]
       var raw_name: String = str(item.get("name", "")).to_lower()
       var icon_path: String = ""
       if "watering can" in raw_name:
           icon_path = "res://assets/icon/watering_can.PNG"
       elif "fertilizer" in raw_name:
           icon_path = "res://assets/icon/fertilizer.png"
       elif "pesticide" in raw_name:
           icon_path = "res://assets/icon/sickle.png"
       if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
           continue
       ItemIconRegistry.register(iid, load(icon_path))
   ```
   Remove the now-unused `_ITEM_NAME_TO_ICON` dictionary constant entirely (or keep as dead reference — removing is cleaner).

3. **Extend `_FLOWER_DEFAULTS` in `ReferenceDataService.gd`** — add 13 variant entries. Each variant uses the same `[0,50,150,300]` XP thresholds as the base flowers but gets a unique `harvest_id` so harvested products are distinguishable in inventory:
   ```gdscript
   const _FLOWER_DEFAULTS: Dictionary = {
       # 7 originals (unchanged)
       "anthurium":            { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_anthurium_bloom" },
       "lotus":                { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_lotus_bloom" },
       "periwinkle":           { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_periwinkle_bloom" },
       "purple_bellflower":    { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_purple_bellflower_bloom" },
       "rose":                 { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_rose_bloom" },
       "sun_flower":           { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_sun_flower_bloom" },
       "tulip":                { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_tulip_bloom" },
       # 13 variants
       "golden_rose":          { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_golden_rose_bloom" },
       "blue_lotus":           { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_blue_lotus_bloom" },
       "rainbow_tulip":        { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_rainbow_tulip_bloom" },
       "midnight_periwinkle":  { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_midnight_periwinkle_bloom" },
       "crimson_anthurium":    { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_crimson_anthurium_bloom" },
       "sunset_sunflower":     { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_sunset_sunflower_bloom" },
       "violet_bellflower":    { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_violet_bellflower_bloom" },
       "moonlit_rose":         { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_moonlit_rose_bloom" },
       "crystal_lotus":        { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_crystal_lotus_bloom" },
       "fire_tulip":           { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_fire_tulip_bloom" },
       "silver_anthurium":     { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_silver_anthurium_bloom" },
       "jade_periwinkle":      { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_jade_periwinkle_bloom" },
       "star_sunflower":       { "stages": [[0, 0], [1, 50], [2, 150], [3, 300]], "harvest_id": "harvest_star_sunflower_bloom" },
   }
   ```

4. **Run static analysis** to confirm no new GDScript errors were introduced:
   ```
   godot --headless --check-only --script res://autoloads/GardenManager.gd
   godot --headless --check-only --script res://services/ReferenceDataService.gd
   ```

5. **Boot the game and log in** — open inventory after a `/api/admin/inventory/grant` call and confirm all 20 flower slots show their tile art (variants share the base asset art) and all 20 item slots show the correct icon (watering can / fertilizer / sickle). No `push_warning` lines for unknown templates should appear in the Godot Output panel.

## Success Criteria
- `_FLOWER_NAME_TO_ASSET` has exactly 20 keys
- `_FLOWER_DEFAULTS` has exactly 20 keys
- The item icon loop resolves icons for all 7 tier prefixes without touching `_ITEM_NAME_TO_ICON`
- Zero "unknown template" warnings in Godot Output after login with a freshly granted inventory
- Godot static analysis exits with code 0 for both changed files

## Risks
- Typo in a variant key causes silent icon miss: Mitigation — key names in `_FLOWER_NAME_TO_ASSET` and `_FLOWER_DEFAULTS` must be byte-for-byte identical to the BE `Name` column (all lowercase, underscores)
- `"watering can"` substring check is order-sensitive — must come before generic fallback: Mitigation — the `elif` chain in step 2 is evaluated top-to-bottom; place the most specific keyword first
