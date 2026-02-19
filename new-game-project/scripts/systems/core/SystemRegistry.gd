# scripts/systems/core/SystemRegistry.gd
# Service locator pattern for clean dependency injection
class_name SystemRegistry extends Node

# Singleton instance
static var _instance: SystemRegistry = null

# System storage
var _systems: Dictionary = {}
var _system_types: Dictionary = {}
var _initialization_order: Array = []

# Shutdown state
var _is_shutting_down: bool = false
var _shutdown_overlay: CanvasLayer = null

## Get the singleton instance
static func get_instance() -> SystemRegistry:
	if not _instance:
		push_error("SystemRegistry: Instance not created. Make sure to create it in main scene.")
		return null
	return _instance

## Initialize the singleton instance
func _init() -> void:
	if _instance == null:
		_instance = self
	else:
		push_error("SystemRegistry: Multiple instances not allowed. Use get_instance()")

func _ready() -> void:
	# Prevent auto-quit so we can do async shutdown
	get_tree().set_auto_accept_quit(false)

## Handle app close/quit - shutdown all systems in reverse order
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _is_shutting_down:
			return  # Already shutting down
		print("SystemRegistry: Shutdown requested, cleaning up systems...")
		_start_async_shutdown()

## Start async shutdown process with UI feedback
func _start_async_shutdown() -> void:
	_is_shutting_down = true
	_show_shutdown_overlay()
	# Use call_deferred to allow the overlay to render before blocking
	call_deferred("_perform_async_shutdown")

func _perform_async_shutdown() -> void:
	await shutdown_all_systems()
	print("SystemRegistry: All systems shut down, quitting...")
	_hide_shutdown_overlay()
	get_tree().quit()

func _show_shutdown_overlay() -> void:
	if _shutdown_overlay:
		return

	_shutdown_overlay = CanvasLayer.new()
	_shutdown_overlay.layer = 128  # On top of everything
	add_child(_shutdown_overlay)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutdown_overlay.add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutdown_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Saving text
	var label := Label.new()
	label.text = "Saving..."
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Please wait while your progress is saved"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

func _hide_shutdown_overlay() -> void:
	if _shutdown_overlay and is_instance_valid(_shutdown_overlay):
		_shutdown_overlay.queue_free()
		_shutdown_overlay = null

## Register a system with the registry
func register_system(system_name: String, system: Node, initialize_immediately: bool = true) -> void:
	if _systems.has(system_name):
		push_warning("SystemRegistry: System '" + system_name + "' is already registered. Replacing.")
		remove_system(system_name)
	
	_systems[system_name] = system
	_system_types[system_name] = system.get_script()
	
	# Add to scene tree if not already added
	if not system.is_inside_tree():
		add_child(system)
		system.name = system_name + "System"
	
	# Track initialization order
	_initialization_order.append(system_name)

	# Initialize if requested
	if initialize_immediately and system.has_method("initialize"):
		system.initialize()

## Get a system by name
func get_system(system_name: String) -> Node:
	if not _systems.has(system_name):
		# Don't error - systems may not be registered yet during initialization
		return null
	return _systems[system_name]

## Check if a system is registered
func has_system(system_name: String) -> bool:
	return _systems.has(system_name)

## Remove a system from the registry
func remove_system(system_name: String) -> bool:
	if not _systems.has(system_name):
		return false
	
	var system: Node = _systems[system_name]
	_systems.erase(system_name)
	_system_types.erase(system_name)
	_initialization_order.erase(system_name)

	if system and is_instance_valid(system):
		system.queue_free()

	return true

## Get all registered system names
func get_system_names() -> Array:
	return _systems.keys()

## Get system count
func get_system_count() -> int:
	return _systems.size()

## Initialize all systems in registration order
func initialize_all_systems() -> void:
	for system_name: String in _initialization_order:
		var system: Node = _systems[system_name]
		if system and system.has_method("initialize"):
			system.initialize()

## Shutdown all systems in reverse registration order
func shutdown_all_systems() -> void:
	# Reverse order - shutdown dependencies first
	var reversed_order: Array = _initialization_order.duplicate()
	reversed_order.reverse()

	for system_name: String in reversed_order:
		var system: Node = _systems.get(system_name)
		if system and is_instance_valid(system) and system.has_method("shutdown"):
			print("SystemRegistry: Shutting down %s" % system_name)
			# Some shutdowns are async (like FirebaseIntegration.shutdown)
			var result = system.shutdown()
			# Await coroutines to ensure they complete before quitting
			if result is Signal:
				await result

## Get system registry statistics for debugging
func get_debug_info() -> Dictionary:
	var info: Dictionary = {
		"total_systems": _systems.size(),
		"systems": {},
		"initialization_order": _initialization_order.duplicate()
	}

	for system_name: String in _systems:
		var system: Node = _systems[system_name]
		info.systems[system_name] = {
			"type": str(_system_types[system_name]),
			"valid": is_instance_valid(system),
			"in_tree": system.is_inside_tree() if is_instance_valid(system) else false,
			"has_initialize": system.has_method("initialize") if is_instance_valid(system) else false,
			"has_shutdown": system.has_method("shutdown") if is_instance_valid(system) else false
		}
	
	return info

## Register standard game systems in proper order
func register_core_systems() -> void:
	_register_core_infrastructure()
	_register_collection_and_territory()
	_register_battle_and_dungeon()
	_register_progression()
	_register_ui_equipment_and_meta()

## Phase 1-2: Core infrastructure and resources (no dependencies)
func _register_core_infrastructure() -> void:
	# Steam MUST be initialized first, before SignInScreen checks for it
	# Note: Don't initialize immediately - AchievementManager isn't registered yet
	# Steam SDK init happens in _ready(), event connection happens in initialize()
	if ResourceLoader.exists("res://scripts/systems/core/SteamManager.gd"):
		var steam_manager := preload("res://scripts/systems/core/SteamManager.gd").new()
		register_system("SteamManager", steam_manager, false)  # defer initialize()

	if ResourceLoader.exists("res://scripts/systems/core/DiscordManager.gd"):
		var discord_manager := preload("res://scripts/systems/core/DiscordManager.gd").new()
		register_system("DiscordManager", discord_manager, false)  # defer initialize()

	var event_bus := preload("res://scripts/systems/core/EventBus.gd").new()
	register_system("EventBus", event_bus)

	# Register DebugLogger early for comprehensive logging
	if ResourceLoader.exists("res://scripts/systems/core/DebugLogger.gd"):
		var debug_logger := preload("res://scripts/systems/core/DebugLogger.gd").new()
		register_system("DebugLogger", debug_logger)

	var save_manager := preload("res://scripts/systems/core/SaveManager.gd").new()
	register_system("SaveManager", save_manager)

	var config_manager := preload("res://scripts/systems/core/ConfigurationManager.gd").new()
	register_system("ConfigurationManager", config_manager)
	config_manager.load_all_configurations()

	if ResourceLoader.exists("res://scripts/systems/resources/ResourceManager.gd"):
		var resource_manager := preload("res://scripts/systems/resources/ResourceManager.gd").new()
		register_system("ResourceManager", resource_manager)

	if ResourceLoader.exists("res://scripts/systems/resources/LootSystem.gd"):
		var loot_system := preload("res://scripts/systems/resources/LootSystem.gd").new()
		register_system("LootSystem", loot_system)

## Phase 3: Collection and territory systems
func _register_collection_and_territory() -> void:
	var collection_manager := preload("res://scripts/systems/collection/CollectionManager.gd").new()
	register_system("CollectionManager", collection_manager)

	if ResourceLoader.exists("res://scripts/systems/territory/HexGridManager.gd"):
		var hex_grid_manager := preload("res://scripts/systems/territory/HexGridManager.gd").new()
		register_system("HexGridManager", hex_grid_manager)

	if ResourceLoader.exists("res://scripts/systems/territory/BuildingManager.gd"):
		var building_manager := preload("res://scripts/systems/territory/BuildingManager.gd").new()
		register_system("BuildingManager", building_manager)

	# NOTE: depends on PlayerProgressionManager which is registered later
	if ResourceLoader.exists("res://scripts/systems/territory/NodeRequirementChecker.gd"):
		var node_requirement_checker := preload("res://scripts/systems/territory/NodeRequirementChecker.gd").new()
		register_system("NodeRequirementChecker", node_requirement_checker)

	if ResourceLoader.exists("res://scripts/systems/territory/TerritoryManager.gd"):
		var territory_manager := preload("res://scripts/systems/territory/TerritoryManager.gd").new()
		register_system("TerritoryManager", territory_manager)

	if ResourceLoader.exists("res://scripts/systems/territory/TerritoryProductionManager.gd"):
		var territory_production := preload("res://scripts/systems/territory/TerritoryProductionManager.gd").new()
		register_system("TerritoryProductionManager", territory_production)

	if ResourceLoader.exists("res://scripts/systems/territory/NodeTaskCalculator.gd"):
		var node_task_calculator := preload("res://scripts/systems/territory/NodeTaskCalculator.gd").new()
		register_system("NodeTaskCalculator", node_task_calculator)

	if ResourceLoader.exists("res://scripts/systems/territory/NodeProductionInfo.gd"):
		var node_production_info := preload("res://scripts/systems/territory/NodeProductionInfo.gd").new()
		register_system("NodeProductionInfo", node_production_info)

	if ResourceLoader.exists("res://scripts/systems/territory/BuildingBuffManager.gd"):
		var building_buff_manager := preload("res://scripts/systems/territory/BuildingBuffManager.gd").new()
		register_system("BuildingBuffManager", building_buff_manager)

## Phase 4: Battle and dungeon systems
func _register_battle_and_dungeon() -> void:
	var battle_coordinator := preload("res://scripts/systems/battle/BattleCoordinator.gd").new()
	register_system("BattleCoordinator", battle_coordinator)

	if ResourceLoader.exists("res://scripts/systems/dungeon/DungeonManager.gd"):
		var dungeon_manager := preload("res://scripts/systems/dungeon/DungeonManager.gd").new()
		register_system("DungeonManager", dungeon_manager)

	if ResourceLoader.exists("res://scripts/systems/dungeon/DungeonCoordinator.gd"):
		var dungeon_coordinator := preload("res://scripts/systems/dungeon/DungeonCoordinator.gd").new()
		register_system("DungeonCoordinator", dungeon_coordinator)

	if ResourceLoader.exists("res://scripts/systems/arena/ArenaManager.gd"):
		var arena_manager := preload("res://scripts/systems/arena/ArenaManager.gd").new()
		register_system("ArenaManager", arena_manager)

## Phase 5: Progression and summoning systems
func _register_progression() -> void:
	if ResourceLoader.exists("res://scripts/systems/progression/PlayerProgressionManager.gd"):
		var progression_manager := preload("res://scripts/systems/progression/PlayerProgressionManager.gd").new()
		register_system("PlayerProgressionManager", progression_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/GodProgressionManager.gd"):
		var god_progression_manager := preload("res://scripts/systems/progression/GodProgressionManager.gd").new()
		register_system("GodProgressionManager", god_progression_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/SacrificeSystem.gd"):
		var sacrifice_system := preload("res://scripts/systems/progression/SacrificeSystem.gd").new()
		register_system("SacrificeSystem", sacrifice_system)

	if ResourceLoader.exists("res://scripts/systems/progression/AwakeningSystem.gd"):
		var awakening_system := preload("res://scripts/systems/progression/AwakeningSystem.gd").new()
		register_system("AwakeningSystem", awakening_system)

	if ResourceLoader.exists("res://scripts/systems/progression/SacrificeManager.gd"):
		var sacrifice_manager := preload("res://scripts/systems/progression/SacrificeManager.gd").new()
		register_system("SacrificeManager", sacrifice_manager)

	if ResourceLoader.exists("res://scripts/systems/collection/SummonManager.gd"):
		var summon_manager := preload("res://scripts/systems/collection/SummonManager.gd").new()
		register_system("SummonManager", summon_manager)

	if ResourceLoader.exists("res://scripts/systems/core/StatisticsManager.gd"):
		var statistics_manager := preload("res://scripts/systems/core/StatisticsManager.gd").new()
		register_system("StatisticsManager", statistics_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/FeatureUnlockManager.gd"):
		var feature_unlock_manager := preload("res://scripts/systems/progression/FeatureUnlockManager.gd").new()
		register_system("FeatureUnlockManager", feature_unlock_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/AchievementManager.gd"):
		var achievement_manager := preload("res://scripts/systems/progression/AchievementManager.gd").new()
		register_system("AchievementManager", achievement_manager)

	# SteamManager is registered in _register_core_infrastructure() (early init)

	if ResourceLoader.exists("res://scripts/systems/tasks/TaskAssignmentManager.gd"):
		var task_assignment_manager := preload("res://scripts/systems/tasks/TaskAssignmentManager.gd").new()
		register_system("TaskAssignmentManager", task_assignment_manager)

## Phase 6-11: UI, equipment, shop, tower, and firebase systems
func _register_ui_equipment_and_meta() -> void:
	if ResourceLoader.exists("res://scripts/systems/ui/ScreenManager.gd"):
		var screen_manager := preload("res://scripts/systems/ui/ScreenManager.gd").new()
		register_system("ScreenManager", screen_manager)

	if ResourceLoader.exists("res://scripts/systems/ui/NotificationManager.gd"):
		var notification_manager := preload("res://scripts/systems/ui/NotificationManager.gd").new()
		register_system("NotificationManager", notification_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/TutorialOrchestrator.gd"):
		var tutorial_orchestrator := preload("res://scripts/systems/progression/TutorialOrchestrator.gd").new()
		register_system("TutorialOrchestrator", tutorial_orchestrator)

	if ResourceLoader.exists("res://scripts/systems/equipment/EquipmentManager.gd"):
		var equipment_manager := preload("res://scripts/systems/equipment/EquipmentManager.gd").new()
		register_system("EquipmentManager", equipment_manager)
		if equipment_manager.stat_calculator:
			register_system("EquipmentStatCalculator", equipment_manager.stat_calculator)

	if ResourceLoader.exists("res://scripts/systems/shop/SkinManager.gd"):
		var skin_manager := preload("res://scripts/systems/shop/SkinManager.gd").new()
		register_system("SkinManager", skin_manager)

	if ResourceLoader.exists("res://scripts/systems/shop/ShopManager.gd"):
		var shop_manager := preload("res://scripts/systems/shop/ShopManager.gd").new()
		register_system("ShopManager", shop_manager)

	if ResourceLoader.exists("res://scripts/systems/tower/TowerManager.gd"):
		var tower_manager := preload("res://scripts/systems/tower/TowerManager.gd").new()
		register_system("TowerManager", tower_manager)

	if ResourceLoader.exists("res://scripts/systems/progression/TeamSaveManager.gd"):
		var team_save_manager := preload("res://scripts/systems/progression/TeamSaveManager.gd").new()
		register_system("TeamSaveManager", team_save_manager)

	if ResourceLoader.exists("res://scripts/systems/firebase/FirebaseIntegration.gd"):
		var firebase_integration := preload("res://scripts/systems/firebase/FirebaseIntegration.gd").new()
		register_system("FirebaseIntegration", firebase_integration)

	if ResourceLoader.exists("res://scripts/systems/leaderboard/LeaderboardDataSync.gd"):
		var leaderboard_data_sync := preload("res://scripts/systems/leaderboard/LeaderboardDataSync.gd").new()
		register_system("LeaderboardDataSync", leaderboard_data_sync)
