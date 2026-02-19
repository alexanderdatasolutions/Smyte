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

# Floor configuration (loaded from data/tower_config.json)
var BASE_ENEMY_LEVEL: int = 1
var LEVEL_SCALING_PER_FLOOR: float = 1.5
var STAT_SCALING_PER_FLOOR: float = 1.08
var ENEMIES_PER_FLOOR: int = 3
var BOSS_FLOOR_INTERVAL: int = 10
var BOSS_STAT_MULTIPLIER: float = 2.5
var BOSS_LEVEL_MULTIPLIER: float = 1.5
var MILESTONE_FLOORS: Array = [10, 25, 50, 100, 150, 200, 250, 500, 1000]

# Base enemy stat formulas (loaded from config)
var _base_hp: int = 100
var _hp_per_level: int = 8
var _base_atk: int = 40
var _atk_per_level: int = 3
var _base_def: int = 30
var _def_per_level: int = 2
var _base_spd: int = 45
var _spd_per_level: int = 1

# Reward config (loaded from config)
var _tower_config: Dictionary = {}

# Enemy pool for tower (scales with floor)
var enemy_templates: Array = []

func _ready():
	_load_tower_config()
	_load_enemy_templates()

func _load_tower_config():
	"""Load tower balance values from data/tower_config.json"""
	var file := FileAccess.open("res://data/tower_config.json", FileAccess.READ)
	if not file:
		return
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	if not config:
		return
	_tower_config = config

	var scaling: Dictionary = config.get("floor_scaling", {})
	BASE_ENEMY_LEVEL = scaling.get("base_enemy_level", BASE_ENEMY_LEVEL)
	LEVEL_SCALING_PER_FLOOR = scaling.get("level_scaling_per_floor", LEVEL_SCALING_PER_FLOOR)
	STAT_SCALING_PER_FLOOR = scaling.get("stat_scaling_per_floor", STAT_SCALING_PER_FLOOR)
	ENEMIES_PER_FLOOR = scaling.get("enemies_per_floor", ENEMIES_PER_FLOOR)
	BOSS_FLOOR_INTERVAL = scaling.get("boss_floor_interval", BOSS_FLOOR_INTERVAL)
	BOSS_STAT_MULTIPLIER = scaling.get("boss_stat_multiplier", BOSS_STAT_MULTIPLIER)
	BOSS_LEVEL_MULTIPLIER = scaling.get("boss_level_multiplier", BOSS_LEVEL_MULTIPLIER)

	var stats: Dictionary = config.get("base_enemy_stats", {})
	_base_hp = stats.get("hp", _base_hp)
	_hp_per_level = stats.get("hp_per_level", _hp_per_level)
	_base_atk = stats.get("attack", _base_atk)
	_atk_per_level = stats.get("attack_per_level", _atk_per_level)
	_base_def = stats.get("defense", _base_def)
	_def_per_level = stats.get("defense_per_level", _def_per_level)
	_base_spd = stats.get("speed", _base_spd)
	_spd_per_level = stats.get("speed_per_level", _spd_per_level)

	var milestones: Array = config.get("milestone_floors", [])
	if not milestones.is_empty():
		MILESTONE_FLOORS = milestones

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

## Save tower data — called by SaveManager during save chain
func get_save_data() -> Dictionary:
	return {
		"best_floor": best_floor,
		"best_floor_timestamp": best_floor_timestamp,
	}

## Load tower data — called by SaveManager during load chain
func load_save_data(data: Dictionary) -> void:
	best_floor = data.get("best_floor", 0)
	best_floor_timestamp = data.get("best_floor_timestamp", 0)

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

	# Start first floor
	advance_to_next_floor()
	return true

func advance_to_next_floor():
	"""Move to the next floor"""
	if not current_run_active:
		return

	current_floor += 1
	floor_started.emit(current_floor)

func get_current_floor_enemies() -> Array:
	"""Generate enemies for the current floor"""
	var enemies: Array = []
	var is_boss: bool = (current_floor % BOSS_FLOOR_INTERVAL == 0)
	var enemy_count: int = 1 if is_boss else ENEMIES_PER_FLOOR

	for i in range(enemy_count):
		var enemy: Dictionary = _create_scaled_enemy(current_floor, is_boss)
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

	# Emit to EventBus for statistics tracking
	var system_registry := SystemRegistry.get_instance()
	if system_registry:
		var event_bus := system_registry.get_system("EventBus")
		if event_bus:
			event_bus.tower_floor_cleared.emit(current_floor)

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

	# Award god XP based on floors cleared (XP is only given at end of run)
	_award_tower_god_experience(final_floor)

	# Check for new record
	if final_floor > best_floor:
		best_floor = final_floor
		best_floor_timestamp = int(Time.get_unix_time_from_system())
		is_new_record = true

	# Emit to EventBus for leaderboard sync and save
	var system_registry := SystemRegistry.get_instance()
	if system_registry:
		var event_bus := system_registry.get_system("EventBus")
		if event_bus:
			event_bus.tower_run_ended.emit(final_floor, is_new_record)
			if is_new_record:
				event_bus.save_requested.emit()

	tower_run_ended.emit(final_floor, is_new_record, total_rewards)

	# Clear run state
	current_team.clear()
	current_floor = 0
	team_hp_state.clear()
	run_total_rewards.clear()

func _award_tower_god_experience(final_floor: int) -> void:
	"""Award XP to all gods that participated in the tower run based on floors cleared"""
	if current_team.is_empty() or final_floor <= 0:
		return

	var system_registry := SystemRegistry.get_instance()
	if not system_registry:
		return

	var god_progression: Node = system_registry.get_system("GodProgressionManager")
	if not god_progression:
		push_warning("TowerManager: GodProgressionManager not found, skipping god XP")
		return

	# Base XP per floor + bonus for boss floors (from config)
	var xp_cfg: Dictionary = _tower_config.get("god_xp_rewards", {})
	var base_xp_per_floor: int = xp_cfg.get("base_xp_per_floor", 50)
	var boss_bonus: int = xp_cfg.get("boss_xp_bonus", 100)
	var total_xp: int = 0

	for floor_num in range(1, final_floor + 1):
		total_xp += base_xp_per_floor
		if floor_num % BOSS_FLOOR_INTERVAL == 0:
			total_xp += boss_bonus

	# Award XP to each god in the team
	for god in current_team:
		if god and god is God:
			god_progression.add_experience_to_god(god, total_xp)

	print("TowerManager: Awarded %d XP to %d gods for reaching floor %d" % [total_xp, current_team.size(), final_floor])

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
	var ratings: Array = _tower_config.get("difficulty_ratings", [])
	for entry in ratings:
		if floor_num <= entry.get("max_floor", 0):
			return entry.get("rating", "Normal")
	return _tower_config.get("difficulty_rating_default", "Abyss")

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
		stat_multiplier *= BOSS_STAT_MULTIPLIER
		base_level = int(base_level * BOSS_LEVEL_MULTIPLIER)

	# Base stats that scale with level
	var base_hp = _base_hp + (base_level * _hp_per_level)
	var base_atk = _base_atk + (base_level * _atk_per_level)
	var base_def = _base_def + (base_level * _def_per_level)
	var base_spd = _base_spd + (base_level * _spd_per_level)

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
		stat_multiplier *= BOSS_STAT_MULTIPLIER
		base_level = int(base_level * BOSS_LEVEL_MULTIPLIER)

	var hp = int((_base_hp + base_level * _hp_per_level) * stat_multiplier)
	var atk = int((_base_atk + base_level * _atk_per_level) * stat_multiplier)
	var def = int((_base_def + base_level * _def_per_level) * stat_multiplier)
	var spd = int((_base_spd + base_level * _spd_per_level) * stat_multiplier)

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
	var boss_names: Array = _tower_config.get("boss_names", [])
	for entry in boss_names:
		if floor_num >= entry.get("min_floor", 0):
			return entry.get("name", "Tower Guardian")
	return _tower_config.get("boss_name_default", "Tower Guardian")

# === REWARDS ===

func _calculate_floor_rewards(floor_num: int) -> Dictionary:
	"""Calculate rewards for completing a floor based on floor cleared"""
	var rewards = {}

	# Exponential scaling for mana/gold (more rewarding at higher floors)
	var reward_cfg: Dictionary = _tower_config.get("rewards", {})
	var base_mana: int = reward_cfg.get("base_mana", 150)
	var base_gold: int = reward_cfg.get("base_gold", 75)
	var floor_multiplier: float = pow(reward_cfg.get("floor_compound_growth", 1.05), floor_num)

	rewards["mana"] = int(base_mana * floor_multiplier)
	rewards["gold"] = int(base_gold * floor_multiplier)

	# === TIER-BASED REWARDS (based on floor brackets) ===
	var tier = _get_floor_tier(floor_num)

	# Crafting materials based on tier (drop rates from config)
	var drop_rates: Dictionary = _tower_config.get("material_drop_rates", {})
	var tier_key: String = "tier_%d" % tier
	var tier_rates: Dictionary = drop_rates.get(tier_key, {})

	# Apply tier-specific material drops from config
	for material_id: String in tier_rates:
		if randf() < tier_rates[material_id]:
			var base_amount: int = 1 + (tier - 1)
			var max_amount: int = 3 + tier
			rewards[material_id] = randi_range(base_amount, max_amount)

	# Element powder drops (random element) - rates from config
	var powder_base: float = reward_cfg.get("element_powder_base_chance", 0.25)
	var powder_per_floor: float = reward_cfg.get("element_powder_chance_per_floor", 0.005)
	if randf() < powder_base + (floor_num * powder_per_floor):
		var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
		var powder_id = elements[randi() % elements.size()] + "_powder"
		@warning_ignore("integer_division")
		rewards[powder_id] = randi_range(1, 3 + floor_num / 20)

	# Soul drops based on floor progression - thresholds from config
	var soul_cfg: Dictionary = reward_cfg.get("soul_thresholds", {})
	var common_soul_cfg: Dictionary = soul_cfg.get("common_soul", {"min_floor": 5, "chance": 0.15})
	var rare_soul_cfg: Dictionary = soul_cfg.get("rare_soul", {"min_floor": 25, "chance": 0.1})
	var epic_soul_cfg: Dictionary = soul_cfg.get("epic_soul", {"min_floor": 75, "chance": 0.05})

	if floor_num >= common_soul_cfg.get("min_floor", 5) and randf() < common_soul_cfg.get("chance", 0.15):
		rewards["common_soul"] = randi_range(1, 2)
	if floor_num >= rare_soul_cfg.get("min_floor", 25) and randf() < rare_soul_cfg.get("chance", 0.1):
		rewards["rare_soul"] = 1
	if floor_num >= epic_soul_cfg.get("min_floor", 75) and randf() < epic_soul_cfg.get("chance", 0.05):
		rewards["epic_soul"] = 1

	# Awakening essence at higher floors - from config
	var essence_min_floor: int = reward_cfg.get("awakening_essence_min_floor", 20)
	var essence_base: float = reward_cfg.get("awakening_essence_base_chance", 0.1)
	var essence_per_floor: float = reward_cfg.get("awakening_essence_chance_per_floor", 0.002)
	if floor_num >= essence_min_floor and randf() < essence_base + (floor_num * essence_per_floor):
		@warning_ignore("integer_division")
		rewards["awakening_essence"] = randi_range(1, 2 + floor_num / 50)

	# === BOSS FLOOR BONUSES (every 10 floors) ===
	if is_boss_floor(floor_num):
		var boss_reward_mult: float = reward_cfg.get("boss_reward_multiplier", 2.5)
		rewards["mana"] = int(rewards["mana"] * boss_reward_mult)
		rewards["gold"] = int(rewards["gold"] * boss_reward_mult)
		@warning_ignore("integer_division")
		rewards["divine_crystals"] = 3 + floor_num / 5

		# Guaranteed soul based on boss floor - thresholds from config
		var boss_thresholds: Dictionary = _tower_config.get("boss_soul_thresholds", {})
		var common_max: int = boss_thresholds.get("common_max_floor", 20)
		var rare_max: int = boss_thresholds.get("rare_max_floor", 50)
		var epic_max: int = boss_thresholds.get("epic_max_floor", 100)

		if floor_num <= common_max:
			rewards["common_soul"] = rewards.get("common_soul", 0) + 1
		elif floor_num <= rare_max:
			rewards["rare_soul"] = rewards.get("rare_soul", 0) + 1
		elif floor_num <= epic_max:
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
	var crystals: Dictionary = _tower_config.get("milestone_crystals", {})
	var key: String = str(floor_num)
	if crystals.has(key):
		return int(crystals[key])
	return 50

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
	var scaling: Dictionary = _tower_config.get("floor_scaling", {})
	config.max_turns = scaling.get("max_turns", 100)  # From config
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

func get_hp_override(god_id: String) -> int:
	"""Get HP override for a god (-1 means use max HP)"""
	return team_hp_state.get(god_id, -1)

func get_team_health_status() -> Dictionary:
	"""Get current HP status of the team (persists between floors)"""
	var status = {}
	for god in current_team:
		var max_hp: int
		var current_hp: int
		if god is God:
			max_hp = god.base_hp
			current_hp = god.current_hp
		else:
			max_hp = god.get("base_hp", 100)
			current_hp = god.get("current_hp", max_hp)
		status[god.id] = {
			"current_hp": current_hp,
			"max_hp": max_hp,
			"is_alive": current_hp > 0
		}
	return status
