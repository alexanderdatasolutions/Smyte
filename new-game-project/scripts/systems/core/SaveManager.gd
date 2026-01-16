# scripts/systems/core/SaveManager.gd
class_name SaveManager extends Node

# Save/Load system following clean architecture - 200 lines max

signal save_completed(success: bool)
signal load_completed(success: bool, data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)

const SAVE_FILE_PATH = "user://save_game.dat"  # Match GameCoordinator path
const SAVE_VERSION = "1.0"

var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var last_auto_save: float = 0.0

func _ready():
	pass

func _process(delta):
	if auto_save_enabled:
		last_auto_save += delta
		if last_auto_save >= auto_save_interval:
			auto_save()
			last_auto_save = 0.0

## Save game data
func save_game() -> bool:
	var save_data = {}
	save_data["version"] = SAVE_VERSION
	save_data["timestamp"] = Time.get_unix_time_from_system()
	
	# Get data from all systems through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	var resource_manager = system_registry.get_system("ResourceManager") if system_registry else null
	if resource_manager and resource_manager.has_method("get_save_data"):
		save_data["resources"] = resource_manager.get_save_data()
	
	var collection_manager = system_registry.get_system("CollectionManager") if system_registry else null
	if collection_manager and collection_manager.has_method("get_save_data"):
		save_data["collection"] = collection_manager.get_save_data()
	
	var battle_coordinator = system_registry.get_system("BattleCoordinator") if system_registry else null
	if battle_coordinator and battle_coordinator.has_method("get_save_data"):
		save_data["battle"] = battle_coordinator.get_save_data()
	
	# Write to file
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		var error = "Failed to open save file for writing"
		save_failed.emit(error)
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()

	save_completed.emit(true)
	return true

## Load game data
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		var error = "Save file does not exist"
		load_failed.emit(error)
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		var error = "Failed to open save file for reading"
		load_failed.emit(error)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		var error = "Failed to parse save file JSON"
		load_failed.emit(error)
		return false
	
	var save_data = json.data
	
	# Validate version
	var version = save_data.get("version", "")
	if version != SAVE_VERSION:
		push_warning("SaveManager: Save file version mismatch: " + version + " vs " + SAVE_VERSION)
	
	# Load data into systems through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if save_data.has("resources"):
		var resource_manager = system_registry.get_system("ResourceManager") if system_registry else null
		if resource_manager and resource_manager.has_method("load_save_data"):
			resource_manager.load_save_data(save_data.resources)
	
	if save_data.has("collection"):
		var collection_manager = system_registry.get_system("CollectionManager") if system_registry else null
		if collection_manager and collection_manager.has_method("load_save_data"):
			collection_manager.load_save_data(save_data.collection)

	load_completed.emit(true, save_data)
	return true

## Auto-save
func auto_save():
	save_game()

## Check if save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

## Delete save file
func delete_save_file() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		return true
	return false

## Get save file info
func get_save_info() -> Dictionary:
	if not has_save_file():
		return {}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var save_data = json.data
	return {
		"version": save_data.get("version", "Unknown"),
		"timestamp": save_data.get("timestamp", 0),
		"readable_time": Time.get_datetime_string_from_unix_time(save_data.get("timestamp", 0))
	}
