# Brainstorm: Character Selection & Shop Purchase

**Date:** 2026-06-27

## Ideas Explored

- **Index-based + BE field** — mirror `avatar_index` pattern: `character_index` (equipped) + `owned_characters` (array) stored in User entity, synced via profile endpoint. Chosen approach.
- **Inventory-backed** — separate `UserCharacters` table + dedicated equip/owned endpoints. Correct but over-engineered for 2–3 characters.
- **Local-only** — ConfigFile only, no BE sync. Loses data on reinstall. Rejected.
- **Multiple SpriteFrames resources** — one `.tres` per character, `Player.set_character(idx)` swaps `_sprite.sprite_frames`. Chosen.
- **Single SpriteFrames with prefix** — `char0_walk_down`, `char1_walk_down` in one file. Hard to maintain. Rejected.
- **Character select after register** — forced, before LoginScene. Chosen.
- **Character select on first garden entry** — overlay in GardenScene. Alternative, avoids token timing issue but UX less clear.

## User's Direction

- Purely cosmetic sprite swap (no stat bonus)
- Assets already exist for new character
- Forced selection after register (no skip)
- Shop tab to buy additional characters with existing coin
- Wants proper BE persistence (not local-only)

## Recommended Architecture

**BE changes (minimal):**
- Add `CharacterIndex` (int, default 0) + `OwnedCharacterIndices` (JSON array, default `[0]`) to User entity
- Include both in `GET /api/auth/profile` response
- Add `PUT /api/auth/character` endpoint (mirrors avatar-index)
- Shop purchase of "Character" category item → BE appends index to `OwnedCharacterIndices`

**Token timing:** Register success → no token yet → store selection in ConfigFile → fade to Login → after `fetch_profile_async()` on first login, sync local selection to BE. Same pattern as `avatar_index`.

**Godot changes:**
- `Player.gd`: add `const _CHARACTER_FRAMES`, `set_character(idx)` swaps `_sprite.sprite_frames`
- `UserManager.gd`: add `character_index`, `owned_characters`, `set_character_async()`, `save/load_character_prefs()`
- New scene `CharacterSelectScene.tscn` — inserted in RegisterScene flow between register success and Login
- Shop: new tab "Nhân Vật" (category `"Character"`) — shows cards with character preview, buy button disabled if already owned
- `GardenScene.gd`: on `_ready`, call `_player.set_character(UserManager.get_character_index())`

## Open Questions

- How many characters at launch? (2 assumed: default + 1 purchasable)
- Price of purchasable character(s)? (must be set in BE shop seeder)
- Animated preview in CharacterSelectScene or static image?
- Does equipping a character cost anything (separate equip fee) or free once owned?

## Risks

1. **SpriteFrames animation name mismatch** — new character assets must have identical animation names (`idle_down`, `idle_up`, `walk_right`, `walk_left`, `walk_down`, `walk_up`). If asset uses different names, `_update_animation()` in `Player.gd` breaks silently.
2. **BE migration** — adding columns to User entity requires migration; existing users default to `CharacterIndex=0`, `OwnedCharacterIndices=[0]`.
3. **Register → CharacterSelect token timing** — local ConfigFile must be read on first `fetch_profile_async()` and synced before emitting `profile_updated`. Risk of double-sync if user logs in from two devices.
