# Phase 1: Domain — Diversity Rule in SynergyEvaluator

## Layer
`domain/` — RefCounted only

## Files

| File | Layer | Action |
|------|-------|--------|
| `domain/SynergyEvaluator.gd` | domain | Edit |
| `tools/test_synergy_evaluator.gd` | tools | Edit |

## Stories
P1-1, P1-2, P2-1, P2-2

## Requirements

### `evaluate_zone` — thêm bước diversity

Sau khi collect occupied plots, giữ nguyên các guard hiện tại:

1. `< 2 occupied` → inactive
2. Bất kỳ template null / `synergy_id` empty → inactive
3. Không cùng `synergy_id` → inactive
4. **MỚI:** Đếm distinct `flower_template_id` từ `plot.current_plant.flower_template_id`
   - Nếu `< 2` distinct → inactive
5. Else → active

Gợi ý implementation (trong cùng loop hoặc loop thứ hai):

```gdscript
var template_ids: Dictionary = {}  # id -> true
# ...
template_ids[plot.current_plant.flower_template_id] = true
# ...
if template_ids.size() < 2:
    return inactive_result
```

`get_bonus_for_plot` và `evaluate_zone_with_cache` **không đổi** — chúng gọi `evaluate_zone`.

### Không sửa

- `autoloads/GardenManager.gd`
- `scenes/garden/GardenScene.gd`
- `scenes/garden/SynergyZoneIndicator.gd`

## Tests to Write First

Cập nhật `tools/test_synergy_evaluator.gd`:

| Case | Setup | Expected |
|------|-------|----------|
| 2× same template, same synergy | 2× `flower_sun` | `active: false` |
| 2× distinct template, same synergy | `flower_sun` + `flower_periwinkle` (cùng synergy_a) | `active: true` |
| 3× same + 1 distinct, same synergy | 3× sun + 1 periwinkle | `active: true` |
| 1 occupied | 1× sun | `active: false` (giữ) |
| mixed synergy | sun + lotus | `active: false` (giữ) |
| `get_bonus_for_plot` | 2× distinct same synergy | bonus = 10 |
| `get_bonus_for_plot` | 2× same template | bonus = 0 |

Thêm template `flower_periwinkle` với `synergy_a` trong fixture.

**Sửa test hiện tại:** case `"two same synergy active"` → expect `false` (2× `flower_sun`).

## Steps

1. Viết/sửa test cases **trước** (TDD) — chạy, expect fail.
2. Sửa `evaluate_zone` thêm distinct `flower_template_id` check.
3. Chạy `godot --headless --script res://tools/test_synergy_evaluator.gd` → all passed.
4. Smoke: mock mode — trồng 2× periwinkle → không indicator; periwinkle + lotus (nếu cùng synergy mock) → có indicator.

## Verification

```bash
godot --headless --script res://tools/test_synergy_evaluator.gd
godot --headless --check-only --script res://domain/SynergyEvaluator.gd
```

## Acceptance

- [ ] `evaluate_zone` inactive khi chỉ 1 loài dù ≥2 cây
- [ ] `evaluate_zone` active khi ≥2 loài + cùng synergy
- [ ] Tests pass
- [ ] Không import Node/autoload trong domain
