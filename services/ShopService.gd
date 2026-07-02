class_name ShopService
extends RefCounted

var _http_catalog: HTTPRequest
var _http_purchase: HTTPRequest

func _init(http_catalog: HTTPRequest, http_purchase: HTTPRequest) -> void:
	_http_catalog  = http_catalog
	_http_purchase = http_purchase

func get_catalog_async(base_url: String, token: String, category: String = "") -> Array[ShopItem]:
	var url := base_url + "/api/shop/items"
	if category != "":
		url += "?category=" + category
	var headers := HttpHelper.make_headers(token)
	var raw: Array = await HttpHelper.request_with_retry_async(_http_catalog, url, HTTPClient.METHOD_GET, headers)
	var err: int = raw[0]
	if err != OK:
		push_warning("ShopService.get_catalog_async: request error %d" % err)
		return []
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code != 200:
		push_warning("ShopService.get_catalog_async: HTTP %d" % status_code)
		return []
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("ShopService.get_catalog_async: JSON parse error")
		return []
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Array:
		return []
	var result: Array[ShopItem] = []
	for item_dict: Variant in data:
		if not item_dict is Dictionary:
			continue
		var item := ShopItem.new()
		var d := item_dict as Dictionary
		item.id        = str(d.get("id", ""))
		item.name      = str(d.get("name", ""))
		item.description = str(d.get("description", ""))
		item.price     = int(d.get("price", 0))
		item.category  = str(d.get("category", ""))
		item.image_url = str(d.get("imageUrl", ""))
		item.is_active = bool(d.get("isActive", true))
		result.append(item)
	return result

func purchase_async(base_url: String, token: String, prefixed_id: String, quantity: int) -> Dictionary:
	var headers := HttpHelper.make_headers(token)
	headers.append("Content-Type: application/json")
	var body_str := HttpHelper.encode_body({"itemId": prefixed_id, "quantity": quantity})
	var raw: Array = await HttpHelper.request_with_retry_async(_http_purchase, base_url + "/api/shop/purchase", HTTPClient.METHOD_POST, headers, body_str)
	var err: int = raw[0]
	if err != OK:
		push_warning("ShopService.purchase_async: request error %d" % err)
		return {}
	var status_code: int = raw[1]
	var body: PackedByteArray = raw[3]
	if status_code != 200:
		push_warning("ShopService.purchase_async: HTTP %d" % status_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("ShopService.purchase_async: JSON parse error")
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(json.get_data())
	if not data is Dictionary:
		return {}
	return data as Dictionary
