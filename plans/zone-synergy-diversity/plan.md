# Plan: Zone Synergy — Diversity Rule (≥2 loài hoa)

**Status:** ✅ Complete  
**Date:** 2026-06-15  
**Mode:** Fast | **Test:** --tdd  
**Parent:** `plans/zone-synergy/` (amendment)

---

## Scope Challenge

```
# Scope Challenge:
#   Exists?     → YES — SynergyEvaluator shipped; chỉ đổi điều kiện active
#   Minimum?    → Thêm distinct flower_template_id check trong evaluate_zone + tests
#   Complexity? → Fast — 1 domain file + 1 test file
#
# Mode: Fast
# Test: --tdd
```

**Spec Quality Check:** PASS

---

## Overview

Bổ sung điều kiện **đa dạng loài**: zone synergy chỉ `active` khi có **≥2 `flower_template_id` khác nhau** trong số cây occupied, ngoài các rule cũ (≥2 cây, cùng synergy).

---

## Phases

- [x] Phase 1: domain — `SynergyEvaluator.evaluate_zone` + headless tests
- [x] Phase 2 (optional, external): BE — **skipped** (Godot only per user)

**Cook order:** 1 only

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-15
**Phase in progress:** complete
**Status:** Diversity rule shipped; tests pass

### Decisions made this session
- Count diversity by `flower_template_id` (user confirmed)
- No mock seed changes — user playtests in game
- BE phase skipped — Godot only
- 8/8 same flower type + same synergy → no bonus (user confirmed)

### Next immediate action
Manual playtest in GardenScene

---

## Architecture Gate

```
Layer mapping:
  domain/     → SynergyEvaluator.gd (RefCounted)
  services/   → không đổi
  autoloads/  → không đổi (GardenManager gọi evaluator)
  scenes/     → không đổi (GardenScene gọi evaluator)

Dependency arrows: scenes → autoloads → domain — không vi phạm

Anti-pattern flags: all NO
Verdict: PASS
```

---

## Research Summary

**Primary (chosen):** Track `distinct template_ids` trong `evaluate_zone` — sau khi verify cùng synergy, check `template_ids.size() >= 2`. Một pass O(n), không API mới.

**Alternative (rejected):** Rule riêng ở GardenManager — duplicate logic, dễ lệch BE.

---

## Dependencies

- `Plot.current_plant.flower_template_id` (đã có)
- `FlowerTemplate.synergy_id` (đã có)
- Mock: `periwinkle` + `lotus`/`sun_flower` cùng synergy để playtest

---

## Risks

| Risk | Mitigation |
|------|------------|
| BE repo chưa sync → client/ server lệch bonus | Phase 2 checklist; document trong handoff |
| Test cũ expect 2× same flower = active | Cập nhật test + thêm case diversity |
| `godot_implement.md` smoke test mô tả rule cũ | Cập nhật sau cook (Step 5) |

---

## Stories Covered

| Phase | P1 | P2 |
|-------|----|----|
| 1 | P1-1, P1-2 | P2-1, P2-2 |
| 2 (BE) | P1-3 | — |

---

## Session Notes

**Last active:** 2026-06-15  
**Next action:** `/ck:cook --fast --tdd plans/zone-synergy-diversity/plan.md`
