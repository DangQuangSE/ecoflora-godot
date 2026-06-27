# Plan: Admin Shop Price Editing

Status: Done
Date: 2026-06-28
Mode: Hard

## Overview

Enable admin users to view all shop items (consumables, seeds, decorations, characters) in a single catalog endpoint and edit prices without code changes. Migrate hardcoded character prices to a new CharacterConfig database entity, unifying price management across all shop categories.

## Phases

- [x] Phase 1: CharacterConfig Entity — Create domain entity, EF Core config, migration, and seed data
- [x] Phase 2: Admin Shop Service — Implement IAdminShopService to aggregate catalog and update prices
- [x] Phase 3: Admin Shop Controller — Expose two endpoints (GET catalog, PATCH price) with admin-only authorization
- [x] Phase 4: Update Shop Service — Remove hardcoded character prices and read from CharacterConfig in DB
- [x] Phase 5: API Documentation — Document admin shop endpoints and prefix format for FE team

## Research Summary

**Approach: Unified AdminShopController + CharacterConfig entity**

- Create new `CharacterConfig` domain entity extending BaseEntity with fields: CharacterIndex (int, unique), Name, Price, ImageUrl, IsActive
- Implement `IAdminShopService` + `AdminShopService` in Application layer to aggregate all shop items and handle price updates
- Add `AdminShopController` with role-based authorization (Admin, SuperAdmin) and two endpoints:
  - `GET /api/admin/shop/catalog` — returns all Items + FlowerTemplates + Decors + CharacterConfigs
  - `PATCH /api/admin/shop/{prefixedId}/price` — updates price in correct table by prefix (item:, seed:, deco:, character:)
- Update `ShopService.PurchaseAsync` to read CharacterConfig prices from DB instead of hardcoded dictionary
- Maintain backward compatibility: player-facing `GET /api/shop/items` unchanged, existing character purchase flow works with DB prices
- Write API contract documentation for admin FE dashboard team

**Key Patterns**:
- Return tuple: `(ApiResponse<T>? Success, ApiError? Error)` — consistent with existing IShopService
- Admin auth: `[Authorize(Roles = "Admin,SuperAdmin")]` — same as ItemsController
- Validation: HTTP 400 for price < 0, HTTP 404 for unknown item, HTTP 403 for non-admin
- EF Core soft delete: IsDeleted field filtering, unique constraint on CharacterIndex

## Dependencies

- EF Core DbSet registration in AppDbContext (existing pattern)
- Existing IUnitOfWork interface with repository pattern
- ASP.NET Core authorization middleware
- SQL migration framework (EF Core Migrations)

## Risks

- HIGH: Hardcoded character prices in production — users may expect instant price updates after PATCH — mitigation: player endpoints read fresh from DB on each call (no client caching). Update is synchronous within PurchaseAsync transaction.
- MEDIUM: Race condition on CharacterConfig during concurrent price updates — mitigation: [ConcurrencyCheck] on Price field + TryCommitAsync() in UpdatePriceAsync → HTTP 409 returned to admin. Admin must refresh and retry.
- MEDIUM: Phase 4 changes character purchase error code 400 → 404 for missing character. Godot client must handle 404. Document in Phase 5 docs.
- MEDIUM: Phase ordering is strict: Phase 4 depends on Phase 1 (IUnitOfWork.CharacterConfigs) and Phase 3 (DI registration). Run in order 1→2→3→4→5.
- LOW: Admin endpoint shows all items (including inactive) — intentional, accepted as design for admin view.
- LOW: ImageUrl excluded from CharacterConfig — Godot hardcodes sprite by index, DB field out of scope.
