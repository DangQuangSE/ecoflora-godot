# Hướng dẫn Godot — Zone Synergy Bonus

Tài liệu này hướng dẫn kiểm tra và tinh chỉnh hiệu ứng **Synergy Zone** sau khi code đã được implement.

---

## 1. Mở Scene và kiểm tra cấu trúc Node

1. Mở Godot 4 → **FileSystem** → double-click `res://scenes/garden/GardenScene.tscn`
2. Scene tree chính:
   - `GardenScene` (Node2D) — scene gốc vườn
   - `PlotAnchors` — các điểm neo cho từng ô đất (plot_0 … plot_55)
   - `Player`, `HUD`, `Background`
3. Sau khi chạy game, `GardenScene` tự spawn:
   - `SynergyZoneIndicator` × 7 (một indicator mỗi zone)
   - `Plot` nodes từ `Plot.tscn`

---

## 2. Hiệu ứng SynergyZoneIndicator

1. **FileSystem** → `res://scenes/garden/SynergyZoneIndicator.tscn`
2. Scene tree (không còn icon tĩnh):

```
SynergyZoneIndicator (Node2D)
└── RiseSparkles (CPUParticles2D)  ← hạt lấp lánh bay thẳng lên từ mép đất zone
```

3. Vị trí/size tự fit theo 8 ô plot của zone (tính từ `PlotAnchors`).

---

## 3. Cài đặt Inspector (tùy chọn tinh chỉnh)

Mở `SynergyZoneIndicator.tscn`:

| Node | Property | Gợi ý |
|------|----------|-------|
| Icon | Modulate | Xanh nhạt `(0.45, 1, 0.55, 0.85)` |
| Icon | Scale | `0.35, 0.35` |
| Particles | Amount | `12` |
| Particles | Color | Xanh `(0.5, 1, 0.6, 0.7)` |

Thay texture Icon: kéo PNG lá/sparkle vào **Inspector → Icon → Texture**.

---

## 4. Wiring Signals

Đã wire qua code — **không cần kết nối thủ công**:

| Signal | Nguồn | Nhận |
|--------|-------|------|
| `plots_updated` | `GardenManager` | `GardenScene._on_plots_updated` → `_refresh_synergy_indicators()` |
| `plant_xp_gained` | `GardenManager` | `PlotNode._on_plant_xp_gained` → float label |

---

## 5. Smoke Test Checklist

- [ ] Trồng **2 cây cùng Synergy** trong cùng zone → icon + particle xuất hiện ở giữa zone
- [ ] Chỉ **1 cây** → không có indicator
- [ ] Trồng cây thứ 3 **khác Synergy** → indicator **tắt ngay**
- [ ] Tưới cây khi synergy active → float label `+20 XP` và `+10 🌿` (mock water + Sun Chaser)
- [ ] Harvest 1 cây (còn 1) → indicator tắt

### Mock mode (Inspector)

1. Chọn autoload `GardenManager` → bật **Use Mock** = `true`
2. Trồng `periwinkle` × 2 (Sun Chaser, +10) hoặc `lotus` × 2 (Water Lover, +5)

### BE mode (`use_mock = false`)

Synergy **vẫn hoạt động** nếu đủ 3 điều kiện:

1. **Login** — catalog tải sau login (`/api/synergies`, `/api/flowertemplates`)
2. **DB có Synergy** — restart API để Seeder chạy (3 synergy mặc định: Water Lover, Sun Chaser, Night Bloom)
3. **Hoa có `synergyId`** — trồng ≥2 cây cùng synergy trong 1 zone (vd. 2× `sun_flower`)

**Lưu ý timing:** indicator refresh khi `icons_registered` (sau catalog load) và mỗi lần `plots_updated`.

Nếu không thấy hiệu ứng, mở **Output** → tìm warning `synergy catalog empty`.

**Test nhanh BE:**
1. Restart API (Seeder gán synergy cho flower templates có sẵn)
2. Login player → vào vườn
3. Mua/trồng 2 hạt `sun_flower` cùng zone → hiệu ứng lấp lánh quanh zone
4. Tưới → XP = base + 10 (Sun Chaser)

---

## 6. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| Không thấy indicator | Chưa đủ 2 cây cùng Synergy | Trồng thêm cây cùng nhóm |
| Indicator không tắt sau harvest | `plots_updated` chưa fire | Kiểm tra GardenManager emit sau harvest |
| Bonus XP = 0 (mock) | `_synergy_cache` rỗng | Bật `use_mock` — `_seed_mock_synergies()` tự chạy |
| Indicator lệch vị trí | PlotAnchors thiếu node | Kiểm tra `PlotAnchors` có đủ 56 anchor |

---

## 7. Chạy test tự động (domain)

```bash
godot --headless --script res://tools/test_synergy_evaluator.gd
```

Kết quả mong đợi: `SynergyEvaluator tests: all passed`
