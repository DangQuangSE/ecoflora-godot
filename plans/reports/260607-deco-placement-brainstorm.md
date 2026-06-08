# Brainstorm: Deco Placement System

**Date:** 2026-06-07

## Ideas Explored

- **Free placement anywhere on scene background** — user taps/drags deco from inventory onto any position in garden or school scene. No grid, no snap.
- **Grid-snapped placement** — decos snap to a grid for cleaner aesthetics. *Dismissed: user explicitly wants free placement.*
- **Plot-attached placement** — decos placed only near plots. *Dismissed: too restrictive.*
- **Session-only placement** — decos reset on game exit, no BE needed. *Dismissed: user wants persistence.*
- **Edit mode (batch save)** — press Edit → drag decos around → press Save. One PATCH call on save. *Chosen.*
- **Realtime save on drop** — PATCH after every drag-and-drop. *Dismissed: user prefers edit mode.*
- **Per-scene script (decentralized)** — GardenScene + SchoolScene each handle their own deco logic. *Dismissed: code duplication.*
- **DecoManager autoload (centralized)** — new autoload handles all deco API calls and scene-level rendering. *Chosen: consistent with existing autoload architecture.*

## User's Direction

Free placement on any scene background (garden + school). Persistent via BE. Edit mode for drag/move, batch save on confirm. Tap placed deco to recall it back to inventory.

## Open Questions

- Should there be a max number of decos per scene per user (anti-clutter)?
- Z-ordering: should newer decos always render on top, or should user control layer order?
- School scene: is there a specific background node to use as placement boundary?

## Risks

1. **Float coordinate drift** — Godot `Vector2` positions may not round-trip cleanly through JSON floats. Consider rounding to 1 decimal on save.
2. **Inventory desync** — if placement succeeds but quantity deduction fails (or vice versa), user could have ghost decos or negative quantity. Must be a single BE transaction.
3. **Scene background boundary** — "anywhere on background" needs a defined rect; without it, users can place decos off-screen on different resolutions.
