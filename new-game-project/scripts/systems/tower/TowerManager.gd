# scripts/systems/tower/TowerManager.gd
# Infinite Tower System - endless scaling challenge mode
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - Tower progression and enemy scaling
extends Node
class_name TowerManager

signal floor_started(floor_number: int)
signal floor_completed(floor_number: int, rewards: Dictionary)
signal tower_run_ended(final_floor: int, is_new_record: bool, total_rewards: Dictionary)
signal enemy_wave_spawned(enemies: Array)

# Current run state
var current_floor: int = 0
var current_run_active: bool = false
var current_team: Array = []  # Array of God objects
var team_hp_state: Dictionary = {}  # god_id -> current_hp (persists between floors)
var run_total_rewards: Dictionary = {}  # Accumulated rewards for the entire run

# Best run tracking (persisted)
var best_floor: int = 0
var best_floor_timestamp: int = 0

# Floor configuration
const BASE_ENEMY_LEVEL: int = 1
const LEVEL_SCALING_PER_FLOOR: float = 1.5  # Enemies gain 1.5 levels per floor
const STAT_SCALING_PER_FLOOR: float = 1.08  # 8% stat increase per floor
const ENEMIES_PER_FLOOR: int = 3
const BOSS_FLOOR_INTERVAL: int = 10  # Every 10 floors is a boss

# Milestone floors for special rewards
const MILESTONE_FLOORS: Array = [10, 25, 50, 100, 150, 200, 250, 500, 1000]

# Enemy pool for tower (scales with floor)
var enemy_templates: Array = []

func _ready():
	_load_enemy_templates()
	_load_best_floor()

func _load_enemy_templates():
	"""Load enemy templates from enemies.json"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var config_manager = system_registry.get_system("ConfigurationManager")
	if not config_manager:
		return

	var enemies_config = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return

	# Collect all enemy names from territory_defenders and enemy_types
	var territory_defenders = enemies_config.get("territory_defenders", {})
	for tier_key in territory_defenders:
		if not territory_defenders[tier_key] is Dictionary:
			continue
		var tier_data = territory_defenders[tier_key]
		for node_type in tier_data:
			if node_type is String and node_type.begins_with("_"):
				continue
			var enemies = tier_data[node_type]
			if enemies is Dictionary:
				for enemy_name in enemies:
					if enemy_name is String and not enemy_templates.has(enemy_name):
						enemy_templates.append(enemy_name)

	# Also add dungeon enemies
	var enemy_types = enemies_config.get("enemy_types", {})
	for element in enemy_types:
		var roles = enemy_types[element]
		for role in roles:
			if roles[role] is Dictionary:
				for enemy_name in roles[role]:
					if not enemy_templates.has(enemy_name):
						enemy_templates.append(enemy_name)

func _load_best_floor():
	"""Load best floor from save data"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var save_manager = system_registry.get_system("SaveManager")
		if save_manager:
			var save_data = save_manager.get_player_data()
			if save_data:
				best_floor = save_data.get("tower_best_floor", 0)
				best_floor_timestamp = save_data.get("tower_best_timestamp", 0)

func _save_best_floor():
	"""Save best floor to save data"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var save_manager = system_registry.get_system("SaveManager")
		if save_manager:
			save_manager.set_player_value("tower_best_floor", best_floor)
			save_manager.set_player_value("tower_best_timestamp", best_floor_timestamp)
			save_manager.save_game()

# === PUBLIC API ===

func start_tower_run(team: Array) -> bool:
	"""Start a new tower run with the given team"""
	if current_run_active:
		push_error("TowerManager: Cannot start new run while one is active")
		return false

	if team.is_empty():
		push_error("TowerManager: Cannot start tower with empty team")
		return false

	# Validate team (max 4 gods)
	current_team = []
	for god in team:
		if god != null:
			current_team.append(god)
		if current_team.size() >= 4:
			break

	if current_team.is_empty():
		push_error("TowerManager: No valid gods in team")
		return false

	current_floor = 0
	current_run_active = true
	run_total_rewards.clear()  # Reset accumulated rewards

	# Initialize HP state - all gods start at full HP
	team_hp_state.clear()
	for god in current_team:
		team_hp_state[god.id] = -1  # -1 means use max HP

	print("TowerManager: Starting tower run with %d gods" % current_team.size())

	# Start first floor
	advance_to_next_floor()
	return true

func advance_to_next_floor():
	"""Move to the next floor"""
	if not current_run_active:
		return

	current_floor += 1
	floor_started.emit(current_floor)

	print("TowerManager: Entering floor %d" % current_floor)

func get_current_floor_enemies() -> Array:
	"""Generate enemies for the current floor"""
	var enemies = []
	var is_boss_floor = (current_floor % BOSS_FLOOR_INTERVAL == 0)
	var enemy_count = 1 if is_boss_floor else ENEMIES_PER_FLOOR

	for i in range(enemy_count):
		var enemy = _create_scaled_enemy(current_floor, is_boss_floor)
		if enemy:
			enemies.append(enemy)

	enemy_wave_spawned.emit(enemies)
	return enemies

func complete_current_floor() -> Dictionary:
	"""Complete the current floor and get rewards"""
	if not current_run_active:
		return {}

	var rewards = _calculate_floor_rewards(current_floor)
	floor_completed.emit(current_floor, rewards)

	# Award rewards immediately
	_award_rewards(rewards)

	# Accumulate rewards for run total
	for resource_id in rewards:
		run_total_rewards[resource_id] = run_total_rewards.get(resource_id, 0) + rewards[resource_id]

	return rewards

func end_tower_run(_victory: bool = false):
	"""End the current tower run (called when team is defeated or player quits)"""
	if not current_run_active:
		return

	current_run_active = false
	var final_floor = current_floor
	var is_new_record = false
	var total_rewards = run_total_rewards.duplicate()

	# Check for new record
	if final_floor > best_floor:
		best_floor = final_floor
		best_floor_timestamp = int(Time.get_unix_time_from_system())
		is_new_record = true
		_save_best_floor()
		print("TowerManager: NEW RECORD! Floor %d" % best_floor)

	tower_run_ended.emit(final_floor, is_new_record, total_rewards)

	# Clear run state
	current_team.clear()
	current_floor = 0
	team_hp_state.clear()
	run_total_rewards.clear()

	print("TowerManager: Run ended at floor %d (Record: %d)" % [final_floor, best_floor])

func get_current_floor() -> int:
	return current_floor

func get_best_floor() -> int:
	return best_floor

func is_run_active() -> bool:
	return current_run_active

func is_boss_floor(floor_num: int = -1) -> bool:
	if floor_num < 0:
		floor_num = current_floor
	return floor_num > 0 and (floor_num % BOSS_FLOOR_INTERVAL == 0)

func is_milestone_floor(floor_num: int = -1) -> bool:
	if floor_num < 0:
		floor_num = current_floor
	return floor_num in MILESTONE_FLOORS

func get_floor_difficulty_rating(floor_num: int) -> String:
	"""Get a difficulty rating string for display"""
	if floor_num <= 10:
		return "Normal"
	elif floor_num <= 25:
		return "Hard"
	elif floor_num <= 50:
		return "Expert"
	elif floor_num <= 100:
		return "Master"
	elif floor_num <= 200:
		return "Nightmare"
	elif floor_num <= 500:
		return "Inferno"
	else:
		return "Abyss"

# === ENEMY GENERATION ===

func _create_scaled_enemy(floor_num: int, is_boss: bool) -> Dictionary:
	"""Create a scaled enemy for the given floor"""
	if enemy_templates.is_empty():
		return _create_default_enemy(floor_num, is_boss)

	# Pick random enemy template
	var template_name = enemy_templates[randi() % enemy_templates.size()]

	# Calculate scaled stats
	var base_level = BASE_ENEMY_LEVEL + int(floor_num * LEVEL_SCALING_PER_FLOOR)
	var stat_multiplier = pow(STAT_SCALING_PER_FLOOR, floor_num)

	# Boss multiplier
	if is_boss:
		stat_multiplier *= 2.5
		base_level = int(base_level * 1.5)

	# Base stats that scale with level
	var base_hp = 100 + (base_level * 8)
	var base_atk = 40 + (base_level * 3)
	var base_def = 30 + (base_level * 2)
	var base_spd = 45 + (base_level * 1)

	# Apply multiplier
	var hp = int(base_hp * stat_multiplier)
	var atk = int(base_atk * stat_multiplier)
	var def = int(base_def * stat_multiplier)
	var spd = int(base_spd * stat_multiplier)

	# Element rotation based on floor
	var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
	var element = elements[floor_num % elements.size()]

	var enemy_name = template_name if not is_boss else "Tower Guardian"
	if is_boss:
		enemy_name = _get_boss_name(floor_num)

	return {
		"id": "tower_enemy_%d_%d" % [floor_num, randi()],
		"name": enemy_name,
		"level": base_level,
		"pantheon": "tower",
		"element": element,
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": [],
		"is_boss": is_boss,
		"floor": floor_num
	}

func _create_default_enemy(floor_num: int, is_boss: bool) -> Dictionary:
	"""Create a default enemy when no templates available"""
	var base_level = BASE_ENEMY_LEVEL + int(floor_num * LEVEL_SCALING_PER_FLOOR)
	var stat_multiplier = pow(STAT_SCALING_PER_FLOOR, floor_num)

	if is_boss:
		stat_multiplier *= 2.5
		base_level = int(base_level * 1.5)

	var hp = int((100 + base_level * 8) * stat_multiplier)
	var atk = int((40 + base_level * 3) * stat_multiplier)
	var def = int((30 + base_level * 2) * stat_multiplier)
	var spd = int((45 + base_level * 1) * stat_multiplier)

	return {
		"id": "tower_enemy_%d_%d" % [floor_num, randi()],
		"name": _get_boss_name(floor_num) if is_boss else "Tower Sentinel",
		"level": base_level,
		"pantheon": "tower",
		"element": "neutral",
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": [],
		"is_boss": is_boss,
		"floor": floor_num
	}

func _get_boss_name(floor_num: int) -> String:
	"""Get boss name based on floor milestone"""
	if floor_num >= 1000:
		return "Primordial Titan"
	elif floor_num >= 500:
		return "Abyssal Overlord"
	elif floor_num >= 200:
		return "Infernal Archon"
	elif floor_num >= 100:
		return "Nightmare Lord"
	elif floor_num >= 50:
		return "Master Guardian"
	elif floor_num >= 20:
		return "Elite Warden"
	else:
		return "Tower Guardian"

# === REWARDS ===

func _calculate_floor_rewards(floor_num: int) -> Dictionary:
	"""Calculate rewards for completing a floor based on floor cleared"""
	var rewards = {}

	# Exponential scaling for mana/gold (more rewarding at higher floors)
	var base_mana = 150
	var base_gold = 75
	var floor_multiplier = pow(1.05, floor_num)  # 5% compound growth per floor

	rewards["mana"] = int(base_mana * floor_multiplier)
	rewards["gold"] = int(base_gold * floor_multiplier)

	# === TIER-BASED REWARDS (based on floor brackets) ===
	var tier = _get_floor_tier(floor_num)

	# Crafting materials based on tier
	match tier:
		1:  # Floors 1-10: T1 raw materials
			if randf() < 0.4:
				rewards["ore"] = randi_range(2, 5)
			if randf() < 0.3:
				rewards["wood"] = randi_range(2, 5)
			if randf() < 0.3:
				rewards["herbs"] = randi_range(2, 5)
		2:  # Floors 11-25: T1 processed + chance at T2 raw
			if randf() < 0.5:
				rewards["refined_metal"] = randi_range(1, 3)
			if randf() < 0.3:
				rewards["monster_parts"] = randi_range(1, 2)
			if randf() < 0.2:
				rewards["fine_ore"] = randi_range(1, 2)
		3:  # Floors 26-50: T2 materials
			if randf() < 0.5:
				rewards["fine_ore"] = randi_range(2, 4)
			if randf() < 0.4:
				rewards["beast_scales"] = randi_range(1, 3)
			if randf() < 0.3:
				rewards["steel_ingot"] = randi_range(1, 2)
		4:  # Floors 51-100: T2 processed + T3 raw
			if randf() < 0.5:
				rewards["steel_ingot"] = randi_range(2, 4)
			if randf() < 0.4:
				rewards["forging_flame"] = randi_range(1, 2)
			if randf() < 0.25:
				rewards["arcane_ore"] = randi_range(1, 2)
		_:  # Floors 100+: T3+ materials
			if randf() < 0.5:
				rewards["arcane_ore"] = randi_range(2, 5)
			if randf() < 0.4:
				rewards["elemental_cores"] = randi_range(1, 3)
			if randf() < 0.3:
				rewards["prometheum"] = randi_range(1, 2)
			if randf() < 0.2:
				rewards["divine_flame"] = randi_range(1, 2)

	# Element powder drops (random element)
	if randf() < 0.25 + (floor_num * 0.005):  # Increases with floor
		var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
		var powder_id = elements[randi() % elements.size()] + "_powder"
		@warning_ignore("integer_division")
		rewards[powder_id] = randi_range(1, 3 + floor_num / 20)

	# Soul drops based on floor progression
	if floor_num >= 5 and randf() < 0.15:
		rewards["common_soul"] = randi_range(1, 2)
	if floor_num >= 25 and randf() < 0.1:
		rewards["rare_soul"] = 1
	if floor_num >= 75 and randf() < 0.05:
		rewards["epic_soul"] = 1

	# Awakening essence at higher floors
	if floor_num >= 20 and randf() < 0.1 + (floor_num * 0.002):
		@warning_ignore("integer_division")
		rewards["awakening_essence"] = randi_range(1, 2 + floor_num / 50)

	# === BOSS FLOOR BONUSES (every 10 floors) ===
	if is_boss_floor(floor_num):
		rewards["mana"] = int(rewards["mana"] * 2.5)
		rewards["gold"] = int(rewards["gold"] * 2.5)
		@warning_ignore("integer_division")
		rewards["divine_crystals"] = 3 + floor_num / 5

		# Guaranteed soul based on boss floor
		if floor_num <= 20:
			rewards["common_soul"] = rewards.get("common_soul", 0) + 1
		elif floor_num <= 50:
			rewards["rare_soul"] = rewards.get("rare_soul", 0) + 1
		elif floor_num <= 100:
			rewards["epic_soul"] = rewards.get("epic_soul", 0) + 1
		else:
			rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 1

		# Boss-specific material drops
		if floor_num >= 30:
			rewards["divine_essence"] = randi_range(1, 3)
		if floor_num >= 60:
			rewards["socket_crystal"] = 1

	# === MILESTONE FLOOR REWARDS ===
	if is_milestone_floor(floor_num):
		rewards["divine_crystals"] = rewards.get("divine_crystals", 0) + _get_milestone_crystals(floor_num)

		# Milestone-specific rewards
		match floor_num:
			10:
				rewards["rare_soul"] = rewards.get("rare_soul", 0) + 1
				rewards["basic_flame"] = 2
			25:
				rewards["epic_soul"] = 1
				rewards["forging_flame"] = 2
			50:
				rewards["epic_soul"] = rewards.get("epic_soul", 0) + 2
				rewards["socket_crystal"] = rewards.get("socket_crystal", 0) + 2
			100:
				rewards["legendary_soul"] = 1
				rewards["divine_flame"] = 2
				rewards["divine_essence"] = rewards.get("divine_essence", 0) + 5
			150:
				rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 1
				rewards["prometheum"] = rewards.get("prometheum", 0) + 5
			200:
				rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 2
				rewards["astral_shard"] = 3
			250:
				rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 2
				rewards["eternal_flame"] = 1
			500:
				rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 3
				rewards["divine_metal"] = 2
				rewards["eternal_flame"] = rewards.get("eternal_flame", 0) + 2
			1000:
				rewards["legendary_soul"] = rewards.get("legendary_soul", 0) + 5
				rewards["divine_metal"] = 5
				rewards["eternal_flame"] = rewards.get("eternal_flame", 0) + 3
				rewards["ascension_crystal"] = 1

	return rewards

func _get_floor_tier(floor_num: int) -> int:
	"""Get the tier bracket for a floor"""
	if floor_num <= 10:
		return 1
	elif floor_num <= 25:
		return 2
	elif floor_num <= 50:
		return 3
	elif floor_num <= 100:
		return 4
	else:
		return 5

func _get_milestone_crystals(floor_num: int) -> int:
	"""Get divine crystal bonus for milestone floors"""
	match floor_num:
		10: return 20
		25: return 35
		50: return 50
		100: return 100
		150: return 150
		200: return 200
		250: return 300
		500: return 500
		1000: return 1000
		_: return 50

func _award_rewards(rewards: Dictionary):
	"""Award rewards to the player"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return

	for resource_id in rewards:
		resource_manager.add_resource(resource_id, rewards[resource_id])

# === BATTLE INTEGRATION ===

func create_tower_battle_config() -> BattleConfig:
	"""Create a battle config for the current floor"""
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.TOWER
	config.attacker_team = current_team.duplicate()
	config.defender_team = get_current_floor_enemies()
	config.max_turns = 100  # More turns for tower battles
	config.allow_auto_battle = true
	config.allow_speed_up = true
	config.victory_condition = "defeat_all_enemies"
	config.defeat_condition = "all_gods_defeated"

	# Store floor info in metadata
	config.set_meta("tower_floor", current_floor)
	config.set_meta("is_boss_floor", is_boss_floor())

	# Store HP overrides for persistent HP between floors
	config.set_meta("hp_overrides", team_hp_state.duplicate())

	return config

func save_team_hp_from_battle(battle_state) -> void:
	"""Save current HP from battle state for next floor"""
	if not battle_state:
		return

	for unit in battle_state.get_player_units():
		if unit.source_god:
			team_hp_state[unit.source_god.id] = unit.current_hp
			print("TowerManager: Saved HP for %s: %d/%d" % [unit.display_name, unit.current_hp, unit.max_hp])

func get_hp_override(god_id: String) -> int:
	"""Get HP override for a god (-1 means use max HP)"""
	return team_hp_state.get(god_id, -1)

func get_team_health_status() -> Dictionary:
	"""Get current HP status of the team (persists between floors)"""
	var status = {}
	for god in current_team:
		var max_hp = god.base_hp if god.has_method("get") else god.get("base_hp", 100)
		status[god.id] = {
			"current_hp": god.get("current_hp") if god.has_method("get") else max_hp,
			"max_hp": max_hp,
			"is_alive": (god.get("current_hp") if god.has_method("get") else max_hp) > 0
		}
	return status
