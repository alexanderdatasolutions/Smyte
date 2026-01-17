# scripts/ui/WorldView.gd - Main hub screen
extends Control

# Helper to get SystemRegistry without parse-time dependency
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

@onready var summon_button = $ContentContainer/ButtonGrid/SummonButton
@onready var collection_button = $ContentContainer/ButtonGrid/CollectionButton
@onready var territory_button = $ContentContainer/ButtonGrid/TerritoryButton
@onready var sacrifice_button = $ContentContainer/ButtonGrid/SacrificeButton
@onready var dungeon_button = $ContentContainer/ButtonGrid/DungeonButton
@onready var equipment_button = $ContentContainer/ButtonGrid/EquipmentButton
@onready var shop_button = $ContentContainer/ButtonGrid/ShopButton
@onready var specialization_button = $ContentContainer/ButtonGrid/SpecializationButton

# Feature unlock tracking (MYTHOS ARCHITECTURE)
var feature_buttons: Dictionary = {}

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _ready():
	# Ensure this control fills the viewport (needed when parent is Node2D)
	_setup_fullscreen()

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
	if shop_button:
		shop_button.pressed.connect(_on_shop_building_pressed)
	if specialization_button:
		specialization_button.pressed.connect(_on_specialization_building_pressed)

	# Setup feature tracking (MYTHOS ARCHITECTURE)
	_setup_feature_buttons()

	# Connect to progression system for feature unlocks (RULE 5: Use SystemRegistry)
	_connect_to_systems()

	# Update button visibility based on current level
	call_deferred("_update_button_visibility")

	# Check if we need to start the first-time tutorial (MYTHOS ARCHITECTURE)
	call_deferred("_check_tutorial_trigger")

func _style_buttons():
	"""Apply dark fantasy styling to navigation buttons"""
	var buttons_data = [
		{"button": summon_button, "color": Color(0.6, 0.5, 0.2)},      # Gold - premium feel
		{"button": collection_button, "color": Color(0.4, 0.5, 0.6)},  # Steel blue
		{"button": territory_button, "color": Color(0.5, 0.35, 0.2)},  # Bronze/copper
		{"button": sacrifice_button, "color": Color(0.5, 0.2, 0.25)},  # Dark red
		{"button": dungeon_button, "color": Color(0.3, 0.4, 0.35)},    # Forest green
		{"button": equipment_button, "color": Color(0.45, 0.4, 0.5)},  # Purple/steel
		{"button": shop_button, "color": Color(0.3, 0.6, 0.7)},        # Crystal blue - shop
		{"button": specialization_button, "color": Color(0.5, 0.3, 0.6)}  # Purple - specialization
	]

	for data in buttons_data:
		var button = data["button"]
		var accent = data["color"]
		if not button:
			continue

		# Normal state - dark with colored accent border
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.95)
		style_normal.border_color = accent * 0.7
		style_normal.set_border_width_all(2)
		style_normal.set_corner_radius_all(8)
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
		style_normal.shadow_size = 4
		style_normal.shadow_offset = Vector2(2, 2)

		# Hover state - brighter, glow effect
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
		style_hover.border_color = accent
		style_hover.set_border_width_all(2)
		style_hover.set_corner_radius_all(8)
		style_hover.shadow_color = accent * 0.5
		style_hover.shadow_size = 8
		style_hover.shadow_offset = Vector2(0, 0)

		# Pressed state - inset look
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.08, 0.06, 0.1, 1.0)
		style_pressed.border_color = accent * 0.5
		style_pressed.set_border_width_all(2)
		style_pressed.set_corner_radius_all(8)

		# Focus state (keyboard nav)
		var style_focus = StyleBoxFlat.new()
		style_focus.bg_color = Color(0.15, 0.12, 0.18, 0.98)
		style_focus.border_color = Color(0.9, 0.8, 0.5)
		style_focus.set_border_width_all(3)
		style_focus.set_corner_radius_all(8)

		# Apply styles
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_stylebox_override("focus", style_focus)

		# Typography
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
		button.add_theme_color_override("font_pressed_color", Color(0.6, 0.55, 0.5))

func _setup_feature_buttons():
	"""Map feature names to their buttons (MYTHOS ARCHITECTURE)"""
	feature_buttons = {
		"territories": territory_button,      # Always available (level 1)
		"collection": collection_button,      # Always available (level 1)
		"summon": summon_button,             # Level 2
		"sacrifice": sacrifice_button,        # Level 3
		"territory_management": territory_button,  # Level 4 (enhanced)
		"equipment": equipment_button,        # Level 8
		"dungeons": dungeon_button,          # Level 10
		"shop": shop_button,                 # Always available
		"specialization": specialization_button  # Level 20 (god level)
	}

func _connect_to_systems():
	"""Connect to game systems through SystemRegistry - following RULE 5"""
	var system_registry = _get_system_registry()
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
	var system_registry = _get_system_registry()
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
	var screen_manager = _get_system_registry().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen(screen_name)
	else:
		push_error("WorldView: ScreenManager not found")

func _on_summon_building_pressed():
	_navigate_to_screen("summon")

func _on_collection_building_pressed():
	_navigate_to_screen("collection")

func _on_territory_building_pressed():
	_navigate_to_screen("hex_territory")

func _on_sacrifice_building_pressed():
	_navigate_to_screen("sacrifice")

func _on_dungeon_building_pressed():
	_navigate_to_screen("dungeon")

func _on_equipment_building_pressed():
	_navigate_to_screen("equipment")

func _on_shop_building_pressed():
	_navigate_to_screen("shop")

func _on_specialization_building_pressed():
	_navigate_to_screen("specialization")

# ==============================================================================
# TUTORIAL SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _check_tutorial_trigger():
	"""Check if we need to trigger the first-time tutorial (MYTHOS ARCHITECTURE)"""
	var system_registry = _get_system_registry()
	if not system_registry:
		return

	# Access GameCoordinator autoload directly
	if not GameCoordinator:
		return

	# TODO: Access player data through proper system once implemented
	# For now, skip tutorial check
	pass
