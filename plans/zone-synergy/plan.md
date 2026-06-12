# Plan: Zone Synergy Bonus (Hệ sinh thái)

**Status:** ✅ Complete  
**Date:** 2026-06-12  
**Mode:** Hard | **Test:** --tdd

---

## Scope Challenge

```
# Scope Challenge:
#   Exists?     → NO — Synergy data + cache only; no xpPlus gameplay
#   Minimum?    → domain evaluator + BE CareForFlowerAsync bonus + GardenManager mock/BE paths
#   Complexity? → Hard — multi-layer (domain/services/autoloads/scenes), BE authority, zone mapping
#
# Mode: Hard
# Test: --tdd
```

**Spec Quality Check:** PASS (resolved 2026-06-12)

---

## Overview

Khi **≥ 2 cây đang trồng** trong một zone thuộc **cùng một Synergy** (non-null), mỗi lần tưới / bón phân / phun thuốc cộng thêm `Synergy.xpPlus`. Ô trống bỏ qua.

---

## Phases

- [x] Phase 1: domain — `ZonePlotMap` + `SynergyEvaluator` (pure RefCounted)
- [x] Phase 2: BE — zone synergy bonus in `GardenService.CareForFlowerAsync` + `CareResponseDto.synergyBonusXp`
- [x] Phase 3: autoloads — `GardenManager` integrate bonus (mock + `_care_action` optimistic/reconcile)
- [x] Phase 4: scenes — synergy float label + **SynergyZoneIndicator** particle/icon (P2, required)

**Cook order:** 1 → 2 → 3 → 4

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-12
**Phase in progress:** complete
**Status:** All 4 phases implemented; BE + domain tests pass

### Decisions made this session
- Minimum 2 occupied plants (user confirmed)
- Empty plots ignored
- SynergyZoneIndicator spawned after add_child to avoid @onready race
- Mock mode seeds `_synergy_cache` via `_seed_mock_synergies()` (lotus/periwinkle assigned)

### Next immediate action
Manual playtest in GardenScene; optional git commit

---

## Architecture Gate

Verdict: PASS — see original plan for details.

---

## Research Summary

Primary: domain evaluator + BE authoritative bonus + optimistic GardenManager + zone indicators.

---

## Dependencies

- `FlowerTemplate.synergy_id`, `GardenManager._synergy_cache`, BE `ZoneDefinitions`, `ZonePlotMap` (all 7 zones)

---

## Risks

See original plan — mitigated via server authority + `evaluate_zone_with_cache` for UI.

---

## Red-Team Review (2026-06-12)

All findings addressed in implementation.

---

## Stories Covered

| Phase | P1 | P2 | P3 |
|-------|----|----|-----|
| 1 | P1-1 | — | — |
| 2 | P1-2 | — | — |
| 3 | P1-1, P1-3 | P2-2 | — |
| 4 | — | P2-1 | — |
