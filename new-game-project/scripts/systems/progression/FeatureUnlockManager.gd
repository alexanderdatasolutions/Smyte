# scripts/systems/progression/FeatureUnlockManager.gd
# Single responsibility: Manage feature unlocking via achievements
class_name FeatureUnlockManager extends Node

# ==============================================================================
# FEATURE UNLOCK SYSTEM - Achievement-based feature unlocking
# ==============================================================================
# Features are unlocked ONLY via achievements (not player level)
# AchievementManager calls unlock_feature() when achievement with "unlocks" completes

signal feature_unlocked(feature_name: String, feature_data: Dictionary)

# Feature introduction data - shown when feature is first unlocked
var feature_introductions: Dictionary = {
	"territory": {
		"title": "Territory Management",
		"message": "Explore and capture territories to expand your domain!",
		"unlock_source": "first_summon"
	},
	"sacrifice": {
		"title": "Sacrifice System",
		"message": "Sacrifice gods to strengthen others and gain powerful resources!",
		"unlock_source": "first_territory"
	},
	"dungeon": {
		"title": "Dungeons Unlocked",
		"message": "Challenge dungeons for rare equipment and upgrade materials!",
		"unlock_source": "tier2_territory"
	},
	"equipment": {
		"title": "Equipment System",
		"message": "Craft and equip gear to enhance your gods!",
		"unlock_source": "tier2_territory"
	},
	"tower": {
		"title": "Tower of Trials",
		"message": "Climb the tower to earn exclusive rewards!",
		"unlock_source": "tier3_territory"
	},
	"arena": {
		"title": "Arena",
		"message": "Battle other players' teams for glory and rewards!",
		"unlock_source": "tier3_territory"
	},
	"pvp": {
		"title": "PvP Territory Wars",
		"message": "Compete with other players for valuable T4 territories!",
		"unlock_source": "tier4_territory"
	},
	"awakening": {
		"title": "Awakening System",
		"message": "Awaken your gods to unlock their true potential!",
		"unlock_source": "god_level_30"
	}
}

# List of all features that can be unlocked
var all_features: Array[String] = [
	"territory",
	"sacrifice",
	"dungeon",
	"equipment",
	"tower",
	"arena",
	"pvp",
	"awakening"
]

func _ready() -> void:
	name = "FeatureUnlockManager"

func initialize() -> void:
	_cache_system_references()

var _save_manager: Node = null

func _cache_system_references() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		push_error("FeatureUnlockManager: SystemRegistry not available")
		return
	_save_manager = registry.get_system("SaveManager")

func unlock_feature(feature_name: String) -> void:
	if not _save_manager:
		push_error("FeatureUnlockManager: SaveManager not found")
		return

	var unlocked_features: Variant = _save_manager.get_player_value("unlocked_features", {})
	if not unlocked_features is Dictionary:
		unlocked_features = {}

	if unlocked_features.has(feature_name):
		return

	unlocked_features[feature_name] = true
	_save_manager.set_player_value("unlocked_features", unlocked_features)
	_save_manager.save_game()

	var feature_data: Dictionary = get_feature_data(feature_name)
	feature_unlocked.emit(feature_name, feature_data)
	_show_feature_introduction(feature_name)

func is_feature_unlocked(feature_name: String) -> bool:
	if not _save_manager:
		return false

	var unlocked_features: Variant = _save_manager.get_player_value("unlocked_features", {})
	if not unlocked_features is Dictionary:
		return false

	return unlocked_features.has(feature_name)

func get_feature_data(feature_name: String) -> Dictionary:
	var intro: Dictionary = feature_introductions.get(feature_name, {})
	return {
		"name": feature_name,
		"introduction": intro,
		"unlocked": is_feature_unlocked(feature_name),
		"unlock_achievement": intro.get("unlock_source", "")
	}

func get_all_features() -> Array[String]:
	return all_features

func get_unlocked_features() -> Array[String]:
	var unlocked: Array[String] = []
	for feature in all_features:
		if is_feature_unlocked(feature):
			unlocked.append(feature)
	return unlocked

func get_locked_features() -> Array[String]:
	var locked: Array[String] = []
	for feature in all_features:
		if not is_feature_unlocked(feature):
			locked.append(feature)
	return locked

func get_unlock_achievement(feature_name: String) -> String:
	var intro: Dictionary = feature_introductions.get(feature_name, {})
	return intro.get("unlock_source", "")

func _show_feature_introduction(feature_name: String) -> void:
	var intro_data: Dictionary = feature_introductions.get(feature_name, {})
	var title: String = intro_data.get("title", feature_name.capitalize())
	var message: String = intro_data.get("message", "New feature unlocked!")

	# Use NotificationQueue for stacked notifications
	var NotificationQueueClass: Variant = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		NotificationQueueClass.show_unlock(title, message)

# ==============================================================================
# SAVE/LOAD - Handled via SaveManager.player_data["unlocked_features"]
# ==============================================================================

func get_save_data() -> Dictionary:
	if not _save_manager:
		return {}

	var unlocked_features: Variant = _save_manager.get_player_value("unlocked_features", {})
	if unlocked_features is Dictionary:
		return unlocked_features
	return {}
