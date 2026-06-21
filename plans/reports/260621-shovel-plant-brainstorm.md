# Brainstorm: Shovel (xúc cây) feature

**Date:** 2026-06-21

## Ideas Explored

- **Mode-toggle trigger (chosen)**: bấm icon shovel trên toolbar → vào "shovel mode" (giống harvest_mode hiện có với sickle), tap ô đất có cây để thực hiện. Tái dùng pattern InteractionManager đã có.
- **Per-plot context menu**: tap vào plot mở menu lựa chọn (water/harvest/shovel...) — bị loại vì user muốn giống đúng UX sickle hiện tại.
- **Instant action không confirm** (giống harvest hiện tại không có dialog) — bị loại, user yêu cầu bắt buộc có popup confirm vì hành động phá hủy progress (mất stage/XP).
- **Mock-only/local-first cho seed restore** — bị loại, user chọn gọi API thật ngay (cần endpoint BE mới).

## User's Direction

- Xúc cây bất kỳ lúc nào (không giới hạn theo stage/giai đoạn).
- Cây bị xúc → trở thành hạt giống Lv0, plot trống lại, +1 seed (đúng loại flower_template) vào bag.
- Trigger giống sickle: bấm `ShovelButton` trên HUD (đã có sẵn icon, chưa wiring) → vào shovel mode → tap plot có cây.
- Bắt buộc confirm popup trước khi xúc (do hành động hủy mất stage/XP đã trồng), dùng lại `BaseDialog` style hiện có (480×340, theme `GlobalTheme.tres`, background `dialog.png`).
- Shovel mode giữ nguyên (không tự tắt) sau mỗi lần xúc — cho xúc liên tục nhiều ô, khác với hành vi one-shot thường thấy.
- Cần đồng bộ BE thật ngay: tạo endpoint mới ở eco-backend (kiểu `dig_up` / `remove_plant`) trả về plot đã clear + inventory đã cộng seed, theo đúng optimistic UI pattern (`is_pending_sync` set trước await, clear sau khi có kết quả, rollback khi lỗi).

## Open Questions

- Endpoint cụ thể ở eco-backend: route path, request/response shape, có cần currency/XP side-effect nào không (ví dụ có hoàn lại 1 phần XP đã tích lũy hay không — hiện giả định KHÔNG, mất hoàn toàn).
- Hành vi khi người chơi bấm Cancel trên popup: giữ shovel mode để thử ô khác (giả định: có, không tự tắt mode).
- Có cần audit log / event riêng (ví dụ DigUpLog) ở BE hay không — hiện chưa thấy bảng tương tự HarvestLog trong eco-backend, cần xác nhận khi /ck:plan động tới phần BE.

## Risks

- **Mất dữ liệu không hoàn tác**: xúc cây xóa hẳn stage/XP đã đầu tư — confirm dialog là rào chắn duy nhất, cần copy đúng message rõ ràng tránh bấm nhầm.
- **Inconsistency giữa harvest_mode và dig_up_mode**: nếu cả hai mode có thể active cùng lúc sẽ gây nhầm UX (cần đảm bảo chỉ 1 mode active tại một thời điểm trong InteractionManager).
- **BE endpoint mới**: rủi ro lệch response format so với các endpoint khác (cần theo đúng convention JWT + response format đã ghi trong eco_backend_context).
