# scripts/systems/SacrificeSystem.gd
extends Node
class_name SacrificeSystem

signal sacrifice_completed(target_god: God, material_gods: Array, xp_gained: int)
signal sacrifice_failed(reason: String)

static var _config: Dictionary = {}

static func _load_config() -> void:
	if not _config.is_empty():
		return
	var file: FileAccess = FileAccess.open("res://data/sacrifice_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed
			return
	push_warning("SacrificeSystem: sacrifice_config.json not found, using defaults")
	_config = {}

static func _get_bonuses() -> Dictionary:
	_load_config()
	return _config.get("bonuses", {})

static func _get_base_value_formula() -> Dictionary:
	_load_config()
	return _config.get("base_value_formula", {})

static func _get_tier_base_values() -> Dictionary:
	_load_config()
	return _config.get("tier_base_values", {})

static func _get_high_level_scaling() -> Dictionary:
	_load_config()
	return _config.get("high_level_scaling", {})

static func _get_xp_curve() -> Dictionary:
	_load_config()
	return _config.get("xp_curve", {})

func calculate_sacrifice_experience(material_gods: Array, target_god: God = null) -> Dictionary:
	var result: Dictionary = {
		"total_xp": 0,
		"bonus_details": [],
		"god_values": []
	}

	var bonuses: Dictionary = _get_bonuses()
	var same_god_mult: float = bonuses.get("same_god_multiplier", 3.0)
	var same_element_mult: float = bonuses.get("same_element_multiplier", 1.5)

	for material_god: Variant in material_gods:
		var base_xp: int = get_god_base_sacrifice_value(material_god)
		var bonus_multiplier: float = 1.0
		var bonus_text: String = ""

		if target_god:
			if material_god.id == target_god.id:
				bonus_multiplier = same_god_mult
				bonus_text = " (Same God Bonus: %sx)" % str(same_god_mult)
			elif material_god.element == target_god.element:
				bonus_multiplier = same_element_mult
				bonus_text = " (Same Element Bonus: %sx)" % str(same_element_mult)

		var final_xp: int = int(base_xp * bonus_multiplier)
		result.total_xp += final_xp

		result.god_values.append({
			"god": material_god,
			"base_xp": base_xp,
			"bonus_multiplier": bonus_multiplier,
			"final_xp": final_xp,
			"bonus_text": bonus_text
		})

	return result

func get_god_base_sacrifice_value(god: God) -> int:
	var formula: Dictionary = _get_base_value_formula()
	var level_xp_mult: int = formula.get("level_xp_multiplier", 15)

	var level_xp: int = god.level * god.level * level_xp_mult
	var tier_base: int = get_tier_base_value(god.tier)
	var base_xp: int = level_xp + tier_base

	var scaling: Dictionary = _get_high_level_scaling()
	var thresholds: Array = scaling.get("thresholds", [])
	for threshold: Variant in thresholds:
		if threshold is Dictionary:
			var lvl: int = int(threshold.get("level", 99))
			var mult: float = threshold.get("multiplier", 1.0)
			if god.level >= lvl:
				base_xp = int(base_xp * mult)

	return base_xp

func get_tier_base_value(tier: God.TierType) -> int:
	var tier_values: Dictionary = _get_tier_base_values()
	match tier:
		God.TierType.COMMON:
			return int(tier_values.get("common", 500))
		God.TierType.RARE:
			return int(tier_values.get("rare", 1500))
		God.TierType.EPIC:
			return int(tier_values.get("epic", 4000))
		God.TierType.LEGENDARY:
			return int(tier_values.get("legendary", 10000))
		_:
			return int(tier_values.get("mythic", 500))

func calculate_levels_gained(target_god: God, xp_gain: int) -> int:
	if not target_god:
		return 0

	var current_level: int = target_god.level
	var current_xp: int = target_god.experience
	var remaining_xp: int = xp_gain
	var levels_gained: int = 0
	var max_level: int = God.get_max_level()

	while remaining_xp > 0 and (current_level + levels_gained) < max_level:
		var next_level: int = current_level + levels_gained + 1
		var xp_needed_for_next: int = get_sw_style_xp_requirement(next_level)

		if levels_gained == 0:
			xp_needed_for_next -= current_xp

		if remaining_xp >= xp_needed_for_next:
			remaining_xp -= xp_needed_for_next
			levels_gained += 1
		else:
			break

	return levels_gained

func get_sw_style_xp_requirement(level: int) -> int:
	if level <= 1:
		return 0

	var curve: Dictionary = _get_xp_curve()
	var base_xp: float = curve.get("base_xp", 200.0)
	var default_exp: float = curve.get("default_exponent", 2.2)
	var high_level_exp: float = curve.get("high_level_exponent", 2.5)
	var level_ranges: Array = curve.get("level_ranges", [])
	var cost_multipliers: Array = curve.get("high_level_cost_multipliers", [])

	var exponent: float = default_exp

	# Check level ranges for exponent override (sorted by max_level ascending)
	var found_range: bool = false
	for range_def: Variant in level_ranges:
		if range_def is Dictionary:
			var max_lvl: int = int(range_def.get("max_level", 0))
			var range_exp: float = range_def.get("exponent", default_exp)
			if level <= max_lvl:
				exponent = range_exp
				found_range = true
				break

	if not found_range:
		exponent = high_level_exp

	var total_xp: int = int(base_xp * pow(level - 1, exponent))

	# Apply high level cost multipliers sequentially
	for mult_def: Variant in cost_multipliers:
		if mult_def is Dictionary:
			var mult_level: int = int(mult_def.get("level", 99))
			var mult_value: float = mult_def.get("multiplier", 1.0)
			if level >= mult_level:
				total_xp = int(total_xp * mult_value)

	return total_xp

func perform_sacrifice(target_god: God, material_gods: Array, player_data: Variant) -> bool:
	if not target_god or material_gods.is_empty() or not player_data:
		sacrifice_failed.emit("Invalid sacrifice parameters")
		return false

	var sacrifice_result: Dictionary = calculate_sacrifice_experience(material_gods, target_god)
	var total_xp: int = sacrifice_result.total_xp

	var collection_manager: Variant = player_data
	for material_god: Variant in material_gods:
		collection_manager.remove_god(material_god)

	var system_registry: Variant = SystemRegistry.get_instance()
	if not system_registry:
		sacrifice_failed.emit("SystemRegistry not available")
		return false
	var god_progression_manager: Variant = system_registry.get_system("GodProgressionManager")
	if not god_progression_manager:
		sacrifice_failed.emit("GodProgressionManager not available")
		return false
	god_progression_manager.add_experience_to_god(target_god, total_xp)

	sacrifice_completed.emit(target_god, material_gods, total_xp)
	return true

func get_sacrifice_preview_text(target_god: God, material_gods: Array) -> String:
	if not target_god or material_gods.is_empty():
		return "Select target and material gods to see experience gain"

	var sacrifice_result: Dictionary = calculate_sacrifice_experience(material_gods, target_god)
	var levels_gained: int = calculate_levels_gained(target_god, sacrifice_result.total_xp)

	var preview_text: String = "Total XP Gain: %d (+%d levels)\n\nBreakdown:\n" % [
		sacrifice_result.total_xp,
		levels_gained
	]

	for god_value: Variant in sacrifice_result.god_values:
		preview_text += "- %s: %d XP%s\n" % [
			god_value.god.name,
			god_value.final_xp,
			god_value.bonus_text
		]

	return preview_text

func validate_sacrifice(target_god: God, material_gods: Array) -> Dictionary:
	var result: Dictionary = {
		"can_sacrifice": true,
		"errors": []
	}

	if not target_god:
		result.can_sacrifice = false
		result.errors.append("No target god selected")

	if material_gods.is_empty():
		result.can_sacrifice = false
		result.errors.append("No material gods selected")

	if target_god and material_gods.has(target_god):
		result.can_sacrifice = false
		result.errors.append("Cannot use target god as material")

	if target_god and target_god.level >= God.get_max_level():
		result.can_sacrifice = false
		result.errors.append("Target god is already max level")

	return result
