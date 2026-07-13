# Spec: Hợp nhất LoadingScreen cho DownloadManager

**Date:** 2026-07-13
**Status:** Ready

---

## Problem Statement
Hiện tại ứng dụng đang có hai giao diện tải riêng biệt: `LoadingScreen` (dùng khi chuyển cảnh) và giao diện nội bộ của `DownloadManager` (khi tải file `assets.pck`). Điều này gây mất đồng bộ về mặt thẩm mỹ và trải nghiệm người dùng. Cần gỡ bỏ giao diện của `DownloadManager` và tái sử dụng `LoadingScreen`.

---

## User Stories

- **[P1]** As a player, I want to see the main `LoadingScreen` when the game is downloading assets, so that the experience is seamless and consistent.
  Accepted when: `DownloadManager` calls `LoadingScreen.show_loading()` and updates progress via `LoadingScreen.set_progress()`.

---

## Functional Requirements

1. FR-01: Xoá bỏ các Node UI dư thừa trong scene `DownloadManager.tscn` (status_label, progress_bar, retry_button).
2. FR-02: Cập nhật script `download_manager.gd` để gọi trực tiếp tới `LoadingScreen` khi bắt đầu tải file: `LoadingScreen.show_loading()`.
3. FR-03: `download_manager.gd` cần tính toán phần trăm tải và gọi `LoadingScreen.set_progress(value)` trong hàm `_process()`.
4. FR-04: Khi hoàn tất hoặc lỗi tải, `download_manager.gd` sẽ gọi `LoadingScreen.hide_loading()` trước khi thao tác tiếp (chuyển cảnh sang MAIN_SCENE hoặc xử lý khác).

---

## Non-Functional Requirements

- Performance: Tiến trình tải phải được cập nhật liên tục mượt mà.
- UX: Các mẹo (tips) trong `LoadingScreen` vẫn phải hoạt động bình thường trong quá trình tải `.pck`.

---

## Success Criteria

- [ ] UI cũ trong `DownloadManager`: Bị xoá bỏ hoàn toàn.
- [ ] Chuyển trạng thái: `DownloadManager` hiển thị `LoadingScreen` và cập nhật đúng thanh tiến trình (từ 0.0 đến 1.0) khi đang download file từ internet.

---

## Out of Scope

- Thêm chức năng Retry thủ công hoặc hiển thị log lỗi chi tiết lên màn hình (người dùng đã yêu cầu bỏ qua).

---

## Assumptions

- `LoadingScreen` đã được thiết lập là một AutoLoad (Singleton) trong Project Settings hoặc có thể truy cập dễ dàng. Nếu `LoadingScreen` chưa phải AutoLoad, cần phải khai báo nó trong AutoLoad của Project Settings.

---

## [NEEDS CLARIFICATION]

