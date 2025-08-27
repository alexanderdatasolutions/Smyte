# scripts/systems/progression/FeatureUnlockManager.gd
# Single responsibility: Manage feature unlocking based on player level
class_name FeatureUnlockManager extends Node

# ==============================================================================
# FEATURE UNLOCK SYSTEM - Progressive feature unlocking (150 lines target)
# ==============================================================================
# Uses SystemRegistry pattern - listens to PlayerProgressionManager signals
# NO direct GameManager access

signal feature_unlocked(feature_name: String, feature_data: Dictionary)

# Feature unlock levels configuration
var feature_unlock_levels: Dictionary = {
	2: "summon",
	3: "sacrifice", 
	5: "territory_management",
	10: "dungeon",
	15: "arena",
	20: "guild",
	25: "raid",
	30: "world_boss",
	35: "pvp_tournament",
	40: "legendary_summon"
}

# Feature introduction data
var feature_introductions: Dictionary = {
	"summon": {
		"title": "Summoning Portal",
		"message": "You can now summon new gods! Visit the summoning portal to expand your collection."
	},
	"sacrifice": {
		"title": "Sacrifice System", 
		"message": "Sacrifice gods to awaken and strengthen your favorites!"
	},
	"territory_management": {
		"title": "Territory Management",
		"message": "Assign gods to territories to generate resources automatically!"
	},
	"dungeon": {
		"title": "Dungeons Unlocked",
		"message": "Challenge dungeons for rare equipment and upgrade materials!"
	},
	"arena": {
		"title": "Arena PvP",
		"message": "Test your gods against other players in the Arena!"
	}
}

func _ready():
	name = "FeatureUnlockManager"
	print("FeatureUnlockManager: Initializing feature unlock system...")
	
	# Listen to player progression events
	var player_progression = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if player_progression:
		player_progression.player_leveled_up.connect(_on_player_level_up)
	
	# Check for any features that should already be unlocked
	_validate_unlocked_features()

func _on_player_level_up(old_level: int, new_level: int):
	"""Handle player level up - unlock appropriate features"""
	print("FeatureUnlockManager: Player leveled up from %d to %d" % [old_level, new_level])
	
	# Check for features to unlock in the new level range
	for level in range(old_level + 1, new_level + 1):
		if feature_unlock_levels.has(level):
			var feature_name = feature_unlock_levels[level]
			unlock_feature(feature_name)

func unlock_feature(feature_name: String):
	"""Unlock a specific feature and show introduction"""
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if not save_manager:
		push_error("FeatureUnlockManager: SaveManager not found")
		return
	
	var player_data = save_manager.get_player_data()
	if not player_data:
		return
	
	# Ensure unlocked features structure exists
	if not player_data.has("unlocked_features"):
		player_data["unlocked_features"] = {}
	
	var unlocked_features = player_data["unlocked_features"]
	
	# Skip if already unlocked
	if unlocked_features.has(feature_name):
		return
	
	# Mark as unlocked
	unlocked_features[feature_name] = true
	save_manager.save_player_data(player_data)
	
	# Get feature data
	var feature_data = get_feature_data(feature_name)
	
	print("FeatureUnlockManager: Feature unlocked - %s" % feature_name)
	
	# Emit unlock signal
	feature_unlocked.emit(feature_name, feature_data)
	
	# Show introduction if first time
	if should_show_introduction(feature_name):
		_show_feature_introduction(feature_name, feature_data)

func is_feature_unlocked(feature_name: String) -> bool:
	"""Check if a feature is unlocked"""
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if not save_manager:
		return false
	
	var player_data = save_manager.get_player_data()
	if not player_data:
		return false
	
	var unlocked_features = player_data.get("unlocked_features", {})
	return unlocked_features.has(feature_name)

func get_required_level_for_feature(feature_name: String) -> int:
	"""Get the level required to unlock a feature"""
	for level in feature_unlock_levels:
		if feature_unlock_levels[level] == feature_name:
			return level
	return 999  # Feature not found

func get_unlocked_features_for_level(level: int) -> Array:
	"""Get all features that should be unlocked at a given level"""
	var features = []
	for unlock_level in feature_unlock_levels:
		if unlock_level <= level:
			features.append(feature_unlock_levels[unlock_level])
	return features

func get_feature_data(feature_name: String) -> Dictionary:
	"""Get data for a specific feature"""
	return {
		"name": feature_name,
		"required_level": get_required_level_for_feature(feature_name),
		"introduction": feature_introductions.get(feature_name, {}),
		"unlocked": is_feature_unlocked(feature_name)
	}

func should_show_introduction(_feature_name: String) -> bool:
	"""Check if we should show introduction for this feature"""
	# For now, always show introduction on first unlock
	# Could be expanded to check tutorial settings
	return true

func _show_feature_introduction(feature_name: String, _feature_data: Dictionary):
	"""Show feature introduction through notification system"""
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	if notification_manager:
		var intro_data = feature_introductions.get(feature_name, {})
		notification_manager.show_feature_unlock_notification(
			intro_data.get("title", feature_name.capitalize()),
			intro_data.get("message", "New feature unlocked!")
		)

func _validate_unlocked_features():
	"""Ensure all features for current level are unlocked"""
	var player_progression = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if not player_progression:
		return
	
	var current_level = player_progression.get_current_level()
	var features_for_level = get_unlocked_features_for_level(current_level)
	
	for feature_name in features_for_level:
		if not is_feature_unlocked(feature_name):
			# Silently unlock without showing introduction (catch-up)
			_unlock_feature_silently(feature_name)

func _unlock_feature_silently(feature_name: String):
	"""Unlock a feature without showing introduction (for catch-up)"""
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if not save_manager:
		return
	
	var player_data = save_manager.get_player_data()
	if not player_data:
		return
	
	if not player_data.has("unlocked_features"):
		player_data["unlocked_features"] = {}
	
	player_data["unlocked_features"][feature_name] = true
	save_manager.save_player_data(player_data)
