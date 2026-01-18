# scripts/systems/dungeon/DungeonManager.gd
# RULE 2: Single responsibility - Manage dungeon data and validation only
# RULE 3: No UI logic - pure business logic
# RULE 5: SystemRegistry integration
extends Node
class_name DungeonManager

# Signals for UI communication (RULE 4: No UI in systems)
signal dungeon_data_loaded
signal dungeon_unlocked(dungeon_id: String)
signal validation_completed(result: Dictionary)

# Core data
var dungeon_data: Dictionary = {}
var dungeon_waves: Dictionary = {}
var player_progress: Dictionary = {}

func _ready():
	"""Initialize dungeon manager"""
	load_dungeon_data()
	load_dungeon_waves()
	initialize_player_progress()

func load_dungeon_data():
	"""Load dungeon definitions from JSON - RULE 5: Data-driven approach"""
	var file_path = "res://data/dungeons.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		push_warning("DungeonManager: Could not open dungeons.json, using fallback data")
		_load_fallback_data()
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("DungeonManager: Error parsing dungeons.json: " + json.error_string)
		_load_fallback_data()
		return
	
	dungeon_data = json.get_data()
	dungeon_data_loaded.emit()

func _load_fallback_data():
	"""Load minimal fallback data if JSON fails"""
	dungeon_data = {
		"elemental_sanctums": {
			"fire_sanctum": {
				"name": "Sanctum of Flames",
				"element": "fire",
				"description": "Ancient temple where fire spirits guard powerful flame essences.",
				"difficulty_levels": {
					"beginner": {"energy_cost": 8, "recommended_level": 10}
				}
			}
		},
		"schedule": {
			"always_available": ["fire_sanctum"]
		}
	}

func load_dungeon_waves():
	"""Load wave configurations from dungeon_waves.json"""
	var file_path = "res://data/dungeon_waves.json"
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_warning("DungeonManager: Could not open dungeon_waves.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("DungeonManager: Error parsing dungeon_waves.json: " + json.error_string)
		return

	dungeon_waves = json.get_data()
	print("DungeonManager: Loaded wave data for dungeon categories: ", dungeon_waves.keys())

func initialize_player_progress():
	"""Initialize player dungeon progress"""
	player_progress = {
		"unlocked_dungeons": [],
		"clear_counts": {},
		"best_times": {},
		"total_clears": 0,
		"completed_dungeons": {},  # Tracks first clears: "dungeon_id_difficulty" -> true
		"daily_completions": {},   # Tracks daily runs: "dungeon_id" -> count
		"daily_completions_date": ""  # Date string for reset detection: "YYYY-MM-DD"
	}
	_check_daily_reset()

func get_available_dungeons() -> Array:
	"""Get all available dungeons for today"""
	var available = []
	var all_dungeons = get_all_dungeons()
	
	for dungeon_info in all_dungeons:
		if is_dungeon_available(dungeon_info.id):
			available.append(dungeon_info)
	
	return available

func get_all_dungeons() -> Array:
	"""Get all dungeons across all categories"""
	var all_dungeons = []
	
	# Elemental sanctums
	var elemental = dungeon_data.get("elemental_sanctums", {})
	for dungeon_id in elemental.keys():
		var info = elemental[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "elemental"
		all_dungeons.append(info)
	
	# Special sanctums
	var special = dungeon_data.get("special_sanctums", {})
	for dungeon_id in special.keys():
		var info = special[dungeon_id].duplicate()
		info["id"] = dungeon_id  
		info["category"] = "special"
		all_dungeons.append(info)
	
	# Pantheon trials
	var pantheon = dungeon_data.get("pantheon_trials", {})
	for dungeon_id in pantheon.keys():
		var info = pantheon[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "pantheon" 
		all_dungeons.append(info)
		
	# Equipment dungeons
	var equipment_dungeons = dungeon_data.get("equipment_dungeons", {})
	for dungeon_id in equipment_dungeons.keys():
		var info = equipment_dungeons[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "equipment"
		all_dungeons.append(info)
	
	return all_dungeons

func get_dungeon_info(dungeon_id: String) -> Dictionary:
	"""Get specific dungeon information with enhanced details"""
	# Check elemental sanctums
	var elemental = dungeon_data.get("elemental_sanctums", {})
	if elemental.has(dungeon_id):
		var info = elemental[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "elemental"
		_enhance_dungeon_info(info)
		return info
	
	# Check special sanctums
	var special = dungeon_data.get("special_sanctums", {})
	if special.has(dungeon_id):
		var info = special[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "special"
		_enhance_dungeon_info(info)
		return info
	
	# Check pantheon trials
	var pantheon = dungeon_data.get("pantheon_trials", {})
	if pantheon.has(dungeon_id):
		var info = pantheon[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "pantheon"
		_enhance_dungeon_info(info)
		return info
	
	# Check equipment dungeons
	var equipment_dungeons = dungeon_data.get("equipment_dungeons", {})
	if equipment_dungeons.has(dungeon_id):
		var info = equipment_dungeons[dungeon_id].duplicate()
		info["id"] = dungeon_id
		info["category"] = "equipment"
		return info
	
	return {}

func is_dungeon_available(_dungeon_id: String) -> bool:
	"""Check if dungeon is available today based on schedule"""
	# For now, all dungeons are available
	# TODO: Implement daily rotation system
	return true

func get_dungeon_schedule_info() -> Dictionary:
	"""Get today's dungeon schedule information - Only show rotating dungeons like Summoners War"""
	var current_date = Time.get_date_dict_from_system()
	var weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
	var today = weekdays[current_date.weekday]
	
	var schedule_info = {
		"today": today.capitalize(),
		"available_dungeons": [],
		"featured_dungeon": "",
		"next_rotation": "Tomorrow"
	}
	
	var all_dungeons = get_all_dungeons()
	for dungeon in all_dungeons:
		var schedule = dungeon.get("schedule", "always_available")
		var schedule_day = dungeon.get("schedule_day", "")
		
		# Only include dungeons with rotating schedules (NOT always_available)
		var is_rotating_and_available = false
		match schedule:
			"always_available":
				# Skip - these don't appear in "Today's Dungeons"
				continue
			"daily_rotation":
				is_rotating_and_available = schedule_day == today
			"weekend_special":
				is_rotating_and_available = (today == "saturday" or today == "sunday")
			"weekend_saturday":
				is_rotating_and_available = (today == "saturday")
			"weekend_sunday":
				is_rotating_and_available = (today == "sunday")
			"weekend_rotating":
				is_rotating_and_available = (today == "saturday" or today == "sunday")
		
		if is_rotating_and_available:
			schedule_info.available_dungeons.append({
				"name": dungeon.get("name", "Unknown"),
				"element": dungeon.get("element", "neutral"),
				"id": dungeon.get("id", "")
			})
			
			# Set featured dungeon (first daily rotation dungeon)
			if schedule_day == today and schedule_info.featured_dungeon == "":
				schedule_info.featured_dungeon = dungeon.get("name", "Unknown")
	
	return schedule_info

func validate_dungeon_entry(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	"""Validate if player can enter dungeon - RULE 3: Pure validation logic"""
	var result = {
		"success": false,
		"error_message": "",
		"energy_cost": 0
	}

	# Check if dungeon exists
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		result.error_message = "Dungeon not found"
		validation_completed.emit(result)
		return result

	# Check difficulty
	var difficulties = dungeon_info.get("difficulty_levels", {})
	if not difficulties.has(difficulty):
		result.error_message = "Invalid difficulty"
		validation_completed.emit(result)
		return result

	# Check team
	if team.is_empty() or team.size() > 4:
		result.error_message = "Invalid team size (1-4 gods required)"
		validation_completed.emit(result)
		return result

	# Check daily limit
	if is_daily_limit_reached(dungeon_id):
		var daily_limit = get_daily_limit(dungeon_id)
		result.error_message = "Daily limit reached (%d/%d completions today)" % [daily_limit, daily_limit]
		validation_completed.emit(result)
		return result

	# Check energy cost
	var difficulty_info = difficulties[difficulty]
	var energy_cost = difficulty_info.get("energy_cost", 8)
	result.energy_cost = energy_cost

	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager:
		var current_energy = resource_manager.get_resource("energy")
		if current_energy < energy_cost:
			result.error_message = "Not enough energy (%d required, %d available)" % [energy_cost, current_energy]
			validation_completed.emit(result)
			return result

	result.success = true
	validation_completed.emit(result)
	return result

func get_dungeon_categories() -> Dictionary:
	"""Get dungeons organized by category"""
	var categories = {
		"elemental": [],
		"pantheon": [], 
		"equipment": [],
		"special": []
	}
	
	var all_dungeons = get_available_dungeons()
	for dungeon_info in all_dungeons:
		var category = dungeon_info.get("category", "elemental")
		if categories.has(category):
			categories[category].append(dungeon_info)
	
	return categories

func get_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Generate loot table name for dungeon rewards"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return ""
	
	var category = dungeon_info.get("category", "")
	
	# Map categories to loot table templates that actually exist
	match category:
		"elemental":
			return "elemental_dungeon_" + difficulty
		"special":
			if dungeon_id == "magic_sanctum":
				return "magic_dungeon"
			return "elemental_dungeon_" + difficulty  # Fallback to elemental template
		"pantheon":
			return "pantheon_trial_" + difficulty
		"equipment":
			return "equipment_dungeon_" + difficulty
		_:
			# Fallback to elemental template for unknown categories
			if dungeon_id.ends_with("_sanctum"):
				return "elemental_dungeon_" + difficulty
			else:
				return "elemental_dungeon_" + difficulty

func get_battle_configuration(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get battle configuration for dungeon fight with wave data from dungeon_waves.json"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return {}

	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	if difficulty_info.is_empty():
		return {}

	# Look up wave data from dungeon_waves.json
	var wave_data = _get_wave_data(dungeon_id, difficulty)
	var enemy_waves = _convert_wave_data_to_battle_config(wave_data)

	return {
		"enemies": difficulty_info.get("enemies", []),
		"enemy_waves": enemy_waves,
		"boss": difficulty_info.get("boss", ""),
		"battle_type": "dungeon",
		"background": dungeon_info.get("background_theme", "default"),
		"special_conditions": difficulty_info.get("special_conditions", []),
		"wave_count": wave_data.size()
	}

func _get_wave_data(dungeon_id: String, difficulty: String) -> Array:
	"""Look up wave data for a dungeon from dungeon_waves.json"""
	# Map dungeon_id to the correct category in dungeon_waves.json
	var category_map = {
		"fire_sanctum": "elemental_sanctums",
		"water_sanctum": "elemental_sanctums",
		"earth_sanctum": "elemental_sanctums",
		"lightning_sanctum": "elemental_sanctums",
		"light_sanctum": "elemental_sanctums",
		"dark_sanctum": "elemental_sanctums",
		"magic_sanctum": "special_sanctums",
		"titans_forge": "equipment_dungeons",
		"valhalla_armory": "equipment_dungeons",
		"oracle_sanctum": "equipment_dungeons",
		"greek_trials": "pantheon_trials",
		"norse_trials": "pantheon_trials",
		"egyptian_trials": "pantheon_trials"
	}

	var category = category_map.get(dungeon_id, "")
	if category.is_empty():
		push_warning("DungeonManager: No wave category found for dungeon: " + dungeon_id)
		return []

	var category_data = dungeon_waves.get(category, {})
	var dungeon_wave_data = category_data.get(dungeon_id, {})
	var difficulty_wave_data = dungeon_wave_data.get(difficulty, {})
	var waves = difficulty_wave_data.get("waves", [])

	return waves

func _convert_wave_data_to_battle_config(wave_data: Array) -> Array:
	"""Convert dungeon_waves.json format to BattleConfig.enemy_waves format"""
	var enemy_waves = []

	for wave in wave_data:
		var wave_enemies = []
		var enemies = wave.get("enemies", [])

		for enemy_def in enemies:
			var count = enemy_def.get("count", 1)
			var level = enemy_def.get("level", 1)
			var tier = enemy_def.get("tier", "basic")
			var enemy_name = enemy_def.get("name", "Unknown Enemy")
			var element = enemy_def.get("type", "neutral")

			# Expand count into multiple enemy entries
			for i in range(count):
				var stats = _calculate_enemy_stats(level, tier)
				wave_enemies.append({
					"name": enemy_name,
					"level": level,
					"hp": stats.hp,
					"attack": stats.attack,
					"defense": stats.defense,
					"speed": stats.speed,
					"element": element,
					"tier": tier
				})

		enemy_waves.append(wave_enemies)

	return enemy_waves

func _calculate_enemy_stats(level: int, tier: String) -> Dictionary:
	"""Calculate enemy stats based on level and tier - BALANCED for god stats"""
	# Base stats at level 1 - matched to god power levels
	# Average god at level 1: ~110 HP, ~55 ATK, ~70 DEF, ~60 SPD
	var base_hp = 120  # Slightly tankier than gods
	var base_attack = 50  # Slightly weaker than gods
	var base_defense = 60  # Similar to gods
	var base_speed = 55  # Similar to gods

	# Tier multipliers - REDUCED from previous values
	var tier_multipliers = {
		"basic": 1.0,    # 1v1 fair fight
		"leader": 1.4,   # Reduced from 1.5 - mini-boss
		"elite": 1.8,    # Reduced from 2.0 - challenging
		"boss": 2.5      # Reduced from 3.0 - team effort required
	}
	var tier_mult = tier_multipliers.get(tier, 1.0)

	# Level scaling: stats grow by ~10% per level (same as gods)
	var level_mult = 1.0 + (level - 1) * 0.1

	return {
		"hp": int(base_hp * level_mult * tier_mult),  # REMOVED x10 multiplier!
		"attack": int(base_attack * level_mult * tier_mult),
		"defense": int(base_defense * level_mult * tier_mult),
		"speed": int(base_speed + level * 2)  # Speed grows linearly
	}

func get_completion_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get rewards for completing dungeon using LootSystem"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return {}

	# Get the loot table name for this dungeon + difficulty
	var loot_table_id = get_loot_table_name(dungeon_id, difficulty)
	if loot_table_id.is_empty():
		push_warning("DungeonManager: No loot table for " + dungeon_id + " " + difficulty)
		return {}

	# Get element for element-specific drops
	var element = dungeon_info.get("element", "")

	# Get difficulty multiplier (higher difficulties = more rewards)
	var multiplier = _get_difficulty_reward_multiplier(difficulty)

	# Generate loot through LootSystem
	var loot_system = SystemRegistry.get_instance().get_system("LootSystem") if SystemRegistry.get_instance() else null
	if loot_system:
		var rewards = loot_system.generate_loot(loot_table_id, multiplier, element)
		print("DungeonManager: Generated rewards for %s %s: %s" % [dungeon_id, difficulty, rewards])
		return rewards
	else:
		push_warning("DungeonManager: LootSystem not available, returning empty rewards")
		return {}

func _get_difficulty_reward_multiplier(difficulty: String) -> float:
	"""Get reward multiplier based on difficulty"""
	match difficulty:
		"beginner":
			return 1.0
		"intermediate":
			return 1.2
		"advanced":
			return 1.5
		"expert":
			return 2.0
		"master":
			return 2.5
		"heroic":
			return 2.0
		"legendary":
			return 3.0
		_:
			return 1.0

func record_completion(dungeon_id: String, difficulty: String, completion_time: float) -> bool:
	"""Record dungeon completion for statistics. Returns true if this was a first clear."""
	var was_first_clear = is_first_clear(dungeon_id, difficulty)

	# Mark as cleared if this is the first time
	if was_first_clear:
		mark_dungeon_cleared(dungeon_id, difficulty)

	update_clear_count(dungeon_id, difficulty)

	# Increment daily completion count
	increment_daily_completion(dungeon_id)

	# Update best time
	var time_key = dungeon_id + "_" + difficulty + "_best_time"
	var current_best = player_progress.best_times.get(time_key, INF)
	if completion_time < current_best:
		player_progress.best_times[time_key] = completion_time

	return was_first_clear

# Save/Load functionality for player progress
func save_progress() -> Dictionary:
	"""Save dungeon progress data"""
	return player_progress.duplicate()

func load_progress(saved_data: Dictionary):
	"""Load dungeon progress data"""
	if saved_data.has("unlocked_dungeons"):
		player_progress = saved_data.duplicate()
		# Ensure completed_dungeons exists for backwards compatibility
		if not player_progress.has("completed_dungeons"):
			player_progress["completed_dungeons"] = {}
		# Ensure daily tracking fields exist for backwards compatibility
		if not player_progress.has("daily_completions"):
			player_progress["daily_completions"] = {}
		if not player_progress.has("daily_completions_date"):
			player_progress["daily_completions_date"] = ""
		# Check if daily reset is needed after loading
		_check_daily_reset()

# SaveManager-compatible interface
func get_save_data() -> Dictionary:
	"""Get save data for SaveManager integration"""
	return save_progress()

func load_save_data(saved_data: Dictionary):
	"""Load save data from SaveManager"""
	load_progress(saved_data)

func update_clear_count(dungeon_id: String, difficulty: String):
	"""Update clear count for completed dungeon"""
	var clear_key = dungeon_id + "_" + difficulty
	var current_count = player_progress.clear_counts.get(clear_key, 0)
	player_progress.clear_counts[clear_key] = current_count + 1
	player_progress.total_clears += 1

func is_first_clear(dungeon_id: String, difficulty: String) -> bool:
	"""Check if this dungeon+difficulty has never been cleared before"""
	var clear_key = dungeon_id + "_" + difficulty
	return not player_progress.completed_dungeons.get(clear_key, false)

func mark_dungeon_cleared(dungeon_id: String, difficulty: String):
	"""Mark a dungeon+difficulty as cleared (for first-clear tracking)"""
	var clear_key = dungeon_id + "_" + difficulty
	player_progress.completed_dungeons[clear_key] = true
	print("DungeonManager: Marked %s as cleared (first clear)" % clear_key)

func get_first_clear_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get first-clear bonus rewards for a dungeon+difficulty"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return {}

	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	return difficulty_info.get("first_clear_rewards", {})

# ===== Daily Completion Tracking =====

func _get_current_date_string() -> String:
	"""Get current date as YYYY-MM-DD string for daily tracking"""
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func _check_daily_reset():
	"""Check if daily completions need to be reset (new day)"""
	var current_date = _get_current_date_string()
	var stored_date = player_progress.get("daily_completions_date", "")

	if stored_date != current_date:
		# New day - reset daily completions
		player_progress["daily_completions"] = {}
		player_progress["daily_completions_date"] = current_date
		print("DungeonManager: Daily completions reset for new day: %s" % current_date)

func get_daily_limit(dungeon_id: String) -> int:
	"""Get the daily completion limit for a dungeon (default: 10)"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return 10
	return dungeon_info.get("daily_limit", 10)

func get_daily_completion_count(dungeon_id: String) -> int:
	"""Get how many times this dungeon has been completed today"""
	_check_daily_reset()  # Ensure we're working with current day's data
	return player_progress.daily_completions.get(dungeon_id, 0)

func get_daily_completions_remaining(dungeon_id: String) -> int:
	"""Get how many daily completions remain for this dungeon"""
	var limit = get_daily_limit(dungeon_id)
	var count = get_daily_completion_count(dungeon_id)
	return max(0, limit - count)

func is_daily_limit_reached(dungeon_id: String) -> bool:
	"""Check if the daily completion limit has been reached"""
	return get_daily_completions_remaining(dungeon_id) <= 0

func increment_daily_completion(dungeon_id: String):
	"""Increment the daily completion count for a dungeon"""
	_check_daily_reset()  # Ensure we're working with current day's data
	var current_count = player_progress.daily_completions.get(dungeon_id, 0)
	player_progress.daily_completions[dungeon_id] = current_count + 1
	print("DungeonManager: Daily completion for %s: %d/%d" % [dungeon_id, current_count + 1, get_daily_limit(dungeon_id)])

func _enhance_dungeon_info(info: Dictionary):
	"""Enhance dungeon info with calculated power ratings and detailed information"""
	var difficulty_levels = info.get("difficulty_levels", {})
	
	for difficulty_name in difficulty_levels.keys():
		var difficulty_info = difficulty_levels[difficulty_name]
		
		# Calculate enemy power for this difficulty
		var enemy_power = _calculate_enemy_power(info, difficulty_name)
		difficulty_info["enemy_power"] = enemy_power
		
		# Add recommended team power (slightly higher than enemy power)
		difficulty_info["recommended_team_power"] = int(enemy_power * 1.2)
		
		# Add difficulty color for UI
		difficulty_info["difficulty_color"] = _get_difficulty_color(difficulty_name)
		
		# Add stage progression info
		difficulty_info["stage_count"] = 5  # Standard dungeon stage count
		difficulty_info["boss_power"] = int(enemy_power * 1.5)  # Boss is 50% stronger

func _calculate_enemy_power(dungeon_info: Dictionary, difficulty: String) -> int:
	"""Calculate estimated enemy power based on dungeon category and difficulty"""
	var base_power = 1000
	
	# Adjust base power by dungeon category
	var category = dungeon_info.get("category", "elemental")
	match category:
		"elemental":
			base_power = 800
		"pantheon":
			base_power = 1200
		"equipment":
			base_power = 1000
		"special":
			base_power = 1500
	
	# Apply difficulty multiplier
	var difficulty_multiplier = 1.0
	match difficulty:
		"beginner":
			difficulty_multiplier = 1.0
		"intermediate":
			difficulty_multiplier = 1.5
		"advanced":
			difficulty_multiplier = 2.2
		"expert":
			difficulty_multiplier = 3.0
		"master":
			difficulty_multiplier = 4.0
	
	# Apply level scaling from dungeon data if available
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	var recommended_level = difficulty_info.get("recommended_level", 10)
	var level_multiplier = 1.0 + (recommended_level - 10) * 0.1
	
	return int(base_power * difficulty_multiplier * level_multiplier)

func _get_difficulty_color(difficulty: String) -> Color:
	"""Get color coding for difficulty levels"""
	match difficulty:
		"beginner":
			return Color.GREEN
		"intermediate":
			return Color.YELLOW
		"advanced":
			return Color.ORANGE
		"expert":
			return Color.RED
		"master":
			return Color.PURPLE
		_:
			return Color.WHITE

func get_enemy_types_for_dungeon(dungeon_id: String) -> Array:
	"""Get list of enemy types that appear in this dungeon"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	var element = dungeon_info.get("element", "neutral")
	var category = dungeon_info.get("category", "elemental")
	
	var enemy_types = []
	
	# Based on element and category, determine enemy types
	match category:
		"elemental":
			enemy_types = [
				element.capitalize() + " Guardian",
				element.capitalize() + " Warden", 
				element.capitalize() + " Spirit"
			]
		"pantheon":
			enemy_types = [
				"Divine Guardian",
				"Sacred Protector",
				"Celestial Champion"
			]
		"equipment":
			enemy_types = [
				"Armored Sentinel",
				"Weapon Master",
				"Equipment Guardian"
			]
	
	return enemy_types

func get_dungeon_enemies(dungeon_id: String, difficulty: String) -> Array:
	"""Get detailed enemy data for battle preview"""
	var dungeon_info = get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	var waves = difficulty_info.get("waves", [])

	var enemies = []
	var enemy_types = get_enemy_types_for_dungeon(dungeon_id)

	# If waves exist in data, use them
	if not waves.is_empty():
		for wave in waves:
			for enemy in wave:
				enemies.append({
					"name": enemy.get("name", "Enemy"),
					"level": enemy.get("level", 1)
				})
	else:
		# Generate preview enemies from enemy types
		var base_level = difficulty_info.get("recommended_level", 5)
		for enemy_type in enemy_types:
			enemies.append({
				"name": enemy_type,
				"level": base_level
			})

	return enemies

func get_dungeon_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get rewards for dungeon (alias for get_completion_rewards)"""
	return get_completion_rewards(dungeon_id, difficulty)
