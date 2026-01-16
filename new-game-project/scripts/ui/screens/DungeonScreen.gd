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

	# Style tab container to show active tab indicator
	_style_tab_container()

	# Update schedule information
	_update_schedule_display()

func _style_tab_container():
	"""Add visual indicator for active tab"""
	if not category_tabs:
		return

	# Create StyleBoxFlat for selected tab
	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = Color(0.3, 0.3, 0.35, 0.8)  # Slightly lighter than background
	tab_selected.border_color = Color(0.6, 0.8, 1.0)  # Light blue underline
	tab_selected.set_border_width_all(0)
	tab_selected.border_width_bottom = 3  # Underline effect

	# Create StyleBoxFlat for unselected tabs
	var tab_unselected = StyleBoxFlat.new()
	tab_unselected.bg_color = Color(0.2, 0.2, 0.25, 0.6)  # Darker
	tab_unselected.set_border_width_all(0)

	# Create StyleBoxFlat for hover state
	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = Color(0.25, 0.25, 0.3, 0.7)  # Medium brightness
	tab_hover.set_border_width_all(0)

	# Apply styles to tab container
	category_tabs.add_theme_stylebox_override("tab_selected", tab_selected)
	category_tabs.add_theme_stylebox_override("tab_unselected", tab_unselected)
	category_tabs.add_theme_stylebox_override("tab_hovered", tab_hover)
	category_tabs.add_theme_font_size_override("font_size", 16)  # Also increase tab text size

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

	# Create difficulty buttons using InfoDisplay
	InfoDisplay.update_difficulty_buttons(
		difficulty_buttons,
		dungeon_info,
		selected_difficulty,
		_on_difficulty_selected
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

	# Check energy requirements
	if resource_manager:
		var energy_cost = _get_energy_cost(selected_dungeon_id, selected_difficulty)
		if resource_manager.get_resource("energy") < energy_cost:
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
