# Phase 1: Domain — FocusSession

testing: skipped (--no-test)

## Layer

`domain/` — RefCounted only, no Node, no autoload imports, no signals

## Files

| File | Layer | Action |
|---|---|---|
| `domain/FocusSession.gd` | domain | CREATE |

---

## Requirements

Deliver a pure-data `FocusSession` class that holds all state for a single focus timer session. This class has zero dependencies on the rest of the game and can be instantiated and inspected without a running scene tree.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| App background detection → violation count | P1 | `violation_count` + `max_violations` fields |
| Complete session → +XP reward | P1 | `duration_seconds`, `elapsed_seconds` fields |
| Fail session → -20 XP penalty | P1 | `violation_count > max_violations` readable by FocusManager |
| Countdown overlay (MM:SS remaining) | P2 | `get_remaining_seconds()` helper |

---

## Steps

1. Create `domain/FocusSession.gd` as a `RefCounted` with `class_name FocusSession`. Add typed fields: `duration_seconds: int`, `elapsed_seconds: float`, `violation_count: int`, `max_violations: int` (default 3). No Node, no autoload references.

2. Add a constructor `_init(duration_sec: int, max_v: int)` that sets `duration_seconds` and `max_violations`, leaving `elapsed_seconds` and `violation_count` at 0.

3. Add `get_remaining_seconds() -> int` — returns `max(0, duration_seconds - int(elapsed_seconds))` — so FocusTimerUI never displays a negative number.

4. Add `get_minutes_focused() -> int` — returns `int(elapsed_seconds) / 60` — the integer minutes used for XP reward calculation by FocusManager.

5. Add `is_failed() -> bool` — returns `violation_count > max_violations` — single source of truth, used by FocusManager state machine.

6. Add `is_completed() -> bool` — returns `elapsed_seconds >= float(duration_seconds)` — used by FocusManager to trigger COMPLETED transition.

---

## Success Criteria

- `FocusSession.new(300, 3)` produces an object with `duration_seconds == 300`, `elapsed_seconds == 0.0`, `violation_count == 0`, `max_violations == 3`.
- After setting `elapsed_seconds = 300.0`, `is_completed()` returns `true` and `get_remaining_seconds()` returns `0`.
- After setting `violation_count = 4`, `is_failed()` returns `true`.
- `get_minutes_focused()` with `elapsed_seconds = 305.7` returns `5` (integer division, no rounding up).
- Static analysis passes: `godot --headless --check-only --script res://domain/FocusSession.gd` exits with no errors.

---

## Risks

- Floating-point accumulation in `elapsed_seconds`: FocusManager adds `delta` each frame, so elapsed may overshoot by a fraction. `is_completed()` using `>=` handles this correctly; `get_remaining_seconds()` uses `max(0, ...)` to prevent underflow display.
