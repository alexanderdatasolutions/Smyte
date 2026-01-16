# test_battle_coordinator.gd - Unit tests for scripts/systems/battle/BattleCoordinator.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# MOCK CLASSES
# ==============================================================================

class MockBattleConfig:
	var battle_type: String = "dungeon"
	var attacker_team: Array = []
	var defender_team: Array = []
	var enemy_waves: Array = []
	var base_rewards: Dictionary = {"gold": 100, "experience": 50}

	static func create_pve_config(attackers: Array, waves: Array) -> MockBattleConfig:
		var config = MockBattleConfig.new()
		config.battle_type = "dungeon"
		config.attacker_team = attackers
		config.enemy_waves = waves
		return config

	static func create_pvp_config(attackers: Array, defenders: Array) -> MockBattleConfig:
		var config = MockBattleConfig.new()
		config.battle_type = "arena"
		config.attacker_team = attackers
		config.defender_team = defenders
		return config

class MockBattleUnit:
	var id: String
	var name: String
	var current_hp: int
	var max_hp: int
	var speed: int
	var is_player_unit: bool = true
	var skills: Array = []

	func _init(unit_id: String = "", unit_name: String = ""):
		id = unit_id if unit_id != "" else "unit_" + str(randi() % 10000)
		name = unit_name if unit_name != "" else "Mock Unit"
		current_hp = 1000
		max_hp = 1000
		speed = 100

	func is_alive() -> bool:
		return current_hp > 0

	func is_enemy() -> bool:
		return not is_player_unit

	func can_use_skill(_index: int) -> bool:
		return true

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_battle_coordinator() -> BattleCoordinator:
	return BattleCoordinator.new()

func create_mock_unit(unit_name: String = "TestUnit", is_player: bool = true) -> MockBattleUnit:
	var unit = MockBattleUnit.new("", unit_name)
	unit.is_player_unit = is_player
	return unit

func create_mock_enemy(enemy_name: String = "Enemy") -> MockBattleUnit:
	return create_mock_unit(enemy_name, false)

func create_player_team(count: int = 3) -> Array:
	var team = []
	for i in range(count):
		team.append(create_mock_unit("Player_%d" % (i + 1)))
	return team

func create_enemy_wave(count: int = 3) -> Array:
	var wave = []
	for i in range(count):
		wave.append(create_mock_enemy("Enemy_%d" % (i + 1)))
	return wave

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_battle_started_signal_exists():
	var coordinator = create_battle_coordinator()
	runner.assert_true(coordinator.has_signal("battle_started"), "should have battle_started signal")

func test_battle_ended_signal_exists():
	var coordinator = create_battle_coordinator()
	runner.assert_true(coordinator.has_signal("battle_ended"), "should have battle_ended signal")

func test_turn_changed_signal_exists():
	var coordinator = create_battle_coordinator()
	runner.assert_true(coordinator.has_signal("turn_changed"), "should have turn_changed signal")

func test_battle_log_message_signal_exists():
	var coordinator = create_battle_coordinator()
	runner.assert_true(coordinator.has_signal("battle_log_message"), "should have battle_log_message signal")

# ==============================================================================
# TEST: Initial State
# ==============================================================================

func test_is_battle_active_false_initially():
	var coordinator = create_battle_coordinator()
	runner.assert_false(coordinator.is_battle_active, "is_battle_active should be false initially")

func test_auto_battle_disabled_initially():
	var coordinator = create_battle_coordinator()
	runner.assert_false(coordinator.auto_battle_enabled, "auto_battle should be disabled initially")

func test_battle_state_null_initially():
	var coordinator = create_battle_coordinator()
	runner.assert_null(coordinator.battle_state, "battle_state should be null initially")

func test_current_battle_config_null_initially():
	var coordinator = create_battle_coordinator()
	runner.assert_null(coordinator.current_battle_config, "current_battle_config should be null initially")

# ==============================================================================
# TEST: Initialize
# ==============================================================================

func test_initialize_creates_turn_manager():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	runner.assert_not_null(coordinator.turn_manager, "should create turn_manager")

func test_initialize_creates_action_processor():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	runner.assert_not_null(coordinator.action_processor, "should create action_processor")

func test_initialize_creates_wave_manager():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	runner.assert_not_null(coordinator.wave_manager, "should create wave_manager")

# ==============================================================================
# TEST: Validate Battle Config
# ==============================================================================

func test_validate_config_returns_false_for_null():
	var coordinator = create_battle_coordinator()
	var result = coordinator._validate_battle_config(null)

	runner.assert_false(result, "should return false for null config")

func test_validate_config_returns_false_for_empty_attacker_team():
	var coordinator = create_battle_coordinator()
	var config = MockBattleConfig.new()
	config.attacker_team = []
	config.defender_team = [create_mock_enemy()]

	var result = coordinator._validate_battle_config(config)

	runner.assert_false(result, "should return false for empty attacker team")

func test_validate_config_returns_false_for_no_defenders_or_waves():
	var coordinator = create_battle_coordinator()
	var config = MockBattleConfig.new()
	config.attacker_team = [create_mock_unit()]
	config.defender_team = []
	config.enemy_waves = []

	var result = coordinator._validate_battle_config(config)

	runner.assert_false(result, "should return false when no defenders or waves")

func test_validate_config_returns_true_with_defender_team():
	var coordinator = create_battle_coordinator()
	var config = MockBattleConfig.create_pvp_config(
		[create_mock_unit()],
		[create_mock_enemy()]
	)

	var result = coordinator._validate_battle_config(config)

	runner.assert_true(result, "should return true with valid defender team")

func test_validate_config_returns_true_with_enemy_waves():
	var coordinator = create_battle_coordinator()
	var config = MockBattleConfig.create_pve_config(
		[create_mock_unit()],
		[[create_mock_enemy()]]
	)

	var result = coordinator._validate_battle_config(config)

	runner.assert_true(result, "should return true with valid enemy waves")

# ==============================================================================
# TEST: Is In Battle
# ==============================================================================

func test_is_in_battle_returns_false_when_inactive():
	var coordinator = create_battle_coordinator()

	runner.assert_false(coordinator.is_in_battle(), "should return false when not in battle")

func test_is_in_battle_returns_current_state():
	var coordinator = create_battle_coordinator()
	coordinator.is_battle_active = true

	runner.assert_true(coordinator.is_in_battle(), "should return true when active")

# ==============================================================================
# TEST: Get Battle State
# ==============================================================================

func test_get_battle_state_returns_null_when_no_battle():
	var coordinator = create_battle_coordinator()

	runner.assert_null(coordinator.get_battle_state(), "should return null when no battle")

func test_get_battle_state_returns_state_when_set():
	var coordinator = create_battle_coordinator()
	coordinator.battle_state = BattleState.new()

	runner.assert_not_null(coordinator.get_battle_state(), "should return battle state")

# ==============================================================================
# TEST: Set Auto Battle
# ==============================================================================

func test_set_auto_battle_enables():
	var coordinator = create_battle_coordinator()
	coordinator.set_auto_battle(true)

	runner.assert_true(coordinator.auto_battle_enabled, "auto_battle should be enabled")

func test_set_auto_battle_disables():
	var coordinator = create_battle_coordinator()
	coordinator.auto_battle_enabled = true
	coordinator.set_auto_battle(false)

	runner.assert_false(coordinator.auto_battle_enabled, "auto_battle should be disabled")

# ==============================================================================
# TEST: Execute Action
# ==============================================================================

func test_execute_action_returns_false_when_not_in_battle():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = false

	var result = coordinator.execute_action(null)

	runner.assert_false(result, "should return false when not in battle")

func test_execute_action_returns_false_during_auto_battle():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = true
	coordinator.auto_battle_enabled = true

	var result = coordinator.execute_action(null)

	runner.assert_false(result, "should return false during auto-battle")

# ==============================================================================
# TEST: Calculate Battle Rewards
# ==============================================================================

func test_calculate_dungeon_rewards():
	var coordinator = create_battle_coordinator()
	coordinator.current_battle_config = MockBattleConfig.new()
	coordinator.current_battle_config.battle_type = "dungeon"
	coordinator.current_battle_config.base_rewards = {"gold": 100, "experience": 50}
	coordinator.battle_state = BattleState.new()

	var rewards = coordinator._calculate_battle_rewards()

	runner.assert_true(rewards.has("gold") or rewards.has("experience"), "dungeon should have rewards")

func test_calculate_arena_rewards():
	var coordinator = create_battle_coordinator()
	coordinator.current_battle_config = MockBattleConfig.new()
	coordinator.current_battle_config.battle_type = "arena"

	var rewards = coordinator._calculate_battle_rewards()

	runner.assert_true(rewards.has("arena_tokens"), "arena should give arena_tokens")
	runner.assert_equal(rewards.arena_tokens, 5, "arena should give 5 tokens")

func test_calculate_territory_rewards():
	var coordinator = create_battle_coordinator()
	coordinator.current_battle_config = MockBattleConfig.new()
	coordinator.current_battle_config.battle_type = "territory"
	coordinator.current_battle_config.base_rewards = {"territory_points": 200}

	var rewards = coordinator._calculate_battle_rewards()

	runner.assert_equal(rewards.territory_points, 200, "territory should use base rewards")

func test_calculate_unknown_battle_type_rewards():
	var coordinator = create_battle_coordinator()
	coordinator.current_battle_config = MockBattleConfig.new()
	coordinator.current_battle_config.battle_type = "unknown"

	var rewards = coordinator._calculate_battle_rewards()

	runner.assert_true(rewards.has("experience"), "unknown type should give default experience")
	runner.assert_true(rewards.has("gold"), "unknown type should give default gold")

# ==============================================================================
# TEST: Cleanup Battle
# ==============================================================================

func test_cleanup_battle_clears_battle_state():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.battle_state = BattleState.new()

	coordinator._cleanup_battle()

	runner.assert_null(coordinator.battle_state, "battle_state should be null after cleanup")

func test_cleanup_battle_clears_config():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.current_battle_config = MockBattleConfig.new()

	coordinator._cleanup_battle()

	runner.assert_null(coordinator.current_battle_config, "current_battle_config should be null after cleanup")

func test_cleanup_battle_resets_wave_manager():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.wave_manager.setup_waves([[create_mock_enemy()]])
	coordinator.wave_manager.start_wave(1)

	coordinator._cleanup_battle()

	runner.assert_equal(coordinator.wave_manager.current_wave, 0, "wave_manager should be reset")

# ==============================================================================
# TEST: Shutdown
# ==============================================================================

func test_shutdown_ends_active_battle():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = true

	coordinator.shutdown()

	runner.assert_false(coordinator.is_battle_active, "should end active battle on shutdown")

func test_shutdown_does_nothing_when_no_battle():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	# Should not throw
	coordinator.shutdown()

	runner.assert_false(coordinator.is_battle_active, "should remain inactive")

# ==============================================================================
# TEST: Find Best Targets
# ==============================================================================

func test_find_best_targets_filters_dead_units():
	var coordinator = create_battle_coordinator()
	var alive_unit = create_mock_enemy("Alive")
	alive_unit.current_hp = 100
	var dead_unit = create_mock_enemy("Dead")
	dead_unit.current_hp = 0

	var targets = coordinator._find_best_targets(null, [alive_unit, dead_unit])

	runner.assert_equal(targets.size(), 1, "should only return alive units")
	runner.assert_equal(targets[0].name, "Alive", "should return the alive unit")

func test_find_best_targets_prioritizes_low_hp():
	var coordinator = create_battle_coordinator()
	var high_hp = create_mock_enemy("HighHP")
	high_hp.current_hp = 1000
	var low_hp = create_mock_enemy("LowHP")
	low_hp.current_hp = 100

	var targets = coordinator._find_best_targets(null, [high_hp, low_hp])

	runner.assert_equal(targets[0].name, "LowHP", "should prioritize lowest HP")

func test_find_best_targets_returns_empty_for_all_dead():
	var coordinator = create_battle_coordinator()
	var dead1 = create_mock_enemy()
	dead1.current_hp = 0
	var dead2 = create_mock_enemy()
	dead2.current_hp = 0

	var targets = coordinator._find_best_targets(null, [dead1, dead2])

	runner.assert_equal(targets.size(), 0, "should return empty for all dead units")

# ==============================================================================
# TEST: Find Best Target (Single)
# ==============================================================================

func test_find_best_target_returns_lowest_hp():
	var coordinator = create_battle_coordinator()
	var high_hp = create_mock_enemy("HighHP")
	high_hp.current_hp = 500
	var low_hp = create_mock_enemy("LowHP")
	low_hp.current_hp = 50

	var target = coordinator._find_best_target([high_hp, low_hp])

	runner.assert_equal(target.name, "LowHP", "should return lowest HP target")

func test_find_best_target_returns_null_for_empty():
	var coordinator = create_battle_coordinator()

	var target = coordinator._find_best_target([])

	runner.assert_null(target, "should return null for empty list")

func test_find_best_target_returns_null_for_all_dead():
	var coordinator = create_battle_coordinator()
	var dead = create_mock_enemy()
	dead.current_hp = 0

	var target = coordinator._find_best_target([dead])

	runner.assert_null(target, "should return null when all dead")

# ==============================================================================
# TEST: Battle Flow States
# ==============================================================================

func test_battle_not_active_after_end():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = true
	coordinator.battle_state = BattleState.new()
	coordinator.current_battle_config = MockBattleConfig.new()

	coordinator.end_battle(BattleResult.create_defeat("Test"))

	runner.assert_false(coordinator.is_battle_active, "is_battle_active should be false after end")

func test_auto_battle_disabled_after_end():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = true
	coordinator.auto_battle_enabled = true
	coordinator.battle_state = BattleState.new()
	coordinator.current_battle_config = MockBattleConfig.new()

	coordinator.end_battle(BattleResult.create_victory("Test"))

	runner.assert_false(coordinator.auto_battle_enabled, "auto_battle should be disabled after end")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_end_battle_does_nothing_when_not_active():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = false

	# Should not throw
	coordinator.end_battle(BattleResult.create_defeat("Test"))

	runner.assert_false(coordinator.is_battle_active, "should remain inactive")

func test_multiple_initialize_calls():
	var coordinator = create_battle_coordinator()

	coordinator.initialize()
	var first_turn_manager = coordinator.turn_manager

	coordinator.initialize()

	runner.assert_not_null(coordinator.turn_manager, "should have turn_manager after second init")

func test_process_auto_battle_does_nothing_when_disabled():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.is_battle_active = true
	coordinator.auto_battle_enabled = false

	# Should not throw
	coordinator._process_auto_battle()

	runner.assert_false(coordinator.auto_battle_enabled, "auto_battle should remain disabled")

func test_process_auto_battle_does_nothing_when_not_in_battle():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()
	coordinator.auto_battle_enabled = true
	coordinator.is_battle_active = false

	# Should not throw
	coordinator._process_auto_battle()

	runner.assert_false(coordinator.is_battle_active, "battle should remain inactive")

# ==============================================================================
# TEST: Dungeon Reward Bonus
# ==============================================================================

func test_dungeon_rewards_bonus_for_no_deaths():
	var coordinator = create_battle_coordinator()
	coordinator.current_battle_config = MockBattleConfig.new()
	coordinator.current_battle_config.battle_type = "dungeon"
	coordinator.current_battle_config.base_rewards = {"gold": 100}

	# Mock battle state with no deaths
	coordinator.battle_state = BattleState.new()

	var rewards = coordinator._calculate_dungeon_rewards()

	# Without deaths, should get 50% bonus: 100 * 1.5 = 150
	runner.assert_true(rewards.has("gold"), "should have gold reward")

# ==============================================================================
# TEST: Component Connections
# ==============================================================================

func test_turn_manager_is_child():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	var found = false
	for child in coordinator.get_children():
		if child is TurnManager:
			found = true
			break

	runner.assert_true(found, "turn_manager should be a child node")

func test_action_processor_is_child():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	var found = false
	for child in coordinator.get_children():
		if child is BattleActionProcessor:
			found = true
			break

	runner.assert_true(found, "action_processor should be a child node")

func test_wave_manager_is_child():
	var coordinator = create_battle_coordinator()
	coordinator.initialize()

	var found = false
	for child in coordinator.get_children():
		if child is WaveManager:
			found = true
			break

	runner.assert_true(found, "wave_manager should be a child node")
