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

# System references
var resource_manager: Node
var battle_coordinator: Node
var collection_manager: Node
var territory_manager: Node

# Current battle state
var current_dungeon_battle: Dictionary = {}
var battle_in_progress: bool = false

func _ready():
	"""Initialize dungeon coordinator"""
	_connect_to_systems()

func _connect_to_systems():
	"""Connect to required systems via SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		push_error("DungeonCoordinator: SystemRegistry not available")
		return
	
	resource_manager = system_registry.get_system("ResourceManager")
	battle_coordinator = system_registry.get_system("BattleCoordinator")
	collection_manager = system_registry.get_system("CollectionManager")
	territory_manager = system_registry.get_system("TerritoryManager")
	
	# Connect battle completion signals
	if battle_coordinator:
		battle_coordinator.battle_ended.connect(_on_battle_completed)

func start_dungeon_battle(dungeon_id: String, difficulty: String, team: Array) -> Dictionary:
	"""Start a dungeon battle with validation"""
	
	# Validate not already in battle
	if battle_in_progress:
		return {"success": false, "error": "Battle already in progress"}
	
	# Validate energy cost
	var energy_cost = _get_energy_cost(dungeon_id, difficulty)
	if not resource_manager or not resource_manager.can_spend("energy", energy_cost):
		return {"success": false, "error": "Not enough energy"}
	
	# Validate team
	var team_validation = _validate_battle_team(team)
	if not team_validation.success:
		return team_validation
	
	# Get dungeon battle data
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	if not dungeon_manager:
		return {"success": false, "error": "Dungeon manager not available"}
	
	var battle_config = dungeon_manager.get_battle_configuration(dungeon_id, difficulty)
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
		var battle_result = battle_coordinator.start_battle(team, battle_config.enemies, battle_config)
		if not battle_result.success:
			_reset_battle_state()
			resource_manager.add("energy", energy_cost)  # Refund energy
			return battle_result
	
	# Emit signal for UI
	dungeon_battle_started.emit(dungeon_id, difficulty)
	
	return {"success": true, "message": "Dungeon battle started"}

func _get_energy_cost(_dungeon_id: String, difficulty: String) -> int:
	"""Calculate energy cost for dungeon battle"""
	# Base cost varies by difficulty
	var base_costs = {
		"easy": 8,
		"normal": 10,
		"hard": 12,
		"hell": 15
	}
	
	return base_costs.get(difficulty, 10)

func _validate_battle_team(team: Array) -> Dictionary:
	"""Validate team composition for dungeon battle"""
	if team.is_empty():
		return {"success": false, "error": "Team cannot be empty"}
	
	if team.size() > 5:
		return {"success": false, "error": "Team cannot exceed 5 gods"}
	
	# Validate each god
	for god in team:
		if not god or not god.has_method("get_power_rating"):
			return {"success": false, "error": "Invalid god in team"}
		
		# Check god health
		if god.current_hp <= 0:
			return {"success": false, "error": "Dead gods cannot battle"}
	
	return {"success": true}

func _on_battle_completed(result: Dictionary):
	"""Handle battle completion from BattleCoordinator"""
	if not battle_in_progress or current_dungeon_battle.is_empty():
		return
	
	var _dungeon_id = current_dungeon_battle.dungeon_id
	var _difficulty = current_dungeon_battle.difficulty

	if result.victory:
		_handle_dungeon_victory(result)
	else:
		_handle_dungeon_defeat(result)
	
	_reset_battle_state()

func _handle_dungeon_victory(_battle_result: Dictionary):
	"""Process dungeon victory rewards and progression"""
	var dungeon_id = current_dungeon_battle.dungeon_id
	var difficulty = current_dungeon_battle.difficulty
	
	# Calculate completion time
	var completion_time = Time.get_unix_time_from_system() - current_dungeon_battle.start_time
	
	# Get dungeon manager for rewards
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	if dungeon_manager:
		# Award completion rewards
		var rewards = dungeon_manager.get_completion_rewards(dungeon_id, difficulty)
		if resource_manager and not rewards.is_empty():
			resource_manager.add_bulk_resources(rewards)
	
	# Award experience to team
	if collection_manager:
		var exp_per_god = _calculate_experience_reward(difficulty)
		for god in current_dungeon_battle.team:
			collection_manager.award_experience(god.id, exp_per_god)
	
	# Update dungeon progress
	if dungeon_manager:
		dungeon_manager.record_completion(dungeon_id, difficulty, completion_time)
	
	# Emit completion signal
	var result_data = {
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"victory": true,
		"completion_time": completion_time,
		"rewards": dungeon_manager.get_completion_rewards(dungeon_id, difficulty) if dungeon_manager else {}
	}
	
	dungeon_battle_completed.emit(result_data)

func _handle_dungeon_defeat(_battle_result: Dictionary):
	"""Process dungeon defeat"""
	var dungeon_id = current_dungeon_battle.dungeon_id
	var difficulty = current_dungeon_battle.difficulty
	
	# Small consolation rewards on defeat
	if resource_manager:
		var consolation_rewards = {"experience": 10}
		resource_manager.add_bulk_resources(consolation_rewards)
	
	# Emit defeat signal
	dungeon_battle_failed.emit(dungeon_id, difficulty, "Battle lost")
	
	var result_data = {
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"victory": false,
		"rewards": {"experience": 10}
	}
	
	dungeon_battle_completed.emit(result_data)

func _calculate_experience_reward(difficulty: String) -> int:
	"""Calculate experience reward per god based on difficulty"""
	var base_exp = {
		"easy": 25,
		"normal": 50,
		"hard": 100,
		"hell": 200
	}
	
	return base_exp.get(difficulty, 50)

func _reset_battle_state():
	"""Reset battle state after completion"""
	current_dungeon_battle.clear()
	battle_in_progress = false

func is_battle_in_progress() -> bool:
	"""Check if dungeon battle is currently in progress"""
	return battle_in_progress

func get_current_battle_info() -> Dictionary:
	"""Get current battle information"""
	return current_dungeon_battle.duplicate()

# System interface methods
func initialize():
	"""Initialize system - called by SystemRegistry"""
	print("DungeonCoordinator: System initialized")

func shutdown():
	"""Shutdown system - called by SystemRegistry"""
	if battle_in_progress:
		_reset_battle_state()
	print("DungeonCoordinator: System shutdown")
