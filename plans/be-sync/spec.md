# Spec: BE Sync — Kết nối Godot client với .NET backend

**Date:** 2026-05-28
**Status:** Draft

---

## Problem Statement

Godot game client và .NET BE có domain models không khớp nhau. Cần lớp mapping trong `services/` để Godot có thể fetch, hiển thị và ghi dữ liệu thật từ BE thay vì chỉ dùng mock.

---

## User Stories

- **[P1]** As a player, I want my garden state (plots, planted flowers) to load from the real server so that progress persists across devices.
  Accepted when: GardenScene hiển thị đúng số plots và trạng thái cây từ BE response.

- **[P1]** As a player, I want my inventory to reflect what's actually stored on the server.
  Accepted when: InventoryPanel hiển thị đúng items/quantities từ BE `/api/inventory` (hoặc tương đương).

- **[P1]** As a player, I want my level and currency to sync with the server.
  Accepted when: UserHUD hiển thị Level và Currency từ `GET /api/auth/profile`.

- **[P1]** As a player, I want to log in with my account.
  Accepted when: Game gọi `POST /api/auth/login`, lưu accessToken, dùng token cho mọi request tiếp theo.

- **[P2]** As a player, I want my focus session result to be saved to the server when I finish.
  Accepted when: Sau khi FocusTimer kết thúc, BE nhận được duration và strike count.

- **[P2]** As a player, I want flower templates and item catalog to load from BE on startup.
  Accepted when: GardenManager dùng FlowerTemplate từ BE thay vì hardcode.

- **[P3]** _(out of scope — harvest_product tracking on BE side)_
- **[P3]** _(out of scope — XP field on BE User entity)_

---

## Functional Requirements

1. **FR-01 (Auth):** Game gọi `POST /api/auth/login` với `{ account, password }`, lưu `accessToken` + `refreshToken` local. Mọi request tiếp theo đính kèm `Authorization: Bearer <token>`.

2. **FR-02 (401 handling):** Khi nhận 401, clear accessToken và emit `login_required` — không silent refresh, không retry. Manager hủy request ngay. Player re-login thủ công qua UI.

3. **FR-03 (Garden fetch):** `GardenService` gọi BE lấy danh sách plots + planted flowers của user, mapper chuyển về `Array[Plot]` với `current_plant` đúng.

4. **FR-04 (Inventory fetch):** `InventoryService` gọi BE lấy danh sách inventory items, mapper chuyển `ItemId/FlowerTemplateId/DecorId nullable FK` → Godot `category enum + reference_id`.

5. **FR-05 (UserProfile fetch):** `UserService` gọi `GET /api/auth/profile`, mapper chuyển `{ Level, Currency }` → `UserProfile`.

6. **FR-06 (Reference data):** Khi boot, fetch `FlowerTemplate[]`, `Item[]`, `Synergy[]` từ BE và cache trong autoload tương ứng (GardenManager, InventoryManager).

7. **FR-07 (FocusSession push):** Khi session kết thúc (hoàn thành hoặc thất bại), gửi `{ duration_seconds, strikes, status }` lên BE.

8. **FR-08 (Mapping layer):** Mỗi service có `parse_*` function riêng, không để mapper logic vào autoload hay domain.

---

## Non-Functional Requirements

- **Latency:** Mỗi HTTP request timeout ≤ 10 giây. Boot fetch (reference data) không block game loop.
- **Security:** `accessToken` không lưu vào file — chỉ in-memory. `refreshToken` có thể lưu persistent.
- **Offline fallback:** Nếu fetch thất bại lúc boot, dùng mock data và hiện warning. Không crash game.

---

## Success Criteria

- [ ] Đăng nhập thành công với tài khoản thật, token được lưu và dùng cho request tiếp theo
- [ ] GardenScene load đúng plots từ BE (số lượng và trạng thái)
- [ ] InventoryPanel hiển thị đúng items từ BE
- [ ] UserHUD hiển thị Level + Currency từ BE profile
- [ ] FlowerTemplate catalog không còn hardcode — lấy từ BE
- [ ] FocusSession được gửi lên BE khi kết thúc, BE trả 200

---

## Out of Scope

- XP field trên BE (BE chỉ có Level — XP vẫn là Godot-only)
- harvest_product sync lên BE
- ZoneDefinition, StageDefinition, WeatherState — Godot-only
- Real-time multiplayer / WebSocket
- Offline sync / conflict resolution

---

## Assumptions

- BE chạy tại `http://localhost:5226` khi dev. URL config qua `@export` trên autoload.
- BE có endpoint trả về garden + planted flowers của user hiện tại (cần kiểm tra hoặc thêm vào BE).
- `accessToken` JWT đủ dùng cho toàn bộ game session (expiry ≥ 15 phút, refresh tự động).
- BE branch `feat/imple-godot` có thể đã có các endpoint game-specific — cần verify.

---

## [NEEDS CLARIFICATION]

- [x] BE **chưa có** garden/plot/planted-flower endpoint → cần implement ở BE trước khi sync garden. Phase garden bị block cho đến khi BE sẵn sàng.
- [ ] Thứ tự implement: Auth trước hay Reference data trước?
- [ ] `harvest_product` trong InventoryItem — giữ Godot-only hay yêu cầu BE support?
