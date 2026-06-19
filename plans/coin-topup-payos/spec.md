# Spec: Nạp coin trong shop qua PayOS

**Date:** 2026-06-19
**Status:** Draft

---

## Problem Statement

Shop hiện chỉ cho dùng coin kiếm được trong game (daily task, vitality claim...). Không có cách nạp tiền thật để mua coin. Cần thêm luồng: user chọn gói coin → BE tạo đơn thanh toán PayOS → user quét QR ngay trong game bằng app ngân hàng → BE nhận webhook PAID → coin được cộng vào `User.Currency` hiện có. Backend hiện chưa có bất kỳ entity Order/Payment hay code PayOS nào — tính năng xây từ đầu.

---

## User Stories

- **[P1]** As a player, I want to see a list of fixed coin packages (price in VND, coin amount) in the shop, so I can choose how much to top up.
  Accepted when: shop "Top-up" tab calls `GET /api/coin-packages` and renders all active packages with `priceVnd` and `coinAmount`.

- **[P1]** As a player, I want to select a package and get a QR code displayed in-game, so I can pay without leaving the app.
  Accepted when: `POST /api/payments/orders { packageId }` creates a pending order via PayOS `createPaymentLink`, returns a QR image (URL or base64) generated server-side, and the client renders it directly without any client-side QR-encoding logic.

- **[P1]** As a player, I want the game to detect my payment automatically and credit coin without me doing anything else, so coin top-up feels seamless.
  Accepted when: client polls `GET /api/payments/orders/{orderCode}/status` every 2-3s while the QR is shown; once PayOS webhook marks the order PAID, the next poll response shows `status=Paid` and `User.Currency` already reflects the credited amount.

- **[P1]** As the system, I want PayOS webhook to credit coin exactly once per order even under retry/duplicate delivery, so no player can be double-credited or under-credited.
  Accepted when: webhook handler verifies PayOS signature (checksum), and a second identical webhook call for the same `orderCode` is a no-op (order already in terminal state `Paid`).

- **[P2]** As a player, I want an abandoned/expired QR to stop being payable and show as expired in the game, so I don't get confused trying to pay a stale code.
  Accepted when: an order not paid within its expiry window transitions to `Expired`/`Cancelled`, and polling status reflects that instead of staying `Pending` forever.

- **[P3]** _(out of scope — noted for future)_ Admin CRUD for coin packages (currently seeded/hard-coded, like daily task rewards before the recent admin-management feature).
- **[P3]** _(out of scope — noted for future)_ Refund flow.
- **[P3]** _(out of scope — noted for future)_ Free-form custom top-up amount (only fixed packages for MVP).

---

## Functional Requirements

1. FR-01: New `CoinPackage` entity (seeded): `Id, PriceVnd (int), CoinAmount (int), IsActive (bool)`. Rate baseline: 10 coin = 1.000đ (1 coin = 100đ); exact tier list is a seed-data decision, not a code constraint.
2. FR-02: New `PaymentOrder` entity: `Id, OrderCode (long, unique — PayOS requires numeric orderCode), UserId, CoinPackageId, AmountVnd, Status (Pending/Paid/Cancelled/Expired), CreatedAt, ExpiresAt, PaidAt`.
3. FR-03: `POST /api/payments/orders` — `[Authorize]`, body `{ packageId }`. Validates package is active, generates a unique `OrderCode`, calls PayOS `createPaymentLink` API with amount/description/returnUrl/cancelUrl, persists `PaymentOrder` as `Pending`, server-side renders the returned VietQR string into a QR image, returns `{ orderCode, qrImage (base64 or URL), expiresAt }`.
4. FR-04: `GET /api/payments/orders/{orderCode}/status` — `[Authorize]`, returns current `Status` and, if `Paid`, the new `User.Currency` balance. Used by client polling.
5. FR-05: `POST /api/payments/webhook` — public endpoint per PayOS spec, verifies `ChecksumKey` signature on every call before trusting payload. On verified PAID event: inside a DB transaction, guard against re-processing (`WHERE Status = 'Pending'` on the update), set order `Paid`, `PaidAt`, then `user.Currency += package.CoinAmount`. Any other event (cancelled) marks the order `Cancelled`.
6. FR-06: A background sweep (or lazy check on status poll) marks `Pending` orders past `ExpiresAt` as `Expired` so they stop being treated as payable.
7. FR-07: PayOS credentials (`ClientId`, `ApiKey`, `ChecksumKey`) read from configuration (`appsettings`/secrets), not committed to source — config section added but real values filled in only once a merchant account exists.

---

## Non-Functional Requirements

- **Security:** webhook endpoint MUST verify PayOS checksum signature before mutating any state — unsigned/invalid requests are rejected with no DB write. Coin-credit step runs inside the same transaction as the order status transition, guarded by a status precondition (no double credit on retry/duplicate webhook).
- **Consistency:** `OrderCode` is unique (DB constraint); webhook handler is idempotent per `OrderCode`.
- **Performance:** polling endpoint is a single-row lookup by `OrderCode`; p95 < 200ms, consistent with existing Admin*Controller endpoints.
- **Availability:** feature depends on external PayOS uptime; if `createPaymentLink` call fails, `POST /api/payments/orders` returns an error and no `PaymentOrder` row is left dangling in `Pending`.

---

## Success Criteria

- [ ] Player can list coin packages, create an order, and see a QR rendered in-game without any client-side QR-encoding code.
- [ ] Paying the real QR (sandbox PayOS) results in `User.Currency` increasing by the package's `CoinAmount` within one polling interval (~2-3s) of PayOS confirming payment.
- [ ] Sending the same PAID webhook payload twice for one `orderCode` credits coin only once (verified by DB state, not just response code).
- [ ] An order left unpaid past `ExpiresAt` reports `Expired` on the next status poll instead of `Pending`.
- [ ] Webhook calls with an invalid/missing signature are rejected and produce no DB change.

---

## Out of Scope

- Admin UI/API to create or edit coin packages — seeded data for MVP (matches "[NEEDS CLARIFICATION]" below).
- Refunds, partial refunds, or chargeback handling.
- Free-form/custom top-up amount.
- Realtime push (SignalR/socket) for payment confirmation — polling only for MVP.
- Godot-side QR-code generation/encoding library — BE always returns a ready-to-display image.

---

## Assumptions

- "Cùng coin hiện tại" means top-up writes to the exact same `User.Currency` field used by shop purchases and daily-task rewards — no new ledger/currency type.
- PayOS sandbox/production merchant account will be registered externally before end-to-end testing; until then, implementation can proceed against PayOS's published API contract with config keys left as placeholders.
- QR image generation on the server can use any standard QR library available in .NET (e.g. `QRCoder`) encoding the VietQR string PayOS returns — no new external image-hosting service required if base64 inline is acceptable to the client.

---

## NEEDS CLARIFICATION

1. **[NEEDS CLARIFICATION: exact coin package tiers]** — only the rate (10 coin = 1.000đ) is confirmed; the actual list of sellable packages (e.g. 20k/50k/100k/200k) needs a business decision before seeding.
2. **[NEEDS CLARIFICATION: package management ownership]** — should `CoinPackage` be admin-editable via API (same pattern as the recent admin-managed daily-task-reward feature) or stay as a static seed for MVP? Affects scope of /ck:plan.
3. **[NEEDS CLARIFICATION: order expiry duration]** — PayOS payment links have their own default expiry; need to decide if `PaymentOrder.ExpiresAt` mirrors that default or uses a custom shorter window.
