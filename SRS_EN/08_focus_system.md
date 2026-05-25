# 08 — Focus System (Study Concentration Mode)

## Overview

Focus Mode is a unique feature that combines a Pomodoro-style timer with a "garden penalty" mechanic if the user violates the focus session. Not yet implemented in MVP — this is the specification for future development.

---

## FocusSession Entity

```
id:              GUID
userId:          GUID
startTime:       DateTime UTC
targetDuration:  int  (minutes)
strikes:         int  (number of violations)
status:          "IN_PROGRESS" | "COMPLETED" | "FAILED"
```

---

## User Flow

```
[User navigates to the school area in-game]
        ↓
[Enter classroom] → [Focus Mode screen]
        ↓
[Set timer] (e.g. 25 minutes)
        ↓
[Start Focus]
        ↓
 FocusSession.status = IN_PROGRESS
 App starts Android Foreground Service (persistent notification)
 Countdown timer runs in background
        ↓
[During focus session]
    ├── User switches app / exits
    │       ↓
    │   Record 1 strike
    │   If strikes > max_strikes (configured by Admin):
    │       status = FAILED
    │       Deduct XP from all plants in garden (amount by Admin config)
    │
    └── User completes the full duration
            ↓
        status = COMPLETED
        Award items: watering cans, fertilizer, decor
```

---

## Background Tracking Mechanism (Android)

### Foreground Service
- When Focus starts: launch Android Foreground Service
- Display a persistent notification on the status bar (non-dismissible)
- Service keeps the app alive while the screen is locked
- Runs the countdown timer in the background

### Violation Detection
```
Screen ON event received (Android):
    if app not in foreground within X seconds:
        session.strikes += 1
        if session.strikes > admin_config.max_strikes:
            TriggerFailure()
```

### TriggerFailure()
```
session.status = FAILED
for each plot in user's garden:
    if plot.IsOccupied:
        plant.CurrentXp -= admin_config.focus_fail_xp_penalty
        plant.CurrentXp = max(0, plant.CurrentXp)
        plant.CurrentStage = ComputeStageForXp(plant.CurrentXp)
SyncGardenState()
```

---

## Rewards on COMPLETED

Rewards depend on `targetDuration` (example values — Admin-configurable):

| Duration | Rewards |
|----------|---------|
| 25 min | 2× Watering Can |
| 50 min | 1× Fertilizer + 2× Watering Can |
| 90 min | 1× Pesticide + 2× Fertilizer + Decor item |

> Reward tables are configured by Admin, not hard-coded.

---

## Admin Config Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `max_strikes` | int | Maximum violations before a FAIL (default: 3) |
| `focus_fail_xp_penalty` | int | XP deducted per plant when session FAILs |
| `focus_reward_table` | JSON | Mapping of duration → reward list |

---

## School Area (FPT University Theme)

- The player controls a 2D character walking around a game world designed after FPT University
- Walk to the school building → enter a classroom → triggers Focus Mode
- Day/night cycle updates automatically based on real-world time

---

## Godot Implementation Notes

```gdscript
# FocusSession as a data class
class_name FocusSession
extends RefCounted

var id: String
var user_id: String
var start_time: int    # Unix timestamp
var target_duration: int  # minutes
var strikes: int = 0
var status: String = "IN_PROGRESS"  # IN_PROGRESS | COMPLETED | FAILED

# Android background tracking requires a native plugin or
# Android native code via Godot's JavaClassWrapper / JNICallable.
```

Required Godot Android plugins:
- `AndroidPlugin` to access Foreground Service
- Screen on/off broadcast receiver
