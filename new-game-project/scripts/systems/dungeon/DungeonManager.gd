# scripts/systems/dungeon/DungeonManager.gd
# RULE 2: Single responsibility - Manage dungeon data, validation, and progress tracking
# RULE 3: No UI logic - pure business logic
# RULE 5: SystemRegistry integration
extends Node
class_name DungeonManager

const DungeonWaveHelperScript := preload("res://scripts/systems/dungeon/DungeonWaveHelper.gd")

signal dungeon_data_loaded

# Core data
var dungeon_data: Dictionary = {}
var dungeon_waves: Dictionary = {}
var player_progress: Dictionary = {}

# Wave/enemy helper (handles battle config, enemy stats, dungeon info enhancement)
var _wave_helper: RefCounted = null

func _ready() -> void:
	load_dungeon_data()
	load_dungeon_waves()
	_wave_helper = DungeonWaveHelperScript.new()
	_wave_helper.initialize(dungeon_waves)
	initialize_player_progress()

func load_dungeon_data() -> void:
	var file_path: String = "res://data/dungeons.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_warning("DungeonManager: Could not open dungeons.json, using fallback data")
		_load_fallback_data()
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("DungeonManager: Error parsing dungeons.json: " + json.error_string)
		_load_fallback_data()
		return

	dungeon_data = json.get_data()
	dungeon_data_loaded.emit()

func _load_fallback_data() -> void:
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

func load_dungeon_waves() -> void:
	var file_path: String = "res://data/dungeon_waves.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_warning("DungeonManager: Could not open dungeon_waves.json")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("DungeonManager: Error parsing dungeon_waves.json: " + json.error_string)
		return

	dungeon_waves = json.get_data()
	if _wave_helper:
		_wave_helper.update_waves(dungeon_waves)

func initialize_player_progress() -> void:
	player_progress = {
		"unlocked_dungeons": [],
		"clear_counts": {},
		"best_times": {},
		"total_clears": 0,
		"completed_dungeons": {},
		"daily_completions": {},
		"daily_completions_date": ""
	}
	_check_daily_reset()

# ===== Dungeon Queries =====

func get_available_dungeons() -> Array:
	var available: Array = []
	var all_dungeons: Array = get_all_dungeons()

	for dungeon_info: Dictionary in all_dungeons:
		if is_dungeon_available(dungeon_info.id):
			available.append(dungeon_info)

	return available

func get_all_dungeons() -> Array:
	var all_dungeons: Array = []
	var categories_to_scan: Array[Array] = [
		[dungeon_data.get("elemental_sanctums", {}), "elemental"],
		[dungeon_data.get("special_sanctums", {}), "special"],
		[dungeon_data.get("pantheon_trials", {}), "pantheon"],
		[dungeon_data.get("equipment_dungeons", {}), "equipment"],
	]

	for entry: Array in categories_to_scan:
		var source: Dictionary = entry[0]
		var category: String = entry[1]
		for dungeon_id: String in source.keys():
			var info: Dictionary = source[dungeon_id].duplicate()
			info["id"] = dungeon_id
			info["category"] = category
			_wave_helper.enhance_dungeon_info(info)
			all_dungeons.append(info)

	return all_dungeons

func get_dungeon_info(dungeon_id: String) -> Dictionary:
	var categories_to_check: Array[Array] = [
		[dungeon_data.get("elemental_sanctums", {}), "elemental"],
		[dungeon_data.get("special_sanctums", {}), "special"],
		[dungeon_data.get("pantheon_trials", {}), "pantheon"],
		[dungeon_data.get("equipment_dungeons", {}), "equipment"],
	]

	for entry: Array in categories_to_check:
		var source: Dictionary = entry[0]
		var category: String = entry[1]
		if source.has(dungeon_id):
			var info: Dictionary = source[dungeon_id].duplicate()
			info["id"] = dungeon_id
			info["category"] = category
			_wave_helper.enhance_dungeon_info(info)
			return info

	return {}

func is_dungeon_available(_dungeon_id: String) -> bool:
	# For now, all dungeons are available
	# TODO: Implement daily rotation system
	return true

func get_dungeon_schedule_info() -> Dictionary:
	var current_date: Dictionary = Time.get_date_dict_from_system()
	var weekdays: Array[String] = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
	var today: String = weekdays[current_date.weekday]

	var schedule_info: Dictionary = {
		"today": today.capitalize(),
		"available_dungeons": [],
		"featured_dungeon": "",
		"next_rotation": "Tomorrow"
	}

	var all_dungeons: Array = get_all_dungeons()
	for dungeon: Dictionary in all_dungeons:
		var schedule: String = dungeon.get("schedule", "always_available")
		var schedule_day: String = dungeon.get("schedule_day", "")

		var is_rotating_and_available: bool = false
		match schedule:
			"always_available":
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

			if schedule_day == today and schedule_info.featured_dungeon == "":
				schedule_info.featured_dungeon = dungeon.get("name", "Unknown")

	return schedule_info

func get_dungeon_categories() -> Dictionary:
	var categories: Dictionary = {
		"elemental": [],
		"pantheon": [],
		"equipment": [],
		"special": []
	}

	var all_dungeons: Array = get_available_dungeons()
	for dungeon_info: Dictionary in all_dungeons:
		var category: String = dungeon_info.get("category", "elemental")
		if categories.has(category):
			categories[category].append(dungeon_info)

	return categories

# ===== Validation =====

func validate_dungeon_entry(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error_message": "",
		"energy_cost": 0
	}

	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		result.error_message = "Dungeon not found"
		return result

	var difficulties: Dictionary = dungeon_info.get("difficulty_levels", {})
	if not difficulties.has(difficulty):
		result.error_message = "Invalid difficulty"
		return result

	if team.is_empty() or team.size() > DungeonConstants.MAX_TEAM_SIZE:
		result.error_message = "Invalid team size (1-%d gods required)" % DungeonConstants.MAX_TEAM_SIZE
		return result

	if is_daily_limit_reached(dungeon_id):
		var daily_limit: int = get_daily_limit(dungeon_id)
		result.error_message = "Daily limit reached (%d/%d completions today)" % [daily_limit, daily_limit]
		return result

	var difficulty_info: Dictionary = difficulties[difficulty]
	var energy_cost: int = difficulty_info.get("energy_cost", 8)
	result.energy_cost = energy_cost

	var resource_manager: Node = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if resource_manager:
		var current_energy: int = resource_manager.get_resource("energy")
		if current_energy < energy_cost:
			result.error_message = "Not enough energy (%d required, %d available)" % [energy_cost, current_energy]
			return result

	result.success = true
	return result

# ===== Battle Config & Enemy Data (delegated to DungeonWaveHelper) =====

func get_battle_configuration(dungeon_id: String, difficulty: String) -> Dictionary:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	return _wave_helper.get_battle_configuration(dungeon_info, difficulty)

func get_enemy_types_for_dungeon(dungeon_id: String) -> Array:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	return _wave_helper.get_enemy_types_for_dungeon(dungeon_info)

func get_dungeon_enemies(dungeon_id: String, difficulty: String) -> Array:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	return _wave_helper.get_dungeon_enemies(dungeon_info, difficulty)

# ===== Loot & Rewards =====

func get_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return ""

	var category: String = dungeon_info.get("category", "")

	match category:
		"elemental":
			return "elemental_dungeon_" + difficulty
		"special":
			if dungeon_id == "magic_sanctum":
				return "magic_dungeon"
			return "elemental_dungeon_" + difficulty
		"pantheon":
			return "pantheon_trial_" + difficulty
		"equipment":
			return "equipment_dungeon_" + difficulty
		_:
			return "elemental_dungeon_" + difficulty

func get_completion_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return {}

	var loot_table_id: String = get_loot_table_name(dungeon_id, difficulty)
	if loot_table_id.is_empty():
		push_warning("DungeonManager: No loot table for " + dungeon_id + " " + difficulty)
		return {}

	var element: String = dungeon_info.get("element", "")
	var multiplier: float = DungeonConstants.get_difficulty_reward_multiplier(difficulty)

	var loot_system: Node = SystemRegistry.get_instance().get_system("LootSystem") if SystemRegistry.get_instance() else null
	if loot_system:
		var rewards: Dictionary = loot_system.generate_loot(loot_table_id, multiplier, element)
		return rewards
	else:
		push_warning("DungeonManager: LootSystem not available, returning empty rewards")
		return {}

func get_dungeon_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	return get_completion_rewards(dungeon_id, difficulty)

func get_first_clear_rewards(dungeon_id: String, difficulty: String) -> Dictionary:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return {}

	var difficulty_info: Dictionary = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	return difficulty_info.get("first_clear_rewards", {})

# ===== Progress Tracking =====

func record_completion(dungeon_id: String, difficulty: String, completion_time: float) -> bool:
	var was_first_clear: bool = is_first_clear(dungeon_id, difficulty)

	if was_first_clear:
		mark_dungeon_cleared(dungeon_id, difficulty)

	update_clear_count(dungeon_id, difficulty)
	increment_daily_completion(dungeon_id)

	var time_key: String = dungeon_id + "_" + difficulty + "_best_time"
	var current_best: float = player_progress.best_times.get(time_key, INF)
	if completion_time < current_best:
		player_progress.best_times[time_key] = completion_time

	return was_first_clear

func save_progress() -> Dictionary:
	return player_progress.duplicate()

func load_progress(saved_data: Dictionary) -> void:
	if saved_data.has("unlocked_dungeons"):
		player_progress = saved_data.duplicate()
		if not player_progress.has("completed_dungeons"):
			player_progress["completed_dungeons"] = {}
		if not player_progress.has("daily_completions"):
			player_progress["daily_completions"] = {}
		if not player_progress.has("daily_completions_date"):
			player_progress["daily_completions_date"] = ""
		_check_daily_reset()

func get_save_data() -> Dictionary:
	return save_progress()

func load_save_data(saved_data: Dictionary) -> void:
	load_progress(saved_data)

func update_clear_count(dungeon_id: String, difficulty: String) -> void:
	var clear_key: String = dungeon_id + "_" + difficulty
	var current_count: int = player_progress.clear_counts.get(clear_key, 0)
	player_progress.clear_counts[clear_key] = current_count + 1
	player_progress.total_clears += 1

func is_first_clear(dungeon_id: String, difficulty: String) -> bool:
	var clear_key: String = dungeon_id + "_" + difficulty
	return not player_progress.completed_dungeons.get(clear_key, false)

func mark_dungeon_cleared(dungeon_id: String, difficulty: String) -> void:
	var clear_key: String = dungeon_id + "_" + difficulty
	player_progress.completed_dungeons[clear_key] = true

# ===== Daily Completion Tracking =====

func _get_current_date_string() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func _check_daily_reset() -> void:
	var current_date: String = _get_current_date_string()
	var stored_date: String = player_progress.get("daily_completions_date", "")

	if stored_date != current_date:
		player_progress["daily_completions"] = {}
		player_progress["daily_completions_date"] = current_date

func get_daily_limit(dungeon_id: String) -> int:
	var dungeon_info: Dictionary = get_dungeon_info(dungeon_id)
	if dungeon_info.is_empty():
		return 10
	return dungeon_info.get("daily_limit", 10)

func get_daily_completion_count(dungeon_id: String) -> int:
	_check_daily_reset()
	return player_progress.daily_completions.get(dungeon_id, 0)

func get_daily_completions_remaining(dungeon_id: String) -> int:
	var limit: int = get_daily_limit(dungeon_id)
	var count: int = get_daily_completion_count(dungeon_id)
	return max(0, limit - count)

func is_daily_limit_reached(dungeon_id: String) -> bool:
	return get_daily_completions_remaining(dungeon_id) <= 0

func increment_daily_completion(dungeon_id: String) -> void:
	_check_daily_reset()
	var current_count: int = player_progress.daily_completions.get(dungeon_id, 0)
	player_progress.daily_completions[dungeon_id] = current_count + 1
