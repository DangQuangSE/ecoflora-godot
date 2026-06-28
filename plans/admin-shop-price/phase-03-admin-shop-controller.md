# Phase 3: Admin Shop Controller

**Depends on:** Phase 2 complete (IAdminShopService registered)

## Requirements

Expose `GET /api/admin/shop/catalog` and `PATCH /api/admin/shop/{prefixedId}/price` with admin-only authorization.

## Steps

1. Create `API/Controllers/AdminShopController.cs`:
   ```csharp
   [Route("api/admin/shop")]
   [ApiController]
   [Authorize(Roles = "Admin,SuperAdmin")]
   public class AdminShopController : ControllerBase
   ```

2. Inject `IAdminShopService` via constructor.

3. Implement `GET /api/admin/shop/catalog`:
   - Call `_adminShopService.GetCatalogAsync()`
   - Return `200 Ok(result.Success)` on success
   - Return `400/500` with `result.Error` on failure
   - `[ProducesResponseType(typeof(ApiResponse<List<AdminShopCatalogItemDto>>), 200)]`
   - `[ProducesResponseType(typeof(ApiError), 400)]`
   - `[ProducesResponseType(403)]`

4. Implement `PATCH /api/admin/shop/{prefixedId}/price`:
   - Accept `[FromBody] UpdateShopItemPriceRequest request`
   - The `prefixedId` route param arrives URL-encoded — use `Uri.UnescapeDataString(prefixedId)` if colons are encoded by client.
   - Call `_adminShopService.UpdatePriceAsync(prefixedId, request.Price)`
   - Return `200 Ok(result.Success)` on success
   - Return `400` for invalid price or format
   - Return `404` for unknown item
   - **Return `409 Conflict` for concurrency conflict** (when service signals HasConcurrencyConflict):
     ```csharp
     if (result.Error?.StatusCode == 409)
         return Conflict(result.Error);
     ```
   - `[ProducesResponseType(typeof(ApiResponse<AdminShopCatalogItemDto>), 200)]`
   - `[ProducesResponseType(typeof(ApiError), 400)]`
   - `[ProducesResponseType(403)]`
   - `[ProducesResponseType(typeof(ApiError), 404)]`
   - `[ProducesResponseType(typeof(ApiError), 409)]`

5. Register in `Program.cs`:
   ```csharp
   services.AddScoped<IAdminShopService, AdminShopService>();
   ```

6. Write integration tests:
   - `GET /api/admin/shop/catalog` with Admin token → 200
   - `GET /api/admin/shop/catalog` with Player token → 403
   - `PATCH /api/admin/shop/item:{validId}/price` `{ "price": 500 }` with Admin token → 200
   - `PATCH` with `{ "price": -1 }` → 400
   - `PATCH` with invalid prefixedId → 404 or 400 depending on format
   - `PATCH` that triggers concurrency conflict (mock) → 409

## Success Criteria

- All endpoints return 403 for Player role
- PATCH returns 409 with message "Price was updated concurrently. Refresh and retry." on conflict
- Route attribute uses `[controller]` → resolves to `api/admin/shop`
- `ProducesResponseType` annotations complete for Swagger

## Risks

- URL encoding: if FE sends `PATCH /api/admin/shop/item%3Aabc123/price`, the colon is encoded. Verify ASP.NET Core route binding decodes it automatically (it does for path segments by default). Test with real FE client.
