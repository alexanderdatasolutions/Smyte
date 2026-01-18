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

	var hex_grid_manager = system_registry.get_system("HexGridManager") if system_registry else null
	if hex_grid_manager and hex_grid_manager.has_method("get_save_data"):
		save_data["hex_grid"] = hex_grid_manager.get_save_data()

	var territory_manager = system_registry.get_system("TerritoryManager") if system_registry else null
	if territory_manager and territory_manager.has_method("get_save_data"):
		save_data["territory"] = territory_manager.get_save_data()

	var dungeon_manager = system_registry.get_system("DungeonManager") if system_registry else null
	if dungeon_manager and dungeon_manager.has_method("get_save_data"):
		save_data["dungeon"] = dungeon_manager.get_save_data()

	var summon_manager = system_registry.get_system("SummonManager") if system_registry else null
	if summon_manager and summon_manager.has_method("get_save_data"):
		save_data["summon"] = summon_manager.get_save_data()

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

	if save_data.has("hex_grid"):
		var hex_grid_manager = system_registry.get_system("HexGridManager") if system_registry else null
		if hex_grid_manager and hex_grid_manager.has_method("load_save_data"):
			hex_grid_manager.load_save_data(save_data.hex_grid)

		# Calculate offline production rewards for hex nodes
		_calculate_offline_production_rewards(system_registry, hex_grid_manager)

	if save_data.has("territory"):
		var territory_manager = system_registry.get_system("TerritoryManager") if system_registry else null
		if territory_manager and territory_manager.has_method("load_save_data"):
			territory_manager.load_save_data(save_data.territory)

	if save_data.has("dungeon"):
		var dungeon_manager = system_registry.get_system("DungeonManager") if system_registry else null
		if dungeon_manager and dungeon_manager.has_method("load_save_data"):
			dungeon_manager.load_save_data(save_data.dungeon)

	if save_data.has("summon"):
		var summon_manager = system_registry.get_system("SummonManager") if system_registry else null
		if summon_manager and summon_manager.has_method("load_save_data"):
			summon_manager.load_save_data(save_data.summon)

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

## Calculate offline production rewards for hex nodes
func _calculate_offline_production_rewards(system_registry, hex_grid_manager) -> void:
	if not system_registry or not hex_grid_manager:
		return

	var territory_production_manager = system_registry.get_system("TerritoryProductionManager")
	if not territory_production_manager:
		print("[SaveManager] TerritoryProductionManager not found, skipping offline production")
		return

	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		print("[SaveManager] ResourceManager not found, skipping offline production")
		return

	# Get all player-controlled nodes
	var player_nodes: Array = hex_grid_manager.get_player_nodes()
	if player_nodes.is_empty():
		print("[SaveManager] No player nodes found, skipping offline production")
		return

	print("[SaveManager] Calculating offline production for %d player nodes..." % player_nodes.size())

	var total_offline_rewards: Dictionary = {}
	var nodes_with_production: int = 0

	# Calculate offline production for each node
	for node in player_nodes:
		var offline_rewards: Dictionary = territory_production_manager.calculate_offline_hex_production(node)

		if not offline_rewards.is_empty():
			nodes_with_production += 1

			# Accumulate total rewards
			for resource_id in offline_rewards:
				if total_offline_rewards.has(resource_id):
					total_offline_rewards[resource_id] += offline_rewards[resource_id]
				else:
					total_offline_rewards[resource_id] = offline_rewards[resource_id]

	# Award accumulated resources to player
	if not total_offline_rewards.is_empty():
		resource_manager.award_resources(total_offline_rewards)
		print("[SaveManager] Awarded offline production rewards: %s" % _format_rewards_dict(total_offline_rewards))
		print("[SaveManager] %d nodes produced resources while offline" % nodes_with_production)

		# Clear accumulated resources from all nodes
		for node in player_nodes:
			node.accumulated_resources.clear()
	else:
		print("[SaveManager] No offline production rewards to award")

## Format rewards dictionary for debug output
func _format_rewards_dict(rewards: Dictionary) -> String:
	if rewards.is_empty():
		return "{}"

	var parts: Array[String] = []
	for resource_id in rewards:
		parts.append("%s: %.1f" % [resource_id, rewards[resource_id]])

	return "{%s}" % ", ".join(parts)
