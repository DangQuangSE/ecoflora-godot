# Plan: Coin Top-up via PayOS (web checkout)

Status: 🟢 Complete (all 3 phases implemented, tested, reviewed — approved, commit deferred by user)
Date: 2026-06-19
Mode: Hard

## Overview
Add a real-money coin top-up flow consumed by a **login-gated web page** (built by a different FE partner, out of scope here) — not an open landing page, and not the Godot app. Player logs in with their existing game account before doing anything else, lists fixed coin packages, creates a PayOS order, and redirects to PayOS's own hosted `checkoutUrl` (no QR rendering on our side). A signature-verified PayOS webhook credits `User.Currency` exactly once per order. This is **BE-only scope** (`D:\GitHub\eco-backend`) — greenfield (no Order/Payment entity exists yet); the Godot client is untouched.

**Why web, not in-app:** the app is distributed via Google Play, which requires Google Play Billing for virtual-currency purchases initiated inside the app. Routing the purchase entirely through a web page outside the app avoids that policy surface. The app contains no top-up UI or link to the web page (see spec Out of Scope) to stay clear of Google's anti-steering provisions too.

## Phases
- [x] Phase 1: BE domain + infra — `CoinPackage` + `PaymentOrder` entities, migration, seed data, repository/UoW wiring
- [x] Phase 2: BE application service — PayOS SDK integration, order creation/status/webhook business logic, backup reconciliation
- [x] Phase 3: BE API layer — 4 endpoints, validators, DTOs, Swagger annotations, PayOS config section

## Research Summary
Resolved architecture decisions (from prior research pass, not re-debated here):
1. Use the official `payOS` NuGet SDK (v2.1.0+) for `createPaymentLink` and webhook signature verification — no manual HMAC/raw HttpClient.
2. **No QR rendering on the BE.** PayOS's `createPaymentLink` response includes a `checkoutUrl` — a PayOS-hosted page that already shows QR/bank-transfer info. The order-creation endpoint returns that URL verbatim; the web partner opens/redirects to it. (Superseded the earlier QRCoder-based design from when this was an in-app Godot flow.)
3. No ledger/transaction-log table. Idempotency = unique constraint on `PaymentOrder.OrderCode` + an **atomic `ExecuteUpdateAsync` conditional update** (`WHERE OrderCode = @code AND Status IN (Pending, Expired)`, checked via affected-row count) before crediting `User.Currency` — not a load-then-`SaveChangesAsync()` pattern, which would race under concurrent/duplicate webhook delivery. Credited amount always comes from `CoinPackage.CoinAmount` resolved via the order's own `CoinPackageId`, never from any field in the webhook payload. Matches the project's existing single-mutable-int convention (`InventoryService.BuyItemAsync`, `DailyTaskService.ClaimTaskAsync`, `VitalityService.ClaimAsync`, `UserService.AdminTopUpCoinAsync` all mutate `User.Currency` inline, no audit trail anywhere) while closing the TOCTOU gap those services don't have to worry about (none of them are racing an external webhook retry).
4. Cheap backup reconciliation: a sweep (background hosted service, or a lazy check inline in the status-poll endpoint) calls PayOS's GET payment-link-status API for any `PaymentOrder` stuck `Pending` past ~3 minutes, recovering from a webhook that never arrives without making every poll hit PayOS live.
5. Seed 4 fixed `CoinPackage` rows (10 coin = 1.000đ, no bonus tiers): 20.000đ/200, 50.000đ/500, 100.000đ/1.000, 200.000đ/2.000. Hard-coded for MVP, no admin CRUD (matches `Out of Scope` in spec.md).
6. `PaymentOrder.ExpiresAt = CreatedAt + 15 minutes`.
7. Web and Godot both authenticate against the same existing login endpoint/JWT — these payment endpoints need no new auth mechanism, just the standard `[Authorize]` already used elsewhere.

**Dropped from the original (in-app) plan:** the Godot client phase, `QRCoder` dependency, and all client-side QR-decoding/polling-timer-cleanup concerns — none of that applies once checkout happens on a web page PayOS itself hosts.

## Dependencies
- PayOS merchant account (`ClientId`, `ApiKey`, `ChecksumKey`) not yet registered — config keys are placeholders until then (see Risks).
- NuGet package: `payOS` SDK (v2.1.0+), added to whichever project layer hosts the external-service call (see Phase 2).
- `returnUrl`/`cancelUrl` for `createPaymentLink` must point at routes the web FE partner provides — exact URLs are a config detail to confirm with them, not a blocker for Phase 1/2.
- No new BE test project exists yet in `eco-backend` — Phase 2/3 test guidance assumes adding test coverage inline with existing conventions (no `*Tests.csproj` currently present; first payment-domain tests require scaffolding a minimal xUnit project).

## Risks
- HIGH: PayOS merchant credentials not yet available — blocks real end-to-end testing (cannot actually call `createPaymentLink` against PayOS or receive real webhooks until a sandbox/production account exists). Mitigation: implement webhook signature verification and SDK wiring now using PayOS's published API contract and mocked/sandbox-shaped JSON payloads (fixture-based unit tests); wire config keys as empty placeholders in `appsettings.json`/secrets; defer only the live-call manual test step until credentials land.
- HIGH: This feature's other half (the login-gated web top-up page) is owned by a different partner working in an unknown repo/stack — a BE contract change (DTO shape, status enum casing, `checkoutUrl` field name) won't be caught by any shared CI. Mitigation: freeze the 3 endpoint response shapes (per spec FR-03/04/05) and hand the partner a short contract note (field names/types) once Phase 3 ships, before they build against it.
- MEDIUM: Double-credit risk on retried/duplicate webhook delivery. Mitigation: atomic `ExecuteUpdateAsync` conditional update (`WHERE Status IN (Pending, Expired)`, affected-row count checked) inside a transaction per FR-06 and NFR — covered explicitly by a unit/integration test in Phase 2.
- MEDIUM: A PayOS webhook reporting PAID can legitimately arrive *after* the 15-minute expiry sweep already flipped an order to `Expired` (race between sweep and slow webhook delivery). Mitigation: the credit guard checks `Status IN (Pending, Expired)`, not `Pending` alone, so a late-but-valid PAID event still credits the player instead of silently dropping a real payment — see Phase 2 step 6 and its dedicated test.
- MEDIUM: Orders left dangling in `Pending` if `createPaymentLink` succeeds at PayOS but the local DB write fails (or vice versa) — could create a payable PayOS link with no local record, or a local `Pending` row with no real PayOS link. Mitigation: call PayOS first, only persist `PaymentOrder` after a successful PayOS response; if the local persist then fails, the order is unreachable by orderCode and naturally expires/is unpaid — no double-spend risk since credit only happens via the local row. Accepted residual risk: a mid-flight crash between the successful PayOS call and reading its response leaves an orphaned PayOS-side link with zero local tracking — very low probability, no money-loss-to-user exposure.
- LOW: Background sweep (Phase 2, required deliverable) competing with webhook processing on the same order. Mitigation: both paths use the same `ExecuteUpdateAsync ... WHERE Status IN (Pending, Expired)` atomic update, so whichever commits first wins and the other affects 0 rows.
- LOW: No cap on concurrent `Pending` orders per user (cost/availability risk against the PayOS account, not a money-loss risk) — see Phase 3 Risks; deferred for MVP.
- LOW: No ledger table means webhook payload receipt/processing must be logged (success and failure, not just failure) so a real-money support dispute has something to grep through — see Phase 2 step 6.
- LOW: If the web partner ever wants an in-app link/hint pointing at the top-up page, that requires a separate policy review against Google Play's anti-steering rules before adding — not assumed safe by default. Flagging so it isn't casually added later without re-checking.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-20
**Phase in progress:** phase-03-be-api-layer (complete, awaiting review gate)
**Status:** Phase 3 implemented, build green (0 warnings/errors), code-reviewer verdict APPROVED (0 CRITICAL/HIGH/MEDIUM, 2 LOW notes, 1 applied), 16/16 tests passing (5 Phase 2 + 11 new Phase 3).

### Decisions made this session
- **`[AllowAnonymous]` vs. no-attribute decision (resolved)**: the public `POST /api/payments/webhook` endpoint has **no `[Authorize]` at all**, not a `[AllowAnonymous]` override. Confirmed via reading `AuthController.cs` that this codebase has zero existing `[AllowAnonymous]` usages — its public `login`/`register` endpoints simply have no `[Authorize]` because the controller itself has no class-level `[Authorize]`. `PaymentsController` follows the same shape: no class-level `[Authorize]`, method-level `[Authorize(Roles = Constant.Roles.Player)]` on the 3 player-facing actions, nothing on the webhook action. Authenticity for the webhook is enforced entirely by `PaymentService.HandleWebhookAsync`'s HMAC signature check (via `IPayOsGateway.VerifyWebhookAsync`), confirmed local-only/no-network in Phase 2.
- **PayOS config section in `appsettings.json` — skipped, not added**. This codebase exclusively configures all external services (OpenWeather, JWT, Redis, and PayOS itself) via `.env`/`Environment.GetEnvironmentVariable`, already wired in `Program.cs` since Phase 2. Adding a parallel `appsettings.json` section would introduce a second, inconsistent config mechanism for the same settings — reconciled by keeping the existing env-var-only approach.
- Route shape: `[Route("api")]` on `PaymentsController` with literal full paths per action (`coin-packages`, `payments/orders`, `payments/orders/{orderCode}/status`, `payments/webhook`) rather than `[Route("api/[controller]")]`, since the controller spans two resource concepts (`coin-packages` and `payments`) that don't share one `[controller]` token — code-reviewer confirmed this is a reasonable variant of the codebase's existing literal-route convention.
- Extended `Application.Tests` (rather than creating a new test project) with controller-level tests — added a `ProjectReference` to `API.csproj` so test code can reach `PaymentsController`/`CreateOrderRequestValidator`. Added a hand-written `FakePaymentService` stub (no mocking library exists anywhere in the solution, confirmed via grep before deciding not to introduce one).
- code-reviewer raised 2 LOW notes, no CRITICAL/HIGH/MEDIUM: (1) controller unit tests bypass the ASP.NET auth pipeline entirely so they can't prove `[Authorize(Roles=...)]` is enforced end-to-end — accepted as a known gap, no `WebApplicationFactory` integration tests exist anywhere in this codebase yet to extend; (2) webhook action was missing a documented 400 `[ProducesResponseType]` for malformed-body model-binding failures — **fixed** (added the attribute).

### Next immediate action
Awaiting user review-gate approval for Phase 3 (final phase) before Finalize step (project-manager/docs-manager/git-manager). The FE-facing API documentation (`docs/api-coin-topup.md` or similar) is explicitly deferred until after this approval, per the user's own earlier choice to implement first then document against the real, verified field names/types.
