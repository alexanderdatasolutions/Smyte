# scripts/ui/screens/DungeonTab.gd
# RULE 1 COMPLIANCE: 500-line limit enforced
# RULE 2 COMPLIANCE: Single responsibility - coordinate dungeon UI components
# RULE 4 COMPLIANCE: UI layer - display coordination only, no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control

# Preload component classes
const DungeonListManagerClass = preload("res://scripts/ui/components/DungeonListManager.gd")
const DungeonInfoDisplayManagerClass = preload("res://scripts/ui/components/DungeonInfoDisplayManager.gd") 
const DungeonEntryManagerClass = preload("res://scripts/ui/components/DungeonEntryManager.gd")

# Component managers for focused responsibilities
var list_manager: DungeonListManager
var info_display_manager: DungeonInfoDisplayManager
var entry_manager: DungeonEntryManager

# UI references - preserving original structure for compatibility
@onready var dungeon_list_container = $VBoxContainer/DungeonList
@onready var dungeon_info_container = $VBoxContainer/DungeonInfo
@onready var difficulty_buttons_container = $VBoxContainer/DifficultyButtons
@onready var rewards_container = $VBoxContainer/RewardsPreview
@onready var enter_button = $VBoxContainer/EnterButton
@onready var schedule_info_label = $VBoxContainer/ScheduleInfo

# Current state
var selected_dungeon_id: String = ""
var selected_difficulty: String = ""

func _ready():
	"""Initialize the dungeon tab"""
	print("DungeonTab: Initializing")
	setup_component_managers()
	connect_signals()
	setup_initial_ui_state()
	refresh_dungeons()

func setup_component_managers():
	"""Initialize component managers - RULE 2: Focused responsibilities"""
	# Create dungeon list manager
	list_manager = DungeonListManagerClass.new()
	add_child(list_manager)
	list_manager.initialize(dungeon_list_container)
	
	# Create dungeon info display manager
	info_display_manager = DungeonInfoDisplayManagerClass.new()
	add_child(info_display_manager)
	info_display_manager.initialize(dungeon_info_container, difficulty_buttons_container, rewards_container)
	
	# Create dungeon entry manager
	entry_manager = DungeonEntryManagerClass.new()
	add_child(entry_manager)
	entry_manager.initialize(self)

func connect_signals():
	"""Connect all component signals"""
	# Enter button
	if enter_button:
		enter_button.pressed.connect(_on_enter_button_pressed)
	
	# Component signal connections
	if list_manager:
		list_manager.dungeon_selected.connect(_on_dungeon_selected)
		list_manager.dungeon_list_refreshed.connect(_on_dungeon_list_refreshed)
	
	if info_display_manager:
		info_display_manager.difficulty_selected.connect(_on_difficulty_selected)
		info_display_manager.rewards_display_updated.connect(_on_rewards_display_updated)
	
	if entry_manager:
		entry_manager.entry_validated.connect(_on_entry_validated)
		entry_manager.dungeon_entry_started.connect(_on_dungeon_entry_started)
		entry_manager.dungeon_completed.connect(_on_dungeon_completed)
		entry_manager.dungeon_failed.connect(_on_dungeon_failed)
	
	print("DungeonTab: Signals connected")

func setup_initial_ui_state():
	"""Setup initial UI state"""
	if enter_button:
		enter_button.disabled = true
		enter_button.text = "Select Dungeon"
	
	update_schedule_info()

func refresh_dungeons():
	"""Refresh dungeon displays - RULE 4: UI coordination only"""
	print("DungeonTab: Refreshing dungeons")
	
	# Delegate to list manager
	if list_manager:
		list_manager.refresh_dungeon_list()

# === EVENT HANDLERS ===

func _on_dungeon_selected(dungeon_id: String):
	"""Handle dungeon selection from list manager"""
	print("DungeonTab: Dungeon selected - %s" % dungeon_id)
	
	selected_dungeon_id = dungeon_id
	
	# Get dungeon data and show info
	if list_manager:
		var dungeon_data = list_manager.get_dungeon_by_id(dungeon_id)
		if info_display_manager:
			info_display_manager.show_dungeon_info(dungeon_id, dungeon_data)

func _on_dungeon_list_refreshed():
	"""Handle dungeon list refresh completion"""
	print("DungeonTab: Dungeon list refreshed")

func _on_difficulty_selected(dungeon_id: String, difficulty: String):
	"""Handle difficulty selection from info display manager"""
	print("DungeonTab: Difficulty selected - %s (%s)" % [dungeon_id, difficulty])
	
	selected_dungeon_id = dungeon_id
	selected_difficulty = difficulty
	
	update_enter_button_state()

func _on_rewards_display_updated():
	"""Handle rewards display updates"""
	print("DungeonTab: Rewards display updated")

func _on_enter_button_pressed():
	"""Handle enter dungeon button press"""
	print("DungeonTab: Enter button pressed")
	
	if selected_dungeon_id.is_empty() or selected_difficulty.is_empty():
		show_notification("Please select a dungeon and difficulty first", Color.YELLOW)
		return
	
	# Delegate to entry manager
	if entry_manager:
		entry_manager.attempt_dungeon_entry(selected_dungeon_id, selected_difficulty)

func _on_entry_validated(can_enter: bool, validation_message: String):
	"""Handle entry validation result"""
	print("DungeonTab: Entry validated - Can enter: %s, Message: %s" % [can_enter, validation_message])
	
	if can_enter:
		show_notification("Entering dungeon...", Color.GREEN)
	else:
		show_notification(validation_message, Color.RED)

func _on_dungeon_entry_started(dungeon_id: String, difficulty: String):
	"""Handle dungeon entry start"""
	print("DungeonTab: Dungeon entry started - %s (%s)" % [dungeon_id, difficulty])
	
	# Disable enter button during dungeon
	if enter_button:
		enter_button.disabled = true
		enter_button.text = "In Dungeon..."

func _on_dungeon_completed(dungeon_id: String, difficulty: String, _rewards: Dictionary):
	"""Handle dungeon completion"""
	print("DungeonTab: Dungeon completed - %s (%s)" % [dungeon_id, difficulty])
	
	# Re-enable enter button
	if enter_button:
		enter_button.disabled = false
		update_enter_button_text()
	
	# Show success notification
	show_notification("Dungeon completed successfully!", Color.GREEN)
	
	# Refresh displays to show updated state
	refresh_dungeons()

func _on_dungeon_failed(dungeon_id: String, difficulty: String):
	"""Handle dungeon failure"""
	print("DungeonTab: Dungeon failed - %s (%s)" % [dungeon_id, difficulty])
	
	# Re-enable enter button
	if enter_button:
		enter_button.disabled = false
		update_enter_button_text()
	
	# Show failure notification
	show_notification("Dungeon failed. Try again!", Color.ORANGE)

func update_enter_button_state():
	"""Update enter button enabled state and text - RULE 4: UI state management"""
	if not enter_button:
		return
	
	if selected_dungeon_id.is_empty():
		enter_button.disabled = true
		enter_button.text = "Select Dungeon"
	elif selected_difficulty.is_empty():
		enter_button.disabled = true  
		enter_button.text = "Select Difficulty"
	else:
		enter_button.disabled = false
		update_enter_button_text()

func update_enter_button_text():
	"""Update enter button text with current selection"""
	if not enter_button or selected_dungeon_id.is_empty() or selected_difficulty.is_empty():
		return
	
	var dungeon_name = selected_dungeon_id.replace("_", " ").capitalize()
	enter_button.text = "Enter %s (%s)" % [dungeon_name, selected_difficulty.capitalize()]

func show_notification(message: String, _color: Color):
	"""Show notification message - RULE 4: UI feedback only"""
	print("🔔 DUNGEON NOTIFICATION: %s" % message)
	
	# Could integrate with NotificationManager through SystemRegistry if available
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var notification_manager = system_registry.get_system("NotificationManager")
		if notification_manager:
			notification_manager.show_notification("dungeon", message, 3.0)

func update_schedule_info():
	"""Update dungeon schedule information - RULE 5: Use SystemRegistry"""
	if not schedule_info_label:
		return
	
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var dungeon_manager = system_registry.get_system("DungeonManager")
		if dungeon_manager and dungeon_manager.has_method("get_daily_schedule"):
			var daily_schedule = dungeon_manager.get_daily_schedule()
			schedule_info_label.text = daily_schedule
			return
	
	# Fallback schedule info
	var weekday = Time.get_datetime_dict_from_system().weekday
	var schedule_text = ""
	
	match weekday:
		1: # Monday
			schedule_text = "📅 Today: All Dungeons Open"
		2: # Tuesday  
			schedule_text = "📅 Today: Giant's Keep & Dragon's Lair"
		3: # Wednesday
			schedule_text = "📅 Today: Necromancer's Tomb & Elemental Sanctum"
		4: # Thursday
			schedule_text = "📅 Today: Giant's Keep & Dragon's Lair"
		5: # Friday
			schedule_text = "📅 Today: Necromancer's Tomb & Elemental Sanctum"
		6: # Saturday
			schedule_text = "📅 Today: All Dungeons Open"
		0: # Sunday
			schedule_text = "📅 Today: All Dungeons Open"
		_:
			schedule_text = "📅 Daily Dungeon Schedule"
	
	schedule_info_label.text = schedule_text

# === PUBLIC API ===

func get_selected_dungeon() -> String:
	"""Get currently selected dungeon ID"""
	return selected_dungeon_id

func get_selected_difficulty() -> String:
	"""Get currently selected difficulty"""
	return selected_difficulty

func get_current_selection() -> Dictionary:
	"""Get current dungeon selection"""
	return {
		"dungeon_id": selected_dungeon_id,
		"difficulty": selected_difficulty
	}

# === CLEANUP ===

func _exit_tree():
	"""Clean up when tab is removed"""
	print("DungeonTab: Cleaning up")
	
	# Component managers are children and will be automatically freed
	# Just ensure any remaining connections are cleared
	if list_manager:
		if list_manager.dungeon_selected.is_connected(_on_dungeon_selected):
			list_manager.dungeon_selected.disconnect(_on_dungeon_selected)
		if list_manager.dungeon_list_refreshed.is_connected(_on_dungeon_list_refreshed):
			list_manager.dungeon_list_refreshed.disconnect(_on_dungeon_list_refreshed)
	
	if info_display_manager:
		if info_display_manager.difficulty_selected.is_connected(_on_difficulty_selected):
			info_display_manager.difficulty_selected.disconnect(_on_difficulty_selected)
		if info_display_manager.rewards_display_updated.is_connected(_on_rewards_display_updated):
			info_display_manager.rewards_display_updated.disconnect(_on_rewards_display_updated)
	
	if entry_manager:
		if entry_manager.entry_validated.is_connected(_on_entry_validated):
			entry_manager.entry_validated.disconnect(_on_entry_validated)
		if entry_manager.dungeon_entry_started.is_connected(_on_dungeon_entry_started):
			entry_manager.dungeon_entry_started.disconnect(_on_dungeon_entry_started)
		if entry_manager.dungeon_completed.is_connected(_on_dungeon_completed):
			entry_manager.dungeon_completed.disconnect(_on_dungeon_completed)
		if entry_manager.dungeon_failed.is_connected(_on_dungeon_failed):
			entry_manager.dungeon_failed.disconnect(_on_dungeon_failed)
