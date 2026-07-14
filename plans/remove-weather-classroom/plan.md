# Plan: Remove Weather in Classroom

## Objective
Remove the weather overlay when the player enters `ClassroomScene.tscn`.

## Scope Challenge
- **Exists?**: No, currently weather is active globally or carries over from outside, showing weather inside the classroom.
- **Minimum?**: Add `WeatherManager.set_overlay_visible(false)` to `ClassroomScene.gd`.
- **Complexity?**: **Fast** — single-file change, familiar pattern used in `LoginScene` and `RegisterScene`.

## Proposed Changes

### Phase 1: Update ClassroomScene.gd
- **Modify** `scenes/school/ClassroomScene.gd`
- In the `_ready()` function, add a call to `WeatherManager.set_overlay_visible(false)` to disable the weather effect.

## Testing
- **testing**: skipped (Fast mode, manual verification is sufficient).
- Manually run the game, enter the classroom, and verify that the rain/weather overlay is not visible.
