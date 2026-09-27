## Local persistence for the whole game state, as JSON in `user://`.
##
## Autoloaded as `SaveManager`. No backend, no accounts, no network — the city
## lives entirely on the device.
extends Node

const SAVE_PATH := "user://metropolis_save.json"
const TEMP_PATH := "user://metropolis_save.tmp"
const SAVE_VERSION := 1


## Returns an empty dictionary when there is no (readable) save file.
func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("SaveManager: save file is corrupt, starting fresh")
	return {}


## Writes atomically: a partial write can never destroy an existing save.
func save_data(data: Dictionary) -> bool:
	var payload := {"version": SAVE_VERSION, "saved_unix": Time.get_unix_time_from_system()}
	payload.merge(data, true)

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open temp file for writing")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)
	)
	if error != OK:
		push_warning("SaveManager: could not commit save file (error %d)" % error)
		return false
	return true


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
