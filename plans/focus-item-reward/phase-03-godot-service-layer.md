# Phase 3: Godot Service Layer

**Layer:** services/ (Godot — GDScript)
**Stories:** P1 (client reads reward items from BE response)

## Requirements
Change `FocusService._patch_terminal()` so that on a successful PATCH it returns the unwrapped `data` Dictionary from the response envelope instead of just `true`/`false`, giving callers access to `rewardItems`.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `services/FocusService.gd` | Edit | `_patch_terminal()` returns `Dictionary` (data on success, `{}` on fail); update `complete_async` and `fail_async` signatures accordingly |

## Steps
1. Change `_patch_terminal()` return type from `bool` to `Dictionary`. On any error path (request error, non-200 status, JSON parse failure) return `{}`. On success, unwrap the envelope using `HttpHelper.unwrap_envelope()` and return the inner `data` Dictionary.
2. Update `complete_async()` to return `Dictionary` and forward `_patch_terminal`'s return value directly.
3. Update `fail_async()` to return `Dictionary` in the same way. A non-empty return still means success; an empty `{}` means failure — this replaces the previous `bool` contract.
4. Verify the change is backward-compatible for `fail_async`: callers only need to know "did it succeed" — an empty dict is falsy equivalent, so checking `result.is_empty()` replaces checking `not ok`.

## Success Criteria
- `complete_async()` called against the updated BE returns a non-empty Dictionary containing a `rewardItems` key
- `complete_async()` against a simulated error (wrong URL) returns `{}`
- `fail_async()` returns a non-empty Dictionary on success (the FAILED session DTO, which has no `rewardItems`)
- No other files outside `services/FocusService.gd` are modified in this phase

## Risks
- `FocusManager` calls `complete_async` and `fail_async` and currently checks `ok: bool` — those call sites will break until Phase 4 updates them; do Phases 3 and 4 in the same working session to avoid broken intermediate state
