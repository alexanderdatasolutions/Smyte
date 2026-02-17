# scripts/systems/progression/GodProgressionManager.gd
extends Node
class_name GodProgressionManager

# ==============================================================================
# GOD PROGRESSION MANAGER - Individual god leveling and experience (150 lines max)
# ==============================================================================
# Single responsibility: Handle individual god XP, leveling, and stat progression
# Uses SystemRegistry pattern for clean architecture

signal god_leveled_up(god: God, new_level: int, old_level: int)
signal god_experience_gained(god: God, amount: int)
signal god_awakened(god: God)

# God Level Configuration (loaded from data/progression_config.json)
var MAX_GOD_LEVEL: int = 999
var AWAKENED_MAX_LEVEL: int = 999
var XP_BASE_AMOUNT: int = 200
var XP_SCALING_FACTOR: float = 1.2
var XP_SCALING_FACTOR_POST_CAP: float = 1.35
var SOFT_CAP_LEVEL: int = 40

# Level up stat bonuses per tier (loaded from config)
var stat_bonuses_per_level: Dictionary = {
	1: {"attack": 10, "defense": 8, "hp": 25, "speed": 2},
	2: {"attack": 12, "defense": 10, "hp": 30, "speed": 2},
	3: {"attack": 15, "defense": 12, "hp": 40, "speed": 3},
	4: {"attack": 20, "defense": 15, "hp": 50, "speed": 3},
	5: {"attack": 25, "defense": 18, "hp": 65, "speed": 4}
}

# Diminishing returns thresholds
var diminishing_returns_enabled: bool = true
var diminishing_thresholds: Array = [
	{"level": 40, "stat_multiplier": 1.0},
	{"level": 60, "stat_multiplier": 0.5},
	{"level": 80, "stat_multiplier": 0.25},
	{"level": 100, "stat_multiplier": 0.1},
	{"level": 999, "stat_multiplier": 0.05}
]

var event_bus: EventBus
var collection_manager: CollectionManager

func _ready() -> void:
	name = "GodProgressionManager"
	_load_config()
	_initialize_dependencies()

func _load_config() -> void:
	var file: FileAccess = FileAccess.open("res://data/progression_config.json", FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var config: Dictionary = parsed as Dictionary

	var leveling: Dictionary = config.get("god_leveling", {})
	MAX_GOD_LEVEL = int(leveling.get("max_god_level", MAX_GOD_LEVEL))
	AWAKENED_MAX_LEVEL = int(leveling.get("awakened_max_level", AWAKENED_MAX_LEVEL))
	XP_BASE_AMOUNT = int(leveling.get("xp_base_amount", XP_BASE_AMOUNT))
	XP_SCALING_FACTOR = float(leveling.get("xp_scaling_factor", XP_SCALING_FACTOR))
	XP_SCALING_FACTOR_POST_CAP = float(leveling.get("xp_scaling_factor_post_cap", XP_SCALING_FACTOR_POST_CAP))
	SOFT_CAP_LEVEL = int(leveling.get("soft_cap_level", SOFT_CAP_LEVEL))

	var bonuses: Dictionary = config.get("stat_bonuses_per_level", {})
	if not bonuses.is_empty():
		stat_bonuses_per_level.clear()
		for tier_key: String in bonuses:
			stat_bonuses_per_level[int(tier_key)] = bonuses[tier_key]

	# Load diminishing returns config
	var dr_config: Dictionary = config.get("diminishing_returns", {})
	diminishing_returns_enabled = dr_config.get("enabled", true)
	var thresholds_raw: Array = dr_config.get("thresholds", [])
	if not thresholds_raw.is_empty():
		diminishing_thresholds.clear()
		for threshold: Dictionary in thresholds_raw:
			diminishing_thresholds.append({
				"level": int(threshold.get("level", 40)),
				"stat_multiplier": float(threshold.get("stat_multiplier", 1.0))
			})

func _initialize_dependencies() -> void:
	var system_registry: Node = SystemRegistry.get_instance()
	if not system_registry:
		return
	event_bus = system_registry.get_system("EventBus")
	collection_manager = system_registry.get_system("CollectionManager")

# ==============================================================================
# EXPERIENCE MANAGEMENT - Core god progression
# ==============================================================================

func add_experience_to_god(god: God, experience_amount: int) -> void:
	if not god:
		return

	if experience_amount <= 0:
		return
	
	var old_level: int = god.level
	god.experience += experience_amount

	var new_level: int = calculate_level_from_experience(god.experience, god.is_awakened)
	if new_level > old_level:
		_level_up_god(god, old_level, new_level)
	
	god_experience_gained.emit(god, experience_amount)

	if collection_manager:
		collection_manager.update_god(god)
	
	if event_bus:
		event_bus.save_requested.emit()

func calculate_level_from_experience(total_xp: int, is_awakened: bool = false) -> int:
	var level: int = 1
	var xp_needed: int = 0
	var max_level: int = AWAKENED_MAX_LEVEL if is_awakened else MAX_GOD_LEVEL
	
	while level < max_level:
		var xp_for_next_level: int = calculate_xp_for_level(level + 1)
		if total_xp < xp_needed + xp_for_next_level:
			break
		xp_needed += xp_for_next_level
		level += 1
	
	return level

func calculate_xp_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	# Use steeper XP curve past soft cap for diminishing returns
	if target_level > SOFT_CAP_LEVEL:
		# XP required up to soft cap + steeper scaling past it
		var xp_at_cap: int = int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, SOFT_CAP_LEVEL - 2))
		var levels_past_cap: int = target_level - SOFT_CAP_LEVEL
		return int(xp_at_cap * pow(XP_SCALING_FACTOR_POST_CAP, levels_past_cap))
	return int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, target_level - 2))

func calculate_total_xp_for_level(target_level: int, _is_awakened: bool = false) -> int:
	var total_xp: int = 0
	for level: int in range(2, target_level + 1):
		total_xp += calculate_xp_for_level(level)
	return total_xp

func get_xp_to_next_level(god: God) -> int:
	if not god:
		return 0
	
	var max_level: int = AWAKENED_MAX_LEVEL if god.is_awakened else MAX_GOD_LEVEL
	if god.level >= max_level:
		return 0

	var next_level_total_xp: int = calculate_total_xp_for_level(god.level + 1, god.is_awakened)
	return next_level_total_xp - god.experience

# ==============================================================================
# LEVEL UP SYSTEM - Stat progression and bonuses
# ==============================================================================

func _level_up_god(god: God, old_level: int, new_level: int) -> void:
	god.level = new_level

	# Stats are now calculated dynamically via GodCalculator using percentage scaling
	# No flat stat bonuses are added to base stats - this prevents double-dipping

	god_leveled_up.emit(god, new_level, old_level)

	if event_bus:
		event_bus.god_level_up.emit(god.id, new_level, old_level)

	_show_level_up_notification(god, new_level, new_level - old_level)

func _get_stat_multiplier_for_level(level: int) -> float:
	"""Get the diminishing returns stat multiplier for a given level"""
	if not diminishing_returns_enabled:
		return 1.0

	# Find the applicable threshold
	var multiplier: float = 1.0
	for threshold: Dictionary in diminishing_thresholds:
		if level <= threshold.level:
			multiplier = threshold.stat_multiplier
			break
		multiplier = threshold.stat_multiplier

	return multiplier

func can_level_up(god: God) -> bool:
	if not god:
		return false
	
	var max_level: int = AWAKENED_MAX_LEVEL if god.is_awakened else MAX_GOD_LEVEL
	if god.level >= max_level:
		return false

	var xp_needed: int = get_xp_to_next_level(god)
	return xp_needed <= 0

func _show_level_up_notification(god: God, new_level: int, levels_gained: int) -> void:
	var NotificationQueueClass: Variant = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		NotificationQueueClass.show_level_up(god.name, new_level, levels_gained)

# ==============================================================================
# AWAKENING SUPPORT - Extended level progression
# ==============================================================================

func handle_god_awakening(god: God) -> void:
	if not god:
		return

	god.is_awakened = true
	god_awakened.emit(god)

	if collection_manager:
		collection_manager.update_god(god)

	if event_bus:
		event_bus.god_awakened.emit(god.id)

# ==============================================================================
# PROGRESSION INFO - For UI display
# ==============================================================================

func get_progression_info(god: God) -> Dictionary:
	"""Get progression information for UI display"""
	if not god:
		return {}

	var current_mult: float = _get_stat_multiplier_for_level(god.level)
	var next_mult: float = _get_stat_multiplier_for_level(god.level + 1)
	var tier_bonuses: Dictionary = stat_bonuses_per_level.get(god.tier, stat_bonuses_per_level[1])

	return {
		"level": god.level,
		"experience": god.experience,
		"xp_to_next": get_xp_to_next_level(god),
		"stat_multiplier": current_mult,
		"stat_multiplier_percent": int(current_mult * 100),
		"next_level_multiplier": next_mult,
		"is_soft_capped": god.level >= SOFT_CAP_LEVEL,
		"soft_cap_level": SOFT_CAP_LEVEL,
		"next_level_gains": {
			"attack": int(tier_bonuses.get("attack", 0) * next_mult),
			"defense": int(tier_bonuses.get("defense", 0) * next_mult),
			"hp": int(tier_bonuses.get("hp", 0) * next_mult),
			"speed": int(tier_bonuses.get("speed", 0) * next_mult)
		}
	}

# ==============================================================================
# DEBUG - Remove in production
# ==============================================================================

func debug_set_god_level(god: God, target_level: int) -> void:
	"""DEBUG: Instantly set a god to a specific level"""
	if not god:
		return
	var old_level: int = god.level
	god.level = target_level
	god.experience = 0
	_level_up_god(god, old_level, target_level)
	if collection_manager:
		collection_manager.update_god(god)
	print("DEBUG: Set %s to level %d" % [god.name, target_level])
