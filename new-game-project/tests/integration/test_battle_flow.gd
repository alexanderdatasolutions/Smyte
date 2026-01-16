# test_battle_flow.gd - Integration tests for battle flow
# Tests interaction between BattleCoordinator, TurnManager, WaveManager, and BattleState
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# MOCK CLASSES FOR INTEGRATION TESTING
# ==============================================================================

class MockBattleUnit:
	var id: String
	var name: String
	var current_hp: int
	var max_hp: int
	var speed: int
	var is_player_unit: bool = true
	var skills: Array = []
	var skill_cooldowns: Array = []
	var status_effects: Array = []

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

	func take_damage(amount: int):
		current_hp = max(0, current_hp - amount)

	func heal(amount: int):
		current_hp = min(max_hp, current_hp + amount)

	func get_display_name() -> String:
		return name

	func can_use_skill(_index: int) -> bool:
		return true

	func get_status_effects() -> Array:
		return status_effects

class MockBattleConfig:
	var battle_type: String = "dungeon"
	var attacker_team: Array = []
	var defender_team: Array = []
	var enemy_waves: Array = []
	var base_rewards: Dictionary = {"gold": 100, "experience": 50}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_player_unit(unit_name: String = "Player", speed: int = 100) -> MockBattleUnit:
	var unit = MockBattleUnit.new("", unit_name)
	unit.is_player_unit = true
	unit.speed = speed
	return unit

func create_enemy_unit(unit_name: String = "Enemy", speed: int = 80) -> MockBattleUnit:
	var unit = MockBattleUnit.new("", unit_name)
	unit.is_player_unit = false
	unit.speed = speed
	return unit

func create_battle_config(player_count: int = 3, enemy_count: int = 3) -> MockBattleConfig:
	var config = MockBattleConfig.new()

	for i in range(player_count):
		config.attacker_team.append(create_player_unit("Player_%d" % (i + 1), 100 + i * 10))

	for i in range(enemy_count):
		config.enemy_waves.append([create_enemy_unit("Enemy_%d" % (i + 1), 80 + i * 5)])

	return config

# ==============================================================================
# TEST: Battle Initialization
# ==============================================================================

func test_battle_state_initialized_with_units():
	var battle_state = BattleState.new()
	var player = create_player_unit()
	var enemy = create_enemy_unit()

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	runner.assert_equal(battle_state.player_units.size(), 1, "should have 1 player unit")
	runner.assert_equal(battle_state.enemy_units.size(), 1, "should have 1 enemy unit")

func test_turn_order_by_speed():
	var units = [
		create_player_unit("Slow", 50),
		create_player_unit("Fast", 200),
		create_player_unit("Medium", 100)
	]

	# Sort by speed descending
	units.sort_custom(func(a, b): return a.speed > b.speed)

	runner.assert_equal(units[0].name, "Fast", "fastest should be first")
	runner.assert_equal(units[1].name, "Medium", "medium should be second")
	runner.assert_equal(units[2].name, "Slow", "slow should be last")

# ==============================================================================
# TEST: Turn Execution
# ==============================================================================

func test_unit_takes_damage():
	var attacker = create_player_unit("Attacker")
	var defender = create_enemy_unit("Defender")
	defender.current_hp = 1000

	# Simulate attack
	var damage = 250
	defender.take_damage(damage)

	runner.assert_equal(defender.current_hp, 750, "defender should have 750 HP")

func test_unit_dies_at_zero_hp():
	var unit = create_enemy_unit()
	unit.current_hp = 100

	unit.take_damage(100)

	runner.assert_equal(unit.current_hp, 0, "HP should be 0")
	runner.assert_false(unit.is_alive(), "unit should be dead")

func test_overkill_damage():
	var unit = create_enemy_unit()
	unit.current_hp = 100

	unit.take_damage(500)

	runner.assert_equal(unit.current_hp, 0, "HP should not go negative")
	runner.assert_false(unit.is_alive(), "unit should be dead")

func test_healing():
	var unit = create_player_unit()
	unit.current_hp = 500
	unit.max_hp = 1000

	unit.heal(300)

	runner.assert_equal(unit.current_hp, 800, "should heal to 800")

func test_healing_capped_at_max():
	var unit = create_player_unit()
	unit.current_hp = 900
	unit.max_hp = 1000

	unit.heal(500)

	runner.assert_equal(unit.current_hp, 1000, "should cap at max HP")

# ==============================================================================
# TEST: Wave Management
# ==============================================================================

func test_wave_progression():
	var wave_manager = WaveManager.new()
	var waves = [
		[create_enemy_unit("Wave1_1")],
		[create_enemy_unit("Wave2_1")],
		[create_enemy_unit("Wave3_1")]
	]

	wave_manager.setup_waves(waves)
	wave_manager.start_wave(1)

	runner.assert_equal(wave_manager.get_current_wave(), 1, "should be at wave 1")
	runner.assert_false(wave_manager.is_final_wave(), "should not be final wave")

func test_wave_advancement():
	var wave_manager = WaveManager.new()
	var waves = [
		[create_enemy_unit()],
		[create_enemy_unit()],
		[create_enemy_unit()]
	]

	wave_manager.setup_waves(waves)
	wave_manager.start_wave(1)
	wave_manager.complete_current_wave()

	runner.assert_equal(wave_manager.get_current_wave(), 2, "should advance to wave 2")

func test_final_wave_detection():
	var wave_manager = WaveManager.new()
	wave_manager.setup_waves([[create_enemy_unit()]])
	wave_manager.start_wave(1)

	runner.assert_true(wave_manager.is_final_wave(), "single wave should be final")

# ==============================================================================
# TEST: Battle State Checks
# ==============================================================================

func test_all_enemies_defeated():
	var battle_state = BattleState.new()
	var player = create_player_unit()
	var enemy = create_enemy_unit()

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	enemy.current_hp = 0  # Kill enemy

	runner.assert_true(battle_state.all_enemy_units_defeated(), "all enemies should be defeated")

func test_all_players_defeated():
	var battle_state = BattleState.new()
	var player = create_player_unit()
	var enemy = create_enemy_unit()

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	player.current_hp = 0  # Kill player

	runner.assert_true(battle_state.all_player_units_defeated(), "all players should be defeated")

func test_battle_should_end_player_victory():
	var battle_state = BattleState.new()
	battle_state.max_waves = 1
	battle_state.current_wave = 1

	var player = create_player_unit()
	var enemy = create_enemy_unit()

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	enemy.current_hp = 0  # Kill enemy

	runner.assert_true(battle_state.should_battle_end(), "battle should end with victory")

func test_battle_should_end_player_defeat():
	var battle_state = BattleState.new()
	var player = create_player_unit()
	var enemy = create_enemy_unit()

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	player.current_hp = 0

	runner.assert_true(battle_state.should_battle_end(), "battle should end with defeat")

# ==============================================================================
# TEST: Complete Battle Flow
# ==============================================================================

func test_complete_battle_victory_flow():
	var battle_state = BattleState.new()
	battle_state.max_waves = 1
	battle_state.current_wave = 1

	var player = create_player_unit("Hero", 150)
	var enemy1 = create_enemy_unit("Enemy1", 100)
	var enemy2 = create_enemy_unit("Enemy2", 80)

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy1)
	battle_state.enemy_units.append(enemy2)

	# Turn 1: Player attacks enemy1
	enemy1.take_damage(600)
	runner.assert_true(enemy1.is_alive(), "enemy1 should survive first hit")

	# Turn 2: Enemy1 attacks player
	player.take_damage(200)
	runner.assert_true(player.is_alive(), "player should survive")

	# Turn 3: Enemy2 attacks player
	player.take_damage(150)

	# Turn 4: Player finishes enemy1
	enemy1.take_damage(500)
	runner.assert_false(enemy1.is_alive(), "enemy1 should be dead")

	# Turn 5: Player kills enemy2
	enemy2.take_damage(1000)
	runner.assert_false(enemy2.is_alive(), "enemy2 should be dead")

	# Check victory
	runner.assert_true(battle_state.all_enemy_units_defeated(), "all enemies defeated")
	runner.assert_false(battle_state.all_player_units_defeated(), "player survived")
	runner.assert_true(battle_state.should_battle_end(), "battle should end")

func test_complete_battle_defeat_flow():
	var battle_state = BattleState.new()
	var player = create_player_unit("Hero")
	player.current_hp = 500  # Weak player

	var enemy = create_enemy_unit("Boss")
	enemy.current_hp = 5000  # Strong enemy

	battle_state.player_units.append(player)
	battle_state.enemy_units.append(enemy)

	# Enemy kills player
	player.take_damage(500)

	runner.assert_false(player.is_alive(), "player should be dead")
	runner.assert_true(battle_state.all_player_units_defeated(), "all players defeated")
	runner.assert_true(battle_state.should_battle_end(), "battle should end")

# ==============================================================================
# TEST: Battle Statistics
# ==============================================================================

func test_battle_tracks_damage():
	var battle_state = BattleState.new()

	battle_state.record_damage_dealt(500)
	battle_state.record_damage_dealt(300)

	var stats = battle_state.get_battle_statistics()
	runner.assert_equal(stats.total_damage_dealt, 800, "should track total damage")

func test_battle_tracks_unit_defeats():
	var battle_state = BattleState.new()

	battle_state.record_unit_defeat()
	battle_state.record_unit_defeat()
	battle_state.record_unit_defeat()

	var stats = battle_state.get_battle_statistics()
	runner.assert_equal(stats.units_defeated, 3, "should track defeats")

func test_battle_tracks_skill_usage():
	var battle_state = BattleState.new()

	battle_state.record_skill_use()
	battle_state.record_skill_use()

	var stats = battle_state.get_battle_statistics()
	runner.assert_equal(stats.skills_used, 2, "should track skill usage")

# ==============================================================================
# TEST: Multi-Wave Battle
# ==============================================================================

func test_multi_wave_battle_flow():
	var wave_manager = WaveManager.new()
	var battle_state = BattleState.new()

	# 3 waves of enemies
	var waves = [
		[create_enemy_unit("W1_E1")],
		[create_enemy_unit("W2_E1"), create_enemy_unit("W2_E2")],
		[create_enemy_unit("Boss")]
	]

	wave_manager.setup_waves(waves)
	battle_state.max_waves = 3
	battle_state.current_wave = 1

	# Start wave 1
	wave_manager.start_wave(1)
	runner.assert_equal(wave_manager.get_current_wave(), 1, "should be wave 1")

	# Complete wave 1
	wave_manager.complete_current_wave()
	runner.assert_equal(wave_manager.get_current_wave(), 2, "should be wave 2")

	# Complete wave 2
	wave_manager.complete_current_wave()
	runner.assert_equal(wave_manager.get_current_wave(), 3, "should be wave 3")
	runner.assert_true(wave_manager.is_final_wave(), "should be final wave")

	# Complete final wave - triggers all_waves_completed signal
	wave_manager.complete_current_wave()

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_empty_battle_state():
	var battle_state = BattleState.new()

	runner.assert_true(battle_state.all_player_units_defeated(), "empty = defeated")
	runner.assert_true(battle_state.all_enemy_units_defeated(), "empty = defeated")

func test_battle_with_multiple_player_deaths():
	var battle_state = BattleState.new()

	var player1 = create_player_unit("P1")
	var player2 = create_player_unit("P2")
	var player3 = create_player_unit("P3")

	battle_state.player_units.append(player1)
	battle_state.player_units.append(player2)
	battle_state.player_units.append(player3)

	player1.current_hp = 0

	runner.assert_false(battle_state.all_player_units_defeated(), "not all dead yet")
	runner.assert_true(battle_state.has_unit_deaths(), "should detect player death")

func test_get_living_units():
	var battle_state = BattleState.new()

	var alive = create_player_unit("Alive")
	var dead = create_player_unit("Dead")
	dead.current_hp = 0

	battle_state.player_units.append(alive)
	battle_state.player_units.append(dead)

	var living = battle_state.get_living_player_units()
	runner.assert_equal(living.size(), 1, "should only return living units")
	runner.assert_equal(living[0].name, "Alive", "should be the alive unit")
