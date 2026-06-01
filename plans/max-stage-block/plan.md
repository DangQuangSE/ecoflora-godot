# Plan: Max Stage Care Block + Floating Notification
Status: ✅ Done
Date: 2026-05-30
Mode: Fast

## Overview
Block water/fertilize/pesticide actions when a plant is at max stage, and display a distinctly colored floating label "ĐÃ ĐẠT LEVEL TỐI ĐA" instead of consuming the item or calling the API.

## Phases
- [x] Phase 1: block-and-notify — Add color param to FloatLabel.play(), update _spawn_float_label, and insert max-stage guard in Plot._apply_item()

## Research Summary
N/A

## Dependencies
None

## Risks
- LOW: FloatLabel.play() signature change could break callers — mitigated by keeping default color identical to current hardcoded value (backward compat)
- LOW: get_max_stage_level() returns unexpected value — already verified in codebase; same call is used by _try_harvest() with no issues
