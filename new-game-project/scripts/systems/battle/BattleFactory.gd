# scripts/systems/battle/BattleFactory.gd
# Battle configuration factory - creates battle setups (100 lines max)
class_name BattleFactory extends Node

# Factory for creating different types of battles

enum BattleType {
	TERRITORY,
	DUNGEON,
	ARENA,
	RAID,
	GUILD_WAR
}

## Create a territory battle
func create_territory_battle(_territory_id: String, player_gods: Array) -> Dictionary:
	var battle_config = {
		"type": "territory",
		"territory_id": _territory_id,
		"player_team": player_gods,
		"enemy_team": _generate_territory_enemies(_territory_id),
		"waves": 1,
		"victory_conditions": ["defeat_all_enemies"],
		"defeat_conditions": ["all_players_dead"]
	}
	
	return battle_config

## Create a dungeon battle
func create_dungeon_battle(dungeon_id: String, stage: int, player_gods: Array) -> Dictionary:
	var battle_config = {
		"type": "dungeon",
		"dungeon_id": dungeon_id,
		"stage": stage,
		"player_team": player_gods,
		"enemy_team": _generate_dungeon_enemies(dungeon_id, stage),
		"waves": _get_dungeon_waves(dungeon_id, stage),
		"victory_conditions": ["defeat_all_waves"],
		"defeat_conditions": ["all_players_dead", "timeout"]
	}
	
	return battle_config

## Create an arena battle
func create_arena_battle(player_gods: Array, opponent_gods: Array) -> Dictionary:
	var battle_config = {
		"type": "arena",
		"player_team": player_gods,
		"enemy_team": opponent_gods,
		"waves": 1,
		"victory_conditions": ["defeat_all_enemies"],
		"defeat_conditions": ["all_players_dead"],
		"time_limit": 300  # 5 minutes
	}
	
	return battle_config

## Generate territory enemies based on territory
func _generate_territory_enemies(territory_id: String) -> Array:
	# Get enemy configuration from data
	var enemy_factory = SystemRegistry.get_instance().get_system("EnemyFactory") if SystemRegistry.get_instance() else null
	if enemy_factory:
		return enemy_factory.create_territory_enemies(territory_id)
	
	# Fallback
	return _create_fallback_enemies()

## Generate dungeon enemies
func _generate_dungeon_enemies(dungeon_id: String, stage: int) -> Array:
	var enemy_factory = SystemRegistry.get_instance().get_system("EnemyFactory") if SystemRegistry.get_instance() else null
	if enemy_factory:
		return enemy_factory.create_dungeon_enemies(dungeon_id, stage)
	
	return _create_fallback_enemies()

## Get dungeon wave count
func _get_dungeon_waves(dungeon_id: String, stage: int) -> int:
	# Different dungeons have different wave patterns
	match dungeon_id:
		"giants_keep":
			return 3 if stage >= 7 else 2
		"dragons_lair":
			return 4 if stage >= 10 else 3
		"necropolis":
			return 5
		_:
			return 1

## Create fallback enemies for testing
func _create_fallback_enemies() -> Array:
	var enemies = []
	
	# Create basic enemy BattleUnits
	for i in range(3):
		var enemy = BattleUnit.new()
		enemy.id = "test_enemy_" + str(i)
		enemy.max_hp = 1000
		enemy.current_hp = 1000
		enemy.attack = 150
		enemy.defense = 100
		enemy.speed = 100 + i * 10
		enemies.append(enemy)
	
	return enemies
