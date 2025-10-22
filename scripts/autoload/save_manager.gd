# res://autoload/save_manager.gd
extends Node

const SAVE_FILE_PATH = "res://user/snaut_save.json"
const SAVE_VERSION = "1.0"

signal save_completed()
signal load_completed()
signal save_failed(error: String)

func _ready():
	print("[SaveManager] Initialized - Save path: %s" % SAVE_FILE_PATH)

func save_game():
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"discovery_data": DiscoveryManager.to_save_dict(),
		"world_state": {
			"current_biome": WorldState.current_biome
		}
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	
	if file:
		file.store_string(json_string)
		file.close()
		print("[SaveManager] Game saved successfully")
		save_completed.emit()
		return true
	else:
		var error = "Failed to open save file for writing"
		push_error("[SaveManager] %s" % error)
		save_failed.emit(error)
		return false

func load_game() -> bool:
	if !FileAccess.file_exists(SAVE_FILE_PATH):
		print("[SaveManager] No save file found")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if !file:
		var error = "Failed to open save file for reading"
		push_error("[SaveManager] %s" % error)
		save_failed.emit(error)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		var error = "Failed to parse save file JSON"
		push_error("[SaveManager] %s" % error)
		save_failed.emit(error)
		return false
	
	var save_data = json.get_data()
	
	# Validate version
	if save_data.get("version", "") != SAVE_VERSION:
		push_warning("[SaveManager] Save version mismatch - may have issues")
	
	# Load discovery data
	if save_data.has("discovery_data"):
		DiscoveryManager.load_from_dict(save_data.discovery_data)
	
	# Load world state
	if save_data.has("world_state"):
		WorldState.current_biome = save_data.world_state.get("current_biome", "starter")
	
	print("[SaveManager] Game loaded successfully")
	load_completed.emit()
	return true

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func delete_save():
	if save_exists():
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("[SaveManager] Save file deleted")
