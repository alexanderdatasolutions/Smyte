# scripts/systems/battle/CombatCalculator.gd
# Consolidated damage calculation and stat computation - replaces multiple scattered implementations
class_name CombatCalculator extends RefCounted

# --- Cached config from battle_config.json ---
static var _config: Dictionary = {}
static var _config_loaded: bool = false

# --- Load config from battle_config.json (cached after first load) ---
static func _ensure_config_loaded() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	var file := FileAccess.open("res://data/battle_config.json", FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(json_text)
		if parsed is Dictionary:
			_config = parsed.get("battle_config", {})
		else:
			push_warning("CombatCalculator: battle_config.json parse failed, using defaults")
	else:
		push_warning("CombatCalculator: battle_config.json not found, using defaults")

# --- Config accessors with fallback defaults ---
static func _get_damage_formula() -> Dictionary:
	_ensure_config_loaded()
	return _config.get("damage_formula", {"numerator": 1000.0, "denominator_base": 1140.0, "defense_scale": 3.5})

static func _get_hit_types() -> Dictionary:
	_ensure_config_loaded()
	return _config.get("hit_types", {"glancing_chance": 0.15, "glancing_damage_mult": 0.7, "damage_variance_min": 0.9, "damage_variance_max": 1.1})

static func _get_element_multipliers() -> Dictionary:
	_ensure_config_loaded()
	return _config.get("element_multipliers", {"advantage": 1.3, "disadvantage": 0.85})

static func _get_stat_scaling() -> Dictionary:
	_ensure_config_loaded()
	return _config.get("stat_scaling", {"level_stat_scale": 0.1, "power_per_level": 50, "power_per_tier": 500})

## Calculate damage between attacker and target
## Optional battle_state parameter allows applying team bonuses to damage
static func calculate_damage(attacker: BattleUnit, target: BattleUnit, skill: Skill = null, battle_state: BattleState = null) -> DamageResult:
	var formula: Dictionary = _get_damage_formula()
	var hit_config: Dictionary = _get_hit_types()

	# Determine base stat for damage calculation
	var base_attack: int = attacker.get_modified_attack()
	var scaling_stat: String = skill.scaling_stat if skill else "attack"

	# HP Scaling: Use caster's max HP instead of attack (Jormungandr, etc.)
	if scaling_stat == "MAX_HP":
		base_attack = attacker.max_hp

	# Use modified defense (includes status effect buffs/debuffs)
	var defense: int = target.get_modified_defense()
	var multiplier: float = skill.get_damage_multiplier() if skill else 1.0

	# Apply skill's defense ignore (e.g., 30% ignore_def_percent)
	if skill and skill.ignore_def_percent > 0:
		defense = int(defense * (1.0 - skill.ignore_def_percent))

	# Apply Artemis Hunt marked_prey effect - if target is marked, ignore defense %
	if attacker.is_target_marked(target.unit_id):
		var defense_ignore: float = attacker.get_set_effect_value("marked_prey")
		defense = int(defense * (1.0 - defense_ignore))
		attacker.clear_mark(target.unit_id)

	# Summoners War damage formula: ATK * Multiplier * (NUM / (BASE + SCALE * DEF))
	var dmg_numerator: float = formula.get("numerator", 1000.0)
	var dmg_denom_base: float = formula.get("denominator_base", 1140.0)
	var dmg_def_scale: float = formula.get("defense_scale", 3.5)
	var base_damage: float = base_attack * multiplier * (dmg_numerator / (dmg_denom_base + dmg_def_scale * defense))

	# Target Max HP Scaling: Add bonus damage based on enemy's max HP (Anubis-style)
	if scaling_stat == "target_max_hp" and skill:
		var hp_bonus: float = float(target.max_hp) * skill.target_hp_percent
		base_damage += hp_bonus

	# Apply Hermes Ambush effect - first attack deals +40% damage
	if not attacker.first_attack_done and attacker.has_set_effect("ambush"):
		base_damage *= (1.0 + attacker.get_set_effect_value("ambush"))
		attacker.first_attack_done = true

	# Apply Titan Overwhelm effect - bonus damage to targets with less max HP
	if attacker.has_set_effect("overwhelm") and target.max_hp < attacker.max_hp:
		base_damage *= (1.0 + attacker.get_set_effect_value("overwhelm"))

	# Check for critical hit
	var is_critical: bool = _check_critical_hit(attacker, target)
	var crit_mult: float = 1.0
	if is_critical:
		# Use modified crit damage (includes status effect buffs)
		crit_mult = 1.0 + float(attacker.get_modified_crit_damage()) / 100.0
		base_damage *= crit_mult

		# Apply Artemis Hunt - crits mark target for next attack
		if attacker.has_set_effect("marked_prey"):
			attacker.mark_target(target.unit_id)

	# Check for glancing hit (opposite of critical)
	# Skills with always_hit cannot glance
	var glancing_chance: float = hit_config.get("glancing_chance", 0.15)
	var always_hit: bool = skill.always_hit if skill else false
	var is_glancing: bool = not is_critical and not always_hit and randf() < glancing_chance
	var glancing_mult: float = 1.0
	if is_glancing:
		glancing_mult = hit_config.get("glancing_damage_mult", 0.7)
		base_damage *= glancing_mult

	# Apply element advantage/disadvantage
	var attacker_element := _get_unit_element(attacker)
	var target_element := _get_unit_element(target)
	var element_mult := _get_element_multiplier(attacker_element, target_element)
	base_damage *= element_mult

	# Apply team bonus damage modifiers (for player attacks)
	if battle_state and attacker.is_player_unit:
		var team_damage_mult: float = _get_team_damage_multiplier(battle_state.team_bonuses)
		base_damage *= team_damage_mult

	# Apply team resistance (reduces damage for enemy attacks on players)
	if battle_state and target.is_player_unit and not attacker.is_player_unit:
		var team_resist: float = _get_team_resistance(battle_state.team_bonuses)
		base_damage *= (1.0 - team_resist)

	# Apply status effect damage taken modifiers (marked_for_death, analyze_weakness)
	var damage_taken_mult: float = target.get_damage_taken_modifier()
	base_damage *= damage_taken_mult

	# Store raw damage before variance
	var raw_damage: float = base_damage

	# Apply random variance
	var variance_min: float = hit_config.get("damage_variance_min", 0.9)
	var variance_max: float = hit_config.get("damage_variance_max", 1.1)
	var variance: float = randf_range(variance_min, variance_max)
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

## Get team damage multiplier from team bonuses
static func _get_team_damage_multiplier(team_bonuses: Array) -> float:
	var mult: float = 1.0
	for bonus: Dictionary in team_bonuses:
		var bonuses: Dictionary = bonus.get("bonuses", {})
		if bonuses.has("elemental_damage"):
			mult += bonuses.elemental_damage
		if bonuses.has("skill_damage"):
			mult += bonuses.skill_damage
	return mult

## Get team resistance from team bonuses (caps at 50%)
static func _get_team_resistance(team_bonuses: Array) -> float:
	var resist: float = 0.0
	for bonus: Dictionary in team_bonuses:
		var bonuses: Dictionary = bonus.get("bonuses", {})
		if bonuses.has("elemental_resistance"):
			resist += bonuses.elemental_resistance
	return minf(resist, 0.5)  # Cap at 50% reduction

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
	var elem_config: Dictionary = _get_element_multipliers()
	var advantage: float = elem_config.get("advantage", 1.3)
	var disadvantage: float = elem_config.get("disadvantage", 0.85)

	match attacker_element:
		God.ElementType.FIRE:
			return advantage if target_element == God.ElementType.EARTH else disadvantage if target_element == God.ElementType.WATER else 1.0
		God.ElementType.WATER:
			return advantage if target_element == God.ElementType.FIRE else disadvantage if target_element == God.ElementType.EARTH else 1.0
		God.ElementType.EARTH:
			return advantage if target_element == God.ElementType.WATER else disadvantage if target_element == God.ElementType.FIRE else 1.0
		God.ElementType.LIGHT:
			return advantage if target_element == God.ElementType.DARK else 1.0
		God.ElementType.DARK:
			return advantage if target_element == God.ElementType.LIGHT else 1.0
		_:
			return 1.0

## Check if attack is a critical hit
static func _check_critical_hit(attacker: BattleUnit, _target: BattleUnit) -> bool:
	# Use modified crit rate (includes status effect buffs like crit_boost)
	var effective_crit_rate: float = float(attacker.get_modified_crit_rate())
	return randf() * 100.0 < effective_crit_rate

## Get detailed attack breakdown for UI/debugging
static func get_detailed_attack_breakdown(god: God) -> Dictionary:
	var scaling: Dictionary = _get_stat_scaling()
	var level_scale: float = scaling.get("level_stat_scale", 0.1)
	var base_attack: int = god.base_attack
	var level_bonus: int = int(base_attack * (god.level - 1) * level_scale)
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
	var scaling: Dictionary = _get_stat_scaling()
	var level_scale: float = scaling.get("level_stat_scale", 0.1)
	var base_defense: int = god.base_defense
	var level_bonus: int = int(base_defense * (god.level - 1) * level_scale)
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
	var scaling: Dictionary = _get_stat_scaling()
	var level_scale: float = scaling.get("level_stat_scale", 0.1)
	var base_hp: int = god.base_hp
	var level_bonus: int = int(base_hp * (god.level - 1) * level_scale)
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

## Calculate total power rating for a god
## Uses GodCalculator stats (HP + ATK + DEF + SPD) with proper tier/level/equipment scaling
static func calculate_total_power(god: God) -> int:
	return GodCalculator.get_power_rating(god)
