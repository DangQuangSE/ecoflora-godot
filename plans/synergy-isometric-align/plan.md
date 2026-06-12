# Plan: Synergy Indicator Isometric Alignment

**Status:** ✅ Complete  
**Date:** 2026-06-12  
**Mode:** Fast

## Problem

Emitter synergy dùng hình chữ nhật trục màn hình (ngang/dọc) trong khi lưới đất isometric (xéo ~32°).

## Solution

Tính `axis_u` từ 3 plot anchor đầu zone → xoay indicator theo `axis_u.angle()` → emitter + hướng bay theo local Y (lên đỉnh kim cương).

## Phase 1 (scenes only)

- `GardenScene._zone_isometric_layout()` — centroid, axis_u, plot globals
- `SynergyZoneIndicator.setup()` — rotation + emitter theo local bounds
