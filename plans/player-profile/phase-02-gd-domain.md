# Phase 2: Godot Domain — UserProfile

## Layer
domain/ — pure RefCounted, no Node, no autoload imports

## Files

| File Path | Layer | Change Type |
|-----------|-------|-------------|
| `domain/UserProfile.gd` | domain | modify |

## Tasks

1. **Add `login_streak: int = 0`** as a new instance variable in `UserProfile.gd`, placed after the existing `harvest_count` field. Type hint required per project style rules.

2. **Add `avatar_index: int = 0`** as a new instance variable, placed after `login_streak`. Valid range is 0–5 (6 preset avatars).

3. **Add `join_date: String = ""`** as a new instance variable (P2 field from spec), placed after `avatar_index`. This will hold the ISO date string from the BE `createdAt` field and is displayed as "Tham gia: DD/MM/YYYY" in the profile card.

4. **No other changes.** Do not add any Node references, autoload imports, signals, or helper methods. The domain layer must remain pure RefCounted with zero engine dependencies beyond `Time` (already used by `is_vitality_ready()`).

## Acceptance
- `godot --headless --check-only --script res://domain/UserProfile.gd` exits with no errors.
- A `UserProfile.new()` instance has `.login_streak == 0`, `.avatar_index == 0`, `.join_date == ""` accessible.
- No `extends Node`, no `get_tree()`, no autoload identifiers appear in the file.
