# Phase 1: Autoload Flag

## Requirements
Expose a single integer field on UserManager that any scene can write before a scene transition to declare which shop tab should open. The field defaults to 0 so existing behavior is unchanged.

## Steps
1. Open `autoloads/UserManager.gd` and locate the block where member variables are declared.
2. Add a typed integer variable named `shop_open_tab` with a default value of 0, placed with the other state variables.
3. Verify no other file already declares or uses this variable name (grep the project).
4. Confirm static analysis passes on UserManager with no new errors.

## Success Criteria
- `UserManager.shop_open_tab` is accessible from any scene without errors
- Default value is 0 at game start
- `godot --headless --check-only --script res://autoloads/UserManager.gd` exits clean

## Risks
- Name collision with an existing property: mitigated by grepping before adding
