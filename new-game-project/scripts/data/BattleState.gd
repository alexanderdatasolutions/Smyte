# scripts/data/BattleState.gd
# Contains the complete state of a battle - units, turn order, etc.
class_name BattleState extends RefCounted

# Battle units
var player_units: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []
var all_units: Array[BattleUnit] = []

# Battle flow state
var current_turn: int = 0
var battle_start_time: int = 0
var current_wave: int = 1
var max_waves: int = 1

# Battle context
var battle_type: String = ""
var battle_id: String = ""

# Statistics tracking
var total_damage_dealt: int = 0
var total_damage_received: int = 0
var units_defeated: int = 0
var skills_used: int = 0

# Team bonuses (calculated from team composition)
var team_bonuses: Array = []

func _init():
	battle_start_time = Time.get_ticks_msec()

## Setup battle state from configuration
func setup_from_config(config: BattleConfig) -> void:
	battle_type = BattleConfig.BattleType.keys()[config.battle_type]
	battle_id = config.dungeon_name if not config.dungeon_name.is_empty() else config.territory_id

	# Check for HP overrides (used by Tower mode for persistent HP)
	var hp_overrides: Dictionary = {}
	if config.has_meta("hp_overrides"):
		hp_overrides = config.get_meta("hp_overrides")

	# Create player units from attacker team
	player_units.clear()
	for god: God in config.attacker_team:
		if god:
			var unit: BattleUnit = BattleUnit.from_god(god)

			# Apply HP override if available (for Tower persistent HP)
			if hp_overrides.has(god.id):
				var override_hp: int = hp_overrides[god.id]
				if override_hp > 0:
					unit.current_hp = min(override_hp, unit.max_hp)
				elif override_hp == 0:
					# God died in previous floor - keep them dead
					unit.current_hp = 0
					unit.is_alive = false

			player_units.append(unit)
			all_units.append(unit)

	# Calculate and apply team bonuses
	_calculate_and_apply_team_bonuses(config.attacker_team)

	# Create enemy units based on battle type
	enemy_units.clear()
	if not config.defender_team.is_empty():
		# Defender team can contain God objects or Dictionary enemy data
		for defender in config.defender_team:
			if defender:
				var unit: BattleUnit
				# Check if it's a God object or Dictionary enemy data
				if defender is God:
					unit = BattleUnit.from_god(defender)
					unit.is_player_unit = false  # Override for enemy team
				elif defender is Dictionary:
					unit = BattleUnit.from_enemy(defender)
				else:
					push_warning("BattleState: Unknown defender type: ", typeof(defender))
					continue

				enemy_units.append(unit)
				all_units.append(unit)
	else:
		# PvE battle - create units from first wave
		max_waves = config.get_wave_count()
		if not config.enemy_waves.is_empty():
			_setup_wave_enemies(config.enemy_waves[0])  # Start with first wave

## Setup enemies for a specific wave
func _setup_wave_enemies(wave_enemies: Array) -> void:
	# Clear existing enemy units
	for unit: BattleUnit in enemy_units:
		all_units.erase(unit)
	enemy_units.clear()

	# Create new enemy units for this wave
	for enemy_data: Dictionary in wave_enemies:
		var unit: BattleUnit = BattleUnit.from_enemy(enemy_data)
		enemy_units.append(unit)
		all_units.append(unit)

## Advance to next wave (for PvE battles)
func advance_to_next_wave(next_wave_enemies: Array) -> bool:
	if current_wave >= max_waves:
		return false  # No more waves
	
	current_wave += 1
	_setup_wave_enemies(next_wave_enemies)
	return true

## Get all living units
func get_living_units() -> Array[BattleUnit]:
	var living: Array[BattleUnit] = []
	for unit: BattleUnit in all_units:
		if unit.is_alive:
			living.append(unit)
	return living

## Get all living player units
func get_living_player_units() -> Array[BattleUnit]:
	var living: Array[BattleUnit] = []
	for unit: BattleUnit in player_units:
		if unit.is_alive:
			living.append(unit)
	return living

## Get all living enemy units
func get_living_enemy_units() -> Array[BattleUnit]:
	var living: Array[BattleUnit] = []
	for unit: BattleUnit in enemy_units:
		if unit.is_alive:
			living.append(unit)
	return living

## Get all player units (alive and dead)
func get_player_units() -> Array[BattleUnit]:
	return player_units.duplicate()

## Get all enemy units (alive and dead)
func get_enemy_units() -> Array[BattleUnit]:
	return enemy_units.duplicate()

## Get all units (alive and dead)
func get_all_units() -> Array[BattleUnit]:
	return all_units.duplicate()

## Check if all player units are defeated
func all_player_units_defeated() -> bool:
	return get_living_player_units().is_empty()

## Check if all enemy units are defeated
func all_enemy_units_defeated() -> bool:
	return get_living_enemy_units().is_empty()

## Check if battle should end
func should_battle_end() -> bool:
	return all_player_units_defeated() or (all_enemy_units_defeated() and current_wave >= max_waves)

## Get battle duration in seconds
func get_battle_duration() -> float:
	return (Time.get_ticks_msec() - battle_start_time) / 1000.0

## Record damage dealt by player units
func record_damage_dealt(damage: int) -> void:
	total_damage_dealt += damage

## Record damage received by player units
func record_damage_received(damage: int) -> void:
	total_damage_received += damage

## Record unit defeat
func record_unit_defeat() -> void:
	units_defeated += 1

## Record skill use
func record_skill_use() -> void:
	skills_used += 1

## Check if any player units have died during battle
func has_unit_deaths() -> bool:
	for unit: BattleUnit in player_units:
		if not unit.is_alive:
			return true
	return false

## Get unit by ID
func get_unit_by_id(unit_id: String) -> BattleUnit:
	for unit: BattleUnit in all_units:
		if unit.unit_id == unit_id:
			return unit
	return null

## Get battle statistics
func get_battle_statistics() -> Dictionary:
	return {
		"current_turn": current_turn,
		"duration": get_battle_duration(),
		"total_damage_dealt": total_damage_dealt,
		"total_damage_received": total_damage_received,
		"units_defeated": units_defeated,
		"skills_used": skills_used,
		"current_wave": current_wave,
		"max_waves": max_waves,
		"player_units_alive": get_living_player_units().size(),
		"enemy_units_alive": get_living_enemy_units().size()
	}

## Process end of turn for all units
func process_end_of_turn() -> void:
	current_turn += 1

	# Process status effects and cooldowns for all living units
	for unit: BattleUnit in get_living_units():
		unit.process_status_effects()
		unit.tick_cooldowns()
		unit.tick_immunity()  # Will set immunity countdown
		unit.tick_vengeance()  # Nemesis vengeance stacks decay

## Get units sorted by speed (for turn order)
func get_units_by_speed() -> Array[BattleUnit]:
	var living_units: Array[BattleUnit] = get_living_units()
	living_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.speed > b.speed)
	return living_units

## Find valid targets for a skill
func find_valid_targets(caster: BattleUnit, skill: Skill) -> Array[BattleUnit]:
	var valid_targets: Array[BattleUnit] = []

	if skill.targets_enemies:
		if caster.is_player_unit:
			valid_targets = get_living_enemy_units()
		else:
			valid_targets = get_living_player_units()
	else:
		# Targets allies
		if caster.is_player_unit:
			valid_targets = get_living_player_units()
		else:
			valid_targets = get_living_enemy_units()

	return valid_targets

## Clean up battle state
func cleanup() -> void:
	player_units.clear()
	enemy_units.clear()
	all_units.clear()

## Calculate team bonuses and apply stat modifiers to player units
func _calculate_and_apply_team_bonuses(attacker_team: Array) -> void:
	# Get team bonuses from TeamStatsCalculator
	team_bonuses = TeamStatsCalculator.get_team_bonuses(attacker_team)

	if team_bonuses.is_empty():
		return

	# Aggregate all stat bonuses from team bonuses
	var stat_mults: Dictionary = {"attack": 1.0, "defense": 1.0, "speed": 1.0, "hp": 1.0}

	for bonus: Dictionary in team_bonuses:
		var bonuses: Dictionary = bonus.get("bonuses", {})
		if bonuses.has("attack"):
			stat_mults.attack += bonuses.attack
		if bonuses.has("defense"):
			stat_mults.defense += bonuses.defense
		if bonuses.has("speed"):
			stat_mults.speed += bonuses.speed
		if bonuses.has("all_stats"):
			stat_mults.attack += bonuses.all_stats
			stat_mults.defense += bonuses.all_stats
			stat_mults.speed += bonuses.all_stats
			stat_mults.hp += bonuses.all_stats

	# Apply stat multipliers to each player unit
	for unit: BattleUnit in player_units:
		unit.attack = int(unit.attack * stat_mults.attack)
		unit.defense = int(unit.defense * stat_mults.defense)
		unit.speed = int(unit.speed * stat_mults.speed)
		unit.max_hp = int(unit.max_hp * stat_mults.hp)
		# Only refresh HP if not using HP overrides (Tower mode)
		if unit.current_hp == unit.max_hp / stat_mults.hp:
			unit.current_hp = unit.max_hp
