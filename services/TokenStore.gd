class_name TokenStore
extends RefCounted

# Per-device obfuscation — not cryptographic security.
# OS.get_unique_id() is deterministic per device so the file can be re-read
# after restart without storing the key anywhere.

const _TOKEN_FILE := "user://tokens.dat"

var access_token: String = ""

func save_refresh_token(token: String) -> void:
	var file := FileAccess.open_encrypted_with_pass(_TOKEN_FILE, FileAccess.WRITE, _key())
	if file == null:
		push_warning("TokenStore: cannot write tokens.dat — %s" % FileAccess.get_open_error())
		return
	file.store_string(token)
	file.close()

func load_refresh_token() -> String:
	if not FileAccess.file_exists(_TOKEN_FILE):
		return ""
	var file := FileAccess.open_encrypted_with_pass(_TOKEN_FILE, FileAccess.READ, _key())
	if file == null:
		return ""
	var token := file.get_as_text()
	file.close()
	return token

func clear() -> void:
	access_token = ""
	if FileAccess.file_exists(_TOKEN_FILE):
		DirAccess.remove_absolute(_TOKEN_FILE)

func _key() -> String:
	return OS.get_unique_id()
