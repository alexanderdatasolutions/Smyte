extends Control

@onready var elemental_dungeon_list = $MainContainer/LeftPanel/CategoryTabs/Elemental/ElementalDungeonList
@onready var pantheon_dungeon_list = $MainContainer/LeftPanel/CategoryTabs/Pantheon/PantheonDungeonList
@onready var equipment_dungeon_list = $MainContainer/LeftPanel/CategoryTabs/Equipment/EquipmentDungeonList
@onready var category_tabs = $MainContainer/LeftPanel/CategoryTabs
@onready var dungeon_info_panel = $MainContainer/DungeonInfoPanel
@onready var dungeon_name_label = $MainContainer/DungeonInfoPanel/InfoContainer/DungeonNameLabel
@onready var dungeon_description = $MainContainer/DungeonInfoPanel/InfoContainer/DungeonDescription
@onready var difficulty_buttons = $MainContainer/DungeonInfoPanel/InfoContainer/DifficultyContainer
@onready var rewards_container = $MainContainer/DungeonInfoPanel/InfoContainer/RewardsContainer
@onready var rewards_label = $MainContainer/DungeonInfoPanel/InfoContainer/RewardsContainer/RewardsLabel
@onready var enter_button = $MainContainer/DungeonInfoPanel/InfoContainer/EnterButton
@onready var schedule_label = $MainContainer/LeftPanel/ScheduleInfo/ScheduleLabel
@onready var back_button = $BackButton

var dungeon_system: Node
var loot_system: Node
var selected_dungeon_id: String = ""
var selected_difficulty: String = ""

signal back_pressed

func _ready():
	# CRITICAL FIX: Remove any existing DungeonScreen instances before initializing this one
	var root = get_tree().root
	var dungeon_screens_to_remove = []
	
	# Find old DungeonScreen instances to remove (but not this current one)
	for child in root.get_children():
		if child != self and child.get_script() == self.get_script():
			dungeon_screens_to_remove.append(child)
	
	# Immediately remove old instances from scene tree
	for old_screen in dungeon_screens_to_remove:
		old_screen.queue_free()
	
	# Get dungeon system reference through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		# TODO: Get DungeonSystem through SystemRegistry when implemented
		print("DungeonScreen: SystemRegistry available, but DungeonSystem not yet registered")
		dungeon_system = null
	else:
		print("DungeonScreen: SystemRegistry not available")
		dungeon_system = null
	
	# Get LootSystem reference (optional - for enhanced loot display)
	if system_registry:
		loot_system = system_registry.get_system("LootSystem")
	
	# Connect UI signals with null checks
	if enter_button:
		enter_button.pressed.connect(_on_enter_button_pressed)
	else:
		print("DungeonScreen: WARNING - enter_button not found")
	
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	else:
		print("DungeonScreen: WARNING - back_button not found")
	
	# Initialize UI
	refresh_dungeon_list()
	update_schedule_info()
	
	# Hide info panel initially
	dungeon_info_panel.visible = false
	
	# Check if we need to refresh a previously selected dungeon
	_check_for_dungeon_refresh()

func refresh_dungeon_list():
	"""Refresh the list of available dungeons, organized by category"""
	
	# Clear all category lists
	clear_dungeon_lists()
	
	# TODO: Get available dungeons through SystemRegistry DungeonSystem
	# For now, show placeholder
	var placeholder_label = Label.new()
	placeholder_label.text = "Dungeons loading through SystemRegistry..."
	placeholder_label.custom_minimum_size = Vector2(200, 50)
	
	if elemental_dungeon_list:
		elemental_dungeon_list.add_child(placeholder_label)

func determine_dungeon_category(dungeon_info: Dictionary) -> String:
	"""Determine the category of a dungeon based on its properties"""
	var dungeon_id = dungeon_info.get("id", "")
	
	# Check if it's an equipment dungeon
	if dungeon_id.begins_with("titans_forge") or dungeon_id.begins_with("valhalla_armory") or \
	   dungeon_id.begins_with("oracle_sanctum") or dungeon_id.begins_with("elysian_fields") or \
	   dungeon_id.begins_with("styx_crossing"):
		return "equipment"
	
	# Check if it's a pantheon dungeon
	if dungeon_id.begins_with("greek_trials") or dungeon_id.begins_with("norse_trials") or \
	   dungeon_id.begins_with("egyptian_trials") or dungeon_id.begins_with("hindu_trials") or \
	   dungeon_id.begins_with("celtic_trials") or dungeon_id.begins_with("aztec_trials") or \
	   dungeon_id.begins_with("japanese_trials") or dungeon_id.begins_with("slavic_trials"):
		return "pantheon"
	
	# Default to elemental (includes fire, water, earth, lightning, light, dark, magic sanctums)
	return "elemental"

func clear_dungeon_lists():
	"""Clear all dungeon category lists"""
	var lists = [elemental_dungeon_list, pantheon_dungeon_list, equipment_dungeon_list]
	for dungeon_list in lists:
		if dungeon_list:
			for child in dungeon_list.get_children():
				dungeon_list.remove_child(child)
				child.queue_free()

func create_dungeon_button(dungeon_info: Dictionary, container: VBoxContainer):
	"""Create a button for a dungeon in the specified container"""
	var button = Button.new()
	var dungeon_id = dungeon_info.get("id", "")
	var dungeon_name = dungeon_info.get("name", "Unknown Dungeon")
	var element = dungeon_info.get("element", "")
	var category = determine_dungeon_category(dungeon_info)
	
	# Set button text and styling based on element/category
	button.text = dungeon_name
	button.custom_minimum_size = Vector2(300, 60)
	
	# Enhanced styling based on category and element
	match category:
		"elemental":
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
				"magic":
					button.modulate = Color.MAGENTA
				"neutral":
					button.modulate = Color.LIGHT_GRAY
				_:
					button.modulate = Color.WHITE
		"pantheon":
			button.modulate = Color.GOLD
		"equipment":
			button.modulate = Color.SILVER
		_:
			button.modulate = Color.WHITE
	
	# Connect button signal
	button.pressed.connect(_on_dungeon_selected.bind(dungeon_id))
	
	# Add to specified container
	container.add_child(button)

func _check_for_dungeon_refresh():
	"""Check if we need to refresh a previously selected dungeon (after battle completion)"""
	# Check if SystemRegistry has a last completed dungeon via temporary data storage
	var system_registry = SystemRegistry.get_instance()
	if system_registry.has_meta("last_dungeon_completed"):
		var last_dungeon = system_registry.get_meta("last_dungeon_completed")
		print("=== DungeonScreen: Auto-selecting last completed dungeon: %s ===" % last_dungeon)
		
		# Auto-select and show info for the last dungeon
		selected_dungeon_id = last_dungeon
		show_dungeon_info(last_dungeon)
		
		# Clear the meta to prevent auto-selection on future visits
		system_registry.remove_meta("last_dungeon_completed")

func _on_dungeon_selected(dungeon_id: String):
	"""Handle dungeon selection"""
	selected_dungeon_id = dungeon_id
	
	# Set appropriate default difficulty based on dungeon type
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	var available_difficulties = dungeon_info.get("difficulty_levels", {}).keys()
	
	if available_difficulties.has("beginner"):
		selected_difficulty = "beginner"  # Default to beginner for normal dungeons
	elif available_difficulties.has("heroic"):
		selected_difficulty = "heroic"    # Default to heroic for pantheon dungeons
	else:
		# Fallback to first available difficulty
		selected_difficulty = available_difficulties[0] if available_difficulties.size() > 0 else "beginner"
	
	# Show dungeon info
	show_dungeon_info(dungeon_id)

func show_dungeon_info(dungeon_id: String):
	"""Show detailed information about a dungeon"""
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return
	
	# Show the info panel
	dungeon_info_panel.visible = true
	
	# Update dungeon name and description
	dungeon_name_label.text = dungeon_info.get("name", "Unknown Dungeon")
	dungeon_description.text = dungeon_info.get("description", "No description available")
	
	# Create difficulty buttons
	update_difficulty_buttons(dungeon_id, dungeon_info)
	
	# Update rewards display with default difficulty (beginner)
	update_rewards_display(dungeon_id, selected_difficulty)
	
	# Show rewards for current difficulty
	update_rewards_display(dungeon_id, selected_difficulty)

func update_difficulty_buttons(dungeon_id: String, dungeon_info: Dictionary):
	"""Update difficulty selection buttons"""
	
	# Clear existing buttons properly - remove from scene tree immediately
	for child in difficulty_buttons.get_children():
		difficulty_buttons.remove_child(child)
		child.queue_free()
	
	var difficulties = dungeon_info.get("difficulty_levels", {})
	
	# Create a button group so only one can be selected at a time
	var button_group = ButtonGroup.new()
	
	for difficulty in difficulties.keys():
		var button = Button.new()
		button.text = difficulty.capitalize()
		button.toggle_mode = true
		button.button_group = button_group  # Add to button group
		
		# Check if difficulty is unlocked
		var unlocked = dungeon_system.is_difficulty_unlocked(dungeon_id, difficulty)
		
		button.disabled = not unlocked
		
		if not unlocked:
			# Show unlock progress for locked difficulties
			var unlock_info = dungeon_system.get_difficulty_unlock_requirements(dungeon_id, difficulty)
			button.text += "\n🔒 " + unlock_info.get("progress_text", "Locked")
			button.modulate = Color.GRAY
		else:
			# Show current clears for unlocked difficulties
			var clear_key = dungeon_id + "_" + difficulty
			var current_clears = dungeon_system.player_dungeon_progress.get("clear_counts", {}).get(clear_key, 0)
			if current_clears > 0:
				button.text += "\n✅ %d clears" % current_clears
			
			# Ensure unlocked buttons are properly styled
			button.modulate = Color.WHITE
		
		# Set default selection
		if difficulty == selected_difficulty:
			button.button_pressed = true
		
		# Connect primary signal for button functionality
		button.pressed.connect(_on_difficulty_button_pressed.bind(difficulty))
		
		difficulty_buttons.add_child(button)

func _on_difficulty_selected(difficulty: String, pressed: bool):
	"""Handle difficulty selection"""
	
	if not pressed:
		return
	
	selected_difficulty = difficulty
	
	# ButtonGroup handles unpressing other buttons automatically
	# Update rewards display
	update_rewards_display(selected_dungeon_id, difficulty)

func _on_difficulty_button_pressed(difficulty: String):
	"""Handle difficulty button press - main selection logic"""
	
	# Update selected difficulty
	selected_difficulty = difficulty
	
	# Manually handle button group selection - ensure only the clicked button is pressed
	for child in difficulty_buttons.get_children():
		if child is Button:
			child.button_pressed = (child.text.to_lower() == difficulty)
	
	# Update the rewards display immediately
	update_rewards_display(selected_dungeon_id, difficulty)

func update_rewards_display(dungeon_id: String, difficulty: String):
	"""Update the rewards display with detailed loot and enemy information"""
	# Clear existing rewards properly - remove from scene tree immediately
	for child in rewards_container.get_children():
		if child.name != "RewardsLabel":  # Keep the title label
			rewards_container.remove_child(child)
			child.queue_free()
	
	# Update the main title
	rewards_label.text = "%s - %s Difficulty" % [dungeon_id.replace("_", " ").capitalize(), difficulty.capitalize()]
	
	# Get dungeon info for enemy and stats
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	
	# Add difficulty stats
	var stats_label = RichTextLabel.new()
	stats_label.custom_minimum_size.y = 80
	stats_label.fit_content = true
	stats_label.bbcode_enabled = true
	stats_label.text = "[b]📊 Dungeon Stats:[/b]\n" + \
		"• Recommended Power: %s\n" % _format_number(difficulty_info.get("recommended_power", 0)) + \
		"• Energy Cost: %d\n" % difficulty_info.get("energy_cost", 0) + \
		"• Waves: %d\n" % difficulty_info.get("waves", 0) + \
		"• Boss: %s" % difficulty_info.get("boss", "Unknown")
	rewards_container.add_child(stats_label)
	
	# Add separator
	var separator1 = HSeparator.new()
	rewards_container.add_child(separator1)
	
	# Add loot information - FULLY MODULAR using actual JSON data
	var loot_table_name = _convert_dungeon_id_to_loot_table_name(dungeon_id, difficulty)
	
	# Use LootSystem to get actual reward preview
	var system_registry = SystemRegistry.get_instance()
	var loot_system_ref = system_registry.get_system("LootSystem")
	if loot_system_ref and loot_system_ref.has_method("get_loot_table_rewards_preview"):
		var rewards_preview = loot_system_ref.get_loot_table_rewards_preview(loot_table_name)
		if rewards_preview.size() > 0:
			var loot_label = RichTextLabel.new()
			loot_label.custom_minimum_size.y = 120
			loot_label.fit_content = true
			loot_label.bbcode_enabled = true
			
			var guaranteed_text = ""
			var rare_text = ""
			
			# Separate guaranteed from rare drops
			for reward_info in rewards_preview:
				var resource_name = reward_info.get("resource_name", "Unknown")
				var amount_text = reward_info.get("amount_text", "")
				var chance_text = reward_info.get("chance_text", "")
				
				var line = "• %s: %s\n" % [resource_name, amount_text]
				
				if chance_text == "Guaranteed":
					guaranteed_text += line
				else:
					rare_text += "• %s: %s (%s)\n" % [resource_name, amount_text, chance_text]
			
			var full_text = ""
			if guaranteed_text != "":
				full_text += "[b]💰 Guaranteed Rewards:[/b]\n" + guaranteed_text
			if rare_text != "":
				if full_text != "":
					full_text += "\n"
				full_text += "[b]🎲 Rare Drops:[/b]\n" + rare_text
			
			loot_label.text = full_text
			rewards_container.add_child(loot_label)
		else:
			var no_loot_label = Label.new()
			no_loot_label.text = "⚠️ No reward data found for: " + loot_table_name
			rewards_container.add_child(no_loot_label)
	else:
		var fallback_label = Label.new()
		fallback_label.text = "⚠️ Loot system not available"
		rewards_container.add_child(fallback_label)
	
	# Add separator
	var separator2 = HSeparator.new()
	rewards_container.add_child(separator2)
	
	# Add enemy preview (simplified)
	var enemy_label = RichTextLabel.new()
	enemy_label.custom_minimum_size.y = 60
	enemy_label.fit_content = true
	enemy_label.bbcode_enabled = true
	enemy_label.text = "[b]👹 Enemy Information:[/b]\n" + \
		"• Element: %s\n" % dungeon_info.get("element", "Unknown").capitalize() + \
		"• Guardian Spirit: %s\n" % dungeon_info.get("guardian_spirit", "Unknown") + \
		"• Boss: %s" % difficulty_info.get("boss", "Unknown")
	rewards_container.add_child(enemy_label)

func _convert_dungeon_id_to_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Convert dungeon ID to the correct loot table name"""
	var base_name = dungeon_id
	
	# Convert sanctum names to dungeon names for loot tables
	if dungeon_id.ends_with("_sanctum"):
		base_name = dungeon_id.replace("_sanctum", "_dungeon")
	
	# Handle special mappings for other dungeon types
	match dungeon_id:
		"magic_sanctum":
			return "magic_dungeon"  # Hall of Magic uses generic table (no difficulty suffix)
		"titans_forge", "valhalla_armory", "oracle_sanctum", "elysian_fields", "styx_crossing":
			return "equipment_dungeon"  # All equipment dungeons use generic table
		_:
			# For trial dungeons, keep the original name
			if dungeon_id.ends_with("_trials"):
				base_name = dungeon_id
				# Pantheon trials only have heroic and legendary difficulties in loot tables
				# Map beginner/intermediate/advanced/expert/master to heroic, and everything else to legendary
				if difficulty in ["beginner", "intermediate", "advanced", "expert", "master"]:
					return base_name + "_heroic"
				else:
					return base_name + "_legendary"
	
	return base_name + "_" + difficulty

func _get_readable_item_name(item: Dictionary) -> String:
	"""Convert item type to readable name using ResourceManager"""
	var item_type = item.get("type", "")
	var element = item.get("specific_element", "")
	
	# Check if ResourceManager is available
	var resource_manager = null
	var system_registry = SystemRegistry.get_instance()
	resource_manager = system_registry.get_system("ResourceManager")
	
	if not resource_manager:
		# Fallback to basic formatting if ResourceManager not available
		if element and item_type.begins_with("powder"):
			var tier_suffix = ""
			if item_type.ends_with("_low"):
				tier_suffix = " (Low)"
			elif item_type.ends_with("_mid"):
				tier_suffix = " (Mid)"
			elif item_type.ends_with("_high"):
				tier_suffix = " (High)"
			return "%s Powder%s" % [element.capitalize(), tier_suffix]
		elif element and item_type == "crystals":
			return "%s Crystals" % element.capitalize()
		else:
			return item_type.capitalize().replace("_", " ")
	
	# For items with specific elements, construct the full resource ID
	if element and item_type.begins_with("powder"):
		var full_resource_id = element + "_" + item_type
		var resource_info = resource_manager.get_resource_info(full_resource_id)
		return resource_info.get("name", full_resource_id.capitalize().replace("_", " "))
	elif element and item_type == "crystals":
		var full_resource_id = element + "_crystals"
		var resource_info = resource_manager.get_resource_info(full_resource_id)
		return resource_info.get("name", ("%s Crystals" % element.capitalize()))
	else:
		# Use ResourceManager for standard resources
		var resource_info = resource_manager.get_resource_info(item_type)
		return resource_info.get("name", item_type.capitalize().replace("_", " "))

func _get_amount_text(item: Dictionary) -> String:
	"""Get amount text for an item"""
	var min_amt = item.get("min_amount", 1)
	var max_amt = item.get("max_amount", 1)
	
	if min_amt == max_amt:
		return str(min_amt)
	else:
		return "%d-%d" % [min_amt, max_amt]

func _format_number(number: float) -> String:
	"""Format large numbers with K/M suffixes"""
	if number >= 1000000:
		return "%.1fM" % (number / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (number / 1000.0)
	else:
		return str(int(number))

func _on_enter_button_pressed():
	"""Handle enter dungeon button press"""
	print("=== DEBUG: Enter button pressed ===")
	print("  selected_dungeon_id: '%s'" % selected_dungeon_id)
	print("  selected_difficulty: '%s'" % selected_difficulty)
	
	if selected_dungeon_id == "" or selected_difficulty == "":
		show_error_message("Please select a dungeon and difficulty")
		print("  ERROR: Missing dungeon or difficulty selection")
		return
	
	# Check if player has gods
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager or collection_manager.get_all_gods().size() == 0:
		show_error_message("You need at least one god to enter a dungeon")
		print("  ERROR: No gods available")
		return
	
	print("  All checks passed, opening battle setup...")
	# Open BattleSetupScreen for team selection
	open_battle_setup_screen()

func open_battle_setup_screen():
	"""Open the universal battle setup screen for dungeons"""
	# Load battle setup scene
	var setup_scene = load("res://scenes/BattleSetupScreen.tscn")
	var setup_screen = setup_scene.instantiate()
	
	# Setup for dungeon battle
	print("=== DEBUG: Setting up battle with dungeon_id='%s', difficulty='%s' ===" % [selected_dungeon_id, selected_difficulty])
	setup_screen.setup_for_dungeon_battle(selected_dungeon_id, selected_difficulty)
	
	# Connect signals
	setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)
	setup_screen.setup_cancelled.connect(_on_battle_setup_cancelled)
	
	# Add to scene tree
	get_tree().root.add_child(setup_screen)

func _on_battle_setup_complete(context: Dictionary):
	"""Handle battle setup completion"""
	var team = context.get("team", [])
	var dungeon_id = context.get("dungeon_id", "")
	var difficulty = context.get("difficulty", "")
	
	if team.size() == 0:
		show_error_message("No team selected")
		return
	
	# Remove setup screen
	var setup_screen = get_tree().get_nodes_in_group("battle_setup")[0] if get_tree().get_nodes_in_group("battle_setup").size() > 0 else null
	if setup_screen:
		setup_screen.queue_free()
	
	# Check energy and validate battle (without starting it)
	var validation_result = dungeon_system.validate_dungeon_attempt(dungeon_id, difficulty, team)
	
	if not validation_result.success:
		show_error_message(validation_result.error_message)
		return
	
	# Spend energy now
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager and resource_manager.has_method("spend_energy"):
		resource_manager.spend_energy(validation_result.energy_cost)
	
	# Save game after spending energy (handled by ResourceManager internally)
	# SystemRegistry systems handle their own persistence
	
	# Switch directly to BattleScreen with complete context
	_switch_to_battle_screen_with_context(context)

func _switch_to_battle_screen_with_context(context: Dictionary):
	"""Switch to BattleScreen with complete battle context"""
	print("=== DungeonScreen: Switching to BattleScreen with context ===")
	print("=== DEBUG: Current DungeonScreen instance ID before transition: ", get_instance_id())
	
	# Store battle context in SystemRegistry for the new scene to pick up
	var system_registry = SystemRegistry.get_instance()
	system_registry.set_meta("pending_battle_context", context)
	
	# Simple scene transition - let the BattleScreen pick up the context in _ready()
	get_tree().change_scene_to_file("res://scenes/BattleScreen.tscn")

func _on_battle_setup_cancelled():
	"""Handle battle setup cancellation"""
	# Remove setup screen
	var setup_screen = get_tree().get_nodes_in_group("battle_setup")[0] if get_tree().get_nodes_in_group("battle_setup").size() > 0 else null
	if setup_screen:
		setup_screen.queue_free()

func _on_dungeon_completed(_dungeon_id: String, _difficulty: String, rewards: Dictionary):
	"""Handle dungeon completion"""
	var message = "Dungeon completed!\nRewards:\n"
	for reward_type in rewards:
		message += "• " + reward_type + ": " + str(rewards[reward_type]) + "\n"
	
	show_success_message(message)

func _on_dungeon_failed(_dungeon_id: String, _difficulty: String):
	"""Handle dungeon failure"""
	show_error_message("Dungeon failed! Your team wasn't strong enough.")

func show_error_message(message: String):
	"""Show error popup"""
	# In a real implementation, you'd create a proper dialog
	print("Error: " + message)
	
	# Simple notification (replace with proper UI)
	var error_label = Label.new()
	error_label.text = message
	error_label.modulate = Color.RED
	error_label.position = Vector2(100, 100)
	get_parent().add_child(error_label)
	
	# Remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(error_label):
		error_label.queue_free()

func show_success_message(message: String):
	"""Show success popup"""
	print("Success: " + message)
	
	# Simple notification (replace with proper UI)
	var success_label = Label.new()
	success_label.text = message
	success_label.modulate = Color.GREEN
	success_label.position = Vector2(100, 150)
	get_parent().add_child(success_label)
	
	# Remove after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(success_label):
		success_label.queue_free()

func update_schedule_info():
	"""Update the schedule information display"""
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

func _on_back_button_pressed():
	"""Handle back button press"""
	print("=== DungeonScreen: Back button pressed ===")
	print("=== DEBUG: back_pressed signal connected count: ", get_signal_connection_list("back_pressed").size())
	back_pressed.emit()
	print("=== DungeonScreen: back_pressed signal emitted ===")

	# Fallback: if no connections, navigate to MainUI or WorldView manually
	if get_signal_connection_list("back_pressed").size() == 0:
		print("=== DungeonScreen: No back_pressed connections, navigating manually ===")
		var world_view = get_node_or_null("/root/Main/WorldView")
		if world_view:
			world_view.visible = true
			queue_free()
		else:
			# Try to go to main scene as fallback
			get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Called when the node enters the scene tree
func _enter_tree():
	# ALWAYS use SystemRegistry's dungeon system - never create a new one
	var system_registry = SystemRegistry.get_instance()
	dungeon_system = system_registry.get_system("DungeonSystem")
	if not dungeon_system:
		print("ERROR: DungeonSystem not available in SystemRegistry")
		# Don't create a new instance - this breaks data persistence
		return
