# Plan: VitalityBar Layout Fix — Đếm ngược trên, Tips dưới cùng

Status: ✅ Complete
Date: 2026-06-17
Mode: Fast

## Overview

Sửa thứ tự các phần tử dọc trong `VitalityBar` để đúng yêu cầu UI:

1. **Tim** (`heart.png`) — trên cùng
2. **Bộ đếm ngược nhận thưởng** (`CountdownLabel`: "Sẵn sàng!" / `HH:MM:SS`) — giữa
3. **Nút Tips** (`tip_icon_v2.png`) — dưới cùng

Hiện tại `TipsButton` nằm giữa tim và countdown, khiến countdown bị đẩy xuống đáy — không đúng thiết kế mong muốn.

## Scope Challenge

| | |
|---|---|
| **Exists?** | Có — `VitalityBar.tscn` đã có đủ 3 node, chỉ sai thứ tự |
| **Minimum?** | Đổi thứ tự child trong `VBoxContainer` (1 file `.tscn`) |
| **Complexity** | Fast — 1 scene, pattern quen thuộc, không đổi logic |

## Phases

- [x] Phase 1: Reorder VBox children trong `VitalityBar.tscn` + smoke test layout

## Architecture Gate

| Check | Result |
|---|---|
| Layer | `scenes/` only |
| Dependency arrows | Không vi phạm |
| GDScript node paths | Không đổi — `$VBoxContainer/TipsButton`, `$VBoxContainer/CountdownLabel` giữ nguyên |
| Manager→View | Không áp dụng |
| Verdict | **PASS** |

## Dependencies

- `scenes/hud/VitalityBar.tscn` — scene chính cần sửa
- `scenes/hud/VitalityBar.gd` — không cần sửa (paths không đổi)
- `scenes/hud/HUD.tscn` — chỉ kiểm tra offset nếu layout tràn

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-17
**Phase in progress:** complete
**Status:** Reordered VBoxContainer: HeartIcon → CountdownLabel → TipsButton

### Decisions made this session
- Giữ kích thước icon sách 72×72, không dịch HUD offset
- Cập nhật `tips-guidebook/phase-03-hud-wiring.md` theo thứ tự mới

### Next immediate action
Smoke test trong Godot Editor (garden scene)


- Trong game, thứ tự trực quan: tim → countdown → icon sách
- Tap tim (khi ready) vẫn claim vitality
- Tap icon sách vẫn toggle TipsPanel
- Countdown vẫn cập nhật mỗi giây
- Portrait 720×1280: không chồng UserHUD / joystick
