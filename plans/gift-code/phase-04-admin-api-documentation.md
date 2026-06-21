# Phase 4: Admin API Documentation

## Requirements

Create markdown documentation describing the admin gift code creation, deletion, and active-toggle endpoints, including request/response contracts, error codes, and examples, enabling the FE web admin team to build their own admin UI without additional backend guidance.

## Steps

1. Create docs/admin-gift-code-api.md file documenting the full API contract for POST /admin/gift-codes, DELETE /admin/gift-codes/{id}, and PATCH /admin/gift-codes/{id}.

2. Document POST /admin/gift-codes endpoint: auth requirement (admin JWT), request body schema (Code, ExpiryDate, UsageLimit, Rewards array), response DTO (id, code, expiryDate, usageLimit, timesUsed, isActive, rewards array), HTTP status codes (201 success, 400 validation error, 401 auth error, 409 conflict). Include a full example JSON response body alongside the request example in step 3, not just the request.

3. Include example request body: a gift code named "SUMMER2026" with ExpiryDate = 2026-12-31, UsageLimit = 100, Rewards = [{RewardType: Currency, Quantity: 500}, {RewardType: Item, RefId: item-id-123, Quantity: 2}], plus its corresponding 201 response JSON.

4. Document DELETE /admin/gift-codes/{id} endpoint: path parameter (gift code id UUID), response (success true/false), HTTP status codes (200 success, 404 not found, 401 auth error). Include example response JSON for 200 and for the 404 error case.

5. Document PATCH /admin/gift-codes/{id} endpoint (the "pause without deleting" toggle, separate from delete): path parameter (gift code id UUID), request body `{ IsActive: bool }`, response `{ id, isActive }`, HTTP status codes (200 success, 404 not found, 401 auth error). Include example request/response JSON. Clarify in prose that toggling IsActive off does not change ExpiryDate/UsageLimit/TimesUsed and a redeem attempt on a toggled-off code returns the distinct `Inactive` error (not NotFound).

6. Document error responses for all three endpoints: list all possible ApiError codes (NotFound, InvalidCode, InvalidReward, InvalidExpiryDate, Unauthorized, Conflict), describe each, and provide a JSON example of the error envelope for every documented status code (400/401/404/409) so FE can match each case exactly rather than guessing the shape.

7. Provide curl examples for all three endpoints so web admin team can test interactively, including at least one example curl call that deliberately triggers a 404 and a 409 to show the error envelope in context.

8. Include a section on Code normalization: explain that codes are normalized to uppercase and trimmed at creation and redemption, so "summer 2026" becomes "SUMMER 2026".

9. Include a testing checklist: verify endpoint auth, test invalid reward RefId, test past ExpiryDate rejection, test UsageLimit=null (unlimited), test PATCH toggle on/off.

## Success Criteria

- Documentation is clear enough that FE web admin team can build an admin UI without asking backend team for clarification.
- Request/response schemas are accurate (match DTOs implemented in phase 2), including the PATCH toggle endpoint.
- All error codes and HTTP status codes are listed and explained, each with a JSON example of the error envelope.
- Curl examples run successfully against a local backend instance.

## Testing

- **Doc Verification**: Have another developer (or team member) read docs and attempt to call endpoints using curl; verify they can create a gift code and delete it without backend clarification.
- **Example Accuracy**: Run curl examples from documentation against actual backend; verify 201 and 200 responses; verify request/response match documented schema.
- **Error Codes**: Test each documented error code (InvalidCode, InvalidReward, etc.) and verify actual response matches documentation.

## Risks

- Documentation drift: if phase 2 implementation details change, docs may become stale — Mitigation: Keep docs in same PR as code changes; review docs in code review.
- Insufficient detail for non-backend teams — Mitigation: Add a "Tips for UI Implementation" section with common patterns (pagination, bulk create, etc.).
