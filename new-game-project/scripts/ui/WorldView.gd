# scripts/ui/WorldView.gd - Main world view with floating buildings like Summoners War
extends Control

@onready var summon_button = $HBoxContainer/SummonButton
@onready var collection_button = $HBoxContainer/CollectionButton
@onready var territory_button = $HBoxContainer/TerritoryButton
@onready var sacrifice_button = $HBoxContainer/SacrificeButton
@onready var dungeon_button = $HBoxContainer/DungeonButton
@onready var equipment_button = $HBoxContainer/EquipmentButton

# Screen references (will be created dynamically or loaded)
var summon_screen_scene = preload("res://scenes/SummonScreen.tscn")
var collection_screen_scene = preload("res://scenes/CollectionScreen.tscn") 
var territory_screen_scene = preload("res://scenes/TerritoryScreen.tscn")
var sacrifice_screen_scene = preload("res://scenes/SacrificeScreen.tscn")
var dungeon_screen_scene = preload("res://scenes/DungeonScreen.tscn")
var equipment_screen_scene = preload("res://scenes/EquipmentScreen.tscn")

# Feature unlock tracking (MYTHOS ARCHITECTURE)
var feature_buttons: Dictionary = {}

func _ready():
	# Connect building buttons
	if summon_button:
		summon_button.pressed.connect(_on_summon_building_pressed)
	if collection_button:
		collection_button.pressed.connect(_on_collection_building_pressed)
	if territory_button:
		territory_button.pressed.connect(_on_territory_building_pressed)
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_building_pressed)
	if dungeon_button:
		dungeon_button.pressed.connect(_on_dungeon_building_pressed)
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_building_pressed)
	
	# Setup feature tracking (MYTHOS ARCHITECTURE)
	_setup_feature_buttons()
	
	# Connect to progression system for feature unlocks
	_connect_progression_signals()
	
	# Update button visibility based on current level
	call_deferred("_update_button_visibility")
	
	# Check if we need to start the first-time tutorial (MYTHOS ARCHITECTURE)
	call_deferred("_check_tutorial_trigger")

func _setup_feature_buttons():
	"""Map feature names to their buttons (MYTHOS ARCHITECTURE)"""
	feature_buttons = {
		"territories": territory_button,      # Always available (level 1)
		"collection": collection_button,      # Always available (level 1)
		"summon": summon_button,             # Level 2
		"sacrifice": sacrifice_button,        # Level 3  
		"territory_management": territory_button,  # Level 4 (enhanced)
		"equipment": equipment_button,        # Level 8
		"dungeons": dungeon_button           # Level 10
	}

func _connect_progression_signals():
	"""Connect to progression system signals"""
	if GameManager and GameManager.progression_manager:
		if not GameManager.progression_manager.feature_unlocked.is_connected(_on_feature_unlocked):
			GameManager.progression_manager.feature_unlocked.connect(_on_feature_unlocked)

func _on_feature_unlocked(feature_name: String, _feature_data: Dictionary):
	"""Handle feature unlock"""
	print("WorldView: Feature unlocked - %s" % feature_name)
	_update_button_visibility()

func _update_button_visibility():
	"""Update button visibility based on unlocked features"""
	if not GameManager or not GameManager.progression_manager:
		return
	
	# Hide all feature buttons initially
	for feature_name in feature_buttons:
		var button = feature_buttons[feature_name]
		if button:
			var is_unlocked = GameManager.progression_manager.is_feature_unlocked(feature_name)
			button.visible = is_unlocked
			
			# Add visual feedback for locked features
			if not is_unlocked:
				button.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Dim locked buttons
			else:
				button.modulate = Color.WHITE  # Full brightness for unlocked
	
	# Territory and Collection are always available (level 1)
	if territory_button:
		territory_button.visible = true
		territory_button.modulate = Color.WHITE
	if collection_button:
		collection_button.visible = true
		collection_button.modulate = Color.WHITE

func _on_summon_building_pressed():
	print("Opening Summon Temple...")
	_open_screen(summon_screen_scene)

func _on_collection_building_pressed():
	print("Opening God Collection...")
	_open_screen(collection_screen_scene)

func _on_territory_building_pressed():
	print("Opening Territory Command...")
	_open_screen(territory_screen_scene)

func _on_sacrifice_building_pressed():
	print("Opening Power Up Altar...")
	_open_screen(sacrifice_screen_scene)

func _on_dungeon_building_pressed():
	print("Opening Dungeons Sanctum...")
	_open_screen(dungeon_screen_scene)

func _on_equipment_building_pressed():
	print("Opening Equipment Forge...")
	_open_screen(equipment_screen_scene)

func _open_screen(screen_scene: PackedScene):
	# This will transition to the specific screen
	# For now, just instantiate and add to scene tree
	if screen_scene:
		var screen_instance = screen_scene.instantiate()
		
		# Add to the scene tree root instead of current_scene
		get_tree().root.add_child(screen_instance)
		
		# Hide the world view
		visible = false
		
		# Connect back button if the screen has one
		if screen_instance.has_signal("back_pressed"):
			screen_instance.back_pressed.connect(_on_screen_back_pressed.bind(screen_instance))

func _on_screen_back_pressed(screen_instance: Node):
	# Return to world view
	visible = true
	screen_instance.queue_free()

# ==============================================================================
# TUTORIAL SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _check_tutorial_trigger():
	"""Check if we need to trigger the first-time tutorial (MYTHOS ARCHITECTURE)"""
	# Only proceed if we have GameManager and it's a first-time player
	if not GameManager or not GameManager.player_data:
		return
		
	if not GameManager.player_data.is_first_time_player:
		return  # Not a new player
		
	if not GameManager.tutorial_manager:
		print("WorldView: TutorialManager not available")
		return
	
	# Check if tutorial is already running
	if GameManager.tutorial_manager.tutorial_active:
		print("WorldView: Tutorial already active")
		return
	
	print("WorldView: UI ready, triggering first-time tutorial...")
	
	# Small delay to ensure everything is fully initialized
	await get_tree().create_timer(0.3).timeout
	
	# Start the tutorial now that the main UI is ready
	GameManager.tutorial_manager.start_tutorial("first_time_experience")
