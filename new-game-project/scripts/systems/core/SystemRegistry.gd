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
func _init():
	if _instance == null:
		_instance = self
	else:
		push_error("SystemRegistry: Multiple instances not allowed. Use get_instance()")

## Register a system with the registry
func register_system(system_name: String, system: Node, initialize_immediately: bool = true):
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
		push_error("SystemRegistry: System '" + system_name + "' not found")
		return null
	return _systems[system_name]

## Get a system by type (class)
func get_system_by_type(type: GDScript) -> Node:
	for system_name in _systems:
		var system = _systems[system_name]
		if system.get_script() == type:
			return system
	
	push_error("SystemRegistry: No system found of type " + str(type))
	return null

## Check if a system is registered
func has_system(system_name: String) -> bool:
	return _systems.has(system_name)

## Remove a system from the registry
func remove_system(system_name: String) -> bool:
	if not _systems.has(system_name):
		return false
	
	var system = _systems[system_name]
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
func initialize_all_systems():
	for system_name in _initialization_order:
		var system = _systems[system_name]
		if system and system.has_method("initialize"):
			system.initialize()

## Shutdown all systems in reverse order
func shutdown_all_systems():
	var shutdown_order = _initialization_order.duplicate()
	shutdown_order.reverse()

	for system_name in shutdown_order:
		var system = _systems[system_name]
		if system and system.has_method("shutdown"):
			system.shutdown()

## Get system registry statistics for debugging
func get_debug_info() -> Dictionary:
	var info = {
		"total_systems": _systems.size(),
		"systems": {},
		"initialization_order": _initialization_order.duplicate()
	}
	
	for system_name in _systems:
		var system = _systems[system_name]
		info.systems[system_name] = {
			"type": str(_system_types[system_name]),
			"valid": is_instance_valid(system),
			"in_tree": system.is_inside_tree() if is_instance_valid(system) else false,
			"has_initialize": system.has_method("initialize") if is_instance_valid(system) else false,
			"has_shutdown": system.has_method("shutdown") if is_instance_valid(system) else false
		}
	
	return info

## Register standard game systems in proper order
func register_core_systems():
	"""Register the essential game systems in dependency order"""
	
	# Phase 1: Core infrastructure (no dependencies)
	var event_bus = preload("res://scripts/systems/core/EventBus.gd").new()
	register_system("EventBus", event_bus)
	
	# Save/Load system (core infrastructure)
	var save_manager = preload("res://scripts/systems/core/SaveManager.gd").new()
	register_system("SaveManager", save_manager)
	
	# Phase 1.5: Configuration Manager (uses JSONDataLoader utility directly)
	var config_manager = preload("res://scripts/systems/core/ConfigurationManager.gd").new()
	register_system("ConfigurationManager", config_manager)
	config_manager.load_all_configurations()
	
	# Phase 2: Data and resource systems
	if FileAccess.file_exists("res://scripts/systems/resources/ResourceManager.gd"):
		var resource_manager = preload("res://scripts/systems/resources/ResourceManager.gd").new()
		register_system("ResourceManager", resource_manager)
	
	# Add LootSystem to resources
	if FileAccess.file_exists("res://scripts/systems/resources/LootSystem.gd"):
		var loot_system = preload("res://scripts/systems/resources/LootSystem.gd").new()
		register_system("LootSystem", loot_system)
	
	# Phase 3: Collection systems
	var collection_manager = preload("res://scripts/systems/collection/CollectionManager.gd").new()
	register_system("CollectionManager", collection_manager)
	
	# Phase 3.5: Territory systems (depend on collection and resource systems)
	# HexGridManager first - provides core hex grid functionality
	if FileAccess.file_exists("res://scripts/systems/territory/HexGridManager.gd"):
		var hex_grid_manager = preload("res://scripts/systems/territory/HexGridManager.gd").new()
		register_system("HexGridManager", hex_grid_manager)

	if FileAccess.file_exists("res://scripts/systems/territory/TerritoryManager.gd"):
		var territory_manager = preload("res://scripts/systems/territory/TerritoryManager.gd").new()
		register_system("TerritoryManager", territory_manager)

	if FileAccess.file_exists("res://scripts/systems/territory/TerritoryProductionManager.gd"):
		var territory_production = preload("res://scripts/systems/territory/TerritoryProductionManager.gd").new()
		register_system("TerritoryProductionManager", territory_production)
	
	# Phase 4: Battle systems
	var battle_coordinator = preload("res://scripts/systems/battle/BattleCoordinator.gd").new()
	register_system("BattleCoordinator", battle_coordinator)
	
	# Phase 4.5: Dungeon systems (depend on collection, resource, and battle systems)
	if FileAccess.file_exists("res://scripts/systems/dungeon/DungeonManager.gd"):
		var dungeon_manager = preload("res://scripts/systems/dungeon/DungeonManager.gd").new()
		register_system("DungeonManager", dungeon_manager)
	
	if FileAccess.file_exists("res://scripts/systems/dungeon/DungeonCoordinator.gd"):
		var dungeon_coordinator = preload("res://scripts/systems/dungeon/DungeonCoordinator.gd").new()
		register_system("DungeonCoordinator", dungeon_coordinator)
	
	# Phase 5: Progression systems
	if FileAccess.file_exists("res://scripts/systems/progression/PlayerProgressionManager.gd"):
		var progression_manager = preload("res://scripts/systems/progression/PlayerProgressionManager.gd").new()
		register_system("PlayerProgressionManager", progression_manager)
	
	if FileAccess.file_exists("res://scripts/systems/progression/GodProgressionManager.gd"):
		var god_progression_manager = preload("res://scripts/systems/progression/GodProgressionManager.gd").new()
		register_system("GodProgressionManager", god_progression_manager)
	
	if FileAccess.file_exists("res://scripts/systems/progression/SacrificeSystem.gd"):
		var sacrifice_system = preload("res://scripts/systems/progression/SacrificeSystem.gd").new()
		register_system("SacrificeSystem", sacrifice_system)
	
	if FileAccess.file_exists("res://scripts/systems/progression/AwakeningSystem.gd"):
		var awakening_system = preload("res://scripts/systems/progression/AwakeningSystem.gd").new()
		register_system("AwakeningSystem", awakening_system)
	
	if FileAccess.file_exists("res://scripts/systems/progression/SacrificeManager.gd"):
		var sacrifice_manager = preload("res://scripts/systems/progression/SacrificeManager.gd").new()
		register_system("SacrificeManager", sacrifice_manager)
	
	if FileAccess.file_exists("res://scripts/systems/collection/SummonManager.gd"):
		var summon_manager = preload("res://scripts/systems/collection/SummonManager.gd").new()
		register_system("SummonManager", summon_manager)
	
	# Phase 6: UI systems
	if FileAccess.file_exists("res://scripts/systems/ui/ScreenManager.gd"):
		var screen_manager = preload("res://scripts/systems/ui/ScreenManager.gd").new()
		register_system("ScreenManager", screen_manager)
	
	if FileAccess.file_exists("res://scripts/systems/ui/NotificationManager.gd"):
		var notification_manager = preload("res://scripts/systems/ui/NotificationManager.gd").new()
		register_system("NotificationManager", notification_manager)
	
	if FileAccess.file_exists("res://scripts/systems/progression/TutorialOrchestrator.gd"):
		var tutorial_orchestrator = preload("res://scripts/systems/progression/TutorialOrchestrator.gd").new()
		register_system("TutorialOrchestrator", tutorial_orchestrator)
	
	# Phase 7: Equipment system
	if FileAccess.file_exists("res://scripts/systems/equipment/EquipmentManager.gd"):
		var equipment_manager = preload("res://scripts/systems/equipment/EquipmentManager.gd").new()
		register_system("EquipmentManager", equipment_manager)

		# Register EquipmentStatCalculator separately for direct access
		if equipment_manager.stat_calculator:
			register_system("EquipmentStatCalculator", equipment_manager.stat_calculator)

	# Phase 8: Shop and cosmetics systems
	if FileAccess.file_exists("res://scripts/systems/shop/SkinManager.gd"):
		var skin_manager = preload("res://scripts/systems/shop/SkinManager.gd").new()
		register_system("SkinManager", skin_manager)

	if FileAccess.file_exists("res://scripts/systems/shop/ShopManager.gd"):
		var shop_manager = preload("res://scripts/systems/shop/ShopManager.gd").new()
		register_system("ShopManager", shop_manager)

	# Phase 9: Trait, Role, and Specialization systems (depend on collection systems)
	if FileAccess.file_exists("res://scripts/systems/traits/TraitManager.gd"):
		var trait_manager = preload("res://scripts/systems/traits/TraitManager.gd").new()
		register_system("TraitManager", trait_manager)

	if FileAccess.file_exists("res://scripts/systems/roles/RoleManager.gd"):
		var role_manager = preload("res://scripts/systems/roles/RoleManager.gd").new()
		register_system("RoleManager", role_manager)

	if FileAccess.file_exists("res://scripts/systems/specialization/SpecializationManager.gd"):
		var spec_manager = preload("res://scripts/systems/specialization/SpecializationManager.gd").new()
		register_system("SpecializationManager", spec_manager)

	if FileAccess.file_exists("res://scripts/systems/tasks/TaskAssignmentManager.gd"):
		var task_manager = preload("res://scripts/systems/tasks/TaskAssignmentManager.gd").new()
		register_system("TaskAssignmentManager", task_manager)
		# Connect trait manager to task manager
		if has_system("TraitManager"):
			task_manager.set_trait_manager(get_system("TraitManager"))
