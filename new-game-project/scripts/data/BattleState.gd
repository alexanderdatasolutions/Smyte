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

# Combat highlights (for achievements, rare rewards)
var max_single_hit: int = 0          # Highest damage in one hit
var player_units_died: int = 0       # How many player gods died during battle

# Team bonuses (calculated from team composition)
var team_bonuses: Array = []

# Team bonus effects (status effect chances, life steal, etc.)
# These are extracted separately for combat hooks
var team_bonus_effects: Dictionary = {
	"life_steal": 0.0,         # % of damage healed
	"stun_chance": 0.0,        # % chance to stun on attack
	"burn_chance": 0.0,        # % chance to burn on attack
	"freeze_chance": 0.0,      # % chance to freeze on attack
	"poison_chance": 0.0,      # % chance to poison on attack
	"dodge_chance": 0.0,       # % chance to dodge attacks (evasion)
	"counter_chance": 0.0,     # % chance to counter-attack when hit
	"reflect_damage": 0.0,     # % of damage reflected back
}

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
	# Track max single hit for achievements
	if damage > max_single_hit:
		max_single_hit = damage

## Record damage received by player units
func record_damage_received(damage: int) -> void:
	total_damage_received += damage

## Record enemy unit defeat
func record_unit_defeat() -> void:
	units_defeated += 1

## Record player unit death
func record_player_unit_death() -> void:
	player_units_died += 1

## Get lowest HP percentage among surviving player units
func get_lowest_surviving_hp_percent() -> float:
	var lowest: float = 1.0
	for unit: BattleUnit in player_units:
		if unit.is_alive and unit.max_hp > 0:
			var hp_percent: float = float(unit.current_hp) / float(unit.max_hp)
			if hp_percent < lowest:
				lowest = hp_percent
	return lowest

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

	# Get leader skill info from first god
	var leader_skill_info: Dictionary = TeamStatsCalculator.get_leader_skill_info(attacker_team)
	var leader_skill: Dictionary = leader_skill_info.get("skill", {})

	# Aggregate all stat bonuses from team bonuses
	var stat_mults: Dictionary = {"attack": 1.0, "defense": 1.0, "speed": 1.0, "hp": 1.0}
	var stat_adds: Dictionary = {"crit_rate": 0.0, "crit_damage": 0.0, "resistance": 0.0, "accuracy": 0.0}

	# Reset team bonus effects
	team_bonus_effects = {
		"life_steal": 0.0,
		"stun_chance": 0.0,
		"burn_chance": 0.0,
		"freeze_chance": 0.0,
		"poison_chance": 0.0,
		"dodge_chance": 0.0,
		"counter_chance": 0.0,
		"reflect_damage": 0.0,
	}

	# Extract leader skill effects (applied to all qualifying units)
	# Leader skill bonuses are stored as integers (e.g., 12 = 12%), convert to decimal
	var leader_bonuses_raw: Dictionary = leader_skill.get("bonuses", {})
	if leader_bonuses_raw.has("life_steal"):
		team_bonus_effects.life_steal += float(leader_bonuses_raw.life_steal) / 100.0
	if leader_bonuses_raw.has("stun_chance"):
		team_bonus_effects.stun_chance += float(leader_bonuses_raw.stun_chance) / 100.0
	if leader_bonuses_raw.has("burn_chance"):
		team_bonus_effects.burn_chance += float(leader_bonuses_raw.burn_chance) / 100.0
	if leader_bonuses_raw.has("freeze_chance"):
		team_bonus_effects.freeze_chance += float(leader_bonuses_raw.freeze_chance) / 100.0
	if leader_bonuses_raw.has("poison_chance"):
		team_bonus_effects.poison_chance += float(leader_bonuses_raw.poison_chance) / 100.0
	if leader_bonuses_raw.has("dodge_chance"):
		team_bonus_effects.dodge_chance += float(leader_bonuses_raw.dodge_chance) / 100.0
	if leader_bonuses_raw.has("counter_chance"):
		team_bonus_effects.counter_chance += float(leader_bonuses_raw.counter_chance) / 100.0
	if leader_bonuses_raw.has("reflect_damage"):
		team_bonus_effects.reflect_damage += float(leader_bonuses_raw.reflect_damage) / 100.0

	for bonus: Dictionary in team_bonuses:
		var bonuses: Dictionary = bonus.get("bonuses", {})
		# Multiplicative stats
		if bonuses.has("attack"):
			stat_mults.attack += bonuses.attack
		if bonuses.has("defense"):
			stat_mults.defense += bonuses.defense
		if bonuses.has("speed"):
			stat_mults.speed += bonuses.speed
		if bonuses.has("hp"):
			stat_mults.hp += bonuses.hp
		if bonuses.has("all_stats"):
			stat_mults.attack += bonuses.all_stats
			stat_mults.defense += bonuses.all_stats
			stat_mults.speed += bonuses.all_stats
			stat_mults.hp += bonuses.all_stats

		# Additive stats (percentage points)
		if bonuses.has("crit_rate"):
			stat_adds.crit_rate += bonuses.crit_rate
		if bonuses.has("crit_damage"):
			stat_adds.crit_damage += bonuses.crit_damage
		if bonuses.has("resistance"):
			stat_adds.resistance += bonuses.resistance
		if bonuses.has("accuracy"):
			stat_adds.accuracy += bonuses.accuracy

		# Extract effect-type bonuses (status effect chances, life steal, etc.)
		if bonuses.has("life_steal"):
			team_bonus_effects.life_steal += bonuses.life_steal
		if bonuses.has("stun_chance"):
			team_bonus_effects.stun_chance += bonuses.stun_chance
		if bonuses.has("burn_chance"):
			team_bonus_effects.burn_chance += bonuses.burn_chance
		if bonuses.has("freeze_chance"):
			team_bonus_effects.freeze_chance += bonuses.freeze_chance
		if bonuses.has("poison_chance"):
			team_bonus_effects.poison_chance += bonuses.poison_chance
		if bonuses.has("dodge_chance"):
			team_bonus_effects.dodge_chance += bonuses.dodge_chance
		if bonuses.has("counter_chance"):
			team_bonus_effects.counter_chance += bonuses.counter_chance
		if bonuses.has("reflect_damage"):
			team_bonus_effects.reflect_damage += bonuses.reflect_damage

	# Apply stat multipliers to each player unit (including leader skill bonuses)
	for i: int in range(player_units.size()):
		var unit: BattleUnit = player_units[i]
		var source_god: God = attacker_team[i] if i < attacker_team.size() else null

		# Start with team bonuses
		var unit_attack_mult: float = stat_mults.attack
		var unit_defense_mult: float = stat_mults.defense
		var unit_speed_mult: float = stat_mults.speed
		var unit_hp_mult: float = stat_mults.hp

		# Apply leader skill bonuses if applicable to this unit
		if source_god and not leader_skill.is_empty():
			var leader_bonuses: Dictionary = TeamStatsCalculator.get_leader_skill_bonuses(leader_skill, source_god)
			if leader_bonuses.has("attack"):
				unit_attack_mult += leader_bonuses.attack
			if leader_bonuses.has("defense"):
				unit_defense_mult += leader_bonuses.defense
			if leader_bonuses.has("speed"):
				unit_speed_mult += leader_bonuses.speed
			if leader_bonuses.has("hp"):
				unit_hp_mult += leader_bonuses.hp
			# Apply other leader skill bonuses (crit_rate, resistance, accuracy)
			if leader_bonuses.has("crit_rate"):
				unit.crit_rate = int(unit.crit_rate + leader_bonuses.crit_rate * 100)
			if leader_bonuses.has("crit_damage"):
				unit.crit_damage = int(unit.crit_damage + leader_bonuses.crit_damage * 100)
			if leader_bonuses.has("resistance"):
				unit.resistance = int(unit.resistance + leader_bonuses.resistance * 100)
			if leader_bonuses.has("accuracy"):
				unit.accuracy = int(unit.accuracy + leader_bonuses.accuracy * 100)

		# Apply team bonus additive stats (crit_rate, crit_damage, resistance, accuracy)
		unit.crit_rate = int(unit.crit_rate + stat_adds.crit_rate * 100)
		unit.crit_damage = int(unit.crit_damage + stat_adds.crit_damage * 100)
		unit.resistance = int(unit.resistance + stat_adds.resistance * 100)
		unit.accuracy = int(unit.accuracy + stat_adds.accuracy * 100)

		# Store original HP for comparison
		var original_max_hp: int = unit.max_hp

		# Apply multipliers
		unit.attack = int(unit.attack * unit_attack_mult)
		unit.defense = int(unit.defense * unit_defense_mult)
		unit.speed = int(unit.speed * unit_speed_mult)
		unit.max_hp = int(unit.max_hp * unit_hp_mult)

		# Only refresh HP if not using HP overrides (Tower mode)
		if unit.current_hp == original_max_hp:
			unit.current_hp = unit.max_hp
