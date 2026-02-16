# scripts/systems/dungeon/DungeonCoordinator.gd
# RULE 1: Under 500 lines - Dungeon battle coordination
# RULE 2: Single responsibility - Coordinate dungeon battles only
# RULE 4: No UI logic - System logic only
# RULE 5: SystemRegistry integration
extends Node
class_name DungeonCoordinator


# Signals for UI communication
signal dungeon_battle_started(dungeon_id: String, difficulty: String)
signal dungeon_battle_completed(result: Dictionary)
signal dungeon_battle_failed(dungeon_id: String, difficulty: String, reason: String)
signal dungeon_completed(dungeon_id: String, difficulty: String)  # For progression systems

# System references
var resource_manager: Node
var battle_coordinator: Node
var collection_manager: Node
var territory_manager: Node
var loot_system: Node

# Current battle state
var current_dungeon_battle: Dictionary = {}
var battle_in_progress: bool = false

func _ready() -> void:
	_connect_to_systems()

func _connect_to_systems() -> void:
	var system_registry: SystemRegistry = SystemRegistry.get_instance()
	if not system_registry:
		push_error("DungeonCoordinator: SystemRegistry not available")
		return
	
	resource_manager = system_registry.get_system("ResourceManager")
	battle_coordinator = system_registry.get_system("BattleCoordinator")
	collection_manager = system_registry.get_system("CollectionManager")
	territory_manager = system_registry.get_system("TerritoryManager")
	loot_system = system_registry.get_system("LootSystem")

	# Connect battle completion signals
	if battle_coordinator:
		battle_coordinator.battle_ended.connect(_on_battle_completed)

func start_dungeon_battle(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	# Validate not already in battle
	if battle_in_progress:
		return {"success": false, "error": "Battle already in progress"}
	
	# Validate energy cost
	var energy_cost: int = _get_energy_cost(dungeon_id, difficulty)
	if not resource_manager or not resource_manager.can_spend("energy", energy_cost):
		return {"success": false, "error": "Not enough energy"}
	
	# Validate team
	var team_validation: Dictionary = _validate_battle_team(team)
	if not team_validation.success:
		return team_validation
	
	# Get dungeon battle data
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if not registry:
		return {"success": false, "error": "System registry not available"}
	var dungeon_manager: Node = registry.get_system("DungeonManager")
	if not dungeon_manager:
		return {"success": false, "error": "Dungeon manager not available"}

	var battle_config: Dictionary = dungeon_manager.get_battle_configuration(dungeon_id, difficulty)
	if battle_config.is_empty():
		return {"success": false, "error": "Invalid dungeon configuration"}
	
	# Spend energy
	if not resource_manager.spend("energy", energy_cost):
		return {"success": false, "error": "Failed to spend energy"}
	
	# Setup battle state
	current_dungeon_battle = {
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"team": team,
		"energy_spent": energy_cost,
		"start_time": Time.get_unix_time_from_system()
	}
	
	battle_in_progress = true
	
	# Start battle through BattleCoordinator
	if battle_coordinator:
		var battle_result: Dictionary = battle_coordinator.start_battle(team, battle_config.enemies, battle_config)
		if not battle_result.success:
			_reset_battle_state()
			resource_manager.add("energy", energy_cost)  # Refund energy
			return battle_result
	
	# Emit signal for UI
	dungeon_battle_started.emit(dungeon_id, difficulty)
	
	return {"success": true, "message": "Dungeon battle started"}

func _get_energy_cost(dungeon_id: String, difficulty: String) -> int:
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if not registry:
		return 10
	var dungeon_manager: Node = registry.get_system("DungeonManager")
	if dungeon_manager:
		var dungeon_info: Dictionary = dungeon_manager.get_dungeon_info(dungeon_id)
		var difficulty_info: Dictionary = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		return difficulty_info.get("energy_cost", 10)
	return 10

func _validate_battle_team(team: Array) -> Dictionary:
	if team.is_empty():
		return {"success": false, "error": "Team cannot be empty"}
	
	if team.size() > DungeonConstants.MAX_TEAM_SIZE:
		return {"success": false, "error": "Team cannot exceed %d gods" % DungeonConstants.MAX_TEAM_SIZE}
	
	# Validate each god
	for god in team:
		if not god or not god is God:
			return {"success": false, "error": "Invalid god in team"}
		
		# Check god health
		if god.current_hp <= 0:
			return {"success": false, "error": "Dead gods cannot battle"}
	
	return {"success": true}

func _on_battle_completed(result: BattleResult) -> void:
	if not battle_in_progress or current_dungeon_battle.is_empty():
		return

	if result.victory:
		_handle_dungeon_victory(result)
	else:
		_handle_dungeon_defeat(result)

	_reset_battle_state()

func _handle_dungeon_victory(battle_result: BattleResult) -> void:
	var dungeon_id: String = current_dungeon_battle.get("dungeon_id", "")
	var difficulty: String = current_dungeon_battle.get("difficulty", "")
	var start_time: float = current_dungeon_battle.get("start_time", Time.get_unix_time_from_system())
	var completion_time: float = Time.get_unix_time_from_system() - start_time

	var registry: SystemRegistry = SystemRegistry.get_instance()
	var dungeon_manager: Node = registry.get_system("DungeonManager") if registry else null
	var all_rewards: Dictionary = _generate_victory_rewards(dungeon_id, difficulty, dungeon_manager, battle_result)

	_award_team_experience(difficulty, battle_result)

	if dungeon_manager:
		dungeon_manager.record_completion(dungeon_id, difficulty, completion_time)

	dungeon_completed.emit(dungeon_id, difficulty)

	dungeon_battle_completed.emit({
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"victory": true,
		"completion_time": completion_time,
		"rewards": all_rewards
	})

func _generate_victory_rewards(dungeon_id: String, difficulty: String, dungeon_manager: Node, battle_result: BattleResult) -> Dictionary:
	var all_rewards: Dictionary = {}

	if dungeon_manager and loot_system:
		var loot_table_id: String = dungeon_manager.get_loot_table_name(dungeon_id, difficulty)
		var dungeon_info: Dictionary = dungeon_manager.get_dungeon_info(dungeon_id)
		var element: String = dungeon_info.get("element", "")
		var multiplier: float = DungeonConstants.get_difficulty_reward_multiplier(difficulty)

		# Generate loot from table
		if not loot_table_id.is_empty():
			var generated_loot: Dictionary = loot_system.generate_loot(loot_table_id, multiplier, element)
			_merge_rewards(all_rewards, generated_loot, battle_result, "loot_table")

		# First-clear bonus
		if dungeon_manager.is_first_clear(dungeon_id, difficulty):
			var first_clear_rewards: Dictionary = dungeon_manager.get_first_clear_rewards(dungeon_id, difficulty)
			_merge_rewards(all_rewards, first_clear_rewards, battle_result, "first_clear")

		# Award all loot through LootSystem (updates ResourceManager)
		if not all_rewards.is_empty():
			loot_system.award_loot(all_rewards)

	elif dungeon_manager:
		# Fallback if LootSystem not available
		var rewards: Dictionary = dungeon_manager.get_completion_rewards(dungeon_id, difficulty)
		if resource_manager and not rewards.is_empty():
			resource_manager.add_bulk_resources(rewards)
		all_rewards = rewards

	return all_rewards

func _merge_rewards(all_rewards: Dictionary, new_rewards: Dictionary, battle_result: BattleResult, source: String) -> void:
	for resource_id: String in new_rewards:
		var amount: int = new_rewards[resource_id]
		all_rewards[resource_id] = all_rewards.get(resource_id, 0) + amount
		battle_result.add_reward(resource_id, amount)
		battle_result.add_loot_item({
			"resource_id": resource_id,
			"amount": amount,
			"source": source
		})

func _award_team_experience(difficulty: String, battle_result: BattleResult) -> void:
	if not collection_manager:
		return
	var exp_per_god: int = _calculate_experience_reward(difficulty)
	var team: Array = current_dungeon_battle.get("team", [])
	for god: God in team:
		collection_manager.award_experience(god.id, exp_per_god)
		battle_result.add_experience_gained(god.id, exp_per_god)

func _handle_dungeon_defeat(_battle_result: BattleResult) -> void:
	var dungeon_id: String = current_dungeon_battle.get("dungeon_id", "")
	var difficulty: String = current_dungeon_battle.get("difficulty", "")

	# Small consolation rewards on defeat
	if resource_manager:
		var consolation_rewards: Dictionary = {"experience": 10}
		resource_manager.add_bulk_resources(consolation_rewards)
	
	# Emit defeat signal
	dungeon_battle_failed.emit(dungeon_id, difficulty, "Battle lost")
	
	var result_data: Dictionary = {
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"victory": false,
		"rewards": {"experience": 10}
	}
	
	dungeon_battle_completed.emit(result_data)

func _calculate_experience_reward(difficulty: String) -> int:
	var base_exp: Dictionary = {
		"easy": 25,
		"normal": 50,
		"hard": 100,
		"hell": 200,
		"beginner": 25,
		"intermediate": 50,
		"advanced": 100,
		"expert": 150,
		"heroic": 100,
		"legendary": 200
	}

	return base_exp.get(difficulty, 50)


func _reset_battle_state() -> void:
	current_dungeon_battle.clear()
	battle_in_progress = false

# System interface methods
func initialize() -> void:
	pass

func shutdown() -> void:
	if battle_in_progress:
		_reset_battle_state()
