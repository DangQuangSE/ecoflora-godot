# Spec: Plot Texture Swap

**Feature:** Thay thế ô đất ColorRect bằng custom sprite có 2 trạng thái visual
**Scope:** `scenes/garden/Plot.tscn` + `scenes/garden/Plot.gd`

---

## Problem

`PlotSprite` hiện là `ColorRect` màu nâu cứng (64×64). Cần thay bằng custom assets có hồn hơn và phản ánh trạng thái tưới nước.

---

## User Stories

| Priority | Story |
|----------|-------|
| P1 | Khi mở game, mỗi ô đất hiển thị `plot.png` thay vì ô màu nâu |
| P1 | Khi ô có cây VÀ `last_watered_at + 3600 > now`, hiển thị `sweet_plot.png` |
| P1 | Khi cooldown hết hoặc ô trống, quay về `plot.png` |
| P2 | Visual cập nhật ngay lập tức sau khi server confirm hành động tưới |

---

## Technical Design

### Node change
```
PlotSprite: ColorRect → Sprite2D
  texture = plot.png (default)
  centered = true
  (remove color property)
```

### Preloads trong Plot.gd
```gdscript
const TEXTURE_NORMAL  := preload("res://assets/plot/plot.png")
const TEXTURE_WATERED := preload("res://assets/plot/sweet_plot.png")
const WATER_COOLDOWN  := 3600
```

### Logic trong _refresh_visual()
```gdscript
# Texture swap
var now := int(Time.get_unix_time_from_system())
var is_watered := (
    plot.is_occupied
    and plot.current_plant != null
    and (now - plot.current_plant.last_watered_at) < WATER_COOLDOWN
)
plot_sprite.texture = TEXTURE_WATERED if is_watered else TEXTURE_NORMAL
```

---

## Success Criteria

- [ ] `plot.png` hiển thị đúng trên tất cả ô đất khi khởi động
- [ ] `sweet_plot.png` hiển thị ngay sau khi server confirm water action
- [ ] Sau 3600s, ô tự động quay về `plot.png` (khi `_refresh_visual()` được gọi tiếp theo)
- [ ] Không còn ô nâu ColorRect nào visible

---

## Out of Scope

- Timer/polling để auto-refresh visual sau 3600s — visual cập nhật lần tiếp theo khi có plot update từ server
- Animation transition giữa 2 trạng thái
