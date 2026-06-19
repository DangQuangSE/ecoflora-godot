# Phase 1: Tips Icon Click Sound

testing: default

## Layer

`scenes/`

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/hud/VitalityBar.gd` | scenes | MODIFY — phát `click.wav` khi TipsButton pressed |
| `scenes/tips/TipsPanel.gd` | scenes | MODIFY — gỡ `item_bag_click.wav` khỏi show/hide panel |

---

## Requirements

Khi bấm icon `tip_icon_v2.png` (TipsButton trong VitalityBar):

- Phát `AudioManager.play_sfx("res://sounds/click.wav")`
- Không phát `item_bag_click.wav` từ TipsPanel trong cùng thao tác toggle

---

## Steps

### 1. VitalityBar.gd

Thay lambda hiện tại:

```gdscript
_tips_btn.pressed.connect(func() -> void: tips_pressed.emit())
```

Bằng handler riêng:

```gdscript
func _on_tips_pressed() -> void:
	AudioManager.play_sfx("res://sounds/click.wav")
	tips_pressed.emit()
```

Wire trong `_ready()`:

```gdscript
_tips_btn.pressed.connect(_on_tips_pressed)
```

### 2. TipsPanel.gd

Xóa hai dòng trong `show_panel()` và `hide_panel()`:

```gdscript
AudioManager.play_sfx("res://sounds/item_bag_click.wav")
```

Lý do: toggle qua icon đã phát `click.wav` tại VitalityBar; CloseBtn và dimmer tap dùng global click handler của AudioManager.

### 3. Tránh double click.wav (optional guard)

Nếu sau smoke test vẫn nghe double click khi bấm icon sách, gọi `AudioManager.suppress_click_sfx()` ngay sau `play_sfx("click.wav")` trong `_on_tips_pressed` để global `_input` không phát thêm lần nữa.

---

## Success Criteria

- [ ] Bấm icon sách mở panel → chỉ nghe `click.wav`
- [ ] Bấm lại icon sách đóng panel → chỉ nghe `click.wav`
- [ ] Bấm CloseBtn đóng panel → nghe `click.wav` (global)
- [ ] Tap dimmer đóng panel → nghe `click.wav` (global)
- [ ] Không regression: inventory/shop vẫn dùng `item_bag_click.wav` như cũ

---

## Smoke Test Checklist

1. Chạy main scene (garden view)
2. Bấm icon sách → TipsPanel mở → xác nhận âm thanh click nhẹ (click.wav), không phải tiếng túi đồ
3. Bấm lại icon sách → panel đóng → cùng âm click
4. Mở panel → bấm CloseBtn → click sound
5. Mở panel → tap vùng tối (dimmer) → click sound
6. Mở inventory → vẫn nghe item_bag_click (không bị ảnh hưởng)

---

## Risks

| Risk | Mitigation |
|---|---|
| Double click.wav (explicit + global) | Dùng `suppress_click_sfx()` sau play nếu cần |
| Mất âm thanh khi đóng bằng CloseBtn | Global AudioManager `_input` vẫn phát click.wav |
| Scope creep sang inventory sound | Chỉ sửa TipsPanel, không đụng InventoryPanel |
