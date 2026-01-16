# scripts/systems/battle/CombatCalculator.gd
# Consolidated damage calculation and stat computation - replaces multiple scattered implementations
class_name CombatCalculator extends RefCounted

## Calculate damage between attacker and target
static func calculate_damage(attacker: BattleUnit, target: BattleUnit, skill: Skill = null) -> DamageResult:
	var base_attack = attacker.attack
	var defense = target.defense
	var multiplier = skill.get_damage_multiplier() if skill else 1.0
	
	# Summoners War damage formula: ATK * Multiplier * (1000 / (1140 + 3.5 * DEF))
	var raw_damage = base_attack * multiplier * (1000.0 / (1140.0 + 3.5 * defense))
	
	# Check for critical hit
	var is_critical = _check_critical_hit(attacker, target)
	if is_critical:
		raw_damage *= (1.0 + attacker.crit_damage / 100.0)
	
	# Check for glancing hit (opposite of critical)
	var is_glancing = not is_critical and randf() < 0.15  # 15% glancing chance
	if is_glancing:
		raw_damage *= 0.7  # Glancing hits do 70% damage
	
	# Apply random variance (±10%)
	var variance = randf_range(0.9, 1.1)
	raw_damage *= variance
	
	# Convert to integer
	var final_damage = max(1, int(raw_damage))
	
	return DamageResult.new(final_damage, is_critical, is_glancing)

## Calculate total stats for a god (base + equipment + buffs)
static func calculate_total_stats(god: God) -> Dictionary:
	# Start with base stats
	var stats = {
		"hp": god.base_hp,
		"attack": god.base_attack,
		"defense": god.base_defense,
		"speed": god.base_speed,
		"crit_rate": god.base_crit_rate,
		"crit_damage": god.base_crit_damage,
		"accuracy": god.base_accuracy,
		"resistance": god.base_resistance
	}
	
	# Apply level scaling
	var level_multiplier = 1.0 + (god.level - 1) * 0.1  # +10% per level
	stats.hp = int(stats.hp * level_multiplier)
	stats.attack = int(stats.attack * level_multiplier)
	stats.defense = int(stats.defense * level_multiplier)
	
	# Equipment stats not yet implemented
	return stats

## Get element multiplier for damage calculation
static func _get_element_multiplier(attacker_element: God.ElementType, target_element: God.ElementType) -> float:
	# Simplified elemental advantage system
	match attacker_element:
		God.ElementType.FIRE:
			return 1.3 if target_element == God.ElementType.EARTH else 0.85 if target_element == God.ElementType.WATER else 1.0
		God.ElementType.WATER:
			return 1.3 if target_element == God.ElementType.FIRE else 0.85 if target_element == God.ElementType.EARTH else 1.0
		God.ElementType.EARTH:
			return 1.3 if target_element == God.ElementType.WATER else 0.85 if target_element == God.ElementType.FIRE else 1.0
		God.ElementType.LIGHT:
			return 1.3 if target_element == God.ElementType.DARK else 1.0
		God.ElementType.DARK:
			return 1.3 if target_element == God.ElementType.LIGHT else 1.0
		_:
			return 1.0

## Check if attack is a critical hit
static func _check_critical_hit(attacker: BattleUnit, _target: BattleUnit) -> bool:
	var base_crit_rate = attacker.crit_rate
	var effective_crit_rate = base_crit_rate  # Could apply accuracy vs resistance here
	return randf() * 100.0 < effective_crit_rate

## Calculate healing amount
static func calculate_healing(healer: BattleUnit, _target: BattleUnit, skill: Skill) -> int:
	var heal_power = healer.attack
	var multiplier = skill.get_damage_multiplier() if skill else 1.0
	
	var base_heal = heal_power * multiplier
	var final_heal = int(base_heal * randf_range(0.95, 1.05))  # ±5% variance
	
	return max(1, final_heal)

## Get detailed attack breakdown for UI/debugging
static func get_detailed_attack_breakdown(god: God) -> Dictionary:
	var base_attack = god.base_attack
	var level_bonus = int(base_attack * (god.level - 1) * 0.1)
	var equipment_bonus = 0  # Not implemented
	var buff_bonus = 0  # Not implemented
	
	return {
		"base_value": base_attack,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_attack + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed defense breakdown for UI/debugging
static func get_detailed_defense_breakdown(god: God) -> Dictionary:
	var base_defense = god.base_defense
	var level_bonus = int(base_defense * (god.level - 1) * 0.1)
	var equipment_bonus = 0  # Not implemented
	var buff_bonus = 0  # Not implemented
	
	return {
		"base_value": base_defense,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_defense + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed HP breakdown for UI/debugging
static func get_detailed_hp_breakdown(god: God) -> Dictionary:
	var base_hp = god.base_hp
	var level_bonus = int(base_hp * (god.level - 1) * 0.1)
	var equipment_bonus = 0  # Not implemented
	var buff_bonus = 0  # Not implemented
	
	return {
		"base_value": base_hp,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_hp + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed speed breakdown for UI/debugging
static func get_detailed_speed_breakdown(god: God) -> Dictionary:
	var base_speed = god.base_speed
	var level_bonus = 0  # Speed typically doesn't scale with level in SW
	var equipment_bonus = 0  # Not implemented
	var buff_bonus = 0  # Not implemented
	
	return {
		"base_value": base_speed,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_speed + level_bonus + equipment_bonus + buff_bonus
	}

## Calculate total power rating for a god (RULE 3 compliance - logic in calculator, not data class)
static func calculate_total_power(god: God) -> int:
	# Base power from stats (HP + ATK + DEF) / 3
	var base_power = (god.base_hp + god.base_attack + god.base_defense) / 3.0
	
	# Level bonus: 50 power per level (from prompt specification)
	var level_bonus = god.level * 50
	
	# Tier bonus: 500 power per tier (from prompt specification)
	var tier_bonus = god.tier * 500
	
	# Total power calculation
	var total_power = base_power + level_bonus + tier_bonus
	
	return int(total_power)
