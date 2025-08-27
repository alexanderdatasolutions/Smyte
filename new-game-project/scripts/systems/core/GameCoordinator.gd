# scripts/systems/core/GameCoordinator.gd
# Main game orchestration - replaces the 1203-line GameManager god class
extends Node

# Auto-save configuration
const SAVE_INTERVAL = 300.0  # 5 minutes
const SAVE_FILE_PATH = "user://save_game.dat"

# Core components
var game_state: GameState
var system_registry: SystemRegistry
var event_bus: EventBus
var save_timer: Timer

# Game flow state
var is_initialized: bool = false
var is_paused: bool = false
var loading_operations: Array = []  # Array[String]

func _ready():
	print("GameCoordinator: Starting game initialization...")
	_setup_core_systems()
	_setup_save_timer()
	_connect_global_events()
	_load_game_data()
	_initialize_game()
	print("GameCoordinator: Game initialization complete")

## Initialize core systems
func _setup_core_systems():
	# Create system registry first
	system_registry = SystemRegistry.new()
	add_child(system_registry)
	
	# Register all core systems
	system_registry.register_core_systems()
	
	# Get EventBus reference
	event_bus = system_registry.get_system("EventBus")
	
	# Create game state
	game_state = GameState.new()

## Setup auto-save timer
func _setup_save_timer():
	save_timer = Timer.new()
	save_timer.wait_time = SAVE_INTERVAL
	save_timer.timeout.connect(_on_auto_save)
	save_timer.autostart = true
	add_child(save_timer)

## Connect to global events
func _connect_global_events():
	if event_bus:
		event_bus.game_paused.connect(_on_game_paused)
		event_bus.game_resumed.connect(_on_game_resumed)
		event_bus.error_occurred.connect(_on_error_occurred)
		event_bus.loading_started.connect(_on_loading_started)
		event_bus.loading_completed.connect(_on_loading_completed)

## Load game data from JSON files
func _load_game_data():
	_emit_loading("Loading game data...")
	
	# Load core game data using the new JSONLoader utility
	var data_paths = [
		"res://data/gods.json",
		"res://data/awakened_gods.json",
		"res://data/enemies.json",
		"res://data/dungeons.json",
		"res://data/territories.json",
		"res://data/equipment.json",
		"res://data/loot.json"
	]
	
	for path in data_paths:
		var data = JSONLoader.load_file(path)
		if not data.is_empty():
			game_state.store_game_data(path.get_file().get_basename(), data)
		else:
			push_warning("GameCoordinator: Failed to load " + path)
	
	_emit_loading_complete("Loading game data...")

## Initialize game systems and start game
func _initialize_game():
	_emit_loading("Initializing systems...")
	
	# Initialize all registered systems
	system_registry.initialize_all_systems()
	
	# Try to load save game
	if SaveLoadUtility.has_save_file():
		_load_save_game()
	else:
		_start_new_game()
	
	is_initialized = true
	_emit_loading_complete("Initializing systems...")

## Load existing save game
func _load_save_game():
	print("GameCoordinator: Loading save game...")
	
	var save_data = SaveLoadUtility.load_game()
	if not save_data.is_empty():
		game_state.load_from_save(save_data)
		event_bus.game_loaded.emit()
		print("GameCoordinator: Save game loaded successfully")
	else:
		push_warning("GameCoordinator: Failed to load save game, starting new game")
		_start_new_game()

## Start a new game
func _start_new_game():
	print("GameCoordinator: Starting new game...")
	
	# Initialize default game state
	game_state.initialize_new_game()
	
	# Give player starting resources and gods
	_setup_starting_resources()
	_setup_starting_gods()
	
	event_bus.emit_notification("Welcome to the world of gods!", "info", 3.0)
	print("GameCoordinator: New game started successfully")

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
		
		for god_id in starter_gods:
			var god = GodFactory.create_from_json(god_id)
			if god:
				collection_manager.add_god(god)

## Save game to file
func save_game() -> bool:
	if not is_initialized:
		return false
	
	print("GameCoordinator: Saving game...")
	
	var success = SaveLoadUtility.save_game(game_state)
	if success:
		event_bus.game_saved.emit()
		event_bus.emit_notification("Game saved", "success", 2.0)
	else:
		event_bus.emit_notification("Failed to save game", "error", 3.0)
	
	return success

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
	print("GameCoordinator: Game paused")

## Resume game
func resume_game():
	if not is_paused:
		return
	
	is_paused = false
	get_tree().paused = false
	event_bus.game_resumed.emit()
	print("GameCoordinator: Game resumed")

## Shutdown game cleanly
func shutdown_game():
	print("GameCoordinator: Shutting down game...")
	
	# Save before shutdown
	save_game()
	
	# Shutdown all systems
	if system_registry:
		system_registry.shutdown_all_systems()
	
	# Cleanup
	if save_timer:
		save_timer.stop()
	
	print("GameCoordinator: Game shutdown complete")

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_auto_save():
	if is_initialized and not is_paused:
		save_game()

func _on_game_paused():
	print("GameCoordinator: Received pause event")

func _on_game_resumed():
	print("GameCoordinator: Received resume event")

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
		"game_state_valid": game_state != null,
		"save_timer_active": save_timer.is_stopped() if save_timer else false
	}
