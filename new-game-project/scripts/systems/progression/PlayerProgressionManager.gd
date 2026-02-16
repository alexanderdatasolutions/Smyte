# scripts/systems/progression/PlayerProgressionManager.gd
extends Node
class_name PlayerProgressionManager

# ==============================================================================
# PLAYER PROGRESSION MANAGER - Player leveling (150 lines max)
# ==============================================================================
# Single responsibility: Handle player XP and level progression
# Uses SystemRegistry pattern for clean architecture

signal player_leveled_up(old_level: int, new_level: int)
signal experience_gained(amount: int)

# Player Level Configuration
const MAX_PLAYER_LEVEL = 50
const XP_BASE_AMOUNT = 100
const XP_SCALING_FACTOR = 1.15

# Feature unlock levels - simplified
var feature_unlock_levels: Dictionary = {
	2: "summon",
	3: "sacrifice", 
	5: "territory_management",
	10: "dungeon",
	15: "arena"
}

var current_player_level: int = 1
var current_experience: int = 0
var unlocked_features: Array[String] = []

func _ready() -> void:
	pass

# ==============================================================================
# EXPERIENCE MANAGEMENT - SystemRegistry Pattern
# ==============================================================================

func add_experience(amount: int) -> void:
	current_experience += amount
	experience_gained.emit(amount)

	var new_level: int = calculate_level_from_experience(current_experience)
	if new_level > current_player_level:
		_level_up(new_level)

func calculate_level_from_experience(total_xp: int) -> int:
	var level: int = 1
	var xp_needed: int = 0

	while level < MAX_PLAYER_LEVEL:
		var xp_for_next_level: int = int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, level - 1))
		if total_xp < xp_needed + xp_for_next_level:
			break
		xp_needed += xp_for_next_level
		level += 1

	return level

func get_xp_for_next_level() -> int:
	if current_player_level >= MAX_PLAYER_LEVEL:
		return 0

	var total_xp_needed: int = 0
	for i: int in range(1, current_player_level + 1):
		total_xp_needed += int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, i - 1))

	return total_xp_needed - current_experience

func _level_up(new_level: int) -> void:
	var old_level: int = current_player_level
	current_player_level = new_level
	player_leveled_up.emit(old_level, new_level)
	_check_feature_unlocks(new_level)

# ==============================================================================
# FEATURE UNLOCKING - Clean separation
# ==============================================================================

func _check_feature_unlocks(level: int) -> void:
	if feature_unlock_levels.has(level):
		var feature_name: String = feature_unlock_levels[level]
		unlock_feature(feature_name)

func unlock_feature(feature_name: String) -> void:
	if feature_name in unlocked_features:
		return
	unlocked_features.append(feature_name)

func is_feature_unlocked(feature_name: String) -> bool:
	return feature_name in unlocked_features

func get_player_level() -> int:
	return current_player_level

func get_player_experience() -> int:
	return current_experience

# ==============================================================================
# SAVE/LOAD INTEGRATION
# ==============================================================================

func get_save_data() -> Dictionary:
	return {
		"level": current_player_level,
		"experience": current_experience,
		"unlocked_features": unlocked_features
	}

func load_save_data(data: Dictionary) -> void:
	current_player_level = int(data.get("level", 1))
	current_experience = int(data.get("experience", 0))
	var raw_features: Array = data.get("unlocked_features", [])
	unlocked_features.clear()
	for f: Variant in raw_features:
		if f is String:
			unlocked_features.append(f)
