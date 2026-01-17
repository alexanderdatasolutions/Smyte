# scripts/data/BattleState.gd
# Contains the complete state of a battle - units, turn order, etc.
class_name BattleState extends RefCounted

# Battle units
var player_units: Array = []  # Array[BattleUnit]
var enemy_units: Array = []   # Array[BattleUnit] 
var all_units: Array = []     # Array[BattleUnit]

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

func _init():
	battle_start_time = Time.get_ticks_msec()

## Setup battle state from configuration
func setup_from_config(config: BattleConfig):
	battle_type = BattleConfig.BattleType.keys()[config.battle_type]
	battle_id = config.dungeon_name if not config.dungeon_name.is_empty() else config.territory_id
	
	# Create player units from attacker team
	player_units.clear()
	for god in config.attacker_team:
		if god:
			var unit = BattleUnit.from_god(god)
			player_units.append(unit)
			all_units.append(unit)
	
	# Create enemy units based on battle type
	enemy_units.clear()
	if not config.defender_team.is_empty():
		# Defender team can contain God objects or Dictionary enemy data
		for defender in config.defender_team:
			if defender:
				var unit
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
func _setup_wave_enemies(wave_enemies: Array):
	# Clear existing enemy units
	for unit in enemy_units:
		all_units.erase(unit)
	enemy_units.clear()
	
	# Create new enemy units for this wave
	for enemy_data in wave_enemies:
		var unit = BattleUnit.from_enemy(enemy_data)
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
func get_living_units() -> Array:
	return all_units.filter(func(unit): return unit.is_alive)

## Get all living player units
func get_living_player_units() -> Array:
	return player_units.filter(func(unit): return unit.is_alive)

## Get all living enemy units
func get_living_enemy_units() -> Array:
	return enemy_units.filter(func(unit): return unit.is_alive)

## Get all player units (alive and dead)
func get_player_units() -> Array:
	return player_units.duplicate()

## Get all enemy units (alive and dead)
func get_enemy_units() -> Array:
	return enemy_units.duplicate()

## Get all units (alive and dead)
func get_all_units() -> Array:
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
func record_damage_dealt(damage: int):
	total_damage_dealt += damage

## Record damage received by player units
func record_damage_received(damage: int):
	total_damage_received += damage

## Record unit defeat
func record_unit_defeat():
	units_defeated += 1

## Record skill use
func record_skill_use():
	skills_used += 1

## Check if any player units have died during battle
func has_unit_deaths() -> bool:
	for unit in player_units:
		if not unit.is_alive:
			return true
	return false

## Get unit by ID
func get_unit_by_id(unit_id: String) -> BattleUnit:
	for unit in all_units:
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
func process_end_of_turn():
	current_turn += 1
	
	# Process status effects and cooldowns for all living units
	for unit in get_living_units():
		unit.process_status_effects()
		unit.tick_cooldowns()

## Get units sorted by speed (for turn order)
func get_units_by_speed() -> Array:
	var living_units = get_living_units()
	living_units.sort_custom(func(a, b): return a.speed > b.speed)
	return living_units

## Find valid targets for a skill
func find_valid_targets(caster, skill) -> Array:
	var valid_targets = []
	
	if skill.targets_enemies():
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
	
	# Apply additional targeting restrictions if needed
	# (e.g., lowest HP, highest HP, random, etc.)
	
	return valid_targets

## Clean up battle state
func cleanup():
	player_units.clear()
	enemy_units.clear()
	all_units.clear()
