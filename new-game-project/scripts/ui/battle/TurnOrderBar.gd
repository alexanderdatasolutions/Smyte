# scripts/ui/battle/TurnOrderBar.gd
# Displays the turn order for upcoming turns in battle
# RULE 2: Single responsibility - ONLY displays turn order
# RULE 4: No logic in UI - just displays state from TurnManager
class_name TurnOrderBar extends PanelContainer

const MAX_PORTRAIT_COUNT := 10  # Maximum portraits to show
const PORTRAIT_SIZE := Vector2(40, 40)  # Size of each portrait
const PORTRAIT_SPACING := 4  # Space between portraits

# UI Elements
var title_label: Label
var portrait_container: HBoxContainer
var portrait_nodes: Array = []  # Array of portrait Controls

# Current turn order data
var current_turn_order: Array = []  # Array[BattleUnit]
var current_unit: BattleUnit = null

func _ready():
	_setup_ui_structure()
	_apply_panel_style()

func _setup_ui_structure():
	"""Create the turn order bar UI structure"""
	# Set minimum size
	custom_minimum_size = Vector2(500, 60)

	# Main vertical container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# Title label
	title_label = Label.new()
	title_label.text = "TURN ORDER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	vbox.add_child(title_label)

	# Portrait container (horizontal)
	var hbox_center = CenterContainer.new()
	vbox.add_child(hbox_center)

	portrait_container = HBoxContainer.new()
	portrait_container.add_theme_constant_override("separation", PORTRAIT_SPACING)
	portrait_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_center.add_child(portrait_container)

func _apply_panel_style():
	"""Apply visual style to the panel"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

func update_turn_order(turn_order: Array, active_unit: BattleUnit = null):
	"""Update the displayed turn order - RULE 4: Just display, no logic"""
	current_turn_order = turn_order
	current_unit = active_unit
	_refresh_portraits()

func clear():
	"""Clear the turn order display"""
	current_turn_order.clear()
	current_unit = null
	_clear_portraits()

func _refresh_portraits():
	"""Refresh the portrait display based on current turn order"""
	_clear_portraits()

	if current_turn_order.is_empty():
		return

	# Create portraits for each unit in turn order (up to max)
	var count = min(current_turn_order.size(), MAX_PORTRAIT_COUNT)
	for i in range(count):
		var unit = current_turn_order[i]
		var portrait = _create_portrait(unit, i == 0)
		portrait_container.add_child(portrait)
		portrait_nodes.append(portrait)

func _clear_portraits():
	"""Remove all portrait nodes"""
	for portrait in portrait_nodes:
		if is_instance_valid(portrait):
			portrait.queue_free()
	portrait_nodes.clear()

func _create_portrait(unit: BattleUnit, is_current: bool) -> Control:
	"""Create a single portrait node for a unit"""
	# Container for portrait and border
	var container = PanelContainer.new()
	container.custom_minimum_size = PORTRAIT_SIZE

	# Apply border style based on current/normal state
	var style = StyleBoxFlat.new()
	if is_current:
		style.bg_color = Color(0.25, 0.3, 0.2, 1.0)
		style.border_color = Color(1.0, 0.9, 0.2, 1.0)  # Gold for current
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		if unit.is_player_unit:
			style.border_color = Color(0.3, 0.5, 0.8, 1.0)  # Blue for player
		else:
			style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red for enemy
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1

	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	container.add_theme_stylebox_override("panel", style)

	# Portrait texture
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = PORTRAIT_SIZE - Vector2(4, 4)  # Account for border
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_portrait_texture(portrait_rect, unit)
	container.add_child(portrait_rect)

	# Dead overlay
	if not unit.is_alive:
		var dead_overlay = ColorRect.new()
		dead_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
		dead_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dead_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(dead_overlay)

		# X mark for dead
		var dead_label = Label.new()
		dead_label.text = "X"
		dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dead_label.add_theme_font_size_override("font_size", 18)
		dead_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 1.0))
		dead_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(dead_label)

	# Add glow effect for current turn
	if is_current:
		_add_current_turn_indicator(container)

	# Tooltip with unit name
	container.tooltip_text = unit.display_name
	if is_current:
		container.tooltip_text += " (Current Turn)"

	return container

func _load_portrait_texture(rect: TextureRect, unit: BattleUnit):
	"""Load the appropriate texture for a unit"""
	var texture_loaded = false

	# Try source_god
	if unit.source_god:
		var sprite_path = "res://assets/gods/" + unit.source_god.id + ".png"
		if ResourceLoader.exists(sprite_path):
			rect.texture = load(sprite_path)
			texture_loaded = true

	# Try source_enemy
	if not texture_loaded and not unit.source_enemy.is_empty():
		var enemy_sprite = unit.source_enemy.get("sprite", "")
		if enemy_sprite != "" and ResourceLoader.exists(enemy_sprite):
			rect.texture = load(enemy_sprite)
			texture_loaded = true

	# Create placeholder
	if not texture_loaded:
		rect.texture = _create_placeholder_texture(unit)

func _create_placeholder_texture(unit: BattleUnit) -> ImageTexture:
	"""Create a placeholder texture"""
	var placeholder = ImageTexture.new()
	var image = Image.create(32, 32, false, Image.FORMAT_RGB8)

	# Color based on unit type
	var color: Color
	if unit.is_player_unit:
		color = Color(0.3, 0.5, 0.8, 1.0)  # Blue for player
	else:
		color = Color(0.8, 0.3, 0.3, 1.0)  # Red for enemy

	# Try element color
	if unit.source_god:
		color = _get_element_color(unit.source_god.element)

	image.fill(color)
	placeholder.set_image(image)
	return placeholder

func _get_element_color(element: God.ElementType) -> Color:
	"""Get color for element type"""
	match element:
		God.ElementType.FIRE: return Color(1.0, 0.4, 0.2, 1.0)
		God.ElementType.WATER: return Color(0.2, 0.6, 1.0, 1.0)
		God.ElementType.EARTH: return Color(0.6, 0.8, 0.2, 1.0)
		God.ElementType.LIGHTNING: return Color(1.0, 1.0, 0.2, 1.0)
		God.ElementType.LIGHT: return Color(1.0, 1.0, 0.8, 1.0)
		God.ElementType.DARK: return Color(0.4, 0.2, 0.6, 1.0)
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _add_current_turn_indicator(container: Control):
	"""Add visual indicator for current turn unit"""
	# Arrow indicator below portrait
	var arrow = Label.new()
	arrow.text = "^"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 14)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	arrow.position = Vector2(PORTRAIT_SIZE.x / 2 - 5, -12)
	container.add_child(arrow)
