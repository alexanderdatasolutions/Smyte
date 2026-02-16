# scripts/systems/core/GameCoordinator.gd
# Main game orchestration - replaces the 1203-line GameManager god class
extends Node

# Core components - untyped to avoid parse-time class_name resolution issues
var system_registry  # SystemRegistry
var event_bus  # EventBus

# Game flow state
var is_initialized: bool = false
var is_paused: bool = false
var loading_operations: Array = []  # Array[String]
var _sign_in_shown: bool = false

func _ready():
	_setup_core_systems()
	_connect_global_events()
	_load_game_data()
	_show_sign_in_screen()

## Show sign-in screen before initializing game
func _show_sign_in_screen():
	# Wait for the scene tree to be fully ready
	await get_tree().process_frame

	_emit_loading("Preparing sign-in...")

	# Load and instance sign-in screen
	var sign_in_scene = load("res://scenes/SignInScreen.tscn")
	if not sign_in_scene:
		push_warning("GameCoordinator: SignInScreen not found, skipping sign-in")
		_emit_loading_complete("Preparing sign-in...")
		_initialize_game()
		return

	var sign_in_screen = sign_in_scene.instantiate()
	if not sign_in_screen:
		push_warning("GameCoordinator: Failed to instantiate SignInScreen")
		_emit_loading_complete("Preparing sign-in...")
		_initialize_game()
		return

	# Add to scene tree (deferred to avoid busy parent error)
	var root = get_tree().root
	root.call_deferred("add_child", sign_in_screen)

	# Wait for it to be added
	await sign_in_screen.tree_entered

	_emit_loading_complete("Preparing sign-in...")

	# Wait for sign-in completion
	var signed_in = await sign_in_screen.sign_in_completed

	_sign_in_shown = true

	# Log analytics event
	var firebase = system_registry.get_system("FirebaseIntegration")
	if firebase and firebase.analytics:
		firebase.analytics.log_event("sign_in_flow_completed", {
			"signed_in": signed_in,
			"method": "google" if signed_in else "skipped"
		})

	# Continue with game initialization
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

## Connect to global events
func _connect_global_events():
	if event_bus:
		event_bus.error_occurred.connect(_on_error_occurred)
		event_bus.loading_started.connect(_on_loading_started)
		event_bus.loading_completed.connect(_on_loading_completed)
		event_bus.save_requested.connect(_on_save_requested)
		event_bus.show_tutorial_requested.connect(_on_show_tutorial_requested)
		event_bus.specialization_unlocked.connect(_on_specialization_unlocked)

## Load game data from JSON files
func _load_game_data():
	_emit_loading("Loading game data...")

	var config_manager = system_registry.get_system("ConfigurationManager")
	if not config_manager:
		push_error("GameCoordinator: ConfigurationManager system not found in registry")
		return

	# ConfigurationManager loads all JSON configs in its _ready() — no further action needed

	_emit_loading_complete("Loading game data...")

## Initialize game systems and start game
func _initialize_game():
	_emit_loading("Initializing systems...")
	
	# Initialize all registered systems
	system_registry.initialize_all_systems()
	
	# Try to load save game using SaveManager
	var save_manager = system_registry.get_system("SaveManager")
	var has_save = save_manager.has_save_file() if save_manager else false
	print("[GameCoordinator] SaveManager found: %s, has_save_file: %s" % [save_manager != null, has_save])

	if save_manager and has_save:
		print("[GameCoordinator] Loading existing save...")
		_load_save_game()
	else:
		print("[GameCoordinator] No save file, starting new game...")
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

## Setup starting gods for new players
func _setup_starting_gods():
	var collection_manager = system_registry.get_system("CollectionManager")
	if collection_manager:
		# Give player a starter god from each element
		var starter_gods = ["ares", "poseidon", "artemis"]  # Fire, Water, Wind
		print("[GameCoordinator] Setting up %d starter gods..." % starter_gods.size())

		# Use late binding to avoid parse-time GodFactory class reference
		var god_factory_script = load("res://scripts/systems/collection/GodFactory.gd")
		for god_id in starter_gods:
			var god = god_factory_script.create_from_json(god_id)
			if god:
				collection_manager.add_god(god)
				print("[GameCoordinator] Added starter god: %s" % god.name)
			else:
				print("[GameCoordinator] ERROR: Failed to create god: %s" % god_id)

		print("[GameCoordinator] Collection now has %d gods" % collection_manager.get_all_gods().size())

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

## Handle window close and other notifications
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Save game when window is closed
		print("GameCoordinator: Window close requested, saving game...")
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Save game when app loses focus (mobile background, alt-tab, etc.)
		if is_initialized:
			print("GameCoordinator: App lost focus, saving game...")
			save_game()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_save_requested():
	save_game()

func _on_error_occurred(error_message: String, context: String):
	push_error("GameCoordinator: Error in " + context + " - " + error_message)

func _on_loading_started(operation: String):
	if not loading_operations.has(operation):
		loading_operations.append(operation)

func _on_loading_completed(operation: String):
	loading_operations.erase(operation)

func _on_show_tutorial_requested(tutorial_data: Dictionary):
	"""Show tutorial dialog when requested by TutorialOrchestrator"""
	# Load and instance the tutorial dialog scene
	var tutorial_dialog_scene = load("res://scenes/TutorialDialog.tscn")
	if not tutorial_dialog_scene:
		push_error("GameCoordinator: TutorialDialog scene not found")
		return

	var tutorial_dialog = tutorial_dialog_scene.instantiate()
	if not tutorial_dialog:
		push_error("GameCoordinator: Failed to instantiate TutorialDialog")
		return

	# Add to current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(tutorial_dialog)
		tutorial_dialog.show_tutorial_step(tutorial_data)

		# Connect to dialog completion to advance tutorial
		var tutorial_orchestrator = system_registry.get_system("TutorialOrchestrator")
		if tutorial_orchestrator and not tutorial_dialog.dialog_completed.is_connected(tutorial_orchestrator.advance_tutorial):
			tutorial_dialog.dialog_completed.connect(tutorial_orchestrator.advance_tutorial)

func _on_specialization_unlocked(god_id: String, spec_id: String):
	"""Trigger tutorial when tier 2+ specialization is unlocked"""
	var specialization_manager = system_registry.get_system("SpecializationManager")
	if not specialization_manager:
		return

	var spec = specialization_manager.get_specialization(spec_id)
	if not spec:
		return

	# Check if this is tier 2 or higher
	if spec.tier >= 2:
		var tutorial_orchestrator = system_registry.get_system("TutorialOrchestrator")
		if tutorial_orchestrator and not tutorial_orchestrator.is_tutorial_completed("hex_specialization_unlock"):
			tutorial_orchestrator.start_tutorial("hex_specialization_unlock")

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
		"system_registry": system_registry.get_debug_info() if system_registry else {}
	}
