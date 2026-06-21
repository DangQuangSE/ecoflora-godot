# Spec: Gift Code Redemption

**Date:** 2026-06-20
**Status:** Draft

---

## Problem Statement

Admin cần một cách phát thưởng (currency, item, seed...) cho người chơi hàng loạt thông qua các đợt sự kiện/khuyến mãi, mà không phải sửa code mỗi lần. Player nhập một mã code trong app để nhận thưởng một lần.

---

## User Stories

- **[P1]** As an admin, I want to create a gift code with a custom string, an expiry date, an optional usage quota, and a reward bundle (currency + multiple item quantities) so that I can run promotional campaigns without a deploy.
  Accepted when: a gift code record can be created via API with `Code`, `ExpiryDate`, nullable `UsageLimit`, and 1+ `GiftCodeReward` rows (currency and/or items).

- **[P1]** As a player, I want to enter a gift code in the client and receive its reward exactly once so that I'm not able to claim the same code twice.
  Accepted when: redeeming the same code twice with the same account returns an "already redeemed" error on the second attempt, and the reward is applied to currency/inventory only on the first successful attempt.

- **[P1]** As a player, I want a clear error when a code is invalid, expired, or out of quota so that I understand why redemption failed.
  Accepted when: redeem endpoint returns distinct error codes for `NotFound`, `Expired`, `QuotaExceeded`, `AlreadyRedeemed`.

- **[P2]** As an admin, I want to view how many times a code has been redeemed so that I can track campaign usage.
  Accepted when: a query endpoint returns `TimesUsed` / `UsageLimit` for a given code.

- **[P3]** _(out of scope — noted for future)_ Auto-generated batch codes (random string per recipient), admin web dashboard UI.

---

## Functional Requirements

1. FR-01: `GiftCode` entity: `Id`, `Code` (unique, normalized uppercase+trim), `ExpiryDate` (UTC), `UsageLimit` (nullable int = unlimited), `TimesUsed` (int, default 0), `IsActive` (bool).
2. FR-02: `GiftCodeReward` entity (1-to-many from `GiftCode`): `Id`, `GiftCodeId`, `RewardType` (enum: `Currency`, `Item`, `FlowerSeed`, `Decor`), `RefId` (nullable — item/seed/decor id, null when `RewardType=Currency`), `Quantity` (int).
3. FR-03: `UserGiftCodeRedemption` entity: `Id`, `UserId`, `GiftCodeId`, `RedeemedAt`. Unique constraint on `(UserId, GiftCodeId)` enforced at DB level.
4. FR-04: `POST /admin/gift-codes` — create a gift code + its reward lines in one request (admin-only, auth via existing admin/JWT mechanism).
5. FR-05: `DELETE /admin/gift-codes/{id}` — hard-deletes a `GiftCode` row (cascade-deletes its `GiftCodeReward` lines). No soft-delete; `IsActive` flag remains only as an admin "pause without deleting" toggle, separate from deletion. `PATCH /admin/gift-codes/{id}` with body `{ IsActive: bool }` flips this toggle without touching `ExpiryDate`/`UsageLimit`/`TimesUsed`; a redeem attempt against a toggled-off code returns a distinct `Inactive` error.
6. FR-06: `POST /gift-codes/redeem` — body `{ code: string }`, authenticated player endpoint. Validates: code exists & `IsActive`, not expired (`ExpiryDate >= now`), quota not exceeded (`UsageLimit == null || TimesUsed < UsageLimit`), no existing `UserGiftCodeRedemption` for (user, code). On success: applies all `GiftCodeReward` lines to user's currency/inventory inside a single DB transaction, increments `TimesUsed`, inserts redemption record, all atomically (reuse `TryCommitAsync` + `DbUpdateConcurrencyException` retry pattern from `DailyTaskService`).
7. FR-07: Redeem response returns updated `NewCurrencyTotal` and the list of granted items (id, qty) so the Godot client can apply reward locally without a second fetch — mirror `ClaimResultDto` shape used by daily tasks.
8. FR-08: Godot client: new `GiftCodeManager` (or method on `UserManager`) calls redeem endpoint, then applies result via existing `UserManager.update_currency()` / `InventoryManager.add_reward_item()` calls, emits a signal for UI (toast/dialog) — same pattern as `TaskManager.gd:162-184`.
9. FR-09: Ship a markdown doc (`docs/admin-gift-code-api.md` or similar) describing the admin create-code endpoint contract, so the FE web admin team can build their own UI against it. No admin UI is built in this feature.

---

## Non-Functional Requirements

- Performance: redeem endpoint p95 < 300ms under normal load (single transaction, indexed lookup on `Code`).
- Security: redeem endpoint requires authenticated player session (existing JWT). No rate-limiting in this MVP — acceptable risk, revisit if abuse observed (see Out of Scope).
- Availability: quota/redemption checks must be race-safe under concurrent requests (DB unique constraint + optimistic concurrency, not application-level check-then-act).

---

## Success Criteria

- [ ] Double-redeem prevention: 100 concurrent redeem requests for the same (user, code) result in exactly 1 successful grant.
- [ ] Quota enforcement: concurrent redeems on a quota-limited code never exceed `UsageLimit` successful grants.
- [ ] Admin can create a multi-reward code (currency + 2 item types) via one API call and a player receives all reward lines in one redeem call.

---

## Out of Scope

- Auto-generated/random batch gift codes (1-code-per-recipient).
- Admin web dashboard UI implementation (only API + markdown contract doc).
- Localized/translated error messages (client maps error codes to text).
- Rate-limiting on the redeem endpoint (brute-force protection) — deferred until abuse is observed.
- Soft-delete / audit trail for deleted or deactivated gift codes — hard delete is acceptable for MVP.

---

## Assumptions

- Eco-backend already exposes a working admin-auth mechanism that the new admin endpoint can reuse (not building new admin auth).
- "Item" reward types map onto the existing `InventoryItem` model (`ItemId` / `FlowerTemplateId` / `DecorId` columns) — `GiftCodeReward.RewardType` acts as the discriminator for which column to populate on grant.
- Code matching is case-insensitive (normalized to uppercase + trimmed) both at creation and redemption time.

