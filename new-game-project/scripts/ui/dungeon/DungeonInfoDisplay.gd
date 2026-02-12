# scripts/ui/dungeon/DungeonInfoDisplay.gd
# RULE 1: Under 500 lines - Single responsibility
# RULE 2: Component for displaying detailed dungeon information
# RULE 3: Uses centralized calculations
extends Object
class_name DungeonInfoDisplay

## Component for displaying detailed dungeon information
## Handles difficulty buttons, stats, enemies, and rewards display

static func update_difficulty_buttons(
	container: Node,
	dungeon_info: Dictionary,
	selected_difficulty: String,
	on_difficulty_selected: Callable,
	dungeon_manager: Node = null
):
	"""Update difficulty selection buttons with unified styling"""
	if not container:
		return

	# Clear existing buttons
	for child in container.get_children():
		child.queue_free()

	var difficulties = dungeon_info.get("difficulty_levels", {})
	var button_group = ButtonGroup.new()
	var dungeon_id = dungeon_info.get("id", "")

	for difficulty in difficulties.keys():
		var button = Button.new()
		var difficulty_info = difficulties[difficulty]

		# Check if this difficulty has been cleared
		var is_cleared = false
		if dungeon_manager and dungeon_manager.has_method("is_first_clear"):
			is_cleared = not dungeon_manager.is_first_clear(dungeon_id, difficulty)

		# Create compact button text
		var button_text = difficulty.capitalize()
		var enemy_power = difficulty_info.get("enemy_power", 0)

		if is_cleared:
			button_text = "✓ " + button_text

		if enemy_power > 0:
			button_text += "\n⚔%s" % _format_power(enemy_power)

		button.text = button_text
		button.toggle_mode = true
		button.button_group = button_group
		button.custom_minimum_size = Vector2(100, 55)
		button.add_theme_font_size_override("font_size", 14)

		# Apply unified styling with difficulty-based accent color
		_style_difficulty_button(button, difficulty, is_cleared)

		# Set default selection
		if difficulty == selected_difficulty:
			button.button_pressed = true

		button.toggled.connect(func(pressed: bool): on_difficulty_selected.call(difficulty, pressed))
		container.add_child(button)

static func _style_difficulty_button(button: Button, difficulty: String, is_cleared: bool):
	"""Apply unified styling to difficulty button"""
	# Get difficulty-based accent color
	var accent_color: Color
	match difficulty:
		"beginner":
			accent_color = Color(0.4, 0.7, 0.4, 0.9)  # Green
		"intermediate":
			accent_color = Color(0.5, 0.6, 0.8, 0.9)  # Blue
		"advanced":
			accent_color = Color(0.7, 0.5, 0.8, 0.9)  # Purple
		"expert":
			accent_color = Color(0.9, 0.6, 0.3, 0.9)  # Orange
		"heroic":
			accent_color = Color(0.9, 0.3, 0.3, 0.9)  # Red
		"legendary":
			accent_color = Color(1.0, 0.8, 0.2, 0.9)  # Gold
		_:
			accent_color = Color(0.5, 0.5, 0.55, 0.9)

	# Desaturate if cleared
	if is_cleared:
		accent_color = accent_color.lerp(Color(0.4, 0.4, 0.45), 0.5)

	# Normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style_normal.border_color = accent_color.darkened(0.2)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	# Hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.16, 0.14, 0.22, 0.98)
	style_hover.border_color = accent_color
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)

	# Pressed/Selected state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = accent_color.darkened(0.4)
	style_pressed.border_color = accent_color.lightened(0.2)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(6)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Text colors
	var text_color = Color(0.85, 0.85, 0.9) if not is_cleared else Color(0.6, 0.6, 0.65)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color(0.95, 0.92, 0.85))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.9))

static func update_rewards_display(
	container: Node,
	dungeon_id: String,
	difficulty: String,
	dungeon_manager: Node,
	loot_system: Node
):
	"""Update the rewards display with detailed dungeon information"""
	if not container:
		return

	# Clear existing rewards
	for child in container.get_children():
		child.queue_free()

	if not dungeon_manager:
		return

	var dungeon_info = dungeon_manager.get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return

	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})

	# Create main info container
	var info_container = VBoxContainer.new()
	container.add_child(info_container)

	# Add dungeon stats section (with wave count, first-clear indicator, daily progress)
	_add_dungeon_stats(info_container, difficulty_info, dungeon_id, difficulty, dungeon_manager)

	# Add enemy information section
	_add_enemy_info(info_container, dungeon_info, dungeon_manager)

	# Add rewards section
	_add_rewards_section(info_container, dungeon_id, difficulty, dungeon_manager, loot_system)

static func _add_dungeon_stats(
	container: Node,
	difficulty_info: Dictionary,
	dungeon_id: String = "",
	difficulty: String = "",
	dungeon_manager: Node = null
):
	"""Add dungeon statistics information in an organized layout"""
	# Use a MarginContainer for proper padding instead of Panel with FULL_RECT
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container.add_child(margin)

	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 6)
	margin.add_child(stats_container)

	# Title - unified styling
	var stats_title = Label.new()
	stats_title.text = "DUNGEON DETAILS"
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))  # Warm gold
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(stats_title)

	# Check for first-clear bonus
	var is_first_clear = true
	if dungeon_manager and dungeon_manager.has_method("is_first_clear") and not dungeon_id.is_empty() and not difficulty.is_empty():
		is_first_clear = dungeon_manager.is_first_clear(dungeon_id, difficulty)

	# Show First Clear Bonus banner if not yet cleared
	if is_first_clear:
		var first_clear_label = Label.new()
		first_clear_label.text = "⭐ FIRST CLEAR BONUS ⭐"
		first_clear_label.add_theme_font_size_override("font_size", 13)
		first_clear_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		first_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(first_clear_label)

	# Stats in a more organized grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats_container.add_child(stats_grid)

	var enemy_power = difficulty_info.get("enemy_power", 0)
	var recommended_team_power = difficulty_info.get("recommended_team_power", 0)
	var boss_power = difficulty_info.get("boss_power", 0)

	# Get wave count from dungeon manager
	var wave_count = 3  # Default
	if dungeon_manager and dungeon_manager.has_method("get_battle_configuration") and not dungeon_id.is_empty() and not difficulty.is_empty():
		var battle_config = dungeon_manager.get_battle_configuration(dungeon_id, difficulty)
		wave_count = battle_config.get("wave_count", 3)

	# Get daily completion info
	var daily_count = 0
	var daily_limit = 10
	if dungeon_manager and dungeon_manager.has_method("get_daily_completion_count") and not dungeon_id.is_empty():
		daily_count = dungeon_manager.get_daily_completion_count(dungeon_id)
		daily_limit = dungeon_manager.get_daily_limit(dungeon_id)

	# Add stat pairs (energy cost removed)
	_add_stat_pair(stats_grid, "🌊 Waves:", str(wave_count))
	_add_stat_pair(stats_grid, "⚔ Enemy Power:", _format_power(enemy_power))
	_add_stat_pair(stats_grid, "📅 Today:", "%d/%d runs" % [daily_count, daily_limit])
	_add_stat_pair(stats_grid, "🛡 Recommended:", _format_power(recommended_team_power))
	if boss_power > 0:
		_add_stat_pair(stats_grid, "👑 Boss Power:", _format_power(boss_power))

static func _add_stat_pair(grid: GridContainer, label_text: String, value_text: String):
	"""Add a label-value pair to the grid with unified styling"""
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))  # Muted
	grid.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))  # Soft cyan
	grid.add_child(value)

static func _add_enemy_info(container: Node, dungeon_info: Dictionary, dungeon_manager: Node):
	"""Add enemy type information in compact format"""
	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	container.add_child(separator)

	# Use margin container instead of panel with FULL_RECT
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	container.add_child(margin)

	var enemy_container = VBoxContainer.new()
	enemy_container.add_theme_constant_override("separation", 4)
	margin.add_child(enemy_container)

	var enemies_title = Label.new()
	enemies_title.text = "ENEMIES"
	enemies_title.add_theme_font_size_override("font_size", 14)
	enemies_title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))  # Soft red
	enemies_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_container.add_child(enemies_title)

	if dungeon_manager:
		var enemy_types = dungeon_manager.get_enemy_types_for_dungeon(dungeon_info.get("id", ""))
		if not enemy_types.is_empty():
			var enemies_text = ""
			for i in range(enemy_types.size()):
				if i > 0:
					enemies_text += " • "
				enemies_text += enemy_types[i]

			var enemies_info = Label.new()
			enemies_info.text = enemies_text
			enemies_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enemies_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			enemies_info.add_theme_font_size_override("font_size", 12)
			enemies_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			enemy_container.add_child(enemies_info)
		else:
			var fallback_label = Label.new()
			fallback_label.text = "Various elemental enemies"
			fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback_label.add_theme_font_size_override("font_size", 12)
			fallback_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			enemy_container.add_child(fallback_label)

static func _add_rewards_section(
	container: Node,
	dungeon_id: String,
	difficulty: String,
	dungeon_manager: Node,
	loot_system: Node
):
	"""Add rewards preview section with better organization"""
	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	container.add_child(separator)

	# Use margin container instead of panel with FULL_RECT
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	container.add_child(margin)

	var rewards_content = VBoxContainer.new()
	rewards_content.add_theme_constant_override("separation", 4)
	margin.add_child(rewards_content)

	var rewards_title = Label.new()
	rewards_title.text = "REWARDS"
	rewards_title.add_theme_font_size_override("font_size", 14)
	rewards_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))  # Soft blue
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_content.add_child(rewards_title)

	# Try to get loot preview if LootSystem is available
	if loot_system and dungeon_manager:
		var loot_table_name = dungeon_manager.get_loot_table_name(dungeon_id, difficulty)
		if not loot_table_name.is_empty():
			var loot_preview = loot_system.get_loot_preview(loot_table_name)

			if not loot_preview.is_empty():
				_display_loot_preview_compact(rewards_content, loot_preview)
			else:
				_show_fallback_rewards_compact(rewards_content, difficulty)
		else:
			_show_fallback_rewards_compact(rewards_content, difficulty)
	else:
		_show_fallback_rewards_compact(rewards_content, difficulty)

static func _display_loot_preview_compact(container: Node, loot_preview: Array):
	"""Display loot preview in a more compact, organized way"""
	if loot_preview.is_empty():
		var no_loot_label = Label.new()
		no_loot_label.text = "No loot information available"
		no_loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(no_loot_label)
		return

	# Group items by type
	var guaranteed_items = []
	var rare_items = []

	for item in loot_preview:
		var chance = item.get("chance", 0.0)
		if chance >= 100.0:
			guaranteed_items.append(item)
		else:
			rare_items.append(item)

	# Create a scrollable area for rewards if there are many
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 120)
	container.add_child(scroll_container)

	var content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_container)

	# Display guaranteed drops
	if not guaranteed_items.is_empty():
		var guaranteed_header = Label.new()
		guaranteed_header.text = "Guaranteed:"
		guaranteed_header.add_theme_font_size_override("font_size", 13)
		guaranteed_header.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))  # Soft green
		content_container.add_child(guaranteed_header)

		for item in guaranteed_items.slice(0, 3):
			var item_label = Label.new()
			var item_id = item.get("item_id", "Unknown")
			var min_amount = item.get("min_amount", 1)
			var max_amount = item.get("max_amount", 1)

			var amount_text = ""
			if min_amount == max_amount:
				amount_text = " x%d" % min_amount
			else:
				amount_text = " x%d-%d" % [min_amount, max_amount]

			item_label.text = "  • %s%s" % [_format_item_name(item_id), amount_text]
			item_label.add_theme_font_size_override("font_size", 12)
			item_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			content_container.add_child(item_label)

	# Display rare drops (limited)
	if not rare_items.is_empty():
		var rare_header = Label.new()
		rare_header.text = "Rare Drops:"
		rare_header.add_theme_font_size_override("font_size", 13)
		rare_header.add_theme_color_override("font_color", Color(0.7, 0.5, 0.8))  # Soft purple
		content_container.add_child(rare_header)

		for item in rare_items.slice(0, 2):
			var item_label = Label.new()
			var item_id = item.get("item_id", "Unknown")
			var chance = item.get("chance", 0.0)

			item_label.text = "  • %s (%.1f%%)" % [_format_item_name(item_id), chance]
			item_label.add_theme_font_size_override("font_size", 12)
			item_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			content_container.add_child(item_label)

static func _show_fallback_rewards_compact(container: Node, difficulty: String):
	"""Show fallback rewards information in compact format"""
	var fallback_text = "• Experience & Mana\n"
	fallback_text += "• Elemental Materials\n"

	# Add difficulty-specific rewards
	match difficulty:
		"beginner":
			fallback_text += "• Basic Equipment"
		"intermediate":
			fallback_text += "• Rare Equipment"
		"advanced":
			fallback_text += "• Epic Equipment"
		"expert":
			fallback_text += "• Legendary Equipment"

	var fallback_label = Label.new()
	fallback_label.text = fallback_text
	fallback_label.add_theme_font_size_override("font_size", 12)
	fallback_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(fallback_label)

static func _format_item_name(item_id: String) -> String:
	"""Format item ID into a readable name"""
	return item_id.replace("_", " ").capitalize()

static func _format_power(power: int) -> String:
	"""Format power number for display"""
	if power >= 1000000:
		return "%.1fM" % (power / 1000000.0)
	elif power >= 1000:
		return "%.1fK" % (power / 1000.0)
	else:
		return str(power)
