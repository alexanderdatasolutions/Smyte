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
	print("ScreenManager: Initializing screen navigation system")
	_register_screen_scenes()

func _register_screen_scenes():
	"""Register all available screen scenes - RULE 2: Single responsibility"""
	screen_scenes = {
		"worldview": "res://scenes/WorldView.tscn",
		"collection": "res://scenes/CollectionScreen.tscn",
		"summon": "res://scenes/SummonScreen.tscn",
		"territory": "res://scenes/TerritoryScreen.tscn",
		"sacrifice": "res://scenes/SacrificeScreen.tscn",
		"dungeon": "res://scenes/DungeonScreen.tscn",
		"equipment": "res://scenes/EquipmentScreen.tscn",
		"battle": "res://scenes/BattleScreen.tscn"
	}
	print("ScreenManager: Registered %d screen scenes" % screen_scenes.size())

func change_screen(screen_name: String) -> bool:
	"""Change to a different screen - RULE 3: Validate, update, emit"""
	print("ScreenManager: Changing screen to: %s" % screen_name)
	
	# 1. Validate
	if not screen_scenes.has(screen_name):
		print("ScreenManager: ERROR - Screen not found: %s" % screen_name)
		return false
	
	if screen_name == current_screen_name:
		print("ScreenManager: Already on screen: %s" % screen_name)
		return true
	
	# 2. Update
	var old_screen_name = current_screen_name
	screen_transition_started.emit(old_screen_name, screen_name)
	
	# Load new screen if not cached
	var new_screen = _get_or_load_screen(screen_name)
	if not new_screen:
		print("ScreenManager: ERROR - Failed to load screen: %s" % screen_name)
		return false
	
	# Switch screens
	_switch_to_screen(new_screen, screen_name)
	
	# 3. Emit
	previous_screen = old_screen_name
	current_screen_name = screen_name
	screen_changed.emit(screen_name)
	screen_transition_completed.emit(screen_name)
	
	return true

func go_back() -> bool:
	"""Go back to previous screen"""
	if previous_screen.is_empty():
		print("ScreenManager: No previous screen to return to")
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
		print("ScreenManager: ERROR - Failed to load scene: %s" % scene_path)
		return null
	
	var screen_instance = scene_resource.instantiate()
	if not screen_instance:
		print("ScreenManager: ERROR - Failed to instantiate scene: %s" % scene_path)
		return null
	
	# Cache the screen
	loaded_screens[screen_name] = screen_instance
	print("ScreenManager: Loaded and cached screen: %s" % screen_name)
	
	return screen_instance

func _switch_to_screen(new_screen: Control, screen_name: String):
	"""Switch the active screen - RULE 2: Single responsibility"""
	# Get the main scene root
	var main_scene = get_tree().current_scene
	if not main_scene:
		print("ScreenManager: ERROR - No main scene found")
		return
	
	# Hide current screen
	if current_screen and is_instance_valid(current_screen):
		current_screen.visible = false
	
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
	
	print("ScreenManager: Switched to screen: %s" % screen_name)

func _on_screen_back_pressed():
	"""Handle back button from screens - RULE 4: UI signals"""
	print("ScreenManager: Back button pressed, returning to previous screen")
	go_back()

# System interface for SystemRegistry
func initialize():
	"""Initialize the screen manager - called by SystemRegistry"""
	print("ScreenManager: System initialization complete")
	
	# Set the initial screen to worldview when the system starts
	call_deferred("_set_initial_screen")

func _set_initial_screen():
	"""Set up the initial WorldView screen"""
	print("ScreenManager: Setting up initial WorldView screen")
	
	# Find the WorldView in the main scene
	var main_scene = get_tree().current_scene
	if not main_scene:
		print("ScreenManager: ERROR - No main scene found")
		return
	
	var world_view = main_scene.get_node_or_null("WorldView")
	if not world_view:
		print("ScreenManager: ERROR - WorldView not found in main scene")
		return
	
	# Register the existing WorldView as current screen
	current_screen = world_view
	current_screen_name = "worldview"
	loaded_screens["worldview"] = world_view
	
	# Make sure it's visible
	world_view.visible = true
	
	print("ScreenManager: WorldView registered as initial screen")
	screen_changed.emit("worldview")
