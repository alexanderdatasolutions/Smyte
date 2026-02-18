# scripts/systems/core/SaveManager.gd
class_name SaveManager extends Node

# CLOUD-ONLY Save/Load system
# All save data goes to/from Firestore - no local files to prevent cheating

signal save_completed(success: bool)
signal load_completed(success: bool, data: Dictionary)
signal save_failed(error: String)
signal load_failed(error: String)
signal cloud_sync_completed
signal cloud_sync_failed(error: String)

const SAVE_VERSION = "1.2"
const KNOWN_VERSIONS: Array[String] = ["1.0", "1.1", "1.2"]

var auto_save_enabled: bool = true
var auto_save_interval: float = 15.0  # 15 seconds - more frequent to prevent data loss
var last_auto_save: float = 0.0
var _pending_save: bool = false  # Track if save is needed due to important event
var _save_debounce_time: float = 0.0  # Debounce timer to prevent rapid saves
const SAVE_DEBOUNCE_INTERVAL: float = 2.0  # Minimum seconds between saves

# Player-specific data that doesn't belong to any system
var player_data: Dictionary = {}

# Track if data was loaded from cloud (prevents new game setup if already loaded)
var data_loaded: bool = false

# Firebase integration reference (set during initialization)
var _firebase_integration = null

func _ready() -> void:
	_connect_firebase()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	# Save when app loses focus (user switches apps, mobile backgrounding)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if data_loaded:
			print("SaveManager: App lost focus, saving...")
			save_game()
	# Also handle pause (mobile apps get paused before being killed)
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if data_loaded:
			print("SaveManager: App paused, saving...")
			save_game()

func _process(delta: float) -> void:
	# Update debounce timer
	if _save_debounce_time > 0.0:
		_save_debounce_time -= delta

	# Handle pending saves after debounce clears
	if _pending_save and _save_debounce_time <= 0.0:
		_pending_save = false
		_do_save()

	if auto_save_enabled and data_loaded:
		last_auto_save += delta
		if last_auto_save >= auto_save_interval:
			auto_save()
			last_auto_save = 0.0

## Save game data to cloud (with debouncing to prevent rapid saves)
func save_game() -> bool:
	# If we're within the debounce window, queue the save for later
	if _save_debounce_time > 0.0:
		_pending_save = true
		return true  # Will save after debounce clears

	return _do_save()

## Internal save function - performs actual cloud save
func _do_save() -> bool:
	if not _firebase_integration:
		print("SaveManager: No Firebase integration, cannot save")
		save_failed.emit("Firebase not available")
		return false

	if not _firebase_integration.is_signed_in():
		print("SaveManager: Not signed in, cannot save (firebase_integration=%s)" % _firebase_integration)
		save_failed.emit("Not signed in")
		return false

	if not _firebase_integration.is_cloud_save_ready():
		print("SaveManager: Cloud save not ready")
		save_failed.emit("Cloud save not ready")
		return false

	var save_data = _collect_save_data()

	print("SaveManager: Saving to cloud...")
	_firebase_integration.save_to_cloud(save_data)
	save_completed.emit(true)

	# Start debounce timer to prevent rapid saves
	_save_debounce_time = SAVE_DEBOUNCE_INTERVAL
	return true

## Collect all save data from systems
func _collect_save_data() -> Dictionary:
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

	var statistics_manager = system_registry.get_system("StatisticsManager") if system_registry else null
	if statistics_manager and statistics_manager.has_method("get_save_data"):
		save_data["statistics"] = statistics_manager.get_save_data()

	var tower_manager = system_registry.get_system("TowerManager") if system_registry else null
	if tower_manager and tower_manager.has_method("get_save_data"):
		save_data["tower"] = tower_manager.get_save_data()

	var inventory_manager = system_registry.get_system("InventoryManager") if system_registry else null
	if inventory_manager and inventory_manager.has_method("get_save_data"):
		save_data["inventory"] = inventory_manager.get_save_data()

	# Save player-specific data
	save_data["player_data"] = player_data

	# Also save unlocked_features at top level for reliability
	save_data["unlocked_features"] = player_data.get("unlocked_features", {})

	return save_data

## Check if we have loaded data (replaces has_save_file for cloud-only)
func has_data() -> bool:
	return data_loaded

## Validate save data structure
func _validate_save_data(save_data: Dictionary) -> bool:
	if not save_data.has("version"):
		push_warning("SaveManager: Save data missing 'version' key")
		return false

	if not save_data["version"] is String:
		push_warning("SaveManager: 'version' is not a String")
		return false

	if not save_data.has("timestamp"):
		push_warning("SaveManager: Save data missing 'timestamp' key")
		return false

	var dict_sections: Array[String] = [
		"resources", "collection", "battle", "hex_grid", "territory",
		"dungeon", "summon", "tutorial", "arena", "player_progression",
		"equipment", "shop", "skins", "achievements", "statistics", "tower", "inventory", "player_data",
	]
	for key: String in dict_sections:
		if save_data.has(key) and not save_data[key] is Dictionary:
			push_warning("SaveManager: Section '%s' expected Dictionary, got %s" % [key, typeof(save_data[key])])
			return false

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

	# Hex grid loading and offline production calculation
	if save_data.has("hex_grid"):
		var hex_grid_manager = system_registry.get_system("HexGridManager")
		if hex_grid_manager and hex_grid_manager.has_method("load_save_data"):
			hex_grid_manager.load_save_data(save_data.hex_grid)

		_calculate_offline_production_rewards(system_registry, hex_grid_manager)

	_load_system_data(system_registry, "TerritoryManager", "territory", save_data)
	_load_system_data(system_registry, "DungeonManager", "dungeon", save_data)
	_load_system_data(system_registry, "SummonManager", "summon", save_data)
	_load_system_data(system_registry, "ArenaManager", "arena", save_data)
	_load_system_data(system_registry, "PlayerProgressionManager", "player_progression", save_data)
	_load_system_data(system_registry, "EquipmentManager", "equipment", save_data)
	_load_system_data(system_registry, "ShopManager", "shop", save_data)
	_load_system_data(system_registry, "SkinManager", "skins", save_data)
	_load_system_data(system_registry, "AchievementManager", "achievements", save_data)
	_load_system_data(system_registry, "StatisticsManager", "statistics", save_data)
	_load_system_data(system_registry, "TowerManager", "tower", save_data)
	_load_system_data(system_registry, "InventoryManager", "inventory", save_data)

	# Migrate legacy tower data from player_data bag if present
	if not save_data.has("tower") and save_data.has("player_data"):
		var pd: Dictionary = save_data.get("player_data", {})
		if pd.has("tower_best_floor"):
			var tower_mgr = system_registry.get_system("TowerManager")
			if tower_mgr and tower_mgr.has_method("load_save_data"):
				tower_mgr.load_save_data({
					"best_floor": pd.get("tower_best_floor", 0),
					"best_floor_timestamp": pd.get("tower_best_timestamp", 0),
				})

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
		# MERGE player_data - once unlocked = always unlocked
		var cloud_player_data: Dictionary = save_data.player_data

		var local_unlocks: Dictionary = player_data.get("unlocked_features", {})
		var cloud_unlocks: Dictionary = cloud_player_data.get("unlocked_features", {})
		var top_level_unlocks: Dictionary = save_data.get("unlocked_features", {})

		var merged_unlocks: Dictionary = local_unlocks.duplicate()
		for feature in cloud_unlocks:
			merged_unlocks[feature] = true
		for feature in top_level_unlocks:
			merged_unlocks[feature] = true

		player_data = cloud_player_data
		player_data["unlocked_features"] = merged_unlocks

		# Cleanup old territory loss alerts (older than 48 hours)
		_cleanup_old_territory_alerts()

## Helper: load a single system's data if present in save_data
func _load_system_data(system_registry, system_name: String, data_key: String, save_data: Dictionary) -> void:
	if not save_data.has(data_key):
		return
	var system = system_registry.get_system(system_name)
	if system and system.has_method("load_save_data"):
		system.load_save_data(save_data[data_key])

## Migrate save data from older versions
func _migrate_save_data(save_data: Dictionary, from_version: String) -> Dictionary:
	var current: String = from_version
	if current not in KNOWN_VERSIONS:
		push_warning("SaveManager: Unknown save version '%s', attempting load without migration" % current)
		save_data["version"] = SAVE_VERSION
		return save_data

	if current == "1.0":
		save_data = _migrate_1_0_to_1_1(save_data)
		current = "1.1"

	if current == "1.1":
		save_data = _migrate_1_1_to_1_2(save_data)
		current = "1.2"

	save_data["version"] = SAVE_VERSION
	return save_data

func _migrate_1_0_to_1_1(save_data: Dictionary) -> Dictionary:
	if not save_data.has("achievements") and save_data.has("player_data"):
		var pd: Dictionary = save_data.get("player_data", {})
		if pd.has("achievements"):
			save_data["achievements"] = pd["achievements"]
			pd.erase("achievements")
	return save_data

func _migrate_1_1_to_1_2(save_data: Dictionary) -> Dictionary:
	if not save_data.has("tower") and save_data.has("player_data"):
		var pd: Dictionary = save_data.get("player_data", {})
		if pd.has("tower_best_floor"):
			save_data["tower"] = {
				"best_floor": pd.get("tower_best_floor", 0),
				"best_floor_timestamp": pd.get("tower_best_timestamp", 0),
			}
			pd.erase("tower_best_floor")
			pd.erase("tower_best_timestamp")
	return save_data

## Auto-save
func auto_save():
	save_game()

## Get player data dictionary
func get_player_data() -> Dictionary:
	return player_data

## Set a player data value
func set_player_value(key: String, value) -> void:
	player_data[key] = value

## Get a player data value
func get_player_value(key: String, default = null):
	return player_data.get(key, default)

## Calculate offline production
func _calculate_offline_production_rewards(system_registry, hex_grid_manager) -> void:
	if not system_registry or not hex_grid_manager:
		return

	var territory_production_manager = system_registry.get_system("TerritoryProductionManager")
	if not territory_production_manager:
		return

	var player_nodes: Array = hex_grid_manager.get_player_nodes()
	if player_nodes.is_empty():
		return

	for node in player_nodes:
		territory_production_manager.calculate_offline_hex_production(node)

# ==============================================================================
# CLOUD SAVE INTEGRATION
# ==============================================================================

func _connect_firebase():
	_connect_firebase_deferred.call_deferred()

func _connect_firebase_deferred():
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

	# Connect to EventBus for event-based saving on important actions
	_connect_event_bus_for_saves(system_registry)

func _connect_event_bus_for_saves(system_registry) -> void:
	"""Connect to important events that should trigger immediate saves"""
	var event_bus = system_registry.get_system("EventBus")
	if not event_bus:
		return

	# Territory captured - major progress
	if event_bus.has_signal("territory_captured"):
		event_bus.territory_captured.connect(_on_important_event)

	# God obtained - valuable acquisition
	if event_bus.has_signal("god_obtained"):
		event_bus.god_obtained.connect(_on_important_event)

	# Battle completed - rewards earned
	if event_bus.has_signal("battle_ended"):
		event_bus.battle_ended.connect(_on_important_event)

	# Equipment changes
	if event_bus.has_signal("equipment_equipped"):
		event_bus.equipment_equipped.connect(_on_important_event_multi)
	if event_bus.has_signal("equipment_obtained"):
		event_bus.equipment_obtained.connect(_on_important_event)

	# Arena battles
	if event_bus.has_signal("arena_battle_completed"):
		event_bus.arena_battle_completed.connect(_on_important_event)

	# Dungeon completed
	if event_bus.has_signal("dungeon_completed"):
		event_bus.dungeon_completed.connect(_on_important_event_multi)

	# Summon performed
	if event_bus.has_signal("summon_performed"):
		event_bus.summon_performed.connect(_on_important_event_multi)

	# Territory lost - track for alerts
	if event_bus.has_signal("territory_lost"):
		event_bus.territory_lost.connect(_on_territory_lost)

	# Explicit save requests from other systems
	if event_bus.has_signal("save_requested"):
		event_bus.save_requested.connect(_on_save_requested)

func _on_important_event(_arg = null) -> void:
	"""Handle important events that warrant an immediate save"""
	if data_loaded:
		_pending_save = true
		# Small delay to batch rapid events, then save
		_save_after_delay()

func _on_important_event_multi(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	"""Handle important events with multiple arguments"""
	_on_important_event()

func _on_save_requested() -> void:
	"""Handle explicit save requests from other systems"""
	if data_loaded:
		save_game()

func _on_territory_lost(territory_id: String, node_name: String, reason: String) -> void:
	"""Track territory losses for UI alerts"""
	var lost_territories: Array = player_data.get("lost_territories", [])

	# Map reason to alert type for UI display
	var alert_type: String = "lost"
	match reason:
		"no_garrison":
			alert_type = "lost_garrison"
		"pvp_attack":
			alert_type = "lost_pvp"
		"garrison_defeated":
			alert_type = "lost_garrison"
		_:
			alert_type = "lost_garrison"  # Default fallback

	# Add new loss entry
	var loss_entry: Dictionary = {
		"type": alert_type,
		"node_id": territory_id,
		"node_name": node_name,
		"reason": reason,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	lost_territories.append(loss_entry)

	# Keep only last 10 losses to prevent unbounded growth
	if lost_territories.size() > 10:
		lost_territories = lost_territories.slice(-10)

	player_data["lost_territories"] = lost_territories

	# Trigger save for this important event
	_on_important_event()

func _cleanup_old_territory_alerts() -> void:
	"""Remove territory loss alerts older than 48 hours"""
	var lost_territories: Array = player_data.get("lost_territories", [])
	if lost_territories.is_empty():
		return

	var current_time: int = int(Time.get_unix_time_from_system())
	var max_age_seconds: int = 48 * 3600  # 48 hours

	var filtered: Array = []
	for loss in lost_territories:
		if loss is Dictionary:
			var timestamp: int = int(loss.get("timestamp", 0))
			if current_time - timestamp < max_age_seconds:
				filtered.append(loss)

	player_data["lost_territories"] = filtered

func clear_territory_alerts() -> void:
	"""Manually clear all territory loss alerts (called from UI)"""
	player_data["lost_territories"] = []

var _save_timer: SceneTreeTimer = null
func _save_after_delay() -> void:
	"""Save after a short delay to batch rapid events"""
	if _save_timer != null:
		return  # Already have a pending save timer
	_save_timer = get_tree().create_timer(1.0)  # 1 second delay
	_save_timer.timeout.connect(func():
		_save_timer = null
		if _pending_save and data_loaded:
			_pending_save = false
			save_game()
	)

func load_from_cloud():
	if not _firebase_integration:
		cloud_sync_failed.emit("Firebase not available")
		return

	if not _firebase_integration.is_cloud_save_ready():
		cloud_sync_failed.emit("Cloud saves not ready")
		return

	_firebase_integration.load_from_cloud()

func _on_cloud_save_completed():
	cloud_sync_completed.emit()

func _on_cloud_save_failed(error: String):
	cloud_sync_failed.emit(error)

func _on_cloud_load_completed(save_data: Dictionary):
	if save_data.is_empty():
		push_warning("SaveManager: Cloud save is empty, ignoring")
		return

	if not _validate_save_data(save_data):
		push_warning("SaveManager: Cloud save failed validation, ignoring")
		cloud_sync_failed.emit("Cloud save data corrupted")
		return

	# Check if cloud save has ACTUAL gods/equipment
	var has_gods = false
	var has_equipment = false
	if save_data.has("collection"):
		var collection = save_data.collection
		if collection is Dictionary:
			var gods_array = collection.get("gods", [])
			var equip_array = collection.get("equipment", [])
			has_gods = gods_array is Array and not gods_array.is_empty()
			has_equipment = equip_array is Array and not equip_array.is_empty()

	if not has_gods and not has_equipment:
		return

	apply_save_data(save_data)
	cloud_sync_completed.emit()

func _on_cloud_load_failed(error: String):
	cloud_sync_failed.emit(error)

func _on_cloud_save_not_found():
	# No cloud save - this is a new player, they'll get starter stuff
	print("SaveManager: No cloud save found - new player")

## Apply save data from cloud to all systems
func apply_save_data(save_data: Dictionary) -> void:
	var system_registry := SystemRegistry.get_instance()
	if not system_registry:
		load_failed.emit("SystemRegistry not available")
		return

	# Migrate cloud save data if needed
	var version: String = save_data.get("version", "0.0")
	if version != SAVE_VERSION:
		save_data = _migrate_save_data(save_data, version)

	_load_systems_from_data(save_data, system_registry)

	# Mark that we have loaded data
	data_loaded = true

	load_completed.emit(true, save_data)
