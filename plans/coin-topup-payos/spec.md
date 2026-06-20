# Spec: Nạp coin qua PayOS (web — yêu cầu đăng nhập)

**Date:** 2026-06-19
**Status:** Draft

---

## Problem Statement

Shop hiện chỉ cho dùng coin kiếm được trong game (daily task, vitality claim...). Không có cách nạp tiền thật để mua coin.

App phân phối qua Google Play, nên **không thể** xử lý mua virtual currency trực tiếp trong app qua cổng thanh toán bên thứ 3 (PayOS) — vi phạm Google Play Payments Policy (digital goods tiêu thụ trong app phải qua Google Play Billing). Quyết định: luồng nạp coin chuyển hoàn toàn ra **một trang web riêng, yêu cầu đăng nhập** (do partner FE khác build) — không phải trang chủ/landing page công khai, để tránh lộ thông tin và lộn tài khoản cần cộng coin. Player đăng nhập bằng tài khoản game (email/password — tái dùng login hiện có), chọn gói, được redirect sang trang checkout do PayOS host (`checkoutUrl`), thanh toán xong PayOS gọi webhook về BE để cộng coin.

**Scope của BE (eco-backend) trong spec này:** toàn bộ API mà trang web nạp coin sẽ gọi. Không động tới code Godot — app không có UI/nút nào liên quan top-up (tránh rủi ro Google Play anti-steering nếu sau này có người muốn thêm link trong app, xem Out of Scope). Backend hiện chưa có bất kỳ entity Order/Payment hay code PayOS nào — tính năng xây từ đầu.

---

## User Stories

- **[P1]** As a player, I want to log into the web top-up page with my existing game account (email/password), so the top-up can be credited to the correct account.
  Accepted when: web calls the existing login endpoint (same one the Godot client uses) and receives a JWT identifying the player; no new auth system is built.

- **[P1]** As a player, I want to see a list of fixed coin packages (price in VND, coin amount) on the web page, so I can choose how much to top up.
  Accepted when: web calls `GET /api/coin-packages` and renders all active packages with `priceVnd` and `coinAmount`.

- **[P1]** As a player, I want to select a package and get redirected to a PayOS-hosted checkout page, so I can pay by bank transfer/QR without the BE needing to render anything itself.
  Accepted when: `POST /api/payments/orders { packageId }` (authenticated) creates a pending order via PayOS `createPaymentLink` and returns `{ orderCode, checkoutUrl, expiresAt }` — `checkoutUrl` is PayOS's own hosted payment page (already includes QR/bank info); BE does **not** generate or return any QR image itself.

- **[P1]** As a player, I want the web page to detect my payment and show updated coin balance, so the top-up feels seamless.
  Accepted when: web polls `GET /api/payments/orders/{orderCode}/status` (or relies on PayOS's `returnUrl` redirect after payment, web's choice) and once PayOS's webhook marks the order PAID, the status response shows `status=Paid` and `User.Currency` already reflects the credited amount.

- **[P1]** As the system, I want PayOS webhook to credit coin exactly once per order even under retry/duplicate delivery, so no player can be double-credited or under-credited.
  Accepted when: webhook handler verifies PayOS signature (checksum), and a second identical webhook call for the same `orderCode` is a no-op (order already in terminal state `Paid`).

- **[P2]** As a player, I want an abandoned/expired order to stop being payable and report as expired, so the web page doesn't keep waiting forever.
  Accepted when: an order not paid within its expiry window transitions to `Expired`/`Cancelled`, and status polling reflects that instead of staying `Pending` forever.

- **[P3]** _(out of scope — noted for future)_ Admin CRUD for coin packages (currently seeded/hard-coded, like daily task rewards before the recent admin-management feature).
- **[P3]** _(out of scope — noted for future)_ Refund flow.
- **[P3]** _(out of scope — noted for future)_ Free-form custom top-up amount (only fixed packages for MVP).
- **[P3]** _(out of scope — noted for future)_ Any in-app (Godot) link/button pointing to the web top-up page — see Out of Scope.

---

## Functional Requirements

1. FR-01: New `CoinPackage` entity (seeded): `Id, PriceVnd (int), CoinAmount (int), IsActive (bool)`. Seed 4 rows at 10 coin = 1.000đ: 20.000đ/200, 50.000đ/500, 100.000đ/1.000, 200.000đ/2.000.
2. FR-02: New `PaymentOrder` entity: `Id, OrderCode (long, unique — PayOS requires numeric orderCode), UserId, CoinPackageId, AmountVnd, Status (Pending/Paid/Cancelled/Expired), CreatedAt, ExpiresAt, PaidAt`.
3. FR-03: `GET /api/coin-packages` — `[Authorize]`, returns all active `CoinPackage` rows.
4. FR-04: `POST /api/payments/orders` — `[Authorize]`, body `{ packageId }`. Validates package is active, generates a unique `OrderCode`, calls PayOS `createPaymentLink` with amount/description/`returnUrl`/`cancelUrl` pointed at the web top-up page's own routes (partner-provided URLs, configurable), persists `PaymentOrder` as `Pending` only after a successful PayOS response, returns `{ orderCode, checkoutUrl, expiresAt }` — `checkoutUrl` is PayOS's response field verbatim, no server-side QR rendering.
5. FR-05: `GET /api/payments/orders/{orderCode}/status` — `[Authorize]`, scoped to the requesting user, returns current `Status` and, if `Paid`, the new `User.Currency` balance. Used by the web page for polling/confirmation.
6. FR-06: `POST /api/payments/webhook` — public endpoint per PayOS spec, verifies `ChecksumKey` signature on every call before trusting payload. On verified PAID event: atomically transition the order (`Pending` or `Expired` → `Paid`) guarded so a duplicate/retried webhook is a no-op, then credit `user.Currency` by the **order's own** `CoinPackage.CoinAmount` (never any amount field from the webhook payload). Any other event (cancelled) marks the order `Cancelled` under the same guard.
7. FR-07: A background sweep (or lazy check on status poll) marks `Pending` orders past `ExpiresAt` as `Expired` so they stop being treated as payable, while still allowing a late-but-valid PAID webhook to credit an already-`Expired` order (see NFR).
8. FR-08: PayOS credentials (`ClientId`, `ApiKey`, `ChecksumKey`) read from configuration (`appsettings`/secrets), not committed to source — config section added but real values filled in only once a merchant account exists.

---

## Non-Functional Requirements

- **Security:** webhook endpoint MUST verify PayOS checksum signature before mutating any state — unsigned/invalid requests are rejected with no DB write. Coin-credit step runs inside the same atomic update as the order status transition, guarded by a status precondition (no double credit on retry/duplicate webhook), and always reads the credited amount from the server-side `CoinPackage` row, never from the webhook payload.
- **Consistency:** `OrderCode` is unique (DB constraint); webhook handler is idempotent per `OrderCode`. A late-arriving valid PAID webhook for an order already flipped to `Expired` by the expiry sweep must still credit the coin (guard on `Status IN (Pending, Expired)`, not `Pending` alone).
- **Performance:** polling endpoint is a single-row lookup by `OrderCode`; p95 < 200ms, consistent with existing Admin*Controller endpoints.
- **Availability:** feature depends on external PayOS uptime; if `createPaymentLink` call fails, `POST /api/payments/orders` returns an error and no `PaymentOrder` row is left dangling in `Pending`.
- **Cross-channel auth:** web and the Godot app both authenticate against the same existing login endpoint/JWT — no new auth system, no new claim type needed for these endpoints.

---

## Success Criteria

- [ ] Web page (or a manual API client standing in for it) can list coin packages, create an order, and receive a `checkoutUrl` it can open directly — no QR-rendering code exists anywhere in the BE diff.
- [ ] Completing payment on the real PayOS-hosted `checkoutUrl` (sandbox) results in `User.Currency` increasing by the package's `CoinAmount`, observable via the status endpoint shortly after PayOS confirms payment.
- [ ] Sending the same PAID webhook payload twice for one `orderCode` credits coin only once (verified by DB state, not just response code).
- [ ] A webhook payload with a tampered amount field still credits exactly the order's original `CoinPackage.CoinAmount`.
- [ ] An order left unpaid past `ExpiresAt` reports `Expired` on the next status poll instead of `Pending`.
- [ ] A PAID webhook arriving after an order already flipped to `Expired` still credits the coin.
- [ ] Webhook calls with an invalid/missing signature are rejected and produce no DB change.

---

## Out of Scope

- Building the web top-up page itself — owned by a different FE partner; this spec covers BE API only. The page requires login (not an open public page) — exact UI/UX is the partner's responsibility.
- Any change to the Godot client (`flow-flora-godot`) — no top-up UI, no link/button to the web page from inside the app. Google Play's anti-steering provisions restrict apps from directing users off-app to purchase digital content; the safest posture is the app contains nothing pointing at the top-up flow at all. If the team later wants an in-app mention (e.g. a non-clickable hint, or a UID players can quote on the web page), that's a separate decision requiring its own legal/policy check, not assumed here.
- Server-side QR image generation/rendering (e.g. `QRCoder`) — PayOS's own `checkoutUrl` already serves a hosted payment page with QR; BE just passes that URL through.
- Admin UI/API to create or edit coin packages — seeded data for MVP.
- Refunds, partial refunds, or chargeback handling.
- Free-form/custom top-up amount.
- Realtime push (SignalR/socket) for payment confirmation — polling only for MVP, web's polling implementation is the partner's choice as long as it calls FR-05.
- New web-specific authentication — web reuses the same login endpoint/JWT as the Godot client.

---

## Assumptions

- "Cùng coin hiện tại" means top-up writes to the exact same `User.Currency` field used by shop purchases and daily-task rewards — no new ledger/currency type.
- PayOS sandbox/production merchant account will be registered externally before end-to-end testing; until then, implementation can proceed against PayOS's published API contract with config keys left as placeholders.
- The web partner's login flow calls the existing `/api/auth/login` (or equivalent) endpoint already used by the Godot client and stores/sends the resulting JWT like any other authenticated API consumer — no BE changes needed to support web as a second client of the same auth endpoint.
- `returnUrl`/`cancelUrl` passed to PayOS's `createPaymentLink` point at web top-up-page routes supplied by the FE partner (configurable, not hardcoded to a single value) — exact URLs are a config detail to confirm with the partner before Phase 3 ships, not a blocker for earlier phases.

---

## Resolved Decisions (2026-06-19)

- **Coin package tiers (seed data):** 20.000đ → 200 coin, 50.000đ → 500 coin, 100.000đ → 1.000 coin, 200.000đ → 2.000 coin. Matches the 10 coin = 1.000đ rate exactly, no bonus tiers for MVP.
- **Package management ownership:** confirmed hard-coded/seeded `CoinPackage` rows for MVP (no admin CRUD endpoint in this pass).
- **Order expiry duration:** `PaymentOrder.ExpiresAt = CreatedAt + 15 minutes`, matching PayOS's common payment-link default.
- **Channel pivot (2026-06-19):** moved from in-app QR display (Godot) to a login-gated web checkout page, after identifying that an in-app PayOS purchase flow for virtual currency would violate Google Play Payments Policy on an app distributed via Google Play. BE scope unchanged in spirit (same entities, same webhook/idempotency logic) but the response shape changes (`checkoutUrl` instead of a rendered QR image) and the Godot client phase is dropped entirely.
- **Login-gated, not an open landing page (2026-06-19):** the web top-up page requires login with the player's existing game account before showing packages/payment, so coin credit is tied to a verified account rather than a publicly-reachable page where the wrong user could be credited or account info exposed.
