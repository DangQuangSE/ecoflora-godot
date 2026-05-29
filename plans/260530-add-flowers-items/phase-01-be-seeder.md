# Phase 1: BE Seeder

## Layer
Infrastructure — `Infrastructure/Data/Seeder.cs`

## Files
| File | Layer | Action |
|------|-------|--------|
| `Infrastructure/Data/Seeder.cs` | Infrastructure | Replace stub body with full seed logic |

## Requirements
After app startup, the database contains 3 Synergy rows, 20 FlowerTemplate rows, and 20 Item rows. Running `SeedAsync` a second time is safe (no duplicate-key errors).

## Steps

1. **Add idempotency guards** — wrap each data block (Synergies, FlowerTemplates, Items) in an `if (!context.<DbSet>.Any())` check so re-running the seeder is a no-op.

2. **Seed 3 Synergies** — create and add the following rows, then `SaveChanges`:
   - `"Water Lover"` — XpPlus = 5, CooldownMinus = 60
   - `"Sun Chaser"` — XpPlus = 10, CooldownMinus = 0
   - `"Night Bloom"` — XpPlus = 0, CooldownMinus = 120

3. **Seed 7 base FlowerTemplates** — names must be lowercase to match asset folder keys; assign synergies by index; `SaveChanges`:
   ```csharp
   // Inside if (!context.FlowerTemplates.Any()) block, after synergies are saved
   var waterLover = context.Synergies.First(s => s.Name == "Water Lover");
   var sunChaser  = context.Synergies.First(s => s.Name == "Sun Chaser");
   var nightBloom = context.Synergies.First(s => s.Name == "Night Bloom");

   var baseFlowers = new List<FlowerTemplate>
   {
       new("anthurium",         70,  "", waterLover.Id),
       new("lotus",             80,  "", waterLover.Id),
       new("periwinkle",        60,  "", null),
       new("purple_bellflower", 65,  "", nightBloom.Id),
       new("rose",              90,  "", null),
       new("sun_flower",        75,  "", sunChaser.Id),
       new("tulip",             85,  "", null),
   };
   context.FlowerTemplates.AddRange(baseFlowers);
   await context.SaveChangesAsync();
   ```

4. **Seed 13 variant FlowerTemplates** — same block, after base flowers are saved; names match the `_FLOWER_NAME_TO_ASSET` keys that Phase 2 will add:
   ```csharp
   var variantFlowers = new List<FlowerTemplate>
   {
       new("golden_rose",          200, "", null),
       new("blue_lotus",           180, "", waterLover.Id),
       new("rainbow_tulip",        190, "", sunChaser.Id),
       new("midnight_periwinkle",  170, "", nightBloom.Id),
       new("crimson_anthurium",    210, "", null),
       new("sunset_sunflower",     195, "", sunChaser.Id),
       new("violet_bellflower",    175, "", nightBloom.Id),
       new("moonlit_rose",         250, "", nightBloom.Id),
       new("crystal_lotus",        240, "", waterLover.Id),
       new("fire_tulip",           230, "", sunChaser.Id),
       new("silver_anthurium",     260, "", null),
       new("jade_periwinkle",      220, "", null),
       new("star_sunflower",       280, "", sunChaser.Id),
   };
   context.FlowerTemplates.AddRange(variantFlowers);
   await context.SaveChangesAsync();
   ```

5. **Seed 20 Items** — 7 WATER + 7 FERTILIZER + 6 PESTICIDE, tiered by prefix; higher tier = more XP + lower cooldown; `ItemType` enum values are `WATER=0, FERTILIZER=1, PESTICIDE=2`:
   ```csharp
   // Cooldown in seconds. Tier order: Basic < Standard < Premium < Super < Enchanted < Legendary < Crystal
   var items = new List<Item>
   {
       // WATER (ItemType.WATER)
       new("Basic Watering Can",     30,  "", 3600, ItemType.WATER,       20),
       new("Standard Watering Can",  60,  "", 3000, ItemType.WATER,       30),
       new("Premium Watering Can",   100, "", 2400, ItemType.WATER,       40),
       new("Super Watering Can",     150, "", 1800, ItemType.WATER,       55),
       new("Enchanted Watering Can", 220, "", 1200, ItemType.WATER,       70),
       new("Legendary Watering Can", 320, "", 600,  ItemType.WATER,       90),
       new("Crystal Watering Can",   450, "", 300,  ItemType.WATER,      120),

       // FERTILIZER (ItemType.FERTILIZER)
       new("Basic Fertilizer",       40,  "", 7200, ItemType.FERTILIZER,  50),
       new("Standard Fertilizer",    80,  "", 6000, ItemType.FERTILIZER,  70),
       new("Premium Fertilizer",     130, "", 4800, ItemType.FERTILIZER,  90),
       new("Super Fertilizer",       190, "", 3600, ItemType.FERTILIZER, 115),
       new("Enchanted Fertilizer",   270, "", 2400, ItemType.FERTILIZER, 140),
       new("Legendary Fertilizer",   380, "", 1200, ItemType.FERTILIZER, 175),
       new("Crystal Fertilizer",     520, "", 600,  ItemType.FERTILIZER, 220),

       // PESTICIDE (ItemType.PESTICIDE)
       new("Basic Pesticide",        40,  "", 7200, ItemType.PESTICIDE,   50),
       new("Standard Pesticide",     80,  "", 6000, ItemType.PESTICIDE,   70),
       new("Premium Pesticide",      130, "", 4800, ItemType.PESTICIDE,   90),
       new("Super Pesticide",        190, "", 3600, ItemType.PESTICIDE,  115),
       new("Enchanted Pesticide",    270, "", 2400, ItemType.PESTICIDE,  140),
       new("Legendary Pesticide",    380, "", 1200, ItemType.PESTICIDE,  175),
   };
   context.Items.AddRange(items);
   await context.SaveChangesAsync();
   ```

6. **Wire Seeder into program startup** — confirm `Seeder.SeedAsync(context)` is already called in `Program.cs` (or `WebApplication` startup). If not, add `await Seeder.SeedAsync(app.Services.GetRequiredService<AppDbContext>())` after `app.UseAuthorization()`. Then rebuild and run the backend once to apply seed data.

7. **Verify via Swagger** — call `GET /api/flowertemplates?pageSize=100` and `GET /api/items?pageSize=100`; confirm 20 rows each. Then call `/api/admin/inventory/grant` for a test user and check the inventory response contains all 40 entries.

## Success Criteria
- `GET /api/flowertemplates?pageSize=100` returns exactly 20 records
- `GET /api/items?pageSize=100` returns exactly 20 records
- Re-running the backend a second time adds 0 new rows (idempotency check)
- All 7 base flower names are lowercase (e.g., `"sun_flower"`, not `"Sun Flower"`)

## Risks
- Seeder runs twice on hot-reload: Mitigation — `Any()` guards on every block
- `ItemType` stored as string in DB (per `AppDbContext` conversion) — enum values like `WATER` serialize correctly; no extra mapping needed
