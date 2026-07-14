# Spec: Cloudinary Asset Pack

**Date:** 2026-07-13
**Status:** Ready

---

## Problem Statement
Dự án game Godot hiện đang lưu asset ảnh trực tiếp trong bộ cài, làm dung lượng file game bị nặng. Cần đưa các asset này lên Cloudinary dưới dạng Resource Pack (.pck), tải về và lưu cục bộ khi người chơi vào game để tối ưu hoá dung lượng ban đầu.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a Người chơi, I want to thấy một màn hình Loading (có Progress Bar) so that tôi biết game đang tải dữ liệu và không bị treo.
  Accepted when: Màn hình hiển thị % tiến trình tải file `.pck` mượt mà, từ 0% đến 100%.

- **[P1]** As a Hệ thống (Game Client), I want to kiểm tra version trên Cloudinary so that tôi biết nên dùng file `.pck` cũ trong máy hay tải bản cập nhật mới.
  Accepted when: Game request file `version.json` trên Cloudinary, so sánh với bản local và tự động tải nếu có phiên bản mới hơn.

- **[P2]** As a Nhà phát triển, I want to có thể thay file `.pck` trên Cloudinary so that cập nhật asset game mà không cần phải ra bản build mới (APK/EXE).
  Accepted when: Thay `.pck` và `version.json` trên server, người chơi tự động nhận update vào lần mở game tiếp theo.

---

## Functional Requirements

1. FR-01: Có 1 Loading Scene độc lập (ví dụ `DownloadManager.tscn`) chạy đầu tiên.
2. FR-02: Game sử dụng `HTTPRequest` để tải `version.json` từ Cloudinary và đọc nội dung JSON (chứa version ID và URL file).
3. FR-03: Game sử dụng một `HTTPRequest` (bật tính năng `download_file`) để tải trực tiếp file `.pck` vào thư mục `user://`.
4. FR-04: Cập nhật giao diện Progress Bar sử dụng `get_downloaded_bytes()` và `get_body_size()`.
5. FR-05: Gọi `ProjectSettings.load_resource_pack("user://assets.pck")` sau khi tải thành công (hoặc khi không cần tải lại), sau đó đổi scene sang Main Menu.
6. FR-06: Bắt lỗi mạng (HTTPRequest error / timeout) và hiển thị nút "Thử lại".

---

## Non-Functional Requirements

- Performance: Loading Scene phải cực nhẹ (chỉ dùng code và asset cơ bản) để hiện lên tức thì.
- Security: Phải dùng HTTPs để chống can thiệp (MitM).
- Availability: Cấu trúc file trong `.pck` phải map đúng với `res://` gốc để code hiện tại không bị lỗi (Ví dụ: `res://assets/...`).

---

## Success Criteria

- [ ] Dung lượng file cài đặt gốc (APK/EXE) được giảm đáng kể (vì không chứa thư mục assets nặng).
- [ ] Màn hình Loading hiển thị và cập nhật phần trăm thực tế khi tải.
- [ ] Godot mount được `.pck` vào hệ thống thành công và load ảnh bình thường.

---

## Out of Scope

- Không tải riêng lẻ từng ảnh khi đang chơi (Load on demand).
- Không cần tích hợp Cloudinary SDK phức tạp (chỉ dùng URL fetch).

---

## Assumptions

- Có đường truyền internet ổn định ở phía người dùng.
- Cloudinary bandwidth đủ phục vụ lượng tải file (Lưu ý: Free tier của Cloudinary có giới hạn Bandwidth, hãy cân nhắc cẩn thận về mức tải).

---

## [NEEDS CLARIFICATION]

*(Không có)*
