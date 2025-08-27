# scripts/ui/components/DungeonEntryManager.gd
# Single responsibility: Handle dungeon entry validation and execution
class_name DungeonEntryManager extends Node

# Entry manager signals
signal entry_validated(can_enter: bool, validation_message: String)
signal dungeon_entry_started(dungeon_id: String, difficulty: String)
signal dungeon_completed(dungeon_id: String, difficulty: String, rewards: Dictionary)
signal dungeon_failed(dungeon_id: String, difficulty: String)

var parent_screen: Control

func initialize(screen_parent: Control):
	"""Initialize with parent screen"""
	parent_screen = screen_parent
	print("DungeonEntryManager: Initialized")

func attempt_dungeon_entry(dungeon_id: String, difficulty: String):
	"""Attempt to enter dungeon with validation - RULE 5: Use SystemRegistry"""
	print("DungeonEntryManager: Attempting entry to %s (%s)" % [dungeon_id, difficulty])
	
	# Validate entry requirements
	var validation_result = validate_dungeon_entry(dungeon_id, difficulty)
	
	if not validation_result.can_enter:
		entry_validated.emit(false, validation_result.message)
		show_validation_error(validation_result.message)
		return
	
	# Entry is valid, proceed
	entry_validated.emit(true, "Ready to enter dungeon!")
	start_dungeon_battle(dungeon_id, difficulty)

func validate_dungeon_entry(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Validate if player can enter dungeon - RULE 5: SystemRegistry access only"""
	var result = {
		"can_enter": false,
		"message": "Validation failed"
	}
	
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		result.message = "System not available"
		return result
	
	# Check player team
	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		result.message = "CollectionManager not found"
		return result
	
	var available_gods = collection_manager.get_all_gods()
	if available_gods.is_empty():
		result.message = "You need at least one god to enter a dungeon!"
		return result
	
	# Check energy requirements
	var resource_manager = system_registry.get_system("ResourceManager")
	if resource_manager:
		var energy_cost = get_energy_cost(dungeon_id, difficulty)
		if not resource_manager.can_spend("energy", energy_cost):
			result.message = "Not enough energy! Need %d energy." % energy_cost
			return result
	
	# All checks passed
	result.can_enter = true
	result.message = "Ready to enter!"
	return result

func get_energy_cost(_dungeon_id: String, difficulty: String) -> int:
	"""Calculate energy cost for dungeon entry"""
	var base_cost = 10
	
	# Difficulty multiplier
	match difficulty.to_lower():
		"hard": base_cost *= 2
		"hell", "nightmare": base_cost *= 3
	
	return base_cost

func start_dungeon_battle(dungeon_id: String, difficulty: String):
	"""Start the dungeon battle - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("DungeonEntryManager: SystemRegistry not available")
		return
	
	# Get necessary systems
	var dungeon_manager = system_registry.get_system("DungeonManager")
	var collection_manager = system_registry.get_system("CollectionManager")
	
	if not dungeon_manager or not collection_manager:
		print("DungeonEntryManager: Required systems not found")
		return
	
	# Prepare player team (simplified - first 5 gods)
	var player_team = prepare_player_team(collection_manager)
	
	# Spend energy
	spend_energy_for_entry(dungeon_id, difficulty)
	
	# Start dungeon battle through dungeon manager
	var battle_result = dungeon_manager.start_dungeon_battle(dungeon_id, difficulty, player_team)
	
	dungeon_entry_started.emit(dungeon_id, difficulty)
	
	# Handle battle result (simplified for now)
	handle_battle_result(dungeon_id, difficulty, battle_result)

func prepare_player_team(collection_manager) -> Array:
	"""Prepare player team for dungeon - RULE 5: SystemRegistry data only"""
	var available_gods = collection_manager.get_all_gods()
	var team = []
	
	# Take first 5 gods (simplified team selection)
	var god_count = min(5, available_gods.size())
	for i in god_count:
		team.append(available_gods[i])
	
	return team

func spend_energy_for_entry(dungeon_id: String, difficulty: String):
	"""Spend energy for dungeon entry - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if resource_manager:
		var energy_cost = get_energy_cost(dungeon_id, difficulty)
		resource_manager.spend("energy", energy_cost)

func handle_battle_result(dungeon_id: String, difficulty: String, battle_result: Dictionary):
	"""Handle the result of dungeon battle"""
	# Simplified battle result handling
	var success = battle_result.get("success", false)
	
	if success:
		var rewards = battle_result.get("rewards", {})
		show_victory_message(dungeon_id, rewards)
		dungeon_completed.emit(dungeon_id, difficulty, rewards)
	else:
		show_failure_message(dungeon_id)
		dungeon_failed.emit(dungeon_id, difficulty)

func show_validation_error(message: String):
	"""Show validation error dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Cannot Enter Dungeon"
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 14)
	
	# Style the dialog
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.1, 0.1, 0.95)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_victory_message(dungeon_id: String, rewards: Dictionary):
	"""Show victory message with rewards"""
	var reward_text = ""
	if not rewards.is_empty():
		reward_text = "\n\nRewards obtained:"
		for reward_type in rewards:
			reward_text += "\n• %s: %s" % [reward_type.capitalize(), rewards[reward_type]]
	
	var message = "🎉 Dungeon Completed!\n\nYou have successfully cleared %s!%s" % [
		dungeon_id.replace("_", " ").capitalize(),
		reward_text
	]
	
	var dialog = AcceptDialog.new()
	dialog.title = "Victory!"
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 14)
	
	# Style with green success color
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.2, 0.1, 0.95)
	panel_style.border_color = Color.GREEN
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_failure_message(dungeon_id: String):
	"""Show failure message"""
	var message = "💀 Dungeon Failed\n\nYour team was defeated in %s.\nBetter luck next time!" % [
		dungeon_id.replace("_", " ").capitalize()
	]
	
	var dialog = AcceptDialog.new()
	dialog.title = "Defeat"
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 14)
	
	# Style with red failure color
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.1, 0.1, 0.95)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
