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

	# Create a grid container instead of vertical list
	var grid_container = GridContainer.new()
	grid_container.columns = 2  # Two columns for better space usage
	grid_container.add_theme_constant_override("h_separation", 10)
	grid_container.add_theme_constant_override("v_separation", 10)
	container.add_child(grid_container)

	# Add dungeon buttons to grid
	for dungeon_info in dungeons:
		create_dungeon_button(dungeon_info, grid_container, on_dungeon_selected)

static func create_dungeon_button(dungeon_info: Dictionary, container: Node, on_dungeon_selected: Callable):
	"""Create a button for a dungeon in the specified container with better formatting"""
	var button = Button.new()
	var dungeon_id = dungeon_info.get("id", "")
	var dungeon_name = dungeon_info.get("name", "Unknown Dungeon")

	# Get power information for beginner difficulty
	var difficulty_levels = dungeon_info.get("difficulty_levels", {})
	var beginner_difficulty = difficulty_levels.get("beginner", {})
	var energy_cost = beginner_difficulty.get("energy_cost", 0)
	var enemy_power = beginner_difficulty.get("enemy_power", 0)
	var recommended_level = beginner_difficulty.get("recommended_level", 1)

	# Create more compact button text
	var button_text = dungeon_name + "\n"
	button_text += "⚡%d • ⚔%s • Lv.%d+" % [
		energy_cost,
		_format_power(enemy_power),
		recommended_level
	]

	# Set button properties for grid layout
	button.text = button_text
	button.custom_minimum_size = Vector2(200, 70)  # Smaller, more compact
	button.add_theme_font_size_override("font_size", 14)  # Add mobile-friendly font size
	button.pressed.connect(func(): on_dungeon_selected.call(dungeon_id))

	# Add styling based on element/category
	_style_dungeon_button(button, dungeon_info)

	container.add_child(button)

static func _style_dungeon_button(button: Button, dungeon_info: Dictionary):
	"""Apply styling to dungeon button based on properties - Enhanced with element colors"""
	var element = dungeon_info.get("element", "neutral")

	# Apply element-based color styling
	var element_color: Color
	match element:
		"fire":
			element_color = Color.ORANGE_RED
		"water":
			element_color = Color.CYAN
		"earth":
			element_color = Color.SADDLE_BROWN
		"lightning":
			element_color = Color.YELLOW
		"light":
			element_color = Color.WHITE
		"dark":
			element_color = Color.PURPLE
		"neutral":
			element_color = Color.LIGHT_GRAY
		_:
			element_color = Color.WHITE

	# Apply the color and store it for hover restoration
	button.modulate = element_color
	button.set_meta("original_color", element_color)

	# Add hover effects
	button.mouse_entered.connect(func(): _on_dungeon_button_hovered(button, true))
	button.mouse_exited.connect(func(): _on_dungeon_button_hovered(button, false))

static func _on_dungeon_button_hovered(button: Button, is_hovered: bool):
	"""Handle dungeon button hover effects"""
	if is_hovered:
		button.modulate = button.modulate.lightened(0.2)
	else:
		# Restore original color
		var original_color = button.get_meta("original_color", Color.WHITE)
		button.modulate = original_color

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
