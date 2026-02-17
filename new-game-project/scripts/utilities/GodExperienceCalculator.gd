class_name GodExperienceCalculator
extends RefCounted

## Single source of truth for all god experience calculations
## Used by CollectionManager, CollectionScreen, and any other system needing XP logic
## Values loaded from data/god_config.json with hardcoded fallback defaults

static var _config: Dictionary = {}
static var _config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	var file := FileAccess.open("res://data/god_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed

static func _get_base_xp() -> int:
	_load_config()
	return _config.get("xp_curve", {}).get("base_xp", 100)

static func _get_level_multiplier() -> float:
	_load_config()
	return _config.get("xp_curve", {}).get("level_multiplier", 1.5)

static func _get_max_level() -> int:
	# Use God class as single source of truth for level config
	return God.get_max_level()

## Calculate what level a god should be based on total experience
static func calculate_level_from_experience(total_xp: int) -> int:
	if total_xp <= 0:
		return 1

	var level: int = 1
	var required_xp: int = 0
	var base_xp: int = _get_base_xp()
	var multiplier: float = _get_level_multiplier()
	var max_level: int = _get_max_level()

	while required_xp < total_xp and level < max_level:
		level += 1
		required_xp += int(base_xp * pow(multiplier, level - 2))

	return level - 1  # Return the last achieved level

## Calculate total experience needed to reach a specific level
static func get_total_experience_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0

	var total_xp: int = 0
	var base_xp: int = _get_base_xp()
	var multiplier: float = _get_level_multiplier()
	for level: int in range(2, target_level + 1):
		total_xp += int(base_xp * pow(multiplier, level - 2))

	return total_xp

## Calculate experience needed to reach next level from current level
static func get_experience_to_next_level(current_level: int) -> int:
	if current_level >= _get_max_level():
		return 0

	return int(_get_base_xp() * pow(_get_level_multiplier(), current_level - 1))

## Calculate experience progress within current level (0.0 to 100.0)
static func get_experience_progress(god: God) -> float:
	if god.level >= _get_max_level():
		return 100.0

	var current_level_xp: int = get_total_experience_for_level(god.level)
	var next_level_xp: int = get_total_experience_for_level(god.level + 1)
	var current_total_xp: int = god.experience

	# Calculate progress within current level
	var level_xp_needed: int = next_level_xp - current_level_xp
	var level_xp_progress: int = current_total_xp - current_level_xp

	if level_xp_needed <= 0:
		return 100.0

	return minf(100.0, maxf(0.0, (float(level_xp_progress) / float(level_xp_needed)) * 100.0))

## Get experience remaining to next level
static func get_experience_remaining_to_next_level(god: God) -> int:
	if god.level >= _get_max_level():
		return 0

	var next_level_total_xp: int = get_total_experience_for_level(god.level + 1)
	return maxi(0, next_level_total_xp - god.experience)
