# Spec: Daily Task System

**Date:** 2026-06-15
**Status:** Draft

---

## Problem Statement

Người chơi không có lý do để mở app mỗi ngày sau khi đã trồng hoa. Daily Task tạo engagement loop hằng ngày/tuần, thưởng currency + item + XP cho các hành động core của game (tưới cây, harvest, focus session, online time).

---

## User Stories

- **[P1]** Là người chơi, tôi muốn xem danh sách task hôm nay cùng progress hiện tại để biết mình cần làm gì.
  Accepted when: Panel hiện ≥ 3 daily task, mỗi task có tên, progress (X/N), và trạng thái (chưa xong / có thể nhận / đã nhận).

- **[P1]** Là người chơi, khi tôi tưới cây / harvest / làm focus session, progress task tương ứng tự động tăng mà không cần bấm gì thêm.
  Accepted when: Sau khi water 1 lần, task "Tưới cây 3 lần" cập nhật từ 0/3 → 1/3 trong UI ngay lập tức.

- **[P1]** Là người chơi, khi task hoàn thành 100%, tôi bấm "Nhận" và nhận được reward (currency / seed / XP).
  Accepted when: POST /api/daily-tasks/{id}/claim trả 200, inventory và currency trong game cập nhật ngay.

- **[P1]** Task daily reset lúc 7:00 AM mỗi ngày, task weekly reset lúc 7:00 AM Thứ Hai.
  Accepted when: Sau 7h sáng, tất cả task daily quay về 0/N và trạng thái "chưa xong".

- **[P2]** Là người chơi, tôi muốn xem tab riêng cho Daily và Weekly task (như screenshot reference).
  Accepted when: ShopScene-style tab, switch giữa Daily / Weekly không reload.

- **[P2]** Task "Online X phút/ngày" track thời gian người chơi mở app và tự cập nhật mỗi phút.
  Accepted when: Timer client-side tăng mỗi 60s, task cập nhật progress, không cần kết nối mạng liên tục.

- **[P3]** _(Battle Pack — bonus reward cho subscriber — out of scope cho EXE2)_

---

## Functional Requirements

1. **FR-01** — `TaskManager` autoload mới: lắng nghe signals (`care_completed`, `harvest_completed`, `session_completed`, `login_succeeded`), track progress in-memory, persist vào `user://daily_task_progress.json`.

2. **FR-02** — Thêm signal `care_completed(plot_id: String, action_type: int)` vào `GardenManager` (emit sau mỗi water/fertilize/pesticide thành công, cả mock lẫn real).

3. **FR-03** — Task definition lấy từ `GET /api/daily-tasks` (BE trả về list tasks + progress của user hiện tại). Fallback hardcode nếu offline.

4. **FR-04** — Claim reward qua `POST /api/daily-tasks/{id}/claim`. BE validate progress ≥ target trước khi grant reward.

5. **FR-05** — Online timer: `TaskManager` có `Timer` node, tick mỗi 60s khi app focused, cộng vào online_minutes của ngày hiện tại.

6. **FR-06** — Reset detection: khi load task list, compare `serverTime` từ BE với `lastResetTime` lưu local. Nếu đã qua 7h AM → clear progress local.

7. **FR-07** — UI: `DailyTaskScene` (CanvasLayer hoặc Panel) hiển thị tab Daily / Weekly, danh sách card task (icon + title + progress bar + claim button).

8. **FR-08** — Task types được support (P1): `GARDEN_CARE` (water/fertilize/pesticide), `HARVEST`, `FOCUS_SESSION`, `ONLINE_TIME`.

---

## Non-Functional Requirements

- Claim API: latency < 2s trên kết nối 4G bình thường.
- Progress update local: < 16ms (synchronous signal handler, không async).
- `user://daily_task_progress.json` < 10KB (chỉ lưu {taskId, progress, claimed, periodStart}).
- Không gọi API khi progress tăng — chỉ gọi khi claim.

---

## BE Schema (eco-backend)

```
DailyTask {
  id: UUID
  title: String
  description: String
  type: Enum [GARDEN_CARE, HARVEST, FOCUS_SESSION, ONLINE_TIME]
  actionSubtype: Nullable String  // "water" | "fertilize" | "pesticide" | null
  target: Int
  cycle: Enum [DAILY, WEEKLY]
  reward: JSON { currency?: Int, items?: [{itemId, qty}], xp?: Int }
  isActive: Bool
}

UserTaskProgress {
  id: UUID
  userId: UUID
  taskId: UUID
  progress: Int
  claimed: Bool
  periodStart: DateTime  // 7AM ngày hiện tại (daily) hoặc 7AM thứ Hai (weekly)
}
```

Endpoints cần build:
- `GET /api/daily-tasks` → list tasks + progress của user (join UserTaskProgress)
- `POST /api/daily-tasks/:id/claim` → validate + grant reward + mark claimed=true

---

## Success Criteria

- [ ] 3 daily task hiển thị đúng progress sau khi login
- [ ] Tưới cây 1 lần → task "Tưới X lần" tăng 1 trong vòng < 1s (local update)
- [ ] Claim thành công → currency trong HUD cập nhật ngay, nút "Nhận" chuyển thành "Đã nhận"
- [ ] Sau 7:00 AM ngày hôm sau → tất cả daily task reset về 0/N
- [ ] Không có ERR_BUSY hay crash khi switch tab nhanh

---

## Out of Scope

- Battle Pack / subscription monetization
- Admin UI để config task list
- Push notification khi task hoàn thành
- Task liên quan đến Decoration / Zone unlock
- Anti-cheat / server-side action validation (trust client progress cho EXE2)

---

## Assumptions

- BE team build DailyTask controller + entity + migration song song với Godot side.
- Server timezone là UTC+7 (Việt Nam). Reset 7:00 AM UTC+7.
- Task list không thay đổi trong ngày (không cần real-time subscription).
- `care_completed` signal có thể thêm vào GardenManager mà không conflict với Synergy code.

---

## Decisions (resolved)

- **Task count**: 5 daily + 3 weekly
- **BE reset**: Cron job server chạy lúc 7:00 AM UTC+7 — reset `UserTaskProgress` (set `progress=0`, `claimed=false`, tạo `periodStart` mới)
- **Weekly scope**: Demo đầy đủ cả Daily + Weekly tab
