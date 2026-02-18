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
var _auto_battle_processing: bool = false  # Guard against overlapping auto-battle

# Signals for battle events
signal battle_started(config)
signal battle_ended(result: BattleResult)
signal turn_changed(current_unit: BattleUnit)
signal battle_log_message(message: String)

func initialize():
	"""Initialize battle coordinator and sub-systems"""
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

## Helper method to get EventBus from SystemRegistry
func _get_event_bus():
	var registry = SystemRegistry.get_instance()
	return registry.get_system("EventBus") if registry else null

## Helper method to get DebugLogger from SystemRegistry
func _get_debug_logger():
	var registry = SystemRegistry.get_instance()
	return registry.get_system("DebugLogger") if registry else null

## Start a new battle with the given configuration
func start_battle(config) -> bool:

	# Force cleanup any stale battle state before starting
	# This prevents the perma-defeat bug where old state blocks new battles
	if is_battle_active or battle_state != null or current_battle_config != null:
		_force_cleanup_stale_battle()

	# Validate battle configuration
	if not _validate_battle_config(config):
		push_error("BattleCoordinator: Invalid battle configuration")
		return false

	# Validate attacker team has valid gods
	var valid_attackers = config.attacker_team.filter(func(god): return god != null)
	if valid_attackers.is_empty():
		push_error("BattleCoordinator: No valid gods in attacker team")
		return false

	# Store config and create battle state
	current_battle_config = config
	battle_state = BattleState.new()
	battle_state.setup_from_config(config)

	# Verify player units were created properly
	var player_units = battle_state.get_player_units()
	if player_units.is_empty():
		push_error("BattleCoordinator: Failed to create player units from config")
		_force_cleanup_stale_battle()
		return false

	# Verify all player units are alive (fix any stale state from previous battles)
	# Skip for Tower mode - dead gods stay dead between floors
	var is_tower_battle = config.battle_type == BattleConfig.BattleType.TOWER
	for unit in player_units:
		if not unit.is_alive and not is_tower_battle:
			push_warning("BattleCoordinator: Unit %s not alive at battle start, fixing" % unit.display_name)
			unit.is_alive = true
			unit.current_hp = unit.max_hp

	# Initialize battle systems
	_initialize_battle_systems()

	# Start the battle
	is_battle_active = true
	battle_started.emit(config)

	# Emit team composition for analytics
	var event_bus = _get_event_bus()
	if event_bus:
		var god_ids: Array = []
		var team_power: int = 0
		for unit in player_units:
			if unit.source_god:
				god_ids.append(unit.source_god.id)
				team_power += unit.max_hp + (unit.attack * 2) + unit.defense + unit.speed
		var enemy_power: int = 0
		for enemy in battle_state.get_enemy_units():
			enemy_power += enemy.max_hp + (enemy.attack * 2) + enemy.defense + enemy.speed
		event_bus.battle_team_entered.emit({
			"battle_type": config.get_battle_type_name() if config.has_method("get_battle_type_name") else str(config.battle_type),
			"god_ids": god_ids,
			"team_power": team_power,
			"enemy_power": enemy_power
		})

	# Log battle start
	var debug_logger = _get_debug_logger()
	if debug_logger:
		debug_logger.log_battle_start(
			config.get_battle_type_name() if config.has_method("get_battle_type_name") else str(config.battle_type),
			valid_attackers.size(),
			battle_state.get_enemy_units().size(),
			battle_state.max_waves
		)

	# Begin battle flow (defer to next frame to let UI initialize)
	_begin_battle_flow.call_deferred()

	return true

## Force cleanup stale battle state without emitting signals
func _force_cleanup_stale_battle():
	"""Emergency cleanup for stale battle state - used to fix perma-defeat bug"""
	auto_battle_enabled = false
	_auto_battle_processing = false

	if battle_state:
		battle_state.cleanup()
		battle_state = null

	if turn_manager:
		turn_manager.end_battle()

	if wave_manager:
		wave_manager.reset()

	current_battle_config = null
	is_battle_active = false

## End the current battle with the given result
func end_battle(result: BattleResult):
	if not is_battle_active:
		push_warning("BattleCoordinator: end_battle called but is_battle_active is false")
		return

	print("BattleCoordinator: end_battle called - victory=%s, reason=%s" % [result.victory, result.victory_condition if result.victory else result.defeat_reason])

	# Stop auto-battle if active
	auto_battle_enabled = false
	_auto_battle_processing = false

	# Calculate final battle statistics
	result.duration = battle_state.get_battle_duration() if battle_state else 0.0
	result.battle_type = current_battle_config.get_battle_type_name() if current_battle_config else "unknown"

	# Award rewards if victory
	if result.victory:
		result.rewards = _calculate_battle_rewards()
		_award_battle_rewards(result.rewards)
		print("BattleCoordinator: Victory rewards calculated: %s" % str(result.rewards))

	# Emit battle_ended BEFORE cleanup so handlers can access battle_state
	# (e.g., TowerScreen needs to save HP for next floor)
	is_battle_active = false
	print("BattleCoordinator: Emitting battle_ended signal")
	battle_ended.emit(result)

	# Log battle end for debugging
	var debug_logger = _get_debug_logger()
	if debug_logger:
		debug_logger.log_battle_end(
			result.victory,
			result.duration,
			result.victory_condition if result.victory else result.defeat_reason
		)

	# Log analytics for BigQuery/Tableau
	_log_battle_analytics(result)

	# Cleanup battle state AFTER signal handlers have run
	_cleanup_battle()
	print("BattleCoordinator: Battle cleanup complete")

## Toggle auto-battle mode
func set_auto_battle(enabled: bool):
	auto_battle_enabled = enabled
	_auto_battle_processing = false  # Reset processing flag on toggle
	if enabled:
		_process_auto_battle()

## Execute a manual action (when auto-battle is off)
func execute_action(action) -> bool:
	if not is_battle_active:
		return false

	if auto_battle_enabled:
		push_warning("BattleCoordinator: Cannot execute manual action during auto-battle")
		return false

	var success = action_processor.execute_action(action, battle_state)

	# Check if battle ended due to this action before advancing turns
	if success:
		var should_end = _check_battle_end_conditions()
		if not should_end and is_battle_active:
			turn_manager.advance_turn()

	return success

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
	# Safety check - config might be null if battle ended before deferred call
	if not current_battle_config:
		push_warning("BattleCoordinator: _begin_battle_flow called but config is null")
		return

	# Start first wave if applicable
	if current_battle_config.enemy_waves and not current_battle_config.enemy_waves.is_empty():
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

	# Prevent overlapping auto-battle processing
	if _auto_battle_processing:
		return
	_auto_battle_processing = true

	# Get current unit's turn
	var current_unit = turn_manager.get_current_unit()
	if not current_unit:
		_auto_battle_processing = false
		return

	# Safety check - unit might have died from DoT
	if not current_unit.is_alive:
		print("BattleCoordinator: _process_auto_battle called for dead unit %s, advancing turn" % current_unit.display_name)
		_auto_battle_processing = false
		turn_manager.advance_turn()
		return

	# Let AI choose action for enemy units, or auto-battle for player units
	var action: BattleAction

	if current_unit.is_enemy():
		action = BattleAI.choose_action(current_unit, battle_state)
	else:
		action = _choose_auto_battle_action(current_unit)

	if action:
		action_processor.execute_action(action, battle_state)
		# End turn after action (same as enemy turn processing)
		_auto_battle_processing = false
		turn_manager.advance_turn()
	else:
		# No valid action found (e.g., all enemies dead) - check battle end conditions
		# This handles the case where wave ends and we need to advance to next wave
		var battle_ended_or_wave_advanced: bool = _check_battle_end_conditions()

		if not battle_ended_or_wave_advanced and is_battle_active:
			# Battle continues but no valid targets - skip this turn
			print("BattleCoordinator: Auto-battle no valid action, skipping turn for %s" % current_unit.display_name)
			_auto_battle_processing = false
			turn_manager.advance_turn()
		else:
			_auto_battle_processing = false

func _choose_auto_battle_action(unit: BattleUnit) -> BattleAction:
	"""Choose the best action for auto-battle using smart AI"""
	# Use the same smart AI as enemies - this ensures fair Arena PvP
	var action: BattleAction = BattleAI.choose_auto_action(unit, battle_state)

	if action:
		var skill_name: String = action.skill.name if action.skill else "Basic Attack"
		var target_names: String = ", ".join(action.targets.map(func(t): return t.display_name))
		print("[AutoBattle] %s: %s -> %s" % [unit.display_name, skill_name, target_names])
	else:
		var enemy_units: Array[BattleUnit] = battle_state.get_living_enemy_units()
		print("[AutoBattle] %s: No valid action found! Skills: %d, Living enemies: %d" % [unit.display_name, unit.skills.size(), enemy_units.size()])

	return action

func _calculate_battle_rewards() -> Dictionary:
	"""Calculate rewards based on battle type and performance"""
	var rewards = {}
	
	var battle_type_name = current_battle_config.get_battle_type_name() if current_battle_config.has_method("get_battle_type_name") else str(current_battle_config.battle_type)
	match battle_type_name:
		"dungeon":
			rewards = _calculate_dungeon_rewards()
		"territory":
			rewards = _calculate_territory_rewards()
		"arena":
			rewards = _calculate_arena_rewards()
		"tower":
			rewards = _calculate_tower_rewards()
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
	return {"gold": 1000, "mana": 500}

func _calculate_tower_rewards() -> Dictionary:
	"""Calculate tower rewards - delegated to TowerManager"""
	var tower_manager = SystemRegistry.get_instance().get_system("TowerManager")
	if tower_manager and tower_manager.is_run_active():
		# TowerManager handles its own reward calculation
		return {}
	return {"mana": 100, "gold": 50}

func _award_battle_rewards(rewards: Dictionary):
	"""Award the calculated rewards to the player"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if not resource_manager:
		return

	# Award resource rewards
	# Collect all resource gains for a single notification
	var resource_gains: Array[String] = []
	for resource in rewards:
		# Skip experience - we handle god XP separately
		if resource == "experience":
			continue
		var amount = rewards[resource]
		resource_manager.add_resource(resource, amount)
		resource_gains.append("%d %s" % [amount, resource.replace("_", " ").capitalize()])

	# Show single reward notification for all resources
	if not resource_gains.is_empty():
		var NotificationQueueClass = load("res://scripts/ui/components/NotificationQueue.gd")
		if NotificationQueueClass:
			NotificationQueueClass.show_reward("Battle Rewards", ", ".join(resource_gains))

	# Award XP to participating gods
	_award_god_experience(rewards)

func _award_god_experience(rewards: Dictionary):
	"""Award XP to each god that participated in the battle"""
	if not battle_state:
		return

	# Skip XP for tower battles - TowerManager handles all rewards at end of run
	var battle_type_name: String = current_battle_config.get_battle_type_name() if current_battle_config else ""
	if battle_type_name == "tower":
		return

	var god_progression = SystemRegistry.get_instance().get_system("GodProgressionManager")
	if not god_progression:
		push_warning("BattleCoordinator: GodProgressionManager not found, skipping god XP")
		return

	# Get base XP from rewards, or calculate based on battle type
	var base_xp = rewards.get("experience", 100)

	# Bonus XP based on battle difficulty/waves
	var wave_bonus = battle_state.current_wave * 25
	var xp_per_god = base_xp + wave_bonus

	# Award XP to each player unit that has a source god
	for unit in battle_state.get_player_units():
		if unit.source_god:
			god_progression.add_experience_to_god(unit.source_god, xp_per_god)

func _log_battle_analytics(result: BattleResult):
	"""Log detailed battle analytics for BigQuery/Tableau"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return
	var analytics = registry.get_system("FirebaseAnalytics")
	if not analytics:
		return

	# Get battle stats
	var stats: Dictionary = battle_state.get_battle_statistics() if battle_state else {}
	var battle_type_name: String = current_battle_config.get_battle_type_name() if current_battle_config else "unknown"
	var difficulty: String = current_battle_config.difficulty_name if current_battle_config and current_battle_config.has_method("get") else ""

	# Calculate team power
	var team_power: int = 0
	var gods_died: int = 0
	if battle_state:
		for unit in battle_state.get_player_units():
			team_power += unit.max_hp + (unit.attack * 2) + unit.defense + unit.speed
			if not unit.is_alive:
				gods_died += 1

	# Log overall battle stats
	analytics.log_battle_stats(
		battle_type_name,
		difficulty,
		result.victory,
		stats.get("current_turn", 0),
		stats.get("total_damage_dealt", 0),
		stats.get("total_damage_received", 0),
		gods_died,
		stats.get("enemy_units_alive", 0) + (battle_state.enemy_units.size() if battle_state else 0),
		team_power
	)

	# Log individual god usage for balance analytics
	if battle_state:
		for unit in battle_state.get_player_units():
			if unit.source_god:
				analytics.log_god_usage(
					unit.source_god.id,
					unit.source_god.tier,
					unit.source_god.element,
					battle_type_name,
					unit.damage_dealt if "damage_dealt" in unit else 0,
					unit.damage_received if "damage_received" in unit else 0,
					unit.kills if "kills" in unit else 0,
					not unit.is_alive
				)

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
	if not is_battle_active:
		print("BattleCoordinator: _on_turn_started called but battle not active, ignoring")
		return

	turn_changed.emit(unit)

	# Process enemy turns automatically (AI takes action)
	if unit.is_enemy():
		# Add small delay for visual feedback
		await get_tree().create_timer(0.5).timeout
		if not is_battle_active:
			return  # Battle ended during delay
		if not unit.is_alive:
			print("BattleCoordinator: Enemy %s died during delay (DoT), skipping turn" % unit.display_name)
			turn_manager.advance_turn()
			return
		_process_enemy_turn(unit)
	elif auto_battle_enabled:
		# Process auto-battle for player units if enabled
		await get_tree().create_timer(0.5).timeout
		if not is_battle_active:
			return  # Battle ended during delay
		if not unit.is_alive:
			print("BattleCoordinator: Player unit %s died during delay (DoT), skipping turn" % unit.display_name)
			turn_manager.advance_turn()
			return
		# Check if the turn already moved on (can happen if turn was skipped due to status effects)
		var current_unit = turn_manager.get_current_unit()
		if current_unit != unit:
			print("BattleCoordinator: Turn moved on from %s to %s during delay, not processing" % [unit.display_name, current_unit.display_name if current_unit else "none"])
			return
		_process_auto_battle()

func _process_enemy_turn(unit: BattleUnit):
	"""Process an enemy unit's turn using AI"""
	if not is_battle_active:
		return

	# Safety check - unit might have died from DoT or other effects
	if not unit.is_alive:
		print("BattleCoordinator: _process_enemy_turn called for dead unit %s, skipping" % unit.display_name)
		turn_manager.advance_turn()
		return

	# Let AI choose action for enemy
	var action = BattleAI.choose_action(unit, battle_state)
	if action:
		action_processor.execute_action(action, battle_state)
		# End turn after action
		turn_manager.advance_turn()
	else:
		# No valid action found (e.g., all player units dead) - check battle end conditions
		var should_end: bool = _check_battle_end_conditions()
		if not should_end and is_battle_active:
			# Battle continues but no valid targets - skip this turn
			print("BattleCoordinator: Enemy %s has no valid action, skipping turn" % unit.display_name)
			turn_manager.advance_turn()

func _on_turn_ended(_unit: BattleUnit):
	# Check for battle end conditions after turn ends
	# Note: turn advancement is handled by the action execution flow,
	# not here - this is just for checking battle end conditions
	_check_battle_end_conditions()

func _on_action_executed(_action: BattleAction, result: ActionResult):
	battle_log_message.emit(result.get_log_message())
	
	# Check if action caused battle to end
	_check_battle_end_conditions()

func _on_wave_started(wave_number: int):
	var event_bus = _get_event_bus()
	if event_bus:
		event_bus.wave_started.emit(wave_number)
	battle_log_message.emit("Wave " + str(wave_number) + " started!")

	# Small delay to let UI update with new enemies
	await get_tree().create_timer(0.8).timeout

	if not is_battle_active:
		return

	# Resume battle after wave transition
	if auto_battle_enabled:
		_process_auto_battle()
	else:
		# Manual battle - start the next turn
		turn_manager.advance_turn()

func _on_wave_completed(wave_number: int):
	var event_bus = _get_event_bus()
	if event_bus:
		event_bus.wave_completed.emit(wave_number)
	battle_log_message.emit("Wave " + str(wave_number) + " completed!")

func _on_all_waves_completed():
	# All waves completed = victory
	var result = BattleResult.create_victory("All waves defeated")
	end_battle(result)

func _advance_to_next_wave():
	"""Advance to the next wave of enemies"""
	if not current_battle_config or not battle_state:
		push_warning("BattleCoordinator: _advance_to_next_wave called but config/state is null")
		return

	print("BattleCoordinator: _advance_to_next_wave - current wave %d" % battle_state.current_wave)

	# Mark current wave as complete
	wave_manager.complete_current_wave()

	# Get next wave enemies from config
	var next_wave_index = battle_state.current_wave  # current_wave is 1-indexed, array is 0-indexed
	if not current_battle_config.enemy_waves or next_wave_index >= current_battle_config.enemy_waves.size():
		push_error("BattleCoordinator: No more wave data available (index %d, waves %d)" % [next_wave_index, current_battle_config.enemy_waves.size() if current_battle_config.enemy_waves else 0])
		# Force end battle as victory since we ran out of waves
		end_battle(BattleResult.create_victory("All waves completed"))
		return

	var next_wave_enemies = current_battle_config.enemy_waves[next_wave_index]
	print("BattleCoordinator: Loading wave %d with %d enemies" % [next_wave_index + 1, next_wave_enemies.size()])

	# Log wave transition
	var debug_logger = _get_debug_logger()
	if debug_logger:
		debug_logger.log_wave_transition(battle_state.current_wave, next_wave_index + 1, battle_state.max_waves)

	# Advance battle state to next wave (this creates new enemy BattleUnits)
	battle_state.advance_to_next_wave(next_wave_enemies)

	# Replace enemy units in turn manager (removes dead ones, adds new wave)
	turn_manager.replace_enemy_units(battle_state.get_enemy_units())

func _check_battle_end_conditions() -> bool:
	"""Check if battle should end and end it if necessary"""
	if not battle_state or not current_battle_config:
		print("BattleCoordinator: _check_battle_end_conditions - no valid state, ending")
		return true  # No valid state, battle should end

	# Check if all player units are defeated
	var player_units = battle_state.get_player_units()
	var player_units_alive = player_units.any(func(unit): return unit.is_alive)
	if not player_units_alive:
		print("BattleCoordinator: All player units defeated (%d total)" % player_units.size())
		end_battle(BattleResult.create_defeat("All player units defeated"))
		return true

	# Check if all enemy units are defeated (for PvE battles with waves, check if wave defeated)
	var enemy_units = battle_state.get_enemy_units()
	var enemy_units_alive = enemy_units.any(func(unit): return unit.is_alive)
	if not enemy_units_alive:
		# All enemies in current wave are defeated
		var no_waves = not current_battle_config.enemy_waves or current_battle_config.enemy_waves.is_empty()
		var wave_info = "wave %d/%d" % [battle_state.current_wave, battle_state.max_waves]
		print("BattleCoordinator: All enemies defeated in %s (no_waves=%s)" % [wave_info, no_waves])

		if no_waves or battle_state.current_wave >= battle_state.max_waves:
			# No more waves or all waves completed
			print("BattleCoordinator: Final wave complete, ending with victory")
			end_battle(BattleResult.create_victory("All enemies defeated"))
			return true
		else:
			# More waves remaining - advance to next wave
			print("BattleCoordinator: Advancing to next wave")
			_advance_to_next_wave()
			return false  # Battle continues

	return false

func shutdown():
	"""Shutdown the battle coordinator cleanly"""
	if is_battle_active:
		end_battle(BattleResult.create_defeat("Battle system shutdown"))
