# Phase 2: HTTP Helper

## Layer
`services/` (RefCounted utility, no Node)

## Files

| File | Layer | New / Modify |
|---|---|---|
| `services/HttpHelper.gd` | services | New |

## Requirements
Provide a single RefCounted utility that all service classes use to (a) build the standard
Authorization + Content-Type header array, and (b) unwrap the BE's `{ isSuccess, message, data, metaData }`
envelope so individual parsers always receive the inner payload and never have to deal with the
wrapper themselves.

> **Note:** BE envelope uses camelCase keys (`isSuccess`, `data`, `metaData`) — confirmed from
> `Application/Helpers/ApiResponse.cs` + ASP.NET Core default camelCase serialization policy.
> Verify casing with a single `curl http://localhost:5226/api/flowertemplates` before Phase 2 cook.

## Steps
1. Create `HttpHelper` (class_name HttpHelper, extends RefCounted). Add a static method
   `make_headers(access_token: String) -> PackedStringArray` that returns the two headers
   `Content-Type: application/json` and `Authorization: Bearer <token>`. When token is empty,
   omit the Authorization header and push_warning.

2. Add a static method `unwrap_envelope(json: Dictionary) -> Variant` that checks for the
   `"isSuccess"` key first — if false or missing, push_warning with the `"message"` value and
   return null. Then return `json.get("data", null)`. The old `"code"` field does NOT exist at
   the root level — only `ApiError` responses have `code`, not `ApiResponse<T>`.

3. Add a static method `encode_body(payload: Dictionary) -> String` that calls `JSON.stringify()`
   and returns the result, so callers never write `JSON.stringify` inline.

4. Write a brief inline comment above each static method describing its expected input and return
   contract — this file is the integration contract between Godot and the BE envelope format,
   so clarity matters more than brevity here.

5. Verify that `HttpHelper` has zero imports of autoloads or Node classes — it must remain a pure
   RefCounted utility usable from any layer including domain tests.

## Success Criteria
- `HttpHelper.make_headers("tok123")` returns a `PackedStringArray` of length 2 containing
  `"Content-Type: application/json"` and `"Authorization: Bearer tok123"`
- `HttpHelper.make_headers("")` returns a `PackedStringArray` of length 1 (no Authorization)
  and emits a push_warning (visible in Godot Output panel)
- `HttpHelper.unwrap_envelope({"isSuccess": true, "data": {"level": 5}, "message": "ok"})` returns
  `{"level": 5}` as a Dictionary
- `HttpHelper.unwrap_envelope({"error": "bad"})` returns null and emits a push_warning
- `godot --headless --check-only --script res://services/HttpHelper.gd` reports zero errors

## Spec Coverage
- FR-08: Mapping layer in services/ — HttpHelper is the shared infrastructure for all service
  mappers, ensuring no envelope-unwrap logic leaks into autoloads or domain
