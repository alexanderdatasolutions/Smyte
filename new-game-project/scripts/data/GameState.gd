# scripts/data/GameState.gd
# Centralized game state management - replaces scattered state in GameManager
class_name GameState extends RefCounted

# Player progression
var player_level: int = 1
var player_experience: int = 0
var player_name: String = "Player"

# Resources
var resources: Dictionary = {}

# Collections
var owned_gods: Array = []  # Array[God]
var owned_equipment: Array = []  # Array[Equipment]

# Territories and progression
var controlled_territories: Array = []
var completed_dungeons: Array = []
var quest_progress: Dictionary = {}
var achievements: Array = []

# Battle and team data
var arena_team: Array = []  # Array[God]
var defense_team: Array = []  # Array[God]
var favorite_gods: Array = []  # Array[String] - God IDs

# Game settings and preferences
var game_settings: Dictionary = {}
var tutorial_progress: Dictionary = {}

# Cached game data (loaded from JSON files)
var game_data: Dictionary = {}

# Statistics
var battle_statistics: Dictionary = {}
var summon_statistics: Dictionary = {}

## Initialize a new game state
func initialize_new_game():
	print("GameState: Initializing new game state")
	
	# Reset all data
	player_level = 1
	player_experience = 0
	player_name = "Player"
	
	resources = {
		"gold": 0,
		"mana": 0,
		"energy": 100,
		"arena_tokens": 0,
		"guild_points": 0,
		"crystals": 0
	}
	
	owned_gods.clear()
	owned_equipment.clear()
	controlled_territories.clear()
	completed_dungeons.clear()
	quest_progress.clear()
	achievements.clear()
	arena_team.clear()
	defense_team.clear()
	favorite_gods.clear()
	
	game_settings = {
		"auto_battle_speed": 1.0,
		"sound_enabled": true,
		"music_enabled": true,
		"notifications_enabled": true
	}
	
	tutorial_progress = {}
	battle_statistics = {}
	summon_statistics = {}

## Store game data loaded from JSON files
func store_game_data(category: String, data: Dictionary):
	game_data[category] = data
	print("GameState: Stored ", category, " data (", data.size(), " entries)")

## Get cached game data by category
func get_game_data(category: String) -> Dictionary:
	return game_data.get(category, {})

## Load state from save data
func load_from_save(save_data: Dictionary):
	print("GameState: Loading from save data")
	
	# Player data
	player_level = save_data.get("level", 1)
	player_experience = save_data.get("experience", 0)
	player_name = save_data.get("name", "Player")
	
	# Resources
	resources = save_data.get("resources", {})
	
	# Collections
	owned_gods.clear()
	for god_data in save_data.get("gods", []):
		var god = SaveLoadUtility.deserialize_god(god_data)
		if god:
			owned_gods.append(god)
	
	owned_equipment.clear()
	for equipment_data in save_data.get("equipment", []):
		var equipment = SaveLoadUtility.deserialize_equipment(equipment_data)
		if equipment:
			owned_equipment.append(equipment)
	
	# Other data
	controlled_territories = save_data.get("territories", [])
	completed_dungeons = save_data.get("completed_dungeons", [])
	quest_progress = save_data.get("quest_progress", {})
	achievements = save_data.get("achievements", [])
	favorite_gods = save_data.get("favorite_gods", [])
	game_settings = save_data.get("settings", {})
	tutorial_progress = save_data.get("tutorial_progress", {})
	battle_statistics = save_data.get("battle_statistics", {})
	summon_statistics = save_data.get("summon_statistics", {})

## Get current save data
func get_save_data() -> Dictionary:
	var save_data = {
		"level": player_level,
		"experience": player_experience,
		"name": player_name,
		"resources": resources.duplicate(),
		"gods": [],
		"equipment": [],
		"territories": controlled_territories.duplicate(),
		"completed_dungeons": completed_dungeons.duplicate(),
		"quest_progress": quest_progress.duplicate(),
		"achievements": achievements.duplicate(),
		"favorite_gods": favorite_gods.duplicate(),
		"settings": game_settings.duplicate(),
		"tutorial_progress": tutorial_progress.duplicate(),
		"battle_statistics": battle_statistics.duplicate(),
		"summon_statistics": summon_statistics.duplicate()
	}
	
	# Serialize gods
	for god in owned_gods:
		save_data.gods.append(SaveLoadUtility.serialize_god(god))
	
	# Serialize equipment
	for equipment in owned_equipment:
		save_data.equipment.append(SaveLoadUtility.serialize_equipment(equipment))
	
	return save_data

# ============================================================================
# RESOURCE MANAGEMENT
# ============================================================================

func get_resource(resource_id: String) -> int:
	return resources.get(resource_id, 0)

func set_resource(resource_id: String, amount: int):
	var old_amount = get_resource(resource_id)
	resources[resource_id] = max(0, amount)
	var delta = resources[resource_id] - old_amount
	
	if delta != 0:
		EventBus.get_instance().emit_resource_change(resource_id, resources[resource_id], delta)

func add_resource(resource_id: String, amount: int):
	set_resource(resource_id, get_resource(resource_id) + amount)

func spend_resource(resource_id: String, amount: int) -> bool:
	var current = get_resource(resource_id)
	if current >= amount:
		set_resource(resource_id, current - amount)
		return true
	return false

func can_afford_resources(cost: Dictionary) -> bool:
	for resource_id in cost:
		if get_resource(resource_id) < cost[resource_id]:
			return false
	return true

func spend_resources(cost: Dictionary) -> bool:
	if not can_afford_resources(cost):
		return false
	
	for resource_id in cost:
		spend_resource(resource_id, cost[resource_id])
	
	return true

# ============================================================================
# COLLECTION MANAGEMENT
# ============================================================================

func add_god(god: God):
	if not god:
		return
	
	owned_gods.append(god)
	EventBus.get_instance().god_obtained.emit(god)

func remove_god(god: God) -> bool:
	var index = owned_gods.find(god)
	if index >= 0:
		owned_gods.remove_at(index)
		return true
	return false

func get_god_by_id(god_id: String) -> God:
	for god in owned_gods:
		if god.id == god_id:
			return god
	return null

func get_gods_by_element(element: String) -> Array:  # Array[God]
	var filtered_gods: Array = []  # Array[God]
	for god in owned_gods:
		if god.element == element:
			filtered_gods.append(god)
	return filtered_gods

func add_equipment(equipment: Equipment):
	if not equipment:
		return
	
	owned_equipment.append(equipment)
	EventBus.get_instance().equipment_obtained.emit(equipment)

func remove_equipment(equipment: Equipment) -> bool:
	var index = owned_equipment.find(equipment)
	if index >= 0:
		owned_equipment.remove_at(index)
		return true
	return false

func get_equipment_by_slot(slot: int) -> Array:  # Array[Equipment]
	var slot_equipment: Array = []  # Array[Equipment]
	for equipment in owned_equipment:
		if equipment.slot == slot:
			slot_equipment.append(equipment)
	return slot_equipment

# ============================================================================
# TEAM MANAGEMENT
# ============================================================================

func set_arena_team(team: Array):  # Array[God]
	arena_team = team.duplicate()

func get_arena_team() -> Array:  # Array[God]
	return arena_team.duplicate()

func set_defense_team(team: Array):  # Array[God]
	defense_team = team.duplicate()

func get_defense_team() -> Array:  # Array[God]
	return defense_team.duplicate()

func add_favorite_god(god_id: String):
	if not favorite_gods.has(god_id):
		favorite_gods.append(god_id)

func remove_favorite_god(god_id: String):
	favorite_gods.erase(god_id)

func is_favorite_god(god_id: String) -> bool:
	return favorite_gods.has(god_id)

# ============================================================================
# PROGRESSION TRACKING
# ============================================================================

func add_experience(amount: int):
	player_experience += amount
	_check_level_up()

func _check_level_up():
	var required_exp = _get_experience_for_level(player_level + 1)
	if player_experience >= required_exp:
		player_level += 1
		player_experience -= required_exp
		EventBus.get_instance().emit_notification("Level up! You are now level " + str(player_level), "success", 3.0)
		_check_level_up()  # Check for multiple level ups

func _get_experience_for_level(level: int) -> int:
	# Simple exponential formula: level^2 * 100
	return level * level * 100

func complete_dungeon(dungeon_id: String):
	if not completed_dungeons.has(dungeon_id):
		completed_dungeons.append(dungeon_id)

func is_dungeon_completed(dungeon_id: String) -> bool:
	return completed_dungeons.has(dungeon_id)

func set_quest_progress(quest_id: String, progress: int):
	quest_progress[quest_id] = progress

func get_quest_progress(quest_id: String) -> int:
	return quest_progress.get(quest_id, 0)

func unlock_achievement(achievement_id: String):
	if not achievements.has(achievement_id):
		achievements.append(achievement_id)
		EventBus.get_instance().achievement_unlocked.emit(achievement_id)

func has_achievement(achievement_id: String) -> bool:
	return achievements.has(achievement_id)

# ============================================================================
# STATISTICS TRACKING
# ============================================================================

func increment_battle_stat(stat_name: String, amount: int = 1):
	battle_statistics[stat_name] = battle_statistics.get(stat_name, 0) + amount

func increment_summon_stat(stat_name: String, amount: int = 1):
	summon_statistics[stat_name] = summon_statistics.get(stat_name, 0) + amount

func get_battle_stat(stat_name: String) -> int:
	return battle_statistics.get(stat_name, 0)

func get_summon_stat(stat_name: String) -> int:
	return summon_statistics.get(stat_name, 0)
