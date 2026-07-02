# Token Timeout & Auto-Refresh Mechanism (401 Interceptor)

Tài liệu này mô tả chi tiết về cách Godot client xử lý lỗi `401 Unauthorized` khi Access Token bị hết hạn, đảm bảo trải nghiệm liền mạch cho người dùng mà không bị văng ra màn hình đăng nhập.

## 1. Vấn đề trước đây
Trước bản cập nhật này, game tự động fetch Profile mỗi 30 giây chạy ngầm. Nếu token hết hạn trong chu kỳ này, nó sẽ tự gọi refresh token thành công. 
Tuy nhiên, nếu người dùng thực hiện một hành động (như **Mua hàng trong Shop**, **Nhận thưởng nhiệm vụ**, **Trồng cây**) vào *đúng khoảnh khắc* token hết hạn (trước khi chu kỳ 30 giây kịp chạy), thì hành động đó sẽ bị lỗi (Silent Fail hoặc văng lỗi mạng), khiến trải nghiệm bị gián đoạn.

## 2. Giải pháp mới: Global 401 Interceptor

Để giải quyết triệt để, chúng ta áp dụng cơ chế đánh chặn (Interceptor) ở mức Service. Mọi cuộc gọi HTTP có yêu cầu token đều sẽ đi qua một bộ bao bọc (wrapper).

### Luồng hoạt động (Workflow)
1. **Gửi Request:** Một Service (ví dụ `ShopService`) gửi request mua hàng.
2. **Nhận lỗi 401:** Server trả về mã lỗi `401 Unauthorized` do Access Token hết hạn.
3. **Đánh chặn & Tạm dừng:** Wrapper `HttpHelper.request_with_retry_async` sẽ giữ lại request này, chặn không cho trả lỗi về UI.
4. **Yêu cầu Refresh:** Wrapper gọi `UserManager.ensure_refresh_async()`. 
   - Nếu có nhiều nút bấm bị lỗi 401 cùng một lúc, tất cả sẽ cùng chờ chung một tiến trình refresh duy nhất, tránh việc gọi API refresh nhiều lần.
5. **Cấp mới Token:** Hệ thống gửi Refresh Token lên server để lấy Access Token mới.
6. **Tự động Retry:** Wrapper tự động trích xuất token mới, cập nhật lại HTTP Headers, và **bắn lại request mua hàng ban đầu**.
7. **Thành công:** Request retry thành công trả về 200 OK. UI nhận được kết quả như chưa hề có lỗi xảy ra.

*(Toàn bộ quy trình này diễn ra hoàn toàn trong suốt với người dùng, có thể chỉ tốn thêm 100-200ms độ trễ).*

## 3. Hướng dẫn Dành cho Developer (Áp dụng API mới)

Khi bạn tạo một Service mới gọi API cần Authenticate, hãy luôn sử dụng hàm `request_with_retry_async` thay vì `http.request` nguyên thuỷ.

### ❌ Cách CŨ (Không dùng nữa)
```gdscript
var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
var raw: Variant = await http.request_completed
var status_code: int = raw[1]
if status_code == 401:
    push_warning("Bị lỗi 401 rồi, chịu thua!")
    return {}
```

### ✅ Cách MỚI (Tự động retry khi 401)
```gdscript
# request_with_retry_async trả về ngay Array chứa [result, response_code, headers, body]
var raw: Array = await HttpHelper.request_with_retry_async(http, url, HTTPClient.METHOD_POST, headers, body)
var err: int = raw[0]

if err != OK:
    push_warning("Lỗi cục bộ/Lỗi mạng %d" % err)
    return {}

var status_code: int = raw[1]
var response_body: PackedByteArray = raw[3]

# Nếu status_code ở đây vẫn là 401, nghĩa là Refresh Token cũng đã chết hoặc tài khoản bị ban. 
# Hệ thống đã tự động đá văng về màn hình Login, ta chỉ cần return rỗng.
if status_code == 401:
    return {}

if status_code == 200:
    # Xử lý thành công
    pass
```

## 4. Cấu trúc kỹ thuật

### `HttpHelper.gd`
Cung cấp hàm tĩnh `request_with_retry_async` chịu trách nhiệm hứng lỗi `401` từ `HTTPRequest.request_completed` và quyết định gọi retry hay không.

### `UserManager.gd`
- Quản lý state của quá trình refresh thông qua biến `_refresh_in_flight`.
- Cung cấp hàm `ensure_refresh_async() -> bool`. 
- Gửi signal `token_refresh_completed` cho mọi tiến trình đang xếp hàng chờ token mới.

## 5. Kết luận
Cơ chế này đảm bảo người chơi có thể cắm máy 24/24 hoặc thao tác liên tục mà không bao giờ gặp lỗi vặt do token hết hạn (miễn là họ vẫn online trong phạm vi vòng đời 7 ngày của Refresh Token).
