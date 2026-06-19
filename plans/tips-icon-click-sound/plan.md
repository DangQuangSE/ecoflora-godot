# Plan: Tips Icon Click Sound — Dùng click.wav khi bấm icon sách

Status: ✅ Complete
Date: 2026-06-19
Mode: Fast

## Overview

Khi người chơi bấm icon sách (`tip_icon_v2.png`) trên `VitalityBar`, phát âm thanh `res://sounds/click.wav` thay vì `item_bag_click.wav` hiện đang phát từ `TipsPanel.show_panel()` / `hide_panel()`.

## Scope Challenge

| | |
|---|---|
| **Exists?** | Có — nút Tips đã hoạt động; âm thanh sai do `TipsPanel` dùng `item_bag_click.wav` |
| **Minimum?** | Phát `click.wav` tại `VitalityBar` khi bấm TipsButton; gỡ `item_bag_click` khỏi open/close panel khi toggle qua icon |
| **Complexity** | Fast — 1–2 file scenes, pattern `AudioManager.play_sfx` đã có sẵn |

## Phases

- [x] Phase 1: Wire click.wav tại TipsButton + dọn âm thanh trùng trong TipsPanel

## Architecture Gate

| Check | Result |
|---|---|
| Layer | `scenes/` only |
| Dependency arrows | scenes → autoloads (AudioManager) — hợp lệ |
| domain/services | Không đụng |
| AudioManager | `click.wav` đã có trong `SFX_VOLUMES` |
| Manager→View | Không vi phạm — audio gọi từ scene, không signal ngược |
| Verdict | **PASS** |

## Root Cause

1. `VitalityBar.gd` không phát SFX khi bấm TipsButton.
2. `TipsPanel.gd` gọi `AudioManager.play_sfx("item_bag_click.wav")` trong `show_panel()` và `hide_panel()`.
3. `AudioManager._input` cố phát `click.wav` khi thả chuột, nhưng bị suppress vì `item_bag_click` vừa cập nhật `_last_other_sfx_time` trong 250ms.

## Dependencies

- `scenes/hud/VitalityBar.gd` — thêm SFX tại handler TipsButton
- `scenes/tips/TipsPanel.gd` — gỡ hoặc thay `item_bag_click` để tránh double/wrong sound
- `autoloads/AudioManager.gd` — không cần sửa
- `sounds/click.wav` — asset đã có

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-19
**Phase in progress:** complete
**Status:** click.wav wired at TipsButton; item_bag_click removed from TipsPanel

### Decisions made this session
- Dùng `suppress_click_sfx()` sau `play_sfx(click.wav)` để chỉ 1 tiếng khi bấm icon sách
- CloseBtn/dimmer dùng global click handler — không thêm SFX riêng
- Inventory giữ nguyên item_bag_click.wav

### Next immediate action
Smoke test trong Godot Editor (garden scene)

## Acceptance Criteria

- Bấm icon sách → nghe `click.wav` (không nghe `item_bag_click.wav`)
- Toggle đóng icon sách → vẫn nghe `click.wav`
- Đóng panel bằng CloseBtn hoặc dimmer → nghe `click.wav` (global handler)
- Không double SFX khi mở/đóng panel
