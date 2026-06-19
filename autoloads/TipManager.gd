extends Node

signal tips_updated(tips: Array)

@export var use_mock: bool = false

const _SAVE_PATH := "user://tips_cache.json"
const _TipServiceScript := preload("res://services/TipService.gd")

var _tips: Array[GameTip] = []
var _svc: TipService
var _http: HTTPRequest
var _fetch_in_flight: bool = false


func _ready() -> void:
	_svc = _TipServiceScript.new()
	_load_cache()
	if not use_mock:
		_http = HTTPRequest.new()
		_http.timeout = 15.0
		add_child(_http)
	UserManager.login_succeeded.connect(_on_login_succeeded)


func _on_login_succeeded() -> void:
	await refresh_async()


func get_tips() -> Array[GameTip]:
	return _tips.duplicate()


func refresh_async() -> void:
	if _fetch_in_flight:
		return
	if use_mock:
		if _tips.is_empty():
			_tips = TipCatalog.build_offline_fallback()
		tips_updated.emit(_tips)
		return
	if _http == null:
		_apply_fallback_if_empty()
		tips_updated.emit(_tips)
		return
	_fetch_in_flight = true
	var fetched := await _svc.fetch_tips_async(_http, UserManager.base_url)
	_fetch_in_flight = false
	if not fetched.is_empty():
		_tips = fetched
		_save_cache()
	else:
		_load_cache()
		_apply_fallback_if_empty()
	tips_updated.emit(_tips)


func _apply_fallback_if_empty() -> void:
	if _tips.is_empty():
		_tips = TipCatalog.build_offline_fallback()


func _save_cache() -> void:
	var payload: Array = []
	for tip: GameTip in _tips:
		payload.append(tip.to_dict())
	var file := FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("TipManager._save_cache: cannot write %s" % _SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload))


func _load_cache() -> void:
	if not FileAccess.file_exists(_SAVE_PATH):
		return
	var file := FileAccess.open(_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return
	var loaded: Array[GameTip] = []
	for item: Variant in parsed:
		if item is Dictionary:
			loaded.append(GameTip.from_dict(item as Dictionary))
	if not loaded.is_empty():
		_tips = loaded
