# Plan: Cloudinary Asset Pack
**Mode:** Fast
**Test:** --no-test

## Phases
1. **[Phase 1]** Giao diện Loading Scene (UI)
   - File: `phase-01-ui.md`
2. **[Phase 2]** Logic Version Check (Kiểm tra cập nhật)
   - File: `phase-02-version-check.md`
3. **[Phase 3]** Logic Download & Mount (Tải & Gắn Resource)
   - File: `phase-03-download-mount.md`

## Risks
- File `.pck` tải giữa chừng bị lỗi, cần tính năng xoá file rác để tải lại từ đầu nếu gặp lỗi.
- Đảm bảo version local chỉ được cập nhật sau khi tải thành công file `.pck`, tránh việc tải lỗi nhưng version đã lưu là bản mới.
