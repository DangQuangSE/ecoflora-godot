# Spec: Zone Synergy Bonus (Hệ sinh thái theo Zone)

**Date:** 2026-06-12  
**Status:** Draft — pending user confirmation on edge cases

---

## Problem

Người chơi chưa có động lực chiến lược khi bố trí hoa theo vùng. Synergy data đã có trên BE (`XpPlus`, `CooldownMinus`) và được cache ở client, nhưng chưa ảnh hưởng gameplay.

## Goal

Khi **một zone** chỉ có các cây thuộc **cùng một Synergy**, mọi hành động chăm sóc (tưới / bón phân / phun thuốc) trên cây trong zone đó nhận thêm **`xpPlus`** từ Synergy đó.

---

## User Stories

### P1 — Core bonus (must ship)

| ID | Story | Acceptance |
|----|-------|------------|
| P1-1 | Là người chơi, khi zone của tôi chỉ có hoa cùng 1 Synergy, tôi nhận thêm XP khi tưới/bón/phun | Care XP = base item XP + synergy.xpPlus |
| P1-2 | Là người chơi ở chế độ BE, bonus XP do server tính — client không thể tự cộng | BE `CareForFlowerAsync` áp bonus; response trả tổng XP thực tế |
| P1-3 | Là người chơi mock, optimistic UI phản ánh bonus ngay | Mock path dùng cùng rule domain; rollback nếu BE fail |

### P2 — Feedback (should ship)

| ID | Story | Acceptance |
|----|-------|------------|
| P2-1 | Là người chơi, tôi thấy zone đang active synergy | **Zone particle/icon** hiển thị khi active + float label bonus khi care |
| P2-2 | Là người chơi, khi trồng/harvest làm mất điều kiện synergy, bonus dừng ngay | Re-evaluate sau plant/harvest; care tiếp theo không bonus |

### P3 — Cooldown bonus (defer)

| ID | Story | Acceptance |
|----|-------|------------|
| P3-1 | Synergy `cooldownMinus` giảm thời gian chờ care | **Out of scope** — chỉ `xpPlus` trong phase này |

---

## Business Rules (proposed defaults — confirm in plan review)

| Rule | Default |
|------|---------|
| Zone membership | 7 zones × 8 plots, khớp `GardenService.ZoneDefinitions` (plot index 0–55) |
| Điều kiện active | **≥ 2** plot occupied trong zone; **mọi** plot occupied phải có `synergy_id` giống nhau và **không rỗng** |
| Empty plots | **Bỏ qua** — ô trống không tính |
| Hoa không thuộc Synergy (`synergy_id` null/empty) | Coi là **không đồng nhất** → không bonus nếu có bất kỳ cây nào null synergy |
| Mixed synergies | Không bonus |
| Actions áp dụng | WATER, FERTILIZE, PESTICIDE only (không plant/harvest) |
| Bonus stack | Flat `xpPlus` mỗi lần care, không nhân theo số cây |

---

## Success Criteria (measurable)

1. Zone có **≥ 2** cây cùng Synergy "Sun Chaser" (xpPlus=10): tưới 1 cây → +20 base +10 bonus = **30 XP** (mock water).
2. Zone có **1** cây Sun Chaser duy nhất → care → **chỉ base XP** (chưa đủ 2 cây).
3. Zone có 2 cây Sun Chaser + 1 cây Water Lover → care → **chỉ base XP** (mixed).
4. BE mode: client optimistic có thể sai ±bonus; sau 200 response, `current_xp` khớp server.
5. Zone active synergy → **particle/icon** visible trên zone; mất điều kiện → ẩn ngay.

---

## Out of Scope

- `cooldownMinus` gameplay
- Adjacency-based synergy (SRS cũ: "cạnh nhau") — **zone purity** thay thế
- Synergy CRUD / admin UI
- Quest "maintain synergy 7 days"

---

## Resolved Decisions (2026-06-12)

| Question | Decision |
|----------|----------|
| Empty plots | Bỏ qua — chỉ xét cây đang trồng |
| Minimum occupied | **≥ 2 cây** cùng Synergy |
| UI P2 | **Zone particle/icon** khi active + float label khi care |
