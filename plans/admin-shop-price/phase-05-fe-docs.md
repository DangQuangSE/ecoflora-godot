# Phase 5: API Documentation

## Requirements

Write comprehensive API contract documentation for the admin shop price editing endpoints, aimed at the FE admin dashboard team (web app). Include request/response examples, error codes, authentication requirements, prefix format reference, and migration guide for existing client code.

## Steps

1. Create d:\GitHub\eco-backend\docs\admin-shop-price-api.md markdown file documenting both endpoints and data model.

2. Document GET /api/admin/shop/catalog: HTTP method, authorization (Admin, SuperAdmin roles), response format with example JSON (array of AdminShopCatalogItemDto), success code 200, error codes 403 (unauthorized), 500 (server error).

3. Document PATCH /api/admin/shop/{prefixedId}/price: HTTP method, authorization, request body format (UpdateShopItemPriceRequest with Price field), response format (single updated AdminShopCatalogItemDto), success code 200, error codes 400 (invalid price < 0), 403 (unauthorized), 404 (unknown item), 500 (server error).

4. Provide complete curl/Postman examples for both endpoints with real-looking data (e.g., item:550e8400-e29b-41d4-a716-446655440000, character:1).

5. Explain prefixed ID format: item: (UUID), seed: (UUID), deco: (UUID), character: (int index 0-N).

6. Document error responses: include example ApiError JSON with code, message, details fields.

7. Add migration guide: for clients currently calling hardcoded character prices endpoint (if exists), explain that prices now come from this admin endpoint and should be cached/displayed to users accordingly.

8. Write notes on usage: explain that admin can update prices without code deployment, prices are immediately reflected in GET /api/shop/items for players, concurrent updates via optimistic locking are transparent to client (no retry logic needed in FE).

## Success Criteria

- Documentation includes full request/response examples for both endpoints
- Prefix format is clearly explained with examples for each type
- Error codes and sample ApiError responses are documented
- Curl/Postman examples are copy-paste ready
- Migration guide helps FE team understand price-source change
- Documentation is in markdown format in docs/ directory

## Risks

- Documentation gets out of sync with code — mitigation: include OpenAPI/Swagger generation (out-of-scope this phase) to auto-generate docs. For now, treat markdown as source-of-truth, add comment in plan if future work adds OpenAPI.
- FE admin dashboard built by different team may not read this doc — mitigation: share link in PR description, mention in team standup, add to README in eco-backend.
