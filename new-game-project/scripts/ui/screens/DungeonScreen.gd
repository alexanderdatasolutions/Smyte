# scripts/ui/screens/DungeonScreen.gd
# RULE 1: Under 500 lines - UI coordination only
# RULE 2: Single responsibility - Display dungeon selection UI
# RULE 4: No business logic - UI display and event handling only
# RULE 5: SystemRegistry access only
extends Control
class_name DungeonScreen

# Preload helper components
const ListBuilder = preload("res://scripts/ui/dungeon/DungeonListBuilder.gd")
const InfoDisplay = preload("res://scripts/ui/dungeon/DungeonInfoDisplay.gd")

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
var screen_manager: Node

# Current state
var selected_dungeon_id: String = ""
var selected_difficulty: String = "beginner"

# Signals
signal back_pressed

func _ready():
	"""Initialize dungeon screen - RULE 4: UI setup only"""
	_setup_fullscreen()
	_apply_unified_styling()
	_init_systems()
	_connect_ui_signals()
	_setup_initial_state()
	_setup_unified_header()
	_refresh_dungeons()

	# Hide old back button (using unified header)
	if back_button:
		back_button.visible = false

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _apply_unified_styling():
	"""Apply unified dark fantasy styling to match battle setup screen"""
	# Style main background
	var bg = get_node_or_null("Background")
	if bg and bg is ColorRect:
		bg.color = Color(0.08, 0.06, 0.12, 1.0)

	# Style the main container
	var main_container = get_node_or_null("MainContainer")
	if main_container:
		_style_panel_container(main_container)

	# Style left panel
	var left_panel = get_node_or_null("MainContainer/LeftPanel")
	if left_panel:
		_style_panel(left_panel)

	# Style dungeon info panel
	if dungeon_info_panel:
		_style_panel(dungeon_info_panel)

	# Style title label
	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		title_label.add_theme_font_size_override("font_size", 24)

	# Style schedule label
	if schedule_label:
		schedule_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		schedule_label.add_theme_font_size_override("font_size", 14)

	# Style dungeon name label
	if dungeon_name_label:
		dungeon_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		dungeon_name_label.add_theme_font_size_override("font_size", 20)

	# Style dungeon description
	if dungeon_description:
		dungeon_description.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		dungeon_description.add_theme_font_size_override("font_size", 13)

	# Style enter button
	if enter_button:
		_style_primary_button(enter_button)

	# Style dungeon lists
	for list in [elemental_list, pantheon_list, equipment_list]:
		if list:
			_style_dungeon_list(list)

func _style_panel(node: Control):
	"""Apply panel styling with unified colors"""
	if node is PanelContainer:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
		style.border_color = Color(0.3, 0.25, 0.4, 0.8)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10)
		node.add_theme_stylebox_override("panel", style)

func _style_panel_container(node: Control):
	"""Style a generic container with subtle background"""
	if node is PanelContainer:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.14, 0.9)
		style.border_color = Color(0.25, 0.2, 0.35, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		node.add_theme_stylebox_override("panel", style)

func _style_primary_button(button: Button):
	"""Style a primary action button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
	style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.6, 0.35, 0.95)
	style_hover.border_color = Color(0.4, 0.8, 0.5, 1.0)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.15, 0.4, 0.25, 0.95)
	style_pressed.border_color = Color(0.3, 0.6, 0.4, 0.8)
	style_pressed.set_border_width_all(1)
	style_pressed.set_corner_radius_all(6)
	button.add_theme_stylebox_override("pressed", style_pressed)

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.15, 0.15, 0.18, 0.7)
	style_disabled.border_color = Color(0.25, 0.25, 0.3, 0.5)
	style_disabled.set_border_width_all(1)
	style_disabled.set_corner_radius_all(6)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))
	button.add_theme_font_size_override("font_size", 16)

func _style_dungeon_list(list: Control):
	"""Style a dungeon list container"""
	if list is ItemList:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.08, 0.13, 0.8)
		style.border_color = Color(0.2, 0.18, 0.28, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		list.add_theme_stylebox_override("panel", style)
		list.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		list.add_theme_color_override("font_selected_color", Color(0.95, 0.9, 0.8))
		list.add_theme_color_override("font_hovered_color", Color(0.85, 0.85, 0.9))
	elif list is VBoxContainer or list is ScrollContainer:
		# Style children if it's a container
		for child in list.get_children():
			if child is Button:
				_style_list_item_button(child)

func _style_list_item_button(button: Button):
	"""Style a dungeon list item button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.16, 0.8)
	style_normal.border_color = Color(0.25, 0.22, 0.35, 0.6)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.9)
	style_hover.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.2, 0.18, 0.28, 0.95)
	style_pressed.border_color = Color(0.5, 0.45, 0.65, 1.0)
	style_pressed.set_border_width_all(1)
	style_pressed.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	button.add_theme_color_override("font_hover_color", Color(0.9, 0.88, 0.8))

func _setup_unified_header():
	"""Configure the unified header for this screen"""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed():
	"""Update header when this screen becomes visible"""
	if visible:
		_update_header_for_screen()

func _update_header_for_screen():
	"""Apply this screen's header settings"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("DUNGEONS")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_button_pressed)

func _style_back_button():
	"""Style the back button to match dark fantasy theme"""
	if not back_button:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", hover)

	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

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

	screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if not screen_manager:
		push_error("DungeonScreen: ScreenManager not found in SystemRegistry")

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

	# Style tab container to show active tab indicator
	_style_tab_container()

	# Update schedule information
	_update_schedule_display()

func _style_tab_container():
	"""Add visual indicator for active tab with unified styling"""
	if not category_tabs:
		return

	# Create StyleBoxFlat for selected tab - matches unified palette
	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = Color(0.18, 0.15, 0.24, 0.95)
	tab_selected.border_color = Color(0.5, 0.7, 0.9, 0.9)  # Subtle blue glow
	tab_selected.set_border_width_all(0)
	tab_selected.border_width_bottom = 3  # Underline effect
	tab_selected.set_corner_radius_all(6)
	tab_selected.corner_radius_bottom_left = 0
	tab_selected.corner_radius_bottom_right = 0
	tab_selected.set_content_margin_all(12)  # Add padding inside tabs

	# Create StyleBoxFlat for unselected tabs
	var tab_unselected = StyleBoxFlat.new()
	tab_unselected.bg_color = Color(0.1, 0.08, 0.14, 0.7)
	tab_unselected.set_border_width_all(0)
	tab_unselected.set_corner_radius_all(6)
	tab_unselected.corner_radius_bottom_left = 0
	tab_unselected.corner_radius_bottom_right = 0
	tab_unselected.set_content_margin_all(12)

	# Create StyleBoxFlat for hover state
	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = Color(0.14, 0.12, 0.2, 0.85)
	tab_hover.border_color = Color(0.4, 0.35, 0.55, 0.6)
	tab_hover.set_border_width_all(0)
	tab_hover.border_width_bottom = 2
	tab_hover.set_corner_radius_all(6)
	tab_hover.corner_radius_bottom_left = 0
	tab_hover.corner_radius_bottom_right = 0
	tab_hover.set_content_margin_all(12)

	# Apply styles to tab container
	category_tabs.add_theme_stylebox_override("tab_selected", tab_selected)
	category_tabs.add_theme_stylebox_override("tab_unselected", tab_unselected)
	category_tabs.add_theme_stylebox_override("tab_hovered", tab_hover)
	category_tabs.add_theme_font_size_override("font_size", 16)
	category_tabs.add_theme_constant_override("h_separation", 20)  # More spacing between tabs
	category_tabs.add_theme_color_override("font_selected_color", Color(0.9, 0.88, 0.8))
	category_tabs.add_theme_color_override("font_unselected_color", Color(0.55, 0.55, 0.6))
	category_tabs.add_theme_color_override("font_hovered_color", Color(0.75, 0.75, 0.8))

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
	"""Refresh dungeon lists - RULE 4: Delegate to ListBuilder"""
	if not dungeon_manager:
		ListBuilder.clear_dungeon_lists([elemental_list, pantheon_list, equipment_list])
		ListBuilder.show_placeholder_dungeons(elemental_list)
		return

	var categories = dungeon_manager.get_dungeon_categories()

	# Use ListBuilder to populate lists
	ListBuilder.populate_category_list(
		elemental_list,
		categories.get("elemental", []),
		_on_dungeon_selected
	)
	ListBuilder.populate_category_list(
		pantheon_list,
		categories.get("pantheon", []),
		_on_dungeon_selected
	)
	ListBuilder.populate_category_list(
		equipment_list,
		categories.get("equipment", []),
		_on_dungeon_selected
	)

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

	# Create difficulty buttons using InfoDisplay (with completion status)
	InfoDisplay.update_difficulty_buttons(
		difficulty_buttons,
		dungeon_info,
		selected_difficulty,
		_on_difficulty_selected,
		dungeon_manager
	)

	# Update rewards display using InfoDisplay
	InfoDisplay.update_rewards_display(
		rewards_container,
		selected_dungeon_id,
		selected_difficulty,
		dungeon_manager,
		loot_system
	)

	# Update enter button
	_update_enter_button_state()

func _on_difficulty_selected(difficulty: String, pressed: bool):
	"""Handle difficulty selection"""
	if not pressed:
		return

	selected_difficulty = difficulty

	# Update rewards display using InfoDisplay
	InfoDisplay.update_rewards_display(
		rewards_container,
		selected_dungeon_id,
		selected_difficulty,
		dungeon_manager,
		loot_system
	)

	_update_enter_button_state()

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

	# Proceed to battle setup (energy cost removed)
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
	if not screen_manager:
		push_error("DungeonScreen: Cannot open battle setup - ScreenManager not available")
		return

	# Navigate to battle setup screen
	if screen_manager.change_screen("battle_setup"):
		# Get the screen instance and configure it for dungeon battle
		var battle_setup_screen = screen_manager.get_current_screen()
		if battle_setup_screen and battle_setup_screen.has_method("setup_for_dungeon_battle"):
			battle_setup_screen.setup_for_dungeon_battle(selected_dungeon_id, selected_difficulty)
			# Connect to completion signal if not already connected
			if not battle_setup_screen.battle_setup_complete.is_connected(_on_battle_setup_complete):
				battle_setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)
			if not battle_setup_screen.setup_cancelled.is_connected(_on_battle_setup_cancelled):
				battle_setup_screen.setup_cancelled.connect(_on_battle_setup_cancelled)

func _on_battle_setup_complete(context: Dictionary):
	"""Handle battle setup completion - start the dungeon battle"""
	if not screen_manager:
		push_error("DungeonScreen: Cannot start battle - ScreenManager not available")
		return

	# Get battle coordinator to start the battle
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")
	if not battle_coordinator:
		push_error("DungeonScreen: BattleCoordinator not available")
		return

	# Build battle configuration for dungeon
	var selected_team = context.get("selected_team", [])
	var dungeon_id = context.get("dungeon_id", selected_dungeon_id)
	var difficulty = context.get("difficulty", selected_difficulty)

	# Filter out null entries from selected team
	var valid_team = []
	for god in selected_team:
		if god != null:
			valid_team.append(god)

	if valid_team.is_empty():
		push_error("DungeonScreen: No valid gods in selected team")
		return

	# Build proper BattleConfig
	var battle_config = BattleConfig.new()
	battle_config.battle_type = BattleConfig.BattleType.DUNGEON
	battle_config.attacker_team = valid_team
	battle_config.dungeon_name = dungeon_id

	# Get enemy waves from dungeon manager using get_battle_configuration
	if dungeon_manager:
		var dungeon_battle_config = dungeon_manager.get_battle_configuration(dungeon_id, difficulty)
		var waves = dungeon_battle_config.get("enemy_waves", [])
		if waves.is_empty():
			# Create default enemy wave if none defined
			waves = [[{"name": "Dungeon Monster", "level": 5, "hp": 500, "attack": 100, "defense": 50, "speed": 80}]]
		battle_config.enemy_waves = waves
		print("DungeonScreen: Loaded ", waves.size(), " waves with enemies: ", waves)

	# Navigate to battle screen first
	if screen_manager.change_screen("battle"):
		# Get battle screen and start battle
		var battle_screen = screen_manager.get_current_screen()
		if battle_screen and battle_screen.has_method("start_battle"):
			battle_screen.start_battle(battle_config)
		else:
			# Fallback: start battle directly through coordinator
			battle_coordinator.start_battle(battle_config)

func _on_battle_setup_cancelled():
	"""Handle battle setup cancellation - return to dungeon screen"""
	# Already on dungeon screen, nothing to do
	pass

func _show_error_message(message: String):
	"""Show error message to user"""
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	if notification_manager:
		notification_manager.show_error(message)

func _on_back_button_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func _enter_tree():
	"""Called when entering scene tree"""
	if not SystemRegistry.get_instance():
		push_error("DungeonScreen: SystemRegistry not available")
