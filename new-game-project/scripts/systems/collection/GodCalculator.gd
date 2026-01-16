# scripts/systems/collection/GodCalculator.gd
# Single responsibility: Calculate god stats and ratings
extends RefCounted
class_name GodCalculator

# ==============================================================================
# GOD STAT CALCULATOR - Clean separation of data and logic
# ==============================================================================

static func get_current_hp(god: God) -> int:
	var base = god.base_hp
	var level_bonus = (god.level - 1) * int(base * 0.1)  # 10% per level
	var equipment_bonus = _get_equipment_stat_bonus(god, "hp")
	var modifier = _get_stat_modifier(god, "hp")
	var ascension_bonus = get_ascension_bonus(god, "hp")
	
	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus))

static func get_max_hp(god: God) -> int:
	return get_current_hp(god)  # Same as current for now

static func get_current_attack(god: God) -> int:
	var base = god.base_attack
	var level_bonus = (god.level - 1) * int(base * 0.1)
	var equipment_bonus = _get_equipment_stat_bonus(god, "attack")
	var modifier = _get_stat_modifier(god, "attack")
	var ascension_bonus = get_ascension_bonus(god, "attack")
	
	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus))

static func get_current_defense(god: God) -> int:
	var base = god.base_defense
	var level_bonus = (god.level - 1) * int(base * 0.1)
	var equipment_bonus = _get_equipment_stat_bonus(god, "defense")
	var modifier = _get_stat_modifier(god, "defense")
	var ascension_bonus = get_ascension_bonus(god, "defense")
	
	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus))

static func get_current_speed(god: God) -> int:
	var base = god.base_speed
	var level_bonus = (god.level - 1) * int(base * 0.05)  # 5% per level for speed
	var equipment_bonus = _get_equipment_stat_bonus(god, "speed")
	var modifier = _get_stat_modifier(god, "speed")
	var ascension_bonus = get_ascension_bonus(god, "speed")
	
	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus))

static func get_current_crit_rate(god: God) -> int:
	var base = god.base_crit_rate
	var equipment_bonus = _get_equipment_stat_bonus(god, "crit_rate")
	var modifier = _get_stat_modifier(god, "crit_rate")
	
	return min(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

static func get_current_crit_damage(god: God) -> int:
	var base = god.base_crit_damage
	var equipment_bonus = _get_equipment_stat_bonus(god, "crit_damage")
	var modifier = _get_stat_modifier(god, "crit_damage")
	
	return int((base + equipment_bonus) * modifier)

static func get_current_accuracy(god: God) -> int:
	var base = god.base_accuracy
	var equipment_bonus = _get_equipment_stat_bonus(god, "accuracy")
	var modifier = _get_stat_modifier(god, "accuracy")
	
	return min(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

static func get_current_resistance(god: God) -> int:
	var base = god.base_resistance
	var equipment_bonus = _get_equipment_stat_bonus(god, "resistance")
	var modifier = _get_stat_modifier(god, "resistance")
	
	return min(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

# ==============================================================================
# PRIVATE HELPER METHODS
# ==============================================================================

static func _get_equipment_stat_bonus(god: God, stat_type: String) -> int:
	var total_bonus = 0
	
	for i in range(god.equipment.size()):
		var equipment = god.equipment[i]
		if equipment and equipment is Equipment:
			# Main stat bonus
			if equipment.main_stat_type.to_lower() == stat_type.to_lower():
				total_bonus += equipment.main_stat_value if equipment.main_stat_value > 0 else equipment.main_stat_base
			
			# Substat bonuses
			for substat in equipment.substats:
				if substat.type.to_lower() == stat_type.to_lower():
					total_bonus += substat.value
	
	return total_bonus

static func _get_stat_modifier(god: God, stat_name: String) -> float:
	var modifier = 1.0
	
	# Territory role bonuses
	match god.territory_role:
		"defender":
			if stat_name in ["hp", "defense"]:
				modifier += 0.15  # 15% bonus to defensive stats
		"gatherer":
			if stat_name == "speed":
				modifier += 0.20  # 20% speed bonus
		"crafter":
			if stat_name == "accuracy":
				modifier += 0.25  # 25% accuracy bonus
	
	return modifier

static func get_ascension_bonus(god: God, _stat_name: String) -> float:
	# Each ascension level provides 5% bonus to all stats
	return god.ascension_level * 0.05

# ==============================================================================
# POWER RATING AND PROGRESSION
# ==============================================================================

static func get_power_rating(god: God) -> int:
	return get_current_hp(god) + get_current_attack(god) + get_current_defense(god) + get_current_speed(god)

static func get_tier_multiplier(god: God) -> float:
	match god.tier:
		God.TierType.COMMON:
			return 1.0
		God.TierType.RARE:
			return 1.2
		God.TierType.EPIC:
			return 1.5
		God.TierType.LEGENDARY:
			return 2.0
		_:
			return 1.0

static func get_experience_to_next_level(god: God) -> int:
	# Use centralized experience calculator
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	return god_exp_calc.get_experience_to_next_level(god.level)
