# scripts/systems/progression/PlayerProgressionManager.gd
extends Node
class_name PlayerProgressionManager

# ==============================================================================
# PLAYER PROGRESSION MANAGER - Player leveling (150 lines max)
# ==============================================================================
# Single responsibility: Handle player XP and level progression
# Uses SystemRegistry pattern for clean architecture

signal player_leveled_up(new_level: int)
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
var unlocked_features: Array = []

func _ready():
	print("PlayerProgressionManager: Player progression system ready")

# ==============================================================================
# EXPERIENCE MANAGEMENT - SystemRegistry Pattern
# ==============================================================================

func add_experience(amount: int):
	"""Add experience to player"""
	current_experience += amount
	experience_gained.emit(amount)
	
	var new_level = calculate_level_from_experience(current_experience)
	if new_level > current_player_level:
		_level_up(new_level)

func calculate_level_from_experience(total_xp: int) -> int:
	"""Calculate level from total experience"""
	var level = 1
	var xp_needed = 0
	
	while level < MAX_PLAYER_LEVEL:
		var xp_for_next_level = int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, level - 1))
		if total_xp < xp_needed + xp_for_next_level:
			break
		xp_needed += xp_for_next_level
		level += 1
	
	return level

func get_xp_for_next_level() -> int:
	"""Get XP needed for next level"""
	if current_player_level >= MAX_PLAYER_LEVEL:
		return 0
	
	var total_xp_needed = 0
	for i in range(1, current_player_level + 1):
		total_xp_needed += int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, i - 1))
	
	return total_xp_needed - current_experience

func _level_up(new_level: int):
	"""Handle player level up"""
	var old_level = current_player_level
	current_player_level = new_level
	
	print("PlayerProgressionManager: Level up! %d -> %d" % [old_level, new_level])
	player_leveled_up.emit(new_level)
	
	# Check for feature unlocks
	_check_feature_unlocks(new_level)
	
	# Save progress
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if save_manager:
		save_manager.save_player_progress({
			"level": current_player_level,
			"experience": current_experience,
			"unlocked_features": unlocked_features
		})

# ==============================================================================
# FEATURE UNLOCKING - Clean separation
# ==============================================================================

func _check_feature_unlocks(level: int):
	"""Check and unlock features for new level"""
	if feature_unlock_levels.has(level):
		var feature_name = feature_unlock_levels[level]
		unlock_feature(feature_name)

func unlock_feature(feature_name: String):
	"""Unlock a specific feature"""
	if feature_name in unlocked_features:
		return
	
	unlocked_features.append(feature_name)
	print("PlayerProgressionManager: Feature unlocked - %s" % feature_name)
	
	# Notify other systems
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.emit_signal("feature_unlocked", feature_name)

func is_feature_unlocked(feature_name: String) -> bool:
	"""Check if feature is unlocked"""
	return feature_name in unlocked_features

func get_player_level() -> int:
	"""Get current player level"""
	return current_player_level

func get_player_experience() -> int:
	"""Get current player experience"""
	return current_experience

# ==============================================================================
# SAVE/LOAD INTEGRATION
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get progression data for saving"""
	return {
		"level": current_player_level,
		"experience": current_experience,
		"unlocked_features": unlocked_features
	}

func load_save_data(data: Dictionary):
	"""Load progression data from save"""
	current_player_level = data.get("level", 1)
	current_experience = data.get("experience", 0)
	unlocked_features = data.get("unlocked_features", [])
	
	print("PlayerProgressionManager: Loaded - Level %d, XP %d" % [current_player_level, current_experience])
