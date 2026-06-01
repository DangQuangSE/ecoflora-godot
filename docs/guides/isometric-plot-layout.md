# Isometric Plot Layout

## Công thức

Để xếp các ô đất (`PlotAnchor`) thành hình thoi isometric chuẩn:

```
col_step = (+half_w, +half_h)   # mỗi cột: phải + xuống
row_step = (-half_w, +half_h)   # mỗi hàng: trái + xuống
```

Với tile `plot.png` ở `scale = 0.3`, `region_rect` ~403×257 px:
- `half_w = 60`
- `half_h = 38`

Vị trí mỗi ô:
```
position(col, row) = origin + col * (60, 38) + row * (-60, 38)
```

## Ví dụ: 2 cột × 4 hàng (8 ô / khu)

```
origin = (360, 80)

(col=0,row=0) → (360, 80)    (col=1,row=0) → (420, 118)
(col=0,row=1) → (300, 118)   (col=1,row=1) → (360, 156)
(col=0,row=2) → (240, 156)   (col=1,row=2) → (300, 194)
(col=0,row=3) → (180, 194)   (col=1,row=3) → (240, 232)
```

Trông như thế này trên màn hình:

```
       [0]
     [2] [1]
   [4] [3]
 [6] [5]
   [7]
```

## Nhiều khu đất

Tách khu bằng offset dọc (~220px) để player di chuyển giữa hai khu:

| Khu | Origin | Plot index | Y range |
|-----|--------|-----------|---------|
| 1   | (360, 80)  | 0–7   | 80–232  |
| 2   | (360, 450) | 8–15  | 450–602 |

## Điều chỉnh kích thước tile

Nếu thay đổi `scale` của `PlotTexture`, tính lại `half_w` và `half_h`:

```
half_w = region_rect.width  * scale / 2
half_h = region_rect.height * scale / 2
```

## Cách xếp trong editor

Các ô đất được spawn từ `Marker2D` nodes trong node `PlotAnchors` của `GardenScene.tscn`.  
Kéo thẳng từng `PlotAnchor_N` trong Godot 2D editor để fine-tune vị trí.
