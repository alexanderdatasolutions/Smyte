# scripts/ui/WorldView.gd - Main world view with floating buildings like Summoners War
extends Control

@onready var summon_button = $HBoxContainer/SummonButton
@onready var collection_button = $HBoxContainer/CollectionButton
@onready var territory_button = $HBoxContainer/TerritoryButton
@onready var sacrifice_button = $HBoxContainer/SacrificeButton
@onready var dungeon_button = $HBoxContainer/DungeonButton
@onready var equipment_button = $HBoxContainer/EquipmentButton

# Feature unlock tracking (MYTHOS ARCHITECTURE)
var feature_buttons: Dictionary = {}

func _ready():
	print("=== DEBUG: WorldView._ready() called ===")
	# Connect building buttons
	if summon_button:
		summon_button.pressed.connect(_on_summon_building_pressed)
		print("=== DEBUG: Connected summon_button ===")
	else:
		print("=== DEBUG: summon_button is null! ===")
		
	if collection_button:
		collection_button.pressed.connect(_on_collection_building_pressed)
		print("=== DEBUG: Connected collection_button ===")
	else:
		print("=== DEBUG: collection_button is null! ===")
		
	if territory_button:
		territory_button.pressed.connect(_on_territory_building_pressed)
		print("=== DEBUG: Connected territory_button ===")
	else:
		print("=== DEBUG: territory_button is null! ===")
		
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_building_pressed)
		print("=== DEBUG: Connected sacrifice_button ===")
	else:
		print("=== DEBUG: sacrifice_button is null! ===")
		
	if dungeon_button:
		dungeon_button.pressed.connect(_on_dungeon_building_pressed)
		print("=== DEBUG: Connected dungeon_button ===")
	else:
		print("=== DEBUG: dungeon_button is null! ===")
		
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_building_pressed)
		print("=== DEBUG: Connected equipment_button ===")
	else:
		print("=== DEBUG: equipment_button is null! ===")
	
	# Setup feature tracking (MYTHOS ARCHITECTURE)
	_setup_feature_buttons()
	
	# Connect to progression system for feature unlocks (RULE 5: Use SystemRegistry)
	_connect_to_systems()
	
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

func _connect_to_systems():
	"""Connect to game systems through SystemRegistry - following RULE 5"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("WorldView: SystemRegistry not available")
		return
	
	var progression_manager = system_registry.get_system("PlayerProgressionManager")
	if progression_manager and progression_manager.has_signal("feature_unlocked"):
		progression_manager.feature_unlocked.connect(_on_feature_unlocked)
		print("WorldView: Connected to PlayerProgressionManager.feature_unlocked")
	else:
		print("WorldView: PlayerProgressionManager not found or missing signal")

func _on_feature_unlocked(feature_name: String, _feature_data: Dictionary):
	"""Handle feature unlock"""
	print("WorldView: Feature unlocked - %s" % feature_name)
	_update_button_visibility()

func _update_button_visibility():
	"""Update button visibility based on unlocked features"""
	print("=== DEBUG: _update_button_visibility called ===")
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("=== DEBUG: No SystemRegistry found ===")
		return
		
	var progression_manager = system_registry.get_system("PlayerProgressionManager")
	if not progression_manager:
		print("=== DEBUG: No PlayerProgressionManager found ===")
		return
	
	# FOR DEVELOPMENT: Show all buttons to test functionality
	# TODO: Restore proper feature unlocking after core systems are working
	print("=== DEBUG: Making all buttons visible for development testing ===")
	for feature_name in feature_buttons:
		var button = feature_buttons[feature_name]
		if button:
			button.visible = true
			button.modulate = Color.WHITE
			print("=== DEBUG: Made button visible: %s ===" % feature_name)
	
	# Territory and Collection are always available (level 1)
	if territory_button:
		territory_button.visible = true
		territory_button.modulate = Color.WHITE
		print("=== DEBUG: Territory button visible ===")
	if collection_button:
		collection_button.visible = true
		collection_button.modulate = Color.WHITE
		print("=== DEBUG: Collection button visible ===")

func _on_summon_building_pressed():
	print("=== DEBUG: Summon button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("summon")
	else:
		print("ERROR: ScreenManager not found")

func _on_collection_building_pressed():
	print("=== DEBUG: Collection button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("collection")
	else:
		print("ERROR: ScreenManager not found")

func _on_territory_building_pressed():
	print("=== DEBUG: Territory button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("territory")
	else:
		print("ERROR: ScreenManager not found")

func _on_sacrifice_building_pressed():
	print("=== DEBUG: Sacrifice button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("sacrifice")
	else:
		print("ERROR: ScreenManager not found")

func _on_dungeon_building_pressed():
	print("=== DEBUG: Dungeon button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("dungeon")
	else:
		print("ERROR: ScreenManager not found")

func _on_equipment_building_pressed():
	print("=== DEBUG: Equipment button pressed! ===")
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen("equipment")
	else:
		print("ERROR: ScreenManager not found")

# ==============================================================================
# TUTORIAL SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _check_tutorial_trigger():
	"""Check if we need to trigger the first-time tutorial (MYTHOS ARCHITECTURE)"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("WorldView: SystemRegistry not available")
		return
	
	# Access GameCoordinator autoload directly
	if not GameCoordinator:
		print("WorldView: GameCoordinator not available")
		return
	
	# TODO: Access player data through proper system once implemented
	# For now, skip tutorial check
	print("WorldView: Tutorial system temporarily disabled - needs PlayerData access pattern")
	# Removed unreachable code after return
