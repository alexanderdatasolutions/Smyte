# scripts/systems/core/SystemRegistry.gd
# Service locator pattern for clean dependency injection
class_name SystemRegistry extends Node

# Singleton instance
static var _instance: SystemRegistry = null

# System storage
var _systems: Dictionary = {}
var _system_types: Dictionary = {}
var _initialization_order: Array = []

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
	var event_bus := preload("res://scripts/systems/core/EventBus.gd").new()
	register_system("EventBus", event_bus)

	var save_manager := preload("res://scripts/systems/core/SaveManager.gd").new()
	register_system("SaveManager", save_manager)

	var config_manager := preload("res://scripts/systems/core/ConfigurationManager.gd").new()
	register_system("ConfigurationManager", config_manager)
	config_manager.load_all_configurations()

	if FileAccess.file_exists("res://scripts/systems/resources/ResourceManager.gd"):
		var resource_manager := preload("res://scripts/systems/resources/ResourceManager.gd").new()
		register_system("ResourceManager", resource_manager)

	if FileAccess.file_exists("res://scripts/systems/resources/LootSystem.gd"):
		var loot_system := preload("res://scripts/systems/resources/LootSystem.gd").new()
		register_system("LootSystem", loot_system)

## Phase 3: Collection and territory systems
func _register_collection_and_territory() -> void:
	var collection_manager := preload("res://scripts/systems/collection/CollectionManager.gd").new()
	register_system("CollectionManager", collection_manager)

	if FileAccess.file_exists("res://scripts/systems/territory/HexGridManager.gd"):
		var hex_grid_manager := preload("res://scripts/systems/territory/HexGridManager.gd").new()
		register_system("HexGridManager", hex_grid_manager)

	if FileAccess.file_exists("res://scripts/systems/territory/BuildingManager.gd"):
		var building_manager := preload("res://scripts/systems/territory/BuildingManager.gd").new()
		register_system("BuildingManager", building_manager)

	# NOTE: depends on SpecializationManager and PlayerProgressionManager
	# which are registered later. Will resolve dependencies in _ready()
	if FileAccess.file_exists("res://scripts/systems/territory/NodeRequirementChecker.gd"):
		var node_requirement_checker := preload("res://scripts/systems/territory/NodeRequirementChecker.gd").new()
		register_system("NodeRequirementChecker", node_requirement_checker)

	if FileAccess.file_exists("res://scripts/systems/territory/TerritoryManager.gd"):
		var territory_manager := preload("res://scripts/systems/territory/TerritoryManager.gd").new()
		register_system("TerritoryManager", territory_manager)

	if FileAccess.file_exists("res://scripts/systems/territory/TerritoryProductionManager.gd"):
		var territory_production := preload("res://scripts/systems/territory/TerritoryProductionManager.gd").new()
		register_system("TerritoryProductionManager", territory_production)

	if FileAccess.file_exists("res://scripts/systems/territory/NodeTaskCalculator.gd"):
		var node_task_calculator := preload("res://scripts/systems/territory/NodeTaskCalculator.gd").new()
		register_system("NodeTaskCalculator", node_task_calculator)

	if FileAccess.file_exists("res://scripts/systems/territory/NodeProductionInfo.gd"):
		var node_production_info := preload("res://scripts/systems/territory/NodeProductionInfo.gd").new()
		register_system("NodeProductionInfo", node_production_info)

## Phase 4: Battle and dungeon systems
func _register_battle_and_dungeon() -> void:
	var battle_coordinator := preload("res://scripts/systems/battle/BattleCoordinator.gd").new()
	register_system("BattleCoordinator", battle_coordinator)

	if FileAccess.file_exists("res://scripts/systems/dungeon/DungeonManager.gd"):
		var dungeon_manager := preload("res://scripts/systems/dungeon/DungeonManager.gd").new()
		register_system("DungeonManager", dungeon_manager)

	if FileAccess.file_exists("res://scripts/systems/dungeon/DungeonCoordinator.gd"):
		var dungeon_coordinator := preload("res://scripts/systems/dungeon/DungeonCoordinator.gd").new()
		register_system("DungeonCoordinator", dungeon_coordinator)

	if FileAccess.file_exists("res://scripts/systems/arena/ArenaManager.gd"):
		var arena_manager := preload("res://scripts/systems/arena/ArenaManager.gd").new()
		register_system("ArenaManager", arena_manager)

## Phase 5: Progression and summoning systems
func _register_progression() -> void:
	if FileAccess.file_exists("res://scripts/systems/progression/PlayerProgressionManager.gd"):
		var progression_manager := preload("res://scripts/systems/progression/PlayerProgressionManager.gd").new()
		register_system("PlayerProgressionManager", progression_manager)

	if FileAccess.file_exists("res://scripts/systems/progression/GodProgressionManager.gd"):
		var god_progression_manager := preload("res://scripts/systems/progression/GodProgressionManager.gd").new()
		register_system("GodProgressionManager", god_progression_manager)

	if FileAccess.file_exists("res://scripts/systems/progression/SacrificeSystem.gd"):
		var sacrifice_system := preload("res://scripts/systems/progression/SacrificeSystem.gd").new()
		register_system("SacrificeSystem", sacrifice_system)

	if FileAccess.file_exists("res://scripts/systems/progression/AwakeningSystem.gd"):
		var awakening_system := preload("res://scripts/systems/progression/AwakeningSystem.gd").new()
		register_system("AwakeningSystem", awakening_system)

	if FileAccess.file_exists("res://scripts/systems/progression/SacrificeManager.gd"):
		var sacrifice_manager := preload("res://scripts/systems/progression/SacrificeManager.gd").new()
		register_system("SacrificeManager", sacrifice_manager)

	if FileAccess.file_exists("res://scripts/systems/collection/SummonManager.gd"):
		var summon_manager := preload("res://scripts/systems/collection/SummonManager.gd").new()
		register_system("SummonManager", summon_manager)

	if FileAccess.file_exists("res://scripts/systems/core/StatisticsManager.gd"):
		var statistics_manager := preload("res://scripts/systems/core/StatisticsManager.gd").new()
		register_system("StatisticsManager", statistics_manager)

	if FileAccess.file_exists("res://scripts/systems/progression/FeatureUnlockManager.gd"):
		var feature_unlock_manager := preload("res://scripts/systems/progression/FeatureUnlockManager.gd").new()
		register_system("FeatureUnlockManager", feature_unlock_manager)

	if FileAccess.file_exists("res://scripts/systems/progression/AchievementManager.gd"):
		var achievement_manager := preload("res://scripts/systems/progression/AchievementManager.gd").new()
		register_system("AchievementManager", achievement_manager)

## Phase 6-11: UI, equipment, shop, tower, and firebase systems
func _register_ui_equipment_and_meta() -> void:
	if FileAccess.file_exists("res://scripts/systems/ui/ScreenManager.gd"):
		var screen_manager := preload("res://scripts/systems/ui/ScreenManager.gd").new()
		register_system("ScreenManager", screen_manager)

	if FileAccess.file_exists("res://scripts/systems/ui/NotificationManager.gd"):
		var notification_manager := preload("res://scripts/systems/ui/NotificationManager.gd").new()
		register_system("NotificationManager", notification_manager)

	if FileAccess.file_exists("res://scripts/systems/progression/TutorialOrchestrator.gd"):
		var tutorial_orchestrator := preload("res://scripts/systems/progression/TutorialOrchestrator.gd").new()
		register_system("TutorialOrchestrator", tutorial_orchestrator)

	if FileAccess.file_exists("res://scripts/systems/equipment/EquipmentManager.gd"):
		var equipment_manager := preload("res://scripts/systems/equipment/EquipmentManager.gd").new()
		register_system("EquipmentManager", equipment_manager)
		if equipment_manager.stat_calculator:
			register_system("EquipmentStatCalculator", equipment_manager.stat_calculator)

	if FileAccess.file_exists("res://scripts/systems/shop/SkinManager.gd"):
		var skin_manager := preload("res://scripts/systems/shop/SkinManager.gd").new()
		register_system("SkinManager", skin_manager)

	if FileAccess.file_exists("res://scripts/systems/shop/ShopManager.gd"):
		var shop_manager := preload("res://scripts/systems/shop/ShopManager.gd").new()
		register_system("ShopManager", shop_manager)

	if FileAccess.file_exists("res://scripts/systems/tower/TowerManager.gd"):
		var tower_manager := preload("res://scripts/systems/tower/TowerManager.gd").new()
		register_system("TowerManager", tower_manager)

	if FileAccess.file_exists("res://scripts/systems/firebase/FirebaseIntegration.gd"):
		var firebase_integration := preload("res://scripts/systems/firebase/FirebaseIntegration.gd").new()
		register_system("FirebaseIntegration", firebase_integration)
