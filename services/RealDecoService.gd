class_name RealDecoService
extends RefCounted

var _http_get:        HTTPRequest
var _http_place:      HTTPRequest
var _http_batch_move: HTTPRequest
var _http_recall:     HTTPRequest

func _init(http_get: HTTPRequest, http_place: HTTPRequest, http_batch_move: HTTPRequest, http_recall: HTTPRequest) -> void:
	_http_get        = http_get
	_http_place      = http_place
	_http_batch_move = http_batch_move
	_http_recall     = http_recall

func get_placements_async(base_url: String, token: String, scene_name: String) -> Array:
	var url := "%s/api/deco-placements?scene=%s" % [base_url, scene_name]
	var raw: Array = await HttpHelper.request_with_retry_async(_http_get, url, HTTPClient.METHOD_GET, HttpHelper.make_headers(token))
	var err: int = raw[0]
	if err != OK:
		push_warning("RealDecoService.get_placements_async: request error %d" % err)
		return []
	var data: Variant = _parse(raw, "get_placements_async")
	if not data is Array:
		return []
	var result: Array = []
	for d: Variant in data:
		if d is Dictionary:
			result.append(DecoPlacement.from_dict(d as Dictionary))
	return result

func place_deco_async(base_url: String, token: String, inventory_item_id: String, scene_name: String, x: float, y: float) -> DecoPlacement:
	var body := HttpHelper.encode_body({
		"inventoryItemId": inventory_item_id,
		"sceneName": scene_name,
		"x": x,
		"y": y,
	})
	var headers := HttpHelper.make_headers(token)
	var raw: Array = await HttpHelper.request_with_retry_async(_http_place, base_url + "/api/deco-placements", HTTPClient.METHOD_POST, headers, body)
	var err: int = raw[0]
	if err != OK:
		push_warning("RealDecoService.place_deco_async: request error %d" % err)
		return DecoPlacement.new()
	var status_code: int = raw[1]
	var data: Variant = _parse(raw, "place_deco_async")
	if (status_code != 200 and status_code != 201) or not data is Dictionary:
		return DecoPlacement.new()
	return DecoPlacement.from_dict(data as Dictionary)

func batch_move_async(base_url: String, token: String, moves: Array) -> bool:
	var entries: Array = []
	for m: Variant in moves:
		if m is Dictionary:
			entries.append(m)
	var body := HttpHelper.encode_body({"moves": entries})
	var headers := HttpHelper.make_headers(token)
	var raw: Array = await HttpHelper.request_with_retry_async(_http_batch_move, base_url + "/api/deco-placements/batch-move", HTTPClient.METHOD_PATCH, headers, body)
	var err: int = raw[0]
	if err != OK:
		push_warning("RealDecoService.batch_move_async: request error %d" % err)
		return false
	var status_code: int = raw[1]
	return status_code == 200

func recall_deco_async(base_url: String, token: String, placement_id: String) -> bool:
	var url := "%s/api/deco-placements/%s" % [base_url, placement_id]
	var raw: Array = await HttpHelper.request_with_retry_async(_http_recall, url, HTTPClient.METHOD_DELETE, HttpHelper.make_headers(token))
	var err: int = raw[0]
	if err != OK:
		push_warning("RealDecoService.recall_deco_async: request error %d" % err)
		return false
	var status_code: int = raw[1]
	return status_code == 200

func _parse(raw: Variant, ctx: String) -> Variant:
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code < 200 or status_code >= 300:
		push_warning("RealDecoService.%s: HTTP %d" % [ctx, status_code])
		return null
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("RealDecoService.%s: JSON parse error" % ctx)
		return null
	return HttpHelper.unwrap_envelope(json.get_data() as Dictionary)
