# BattleFactory.gd - Modular battle instantiation system
# Creates and configures battles for all content types: Dungeons, Territories, Raids, PvP, etc.
# This is the factory that creates battles, BattleManager handles the actual battle logic
extends Resource
class_name BattleFactory

# Battle type enum
enum BattleType {
	TERRITORY,
	DUNGEON,
	RAID,
	GUILD_BATTLE,
	ARENA,
	WORLD_BOSS
}

# Core battle properties - these get set by factory methods
@export var battle_type: String = ""
@export var player_team: Array[God] = []

# Context-specific properties - set dynamically based on battle type
@export var battle_territory: Territory = null
@export var battle_stage: int = 1
@export var battle_dungeon_id: String = ""
@export var battle_difficulty: String = "beginner"
@export var battle_raid_id: String = ""
@export var battle_guild_id: String = ""
@export var battle_opponent_team: Array = []

# Wave management
@export var current_wave: int = 1
@export var total_waves: int = 1

# Battle mechanics
@export var max_enemies_per_wave: int = 4  # UI constraint
@export var auto_progression: bool = false
@export var reward_multiplier: float = 1.0

# Factory methods for different battle types
static func create_territory_battle(gods: Array, territory: Territory, stage: int) -> BattleFactory:
	"""Create configuration for territory battle"""
	var config = BattleFactory.new()
	config.battle_type = "territory"
	config.player_team = gods.duplicate()
	config.battle_territory = territory
	config.battle_stage = stage
	config.total_waves = _calculate_territory_waves(territory, stage)
	return config

static func create_dungeon_battle(gods: Array, dungeon_id: String, difficulty: String, _enemies: Array = []) -> BattleFactory:
	"""Create configuration for dungeon battle"""
	var config = BattleFactory.new()
	config.battle_type = "dungeon" 
	config.player_team = gods.duplicate()
	config.battle_dungeon_id = dungeon_id
	config.battle_difficulty = difficulty
	config.total_waves = _get_dungeon_waves(dungeon_id, difficulty)
	config.auto_progression = true  # Dungeons auto-progress through waves
	return config

static func create_raid_battle(gods: Array, raid_id: String, difficulty: String) -> BattleFactory:
	"""Create configuration for raid battle"""
	var config = BattleFactory.new()
	config.battle_type = "raid"
	config.player_team = gods.duplicate()
	config.battle_raid_id = raid_id
	config.battle_difficulty = difficulty
	config.total_waves = _get_raid_waves(raid_id, difficulty)
	config.reward_multiplier = _get_raid_reward_multiplier(difficulty)
	return config

static func create_arena_battle(gods: Array, opponent_team: Array) -> BattleFactory:
	"""Create configuration for PvP arena battle"""
	var config = BattleFactory.new()
	config.battle_type = "arena"
	config.player_team = gods.duplicate()
	config.battle_opponent_team = opponent_team.duplicate()
	config.total_waves = 1  # PvP is single wave
	return config

# Validation
func validate() -> bool:
	"""Validate battle configuration"""
	if player_team.is_empty():
		print("ERROR: No player team specified")
		return false
	
	match battle_type:
		"territory":
			return battle_territory != null and battle_stage > 0
		"dungeon":
			return not battle_dungeon_id.is_empty() and not battle_difficulty.is_empty()
		"raid":
			return not battle_raid_id.is_empty() and not battle_difficulty.is_empty()
		"arena":
			return not battle_opponent_team.is_empty()
		_:
			print("ERROR: Unknown battle type: %s" % battle_type)
			return false

# Enemy creation should be handled by EnemyFactory, not BattleFactory
# BattleFactory only provides configuration data for EnemyFactory to use
func get_battle_config() -> Dictionary:
	"""Get battle configuration data for EnemyFactory"""
	match battle_type:
		"territory":
			return {
				"type": "territory",
				"territory": battle_territory,
				"stage": battle_stage,
				"wave": current_wave
			}
		"dungeon":
			return {
				"type": "dungeon", 
				"dungeon_id": battle_dungeon_id,
				"difficulty": battle_difficulty,
				"wave": current_wave
			}
		"raid":
			return {
				"type": "raid",
				"raid_id": battle_raid_id,
				"difficulty": battle_difficulty,
				"wave": current_wave
			}
		"arena":
			return {
				"type": "arena",
				"opponent_team": battle_opponent_team
			}
		_:
			return {}

# Battle description for UI
func get_battle_description() -> String:
	"""Get user-friendly battle description"""
	match battle_type:
		"territory":
			return "Territory Battle: %s Stage %d" % [battle_territory.name if battle_territory else "Unknown", battle_stage]
		"dungeon":
			return "Dungeon Battle: %s - %s Difficulty" % [battle_dungeon_id.capitalize().replace("_", " "), battle_difficulty.capitalize()]
		"raid":
			return "Raid Battle: %s - %s Difficulty" % [battle_raid_id.capitalize().replace("_", " "), battle_difficulty.capitalize()]
		"arena":
			return "Arena Battle: PvP Combat"
		_:
			return "Battle: %s" % battle_type.capitalize()

# Helper methods for JSON data loading - these are used by wave count calculations
static func _calculate_territory_waves(_territory: Territory, stage: int) -> int:
	"""Calculate waves for territory based on stage"""
	if stage <= 3:
		return 1
	elif stage <= 7:
		return 2
	else:
		return 3  # Boss stages

static func _get_dungeon_waves(dungeon_id: String, difficulty: String) -> int:
	"""Get wave count from dungeons.json"""
	var dungeon_system = GameManager.get_dungeon_system() if GameManager else null
	if not dungeon_system:
		return 3  # fallback
	
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	return int(difficulty_info.get("waves", 3))

static func _get_raid_waves(_raid_id: String, difficulty: String) -> int:
	"""Get wave count for raids"""
	match difficulty:
		"easy": return 3
		"normal": return 4
		"hard": return 5
		"nightmare": return 6
		_: return 4

static func _get_raid_reward_multiplier(difficulty: String) -> float:
	"""Get reward multiplier for raid difficulty"""
	match difficulty:
		"easy": return 1.0
		"normal": return 1.5
		"hard": return 2.0
		"nightmare": return 3.0
		_: return 1.0
