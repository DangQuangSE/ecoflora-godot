# Spec: Character Selection & Shop Purchase

**Date:** 2026-06-27
**Status:** Draft

---

## Problem Statement

Player hiện không thể tùy chỉnh nhân vật di chuyển trong garden. Tính năng này cho phép chọn skin nhân vật sau khi đăng ký và mua thêm nhân vật bằng coin trong shop, tăng tính cá nhân hóa.

---

## User Stories

- **[P1]** As a new player, I want to choose my character immediately after registration so that I start the game with a personalized avatar.
  Accepted when: After `register_succeeded`, a forced CharacterSelectScene appears showing ≥2 characters; cannot skip; proceeds to LoginScene after confirming.

- **[P1]** As a player, I want my selected character to appear as the walking sprite in the garden so that the game reflects my choice.
  Accepted when: `_player.set_character(idx)` is called in `GardenScene._ready()` using the stored index; correct SpriteFrames loads; all 6 animations play correctly.

- **[P1]** As a player, I want to buy additional characters in the shop using coins so that I can unlock new skins.
  Accepted when: Shop shows a "Nhân Vật" tab; character cards show price + "Đã sở hữu"/"Mua" state; purchase deducts coin; owned list persists in BE across sessions.

- **[P1]** As a player, I want to switch between characters I already own via my profile so that I can change my look without going to the shop.
  Accepted when: Profile scene shows a "Nhân Vật" section listing all owned characters; tapping one equips immediately (optimistic) and syncs to BE via `PUT /api/auth/character`.

- **[P2]** As a player, I want to preview character animations before buying so that I know what I'm purchasing.
  Accepted when: Character card in shop shows a looping idle animation preview.

- **[P3]** _(out of scope — character stat bonuses, character unlock via XP milestone, character rental)_

---

## Functional Requirements

1. **FR-01 — CharacterSelectScene**: Full-screen scene shown once after `register_succeeded`. Displays all available characters (owned + locked). Tapping a character previews it. Confirm button (always enabled) saves selection locally and fades to LoginScene.

2. **FR-02 — Player sprite swap**: `Player.gd` exposes `set_character(idx: int)`. Loads from `const _CHARACTER_FRAMES: Array[SpriteFrames]` (preloaded). `GardenScene._ready()` calls `_player.set_character(UserManager.get_character_index())` after player node is ready.

3. **FR-03 — UserManager character fields**: `character_index: int` (currently equipped), `owned_characters: Array[int]` (all owned including default). Local ConfigFile key `character_prefs.cfg`. `set_character_async(idx)` = optimistic local update + `PUT /api/auth/character`.

4. **FR-04 — BE: User entity fields**: Add `CharacterIndex` (int, default 0) and `OwnedCharacterIndices` (JSON string, default `"[0]"`) to User entity. Include in `GET /api/auth/profile` response. Add `PUT /api/auth/character` endpoint accepting `{ "characterIndex": N }`.

5. **FR-05 — BE: Shop purchase "Character" category**: When `purchase_async("character:N", 1)` is called, BE appends N to `OwnedCharacterIndices` (idempotent — no duplicates). Response includes `remainingCurrency` + `ownedCharacters` array.

6. **FR-06 — Shop "Nhân Vật" tab**: New tab in ShopScene. Category string `"Character"`. Cards show: character preview image, name, price (or "Đã sở hữu" if owned). No equip button in shop — equip is done in Profile. Coin tab stays at last position.

7. **FR-07 — Profile character section**: Existing ProfileScene gets a new "Nhân Vật" section. Shows all owned characters as selectable cards with current equipped state ("Đang mặc"). Tapping an unequipped owned character calls `UserManager.set_character_async(idx)` → sprite updates on next garden entry.

7. **FR-07 — First-login sync**: On `fetch_profile_async()` after login, if `load_character_index_local() > 0` and BE returns `CharacterIndex = 0`, call `set_character_async()` to sync the locally-picked choice to BE. Fire-and-forget.

8. **FR-08 — Owned-character guard**: `set_character_async(idx)` is a no-op if `idx not in owned_characters`. UI must not show Equip button for unowned characters.

---

## Non-Functional Requirements

- **Sync latency**: `PUT /api/auth/character` timeout 10s (same as avatar-index). Rollback on non-200.
- **Asset constraint**: All character `SpriteFrames` resources must define the same 6 animation names: `idle_down`, `idle_up`, `walk_right`, `walk_left`, `walk_down`, `walk_up`. Validated at editor time.
- **BE migration**: Existing users get `CharacterIndex=0`, `OwnedCharacterIndices="[0]"` via EF Core migration default values.

---

## Success Criteria

- [ ] Register → CharacterSelectScene appears, cannot exit without selecting → LoginScene
- [ ] Garden loads with correct character sprite based on stored index
- [ ] All 6 movement animations play correctly for new character
- [ ] Shop "Nhân Vật" tab shows "Đã sở hữu" (no equip button) for owned characters
- [ ] Profile scene shows owned characters; tapping equips and updates garden sprite
- [ ] Re-login (fresh app start) preserves character selection (from BE profile response)
- [ ] `owned_characters` in BE does not contain duplicates after multiple purchases of same character

---

## Out of Scope

- Character stat bonuses or gameplay effects
- Character unlock via XP milestone (only coin purchase)
- Animated preview in CharacterSelectScene (P2, may be cut)
- Equip button in shop — equip only via Profile scene
- Character rental / time-limited ownership
- Admin CRUD for character catalog (hardcoded client-side for MVP, like `_COIN_PACKAGES`)

---

## Assumptions

- Exactly 2 characters at launch: index 0 (default, free) + index 1 (purchasable, 10,000 coin)
- Character assets use identical animation names as Player.tscn current SpriteFrames
- Shop "Character" items hardcoded client-side (like `_COIN_PACKAGES`) — no new BE shop category seeder needed
- `purchase_async()` response extended to include `ownedCharacters: [int]` when item category is Character
- Shop tab order: `Seed | Consumable | Nhân Vật | Decoration | Coin` (tab index 2)
- CharacterSelectScene animated preview: `AnimatedSprite2D` playing `idle_down` per character card

---

## [NEEDS CLARIFICATION]

_All items resolved._
