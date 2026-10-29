extends RefCounted
class_name SaveSystem

## Versioned JSON save/load in user://. No network, no external deps.

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


static func save_game(path: String, data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = CURRENT_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for writing (error %s)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func load_game(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: cannot open %s for reading (error %s)" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: %s is not valid JSON object" % path)
		return {}
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version > CURRENT_VERSION:
		push_error("SaveSystem: save version %d is newer than supported %d" % [version, CURRENT_VERSION])
		return {}
	if version < CURRENT_VERSION:
		data = _migrate(data, version)
	data["version"] = CURRENT_VERSION
	return data


static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Add future migrations here, one step at a time.
	var migrated := data
	if from_version < 1:
		migrated["migrated_from"] = from_version
	return migrated
