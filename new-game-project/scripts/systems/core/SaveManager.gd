# scripts/systems/core/SaveManager.gd
class_name SaveManager extends Node

# Save/Load system following clean architecture
# Supports local saves and cloud saves (Firestore) when signed in

signal save_completed(success: bool)
signal load_completed(success: bool, data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)
signal cloud_sync_completed
signal cloud_sync_failed(error: String)

const SAVE_FILE_PATH = "user://save_game.dat"  # Match GameCoordinator path
const SAVE_VERSION = "1.1"
const KNOWN_VERSIONS: Array[String] = ["1.0", "1.1"]

var auto_save_enabled: bool = true
var auto_save_interval: float = 60.0  # 1 minute - shorter interval to prevent data loss
var last_auto_save: float = 0.0
var cloud_save_enabled: bool = true  # Sync to cloud when signed in

# Player-specific data that doesn't belong to any system
var player_data: Dictionary = {}

# Firebase integration reference (set during initialization)
var _firebase_integration = null

func _ready() -> void:
	_connect_firebase()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _process(delta: float) -> void:
	if auto_save_enabled:
		last_auto_save += delta
		if last_auto_save >= auto_save_interval:
			auto_save()
			last_auto_save = 0.0

## Save game data
func save_game() -> bool:
	print("[SaveManager] save_game() called")

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

	var tutorial_orchestrator = system_registry.get_system("TutorialOrchestrator") if system_registry else null
	if tutorial_orchestrator and tutorial_orchestrator.has_method("get_tutorial_save_data"):
		save_data["tutorial"] = tutorial_orchestrator.get_tutorial_save_data()

	var arena_manager = system_registry.get_system("ArenaManager") if system_registry else null
	if arena_manager and arena_manager.has_method("get_save_data"):
		save_data["arena"] = arena_manager.get_save_data()

	var player_progression = system_registry.get_system("PlayerProgressionManager") if system_registry else null
	if player_progression and player_progression.has_method("get_save_data"):
		save_data["player_progression"] = player_progression.get_save_data()

	var equipment_manager = system_registry.get_system("EquipmentManager") if system_registry else null
	if equipment_manager and equipment_manager.has_method("get_save_data"):
		save_data["equipment"] = equipment_manager.get_save_data()

	var shop_manager = system_registry.get_system("ShopManager") if system_registry else null
	if shop_manager and shop_manager.has_method("get_save_data"):
		save_data["shop"] = shop_manager.get_save_data()

	var skin_manager = system_registry.get_system("SkinManager") if system_registry else null
	if skin_manager and skin_manager.has_method("get_save_data"):
		save_data["skins"] = skin_manager.get_save_data()

	var achievement_manager = system_registry.get_system("AchievementManager") if system_registry else null
	if achievement_manager and achievement_manager.has_method("get_save_data"):
		save_data["achievements"] = achievement_manager.get_save_data()

	# Save player-specific data (tower best floor, etc.)
	save_data["player_data"] = player_data

	# Write to file
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		var error = "Failed to open save file for writing"
		save_failed.emit(error)
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()

	print("[SaveManager] Save completed successfully to: %s" % SAVE_FILE_PATH)
	print("[SaveManager] Save data keys: %s" % str(save_data.keys()))

	save_completed.emit(true)

	# Trigger cloud save if signed in
	_trigger_cloud_save(save_data)

	return true

## Load game data
func load_game() -> bool:
	print("[SaveManager] load_game() called, checking: %s" % SAVE_FILE_PATH)

	var save_data: Dictionary = _read_save_file()
	if save_data.is_empty():
		return false

	# Validate save data structure before loading
	if not _validate_save_data(save_data):
		load_failed.emit("Save data failed validation — may be corrupted")
		return false

	# Migrate save data if version differs
	var version: String = save_data.get("version", "0.0")
	if version != SAVE_VERSION:
		save_data = _migrate_save_data(save_data, version)

	# Load data into all systems
	var system_registry := SystemRegistry.get_instance()
	_load_systems_from_data(save_data, system_registry)

	load_completed.emit(true, save_data)
	return true

## Read and parse the local save file, returning the parsed Dictionary (empty on failure)
func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		var error := "Save file does not exist"
		print("[SaveManager] ERROR: %s" % error)
		load_failed.emit(error)
		return {}

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		var error := "Failed to open save file for reading"
		print("[SaveManager] ERROR: %s" % error)
		load_failed.emit(error)
		return {}

	var json_string := file.get_as_text()
	file.close()

	print("[SaveManager] Loaded %d bytes from save file" % json_string.length())

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		var error := "Failed to parse save file JSON"
		print("[SaveManager] ERROR: %s" % error)
		load_failed.emit(error)
		return {}

	var save_data: Dictionary = json.data
	print("[SaveManager] Parsed save data, keys: %s" % str(save_data.keys()))
	return save_data

## Validate save data structure — checks required keys and expected types.
## Returns true if the data looks safe to load, false if corrupted.
func _validate_save_data(save_data: Dictionary) -> bool:
	# Required top-level keys
	if not save_data.has("version"):
		push_warning("SaveManager: Save data missing 'version' key")
		return false

	if not save_data["version"] is String:
		push_warning("SaveManager: 'version' is not a String")
		return false

	if not save_data.has("timestamp"):
		push_warning("SaveManager: Save data missing 'timestamp' key")
		return false

	# Validate that known section keys, when present, are Dictionaries
	var dict_sections: Array[String] = [
		"resources", "collection", "battle", "hex_grid", "territory",
		"dungeon", "summon", "tutorial", "arena", "player_progression",
		"equipment", "shop", "skins", "achievements", "player_data",
	]
	for key: String in dict_sections:
		if save_data.has(key) and not save_data[key] is Dictionary:
			push_warning("SaveManager: Section '%s' expected Dictionary, got %s" % [key, typeof(save_data[key])])
			return false

	# Validate collection section has expected structure if present
	if save_data.has("collection"):
		var collection: Dictionary = save_data["collection"]
		if collection.has("gods") and not collection["gods"] is Array:
			push_warning("SaveManager: 'collection.gods' expected Array, got %s" % typeof(collection["gods"]))
			return false

	return true

## Load save data into all game systems via SystemRegistry
func _load_systems_from_data(save_data: Dictionary, system_registry) -> void:
	if not system_registry:
		return

	_load_system_data(system_registry, "ResourceManager", "resources", save_data)
	_load_system_data(system_registry, "CollectionManager", "collection", save_data)

	# Hex grid needs extra logging and offline production calculation
	if save_data.has("hex_grid"):
		print("[SaveManager] hex_grid data found in save")
		var hex_grid_data: Dictionary = save_data.hex_grid
		if hex_grid_data.has("nodes"):
			print("[SaveManager] hex_grid has %d nodes in save data" % hex_grid_data.nodes.size())
		else:
			print("[SaveManager] WARNING: hex_grid has no 'nodes' key!")

		var hex_grid_manager = system_registry.get_system("HexGridManager")
		if hex_grid_manager and hex_grid_manager.has_method("load_save_data"):
			hex_grid_manager.load_save_data(save_data.hex_grid)
		else:
			print("[SaveManager] WARNING: HexGridManager not found or no load_save_data method!")

		_calculate_offline_production_rewards(system_registry, hex_grid_manager)
	else:
		print("[SaveManager] WARNING: No hex_grid data in save file!")

	_load_system_data(system_registry, "TerritoryManager", "territory", save_data)
	_load_system_data(system_registry, "DungeonManager", "dungeon", save_data)
	_load_system_data(system_registry, "SummonManager", "summon", save_data)
	_load_system_data(system_registry, "ArenaManager", "arena", save_data)
	_load_system_data(system_registry, "PlayerProgressionManager", "player_progression", save_data)
	_load_system_data(system_registry, "EquipmentManager", "equipment", save_data)
	_load_system_data(system_registry, "ShopManager", "shop", save_data)
	_load_system_data(system_registry, "SkinManager", "skins", save_data)
	_load_system_data(system_registry, "AchievementManager", "achievements", save_data)

	# After loading arena, restore defense team references
	var arena_manager = system_registry.get_system("ArenaManager")
	if arena_manager and arena_manager.has_method("restore_defense_team_from_ids"):
		arena_manager.restore_defense_team_from_ids()

	# Tutorial uses a different method name
	if save_data.has("tutorial"):
		var tutorial_orchestrator = system_registry.get_system("TutorialOrchestrator")
		if tutorial_orchestrator and tutorial_orchestrator.has_method("load_tutorial_save_data"):
			tutorial_orchestrator.load_tutorial_save_data(save_data.tutorial)

	if save_data.has("player_data"):
		player_data = save_data.player_data

## Helper: load a single system's data if present in save_data
func _load_system_data(system_registry, system_name: String, data_key: String, save_data: Dictionary) -> void:
	if not save_data.has(data_key):
		return
	var system = system_registry.get_system(system_name)
	if system and system.has_method("load_save_data"):
		system.load_save_data(save_data[data_key])

## Migrate save data from older versions to current version via sequential upgrades
func _migrate_save_data(save_data: Dictionary, from_version: String) -> Dictionary:
	var current: String = from_version
	if current not in KNOWN_VERSIONS:
		push_warning("SaveManager: Unknown save version '%s', attempting load without migration" % current)
		save_data["version"] = SAVE_VERSION
		return save_data

	# Apply migrations sequentially: 1.0 → 1.1 → ...
	if current == "1.0":
		save_data = _migrate_1_0_to_1_1(save_data)
		current = "1.1"

	# Future migrations go here:
	# if current == "1.1":
	#     save_data = _migrate_1_1_to_1_2(save_data)
	#     current = "1.2"

	save_data["version"] = SAVE_VERSION
	return save_data

## Migrate from 1.0 → 1.1: move achievements from player_data bag to top-level key
func _migrate_1_0_to_1_1(save_data: Dictionary) -> Dictionary:
	# Achievements were stored inside player_data in v1.0 — promote to top-level
	if not save_data.has("achievements") and save_data.has("player_data"):
		var pd: Dictionary = save_data.get("player_data", {})
		if pd.has("achievements"):
			save_data["achievements"] = pd["achievements"]
			pd.erase("achievements")
	return save_data

## Auto-save
func auto_save():
	save_game()

## Check if save file exists
func has_save_file() -> bool:
	var exists = FileAccess.file_exists(SAVE_FILE_PATH)
	print("[SaveManager] has_save_file() checking: %s -> %s" % [SAVE_FILE_PATH, exists])
	return exists

## Delete save file
func delete_save_file() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		return true
	return false

## Get player data dictionary
func get_player_data() -> Dictionary:
	return player_data

## Set a player data value
func set_player_value(key: String, value) -> void:
	player_data[key] = value

## Get a player data value
func get_player_value(key: String, default = null):
	return player_data.get(key, default)

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

## Calculate offline production and store in nodes for manual collection
## Player collects via "Collect All" on territory screen for satisfying reward moment
func _calculate_offline_production_rewards(system_registry, hex_grid_manager) -> void:
	if not system_registry or not hex_grid_manager:
		return

	var territory_production_manager = system_registry.get_system("TerritoryProductionManager")
	if not territory_production_manager:
		print("[SaveManager] TerritoryProductionManager not found, skipping offline production")
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
	# calculate_offline_hex_production() adds to node.accumulated_resources automatically
	for node in player_nodes:
		var offline_rewards: Dictionary = territory_production_manager.calculate_offline_hex_production(node)

		if not offline_rewards.is_empty():
			nodes_with_production += 1

			# Track total for logging only
			for resource_id in offline_rewards:
				if total_offline_rewards.has(resource_id):
					total_offline_rewards[resource_id] += offline_rewards[resource_id]
				else:
					total_offline_rewards[resource_id] = offline_rewards[resource_id]

	# Log what's waiting to be collected (NOT auto-awarded)
	if not total_offline_rewards.is_empty():
		print("[SaveManager] Offline production stored in nodes (awaiting collection): %s" % _format_rewards_dict(total_offline_rewards))
		print("[SaveManager] %d nodes have resources ready - player can Collect All!" % nodes_with_production)
	else:
		print("[SaveManager] No offline production to store")

## Format rewards dictionary for debug output
func _format_rewards_dict(rewards: Dictionary) -> String:
	if rewards.is_empty():
		return "{}"

	var parts: Array[String] = []
	for resource_id in rewards:
		parts.append("%s: %.1f" % [resource_id, rewards[resource_id]])

	return "{%s}" % ", ".join(parts)

# ==============================================================================
# CLOUD SAVE INTEGRATION
# ==============================================================================

func _connect_firebase():
	"""Connect to FirebaseIntegration for cloud saves"""
	# Defer to allow systems to initialize
	_connect_firebase_deferred.call_deferred()

func _connect_firebase_deferred():
	"""Deferred connection to Firebase"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	_firebase_integration = system_registry.get_system("FirebaseIntegration")
	if _firebase_integration:
		_firebase_integration.cloud_save_completed.connect(_on_cloud_save_completed)
		_firebase_integration.cloud_save_failed.connect(_on_cloud_save_failed)
		_firebase_integration.cloud_load_completed.connect(_on_cloud_load_completed)
		_firebase_integration.cloud_load_failed.connect(_on_cloud_load_failed)
		_firebase_integration.cloud_save_not_found.connect(_on_cloud_save_not_found)
		print("[SaveManager] Connected to FirebaseIntegration for cloud saves")

func _trigger_cloud_save(save_data: Dictionary):
	"""Trigger cloud save if signed in and enabled"""
	if not cloud_save_enabled:
		return

	if not _firebase_integration:
		return

	if not _firebase_integration.is_signed_in():
		return

	if not _firebase_integration.is_cloud_save_ready():
		return

	print("[SaveManager] Triggering cloud save...")
	_firebase_integration.save_to_cloud(save_data)

func load_from_cloud():
	"""Manually load save data from cloud"""
	if not _firebase_integration:
		cloud_sync_failed.emit("Firebase not available")
		return

	if not _firebase_integration.is_cloud_save_ready():
		cloud_sync_failed.emit("Cloud saves not ready")
		return

	print("[SaveManager] Loading from cloud...")
	_firebase_integration.load_from_cloud()

func _on_cloud_save_completed():
	"""Handle successful cloud save"""
	print("[SaveManager] Cloud save completed")
	cloud_sync_completed.emit()

func _on_cloud_save_failed(error: String):
	"""Handle failed cloud save"""
	print("[SaveManager] Cloud save failed: %s" % error)
	cloud_sync_failed.emit(error)

func _on_cloud_load_completed(save_data: Dictionary):
	"""Handle successful cloud load - apply save data to game"""
	print("[SaveManager] Cloud load completed, checking save data...")
	print("[SaveManager] Cloud save_data keys: %s" % str(save_data.keys()))

	# Safety check: Don't apply empty or invalid cloud saves
	# This prevents wiping local data if cloud save is corrupted/empty
	if save_data.is_empty():
		push_warning("SaveManager: Cloud save is empty, ignoring")
		return

	# Validate structure before applying
	if not _validate_save_data(save_data):
		push_warning("SaveManager: Cloud save failed validation, ignoring")
		cloud_sync_failed.emit("Cloud save data corrupted")
		return

	# Check if cloud save has ACTUAL gods/equipment, not just empty arrays
	var has_gods = false
	var has_equipment = false
	if save_data.has("collection"):
		var collection = save_data.collection
		print("[SaveManager] Cloud collection keys: %s" % str(collection.keys() if collection is Dictionary else "not a dict"))
		if collection is Dictionary:
			var gods_array = collection.get("gods", [])
			var equip_array = collection.get("equipment", [])
			has_gods = gods_array is Array and not gods_array.is_empty()
			has_equipment = equip_array is Array and not equip_array.is_empty()
			print("[SaveManager] Cloud save has %d gods, %d equipment" % [gods_array.size() if gods_array is Array else 0, equip_array.size() if equip_array is Array else 0])

	if not has_gods and not has_equipment:
		print("[SaveManager] WARNING: Cloud save has no gods or equipment, IGNORING to prevent data loss")
		return

	print("[SaveManager] Cloud save valid with gods/equipment, applying data...")
	_apply_save_data(save_data)
	cloud_sync_completed.emit()

func _on_cloud_load_failed(error: String):
	"""Handle failed cloud load"""
	print("[SaveManager] Cloud load failed: %s" % error)
	cloud_sync_failed.emit(error)

func _on_cloud_save_not_found():
	"""Handle case where no cloud save exists - push local save to cloud"""
	print("[SaveManager] No cloud save found...")

	# Safety check: Only push to cloud if we have a local save with actual data
	if not has_save_file():
		print("[SaveManager] No local save file either, nothing to push")
		return

	# Extra safety: Check if collection has data before pushing
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			var gods = collection_manager.get_all_gods()
			if gods.is_empty():
				print("[SaveManager] Collection is empty, skipping cloud push (game may not be fully initialized)")
				return

	print("[SaveManager] Pushing local save to cloud...")
	save_game()  # This will trigger cloud save after local save

func _apply_save_data(save_data: Dictionary) -> void:
	var system_registry := SystemRegistry.get_instance()
	if not system_registry:
		load_failed.emit("SystemRegistry not available")
		return

	# Migrate cloud save data if needed
	var version: String = save_data.get("version", "0.0")
	if version != SAVE_VERSION:
		save_data = _migrate_save_data(save_data, version)

	_load_systems_from_data(save_data, system_registry)
	load_completed.emit(true, save_data)
	print("[SaveManager] Cloud save data applied successfully")
