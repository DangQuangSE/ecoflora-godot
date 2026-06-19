# Plan: Tips Guidebook — Database-Driven (Simplified)

Status: ✅ Complete
Date: 2026-06-19 (revised)
Mode: Hard

## Overview

Chuyển **Mẹo Chơi** từ hardcode sang PostgreSQL. Mỗi tip = **một bản ghi đơn giản** (`title` + `content`). Admin CRUD qua Swagger; client `GET /api/gametips`.

## Phases

- [x] Phase 1: [BE Domain](phase-01-be-domain.md) — `GameTip` table + seeder 1 tip synergy merged
- [x] Phase 2: [BE API](phase-02-be-api.md) — `GET/POST/PUT/DELETE /api/gametips`
- [x] Phase 3: [Godot Service](phase-03-godot-service.md) — `TipService` + `TipManager` flat list
- [x] Phase 4: [Godot Scenes](phase-04-godot-scenes.md) — `TipsPanel` 1 paragraph/tab

## Defaults (no further input needed)

| Topic | Choice |
|-------|--------|
| Admin UI | Swagger only |
| Offline fallback | 1 merged tip trong `TipCatalog` |
| Public read | `GET /api/game-tips` AllowAnonymous |
| Sort | `SortOrder` integer |

## Risks

| Risk | Mitigation |
|------|------------|
| Nhiều tab trên mobile | Tab bar scroll horizontal nếu >4 tips (phase 4) |
| Copy synergy gộp 1 đoạn | Draft trong seeder, admin chỉnh Swagger |
| Breaking `GameTip.body` / `category_id` | Phase 3 đổi sang `content`, bỏ category |

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-19
**Phase in progress:** complete
**Status:** All 4 phases implemented — BE GameTips CRUD + Godot TipManager + simplified TipsPanel

### Decisions made this session
- Single `GameTips` table — no category entity
- Public route `/api/gametips` (ASP.NET controller naming)
- `TipCatalog` retained as offline fallback with 1 merged synergy tip
- TipsPanel: one tab per tip, content = title + single paragraph

### Next immediate action
Run `dotnet ef database update` on BE; smoke test in Godot Editor
