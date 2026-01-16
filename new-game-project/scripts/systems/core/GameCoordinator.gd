# scripts/systems/core/GameCoordinator.gd
# Main game orchestration - replaces the 1203-line GameManager god class
extends Node

# Core components - untyped to avoid parse-time class_name resolution issues
var game_state  # GameState
var system_registry  # SystemRegistry
var event_bus  # EventBus

# Game flow state
var is_initialized: bool = false
var is_paused: bool = false
var loading_operations: Array = []  # Array[String]

func _ready():
	_setup_core_systems()
	_connect_global_events()
	_load_game_data()
	_initialize_game()

## Initialize core systems
func _setup_core_systems():
	# Create system registry first (late binding to avoid parse-time class_name issues)
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	system_registry = registry_script.new()
	add_child(system_registry)

	# Register all core systems
	system_registry.register_core_systems()

	# Get EventBus reference
	event_bus = system_registry.get_system("EventBus")

	# Create game state (late binding)
	var game_state_script = load("res://scripts/data/GameState.gd")
	game_state = game_state_script.new()

## Connect to global events
func _connect_global_events():
	if event_bus:
		event_bus.game_paused.connect(_on_game_paused)
		event_bus.game_resumed.connect(_on_game_resumed)
		event_bus.error_occurred.connect(_on_error_occurred)
		event_bus.loading_started.connect(_on_loading_started)
		event_bus.loading_completed.connect(_on_loading_completed)
		event_bus.save_requested.connect(_on_save_requested)

## Load game data from JSON files
func _load_game_data():
	_emit_loading("Loading game data...")
	
	# Load core game data through ConfigurationManager (RULE 5 - proper layering)
	
	# Use local system_registry instance (avoid parse-time SystemRegistry class reference)
	var config_manager = system_registry.get_system("ConfigurationManager")
	if not config_manager:
		push_error("GameCoordinator: ConfigurationManager system not found in registry")
		return
		
	# Store configuration data in game state (ConfigurationManager already loaded all data)
	game_state.store_game_data("gods", config_manager.gods_config)
	game_state.store_game_data("awakened_gods", {})  # Empty initially
	game_state.store_game_data("enemies", {})  # Load from battle config
	game_state.store_game_data("dungeons", {})  # Load from dungeon config  
	game_state.store_game_data("territories", config_manager.territories_config)
	game_state.store_game_data("equipment", config_manager.equipment_config)
	game_state.store_game_data("loot", config_manager.loot_config)
	
	_emit_loading_complete("Loading game data...")

## Initialize game systems and start game
func _initialize_game():
	_emit_loading("Initializing systems...")
	
	# Initialize all registered systems
	system_registry.initialize_all_systems()
	
	# Try to load save game using SaveManager
	var save_manager = system_registry.get_system("SaveManager")
	if save_manager and save_manager.has_save_file():
		_load_save_game()
	else:
		_start_new_game()
	
	is_initialized = true
	_emit_loading_complete("Initializing systems...")

## Load existing save game
func _load_save_game():
	var save_manager = system_registry.get_system("SaveManager")
	if save_manager and save_manager.load_game():
		event_bus.game_loaded.emit()

		# Check if we need to add starter equipment to existing save
		var equipment_manager = system_registry.get_system("EquipmentManager")
		if equipment_manager and equipment_manager.get_unequipped_equipment().is_empty():
			_setup_starting_equipment()
			# Save the updated game
			save_manager.save_game()
	else:
		push_warning("GameCoordinator: Failed to load save game, starting new game")
		_start_new_game()

## Start a new game
func _start_new_game():
	# Initialize default game state
	game_state.initialize_new_game()

	# Give player starting resources and gods
	_setup_starting_resources()
	_setup_starting_gods()
	_setup_starting_equipment()

	event_bus.emit_notification("Welcome to the world of gods!", "info", 3.0)

## Setup starting resources for new players
func _setup_starting_resources():
	var resource_manager = system_registry.get_system("ResourceManager")
	if resource_manager:
		resource_manager.add_resource("gold", 10000)
		resource_manager.add_resource("mana", 1000)
		resource_manager.add_resource("energy", 100)
		resource_manager.add_resource("arena_tokens", 10)

## Setup starting gods for new players
func _setup_starting_gods():
	var collection_manager = system_registry.get_system("CollectionManager")
	if collection_manager:
		# Give player a starter god from each element
		var starter_gods = ["ares", "poseidon", "artemis"]  # Fire, Water, Wind

		# Use late binding to avoid parse-time GodFactory class reference
		var god_factory_script = load("res://scripts/systems/collection/GodFactory.gd")
		for god_id in starter_gods:
			var god = god_factory_script.create_from_json(god_id)
			if god:
				collection_manager.add_god(god)

## Setup starting equipment for new players
func _setup_starting_equipment():
	var equipment_manager = system_registry.get_system("EquipmentManager")
	if equipment_manager:
		# Use late binding to avoid parse-time Equipment class reference
		var equipment_script = load("res://scripts/data/Equipment.gd")

		# Create basic starter equipment manually for now
		# Iron Sword (Weapon)
		var iron_sword = equipment_script.new()
		iron_sword.id = "iron_sword"
		iron_sword.name = "Iron Sword"
		iron_sword.type = equipment_script.EquipmentType.WEAPON
		iron_sword.rarity = equipment_script.Rarity.COMMON
		iron_sword.slot = 1
		iron_sword.main_stat_type = "attack"
		iron_sword.main_stat_base = 45
		iron_sword.main_stat_value = 45
		iron_sword.level = 0
		iron_sword.equipped_by_god_id = ""  # Ensure unequipped state
		equipment_manager.add_equipment_to_inventory(iron_sword)

		# Steel Armor (Armor)
		var steel_armor = equipment_script.new()
		steel_armor.id = "steel_armor"
		steel_armor.name = "Steel Armor"
		steel_armor.type = equipment_script.EquipmentType.ARMOR
		steel_armor.rarity = equipment_script.Rarity.RARE
		steel_armor.slot = 2
		steel_armor.main_stat_type = "defense"
		steel_armor.main_stat_base = 78
		steel_armor.main_stat_value = 78
		steel_armor.level = 0
		steel_armor.equipped_by_god_id = ""  # Ensure unequipped state
		equipment_manager.add_equipment_to_inventory(steel_armor)

		# Mystic Helm (Helm)
		var mystic_helm = equipment_script.new()
		mystic_helm.id = "mystic_helm"
		mystic_helm.name = "Mystic Helm"
		mystic_helm.type = equipment_script.EquipmentType.HELM
		mystic_helm.rarity = equipment_script.Rarity.EPIC
		mystic_helm.slot = 3
		mystic_helm.main_stat_type = "hp"
		mystic_helm.main_stat_base = 580
		mystic_helm.main_stat_value = 580
		mystic_helm.level = 0
		mystic_helm.equipped_by_god_id = ""  # Ensure unequipped state
		equipment_manager.add_equipment_to_inventory(mystic_helm)

## Save game to file
func save_game() -> bool:
	if not is_initialized:
		return false

	var save_manager = system_registry.get_system("SaveManager")
	if save_manager and save_manager.save_game():
		event_bus.game_saved.emit()
		event_bus.emit_notification("Game saved", "success", 2.0)
		return true
	else:
		event_bus.emit_notification("Failed to save game", "error", 3.0)
		return false

## Get system by name (convenience method)
func get_system(system_name: String) -> Node:
	if system_registry:
		return system_registry.get_system(system_name)
	return null

## Get system by type (convenience method)
func get_system_by_type(type: GDScript) -> Node:
	if system_registry:
		return system_registry.get_system_by_type(type)
	return null

## Pause game
func pause_game():
	if is_paused:
		return

	is_paused = true
	get_tree().paused = true
	event_bus.game_paused.emit()

## Resume game
func resume_game():
	if not is_paused:
		return

	is_paused = false
	get_tree().paused = false
	event_bus.game_resumed.emit()

## Shutdown game cleanly
func shutdown_game():
	# Save before shutdown
	save_game()

	# Shutdown all systems
	if system_registry:
		system_registry.shutdown_all_systems()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_game_paused():
	pass

func _on_game_resumed():
	pass

func _on_save_requested():
	save_game()

func _on_error_occurred(error_message: String, context: String):
	push_error("GameCoordinator: Error in " + context + " - " + error_message)

func _on_loading_started(operation: String):
	if not loading_operations.has(operation):
		loading_operations.append(operation)

func _on_loading_completed(operation: String):
	loading_operations.erase(operation)

# ============================================================================
# HELPER METHODS
# ============================================================================

func _emit_loading(operation: String):
	loading_operations.append(operation)
	event_bus.loading_started.emit(operation)

func _emit_loading_complete(operation: String):
	loading_operations.erase(operation)
	event_bus.loading_completed.emit(operation)

## Get current loading status
func is_loading() -> bool:
	return loading_operations.size() > 0

## Get debug information
func get_debug_info() -> Dictionary:
	return {
		"initialized": is_initialized,
		"paused": is_paused,
		"loading_operations": loading_operations.duplicate(),
		"system_registry": system_registry.get_debug_info() if system_registry else {},
		"game_state_valid": game_state != null
	}
