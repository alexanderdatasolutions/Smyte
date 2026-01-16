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
	on_difficulty_selected: Callable
):
	"""Update difficulty selection buttons with organized layout"""
	if not container:
		return

	# Clear existing buttons
	for child in container.get_children():
		child.queue_free()

	var difficulties = dungeon_info.get("difficulty_levels", {})
	var button_group = ButtonGroup.new()

	# Create a more compact layout
	for difficulty in difficulties.keys():
		var button = Button.new()
		var difficulty_info = difficulties[difficulty]

		# Create more compact button text
		var button_text = difficulty.capitalize()
		var enemy_power = difficulty_info.get("enemy_power", 0)
		var energy_cost = difficulty_info.get("energy_cost", 0)

		if enemy_power > 0:
			button_text += "\n⚔%s • ⚡%d" % [_format_power(enemy_power), energy_cost]

		button.text = button_text
		button.toggle_mode = true
		button.button_group = button_group
		button.custom_minimum_size = Vector2(100, 55)  # More compact
		button.add_theme_font_size_override("font_size", 14)  # Add mobile-friendly font size

		# Apply difficulty color
		var difficulty_color = difficulty_info.get("difficulty_color", Color.WHITE)
		button.modulate = difficulty_color.lerp(Color.WHITE, 0.7)  # Lighter tint

		# Set default selection
		if difficulty == selected_difficulty:
			button.button_pressed = true

		# Connect to callback
		button.toggled.connect(func(pressed: bool): on_difficulty_selected.call(difficulty, pressed))
		container.add_child(button)

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

	# Add dungeon stats section
	_add_dungeon_stats(info_container, difficulty_info)

	# Add enemy information section
	_add_enemy_info(info_container, dungeon_info, dungeon_manager)

	# Add rewards section
	_add_rewards_section(info_container, dungeon_id, difficulty, dungeon_manager, loot_system)

static func _add_dungeon_stats(container: Node, difficulty_info: Dictionary):
	"""Add dungeon statistics information in a organized card layout"""
	# Create a styled panel for stats
	var stats_panel = Panel.new()
	stats_panel.custom_minimum_size = Vector2(0, 120)
	container.add_child(stats_panel)

	var stats_container = VBoxContainer.new()
	stats_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_container.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_container)

	# Title
	var stats_title = Label.new()
	stats_title.text = "📊 DUNGEON DETAILS"
	stats_title.add_theme_font_size_override("font_size", 20)
	stats_title.add_theme_color_override("font_color", Color.GOLD)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(stats_title)

	# Stats in a more organized grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 3)
	stats_container.add_child(stats_grid)

	var energy_cost = difficulty_info.get("energy_cost", 0)
	var enemy_power = difficulty_info.get("enemy_power", 0)
	var recommended_team_power = difficulty_info.get("recommended_team_power", 0)
	var boss_power = difficulty_info.get("boss_power", 0)

	# Add stat pairs
	_add_stat_pair(stats_grid, "⚡ Energy:", str(energy_cost))
	_add_stat_pair(stats_grid, "⚔ Enemy Power:", _format_power(enemy_power))
	_add_stat_pair(stats_grid, "🛡 Recommended:", _format_power(recommended_team_power))
	_add_stat_pair(stats_grid, "👑 Boss Power:", _format_power(boss_power))

static func _add_stat_pair(grid: GridContainer, label_text: String, value_text: String):
	"""Add a label-value pair to the grid"""
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	grid.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color.CYAN)
	grid.add_child(value)

static func _add_enemy_info(container: Node, dungeon_info: Dictionary, dungeon_manager: Node):
	"""Add enemy type information in compact format"""
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)

	# Create enemy info panel
	var enemy_panel = Panel.new()
	enemy_panel.custom_minimum_size = Vector2(0, 80)
	container.add_child(enemy_panel)

	var enemy_container = VBoxContainer.new()
	enemy_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_container.add_theme_constant_override("separation", 5)
	enemy_panel.add_child(enemy_container)

	var enemies_title = Label.new()
	enemies_title.text = "👹 ENEMY TYPES"
	enemies_title.add_theme_font_size_override("font_size", 20)
	enemies_title.add_theme_color_override("font_color", Color.ORANGE_RED)
	enemies_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_container.add_child(enemies_title)

	if dungeon_manager:
		var enemy_types = dungeon_manager.get_enemy_types_for_dungeon(dungeon_info.get("id", ""))
		if not enemy_types.is_empty():
			# Display enemies in a horizontal flow
			var enemies_text = ""
			for i in range(enemy_types.size()):
				if i > 0:
					enemies_text += " • "
				enemies_text += enemy_types[i]

			var enemies_info = Label.new()
			enemies_info.text = enemies_text
			enemies_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enemies_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			enemies_info.add_theme_font_size_override("font_size", 14)
			enemy_container.add_child(enemies_info)
		else:
			var fallback_label = Label.new()
			fallback_label.text = "Various elemental enemies"
			fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback_label.add_theme_font_size_override("font_size", 14)
			enemy_container.add_child(fallback_label)

static func _add_rewards_section(
	container: Node,
	dungeon_id: String,
	difficulty: String,
	dungeon_manager: Node,
	loot_system: Node
):
	"""Add rewards preview section with better organization"""
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)

	# Create rewards panel
	var rewards_panel = Panel.new()
	container.add_child(rewards_panel)

	var rewards_content = VBoxContainer.new()
	rewards_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rewards_content.add_theme_constant_override("separation", 8)
	rewards_panel.add_child(rewards_content)

	var rewards_title = Label.new()
	rewards_title.text = "🎁 REWARDS"
	rewards_title.add_theme_font_size_override("font_size", 20)
	rewards_title.add_theme_color_override("font_color", Color.LIME_GREEN)
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
		guaranteed_header.text = "✅ Guaranteed:"
		guaranteed_header.add_theme_font_size_override("font_size", 16)
		guaranteed_header.add_theme_color_override("font_color", Color.YELLOW)
		content_container.add_child(guaranteed_header)

		for item in guaranteed_items.slice(0, 3):  # Limit to first 3 items
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
			item_label.add_theme_font_size_override("font_size", 14)
			content_container.add_child(item_label)

	# Display rare drops (limited)
	if not rare_items.is_empty():
		var rare_header = Label.new()
		rare_header.text = "🎲 Rare Drops:"
		rare_header.add_theme_font_size_override("font_size", 16)
		rare_header.add_theme_color_override("font_color", Color.PURPLE)
		content_container.add_child(rare_header)

		for item in rare_items.slice(0, 2):  # Limit to first 2 rare items
			var item_label = Label.new()
			var item_id = item.get("item_id", "Unknown")
			var chance = item.get("chance", 0.0)

			item_label.text = "  • %s (%.1f%%)" % [_format_item_name(item_id), chance]
			item_label.add_theme_font_size_override("font_size", 14)
			content_container.add_child(item_label)

static func _show_fallback_rewards_compact(container: Node, difficulty: String):
	"""Show fallback rewards information in compact format"""
	var fallback_text = "⭐ Experience & Mana\n"
	fallback_text += "🔮 Elemental Materials\n"

	# Add difficulty-specific rewards
	match difficulty:
		"beginner":
			fallback_text += "🛡 Basic Equipment"
		"intermediate":
			fallback_text += "⚔ Rare Equipment"
		"advanced":
			fallback_text += "👑 Epic Equipment"
		"expert":
			fallback_text += "💎 Legendary Equipment"

	var fallback_label = Label.new()
	fallback_label.text = fallback_text
	fallback_label.add_theme_font_size_override("font_size", 14)
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
