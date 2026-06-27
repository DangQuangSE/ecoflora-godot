# Plan: Character Selection & Shop Purchase

**Status:** Complete
**Spec:** [spec.md](spec.md)
**Date:** 2026-06-27

---

## Overview

Adds a cosmetic character system: forced selection after register, purchasable skins in Shop, equip via Profile card. BE stores `CharacterIndex` + `OwnedCharacterIndices` on the User entity; Godot swaps `SpriteFrames` at runtime.

---

## Phases

| # | File | Goal |
|---|------|------|
| 1 | [phase-01-be-character-fields.md](phase-01-be-character-fields.md) | User entity + migration + PUT /api/auth/character + Character purchase in ShopService |
| 2 | [phase-02-player-sprite-swap.md](phase-02-player-sprite-swap.md) | Player.gd `set_character(idx)` + GardenScene wiring |
| 3 | [phase-03-usermanager-character.md](phase-03-usermanager-character.md) | UserManager: new fields, signals, ConfigFile prefs, set_character_async, fetch_profile sync |
| 4 | [phase-04-character-select-scene.md](phase-04-character-select-scene.md) | New CharacterSelectScene — forced after register_succeeded |
| 5 | [phase-05-shop-tab.md](phase-05-shop-tab.md) | Shop "Nhân Vật" tab — buy, "Đã sở hữu" state |
| 6 | [phase-06-profile-character-section.md](phase-06-profile-character-section.md) | UserProfileCard character equip section |

---

## Dependencies

```
Phase 1 (BE) ──► Phase 3 (UserManager fetch_profile parse)
Phase 2 (Player) ──► Phase 4 (CharacterSelectScene preview)
Phase 2 + 3 ──► Phase 5 (Shop purchase → sprite update)
Phase 3 ──► Phase 6 (Profile equip)
```

Phase 4 can be built before Phase 3 is complete (uses local ConfigFile only; no BE call).
Phases 2 and 4 can be built in parallel with Phase 1 (no BE dependency).

---

## Risks

1. **Animation name mismatch** — new character SpriteFrames must define all 6 names (`idle_down`, `idle_up`, `walk_right`, `walk_left`, `walk_down`, `walk_up`). Mismatch silently stops animation. Mitigation: assert in `set_character()`.

2. **OwnedCharacterIndices JSON parse on BE** — EF Core stores as `string`; need manual `JsonSerializer.Deserialize` + idempotent append + re-serialize. No migration complexity, but service layer must handle malformed defaults gracefully.

3. **Post-register token timing** — after `register_succeeded`, user has no token. CharacterSelectScene must save selection locally only; sync happens inside `fetch_profile_async()` after first login. Risk: user switches device → local selection overrides BE. Acceptable for MVP.

4. **ShopScene tab index shift** — inserting Character at index 2 shifts Decoration to 3 and Coin to 4. Must update both `_TAB_CATEGORIES` array and the `_tab_btns` array + `.tscn` node references.

5. **`purchase_async` return type change** — currently returns `Dictionary` with only `remainingCurrency`. After Phase 1, Character purchases also return `ownedCharacters`. Phase 3 must check `data.has("ownedCharacters")` before updating local state.

---

## Out of Scope

- Character stat bonuses
- Admin CRUD for character catalog (hardcoded for MVP)
- Animated preview in ShopScene cards (P2)
- Equip button inside ShopScene (Profile-only)
- Live sprite hot-swap in GardenScene via signal (P2 — garden reload on next entry is sufficient)

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-27
**Phase in progress:** (all complete)
**Status:** All 6 phases implemented and reviewed

### Decisions made this session
- Character 0 (default) pre-owned — never purchasable, always shown as "Đã sở hữu"
- Thumbnail assets (`char_0_thumb.png`, `char_1_thumb.png`) and SpriteFrames (`.tres`) are required before visual testing — ResourceLoader.exists() guards prevent crashes without them
- `_char_section` onready removed (unused — only `_char_grid` needed)
- `set_character_async` double-guard: `_on_char_selected` checks `is_character_owned` + button disabled in `_refresh_character_section` — belt-and-suspenders

### Next immediate action
Create asset files in Godot editor: `char_0.tres`, `char_1.tres`, `char_0_thumb.png`, `char_1_thumb.png`
