# scripts/systems/battle/BattleCoordinator.gd
# Simplified battle coordinator - replaces 1043-line BattleManager god class
class_name BattleCoordinator extends Node

# Core battle components
var turn_manager: TurnManager
var action_processor: BattleActionProcessor
var wave_manager: WaveManager
var battle_state: BattleState

# Battle flow state
var current_battle_config
var is_battle_active: bool = false
var auto_battle_enabled: bool = false

# Signals for battle events
signal battle_started(config)
signal battle_ended(result: BattleResult)
signal turn_changed(current_unit: BattleUnit)
signal battle_log_message(message: String)

func initialize():
	"""Initialize battle coordinator and sub-systems"""
	print("BattleCoordinator: Initializing...")
	
	# Create sub-systems
	turn_manager = TurnManager.new()
	action_processor = BattleActionProcessor.new()
	wave_manager = WaveManager.new()
	
	add_child(turn_manager)
	add_child(action_processor)
	add_child(wave_manager)
	
	# Connect sub-system signals
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_ended.connect(_on_turn_ended)
	action_processor.action_executed.connect(_on_action_executed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	
	print("BattleCoordinator: Initialization complete")

## Helper method to get EventBus from SystemRegistry
func _get_event_bus():
	var registry = SystemRegistry.get_instance()
	return registry.get_system("EventBus") if registry else null

## Start a new battle with the given configuration
func start_battle(config) -> bool:
	if is_battle_active:
		push_warning("BattleCoordinator: Battle already active, ending previous battle")
		end_battle(BattleResult.create_defeat("Battle interrupted"))
		return false
	
	print("BattleCoordinator: Starting ", config.battle_type, " battle")
	
	# Validate battle configuration
	if not _validate_battle_config(config):
		push_error("BattleCoordinator: Invalid battle configuration")
		return false
	
	# Store config and create battle state
	current_battle_config = config
	battle_state = BattleState.new()
	battle_state.setup_from_config(config)
	
	# Initialize battle systems
	_initialize_battle_systems()
	
	# Start the battle
	is_battle_active = true
	battle_started.emit(config)
	
	# TODO: Re-enable EventBus once parsing issues resolved
	# EventBus.battle_started.emit(config)
	
	# Begin battle flow
	_begin_battle_flow()
	
	return true

## End the current battle with the given result
func end_battle(result: BattleResult):
	if not is_battle_active:
		return
	
	print("BattleCoordinator: Ending battle - ", "Victory" if result.victory else "Defeat")
	
	# Stop auto-battle if active
	auto_battle_enabled = false
	
	# Calculate final battle statistics
	result.duration = battle_state.get_battle_duration()
	result.battle_type = current_battle_config.battle_type
	
	# Award rewards if victory
	if result.victory:
		result.rewards = _calculate_battle_rewards()
		_award_battle_rewards(result.rewards)
	
	# Cleanup battle state
	_cleanup_battle()
	
	# Emit events
	is_battle_active = false
	battle_ended.emit(result)
	
	# TODO: Re-enable EventBus once parsing issues resolved  
	# EventBus.battle_ended.emit(result)
	
	print("BattleCoordinator: Battle ended successfully")

## Toggle auto-battle mode
func set_auto_battle(enabled: bool):
	auto_battle_enabled = enabled
	if enabled:
		print("BattleCoordinator: Auto-battle enabled")
		_process_auto_battle()
	else:
		print("BattleCoordinator: Auto-battle disabled")

## Execute a manual action (when auto-battle is off)
func execute_action(action) -> bool:
	if not is_battle_active:
		return false
	
	if auto_battle_enabled:
		push_warning("BattleCoordinator: Cannot execute manual action during auto-battle")
		return false
	
	return action_processor.execute_action(action, battle_state)

## Get current battle state (for UI updates)
func get_battle_state() -> BattleState:
	return battle_state

## Check if a battle is currently active
func is_in_battle() -> bool:
	return is_battle_active

# ============================================================================
# PRIVATE METHODS - BATTLE FLOW
# ============================================================================

func _validate_battle_config(config) -> bool:
	"""Validate that the battle configuration is valid"""
	if not config:
		push_error("BattleCoordinator: Battle config is null")
		return false
	
	if config.attacker_team.is_empty():
		push_error("BattleCoordinator: No attacker team specified")
		return false
	
	if config.defender_team.is_empty() and config.enemy_waves.is_empty():
		push_error("BattleCoordinator: No defenders or enemy waves specified")
		return false
	
	return true

func _initialize_battle_systems():
	"""Initialize all battle sub-systems with current config"""
	# Setup turn order
	var all_units = battle_state.get_all_units()
	turn_manager.setup_turn_order(all_units)
	
	# Setup waves if this is a PvE battle
	if not current_battle_config.enemy_waves.is_empty():
		wave_manager.setup_waves(current_battle_config.enemy_waves)
	
	# Initialize action processor
	action_processor.setup_battle_context(battle_state)

func _begin_battle_flow():
	"""Start the main battle loop"""
	print("BattleCoordinator: Beginning battle flow")
	
	# Start first wave if applicable
	if not current_battle_config.enemy_waves.is_empty():
		wave_manager.start_wave(1)
	
	# Begin turn cycle
	turn_manager.start_battle()
	
	# Start auto-battle if enabled
	if auto_battle_enabled:
		_process_auto_battle()

func _process_auto_battle():
	"""Process auto-battle logic"""
	if not auto_battle_enabled or not is_battle_active:
		return
	
	# Get current unit's turn
	var current_unit = turn_manager.get_current_unit()
	if not current_unit:
		return
	
	# Let AI choose action for enemy units, or auto-battle for player units
	var action: BattleAction
	
	if current_unit.is_enemy():
		action = BattleAI.choose_action(current_unit, battle_state)
	else:
		action = _choose_auto_battle_action(current_unit)
	
	if action:
		action_processor.execute_action(action, battle_state)

func _choose_auto_battle_action(unit: BattleUnit) -> BattleAction:
	"""Choose the best action for auto-battle"""
	# Simple auto-battle AI - always try to use most powerful available skill
	for i in range(unit.skills.size() - 1, -1, -1):  # Check from most powerful skill
		var skill = unit.skills[i]
		if unit.can_use_skill(i):
			var targets = _find_best_targets(skill, battle_state.get_enemy_units())
			if not targets.is_empty():
				return BattleAction.create_skill_action(unit, skill, targets)
	
	# Fallback to basic attack
	var target = _find_best_target(battle_state.get_enemy_units())
	if target:
		return BattleAction.create_attack_action(unit, target)
	
	return null

func _find_best_targets(skill: Skill, potential_targets: Array) -> Array:
	"""Find the best targets for a given skill"""
	# Simple targeting: prioritize lowest HP enemies
	var valid_targets = potential_targets.filter(func(unit): return unit.is_alive())
	if valid_targets.is_empty():
		return []
	
	# Sort by current HP (lowest first)
	valid_targets.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	
	# Return appropriate number of targets based on skill
	var target_count = skill.get_target_count()
	return valid_targets.slice(0, min(target_count, valid_targets.size()))

func _find_best_target(potential_targets: Array) -> BattleUnit:
	"""Find the best single target"""
	var targets = _find_best_targets(null, potential_targets)
	return targets[0] if not targets.is_empty() else null

func _calculate_battle_rewards() -> Dictionary:
	"""Calculate rewards based on battle type and performance"""
	var rewards = {}
	
	match current_battle_config.battle_type:
		"dungeon":
			rewards = _calculate_dungeon_rewards()
		"territory":
			rewards = _calculate_territory_rewards()
		"arena":
			rewards = _calculate_arena_rewards()
		_:
			rewards = {"experience": 100, "gold": 50}
	
	return rewards

func _calculate_dungeon_rewards() -> Dictionary:
	var base_rewards = current_battle_config.base_rewards
	var multiplier = 1.0
	
	# Bonus for completing without losses
	if not battle_state.has_unit_deaths():
		multiplier += 0.5
	
	# Apply multiplier
	var rewards = {}
	for resource in base_rewards:
		rewards[resource] = int(base_rewards[resource] * multiplier)
	
	return rewards

func _calculate_territory_rewards() -> Dictionary:
	return current_battle_config.base_rewards

func _calculate_arena_rewards() -> Dictionary:
	return {"arena_tokens": 5, "gold": 1000}

func _award_battle_rewards(rewards: Dictionary):
	"""Award the calculated rewards to the player"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if not resource_manager:
		return
	
	for resource in rewards:
		var amount = rewards[resource]
		resource_manager.add_resource(resource, amount)
		
		var event_bus = _get_event_bus()
		if event_bus:
			event_bus.notification_created.emit("Gained " + str(amount) + " " + resource, "reward", 2.0)

func _cleanup_battle():
	"""Clean up battle state and systems"""
	if battle_state:
		battle_state.cleanup()
		battle_state = null
	
	if turn_manager:
		turn_manager.end_battle()
	
	if wave_manager:
		wave_manager.reset()
	
	current_battle_config = null

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_turn_started(unit: BattleUnit):
	print("BattleCoordinator: Turn started for ", unit.get_name())
	turn_changed.emit(unit)
	
	# Process auto-battle if enabled
	if auto_battle_enabled:
		# Add small delay for visual feedback
		await get_tree().create_timer(0.5).timeout
		_process_auto_battle()

func _on_turn_ended(unit: BattleUnit):
	print("BattleCoordinator: Turn ended for ", unit.get_name())
	
	# Check for battle end conditions
	if _check_battle_end_conditions():
		return  # Battle ended
	
	# Continue to next turn
	turn_manager.advance_turn()

func _on_action_executed(_action: BattleAction, result: ActionResult):
	battle_log_message.emit(result.get_log_message())
	
	# Check if action caused battle to end
	_check_battle_end_conditions()

func _on_wave_started(wave_number: int):
	var event_bus = _get_event_bus()
	if event_bus:
		event_bus.wave_started.emit(wave_number)
	battle_log_message.emit("Wave " + str(wave_number) + " started!")

func _on_wave_completed(wave_number: int):
	var event_bus = _get_event_bus()
	if event_bus:
		event_bus.wave_completed.emit(wave_number)
	battle_log_message.emit("Wave " + str(wave_number) + " completed!")

func _on_all_waves_completed():
	# All waves completed = victory
	var result = BattleResult.create_victory("All waves defeated")
	end_battle(result)

func _check_battle_end_conditions() -> bool:
	"""Check if battle should end and end it if necessary"""
	# Check if all player units are defeated
	var player_units_alive = battle_state.get_player_units().any(func(unit): return unit.is_alive())
	if not player_units_alive:
		end_battle(BattleResult.create_defeat("All player units defeated"))
		return true
	
	# Check if all enemy units are defeated (for PvP battles)
	if current_battle_config.enemy_waves.is_empty():
		var enemy_units_alive = battle_state.get_enemy_units().any(func(unit): return unit.is_alive())
		if not enemy_units_alive:
			end_battle(BattleResult.create_victory("All enemies defeated"))
			return true
	
	return false

func shutdown():
	"""Shutdown the battle coordinator cleanly"""
	if is_battle_active:
		end_battle(BattleResult.create_defeat("Battle system shutdown"))
	
	print("BattleCoordinator: Shutdown complete")
