# scripts/data/BattleConfig.gd
# Battle configuration data class - ONLY data properties (RULE 3 compliance)
class_name BattleConfig extends Resource

enum BattleType {
	ARENA,      # PvP battles
	DUNGEON,    # PvE dungeon battles  
	TERRITORY,  # Territory conquest battles
	RAID,       # Guild raid battles
	STORY       # Story mode battles
}

# Core battle setup - ONLY properties, NO logic
@export var battle_type: BattleType = BattleType.DUNGEON
@export var attacker_team: Array = []  # Array[God]
@export var defender_team: Array = []  # Array[God] - For PvP battles
@export var enemy_waves: Array = []  # Array[Array] - For PvE battles

# Battle parameters
@export var max_turns: int = 50
@export var allow_auto_battle: bool = true
@export var allow_speed_up: bool = true
@export var victory_condition: String = "defeat_all_enemies"
@export var defeat_condition: String = "all_gods_defeated"
@export var time_limit: float = 0.0  # 0 = no time limit

# Context data
@export var territory_id: String = ""
@export var stage_number: int = 1
@export var dungeon_name: String = ""
@export var floor_number: int = 1
@export var boss_fight: bool = false
@export var arena_tier: String = ""
@export var opponent_player_id: String = ""

# Rewards and loot
@export var base_rewards: Dictionary = {}
@export var loot_table_id: String = ""
@export var experience_multiplier: float = 1.0

# Battle modifiers
@export var battle_modifiers: Array = []  # Array[String] - Special battle conditions
@export var environmental_effects: Array = []  # Array[String]

# Simple getters only - no business logic (RULE 3 compliance)
func get_battle_type_name() -> String:
	match battle_type:
		BattleType.ARENA: return "arena"
		BattleType.DUNGEON: return "dungeon" 
		BattleType.TERRITORY: return "territory"
		BattleType.RAID: return "raid"
		BattleType.STORY: return "story"
		_: return "unknown"

func has_enemy_waves() -> bool:
	return enemy_waves.size() > 0

func has_defender_team() -> bool:
	return defender_team.size() > 0

func is_pve_battle() -> bool:
	return battle_type in [BattleType.DUNGEON, BattleType.TERRITORY, BattleType.STORY]

func is_pvp_battle() -> bool:
	return battle_type in [BattleType.ARENA, BattleType.RAID]

func get_wave_count() -> int:
	return enemy_waves.size()
