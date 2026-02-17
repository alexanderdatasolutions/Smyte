# scripts/systems/collection/GodCalculator.gd
# Single responsibility: Calculate god stats and ratings
extends RefCounted
class_name GodCalculator

# ==============================================================================
# GOD STAT CALCULATOR - Clean separation of data and logic
# ==============================================================================

# Cached config from data/progression_config.json
static var _config: Dictionary = {}
static var _config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	var file := FileAccess.open("res://data/progression_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed as Dictionary
	_config_loaded = true

static func _get_level_scale(stat_name: String) -> float:
	_load_config()
	var scaling: Dictionary = _config.get("stat_scaling", {}).get("level_scaling_per_level", {})
	return scaling.get(stat_name, 0.1)

static func get_current_hp(god: God) -> int:
	var base: int = god.base_hp
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("hp"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "hp")
	var modifier: float = _get_stat_modifier(god, "hp")
	var ascension_bonus: float = get_ascension_bonus(god, "hp")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_max_hp(god: God) -> int:
	return get_current_hp(god)  # Same as current for now

static func get_current_attack(god: God) -> int:
	var base: int = god.base_attack
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("attack"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "attack")
	var modifier: float = _get_stat_modifier(god, "attack")
	var ascension_bonus: float = get_ascension_bonus(god, "attack")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_defense(god: God) -> int:
	var base: int = god.base_defense
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("defense"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "defense")
	var modifier: float = _get_stat_modifier(god, "defense")
	var ascension_bonus: float = get_ascension_bonus(god, "defense")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_speed(god: God) -> int:
	var base: int = god.base_speed
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("speed"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "speed")
	var modifier: float = _get_stat_modifier(god, "speed")
	var ascension_bonus: float = get_ascension_bonus(god, "speed")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_crit_rate(god: God) -> int:
	var base: int = god.base_crit_rate
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "crit_rate")
	var modifier: float = _get_stat_modifier(god, "crit_rate")

	return mini(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

static func get_current_crit_damage(god: God) -> int:
	var base: int = god.base_crit_damage
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "crit_damage")
	var modifier: float = _get_stat_modifier(god, "crit_damage")

	return int((base + equipment_bonus) * modifier)

static func get_current_accuracy(god: God) -> int:
	var base: int = god.base_accuracy
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "accuracy")
	var modifier: float = _get_stat_modifier(god, "accuracy")

	return mini(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

static func get_current_resistance(god: God) -> int:
	var base: int = god.base_resistance
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "resistance")
	var modifier: float = _get_stat_modifier(god, "resistance")

	return mini(100, int((base + equipment_bonus) * modifier))  # Cap at 100%

# ==============================================================================
# PRIVATE HELPER METHODS
# ==============================================================================

static func _get_equipment_stat_bonus(god: God, stat_type: String) -> int:
	var total_bonus: int = 0

	for i: int in range(god.equipment.size()):
		var eq: Variant = god.equipment[i]
		if eq and eq is Equipment:
			var typed_eq: Equipment = eq as Equipment
			# Main stat bonus
			if typed_eq.main_stat_type.to_lower() == stat_type.to_lower():
				total_bonus += typed_eq.main_stat_value if typed_eq.main_stat_value > 0 else typed_eq.main_stat_base

			# Substat bonuses
			for substat: Dictionary in typed_eq.substats:
				if substat.type.to_lower() == stat_type.to_lower():
					total_bonus += int(substat.value)

	return total_bonus

static func _get_stat_modifier(god: God, stat_name: String) -> float:
	_load_config()
	var modifier: float = 1.0
	var role_modifiers: Dictionary = _config.get("stat_scaling", {}).get("role_modifiers", {})

	var role_data: Dictionary = role_modifiers.get(god.territory_role, {})
	if not role_data.is_empty():
		var affected_stats: Array = role_data.get("stats", [])
		if stat_name in affected_stats:
			modifier += role_data.get("bonus", 0.0)

	return modifier

static func get_ascension_bonus(god: God, _stat_name: String) -> float:
	_load_config()
	var bonus_per_level: float = _config.get("stat_scaling", {}).get("ascension_bonus_per_level", 0.05)
	return god.ascension_level * bonus_per_level

# ==============================================================================
# POWER RATING AND PROGRESSION
# ==============================================================================

static func get_power_rating(god: God) -> int:
	return get_current_hp(god) + get_current_attack(god) + get_current_defense(god) + get_current_speed(god)

static func get_tier_multiplier(god: God) -> float:
	"""Get tier multiplier from progression_config.json - single source of truth"""
	_load_config()
	var tier_mults: Dictionary = _config.get("stat_scaling", {}).get("tier_multipliers", {})
	var tier_name: String = God.tier_to_string(god.tier).to_lower()
	return tier_mults.get(tier_name, 1.0)  # Config is source of truth, 1.0 fallback for unknown

static func get_experience_to_next_level(god: God) -> int:
	var god_exp_calc: GDScript = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	return god_exp_calc.get_experience_to_next_level(god.level)
