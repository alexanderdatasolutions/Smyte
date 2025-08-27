# scripts/ui/DungeonTab.gd
extends Control

@onready var schedule_label = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_ScheduleInfo#ScheduleLabel"
@onready var dungeon_list = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_LeftPanel_ScrollContainer#DungeonList"
@onready var dungeon_info_panel = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer#DungeonInfoPanel"
@onready var dungeon_name_label = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_DungeonInfoPanel#DungeonNameLabel"
@onready var dungeon_description = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_DungeonInfoPanel#DungeonDescription"
@onready var difficulty_container = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_DungeonInfoPanel#DifficultyContainer"
@onready var rewards_container = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_DungeonInfoPanel#RewardsContainer"
@onready var enter_button = $"TabContainer_Dungeons_DungeonScreen_VBoxContainer_HBoxContainer_DungeonInfoPanel#EnterButton"

var dungeon_system: Node
var selected_dungeon_id: String = ""
var selected_difficulty: String = ""

func _ready():
	# Get dungeon system reference
	dungeon_system = get_node_or_null("/root/DungeonSystem")
	if not dungeon_system:
		print("DungeonSystem not found")
		return
	
	# Connect signals
	if dungeon_system.has_signal("dungeon_completed"):
		dungeon_system.dungeon_completed.connect(_on_dungeon_completed)
	if dungeon_system.has_signal("dungeon_failed"):
		dungeon_system.dungeon_failed.connect(_on_dungeon_failed)
	
	# Connect UI signals
	if enter_button:
		enter_button.pressed.connect(_on_enter_button_pressed)

func refresh_dungeons():
	"""Refresh the dungeon interface - called when tab becomes visible"""
	if not dungeon_system:
		return
	
	update_schedule_info()
	refresh_dungeon_list()

func refresh_dungeon_list():
	"""Refresh the list of available dungeons"""
	if not dungeon_list:
		return
	
	# Clear existing list
	for child in dungeon_list.get_children():
		child.queue_free()
	
	var available_dungeons = dungeon_system.get_available_dungeons_today()
	
	if available_dungeons.size() == 0:
		var no_dungeons_label = Label.new()
		no_dungeons_label.text = "No dungeons available today"
		no_dungeons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dungeon_list.add_child(no_dungeons_label)
		return
	
	# Create dungeon buttons
	for dungeon_info in available_dungeons:
		create_dungeon_button(dungeon_info)

func create_dungeon_button(dungeon_info: Dictionary):
	"""Create a button for a dungeon"""
	var button = Button.new()
	var dungeon_id = dungeon_info.get("id", "")
	var dungeon_name = dungeon_info.get("name", "Unknown Dungeon")
	var element = dungeon_info.get("element", "")
	
	# Set button text and styling based on element
	button.text = dungeon_name
	button.custom_minimum_size = Vector2(250, 50)
	
	# Style based on element
	match element:
		"fire":
			button.modulate = Color.ORANGE_RED
		"water":
			button.modulate = Color.CYAN
		"earth":
			button.modulate = Color.SADDLE_BROWN
		"lightning":
			button.modulate = Color.YELLOW
		"light":
			button.modulate = Color.WHITE
		"dark":
			button.modulate = Color.PURPLE
		"neutral":
			button.modulate = Color.LIGHT_GRAY
		_:
			button.modulate = Color.WHITE
	
	# Connect button signal
	button.pressed.connect(_on_dungeon_selected.bind(dungeon_id))
	
	# Add to list
	dungeon_list.add_child(button)

func _on_dungeon_selected(dungeon_id: String):
	"""Handle dungeon selection"""
	selected_dungeon_id = dungeon_id
	selected_difficulty = "beginner"  # Default to beginner
	
	# Show dungeon info
	show_dungeon_info(dungeon_id)

func show_dungeon_info(dungeon_id: String):
	"""Show detailed information about a dungeon"""
	if not dungeon_system:
		return
	
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return
	
	# Show the info panel
	if dungeon_info_panel:
		dungeon_info_panel.visible = true
	
	# Update dungeon name and description
	if dungeon_name_label:
		dungeon_name_label.text = dungeon_info.get("name", "Unknown Dungeon")
	if dungeon_description:
		dungeon_description.text = dungeon_info.get("description", "No description available")
	
	# Create difficulty buttons
	update_difficulty_buttons(dungeon_id, dungeon_info)
	
	# Show rewards for current difficulty
	update_rewards_display(dungeon_id, selected_difficulty)

func update_difficulty_buttons(dungeon_id: String, dungeon_info: Dictionary):
	"""Update difficulty selection buttons"""
	if not difficulty_container:
		return
	
	# Clear existing buttons
	for child in difficulty_container.get_children():
		child.queue_free()
	
	var difficulties = dungeon_info.get("difficulty_levels", {})
	
	for difficulty in difficulties.keys():
		var button = Button.new()
		button.text = difficulty.capitalize()
		button.toggle_mode = true
		
		# Check if difficulty is unlocked
		var unlocked = dungeon_system.is_difficulty_unlocked(dungeon_id, difficulty)
		button.disabled = not unlocked
		
		if not unlocked:
			button.text += " (Locked)"
			button.modulate = Color.GRAY
		
		# Set default selection
		if difficulty == selected_difficulty:
			button.button_pressed = true
		
		# Connect signal
		button.toggled.connect(_on_difficulty_selected.bind(difficulty))
		
		difficulty_container.add_child(button)

func _on_difficulty_selected(difficulty: String, pressed: bool):
	"""Handle difficulty selection"""
	if not pressed:
		return
	
	selected_difficulty = difficulty
	
	# Unpress other buttons
	if difficulty_container:
		for button in difficulty_container.get_children():
			if button != get_viewport().gui_get_focus_owner():
				button.button_pressed = false
	
	# Update rewards display
	update_rewards_display(selected_dungeon_id, difficulty)

func update_rewards_display(dungeon_id: String, difficulty: String):
	"""Update the rewards display for the selected dungeon and difficulty - FULLY MODULAR"""
	if not rewards_container:
		return
	
	# Clear existing rewards (except title label)
	for child in rewards_container.get_children():
		if child.name != "RewardsLabel":
			child.queue_free()
	
	# Get the actual loot table name for this dungeon/difficulty
	var loot_table_name = _convert_dungeon_id_to_loot_table_name(dungeon_id, difficulty)
	
	# Get the loot system to read actual rewards
	var system_registry = SystemRegistry.get_instance()
	var loot_system = system_registry.get_system("LootSystem")
	if loot_system:
		if loot_system and loot_system.has_method("get_loot_table_rewards_preview"):
			var rewards_preview = loot_system.get_loot_table_rewards_preview(loot_table_name)
			if rewards_preview.size() > 0:
				_display_modular_rewards(rewards_preview)
				return
	
	# Fallback - show message that rewards are being loaded
	var loading_label = Label.new()
	loading_label.text = "• Loading reward information..."
	loading_label.modulate = Color.YELLOW
	rewards_container.add_child(loading_label)

func _convert_dungeon_id_to_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Convert dungeon ID to the correct loot table name - matches loot_tables.json structure"""
	
	# Handle special mappings first
	match dungeon_id:
		"magic_sanctum":
			return "magic_dungeon"  # Hall of Magic uses generic "magic_dungeon" (no difficulty)
		"titans_forge", "valhalla_armory", "oracle_sanctum", "elysian_fields", "styx_crossing":
			return "equipment_dungeon"  # All equipment dungeons use generic table
		_:
			# Handle elemental sanctums - they need difficulty appended
			if dungeon_id.ends_with("_sanctum"):
				var element = dungeon_id.replace("_sanctum", "")
				return element + "_dungeon_" + difficulty  # e.g. "fire_dungeon_beginner"
			elif "_trials" in dungeon_id:
				var pantheon = dungeon_id.replace("_trials", "")
				return "pantheon_trial_" + pantheon  # e.g. "pantheon_trial_greek"
	
	# Default fallback
	return dungeon_id + "_" + difficulty

func _display_modular_rewards(rewards_preview: Array):
	"""Display rewards using the modular system - no hardcoded text"""
	for reward_info in rewards_preview:
		var reward_label = Label.new()
		var resource_name = reward_info.get("resource_name", "Unknown")
		var amount_text = reward_info.get("amount_text", "")
		var chance_text = reward_info.get("chance_text", "")
		
		# Format: • Resource Name: Amount (Chance)
		var display_text = "• %s: %s" % [resource_name, amount_text]
		if chance_text != "":
			display_text += " (%s)" % chance_text
		
		reward_label.text = display_text
		reward_label.modulate = reward_info.get("color", Color.WHITE)
		rewards_container.add_child(reward_label)

func add_reward_item(reward_text: String):
	"""Add a reward item to the display"""
	if not rewards_container:
		return
	
	var item = Label.new()
	item.text = "• " + reward_text
	item.modulate = Color.LIGHT_GREEN
	rewards_container.add_child(item)

func _on_enter_button_pressed():
	"""Handle enter dungeon button press"""
	if selected_dungeon_id == "" or selected_difficulty == "":
		show_notification("Please select a dungeon and difficulty", Color.RED)
		return
	
	# Check if player has a team selected
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	var gods_list = collection_manager.get_all_gods() if collection_manager else []
	if gods_list.size() == 0:
		show_notification("You need at least one god to enter a dungeon", Color.RED)
		return
	
	# For now, use first 5 gods as team (in real implementation, show team selection)
	var team = []
	var god_count = min(5, gods_list.size())
	for i in range(god_count):
		team.append(gods_list[i])
	
	# Attempt dungeon
	var result = dungeon_system.attempt_dungeon(selected_dungeon_id, selected_difficulty, team)
	
	if not result.success:
		show_notification(result.error_message, Color.RED)
	else:
		show_notification("Dungeon completed! Check your rewards.", Color.GREEN)
		# Refresh UI to update clear counts, etc.
		refresh_dungeon_list()

func _on_dungeon_completed(_dungeon_id: String, _difficulty: String, rewards: Dictionary):
	"""Handle dungeon completion"""
	var message = "Dungeon completed!\nRewards:\n"
	for reward_type in rewards:
		message += "• " + reward_type + ": " + str(rewards[reward_type]) + "\n"
	
	show_notification(message, Color.GREEN)

func _on_dungeon_failed(_dungeon_id: String, _difficulty: String):
	"""Handle dungeon failure"""
	show_notification("Dungeon failed! Your team wasn't strong enough.", Color.RED)

func show_notification(message: String, _color: Color):
	"""Show a temporary notification"""
	print("Dungeon Notification: " + message)
	# In a real implementation, you'd create a proper notification UI

func update_schedule_info():
	"""Update the schedule information display"""
	if not schedule_label or not dungeon_system:
		return
	
	var schedule_info = dungeon_system.get_dungeon_schedule_info()
	var today = schedule_info.get("today", "unknown")
	var todays_dungeons = schedule_info.get("todays_dungeons", [])
	
	var schedule_text = "Today (" + today.capitalize() + "): "
	if todays_dungeons.size() > 0:
		schedule_text += todays_dungeons[0].replace("_", " ").capitalize()
		for i in range(1, todays_dungeons.size()):
			schedule_text += ", " + todays_dungeons[i].replace("_", " ").capitalize()
	else:
		schedule_text += "No special dungeons"
	
	schedule_label.text = schedule_text
