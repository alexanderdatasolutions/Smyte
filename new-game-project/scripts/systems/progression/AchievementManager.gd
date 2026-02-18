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

# Discord webhook for achievement announcements (set your webhook URL here)
const DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1473115579559710845/jowJ3u5ZMyVmFdhhpQPlCyH1RnTfeCrvPSQ_CiI3qJREu8ooZe6TfAZr-XClFkscv0J2"  # e.g. "https://discord.com/api/webhooks/xxx/yyy"

# Achievements worth announcing to Discord (the flex-worthy ones)
const DISCORD_ANNOUNCE_ACHIEVEMENTS: Array[String] = [
	"first_territory",   # Landowner (TEST - remove after testing)
	"tier3_territory",   # Rising Power
	"tier4_territory",   # Domain Master
	"ten_gods",          # Divine Assembly
	"ten_territories",   # Empire Builder
	"god_level_30",      # Awakening Potential
	"legendary_champion", # Legendary Champion - unlocks skins
]

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
var _skin_manager: Node = null

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
	_skin_manager = registry.get_system("SkinManager")

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

	# Sacrifice events
	if _event_bus.has_signal("god_sacrifice_completed"):
		_event_bus.god_sacrifice_completed.connect(_on_god_sacrifice_completed)

	# Equipment events
	if _event_bus.has_signal("equipment_equipped"):
		_event_bus.equipment_equipped.connect(_on_equipment_equipped)

	# Tower events
	if _event_bus.has_signal("tower_floor_cleared"):
		_event_bus.tower_floor_cleared.connect(_on_tower_floor_cleared)

	# Arena events
	if _event_bus.has_signal("arena_battle_completed"):
		_event_bus.arena_battle_completed.connect(_on_arena_battle_completed)

	# Awakening events
	if _event_bus.has_signal("god_awakening_completed"):
		_event_bus.god_awakening_completed.connect(_on_god_awakening_completed)

	# Building events - connect to BuildingManager directly since it has local signals
	var registry: Node = SystemRegistry.get_instance()
	var building_manager: Node = registry.get_system("BuildingManager") if registry else null
	if building_manager:
		building_manager.building_placed.connect(_on_building_placed)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_god_obtained(_god) -> void:
	"""Handle god obtained - check god_count, legendary_count, epic_count, and all_elements achievements"""
	_check_god_count_achievements()
	_check_legendary_count_achievements()
	_check_epic_count_achievements()
	_check_all_elements_achievement()

func _on_god_level_up(god_id: String, new_level: int, _old_level: int) -> void:
	"""Handle god level up - check max_god_level and legendary_god_level_40 achievements"""
	_check_max_god_level_achievements(new_level)
	_check_legendary_god_level_40_achievement(god_id, new_level)

func _on_summon_performed(_banner_id: String, results: Array) -> void:
	"""Handle summon performed - check summon_count achievements"""
	# Note: We add results.size() because StatisticsManager might not have incremented yet (race condition)
	var current_count: int = _statistics_manager.resource_stats.get("total_summons_performed", 0) if _statistics_manager else 0
	var new_count: int = current_count + results.size()
	print("AchievementManager: summon_performed received, summon_count=%d (current=%d + new=%d)" % [new_count, current_count, results.size()])
	_check_summon_count_achievements_with_count(new_count)

func _on_battle_ended(result) -> void:
	"""Handle battle end - check battle_wins, legendary_team, and battle condition achievements"""
	if result and result.victory:
		_check_battle_wins_achievements()
		_check_legendary_team_achievement(result)
		_check_battle_condition_achievements(result)

func _on_dungeon_completed(_dungeon_id: String, _rewards: Array) -> void:
	"""Handle dungeon completion - check dungeon_clears achievements"""
	_check_dungeon_clears_achievements()

func _on_territory_captured(territory_id) -> void:
	"""Handle territory capture - check territory achievements"""
	print("AchievementManager: Territory captured signal received for: %s" % str(territory_id))
	_check_territory_count_achievements()
	_check_max_territory_tier_achievements(territory_id)

func _on_building_placed(_node_id: String, _building_id: String) -> void:
	"""Handle building placed - check building_count achievements"""
	_check_building_count_achievements()

func _on_god_sacrifice_completed(_sacrifice_data: Dictionary) -> void:
	"""Handle god sacrifice - check sacrifice_count achievements"""
	_check_sacrifice_count_achievements()

func _on_equipment_equipped(_god, _equipment, _slot) -> void:
	"""Handle equipment equipped - check equipment achievements"""
	_check_equipment_count_achievements()
	_check_full_equipment_achievement()

func _on_tower_floor_cleared(floor_number: int) -> void:
	"""Handle tower floor cleared - check tower_floor achievements"""
	_check_tower_floor_achievements(floor_number)

func _on_arena_battle_completed(arena_data: Dictionary) -> void:
	"""Handle arena battle - check arena_wins achievements"""
	if arena_data.get("victory", false):
		_check_arena_wins_achievements()

func _on_god_awakening_completed(_awakening_data: Dictionary) -> void:
	"""Handle god awakening - check awakening_count achievements"""
	_check_awakening_count_achievements()

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

func _check_legendary_god_level_40_achievement(god_id: String, new_level: int) -> void:
	"""Check if a legendary god reached level 40 - triggers skin unlock"""
	if new_level < 40:
		return

	if is_achievement_completed("legendary_champion"):
		return

	if not _collection_manager:
		return

	# Get the god that just leveled up
	var god: God = _collection_manager.get_god_by_id(god_id)
	if not god:
		return

	# Check if this god is legendary (tier 3 = LEGENDARY in enum)
	if god.tier != God.TierType.LEGENDARY:
		return

	# This is a legendary god at level 40+, complete the achievement
	print("AchievementManager: Legendary god '%s' reached level %d - unlocking skins!" % [god.name, new_level])

	# Store the god_id for the free skin pick popup
	if _skin_manager and _skin_manager.has_method("set_pending_free_skin_god"):
		_skin_manager.set_pending_free_skin_god(god_id)

	complete_achievement("legendary_champion")

func _check_summon_count_achievements() -> void:
	"""Check achievements with trigger type: summon_count"""
	if not _statistics_manager:
		return
	var summon_count: int = _statistics_manager.resource_stats.get("total_summons_performed", 0)
	_check_summon_count_achievements_with_count(summon_count)

func _check_summon_count_achievements_with_count(summon_count: int) -> void:
	"""Check achievements with trigger type: summon_count using provided count"""
	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "summon_count":
			var target: int = trigger.get("target", 0)
			if summon_count >= target and not is_achievement_completed(achievement_id):
				print("AchievementManager: Completing '%s' (summon_count %d >= target %d)" % [achievement_id, summon_count, target])
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
		print("AchievementManager: _hex_grid_manager is null, skipping territory check")
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

	print("AchievementManager: Player has %d captured territories" % territory_count)

	for achievement_id: String in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "territory_count":
			var target: int = trigger.get("target", 0)
			var already_completed: bool = is_achievement_completed(achievement_id)
			if territory_count >= target and not already_completed:
				print("AchievementManager: Completing achievement '%s' (territories: %d >= %d)" % [achievement_id, territory_count, target])
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

func _check_legendary_count_achievements() -> void:
	"""Check achievements with trigger type: legendary_count"""
	if not _collection_manager:
		return

	# Count legendary gods in collection
	var legendary_count: int = 0
	for god in _collection_manager.gods:
		if god and god.tier == God.TierType.LEGENDARY:
			legendary_count += 1

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "legendary_count":
			var target: int = trigger.get("target", 0)
			if legendary_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_legendary_team_achievement(result) -> void:
	"""Check if player fielded a full team of 4 legendary gods"""
	if is_achievement_completed("full_team_legendary"):
		return

	if not _collection_manager or not result:
		return

	# Get gods that participated from experience_gained (god_id -> exp)
	var experience_gained: Dictionary = result.experience_gained if "experience_gained" in result else {}
	if experience_gained.size() < 4:
		return  # Need exactly 4 gods for a full team

	# Check if all participating gods are legendary
	var legendary_count: int = 0
	for god_id in experience_gained:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god and god.tier == God.TierType.LEGENDARY:
			legendary_count += 1

	if legendary_count >= 4:
		complete_achievement("full_team_legendary")

func _check_battle_condition_achievements(result) -> void:
	"""Check hidden battle condition achievements (speed_demon, flawless_victory, etc.)"""
	if not result:
		return

	# Speed Demon - Win a battle in under 30 seconds
	if not is_achievement_completed("speed_demon"):
		var duration: float = result.duration if "duration" in result else 0.0
		if duration > 0 and duration <= 30.0:
			complete_achievement("speed_demon")

	# Untouchable - Win without taking any damage
	if not is_achievement_completed("no_damage"):
		var damage_received: int = result.damage_received if "damage_received" in result else 0
		if damage_received == 0:
			complete_achievement("no_damage")

	# One Punch God - Deal 10000+ damage in a single hit
	if not is_achievement_completed("one_shot"):
		var max_hit: int = result.max_single_hit if "max_single_hit" in result else 0
		if max_hit >= 10000:
			complete_achievement("one_shot")

	# Comeback Kid - Win after 3 of your gods have fallen
	if not is_achievement_completed("comeback_kid"):
		var units_died: int = result.player_units_died if "player_units_died" in result else 0
		if units_died >= 3:
			complete_achievement("comeback_kid")

	# Underdog Victory - Win with only 1 god surviving at 10% HP or less
	if not is_achievement_completed("underdog"):
		var lowest_hp: float = result.lowest_surviving_hp_percent if "lowest_surviving_hp_percent" in result else 1.0
		var units_died: int = result.player_units_died if "player_units_died" in result else 0
		var experience_gained: Dictionary = result.experience_gained if "experience_gained" in result else {}
		var team_size: int = experience_gained.size()
		# Only 1 survivor (team_size - units_died == 1) and that survivor at 10% or less
		if team_size > 0 and (team_size - units_died) == 1 and lowest_hp <= 0.1:
			complete_achievement("underdog")

	# Check mono-element team achievements
	_check_mono_element_achievement(result)

	# Night Owl - Playing between 2 AM and 5 AM
	if not is_achievement_completed("night_owl"):
		var datetime: Dictionary = Time.get_datetime_dict_from_system()
		var hour: int = datetime.get("hour", 12)
		if hour >= 2 and hour < 5:
			complete_achievement("night_owl")

func _check_mono_element_achievement(result) -> void:
	"""Check if the team was all one element"""
	if not _collection_manager or not result:
		return

	var experience_gained: Dictionary = result.experience_gained if "experience_gained" in result else {}
	if experience_gained.size() < 1:
		return

	var team_element: int = -1  # Use int for enum comparison
	var all_same: bool = true

	for god_id in experience_gained:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god:
			if team_element == -1:
				team_element = god.element
			elif god.element != team_element:
				all_same = false
				break

	if all_same and team_element >= 0:
		# Map element enum to string for achievement ID
		var element_names: Array = ["fire", "water", "earth", "lightning", "light", "dark"]
		if team_element < element_names.size():
			var element_name: String = element_names[team_element]
			var achievement_id: String = "element_team_" + element_name
			if _achievements.has(achievement_id) and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_sacrifice_count_achievements() -> void:
	"""Check achievements with trigger type: sacrifice_count"""
	if not _statistics_manager:
		return

	var sacrifice_count: int = _statistics_manager.resource_stats.get("gods_sacrificed", 0)

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "sacrifice_count":
			var target: int = trigger.get("target", 0)
			if sacrifice_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_equipment_count_achievements() -> void:
	"""Check achievements with trigger type: equipment_count"""
	if not _collection_manager:
		return

	# Count total equipped items across all gods
	# equipment is an Array[Equipment or null] with 6 slots
	var equipment_count: int = 0
	for god in _collection_manager.gods:
		if god and "equipment" in god and god.equipment is Array:
			for item in god.equipment:
				if item != null:
					equipment_count += 1

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "equipment_count":
			var target: int = trigger.get("target", 0)
			if equipment_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_full_equipment_achievement() -> void:
	"""Check if any god has all 6 equipment slots filled"""
	if is_achievement_completed("full_equipment"):
		return

	if not _collection_manager:
		return

	for god in _collection_manager.gods:
		if god and "equipment" in god and god.equipment is Array:
			var filled_slots: int = 0
			for item in god.equipment:
				if item != null:
					filled_slots += 1
			if filled_slots >= 6:
				complete_achievement("full_equipment")
				return

func _check_tower_floor_achievements(current_floor: int) -> void:
	"""Check achievements with trigger type: tower_floor"""
	# Also check TowerManager best_floor in case current_floor isn't the best
	var registry: Node = SystemRegistry.get_instance()
	var tower_manager: Node = registry.get_system("TowerManager") if registry else null
	var best_floor: int = current_floor
	if tower_manager and "best_floor" in tower_manager:
		best_floor = maxi(best_floor, tower_manager.best_floor)

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "tower_floor":
			var target: int = trigger.get("target", 0)
			if best_floor >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_arena_wins_achievements() -> void:
	"""Check achievements with trigger type: arena_wins"""
	var registry: Node = SystemRegistry.get_instance()
	var arena_manager: Node = registry.get_system("ArenaManager") if registry else null
	if not arena_manager:
		return

	var arena_wins: int = 0
	if "wins" in arena_manager:
		arena_wins = arena_manager.wins

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "arena_wins":
			var target: int = trigger.get("target", 0)
			if arena_wins >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_awakening_count_achievements() -> void:
	"""Check achievements with trigger type: awakening_count"""
	if not _collection_manager:
		return

	# Count gods that have been awakened (tier > base tier or awakening_level > 0)
	var awakening_count: int = 0
	for god in _collection_manager.gods:
		if god and "awakening_level" in god and god.awakening_level > 0:
			awakening_count += 1

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "awakening_count":
			var target: int = trigger.get("target", 0)
			if awakening_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_epic_count_achievements() -> void:
	"""Check achievements with trigger type: epic_count"""
	if not _collection_manager:
		return

	var epic_count: int = 0
	for god in _collection_manager.gods:
		if god and god.tier == God.TierType.EPIC:
			epic_count += 1

	for achievement_id in _achievements:
		var achievement: Dictionary = _achievements[achievement_id]
		var trigger: Dictionary = achievement.get("trigger", {})

		if trigger.get("type") == "epic_count":
			var target: int = trigger.get("target", 0)
			if epic_count >= target and not is_achievement_completed(achievement_id):
				complete_achievement(achievement_id)

func _check_all_elements_achievement() -> void:
	"""Check if player has at least one god of each element"""
	if is_achievement_completed("all_elements"):
		return

	if not _collection_manager:
		return

	var elements_found: Dictionary = {}
	# ElementType enum: FIRE=0, WATER=1, EARTH=2, LIGHTNING=3, LIGHT=4, DARK=5
	var all_elements: Array = [
		God.ElementType.FIRE, God.ElementType.WATER, God.ElementType.EARTH,
		God.ElementType.LIGHTNING, God.ElementType.LIGHT, God.ElementType.DARK
	]

	for god in _collection_manager.gods:
		if god:
			elements_found[god.element] = true

	# Check if all 6 elements are represented
	for element in all_elements:
		if not elements_found.has(element):
			return  # Missing at least one element

	complete_achievement("all_elements")

func _validate_all_achievements() -> void:
	"""Check all achievements against current progress (catch-up on load)"""
	_check_god_count_achievements()
	_check_legendary_count_achievements()
	_check_epic_count_achievements()
	_check_all_elements_achievement()
	_check_territory_count_achievements()
	_check_building_count_achievements()
	_check_battle_wins_achievements()
	_check_dungeon_clears_achievements()
	_check_summon_count_achievements()
	_check_sacrifice_count_achievements()
	_check_equipment_count_achievements()
	_check_full_equipment_achievement()
	_check_awakening_count_achievements()
	_check_arena_wins_achievements()

	# Check max god level
	if _collection_manager:
		var max_level: int = 0
		for god in _collection_manager.gods:
			if god.level > max_level:
				max_level = god.level
		if max_level > 0:
			_check_max_god_level_achievements(max_level)

		# Check legendary god level 40
		for god in _collection_manager.gods:
			if god.tier == God.TierType.LEGENDARY and god.level >= 40:
				_check_legendary_god_level_40_achievement(god.id, god.level)
				break  # Only need to trigger once

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

	# Check tower floor achievements
	var registry: Node = SystemRegistry.get_instance()
	var tower_manager: Node = registry.get_system("TowerManager") if registry else null
	if tower_manager and "best_floor" in tower_manager and tower_manager.best_floor > 0:
		_check_tower_floor_achievements(tower_manager.best_floor)

# ==============================================================================
# ACHIEVEMENT COMPLETION
# ==============================================================================

func complete_achievement(achievement_id: String) -> void:
	"""Complete an achievement, award rewards, and unlock features"""
	if is_achievement_completed(achievement_id):
		print("AchievementManager: Achievement '%s' already completed, skipping" % achievement_id)
		return

	var achievement: Dictionary = _achievements.get(achievement_id, {})
	if achievement.is_empty():
		push_error("AchievementManager: Unknown achievement: %s" % achievement_id)
		return

	print("AchievementManager: === COMPLETING ACHIEVEMENT: %s ===" % achievement_id)

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

	# Announce to Discord (for flex-worthy achievements)
	_announce_to_discord(achievement_id, achievement)

func _award_rewards(rewards: Dictionary) -> void:
	"""Award resources from achievement"""
	if not _resource_manager:
		return

	for resource_id: String in rewards:
		var amount: int = rewards[resource_id]
		_resource_manager.add_resource(resource_id, amount)

func _unlock_feature(feature_name: String) -> void:
	"""Unlock a feature via FeatureUnlockManager"""
	if not _feature_unlock_manager:
		push_error("AchievementManager: FeatureUnlockManager not found, cannot unlock '%s'" % feature_name)
		return

	# Skip if already unlocked to avoid log spam on load
	if _feature_unlock_manager.is_feature_unlocked(feature_name):
		return

	print("AchievementManager: Unlocking feature '%s'" % feature_name)
	_feature_unlock_manager.unlock_feature(feature_name)

func _show_achievement_notification(achievement: Dictionary) -> void:
	"""Show achievement unlock notification using NotificationQueue"""
	var NotificationQueueClass = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		var achievement_name: String = achievement.get("name", "Unknown")
		var desc: String = achievement.get("description", "")
		NotificationQueueClass.show_achievement(achievement_name, desc)

func _announce_to_discord(achievement_id: String, achievement: Dictionary) -> void:
	"""Announce big achievements to Discord for flexing"""
	if DISCORD_WEBHOOK_URL.is_empty():
		return

	if achievement_id not in DISCORD_ANNOUNCE_ACHIEVEMENTS:
		return

	# Get player display name from SaveManager (set during onboarding)
	var player_name: String = "A mysterious player"
	if _save_manager:
		var saved_name: String = _save_manager.get_player_value("display_name", "")
		if not saved_name.is_empty():
			player_name = saved_name

	var achievement_name: String = achievement.get("name", "Unknown")
	var description: String = achievement.get("description", "")

	# Build Discord embed
	var embed: Dictionary = {
		"title": "🏆 Achievement Unlocked!",
		"description": "**%s** just earned **%s**!\n_%s_" % [player_name, achievement_name, description],
		"color": 16766720,  # Gold color
		"timestamp": Time.get_datetime_string_from_system(true)
	}

	var payload: Dictionary = {
		"embeds": [embed]
	}

	# Fire and forget HTTP request
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, _code, _headers, _body): http.queue_free())

	var json_body: String = JSON.stringify(payload)
	var headers: Array = ["Content-Type: application/json"]
	http.request(DISCORD_WEBHOOK_URL, headers, HTTPClient.METHOD_POST, json_body)

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
		"legendary_count":
			if not _collection_manager:
				return 0
			var count: int = 0
			for god in _collection_manager.gods:
				if god and god.tier == God.TierType.LEGENDARY:
					count += 1
			return count
		"legendary_team":
			# This is checked on battle end, not progressively tracked
			return 1 if is_achievement_completed("full_team_legendary") else 0
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
		"legendary_god_level_40":
			# Returns 1 if any legendary god is at level 40+, 0 otherwise
			if not _collection_manager:
				return 0
			for god in _collection_manager.gods:
				if god.tier == God.TierType.LEGENDARY and god.level >= 40:
					return 1
			return 0
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
		"sacrifice_count":
			return _statistics_manager.resource_stats.get("gods_sacrificed", 0) if _statistics_manager else 0
		"equipment_count":
			if not _collection_manager:
				return 0
			var count: int = 0
			for god in _collection_manager.gods:
				if god and "equipment" in god and god.equipment is Array:
					for item in god.equipment:
						if item != null:
							count += 1
			return count
		"full_equipment":
			# Returns 1 if any god has all 6 slots, 0 otherwise
			if not _collection_manager:
				return 0
			for god in _collection_manager.gods:
				if god and "equipment" in god and god.equipment is Array:
					var filled: int = 0
					for item in god.equipment:
						if item != null:
							filled += 1
					if filled >= 6:
						return 1
			return 0
		"tower_floor":
			var registry: Node = SystemRegistry.get_instance()
			var tower_manager: Node = registry.get_system("TowerManager") if registry else null
			if tower_manager and "best_floor" in tower_manager:
				return tower_manager.best_floor
			return 0
		"arena_wins":
			var registry: Node = SystemRegistry.get_instance()
			var arena_manager: Node = registry.get_system("ArenaManager") if registry else null
			if not arena_manager:
				return 0
			if "wins" in arena_manager:
				return arena_manager.wins
			return 0
		"awakening_count":
			if not _collection_manager:
				return 0
			var count: int = 0
			for god in _collection_manager.gods:
				if god and "awakening_level" in god and god.awakening_level > 0:
					count += 1
			return count
		"epic_count":
			if not _collection_manager:
				return 0
			var count: int = 0
			for god in _collection_manager.gods:
				if god and god.tier == God.TierType.EPIC:
					count += 1
			return count
		"all_elements":
			# Returns 1 if all 6 elements collected, 0 otherwise
			if not _collection_manager:
				return 0
			var elements_found: Dictionary = {}
			for god in _collection_manager.gods:
				if god:
					elements_found[god.element] = true
			# Check if all 6 element types are present
			return 1 if elements_found.size() >= 6 else 0

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
	# MERGE completed achievements (union) - once completed = always completed
	var loaded_completed: Dictionary = data.get("completed", {})
	for achievement_id in loaded_completed:
		if not _completed.has(achievement_id):
			_completed[achievement_id] = loaded_completed[achievement_id]

	# Re-apply feature unlocks for all completed achievements (ensures features stay unlocked)
	call_deferred("_reapply_feature_unlocks")
	# Re-validate achievements after restore to catch any progress made before save
	call_deferred("_validate_all_achievements")

func _reapply_feature_unlocks() -> void:
	"""Re-apply feature unlocks for all completed achievements (called on load)"""
	for achievement_id in _completed:
		var achievement: Dictionary = _achievements.get(achievement_id, {})
		var unlocks: Variant = achievement.get("unlocks")
		if unlocks:
			if unlocks is String and not unlocks.is_empty():
				_unlock_feature(unlocks)
			elif unlocks is Array:
				for feature in unlocks:
					if feature is String and not feature.is_empty():
						_unlock_feature(feature)
