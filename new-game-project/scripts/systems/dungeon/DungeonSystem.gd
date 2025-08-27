# scripts/systems/DungeonSystem.gd
extends Node
class_name DungeonSystem

signal dungeon_completed(dungeon_id: String, difficulty: String, rewards: Dictionary)
signal dungeon_failed(dungeon_id: String, difficulty: String)
signal dungeon_unlocked(dungeon_id: String)

var dungeon_data: Dictionary = {}
var player_dungeon_progress: Dictionary = {}
var battle_in_progress: bool = false
var current_battle_scene_path: String = ""
var _stored_battle_data: Dictionary = {}  # Store battle data during scene transitions

func _ready():
	load_dungeon_data()
	initialize_player_progress()
	
	# NOTE: Don't connect to battle completion signals anymore
	# The new clean architecture has BattleScreen handle completion directly
	# Old approach was causing double completion handling

func load_dungeon_data():
	"""Load dungeon definitions from dungeons.json"""
	var file_path = "res://data/dungeons.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Warning: Could not open dungeons.json - dungeon system disabled")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing dungeons.json: ", json.error_string)
		return
	
	dungeon_data = json.get_data()
	var all_dungeons = get_all_dungeons()
	print("Loaded ", all_dungeons.size(), " dungeons")
	
	# Debug: Print all dungeon categories
	var elemental = dungeon_data.get("elemental_dungeons", {}).size()
	var special = dungeon_data.get("special_dungeons", {}).size() 
	var pantheon = dungeon_data.get("pantheon_dungeons", {}).size()
	var equipment = dungeon_data.get("equipment_dungeons", {}).size()
	print("  - Elemental: ", elemental)
	print("  - Special: ", special)
	print("  - Pantheon: ", pantheon)
	print("  - Equipment: ", equipment)

func initialize_player_progress():
	"""Initialize player's dungeon progress tracking"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if not resource_manager:
		return
	
	# Load from save file or initialize
	player_dungeon_progress = {
		"unlocked_dungeons": [],
		"difficulty_unlocks": {},
		"clear_counts": {},
		"best_times": {},
		"total_clears": 0
	}

func get_available_dungeons_today() -> Array:
	"""Get list of dungeons available today based on schedule"""
	var available = []
	var added_dungeon_ids = {}  # Track already added dungeons to prevent duplicates
	var current_day = Time.get_datetime_dict_from_system().weekday
	var day_names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
	var today = day_names[current_day]
	
	# Always available dungeons
	var always_available = dungeon_data.get("dungeon_schedule", {}).get("always_available", [])
	for dungeon_id in always_available:
		if is_dungeon_unlocked(dungeon_id) and not added_dungeon_ids.has(dungeon_id):
			var dungeon_info = get_dungeon_info(dungeon_id)
			if not dungeon_info.is_empty():
				available.append(dungeon_info)
				added_dungeon_ids[dungeon_id] = true
	
	# Daily rotation dungeons (only add if not already added)
	var daily_rotation = dungeon_data.get("dungeon_schedule", {}).get("daily_rotation", {})
	if daily_rotation.has(today):
		for dungeon_id in daily_rotation[today]:
			if is_dungeon_unlocked(dungeon_id) and not added_dungeon_ids.has(dungeon_id):
				var dungeon_info = get_dungeon_info(dungeon_id)
				if not dungeon_info.is_empty():
					available.append(dungeon_info)
					added_dungeon_ids[dungeon_id] = true
	
	return available

func get_dungeon_info(dungeon_id: String) -> Dictionary:
	"""Get complete dungeon information"""
	# Check elemental dungeons
	var elemental_dungeons = dungeon_data.get("elemental_dungeons", {})
	if elemental_dungeons.has(dungeon_id):
		return elemental_dungeons[dungeon_id]
	
	# Check special dungeons
	var special_dungeons = dungeon_data.get("special_dungeons", {})
	if special_dungeons.has(dungeon_id):
		return special_dungeons[dungeon_id]
	
	# Check pantheon dungeons
	var pantheon_dungeons = dungeon_data.get("pantheon_dungeons", {})
	if pantheon_dungeons.has(dungeon_id):
		return pantheon_dungeons[dungeon_id]
	
	# Check equipment dungeons
	var equipment_dungeons = dungeon_data.get("equipment_dungeons", {})
	if equipment_dungeons.has(dungeon_id):
		return equipment_dungeons[dungeon_id]
	
	return {}

func is_dungeon_unlocked(dungeon_id: String) -> bool:
	"""Check if player has unlocked a specific dungeon"""
	if not GameManager or not GameManager.player_data:
		return false
	
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return false
	
	# Check unlock requirements based on dungeon category
	var unlock_requirements = dungeon_info.get("unlock_requirement", {})
	
	# Player level check
	if unlock_requirements.has("player_level"):
		var required_level = unlock_requirements.player_level
		var player_level = GameManager.progression_manager.calculate_level_from_experience(GameManager.player_data.player_experience) if GameManager.progression_manager else 1
		if player_level < required_level:
			return false
	
	# Legendary gods owned check
	if unlock_requirements.has("legendary_gods_owned"):
		var legendary_count = GameManager.player_data.get_gods_by_tier(4).size()  # 4 = LEGENDARY tier
		var required_count = unlock_requirements.legendary_gods_owned
		if legendary_count < required_count:
			return false
	
	# Territories completed check
	if unlock_requirements.has("territories_completed"):
		var territories_count = GameManager.player_data.controlled_territories.size()
		var required_territories = unlock_requirements.territories_completed
		if territories_count < required_territories:
			return false
	
	return true

func is_difficulty_unlocked(dungeon_id: String, difficulty: String) -> bool:
	"""Check if specific difficulty is unlocked for a dungeon"""
	var progression = dungeon_data.get("progression_system", {}).get("difficulty_unlock", {})
	var requirement_data = progression.get(difficulty, "always_unlocked")
	
	# Handle different data structures in the JSON
	var requirement_str = ""
	if typeof(requirement_data) == TYPE_STRING:
		requirement_str = requirement_data
	elif typeof(requirement_data) == TYPE_DICTIONARY:
		requirement_str = requirement_data.get("requirement", "always_unlocked")
	else:
		requirement_str = "always_unlocked"
	
	if requirement_str == "always_unlocked":
		return true
	
	# Special handling for pantheon dungeons which only have heroic and legendary
	if dungeon_id.ends_with("_trials"):
		if difficulty == "heroic":
			# Heroic is always unlocked for trials (they're already high-level content)
			return true
		elif difficulty == "legendary":
			# Legendary requires heroic clears
			var clear_key = dungeon_id + "_heroic"
			var required_clears = extract_clear_count_from_requirement("heroic_cleared_15_times")  # from JSON
			var current_clears = player_dungeon_progress.get("clear_counts", {}).get(clear_key, 0)
			return current_clears >= required_clears
	
	# Standard difficulty progression for elemental/equipment dungeons
	var clear_key = dungeon_id + "_" + get_previous_difficulty(difficulty)
	var required_clears = extract_clear_count_from_requirement(requirement_str)
	var current_clears = player_dungeon_progress.get("clear_counts", {}).get(clear_key, 0)
	
	return current_clears >= required_clears

func get_previous_difficulty(difficulty: String) -> String:
	"""Get the previous difficulty tier"""
	match difficulty:
		"intermediate": return "beginner"
		"advanced": return "intermediate"
		"expert": return "advanced"
		"master": return "expert"
		"heroic": return "master"
		"legendary": return "heroic"
		_: return "beginner"

func extract_clear_count_from_requirement(requirement: String) -> int:
	"""Extract required clear count from requirement string"""
	# Parse strings like "beginner_cleared_10_times"
	if "_cleared_" in requirement and "_times" in requirement:
		var parts = requirement.split("_cleared_")
		if parts.size() >= 2:
			var count_part = parts[1].replace("_times", "")
			return int(count_part)
	return 0

func attempt_dungeon(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	"""Attempt to enter and complete a dungeon"""
	var result = {
		"success": false,
		"rewards": {},
		"error_message": ""
	}
	
	# Validation checks
	if not is_dungeon_unlocked(dungeon_id):
		result.error_message = "Dungeon not unlocked"
		return result
	
	if not is_difficulty_unlocked(dungeon_id, difficulty):
		result.error_message = "Difficulty not unlocked"
		return result
	
	var dungeon_info = get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	
	if difficulty_info.is_empty():
		result.error_message = "Invalid difficulty"
		return result
	
	# Energy check
	var energy_cost = difficulty_info.get("energy_cost", 8)
	if not GameManager.player_data.can_afford_energy(energy_cost):
		result.error_message = "Insufficient energy"
		return result
	
	# Team validation
	if team.size() == 0 or team.size() > 4:
		result.error_message = "Invalid team size (1-4 gods required)"
		return result
	
	# Start real dungeon battle first (before spending energy)
	var battle_started = start_dungeon_battle(dungeon_id, difficulty, team)
	
	if battle_started:
		# Battle started successfully - now spend energy and save
		GameManager.player_data.spend_energy(energy_cost)
		GameManager.save_game()  # Immediately save energy consumption
		
		# Battle has started - don't complete dungeon yet
		# Wait for battle_completed signal from BattleManager
		result.success = true  # Battle started successfully
		result.rewards = {}    # No rewards yet - will be awarded when battle completes
	else:
		# Battle failed to start - don't spend energy
		result.success = false
		result.error_message = "Failed to start battle"
		dungeon_failed.emit(dungeon_id, difficulty)
	
	return result

func validate_dungeon_attempt(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	"""Validate if a dungeon attempt can proceed (without starting battle)"""
	var result = {
		"success": false,
		"error_message": "",
		"energy_cost": 0
	}
	
	# Check if dungeon exists
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		result.error_message = "Dungeon not found: " + str(dungeon_id)
		return result
	
	# Check if difficulty is unlocked
	if not is_difficulty_unlocked(dungeon_id, difficulty):
		result.error_message = "Difficulty %s is not unlocked for %s" % [difficulty, dungeon_id]
		return result
	
	# Get energy cost
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	var energy_cost = int(difficulty_info.get("energy_cost", 8))
	result.energy_cost = energy_cost
	
	# Check energy
	if not GameManager.player_data.can_afford_energy(energy_cost):
		result.error_message = "Not enough energy (need %d, have %d)" % [energy_cost, GameManager.player_data.energy]
		return result
	
	# Team validation
	if team.size() == 0 or team.size() > 4:
		result.error_message = "Invalid team size (1-4 gods required)"
		return result
	
	result.success = true
	return result

func start_dungeon_battle(dungeon_id: String, difficulty: String, team: Array) -> bool:
	"""Start real battle using BattleManager and EnemyFactory"""
	
	# Prevent double battle screen creation
	if battle_in_progress:
		return false
	
	# Check if we're already on the battle screen
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.get_script() and current_scene.get_script().get_path().ends_with("BattleScreen.gd"):
		battle_in_progress = true
		current_dungeon_id = dungeon_id
		current_dungeon_difficulty = difficulty
		
		if current_scene.has_method("setup_dungeon_battle"):
			current_scene.setup_dungeon_battle(dungeon_id, difficulty, team)
			return true
		else:
			print("Warning: Battle screen doesn't have setup_dungeon_battle method")
			battle_in_progress = false
			return false
	
	# Mark battle as starting
	battle_in_progress = true
	
	# Store current dungeon info for completion handler
	current_dungeon_id = dungeon_id
	current_dungeon_difficulty = difficulty
	
	# Create dungeon enemies using EnemyFactory
	var enemies = EnemyFactory.create_enemies_for_dungeon(dungeon_id, difficulty)
	
	if enemies.is_empty():
		print("Failed to create enemies for dungeon - falling back to simulation")
		var dungeon_info = get_dungeon_info(dungeon_id)
		var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		var sim_result = simulate_dungeon_battle(dungeon_info, difficulty_info, team)
		
		# Handle simulation result immediately
		if sim_result:
			var rewards = award_dungeon_rewards(dungeon_id, difficulty)
			update_dungeon_progress(dungeon_id, difficulty)
			dungeon_completed.emit(dungeon_id, difficulty, rewards)
		else:
			dungeon_failed.emit(dungeon_id, difficulty)
		
		return sim_result
	
	# Use BattleManager for real combat with wave system
	if GameManager and GameManager.battle_system:
		print("Starting wave-based dungeon battle")
		
		# Setup wave system for this dungeon
		var wave_system = GameManager.get_wave_system()
		if wave_system:
			wave_system.setup_waves_for_dungeon(dungeon_id, difficulty)
		
		# First switch to the BattleScreen, then start the battle
		# Store battle data for after scene transition
		_stored_battle_data = {
			"team": team,
			"dungeon_id": dungeon_id, 
			"difficulty": difficulty,
			"enemies": enemies
		}
		
		# Switch to BattleScreen first
		_open_battle_screen_for_dungeon(dungeon_id, difficulty, team)
		
		return true
	else:
		print("BattleManager not available - using simulation")
		var dungeon_info = get_dungeon_info(dungeon_id)
		var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		var sim_result = simulate_dungeon_battle(dungeon_info, difficulty_info, team)
		
		# Handle simulation result immediately
		if sim_result:
			var rewards = award_dungeon_rewards(dungeon_id, difficulty)
			update_dungeon_progress(dungeon_id, difficulty)
			dungeon_completed.emit(dungeon_id, difficulty, rewards)
		else:
			dungeon_failed.emit(dungeon_id, difficulty)
		
		return sim_result

func reset_battle_state():
	"""Reset dungeon battle state - call when battle is cancelled or interrupted"""
	print("=== DungeonSystem: Resetting battle state ===")
	battle_in_progress = false
	current_dungeon_id = ""
	current_dungeon_difficulty = ""
	_stored_battle_data.clear()

func simulate_dungeon_battle(_dungeon_info: Dictionary, difficulty_info: Dictionary, team: Array) -> bool:
	"""Simulate the dungeon battle - simplified for now"""
	var team_power = calculate_team_power(team)
	var recommended_power = difficulty_info.get("recommended_power", 5000)
	
	# Simple power-based success calculation
	var success_chance = min(team_power / float(recommended_power), 2.0) * 0.8
	
	# Add some randomness
	success_chance += randf() * 0.2
	
	return randf() < success_chance

func calculate_team_power(team: Array) -> int:
	"""Calculate total team power"""
	var total_power = 0
	for god in team:
		if god != null:
			total_power += god.get_power_rating()
	return total_power

func award_dungeon_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Award loot from dungeon completion"""
	var loot_table_name = get_loot_table_name(dungeon_id, difficulty)
	
	if GameManager.has_method("get_loot_system"):
		var loot_system = GameManager.get_loot_system()
		if loot_system:
			return loot_system.award_loot(loot_table_name)
	
	return {}

func get_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Generate loot table name from dungeon ID and difficulty"""
	# Convert dungeon_id like "fire_sanctum" to "fire_dungeon_beginner"
	var element = ""
	if "_sanctum" in dungeon_id:
		element = dungeon_id.replace("_sanctum", "")
		return element + "_dungeon_" + difficulty
	elif dungeon_id == "magic_sanctum":
		return "magic_dungeon_" + difficulty
	elif "_trials" in dungeon_id:
		var pantheon = dungeon_id.replace("_trials", "")
		return pantheon + "_trials_" + difficulty
	
	return dungeon_id + "_" + difficulty

func update_dungeon_progress(dungeon_id: String, difficulty: String):
	"""Update player's dungeon progress"""
	var clear_key = dungeon_id + "_" + difficulty
	
	if not player_dungeon_progress.has("clear_counts"):
		player_dungeon_progress["clear_counts"] = {}
	
	var current_clears = player_dungeon_progress.clear_counts.get(clear_key, 0)
	player_dungeon_progress.clear_counts[clear_key] = current_clears + 1
	player_dungeon_progress.total_clears += 1
	
	# Check if new difficulties are unlocked
	check_difficulty_unlocks(dungeon_id)
	
	# Save progress immediately
	if GameManager:
		GameManager.save_game()
	else:
		print("ERROR: GameManager not found for saving dungeon progress")

func debug_complete_sanctum():
	"""Debug function to manually complete Sanctum of Radiance and check unlocks"""
	
	# Complete sanctum on beginner difficulty
	var result = complete_dungeon_manually("light_sanctum", "beginner")
	
	# Check if intermediate is now unlocked
	var is_unlocked = is_difficulty_unlocked("light_sanctum", "intermediate")
	
	# Show progress info
	var progress = get_dungeon_progress_info("light_sanctum")
	
	return result

func complete_dungeon_manually(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Manually complete a dungeon - useful for fixing completion tracking issues"""
	
	# Award rewards
	var rewards = award_dungeon_rewards(dungeon_id, difficulty)
	
	# Update progress
	update_dungeon_progress(dungeon_id, difficulty)
	
	# Emit completion signal
	dungeon_completed.emit(dungeon_id, difficulty, rewards)
	
	return {
		"success": true,
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"rewards": rewards
	}

func get_dungeon_progress_info(dungeon_id: String = "") -> Dictionary:
	"""Get current dungeon progress information for debugging"""
	if dungeon_id.is_empty():
		return {
			"total_clears": player_dungeon_progress.get("total_clears", 0),
			"all_clear_counts": player_dungeon_progress.get("clear_counts", {}),
			"unlocked_dungeons": player_dungeon_progress.get("unlocked_dungeons", []),
			"difficulty_unlocks": player_dungeon_progress.get("difficulty_unlocks", {})
		}
	else:
		var clear_counts_for_dungeon = {}
		var all_clears = player_dungeon_progress.get("clear_counts", {})
		for key in all_clears.keys():
			if key.begins_with(dungeon_id + "_"):
				clear_counts_for_dungeon[key] = all_clears[key]
		
		return {
			"dungeon_id": dungeon_id,
			"clear_counts": clear_counts_for_dungeon,
			"unlocked_difficulties": get_unlocked_difficulties_for_dungeon(dungeon_id)
		}

func get_unlocked_difficulties_for_dungeon(dungeon_id: String) -> Array:
	"""Get list of unlocked difficulties for a specific dungeon"""
	var unlocked = ["beginner"]  # Beginner is always unlocked
	var difficulties = ["intermediate", "advanced", "expert", "master", "heroic", "legendary"]
	
	for difficulty in difficulties:
		if is_difficulty_unlocked(dungeon_id, difficulty):
			unlocked.append(difficulty)
	
	return unlocked

func check_difficulty_unlocks(dungeon_id: String):
	"""Check and unlock new difficulties for a dungeon"""
	var difficulties = ["intermediate", "advanced", "expert", "master", "heroic", "legendary"]
	
	for difficulty in difficulties:
		# Always do a fresh check regardless of current state
		var now_unlocked = _check_difficulty_unlock_fresh(dungeon_id, difficulty)
		var was_unlocked_before = is_difficulty_unlocked(dungeon_id, difficulty)
		
		if not was_unlocked_before and now_unlocked:
			# Show notification to player
			if GameManager and GameManager.player_data:
				var dungeon_info = get_dungeon_info(dungeon_id)
				var dungeon_name = dungeon_info.get("name", dungeon_id.capitalize().replace("_", " "))
				var message = "New difficulty unlocked!\n%s - %s" % [dungeon_name, difficulty.capitalize()]
				print("NOTIFICATION: %s" % message)
				# TODO: Show this in UI notification system

func _check_difficulty_unlock_fresh(dungeon_id: String, difficulty: String) -> bool:
	"""Fresh check of difficulty unlock (bypasses any caching)"""
	var progression = dungeon_data.get("progression_system", {}).get("difficulty_unlock", {})
	var requirement_data = progression.get(difficulty, "always_unlocked")
	
	# Handle different data structures in the JSON
	var requirement_str = ""
	if typeof(requirement_data) == TYPE_STRING:
		requirement_str = requirement_data
	elif typeof(requirement_data) == TYPE_DICTIONARY:
		requirement_str = requirement_data.get("requirement", "always_unlocked")
	else:
		requirement_str = "always_unlocked"
	
	if requirement_str == "always_unlocked":
		return true
	
	# Check clear count requirements
	var previous_difficulty = get_previous_difficulty(difficulty)
	var clear_key = dungeon_id + "_" + previous_difficulty
	var required_clears = extract_clear_count_from_requirement(requirement_str)
	var current_clears = player_dungeon_progress.get("clear_counts", {}).get(clear_key, 0)
	
	return current_clears >= required_clears

func get_difficulty_unlock_requirements(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get information about what's needed to unlock a difficulty"""
	var info = {
		"is_unlocked": false,
		"requirement_text": "",
		"progress_text": "",
		"progress_percentage": 0.0
	}
	
	var progression = dungeon_data.get("progression_system", {}).get("difficulty_unlock", {})
	var requirement_data = progression.get(difficulty, "always_unlocked")
	
	# Handle different data structures
	var requirement_str = ""
	if typeof(requirement_data) == TYPE_STRING:
		requirement_str = requirement_data
	elif typeof(requirement_data) == TYPE_DICTIONARY:
		requirement_str = requirement_data.get("requirement", "always_unlocked")
	else:
		requirement_str = "always_unlocked"
	
	if requirement_str == "always_unlocked":
		info.is_unlocked = true
		info.requirement_text = "Unlocked"
		info.progress_text = "Available"
		info.progress_percentage = 1.0
		return info
	
	# Check current progress
	var previous_difficulty = get_previous_difficulty(difficulty)
	var clear_key = dungeon_id + "_" + previous_difficulty
	var required_clears = extract_clear_count_from_requirement(requirement_str)
	var current_clears = player_dungeon_progress.get("clear_counts", {}).get(clear_key, 0)
	
	info.is_unlocked = (current_clears >= required_clears)
	info.requirement_text = "Clear %s difficulty %d times" % [previous_difficulty.capitalize(), required_clears]
	info.progress_text = "%d/%d clears" % [current_clears, required_clears]
	info.progress_percentage = min(float(current_clears) / float(required_clears), 1.0)
	
	return info

func get_total_clear_counts(dungeon_id: String = "") -> Dictionary:
	"""Get clear counts for display - either for specific dungeon or all dungeons"""
	var clear_counts = player_dungeon_progress.get("clear_counts", {})
	
	if dungeon_id == "":
		# Return all clear counts
		return clear_counts
	else:
		# Return clear counts for specific dungeon
		var dungeon_clears = {}
		for key in clear_counts:
			if key.begins_with(dungeon_id + "_"):
				var difficulty = key.replace(dungeon_id + "_", "")
				dungeon_clears[difficulty] = clear_counts[key]
		
		return dungeon_clears

func get_dungeon_schedule_info() -> Dictionary:
	"""Get information about dungeon schedule"""
	var current_day = Time.get_datetime_dict_from_system().weekday
	var day_names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
	var today = day_names[current_day]
	
	var schedule = dungeon_data.get("dungeon_schedule", {}).get("daily_rotation", {})
	
	return {
		"today": today,
		"todays_dungeons": schedule.get(today, []),
		"always_available": dungeon_data.get("dungeon_schedule", {}).get("always_available", []),
		"full_schedule": schedule
	}

func get_player_dungeon_stats() -> Dictionary:
	"""Get player's dungeon statistics"""
	return {
		"total_clears": player_dungeon_progress.get("total_clears", 0),
		"clear_counts": player_dungeon_progress.get("clear_counts", {}),
		"unlocked_dungeons": get_unlocked_dungeons(),
		"available_today": get_available_dungeons_today().size()
	}

func get_unlocked_dungeons() -> Array:
	"""Get list of all unlocked dungeons"""
	var unlocked = []
	var all_dungeons = get_all_dungeons()
	
	for dungeon_id in all_dungeons:
		if is_dungeon_unlocked(dungeon_id):
			unlocked.append(dungeon_id)
	
	return unlocked

func get_all_dungeons() -> Array:
	"""Get list of all dungeon IDs"""
	var all_dungeons = []
	
	# Add elemental dungeons
	var elemental = dungeon_data.get("elemental_dungeons", {})
	for dungeon_id in elemental.keys():
		all_dungeons.append(dungeon_id)
	
	# Add special dungeons
	var special = dungeon_data.get("special_dungeons", {})
	for dungeon_id in special.keys():
		all_dungeons.append(dungeon_id)
	
	# Add pantheon dungeons
	var pantheon = dungeon_data.get("pantheon_dungeons", {})
	for dungeon_id in pantheon.keys():
		all_dungeons.append(dungeon_id)
	
	# Add equipment dungeons
	var equipment = dungeon_data.get("equipment_dungeons", {})
	for dungeon_id in equipment.keys():
		all_dungeons.append(dungeon_id)
	
	return all_dungeons

# Save/Load functionality
func save_dungeon_progress() -> Dictionary:
	"""Save dungeon progress to player data"""
	return player_dungeon_progress.duplicate()

func load_dungeon_progress(saved_data: Dictionary):
	"""Load dungeon progress from player data"""
	if saved_data.has("dungeon_progress"):
		player_dungeon_progress = saved_data.dungeon_progress.duplicate()
	else:
		initialize_player_progress()

# Battle completion handler
var current_dungeon_id: String = ""
var current_dungeon_difficulty: String = ""
var current_wave: int = 1
var total_waves: int = 3
var dungeon_enemies_per_wave: Array = []

func _on_battle_completed(_result):
	"""Handle battle completion for dungeons - LEGACY METHOD"""
	# NOTE: This method is kept for compatibility but should not run in new architecture
	# In the new clean architecture, BattleScreen handles completion directly
	print("WARNING: Legacy DungeonSystem._on_battle_completed called - this suggests old and new architectures are both running")
	print("This can cause double completion handling and UI issues")
	
	# Do not process completion here - let BattleScreen handle it
	return

func _open_battle_screen_for_dungeon(dungeon_id: String, difficulty: String, team: Array):
	"""Open the battle screen properly configured for dungeon battles"""
	
	# Check if we're already in a BattleScreen (avoid double creation)
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("setup_dungeon_battle"):
		current_scene.setup_dungeon_battle(dungeon_id, difficulty, team)
		return
	
	# Load battle screen scene
	var battle_scene = load("res://scenes/BattleScreen.tscn")
	
	# Get the current scene tree
	var scene_tree = get_tree()
	if not scene_tree:
		print("Error: No scene tree available")
		return
	
	# Change to battle screen
	scene_tree.change_scene_to_packed(battle_scene)
	
	# Wait for scene change to complete
	await scene_tree.process_frame
	
	# Wait for current_scene to be set
	var timeout_counter = 0
	while not scene_tree.current_scene and timeout_counter < 60:  # Max 1 second wait
		await scene_tree.process_frame
		timeout_counter += 1
	
	if timeout_counter >= 60:
		print("ERROR: Timeout waiting for scene change")
		return
	
	# Find the battle screen instance and wait for it to be ready
	current_scene = scene_tree.current_scene
	
	if current_scene:
		# Wait for BattleScreen to be ready before calling setup (with timeout)
		timeout_counter = 0
		while not current_scene.has_meta("ready_complete") and timeout_counter < 60:
			await scene_tree.process_frame
			timeout_counter += 1
		
		if timeout_counter >= 60:
			print("ERROR: Timeout waiting for BattleScreen ready")
			return
		
		if current_scene.has_method("setup_dungeon_battle"):
			current_scene.setup_dungeon_battle(dungeon_id, difficulty, team)
		else:
			print("Warning: Battle screen doesn't have setup_dungeon_battle method")
	else:
		print("Warning: No current scene found")
