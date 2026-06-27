# Phase 03 — UserManager: character fields + set_character_async

**Goal:** Add `character_index`, `owned_characters`, `character_changed` signal, ConfigFile persistence, `set_character_async()`, and extend `fetch_profile_async()` + `purchase_async()`.

**Covers:** FR-03, FR-07 (sync), FR-08 | **Dependencies:** Phase 1 (BE endpoints)

---

## Files

| File | Change |
|------|--------|
| `autoloads/UserManager.gd` | New signal, new fields, 5 new methods, extend 3 existing |

---

## Pattern to mirror

Mirror `set_avatar_async` (lines 564–593) exactly. Key points:
- Create HTTPRequest with `timeout = 10.0`, add_child — NO `connect` to a stub handler
- Use `var raw: Variant = await _character_http.request_completed; var status_code: int = raw[1]`
- Check `use_mock` before making network request
- Emit `character_changed` AFTER local update and BEFORE `await`
- Rollback on non-200

---

## Steps

All changes in `UserManager.gd`:

**1. Signal** — add after existing signals (top of file):
```gdscript
signal character_changed(idx: int)
```

**2. Fields** — add near `_avatar_http` block:
```gdscript
var _character_index: int = 0
var _owned_characters: Array[int] = [0]
var _character_http: HTTPRequest
var _character_in_flight: bool = false
```

**3. `_ready()`** — after `_avatar_http` setup block, add:
```gdscript
_character_http = HTTPRequest.new()
_character_http.timeout = 10.0
add_child(_character_http)
# NO connect — use await directly in set_character_async
```

**4. Getters:**
```gdscript
func get_character_index() -> int:
	return _character_index

func get_owned_characters() -> Array[int]:
	return _owned_characters

func is_character_owned(idx: int) -> bool:
	return idx in _owned_characters
```

**5. ConfigFile helpers** (mirror `save_avatar_index` / `load_avatar_index`):
```gdscript
func save_character_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("character", "index", _character_index)
	cfg.set_value("character", "owned", JSON.stringify(_owned_characters))
	cfg.save("user://character_prefs.cfg")

func load_character_index_local() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://character_prefs.cfg") != OK:
		return 0
	return int(cfg.get_value("character", "index", 0))
```

**6. `set_character_async(idx: int)`** — mirrors `set_avatar_async`:
```gdscript
func set_character_async(idx: int) -> void:
	if not is_character_owned(idx) or _character_in_flight:
		return
	var prev := _character_index
	_character_index = idx
	save_character_prefs()
	character_changed.emit(idx)
	if use_mock:
		return
	_character_in_flight = true
	var body := JSON.stringify({"characterIndex": idx})
	var headers := HttpHelper.make_headers(_token_store.access_token if _token_store else "")
	headers.append("Content-Type: application/json")
	var err := _character_http.request(
		base_url + "/api/auth/character", headers, HTTPClient.METHOD_PUT, body)
	if err != OK:
		_character_index = prev
		save_character_prefs()
		character_changed.emit(_character_index)
		_character_in_flight = false
		push_warning("UserManager.set_character_async: request error %d" % err)
		return
	var raw: Variant = await _character_http.request_completed
	_character_in_flight = false
	var status_code: int = raw[1]
	if status_code != 200:
		_character_index = prev
		save_character_prefs()
		character_changed.emit(_character_index)
		push_warning("UserManager.set_character_async: BE sync failed (HTTP %d), reverted to %d" % [status_code, prev])
```

**7. Extend `fetch_profile_async()`** — after `_profile = _user_service.parse_profile(data)` (around line 341), BEFORE `profile_updated.emit()`:
```gdscript
# Character — BE is source of truth for owned; local is source of truth for equipped index
var be_char_idx: int = data.get("characterIndex", 0)
var be_owned = data.get("ownedCharacters", [0])
if be_owned is Array:
	_owned_characters = Array(be_owned, TYPE_INT, "", null)
var local_char_idx := load_character_index_local()
if local_char_idx != be_char_idx and is_character_owned(local_char_idx):
	_character_index = local_char_idx
	set_character_async(local_char_idx)  # fire-and-forget first-login sync
else:
	_character_index = be_char_idx
save_character_prefs()
character_changed.emit(_character_index)
```

**8. Extend `purchase_async()`** — after `update_currency(...)`, before `return data`:
```gdscript
if data.has("ownedCharacters") and data["ownedCharacters"] is Array:
	_owned_characters = Array(data["ownedCharacters"], TYPE_INT, "", null)
	save_character_prefs()
```

**9. Cancel on background** — in the existing cancel block (line 684 area), add:
```gdscript
if _character_http and _character_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
	_character_http.cancel_request()
```

---

## Acceptance Check

- `get_character_index()` returns 0 on fresh install
- `set_character_async(1)` when not owned → no-op (guard fires)
- `set_character_async(1)` when owned, `use_mock=true` → local update + emit, no HTTP
- `set_character_async(1)` when owned, real BE → optimistic emit, PUT request, rollback on 4xx/5xx
- After `fetch_profile_async()`, `_owned_characters` reflects BE array; first-login sync fires if local differs from BE
- After `purchase_async("character:1", 1)`, `_owned_characters` includes 1
- No orphan connections to `_character_http`
