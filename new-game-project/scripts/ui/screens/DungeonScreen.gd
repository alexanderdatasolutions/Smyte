# scripts/ui/screens/DungeonScreen.gd
# RULE 1: Under 500 lines - UI coordination only
# RULE 2: Single responsibility - Display dungeon selection UI 
# RULE 4: No business logic - UI display and event handling only
# RULE 5: SystemRegistry access only
extends Control
class_name DungeonScreen

# UI node references - Fixed positioning system like other scenes
@onready var back_button = $BackButton
@onready var title_label = $TitleLabel
@onready var schedule_label = $MainContainer/LeftPanel/ScheduleInfo/ScheduleLabel
@onready var category_tabs = $MainContainer/LeftPanel/CategoryTabs
@onready var elemental_list = $MainContainer/LeftPanel/CategoryTabs/Elemental/ElementalDungeonList
@onready var pantheon_list = $MainContainer/LeftPanel/CategoryTabs/Pantheon/PantheonDungeonList
@onready var equipment_list = $MainContainer/LeftPanel/CategoryTabs/Equipment/EquipmentDungeonList
@onready var dungeon_info_panel = $MainContainer/DungeonInfoPanel
@onready var dungeon_name_label = $MainContainer/DungeonInfoPanel/InfoContainer/DungeonNameLabel
@onready var dungeon_description = $MainContainer/DungeonInfoPanel/InfoContainer/DungeonDescription
@onready var difficulty_buttons = $MainContainer/DungeonInfoPanel/InfoContainer/DifficultyContainer
@onready var rewards_container = $MainContainer/DungeonInfoPanel/InfoContainer/RewardsContainer
@onready var enter_button = $MainContainer/DungeonInfoPanel/InfoContainer/EnterButton

# System references (RULE 5)
var dungeon_manager: Node
var resource_manager: Node
var loot_system: Node

# Current state
var selected_dungeon_id: String = ""
var selected_difficulty: String = "beginner"

# Signals
signal back_pressed

func _ready():
	"""Initialize dungeon screen - RULE 4: UI setup only"""
	_init_systems()
	_connect_ui_signals()
	_setup_initial_state()
	_refresh_dungeons()

func _init_systems():
	"""Initialize system references through SystemRegistry"""
	# Use correct SystemRegistry access pattern
	dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	if not dungeon_manager:
		push_error("DungeonScreen: DungeonManager not found in SystemRegistry")
	
	resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if not resource_manager:
		push_error("DungeonScreen: ResourceManager not found in SystemRegistry")
	
	loot_system = SystemRegistry.get_instance().get_system("LootSystem")
	if not loot_system:
		push_warning("DungeonScreen: LootSystem not found - loot previews will be limited")

func _connect_ui_signals():
	"""Connect UI element signals"""
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	if enter_button:
		enter_button.pressed.connect(_on_enter_button_pressed)
	
	# Connect system signals if available
	if dungeon_manager:
		if dungeon_manager.has_signal("dungeon_data_loaded"):
			dungeon_manager.dungeon_data_loaded.connect(_refresh_dungeons)

func _setup_initial_state():
	"""Setup initial UI state"""
	dungeon_info_panel.visible = false
	enter_button.disabled = true
	
	# Update schedule information
	_update_schedule_display()

func _update_schedule_display():
	"""Update the schedule information like Summoners War - only rotating dungeons"""
	if not schedule_label or not dungeon_manager:
		return
	
	# Get today's dungeon schedule
	var schedule_info = dungeon_manager.get_dungeon_schedule_info()
	if schedule_info.is_empty():
		schedule_label.text = "Loading schedule..."
		return
	
	var today = schedule_info.get("today", "Unknown")
	var available_dungeons = schedule_info.get("available_dungeons", [])
	
	var schedule_text = "Today (%s): " % today.capitalize()
	if available_dungeons.size() > 0:
		var dungeon_names = PackedStringArray()
		for dungeon in available_dungeons:
			var dungeon_name = dungeon.get("name", "Unknown")
			dungeon_names.append(dungeon_name)
		schedule_text += ", ".join(dungeon_names)
	else:
		schedule_text += "No special dungeons today"
	
	schedule_label.text = schedule_text
	if enter_button:
		enter_button.disabled = true
		enter_button.text = "Select Dungeon"

func _refresh_dungeons():
	"""Refresh dungeon lists - RULE 4: Delegate to systems"""
	if not dungeon_manager:
		_show_placeholder_dungeons()
		return
	
	var categories = dungeon_manager.get_dungeon_categories()
	
	_populate_category_list(elemental_list, categories.get("elemental", []))
	_populate_category_list(pantheon_list, categories.get("pantheon", []))
	_populate_category_list(equipment_list, categories.get("equipment", []))

func _show_placeholder_dungeons():
	"""Show placeholder while systems load"""
	_clear_dungeon_lists()
	
	# Create a simple test button to verify the container works
	if elemental_list:
		var test_button = Button.new()
		test_button.text = "Test Elemental Dungeon"
		test_button.custom_minimum_size = Vector2(200, 50)
		elemental_list.add_child(test_button)

func _populate_category_list(container: Node, dungeons: Array):
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
		_create_dungeon_button(dungeon_info, grid_container)

func _create_dungeon_button(dungeon_info: Dictionary, container: Node):
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
	button.pressed.connect(_on_dungeon_selected.bind(dungeon_id))
	
	# Add styling based on element/category
	_style_dungeon_button(button, dungeon_info)
	
	container.add_child(button)

func _format_power(power: int) -> String:
	"""Format power number for display"""
	if power >= 1000000:
		return "%.1fM" % (power / 1000000.0)
	elif power >= 1000:
		return "%.1fK" % (power / 1000.0)
	else:
		return str(power)

func _style_dungeon_button(button: Button, dungeon_info: Dictionary):
	"""Apply styling to dungeon button based on properties - Enhanced with element colors"""
	var element = dungeon_info.get("element", "neutral")
	
	# Apply element-based color styling like original
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
	button.mouse_entered.connect(_on_dungeon_button_hovered.bind(button, true))
	button.mouse_exited.connect(_on_dungeon_button_hovered.bind(button, false))

func _on_dungeon_button_hovered(button: Button, is_hovered: bool):
	"""Handle dungeon button hover effects"""
	if is_hovered:
		button.modulate = button.modulate.lightened(0.2)
	else:
		# Restore original color
		var original_color = button.get_meta("original_color", Color.WHITE)
		button.modulate = original_color

func _clear_dungeon_lists():
	"""Clear all dungeon category lists"""
	var lists = [elemental_list, pantheon_list, equipment_list]
	for dungeon_list in lists:
		if dungeon_list:
			for child in dungeon_list.get_children():
				child.queue_free()

func _on_dungeon_selected(dungeon_id: String):
	"""Handle dungeon selection"""
	selected_dungeon_id = dungeon_id
	
	# Set default difficulty based on dungeon type
	if dungeon_manager:
		var dungeon_info = dungeon_manager.get_dungeon_info(dungeon_id)
		var available_difficulties = dungeon_info.get("difficulty_levels", {}).keys()
		
		if available_difficulties.has("beginner"):
			selected_difficulty = "beginner"
		elif available_difficulties.has("heroic"):
			selected_difficulty = "heroic"
		else:
			selected_difficulty = available_difficulties[0] if not available_difficulties.is_empty() else ""
	
	_show_dungeon_info(dungeon_id)

func _show_dungeon_info(dungeon_id: String):
	"""Show detailed information about a dungeon"""
	if not dungeon_manager:
		return
	
	var dungeon_info = dungeon_manager.get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		_show_error_message("Dungeon information not found")
		return
	
	# Show the info panel
	dungeon_info_panel.visible = true
	
	# Update dungeon name and description
	if dungeon_name_label:
		dungeon_name_label.text = dungeon_info.get("name", "Unknown Dungeon")
	if dungeon_description:
		var description_text = dungeon_info.get("description", "No description available")
		# Truncate description if too long to keep it compact
		if description_text.length() > 150:
			description_text = description_text.substr(0, 147) + "..."
		dungeon_description.text = description_text
		# Set a maximum height for the description to keep layout compact
		dungeon_description.custom_minimum_size = Vector2(0, 40)
		dungeon_description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create difficulty buttons
	_update_difficulty_buttons(dungeon_info)
	
	# Update rewards display
	_update_rewards_display(dungeon_id, selected_difficulty)
	
	# Update enter button
	_update_enter_button_state()

func _update_difficulty_buttons(dungeon_info: Dictionary):
	"""Update difficulty selection buttons with organized layout"""
	if not difficulty_buttons:
		return
	
	# Clear existing buttons
	for child in difficulty_buttons.get_children():
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
		
		# Use a simple callable approach
		var callable = func(pressed: bool): _on_difficulty_selected(difficulty, pressed)
		button.toggled.connect(callable)
		difficulty_buttons.add_child(button)

func _on_difficulty_selected(difficulty: String, pressed: bool):
	"""Handle difficulty selection"""
	if not pressed:
		return
	
	selected_difficulty = difficulty
	_update_rewards_display(selected_dungeon_id, difficulty)
	_update_enter_button_state()

func _update_rewards_display(dungeon_id: String, difficulty: String):
	"""Update the rewards display with detailed dungeon information"""
	
	if not rewards_container:
		return
	
	# Clear existing rewards
	for child in rewards_container.get_children():
		child.queue_free()
	
	if not dungeon_manager:
		return
	
	var dungeon_info = dungeon_manager.get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return
	
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	
	# Create main info container
	var info_container = VBoxContainer.new()
	rewards_container.add_child(info_container)
	
	# Add dungeon stats section
	_add_dungeon_stats(info_container, difficulty_info)
	
	# Add enemy information section
	_add_enemy_info(info_container, dungeon_info, difficulty_info)
	
	# Add rewards section
	_add_rewards_section(info_container, dungeon_id, difficulty)

func _add_dungeon_stats(container: Node, difficulty_info: Dictionary):
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
	stats_title.add_theme_font_size_override("font_size", 20)  # Increased from 14
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

func _add_stat_pair(grid: GridContainer, label_text: String, value_text: String):
	"""Add a label-value pair to the grid"""
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)  # Increased from 12
	grid.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)  # Increased from 12
	value.add_theme_color_override("font_color", Color.CYAN)
	grid.add_child(value)

func _add_enemy_info(container: Node, dungeon_info: Dictionary, _difficulty_info: Dictionary):
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
	enemies_title.add_theme_font_size_override("font_size", 20)  # Increased from 14
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
			enemies_info.add_theme_font_size_override("font_size", 14)  # Increased from 11
			enemy_container.add_child(enemies_info)
		else:
			var fallback_label = Label.new()
			fallback_label.text = "Various elemental enemies"
			fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback_label.add_theme_font_size_override("font_size", 14)  # Increased from 11
			enemy_container.add_child(fallback_label)

func _add_rewards_section(container: Node, dungeon_id: String, difficulty: String):
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
	rewards_title.add_theme_font_size_override("font_size", 20)  # Increased from 14
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

func _display_loot_preview_compact(container: Node, loot_preview: Array):
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
		guaranteed_header.add_theme_font_size_override("font_size", 16)  # Increased from 12
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
			item_label.add_theme_font_size_override("font_size", 14)  # Increased from 10
			content_container.add_child(item_label)
	
	# Display rare drops (limited)
	if not rare_items.is_empty():
		var rare_header = Label.new()
		rare_header.text = "🎲 Rare Drops:"
		rare_header.add_theme_font_size_override("font_size", 16)  # Increased from 12
		rare_header.add_theme_color_override("font_color", Color.PURPLE)
		content_container.add_child(rare_header)
		
		for item in rare_items.slice(0, 2):  # Limit to first 2 rare items
			var item_label = Label.new()
			var item_id = item.get("item_id", "Unknown")
			var chance = item.get("chance", 0.0)
			
			item_label.text = "  • %s (%.1f%%)" % [_format_item_name(item_id), chance]
			item_label.add_theme_font_size_override("font_size", 14)  # Increased from 10
			content_container.add_child(item_label)

func _show_fallback_rewards_compact(container: Node, difficulty: String):
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
	fallback_label.add_theme_font_size_override("font_size", 14)  # Increased from 11
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(fallback_label)

func _display_loot_preview(container: Node, loot_preview: Array):
	"""Display actual loot preview from LootSystem"""
	var preview_text = ""
	
	if loot_preview.is_empty():
		preview_text = "No loot information available"
	else:
		# Group items by type or rarity
		var guaranteed_items = []
		var rare_items = []
		
		for item in loot_preview:
			var chance = item.get("chance", 0.0)
			if chance >= 100.0:
				guaranteed_items.append(item)
			else:
				rare_items.append(item)
		
		# Display guaranteed drops
		if not guaranteed_items.is_empty():
			preview_text += "Guaranteed:\n"
			for item in guaranteed_items:
				var item_id = item.get("item_id", "Unknown")
				var min_amount = item.get("min_amount", 1)
				var max_amount = item.get("max_amount", 1)
				
				var amount_text = ""
				if min_amount == max_amount:
					amount_text = " x%d" % min_amount
				else:
					amount_text = " x%d-%d" % [min_amount, max_amount]
				
				preview_text += "• %s%s\n" % [_format_item_name(item_id), amount_text]
		
		# Display rare drops
		if not rare_items.is_empty():
			if not guaranteed_items.is_empty():
				preview_text += "\n"
			preview_text += "Rare Drops:\n"
			for item in rare_items:
				var item_id = item.get("item_id", "Unknown")
				var chance = item.get("chance", 0.0)
				var min_amount = item.get("min_amount", 1)
				var max_amount = item.get("max_amount", 1)
				
				var amount_text = ""
				if min_amount == max_amount:
					amount_text = " x%d" % min_amount
				else:
					amount_text = " x%d-%d" % [min_amount, max_amount]
				
				preview_text += "• %s%s (%.1f%%)\n" % [_format_item_name(item_id), amount_text, chance]
	
	if preview_text.is_empty():
		preview_text = "Loot information loading..."
	
	var preview_label = Label.new()
	preview_label.text = preview_text
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(preview_label)

func _format_item_name(item_id: String) -> String:
	"""Format item ID into a readable name"""
	return item_id.replace("_", " ").capitalize()

func _show_fallback_rewards(container: Node, dungeon_id: String, difficulty: String):
	"""Show fallback rewards information when LootSystem is unavailable"""
	var fallback_text = "• Experience for your gods\n"
	fallback_text += "• Elemental materials\n"
	fallback_text += "• Mana crystals\n"
	
	# Add difficulty-specific rewards
	match difficulty:
		"beginner":
			fallback_text += "• Basic equipment materials"
		"intermediate":
			fallback_text += "• Rare equipment materials"
		"advanced":
			fallback_text += "• Epic equipment materials"
		"expert":
			fallback_text += "• Legendary equipment materials"
	
	var fallback_label = Label.new()
	fallback_label.text = fallback_text
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(fallback_label)
	
	# Add title
	var rewards_title = RichTextLabel.new()
	rewards_title.custom_minimum_size.y = 40
	rewards_title.fit_content = true
	rewards_title.bbcode_enabled = true
	rewards_title.text = "[b]Rewards - %s[/b]" % difficulty.capitalize()
	rewards_container.add_child(rewards_title)
	
	# Get loot information from LootSystem
	if loot_system:
		var loot_table_name = _get_loot_table_name(dungeon_id, difficulty)
		var loot_preview = loot_system.get_loot_preview(loot_table_name)
		
		if not loot_preview.is_empty():
			_display_loot_preview(container, loot_preview)

func _get_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Convert dungeon ID and difficulty to loot table name"""
	var loot_table_name = ""
	
	if dungeon_manager and dungeon_manager.has_method("get_loot_table_name"):
		loot_table_name = dungeon_manager.get_loot_table_name(dungeon_id, difficulty)
	
	if loot_table_name == "":
		# Fallback logic
		if dungeon_id.ends_with("_sanctum"):
			loot_table_name = "elemental_dungeon_" + difficulty
		else:
			loot_table_name = dungeon_id + "_" + difficulty
	
	return loot_table_name

func _update_enter_button_state():
	"""Update enter button state"""
	if not enter_button:
		return
	
	var can_enter = not selected_dungeon_id.is_empty() and not selected_difficulty.is_empty()
	enter_button.disabled = not can_enter
	
	if can_enter:
		enter_button.text = "Enter Dungeon"
	else:
		enter_button.text = "Select Dungeon & Difficulty"

func _on_enter_button_pressed():
	"""Handle enter dungeon button press"""
	if selected_dungeon_id.is_empty() or selected_difficulty.is_empty():
		_show_error_message("Please select a dungeon and difficulty first")
		return
	
	# Check energy requirements
	if resource_manager:
		var energy_cost = _get_energy_cost(selected_dungeon_id, selected_difficulty)
		if not resource_manager.has_resource("energy", energy_cost):
			_show_error_message("Not enough energy (need %d)" % energy_cost)
			return
	
	# Proceed to battle setup
	_open_battle_setup()

func _get_energy_cost(dungeon_id: String, difficulty: String) -> int:
	"""Get energy cost for dungeon"""
	if dungeon_manager:
		var dungeon_info = dungeon_manager.get_dungeon_info(dungeon_id)
		var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		return difficulty_info.get("energy_cost", 8)
	
	return 8  # Default cost

func _open_battle_setup():
	"""Open battle setup screen for dungeon"""
	# This would typically switch to a battle setup screen
	# Could emit signal for parent to handle
	# battle_setup_requested.emit(selected_dungeon_id, selected_difficulty)
	pass

func _show_error_message(_message: String):
	"""Show error message to user"""
	# Could integrate with NotificationManager through SystemRegistry
	pass

func _on_back_button_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func _enter_tree():
	"""Called when entering scene tree"""
	if not SystemRegistry.get_instance():
		push_error("DungeonScreen: SystemRegistry not available")
