# scripts/systems/core/ConfigurationManager.gd
# JSON loading system - handles all configuration data loading (150 lines max)
class_name ConfigurationManager extends Node

signal configuration_loaded(config_type: String)
signal all_configurations_loaded

# Cached configuration data
var territories_config: Dictionary = {}
var gods_config: Dictionary = {}
var equipment_config: Dictionary = {}
var resources_config: Dictionary = {}
var battle_config: Dictionary = {}
var loot_config: Dictionary = {}

var is_loaded: bool = false

func _ready():
	print("ConfigurationManager: Initialized")

## Load all game configurations
func load_all_configurations():
	if is_loaded:
		print("ConfigurationManager: Configurations already loaded")
		return
	
	print("ConfigurationManager: Loading all configurations...")
	
	_load_territories_config()
	_load_gods_config()
	_load_equipment_config()
	_load_resources_config()
	_load_battle_config()
	_load_loot_config()
	
	is_loaded = true
	all_configurations_loaded.emit()
	print("ConfigurationManager: All configurations loaded")

## Load territories configuration
func _load_territories_config():
	territories_config = _load_json_file("res://data/territories.json")
	if not territories_config.is_empty():
		configuration_loaded.emit("territories")

## Load gods configuration
func _load_gods_config():
	gods_config = _load_json_file("res://data/gods.json")
	if not gods_config.is_empty():
		configuration_loaded.emit("gods")

## Load equipment configuration
func _load_equipment_config():
	equipment_config = _load_json_file("res://data/equipment.json")
	if not equipment_config.is_empty():
		configuration_loaded.emit("equipment")

## Load resources configuration
func _load_resources_config():
	resources_config = _load_json_file("res://data/resources.json")
	if not resources_config.is_empty():
		configuration_loaded.emit("resources")

## Load battle configuration
func _load_battle_config():
	battle_config = _load_json_file("res://data/battle_config.json")
	if not battle_config.is_empty():
		configuration_loaded.emit("battle")

## Load loot configuration
func _load_loot_config():
	loot_config = _load_json_file("res://data/loot.json")
	if not loot_config.is_empty():
		configuration_loaded.emit("loot")

## Generic JSON file loader
func _load_json_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("ConfigurationManager: Could not open " + file_path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("ConfigurationManager: Error parsing " + file_path + ": " + json.get_error_message())
		return {}
	
	print("ConfigurationManager: Loaded " + file_path)
	return json.get_data()

## Get territories configuration
func get_territories_config() -> Dictionary:
	return territories_config

## Get gods configuration
func get_gods_config() -> Dictionary:
	return gods_config

## Get a specific god configuration by ID
func get_god_config(god_id: String) -> Dictionary:
	# Search in the gods array
	if gods_config.has("gods") and gods_config.gods is Array:
		for god_data in gods_config.gods:
			if god_data.get("id", "") == god_id:
				return god_data
	
	# Check awakened gods data too
	var awakened_gods = _load_json_file("res://data/awakened_gods.json")
	if awakened_gods.has("awakened_gods") and awakened_gods.awakened_gods is Array:
		for god_data in awakened_gods.awakened_gods:
			if god_data.get("id", "") == god_id:
				return god_data
	elif awakened_gods.has(god_id):
		return awakened_gods[god_id]
	
	print("ConfigurationManager: God config not found for ID: ", god_id)
	return {}

## Get equipment configuration
func get_equipment_config() -> Dictionary:
	return equipment_config

## Get resources configuration
func get_resources_config() -> Dictionary:
	return resources_config

## Get battle configuration
func get_battle_config() -> Dictionary:
	return battle_config

## Get loot configuration
func get_loot_config() -> Dictionary:
	return loot_config

## Check if configurations are loaded
func is_configuration_loaded() -> bool:
	return is_loaded

## Reload all configurations (for development)
func reload_configurations():
	is_loaded = false
	territories_config.clear()
	gods_config.clear()
	equipment_config.clear()
	resources_config.clear()
	battle_config.clear()
	loot_config.clear()
	
	load_all_configurations()
