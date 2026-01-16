# scripts/ui/WorldView.gd - Main world view with floating buildings like Summoners War
extends Control

@onready var summon_button = $ButtonGrid/SummonButton
@onready var collection_button = $ButtonGrid/CollectionButton
@onready var territory_button = $ButtonGrid/TerritoryButton
@onready var sacrifice_button = $ButtonGrid/SacrificeButton
@onready var dungeon_button = $ButtonGrid/DungeonButton
@onready var equipment_button = $ButtonGrid/EquipmentButton

# Feature unlock tracking (MYTHOS ARCHITECTURE)
var feature_buttons: Dictionary = {}

func _ready():
	# Style all buttons first
	_style_buttons()

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

	# Connect to progression system for feature unlocks (RULE 5: Use SystemRegistry)
	_connect_to_systems()

	# Update button visibility based on current level
	call_deferred("_update_button_visibility")

	# Check if we need to start the first-time tutorial (MYTHOS ARCHITECTURE)
	call_deferred("_check_tutorial_trigger")

func _style_buttons():
	"""Apply visual styling to all navigation buttons"""
	var buttons = [
		summon_button, collection_button, territory_button,
		sacrifice_button, dungeon_button, equipment_button
	]

	for button in buttons:
		if not button:
			continue

		# Create StyleBoxFlat for normal state
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.29, 0.29, 0.35)  # #4a4a5a - increased contrast
		style_normal.border_color = Color(0.4, 0.4, 0.5)  # #666680
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.corner_radius_bottom_right = 4

		# Create StyleBoxFlat for hover state
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.33, 0.33, 0.4)  # Brighter on hover
		style_hover.border_color = Color(0.5, 0.5, 0.6)  # Brighter border
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		style_hover.border_width_top = 2
		style_hover.border_width_bottom = 2
		style_hover.corner_radius_top_left = 4
		style_hover.corner_radius_top_right = 4
		style_hover.corner_radius_bottom_left = 4
		style_hover.corner_radius_bottom_right = 4

		# Create StyleBoxFlat for pressed state
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.15, 0.15, 0.2)  # Darker
		style_pressed.border_color = Color(0.4, 0.4, 0.5)
		style_pressed.border_width_left = 2
		style_pressed.border_width_right = 2
		style_pressed.border_width_top = 2
		style_pressed.border_width_bottom = 2
		style_pressed.corner_radius_top_left = 4
		style_pressed.corner_radius_top_right = 4
		style_pressed.corner_radius_bottom_left = 4
		style_pressed.corner_radius_bottom_right = 4

		# Apply styles
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)

		# Set font size for readability (16px minimum)
		button.add_theme_font_size_override("font_size", 16)

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
		push_warning("WorldView: SystemRegistry not available")
		return

	var progression_manager = system_registry.get_system("PlayerProgressionManager")
	if progression_manager and progression_manager.has_signal("feature_unlocked"):
		progression_manager.feature_unlocked.connect(_on_feature_unlocked)

func _on_feature_unlocked(_feature_name: String, _feature_data: Dictionary):
	"""Handle feature unlock"""
	_update_button_visibility()

func _update_button_visibility():
	"""Update button visibility based on unlocked features"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var progression_manager = system_registry.get_system("PlayerProgressionManager")
	if not progression_manager:
		return

	# All buttons visible for development - feature unlocking not implemented yet
	for feature_name in feature_buttons:
		var button = feature_buttons[feature_name]
		if button:
			button.visible = true
			button.modulate = Color.WHITE

	# Territory and Collection are always available (level 1)
	if territory_button:
		territory_button.visible = true
		territory_button.modulate = Color.WHITE
	if collection_button:
		collection_button.visible = true
		collection_button.modulate = Color.WHITE

func _navigate_to_screen(screen_name: String):
	"""Helper function to navigate to a screen"""
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen(screen_name)
	else:
		push_error("WorldView: ScreenManager not found")

func _on_summon_building_pressed():
	_navigate_to_screen("summon")

func _on_collection_building_pressed():
	_navigate_to_screen("collection")

func _on_territory_building_pressed():
	_navigate_to_screen("territory")

func _on_sacrifice_building_pressed():
	_navigate_to_screen("sacrifice")

func _on_dungeon_building_pressed():
	_navigate_to_screen("dungeon")

func _on_equipment_building_pressed():
	_navigate_to_screen("equipment")

# ==============================================================================
# TUTORIAL SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _check_tutorial_trigger():
	"""Check if we need to trigger the first-time tutorial (MYTHOS ARCHITECTURE)"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	# Access GameCoordinator autoload directly
	if not GameCoordinator:
		return

	# TODO: Access player data through proper system once implemented
	# For now, skip tutorial check
	pass
