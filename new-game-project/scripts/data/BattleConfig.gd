# scripts/data/BattleConfig.gd
# Battle configuration data class - defines how battles should be set up
class_name BattleConfig extends Resource

enum BattleType {
	ARENA,      # PvP battles
	DUNGEON,    # PvE dungeon battles  
	TERRITORY,  # Territory conquest battles
	RAID,       # Guild raid battles
	STORY       # Story mode battles
}

# Core battle setup
@export var battle_type: BattleType = BattleType.DUNGEON
@export var attacker_team: Array = []  # Array[God]
@export var defender_team: Array = []  # Array[God] - For PvP battles
@export var enemy_waves: Array = []  # Array[Array] - For PvE battles

# Battle parameters
@export var max_turns: int = 50
@export var allow_auto_battle: bool = true
@export var time_limit: float = 0.0  # 0 = no time limit

# Rewards and loot
@export var base_rewards: Dictionary = {}
@export var loot_table_id: String = ""
@export var experience_multiplier: float = 1.0

# Battle modifiers
@export var battle_modifiers: Array = []  # Array[String] - Special battle conditions
@export var environmental_effects: Array = []  # Array[String]

# Context data
@export var dungeon_id: String = ""
@export var territory_id: String = ""
@export var difficulty_level: int = 1

## Create a new dungeon battle configuration
static func create_dungeon_battle(dungeon_name: String, player_team: Array, difficulty: int = 1) -> BattleConfig:  # Array[God]
	var config = BattleConfig.new()
	config.battle_type = BattleType.DUNGEON
	config.dungeon_id = dungeon_name
	config.attacker_team = player_team.duplicate()
	config.difficulty_level = difficulty
	config.allow_auto_battle = true
	
	# Load dungeon data to set up waves
	var dungeon_data = JSONLoader.load_file("res://data/dungeons.json")
	if dungeon_data.has(dungeon_name):
		var dungeon = dungeon_data[dungeon_name]
		config._setup_dungeon_waves(dungeon, difficulty)
		config.base_rewards = dungeon.get("rewards", {})
		config.loot_table_id = dungeon.get("loot_table", "")
	
	return config

## Create a new arena battle configuration
static func create_arena_battle(attacking_team: Array, defending_team: Array) -> BattleConfig:  # Array[God], Array[God]
	var config = BattleConfig.new()
	config.battle_type = BattleType.ARENA
	config.attacker_team = attacking_team.duplicate()
	config.defender_team = defending_team.duplicate()
	config.allow_auto_battle = true
	config.max_turns = 30  # Arena battles are shorter
	
	return config

## Create a new territory battle configuration
static func create_territory_battle(territory_name: String, attacking_team: Array) -> BattleConfig:  # Array[God]
	var config = BattleConfig.new()
	config.battle_type = BattleType.TERRITORY
	config.territory_id = territory_name
	config.attacker_team = attacking_team.duplicate()
	
	# Load territory data to set up defenders
	var territory_data = JSONLoader.load_file("res://data/territories.json")
	if territory_data.has(territory_name):
		var territory = territory_data[territory_name]
		config._setup_territory_defenders(territory)
		config.base_rewards = territory.get("capture_rewards", {})
	
	return config

## Create a test battle configuration for debugging
static func create_test_battle() -> BattleConfig:
	var config = BattleConfig.new()
	config.battle_type = BattleType.STORY
	config.allow_auto_battle = true
	config.max_turns = 20
	
	# Create simple test teams
	var test_god = God.new()
	test_god.id = "ares"
	test_god.name = "Test Ares"
	config.attacker_team = [test_god]
	
	var test_enemy = {"name": "Test Enemy", "hp": 1000, "attack": 200, "defense": 100}
	config.enemy_waves = [[test_enemy]]
	
	return config

# ============================================================================
# PRIVATE SETUP METHODS
# ============================================================================

func _setup_dungeon_waves(dungeon_data: Dictionary, difficulty: int):
	"""Setup enemy waves based on dungeon data and difficulty"""
	var waves = dungeon_data.get("waves", [])
	var enemies_data = JSONLoader.load_file("res://data/enemies.json")
	
	enemy_waves.clear()
	
	for wave_data in waves:
		var wave_enemies = []
		
		for enemy_id in wave_data.get("enemies", []):
			if enemies_data.has(enemy_id):
				var enemy = enemies_data[enemy_id].duplicate()
				_scale_enemy_for_difficulty(enemy, difficulty)
				wave_enemies.append(enemy)
		
		enemy_waves.append(wave_enemies)

func _setup_territory_defenders(territory_data: Dictionary):
	"""Setup defender team based on territory data"""
	var defenders = territory_data.get("defenders", [])
	var gods_data = JSONLoader.load_file("res://data/gods.json")
	
	defender_team.clear()
	
	for defender_id in defenders:
		if gods_data.has(defender_id):
			var god = GodFactory.create_from_json(defender_id)
			if god:
				defender_team.append(god)

func _scale_enemy_for_difficulty(enemy: Dictionary, difficulty: int):
	"""Scale enemy stats based on difficulty level"""
	var scale_factor = 1.0 + (difficulty - 1) * 0.3  # +30% per difficulty level
	
	enemy["hp"] = int(enemy.get("hp", 100) * scale_factor)
	enemy["current_hp"] = enemy["hp"]  # Ensure current_hp matches max
	enemy["attack"] = int(enemy.get("attack", 50) * scale_factor)
	enemy["defense"] = int(enemy.get("defense", 30) * scale_factor)
	enemy["speed"] = int(enemy.get("speed", 100) * scale_factor)

## Get total number of waves
func get_wave_count() -> int:
	return enemy_waves.size()

## Get total number of enemies across all waves
func get_total_enemy_count() -> int:
	var total = 0
	for wave in enemy_waves:
		total += wave.size()
	return total

## Validate that the battle configuration is complete and valid
func is_valid() -> bool:
	# Must have attacker team
	if attacker_team.is_empty():
		return false
	
	# Must have either defenders or enemy waves
	if defender_team.is_empty() and enemy_waves.is_empty():
		return false
	
	# Check that gods are valid
	for god in attacker_team:
		if not god or not god.is_valid():
			return false
	
	for god in defender_team:
		if not god or not god.is_valid():
			return false
	
	return true

## Get a string description of this battle config (for debugging)
func get_description() -> String:
	var type_name = BattleType.keys()[battle_type]
	var attacker_count = attacker_team.size()
	var defender_count = defender_team.size() + get_total_enemy_count()
	
	return "%s Battle: %d vs %d" % [type_name, attacker_count, defender_count]
