# Spec: Zone Synergy — Yêu cầu đa dạng loài hoa

**Date:** 2026-06-15  
**Status:** Ready  
**Parent:** `plans/zone-synergy/` (rule amendment)

---

## Problem

Quy tắc hiện tại cho phép synergy kích hoạt khi zone có ≥2 cây **cùng synergy**, kể cả khi chỉ trồng **một loài hoa** (vd. 2× sunflower Sun Chaser). Điều này không khuyến khích người chơi bố trí đa dạng loài trong cùng hệ sinh thái.

## Goal

Synergy zone chỉ active khi zone có **≥2 loài hoa khác nhau** (`flower_template_id` distinct) **và** tất cả cây đang trồng thuộc **cùng một Synergy**.

---

## User Stories

### P1 — Core rule change (must ship)

| ID | Story | Acceptance |
|----|-------|------------|
| P1-1 | Là người chơi, trồng 2 cây cùng loài cùng synergy → **không** bonus | `evaluate_zone` → `active: false` |
| P1-2 | Là người chơi, trồng ≥2 **loài khác nhau** cùng synergy → bonus XP khi care | Care XP = base + synergy.xpPlus |
| P1-3 | Mock + BE dùng **cùng rule** domain | Godot evaluator và BE `SynergyEvaluator.cs` (repo ngoài) khớp logic |

### P2 — Feedback (should ship — no scene changes expected)

| ID | Story | Acceptance |
|----|-------|------------|
| P2-1 | Indicator tắt khi chỉ còn 1 loài (dù ≥2 cây) | `GardenScene._refresh_synergy_indicators` reflect evaluator |
| P2-2 | Float label bonus chỉ khi diversity rule pass | `plant_xp_gained` synergy_bonus = 0 otherwise |

---

## Business Rules

| Rule | Value |
|------|-------|
| Minimum occupied plots | ≥ 2 (giữ nguyên) |
| Synergy purity | Mọi cây occupied phải có cùng `synergy_id` non-empty (giữ nguyên) |
| **Diversity (MỚI)** | **≥ 2 distinct `flower_template_id`** trong số cây occupied |
| Empty plots | Bỏ qua |
| Mixed synergies | Không bonus |
| Actions | WATER, FERTILIZE, PESTICIDE only |

---

## Success Criteria (measurable)

1. Zone: 2× `sun_flower` (Sun Chaser) → care → **chỉ base XP** (1 loài).
2. Zone: 1× `sun_flower` + 1× `periwinkle` (Sun Chaser) → tưới → **base + 10**.
3. Zone: 3× `sun_flower` + 1× `periwinkle` (Sun Chaser) → **active** (2 loài).
4. Zone: 2 loài cùng synergy + 1 cây synergy khác → **inactive**.
5. `godot --headless --script res://tools/test_synergy_evaluator.gd` → all passed.

---

## Out of Scope

- Thay đổi UI indicator / particle
- `cooldownMinus`
- Thay đổi zone boundaries

---

## Resolved Decisions (2026-06-15)

| Question | Decision |
|----------|----------|
| Đếm loài theo gì? | `flower_template_id` (không đếm theo instance) |
| 2 cây cùng template_id | Coi là **1 loài** |
| BE sync | Phase riêng — repo `eco-backend` ngoài workspace |
