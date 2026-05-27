# Spec: Focus Mode (Chế độ Học Tập Trung)

**Date:** 2026-05-27
**Status:** Ready

---

## Problem Statement

Người chơi cần động lực tập trung học tập. Game tích hợp focus timer để vừa học vừa nhận phần thưởng cho vườn hoa, tạo vòng lặp hành vi tích cực.

---

## User Stories

- **[P1]** As a player, I want to walk from garden to the school scene so that I feel I'm "going to school" before studying.
  Accepted when: Portal từ GardenScene dẫn đến SchoolScene, player có thể di chuyển trong campus.

- **[P1]** As a player, I want to enter a classroom and set a focus timer so that I can start a study session.
  Accepted when: Player bước vào Area2D classroom → FocusTimerUI hiện ra → có thể chọn thời gian (5–120 phút) → nhấn Start.

- **[P1]** As a player, I want the game to detect when I leave the app during focus so that violations are counted.
  Accepted when: Mỗi lần app vào background trong lúc timer đang chạy → violation_count tăng 1, hiện thông báo trong game khi quay lại.

- **[P1]** As a player, I want to receive XP reward for all my plants when I complete a focus session so that studying feels rewarding.
  Accepted when: Khi timer về 0 và violations ≤ max_violations → tất cả plots có cây nhận +1 XP/phút tập trung.

- **[P1]** As a player, I want my plants to lose XP if I fail a focus session so that I'm motivated to stay focused.
  Accepted when: Khi violations > max_violations → session fail → tất cả plots có cây trừ 20 XP (không xuống dưới 0).

- **[P2]** As a player, I want to see a countdown timer overlay while focusing so that I know how much time is left.
  Accepted when: CanvasLayer hiển thị MM:SS đếm ngược, violation count, và nút Stop (cancel session).

- **[P2]** As a player, I want to walk around the FPT campus in the school scene so that the environment feels immersive.
  Accepted when: SchoolScene có background FPT-style, ít nhất 1 classroom có thể vào.

- **[P3]** Android Foreground Service — persistent notification, timer khi khóa máy _(out of scope — deferred)_

---

## Functional Requirements

1. **FR-01:** `FocusManager` autoload quản lý state machine: IDLE → SETUP → ACTIVE → COMPLETED / FAILED.
2. **FR-02:** `FocusSession` domain class (RefCounted) chứa: `duration_seconds`, `elapsed_seconds`, `violation_count`, `max_violations` (default=3).
3. **FR-03:** Khi app nhận `NOTIFICATION_APPLICATION_PAUSED` trong lúc state = ACTIVE → `violation_count += 1`; nếu vượt max → emit `session_failed`.
4. **FR-04:** Khi timer hoàn thành (elapsed >= duration) → emit `session_completed(minutes_focused: int)`.
5. **FR-05:** `GardenManager` lắng nghe `session_completed` → apply `+minutes_focused XP` cho tất cả cây đang có hoa.
6. **FR-06:** `GardenManager` lắng nghe `session_failed` → apply `-20 XP` cho tất cả cây (floor = 0).
7. **FR-07:** SchoolScene có Portal dẫn về GardenScene; player có thể exit focus bất cứ lúc nào (cancel session, không nhận reward).
8. **FR-08:** FocusTimerUI hiển thị: thời gian còn lại (MM:SS), violation count / max_violations, nút Cancel.

---

## Non-Functional Requirements

- Performance: Apply XP batch cho ≤ 16 plants trong 1 frame — không cần async.
- Platform: Chạy được trên Android (detection via `_notification()`) và PC (testing/demo).
- State persistence: Session state KHÔNG cần persist qua app kill (chấp nhận mất session nếu app bị kill).

---

## Success Criteria

- [ ] Player portal từ GardenScene → SchoolScene → vào classroom → FocusTimerUI hiện ra trong < 1 giây.
- [ ] Timer 5 phút chạy đến 0 → tất cả cây đang có hoa nhận đúng +5 XP.
- [ ] Minimize app 4 lần trong lúc timer chạy → session fail → cây trừ 20 XP (không âm).
- [ ] Minimize app 2 lần → quay lại → timer tiếp tục → hoàn thành bình thường → reward đúng.
- [ ] SchoolScene hiển thị với background, player di chuyển được, Portal về garden hoạt động.

---

## Out of Scope

- Android Foreground Service / persistent status bar notification
- Timer chạy khi app bị kill hoàn toàn
- NPC dialogue trong trường
- Multiple classrooms
- Admin config panel cho max_violations / penalty amount

---

## Assumptions

- GardenManager đã có method để apply XP delta cho tất cả cây (hoặc sẽ thêm trong implementation).
- Portal.disabled = true hiện tại — sẽ re-enable cho school portal trong phase này.
- Background art FPT campus: dùng Sprite2D static PNG (cùng approach với garden background).
- max_violations = 3 hardcoded, penalty = 20 XP hardcoded cho MVP.
