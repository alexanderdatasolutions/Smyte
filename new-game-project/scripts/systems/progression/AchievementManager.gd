# scripts/systems/progression/AchievementManager.gd
# Manages achievement tracking, completion, and rewards
extends Node
class_name AchievementManager

"""
AchievementManager - Core achievement logic
RULE 2: Single responsibility - Achievement tracking only
RULE 5: SystemRegistry integration

Handles:
- Loading achievement definitions from achievements.json
- Tracking progress for each trigger type
- Checking and awarding achievements when conditions are met
- Triggering feature unlocks for achievements with "unlocks" field
- Persisting state via SaveManager
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal achievement_completed(achievement_id: String, achievement_data: Dictionary)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const ACHIEVEMENTS_PATH = "res://data/achievements.json"

# ==============================================================================
# STATE
# ==============================================================================
var _achievements: Dictionary = {}  # id -> definition from JSON
var _completed: Dictionary = {}     # id -> completion timestamp
var _is_loaded: bool = false
var _is_initialized: bool = false

# Cached system references (populated in initialize())
var _event_bus: Node = null
var _collection_manager: Node = null
var _statistics_manager: Node = null
var _hex_grid_manager: Node = null
var _resource_manager: Node = null
var _save_manager: Node = null
var _feature_unlock_manager: Node = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	name = "AchievementManager"
	_load_achievements()

func initialize() -> void:
	"""Called by SystemRegistry after all systems registered.
	Note: Achievement state is restored by SaveManager.load_game() calling load_save_data(),
	NOT here, because player_data is not yet loaded when initialize() runs."""
	if _is_initialized:
		return
	_is_initialized = true

	_cache_system_references()
	_connect_to_events()
	# Achievement state restored via load_save_data() called by SaveManager.load_game()
	# _validate_all_achievements() is called deferred after load_save_data()

func _cache_system_references() -> void:
	"""Cache references to frequently-used systems to avoid repeated SystemRegistry lookups."""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		push_error("AchievementManager: SystemRegistry not available")
		return
	_event_bus = registry.get_system("EventBus")
	_collection_manager = registry.get_system("CollectionManager")
	_statistics_manager = registry.get_system("StatisticsManager")
	_hex_grid_manager = registry.get_system("HexGridManager")
	_resource_manager = registry.get_system("ResourceManager")
	_save_manager = registry.get_system("SaveManager")
	_feature_unlock_manager = registry.get_system("FeatureUnlockManager")

func _load_achievements() -> void:
	"""Load achievement definitions from JSON"""
	var file: FileAccess = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if not file:
		push_error("AchievementManager: Failed to open achievements file: %s" % ACHIEVEMENTS_PATH)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("AchievementManager: Failed to parse achievements JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.get_data()
	_achievements = data.get("achievements", {})
	_is_loaded = true

func _connect_to_events() -> void:
	"""Connect to EventBus signals for achievement tracking"""
	if not _event_bus:
		push_error("AchievementManager: EventBus not found")
		return

	# Collection events
	_event_bus.god_obtained.connect(_on_god_obtained)
	_event_bus.god_level_up.connect(_on_god_level_up)
	_event_bus.summon_performed.connect(_on_summon_performed)

	# Battle events
	_event_bus.battle_ended.connect(_on_battle_ended)
	_event_bus.dungeon_completed.connect(_on_dungeon_completed)

	# Territory events - TerritoryManager emits via EventBus
	if _event_bus.has_signal("territory_captured"):
		_event_bus.territory_captured.connect(_on_territory_captured)

	# Building events - connect to BuildingManager directly since it has local signals
	var registry: Node = SystemRegistry.get_instance()
	var building_manager: Node = registry.get_system("BuildingManager") if registry else null
	if building_manager:
		building_manager.building_placed.connect(_on_building_placed)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_god_obtained(_god) -> void:
	"""Handle god obtained - check god_count achievements"""
	_check_god_count_achievements()

func _on_god_level_up(_god_id: String, new_level: int, _old_level: int) -> void:
	"""Handle god level up - check max_god_level achievements"""
	_check_max_god_level_achievements(new_level)

func _on_summon_performed(_banner_id: String, _results: Array) -> void:
	"""Handle summon performed - check summon_count achievements"""
	_check_summon_count_achievements()

func _on_battle_ended(result) -> void:
	"""Handle battle end - check battle_wins achievements"""
	if result and result.victory:
		_check_battle_wins_achievements()

func _on_dungeon_completed(_dungeon_id: String, _rewards: Array) -> void:
	"""Handle dungeon completion - check dungeon_clears achievements"""
	_check_dungeon_clears_achievements()

func _on_territory_captured(territory_id) -> void:
	"""Handle territory capture - check territory achievements"""
	_check_territory_count_achievements()
	_check_max_territory_tier_achievements(territory_id)

func _on_building_placed(_node_id: String, _building_id: String) -> void:
	"""Handle building placed - check building_count achievements"""
	_check_building_count_achievements()

# ==============================================================================
# ACHIEVEMENT CHECKING
# ==============================================================================

func _check_god_count_achievements() -> void:
	"""Check achievements with trigger type: god_count"""
	if not _collection_manager:
		return

	var god_count: int = _collection_manager.gods.size()

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "god_count":
			var target: int = trigger.get("target", 0)
			var already_done: bool = is_achievement_completed(achievement_id)
			if god_count >= target and not already_done:
				complete_achievement(achievement_id)

func _check_max_god_level_achievements(current_max_level: int) -> void:
	"""Check achievements with trigger type: max_god_level"""
	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "max_god_level":
			var target: int = trigger.get("target", 0)
			if current_max_level >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_summon_count_achievements() -> void:
	"""Check achievements with trigger type: summon_count"""
	if not _statistics_manager:
		return

	var summon_count: int = _statistics_manager.resource_stats.get("total_summons_performed", 0)

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "summon_count":
			var target: int = trigger.get("target", 0)
			if summon_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_battle_wins_achievements() -> void:
	"""Check achievements with trigger type: battle_wins"""
	if not _statistics_manager:
		return

	var battle_wins: int = _statistics_manager.battle_stats.get("battles_won", 0)

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "battle_wins":
			var target: int = trigger.get("target", 0)
			if battle_wins >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_dungeon_clears_achievements() -> void:
	"""Check achievements with trigger type: dungeon_clears"""
	if not _statistics_manager:
		return

	# Sum up all dungeon clears
	var total_clears: int = 0
	for dungeon_id: String in _statistics_manager.battle_stats.get("dungeon_clears", {}):
		total_clears += _statistics_manager.battle_stats.dungeon_clears[dungeon_id]

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "dungeon_clears":
			var target: int = trigger.get("target", 0)
			if total_clears >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_territory_count_achievements() -> void:
	"""Check achievements with trigger type: territory_count"""
	if not _hex_grid_manager:
		return

	# Count player-controlled nodes (exclude home base and base-type nodes)
	var territory_count: int = 0
	for node_id: String in _hex_grid_manager._nodes:
		var node: HexNode = _hex_grid_manager._nodes[node_id]
		# Skip the home base - it's not a "captured" territory
		if node.id == "home_base" or node.node_type == "base":
			continue
		if node.controller == "player":
			territory_count += 1

	for achievement_id: String in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "territory_count":
			var target: int = trigger.get("target", 0)
			if territory_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_max_territory_tier_achievements(_territory_id) -> void:
	"""Check achievements with trigger type: max_territory_tier"""
	if not _hex_grid_manager:
		return

	# Find the max tier the player has (exclude home base)
	var max_tier: int = 0
	for node_id: String in _hex_grid_manager._nodes:
		var check_node: HexNode = _hex_grid_manager._nodes[node_id]
		# Skip home base
		if check_node.id == "home_base" or check_node.node_type == "base":
			continue
		if check_node.controller == "player" and check_node.tier > max_tier:
			max_tier = check_node.tier

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "max_territory_tier":
			var target: int = trigger.get("target", 0)
			if max_tier >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_building_count_achievements() -> void:
	"""Check achievements with trigger type: building_count"""
	if not _hex_grid_manager:
		return

	# Count placed buildings on player-controlled nodes
	var building_count: int = 0
	for node_id: String in _hex_grid_manager._nodes:
		var node: HexNode = _hex_grid_manager._nodes[node_id]
		if node.controller == "player" and node.has_building():
			building_count += 1

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "building_count":
			var target: int = trigger.get("target", 0)
			if building_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _validate_all_achievements() -> void:
	"""Check all achievements against current progress (catch-up on load)"""
	_check_god_count_achievements()
	_check_territory_count_achievements()
	_check_building_count_achievements()
	_check_battle_wins_achievements()
	_check_dungeon_clears_achievements()
	_check_summon_count_achievements()

	# Check max god level
	if _collection_manager:
		var max_level: int = 0
		for god in _collection_manager.gods:
			if god.level > max_level:
				max_level = god.level
		if max_level > 0:
			_check_max_god_level_achievements(max_level)

	# Check max territory tier
	if _hex_grid_manager:
		var max_tier: int = 0
		for node_id: String in _hex_grid_manager._nodes:
			var node: HexNode = _hex_grid_manager._nodes[node_id]
			if node.controller == "player" and node.tier > max_tier:
				max_tier = node.tier
		if max_tier > 0:
			# Pass dummy ID, the function will check max tier anyway
			_check_max_territory_tier_achievements("")

# ==============================================================================
# ACHIEVEMENT COMPLETION
# ==============================================================================

func complete_achievement(achievement_id: String) -> void:
	"""Complete an achievement, award rewards, and unlock features"""
	if is_achievement_completed(achievement_id):
		return

	var achievement: Dictionary = _achievements.get(achievement_id, {})
	if achievement.is_empty():
		push_error("AchievementManager: Unknown achievement: %s" % achievement_id)
		return

	# Mark as completed
	_completed[achievement_id] = Time.get_unix_time_from_system()
	_save_state()

	# Award rewards
	var rewards: Dictionary = achievement.get("rewards", {})
	_award_rewards(rewards)

	# Unlock features (supports single string or array of strings)
	var unlocks: Variant = achievement.get("unlocks")
	if unlocks:
		if unlocks is String and not unlocks.is_empty():
			_unlock_feature(unlocks)
		elif unlocks is Array:
			for feature in unlocks:
				if feature is String and not feature.is_empty():
					_unlock_feature(feature)

	# Emit signal
	achievement_completed.emit(achievement_id, achievement)

	# Emit to EventBus
	if _event_bus:
		_event_bus.achievement_unlocked.emit(achievement_id)

	# Show notification
	_show_achievement_notification(achievement)

func _award_rewards(rewards: Dictionary) -> void:
	"""Award resources from achievement"""
	if not _resource_manager:
		return

	for resource_id: String in rewards:
		var amount: int = rewards[resource_id]
		_resource_manager.add_resource(resource_id, amount)

func _unlock_feature(feature_name: String) -> void:
	"""Unlock a feature via FeatureUnlockManager"""
	if _feature_unlock_manager:
		_feature_unlock_manager.unlock_feature(feature_name)

func _show_achievement_notification(achievement: Dictionary) -> void:
	"""Show achievement unlock notification using NotificationQueue"""
	var NotificationQueueClass = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		var achievement_name: String = achievement.get("name", "Unknown")
		var desc: String = achievement.get("description", "")
		NotificationQueueClass.show_achievement(achievement_name, desc)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func is_achievement_completed(achievement_id: String) -> bool:
	"""Check if an achievement is completed"""
	return _completed.has(achievement_id)

func get_achievement(achievement_id: String) -> Dictionary:
	"""Get achievement definition"""
	return _achievements.get(achievement_id, {})

func get_all_achievements() -> Dictionary:
	"""Get all achievement definitions"""
	return _achievements.duplicate()

func get_completed_achievements() -> Array:
	"""Get list of completed achievement IDs"""
	return _completed.keys()

func get_achievement_progress(achievement_id: String) -> Dictionary:
	"""Get progress towards an achievement"""
	var achievement: Dictionary = _achievements.get(achievement_id, {})
	if achievement.is_empty():
		return {}

	var trigger: Dictionary = achievement.get("trigger", {})
	var trigger_type: String = trigger.get("type", "")
	var target: int = trigger.get("target", 0)
	var current: int = _get_current_value_for_trigger(trigger_type)

	return {
		"current": current,
		"target": target,
		"completed": is_achievement_completed(achievement_id),
		"percent": minf(1.0, float(current) / float(target)) if target > 0 else 0.0
	}

func _get_current_value_for_trigger(trigger_type: String) -> int:
	"""Get current value for a trigger type"""
	match trigger_type:
		"god_count":
			return _collection_manager.gods.size() if _collection_manager else 0
		"territory_count":
			if not _hex_grid_manager:
				return 0
			var count: int = 0
			for node_id: String in _hex_grid_manager._nodes:
				var node: HexNode = _hex_grid_manager._nodes[node_id]
				# Skip home base - not a captured territory
				if node_id == "home_base" or node.node_type == "base":
					continue
				if node.controller == "player":
					count += 1
			return count
		"max_territory_tier":
			if not _hex_grid_manager:
				return 0
			var max_tier: int = 0
			for node_id: String in _hex_grid_manager._nodes:
				var node: HexNode = _hex_grid_manager._nodes[node_id]
				# Skip home base
				if node.id == "home_base" or node.node_type == "base":
					continue
				if node.controller == "player" and node.tier > max_tier:
					max_tier = node.tier
			return max_tier
		"max_god_level":
			if not _collection_manager:
				return 0
			var max_level: int = 0
			for god in _collection_manager.gods:
				if god.level > max_level:
					max_level = god.level
			return max_level
		"building_count":
			if not _hex_grid_manager:
				return 0
			var count: int = 0
			for node_id: String in _hex_grid_manager._nodes:
				var node: HexNode = _hex_grid_manager._nodes[node_id]
				if node.controller == "player" and node.has_building():
					count += 1
			return count
		"battle_wins":
			return _statistics_manager.battle_stats.get("battles_won", 0) if _statistics_manager else 0
		"dungeon_clears":
			if not _statistics_manager:
				return 0
			var total: int = 0
			for dungeon_id: String in _statistics_manager.battle_stats.get("dungeon_clears", {}):
				total += _statistics_manager.battle_stats.dungeon_clears[dungeon_id]
			return total
		"summon_count":
			return _statistics_manager.resource_stats.get("total_summons_performed", 0) if _statistics_manager else 0

	return 0

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func _save_state() -> void:
	"""Save achievement state via SaveManager (achievements included in save chain)"""
	if not _save_manager:
		return

	_save_manager.save_game()

func get_save_data() -> Dictionary:
	"""Get achievement data for saving"""
	return {
		"completed": _completed.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	"""Load achievement data from save - called by SaveManager during load_game()"""
	_completed = data.get("completed", {})
	# Re-validate achievements after restore to catch any progress made before save
	call_deferred("_validate_all_achievements")
