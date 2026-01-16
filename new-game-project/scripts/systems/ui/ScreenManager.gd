class_name ScreenManager
extends Node

"""
ScreenManager.gd
RULE 5: SystemRegistry compliant screen navigation system
RULE 2: Single responsibility - ONLY manages screen transitions
RULE 4: No UI in systems - emits events for UI changes

Following prompt.prompt.md CRITICAL SYSTEMS LIST:
- ScreenManager - Screen navigation (150 lines)
"""

signal screen_changed(screen_name: String)
signal screen_transition_started(from_screen: String, to_screen: String)
signal screen_transition_completed(screen_name: String)

# Current screen tracking
var current_screen: Control
var previous_screen: String = ""
var current_screen_name: String = "worldview"

# Screen registry
var screen_scenes: Dictionary = {}
var loaded_screens: Dictionary = {}

func _ready():
	_register_screen_scenes()

func _register_screen_scenes():
	"""Register all available screen scenes - RULE 2: Single responsibility"""
	screen_scenes = {
		"worldview": "res://scenes/WorldView.tscn",
		"collection": "res://scenes/CollectionScreen.tscn",
		"summon": "res://scenes/SummonScreen.tscn",
		"territory": "res://scenes/TerritoryScreen.tscn",
		"sacrifice": "res://scenes/SacrificeScreen.tscn",
		"sacrifice_selection": "res://scenes/SacrificeSelectionScreen.tscn",
		"dungeon": "res://scenes/DungeonScreen.tscn",
		"equipment": "res://scenes/EquipmentScreen.tscn",
		"battle": "res://scenes/BattleScreen.tscn"
	}

func _normalize_screen_name(screen_name: String) -> String:
	"""Normalize screen name to handle different naming conventions"""
	var normalized = screen_name.to_lower()

	# Handle common aliases
	var aliases = {
		"worldview": "worldview",
		"collectionscreen": "collection",
		"summonscreen": "summon",
		"territoryscreen": "territory",
		"sacrificescreen": "sacrifice",
		"sacrificeselectionscreen": "sacrifice_selection",
		"dungeonscreen": "dungeon",
		"equipmentscreen": "equipment",
		"battlescreen": "battle"
	}

	if aliases.has(normalized):
		return aliases[normalized]

	return normalized

func change_screen(screen_name: String) -> bool:
	"""Change to a different screen - RULE 3: Validate, update, emit"""
	# Normalize screen name to handle different naming conventions
	var normalized_name = _normalize_screen_name(screen_name)

	# 1. Validate
	if not screen_scenes.has(normalized_name):
		push_error("ScreenManager: Screen not found: %s (normalized: %s)" % [screen_name, normalized_name])
		return false

	if normalized_name == current_screen_name:
		return true
	
	# 2. Update
	var old_screen_name = current_screen_name
	screen_transition_started.emit(old_screen_name, normalized_name)

	# Load new screen if not cached
	var new_screen = _get_or_load_screen(normalized_name)
	if not new_screen:
		push_error("ScreenManager: Failed to load screen: %s" % normalized_name)
		return false

	# Switch screens
	_switch_to_screen(new_screen, normalized_name)

	# 3. Emit
	previous_screen = old_screen_name
	current_screen_name = normalized_name
	screen_changed.emit(normalized_name)
	screen_transition_completed.emit(normalized_name)

	return true

func go_back() -> bool:
	"""Go back to previous screen"""
	if previous_screen.is_empty():
		return false

	return change_screen(previous_screen)

func _get_or_load_screen(screen_name: String) -> Control:
	"""Get cached screen or load it - RULE 2: Single responsibility"""
	# Check cache first
	if loaded_screens.has(screen_name):
		return loaded_screens[screen_name]
	
	# Load new screen
	var scene_path = screen_scenes[screen_name]
	var scene_resource = load(scene_path)
	if not scene_resource:
		push_error("ScreenManager: Failed to load scene: %s" % scene_path)
		return null

	var screen_instance = scene_resource.instantiate()
	if not screen_instance:
		push_error("ScreenManager: Failed to instantiate scene: %s" % scene_path)
		return null

	# Cache the screen
	loaded_screens[screen_name] = screen_instance

	return screen_instance

func _switch_to_screen(new_screen: Control, _screen_name: String):
	"""Switch the active screen - RULE 2: Single responsibility"""
	# Get the main scene root
	var main_scene = get_tree().current_scene
	if not main_scene:
		push_error("ScreenManager: No main scene found")
		return

	# Hide ALL loaded screens before showing the new one
	for screen in loaded_screens.values():
		if screen and is_instance_valid(screen):
			screen.visible = false

	# Add new screen if not already in tree
	if not new_screen.get_parent():
		main_scene.add_child(new_screen)

	# Show new screen
	new_screen.visible = true
	current_screen = new_screen
	
	# Connect back signals if available - RULE 4: UI signals to systems
	if new_screen.has_signal("back_pressed"):
		# Disconnect any existing connections
		if new_screen.is_connected("back_pressed", _on_screen_back_pressed):
			new_screen.disconnect("back_pressed", _on_screen_back_pressed)
		# Connect to our handler
		new_screen.connect("back_pressed", _on_screen_back_pressed)

func _on_screen_back_pressed():
	"""Handle back button from screens - RULE 4: UI signals"""
	go_back()

# System interface for SystemRegistry
func initialize():
	"""Initialize the screen manager - called by SystemRegistry"""
	# Set the initial screen to worldview when the system starts
	call_deferred("_set_initial_screen")

func _set_initial_screen():
	"""Set up the initial WorldView screen"""
	# Find the WorldView in the main scene
	var main_scene = get_tree().current_scene
	if not main_scene:
		push_error("ScreenManager: No main scene found")
		return

	var world_view = main_scene.get_node_or_null("WorldView")
	if not world_view:
		push_error("ScreenManager: WorldView not found in main scene")
		return
	
	# Register the existing WorldView as current screen
	current_screen = world_view
	current_screen_name = "worldview"
	loaded_screens["worldview"] = world_view
	
	# Make sure it's visible
	world_view.visible = true

	screen_changed.emit("worldview")
