# scripts/systems/core/GameCoordinator.gd
# Main game orchestration - replaces the 1203-line GameManager god class
extends Node

# Discord webhook for announcements
const DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1473115579559710845/jowJ3u5ZMyVmFdhhpQPlCyH1RnTfeCrvPSQ_CiI3qJREu8ooZe6TfAZr-XClFkscv0J2"

# Core components - untyped to avoid parse-time class_name resolution issues
var system_registry  # SystemRegistry
var event_bus  # EventBus

# Game flow state
var is_initialized: bool = false
var is_paused: bool = false
var loading_operations: Array = []  # Array[String]
var _sign_in_shown: bool = false

# Debug overlay
var _steam_debug_overlay: Control = null

func _ready():
	_setup_core_systems()
	_connect_global_events()
	_load_game_data()
	_show_sign_in_screen()

func _input(event: InputEvent) -> void:
	# F10 toggles Steam debug overlay
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		_toggle_steam_debug_overlay()

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

	# Connect to achievement completions for global popups (like free skin pick)
	var achievement_manager = system_registry.get_system("AchievementManager")
	if achievement_manager and achievement_manager.has_signal("achievement_completed"):
		achievement_manager.achievement_completed.connect(_on_achievement_completed_global)

	# Check if data was already loaded from cloud (via SignInScreen)
	var save_manager = system_registry.get_system("SaveManager")
	var data_already_loaded = save_manager.has_data() if save_manager else false

	if data_already_loaded:
		print("GameCoordinator: Data already loaded from cloud")
		_post_load_setup()
	else:
		print("GameCoordinator: No cloud data - starting new game")
		_start_new_game()

	is_initialized = true
	_emit_loading_complete("Initializing systems...")

## Post-load setup after cloud data is loaded
func _post_load_setup():
	event_bus.game_loaded.emit()

	var save_manager = system_registry.get_system("SaveManager")

	# Check if we need to add starter equipment to existing save
	var equipment_manager = system_registry.get_system("EquipmentManager")
	if equipment_manager and equipment_manager.get_unequipped_equipment().is_empty():
		_setup_starting_equipment()
		if save_manager:
			save_manager.save_game()

	# Safety check: if save loaded but no gods, give starter gods
	var collection_manager = system_registry.get_system("CollectionManager")
	if collection_manager and collection_manager.gods.is_empty():
		print("GameCoordinator: Save had no gods, adding starters")
		_setup_starting_gods()
		if save_manager:
			save_manager.save_game()

## Start a new game
func _start_new_game():
	print("GameCoordinator: Setting up new game...")

	# Give player starting resources and gods
	_setup_starting_resources()
	_setup_starting_gods()
	_setup_starting_equipment()

	# Mark data as loaded so auto-save works for new players too
	var save_manager = system_registry.get_system("SaveManager")
	if save_manager:
		save_manager.data_loaded = true
		# Immediately save to cloud so new player data persists
		print("GameCoordinator: Saving new game to cloud...")
		save_manager.save_game()

	# Announce new player to Discord
	_announce_new_player_to_discord()

	event_bus.emit_notification("Welcome to the world of gods!", "info", 3.0)

	# Emit game_loaded so WorldView and other systems know game is ready
	event_bus.game_loaded.emit()

## Announce new player welcome to Discord
func _announce_new_player_to_discord():
	if DISCORD_WEBHOOK_URL.is_empty():
		return

	# Get player display name - try multiple sources
	var player_name: String = "A new adventurer"

	# Try SaveManager first
	var save_manager = system_registry.get_system("SaveManager")
	if save_manager:
		var saved_name: String = save_manager.get_player_value("display_name", "")
		if not saved_name.is_empty():
			player_name = saved_name
			print("GameCoordinator: Found display_name in SaveManager: %s" % player_name)

	# Fallback: try Firebase user_data
	if player_name == "A new adventurer":
		var firebase = system_registry.get_system("FirebaseIntegration")
		if firebase and firebase.user_data:
			var fb_name: String = firebase.user_data.get("displayname", "")
			if fb_name.is_empty():
				fb_name = firebase.user_data.get("display_name", "")
			if fb_name.is_empty():
				# Try email prefix as last resort
				var email: String = firebase.user_data.get("email", "")
				if not email.is_empty() and "@" in email:
					fb_name = email.split("@")[0]
			if not fb_name.is_empty():
				player_name = fb_name
				print("GameCoordinator: Found display_name in Firebase: %s" % player_name)

	# Build Discord embed
	var embed: Dictionary = {
		"title": "👋 New Player",
		"description": "**%s** just joined!" % player_name,
		"color": 5814783,  # Blue color
		"timestamp": Time.get_datetime_string_from_system(true)
	}

	var payload: Dictionary = {
		"embeds": [embed]
	}

	# Fire and forget HTTP request
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, _body): http.queue_free())

	var json_body: String = JSON.stringify(payload)
	var headers: Array = ["Content-Type: application/json"]
	http.request(DISCORD_WEBHOOK_URL, headers, HTTPClient.METHOD_POST, json_body)

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
	if not collection_manager:
		push_error("GameCoordinator: CollectionManager not found!")
		return

	# Give player a starter god from each element
	var starter_gods = ["ares", "poseidon", "artemis"]  # Fire, Water, Wind

	# Use late binding to avoid parse-time GodFactory class reference
	var god_factory_script = load("res://scripts/systems/collection/GodFactory.gd")
	if not god_factory_script:
		push_error("GameCoordinator: GodFactory script not found!")
		return

	var gods_added = 0
	for god_id in starter_gods:
		var god = god_factory_script.create_from_json(god_id)
		if god:
			collection_manager.add_god(god)
			gods_added += 1
			print("GameCoordinator: Added starter god '%s'" % god_id)
		else:
			push_error("GameCoordinator: Failed to create god '%s'" % god_id)

	print("GameCoordinator: Added %d starter gods (total: %d)" % [gods_added, collection_manager.gods.size()])
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
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Save game when app loses focus (mobile background, alt-tab, etc.)
		if is_initialized:
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

## Handle global achievement completions (for popups that should show regardless of screen)
func _on_achievement_completed_global(achievement_id: String, _achievement_data: Dictionary) -> void:
	if achievement_id == "legendary_champion":
		_show_free_skin_popup()

## Show the free skin selection popup
func _show_free_skin_popup() -> void:
	var skin_manager: Node = system_registry.get_system("SkinManager") if system_registry else null
	if not skin_manager:
		return

	var pending_god_id: String = skin_manager.get_pending_free_skin_god()
	if pending_god_id.is_empty():
		return

	# Create and show the popup on the current scene
	var popup: FreeSkinPickPopup = FreeSkinPickPopup.new()
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		current_scene.add_child(popup)
		popup.show_for_god(pending_god_id)
		print("GameCoordinator: Showing free skin popup for god: %s" % pending_god_id)

# ============================================================================
# STEAM DEBUG OVERLAY
# ============================================================================

func _toggle_steam_debug_overlay() -> void:
	"""Toggle Steam debug overlay (F12)"""
	if _steam_debug_overlay and is_instance_valid(_steam_debug_overlay):
		_steam_debug_overlay.queue_free()
		_steam_debug_overlay = null
		return

	# Create overlay
	_steam_debug_overlay = _create_steam_debug_overlay()
	get_tree().root.add_child(_steam_debug_overlay)

func _create_steam_debug_overlay() -> Control:
	"""Create Steam debug overlay UI"""
	var overlay := Control.new()
	overlay.name = "SteamDebugOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background panel (semi-transparent, top-left corner)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(500, 400)
	panel.position = Vector2(10, 10)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	# VBox for content
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.custom_minimum_size = Vector2(480, 380)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "STEAM DEBUG (F10 to close)"
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Status label (will be updated)
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(status_label)

	# Test button - use the actual achievement ID from achievements.json
	var test_btn := Button.new()
	test_btn.text = "Test Unlock 'first_territory' Achievement"
	test_btn.pressed.connect(_test_steam_achievement)
	vbox.add_child(test_btn)

	# Refresh button
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Status"
	refresh_btn.pressed.connect(_refresh_steam_debug)
	vbox.add_child(refresh_btn)

	# Initial status update
	_update_steam_debug_status(status_label)

	return overlay

func _update_steam_debug_status(label: Label) -> void:
	"""Update debug status text"""
	var steam_manager: Node = system_registry.get_system("SteamManager") if system_registry else null
	if steam_manager and steam_manager.has_method("get_debug_status"):
		label.text = steam_manager.get_debug_status()
	else:
		label.text = "SteamManager not found or no get_debug_status method"

func _refresh_steam_debug() -> void:
	"""Refresh the debug overlay"""
	if _steam_debug_overlay and is_instance_valid(_steam_debug_overlay):
		var label: Label = _steam_debug_overlay.find_child("StatusLabel", true, false)
		if label:
			_update_steam_debug_status(label)

func _test_steam_achievement() -> void:
	"""Test unlocking an achievement directly"""
	var steam_manager: Node = system_registry.get_system("SteamManager") if system_registry else null
	if steam_manager and steam_manager.has_method("unlock_achievement"):
		# Use the actual achievement ID from achievements.json, NOT the display name
		steam_manager.unlock_achievement("first_territory")
		# Refresh display after attempt
		_refresh_steam_debug()
