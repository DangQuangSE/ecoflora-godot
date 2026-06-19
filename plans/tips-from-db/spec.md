# Spec: Tips Guidebook — Database-Driven (Simplified)

## Problem

Tips hiện hardcode trong `domain/TipCatalog.gd` với cấu trúc phức tạp: category → nhiều mẹo con (title + body từng phần). Admin không sửa được; UI khó đọc vì chia quá nhiều tiểu mục.

## Goal

Mỗi mẹo chơi là **một bản ghi đơn giản**: **tiêu đề** (vd. "Hệ Sinh Thái") + **một đoạn nội dung** (plain text, dễ hiểu). Admin CRUD qua API; client fetch và hiển thị.

**Không có category / chủ đề lồng nhau.**

## UI Model (theo screenshot + yêu cầu user)

```
Panel "Mẹo Chơi"
├── Tab bar: mỗi tip.title → một tab (vd. "Hệ Sinh Thái", "Thu Hoạch", ...)
└── Vùng scroll (tab đang chọn):
    ├── Tiêu đề lớn (tip.title)     ← header vàng như hiện tại
    └── Một đoạn văn (tip.content)  ← KHÔNG chia sub-heading
```

Nhiều tip → nhiều tab. Một tip → một tab (vẫn hiện tab bar để sẵn mở rộng).

## User Stories

### P1 — Must have

| ID | Story | Acceptance |
|----|-------|------------|
| P1-1 | Admin tạo/sửa/xóa tip | `POST/PUT/DELETE /api/game-tips` với JWT Admin |
| P1-2 | Player mở Mẹo Chơi, thấy tip từ server | `GET /api/game-tips` trả danh sách flat, sorted |
| P1-3 | Mỗi tip chỉ có title + content | Không FK category, không nested tips |
| P1-4 | DB seed sẵn tip "Hệ Sinh Thái" | Một đoạn văn gộp nội dung synergy hiện tại |

### P2 — Should have

| ID | Story | Acceptance |
|----|-------|------------|
| P2-1 | Client cache sau fetch | `user://tips_cache.json` |
| P2-2 | Fallback offline | 1 tip synergy merged trong `TipCatalog` |

### P3 — Out of scope v1

- Web admin dashboard (Swagger only)
- i18n, markdown, category grouping

## API Contract

### `GET /api/game-tips` — `[AllowAnonymous]`

```json
{
  "isSuccess": true,
  "message": "Tips retrieved",
  "data": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "title": "Hệ Sinh Thái",
      "content": "Vườn chia thành nhiều zone. Khi mọi cây trong zone cùng nhóm Synergy (ít nhất 2 cây), bạn nhận bonus XP khi tưới/bón. Zone active có hiệu ứng lấp lánh. Bonus mất khi trộn Synergy hoặc còn dưới 2 cây.",
      "sortOrder": 0
    }
  ]
}
```

Chỉ trả `IsActive = true`, `IsDeleted = false`, sort `SortOrder` ASC.

### Admin CRUD — mirror `ItemsController`

| Method | Route | Auth |
|--------|-------|------|
| GET | `/api/game-tips` | Anonymous |
| GET | `/api/game-tips/{id}` | Anonymous |
| POST | `/api/game-tips` | Admin, SuperAdmin |
| PUT | `/api/game-tips/{id}` | Admin, SuperAdmin |
| DELETE | `/api/game-tips/{id}` | Admin, SuperAdmin |

## Entity Model (BE) — single table

### `GameTip`

| Field | Type | Notes |
|-------|------|-------|
| Id | Guid | PK |
| Title | string | tab label + header trong panel |
| Content | string | một đoạn văn plain text |
| SortOrder | int | thứ tự tab |
| IsActive | bool | default true |
| + BaseEntity | | soft delete, audit |

## Godot Domain

### `GameTip` (simplify)

- `id: String`
- `title: String`
- `content: String` (đổi từ `body`; bỏ `category_id`)

### `TipCatalog` — offline fallback only

- Trả `Array[GameTip]` flat, 1 entry synergy merged

## Seeder Content Draft — "Hệ Sinh Thái"

Dùng cho Phase 1 seeder (admin có thể sửa sau):

> Vườn của bạn chia thành nhiều zone. Khi trong cùng một zone có từ 2 cây trở lên thuộc cùng nhóm Synergy (ô trống không tính), zone được coi là "thuần" và kích hoạt bonus XP. Khi synergy đang active, tưới nước hoặc bón phân trên bất kỳ cây nào trong zone đều cộng thêm XP. Zone đang có synergy sẽ hiện hiệu ứng lấp lánh; khi chăm sóc bạn thấy nhãn +XP và +🌿 bonus. Bonus mất khi trộn hai nhóm Synergy, trồng cây không có Synergy, hoặc sau thu hoạch còn dưới 2 cây.

## Success Criteria

- [ ] Admin POST tip mới → game thấy tab + nội dung mới
- [ ] Tab "Hệ Sinh Thái" hiển thị **một** đoạn văn, không còn 5 tiểu mục
- [ ] `dotnet build` + Godot check pass
