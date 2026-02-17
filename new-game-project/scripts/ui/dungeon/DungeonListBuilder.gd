# scripts/ui/dungeon/DungeonListBuilder.gd
# RULE 1: Under 500 lines - Single responsibility
# RULE 2: Static factory for creating dungeon list UI
# RULE 3: Uses centralized calculations
extends Object
class_name DungeonListBuilder

## Static factory for creating dungeon list buttons
## Handles button creation, styling, and layout for dungeon selection UI

static func populate_category_list(container: Node, dungeons: Array, on_dungeon_selected: Callable):
	"""Populate a category list with dungeon buttons using grid layout"""
	if not container:
		return

	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# Create a margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(margin)

	# Create a grid container - 3 columns for more dungeons visible
	var grid_container = GridContainer.new()
	grid_container.columns = 3
	grid_container.add_theme_constant_override("h_separation", 12)
	grid_container.add_theme_constant_override("v_separation", 12)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(grid_container)

	# Add dungeon buttons to grid
	for dungeon_info in dungeons:
		create_dungeon_button(dungeon_info, grid_container, on_dungeon_selected)

static func create_dungeon_button(dungeon_info: Dictionary, container: Node, on_dungeon_selected: Callable):
	"""Create a button for a dungeon in the specified container with better formatting"""
	var button = Button.new()
	var dungeon_id = dungeon_info.get("id", "")
	var dungeon_name = dungeon_info.get("name", "Unknown Dungeon")

	# Get power information for first available difficulty (not just beginner)
	var difficulty_levels = dungeon_info.get("difficulty_levels", {})
	var first_difficulty = _get_first_difficulty(difficulty_levels)
	var enemy_power = first_difficulty.get("enemy_power", 0)
	var recommended_level = first_difficulty.get("recommended_level", 1)

	# Create button text with power info (energy cost removed)
	var button_text = dungeon_name + "\n"
	button_text += "⚔%s  Lv.%d+" % [
		_format_power(enemy_power),
		recommended_level
	]

	# Set button properties for grid layout - cards that fill available space
	button.text = button_text
	button.custom_minimum_size = Vector2(180, 75)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(func(): on_dungeon_selected.call(dungeon_id))

	# Add styling based on element/category
	_style_dungeon_button(button, dungeon_info)

	container.add_child(button)

static func _get_first_difficulty(difficulty_levels: Dictionary) -> Dictionary:
	"""Get the first (easiest) difficulty info - handles different naming conventions"""
	# Priority order: beginner, heroic (for pantheon), intermediate, etc.
	var priority_order = ["beginner", "heroic", "intermediate", "advanced", "expert", "legendary"]
	for diff_name in priority_order:
		if difficulty_levels.has(diff_name):
			return difficulty_levels[diff_name]
	# Fallback: return first available
	if not difficulty_levels.is_empty():
		return difficulty_levels[difficulty_levels.keys()[0]]
	return {}

static func _style_dungeon_button(button: Button, dungeon_info: Dictionary):
	"""Apply unified styling to dungeon button with element-based accent colors"""
	var element = dungeon_info.get("element", "neutral")

	# Get element-based accent color
	var accent_color: Color
	match element:
		"fire":
			accent_color = Color(0.9, 0.4, 0.2, 0.9)
		"water":
			accent_color = Color(0.3, 0.6, 0.9, 0.9)
		"earth":
			accent_color = Color(0.6, 0.45, 0.3, 0.9)
		"lightning":
			accent_color = Color(0.9, 0.8, 0.3, 0.9)
		"light":
			accent_color = Color(0.9, 0.9, 0.8, 0.9)
		"dark":
			accent_color = Color(0.6, 0.3, 0.7, 0.9)
		"neutral", _:
			accent_color = Color(0.5, 0.5, 0.55, 0.9)

	# Create styled normal state - unified dark panel with element border
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style_normal.border_color = accent_color.darkened(0.3)
	style_normal.set_border_width_all(2)
	style_normal.border_width_left = 4  # Thicker left border as element indicator
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	# Hover state - brighten
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.16, 0.14, 0.22, 0.98)
	style_hover.border_color = accent_color
	style_hover.set_border_width_all(2)
	style_hover.border_width_left = 4
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)

	# Pressed state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.2, 0.18, 0.28, 1.0)
	style_pressed.border_color = accent_color.lightened(0.2)
	style_pressed.set_border_width_all(2)
	style_pressed.border_width_left = 4
	style_pressed.set_corner_radius_all(6)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Focus state (for keyboard/controller)
	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(0.14, 0.12, 0.2, 0.98)
	style_focus.border_color = accent_color.lightened(0.1)
	style_focus.set_border_width_all(2)
	style_focus.border_width_left = 4
	style_focus.set_corner_radius_all(6)
	button.add_theme_stylebox_override("focus", style_focus)

	# Text colors
	button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	button.add_theme_color_override("font_hover_color", Color(0.95, 0.92, 0.85))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.9))

static func _format_power(power: int) -> String:
	"""Format power number for display"""
	if power >= 1000000:
		return "%.1fM" % (power / 1000000.0)
	elif power >= 1000:
		return "%.1fK" % (power / 1000.0)
	else:
		return str(power)

static func clear_dungeon_lists(lists: Array):
	"""Clear all dungeon category lists"""
	for dungeon_list in lists:
		if dungeon_list:
			for child in dungeon_list.get_children():
				child.queue_free()

static func show_placeholder_dungeons(elemental_list: Node):
	"""Show placeholder while systems load"""
	if elemental_list:
		var test_button = Button.new()
		test_button.text = "Test Elemental Dungeon"
		test_button.custom_minimum_size = Vector2(200, 50)
		elemental_list.add_child(test_button)
