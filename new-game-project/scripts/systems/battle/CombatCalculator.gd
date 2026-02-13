# scripts/systems/battle/CombatCalculator.gd
# Consolidated damage calculation and stat computation - replaces multiple scattered implementations
class_name CombatCalculator extends RefCounted

# --- Damage Formula Constants (Summoners War style) ---
const DAMAGE_NUMERATOR: float = 1000.0
const DAMAGE_DENOMINATOR_BASE: float = 1140.0
const DAMAGE_DEFENSE_SCALE: float = 3.5

# --- Hit Type Constants ---
const GLANCING_HIT_CHANCE: float = 0.15
const GLANCING_DAMAGE_MULT: float = 0.7
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1

# --- Element Constants ---
const ELEMENT_ADVANTAGE_MULT: float = 1.3
const ELEMENT_DISADVANTAGE_MULT: float = 0.85

# --- Healing Constants ---
const HEAL_VARIANCE_MIN: float = 0.95
const HEAL_VARIANCE_MAX: float = 1.05

# --- Stat Scaling Constants ---
const LEVEL_STAT_SCALE: float = 0.1  # +10% per level
const POWER_PER_LEVEL: int = 50
const POWER_PER_TIER: int = 500

## Calculate damage between attacker and target
static func calculate_damage(attacker: BattleUnit, target: BattleUnit, skill: Skill = null) -> DamageResult:
	var base_attack: int = attacker.attack
	var defense: int = target.defense
	var multiplier: float = skill.get_damage_multiplier() if skill else 1.0

	# Summoners War damage formula: ATK * Multiplier * (NUM / (BASE + SCALE * DEF))
	var base_damage: float = base_attack * multiplier * (DAMAGE_NUMERATOR / (DAMAGE_DENOMINATOR_BASE + DAMAGE_DEFENSE_SCALE * defense))

	# Check for critical hit
	var is_critical: bool = _check_critical_hit(attacker, target)
	var crit_mult: float = 1.0
	if is_critical:
		crit_mult = 1.0 + attacker.crit_damage / 100.0
		base_damage *= crit_mult

	# Check for glancing hit (opposite of critical)
	var is_glancing: bool = not is_critical and randf() < GLANCING_HIT_CHANCE
	var glancing_mult: float = 1.0
	if is_glancing:
		glancing_mult = GLANCING_DAMAGE_MULT
		base_damage *= glancing_mult

	# Apply element advantage/disadvantage
	var attacker_element := _get_unit_element(attacker)
	var target_element := _get_unit_element(target)
	var element_mult := _get_element_multiplier(attacker_element, target_element)
	base_damage *= element_mult

	# Store raw damage before variance
	var raw_damage: float = base_damage

	# Apply random variance
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	base_damage *= variance

	# Convert to integer
	var final_damage: int = max(1, int(base_damage))

	# Create result with all details
	var result := DamageResult.new(final_damage, is_critical, is_glancing)

	# Populate detailed breakdown for tooltips
	result.attacker_attack = base_attack
	result.target_defense = defense
	result.skill_multiplier = multiplier
	result.crit_multiplier = crit_mult
	result.glancing_multiplier = glancing_mult
	result.element_multiplier = element_mult
	result.variance_multiplier = variance
	result.raw_damage = raw_damage
	result.attacker_name = attacker.display_name
	result.target_name = target.display_name
	result.skill_name = skill.name if skill else ""

	return result

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
	var level_multiplier: float = 1.0 + (god.level - 1) * LEVEL_STAT_SCALE
	stats.hp = int(stats.hp * level_multiplier)
	stats.attack = int(stats.attack * level_multiplier)
	stats.defense = int(stats.defense * level_multiplier)
	
	# Equipment stats not yet implemented
	return stats

## Get element type from a BattleUnit (from source god or enemy data)
static func _get_unit_element(unit: BattleUnit) -> God.ElementType:
	if unit.source_god:
		return unit.source_god.element
	var element_str: String = unit.source_enemy.get("element", "")
	if not element_str.is_empty() and element_str != "neutral":
		return God.string_to_element(element_str)
	return God.ElementType.LIGHT  # Default fallback (neutral)

## Get element multiplier for damage calculation
## Fire > Earth > Water > Fire, Lightning neutral, Light <> Dark
static func _get_element_multiplier(attacker_element: God.ElementType, target_element: God.ElementType) -> float:
	match attacker_element:
		God.ElementType.FIRE:
			return ELEMENT_ADVANTAGE_MULT if target_element == God.ElementType.EARTH else ELEMENT_DISADVANTAGE_MULT if target_element == God.ElementType.WATER else 1.0
		God.ElementType.WATER:
			return ELEMENT_ADVANTAGE_MULT if target_element == God.ElementType.FIRE else ELEMENT_DISADVANTAGE_MULT if target_element == God.ElementType.EARTH else 1.0
		God.ElementType.EARTH:
			return ELEMENT_ADVANTAGE_MULT if target_element == God.ElementType.WATER else ELEMENT_DISADVANTAGE_MULT if target_element == God.ElementType.FIRE else 1.0
		God.ElementType.LIGHT:
			return ELEMENT_ADVANTAGE_MULT if target_element == God.ElementType.DARK else 1.0
		God.ElementType.DARK:
			return ELEMENT_ADVANTAGE_MULT if target_element == God.ElementType.LIGHT else 1.0
		_:
			return 1.0

## Check if attack is a critical hit
static func _check_critical_hit(attacker: BattleUnit, _target: BattleUnit) -> bool:
	var base_crit_rate: float = attacker.crit_rate
	var effective_crit_rate: float = base_crit_rate  # Could apply accuracy vs resistance here
	return randf() * 100.0 < effective_crit_rate

## Calculate healing amount
static func calculate_healing(healer: BattleUnit, _target: BattleUnit, skill: Skill) -> int:
	var heal_power: int = healer.attack
	var multiplier: float = skill.get_damage_multiplier() if skill else 1.0

	var base_heal: float = heal_power * multiplier
	var final_heal: int = int(base_heal * randf_range(HEAL_VARIANCE_MIN, HEAL_VARIANCE_MAX))

	return max(1, final_heal)

## Get detailed attack breakdown for UI/debugging
static func get_detailed_attack_breakdown(god: God) -> Dictionary:
	var base_attack: int = god.base_attack
	var level_bonus: int = int(base_attack * (god.level - 1) * LEVEL_STAT_SCALE)
	var equipment_bonus: int = 0  # Not implemented
	var buff_bonus: int = 0  # Not implemented
	
	return {
		"base_value": base_attack,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_attack + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed defense breakdown for UI/debugging
static func get_detailed_defense_breakdown(god: God) -> Dictionary:
	var base_defense: int = god.base_defense
	var level_bonus: int = int(base_defense * (god.level - 1) * LEVEL_STAT_SCALE)
	var equipment_bonus: int = 0  # Not implemented
	var buff_bonus: int = 0  # Not implemented
	
	return {
		"base_value": base_defense,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_defense + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed HP breakdown for UI/debugging
static func get_detailed_hp_breakdown(god: God) -> Dictionary:
	var base_hp: int = god.base_hp
	var level_bonus: int = int(base_hp * (god.level - 1) * LEVEL_STAT_SCALE)
	var equipment_bonus: int = 0  # Not implemented
	var buff_bonus: int = 0  # Not implemented
	
	return {
		"base_value": base_hp,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_hp + level_bonus + equipment_bonus + buff_bonus
	}

## Get detailed speed breakdown for UI/debugging
static func get_detailed_speed_breakdown(god: God) -> Dictionary:
	var base_speed: int = god.base_speed
	var level_bonus: int = 0  # Speed typically doesn't scale with level in SW
	var equipment_bonus: int = 0  # Not implemented
	var buff_bonus: int = 0  # Not implemented
	
	return {
		"base_value": base_speed,
		"level_bonus": level_bonus,
		"equipment_bonus": equipment_bonus,
		"buff_bonus": buff_bonus,
		"final_value": base_speed + level_bonus + equipment_bonus + buff_bonus
	}

## Calculate total power rating for a god (RULE 3 compliance - logic in calculator, not data class)
static func calculate_total_power(god: God) -> int:
	var base_power: float = (god.base_hp + god.base_attack + god.base_defense) / 3.0
	var level_bonus: int = god.level * POWER_PER_LEVEL
	var tier_bonus: int = god.tier * POWER_PER_TIER
	var total_power: float = base_power + level_bonus + tier_bonus

	return int(total_power)
