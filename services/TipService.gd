class_name TipService
extends RefCounted

func fetch_tips_async(http: HTTPRequest, base_url: String) -> Array[GameTip]:
	var url := base_url + "/api/gametips"
	var err := http.request(url, PackedStringArray(["Content-Type: application/json"]))
	if err != OK:
		push_warning("TipService.fetch_tips_async: request error %d" % err)
		return []
	var raw: Variant = await http.request_completed
	var http_result: int = raw[0]
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if http_result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
		push_warning("TipService.fetch_tips_async: HTTP %d" % status_code)
		return []
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("TipService.fetch_tips_async: JSON parse error")
		return []
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Array:
		return []
	return _parse_tips(data as Array)


func _parse_tips(items: Array) -> Array[GameTip]:
	var result: Array[GameTip] = []
	for item: Variant in items:
		if not item is Dictionary:
			continue
		result.append(GameTip.from_dict(item as Dictionary))
	result.sort_custom(func(a: GameTip, b: GameTip) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.title < b.title
	)
	return result
