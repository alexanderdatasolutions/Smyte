# test_battle_state.gd - Unit tests for scripts/data/BattleState.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_battle_unit(unit_name: String, is_player: bool = true, hp: int = 1000) -> BattleUnit:
	"""Create a mock battle unit for testing"""
	var unit = BattleUnit.new()
	unit.unit_id = unit_name + "_" + str(randi() % 10000)
	unit.unit_name = unit_name
	unit.is_player_unit = is_player
	unit.max_hp = hp
	unit.current_hp = hp
	unit.attack = 100
	unit.defense = 50
	unit.speed = 100
	unit.is_alive = true
	return unit

func create_battle_state_with_units(player_count: int = 2, enemy_count: int = 3) -> BattleState:
	"""Create a battle state with specified number of units"""
	var state = BattleState.new()

	for i in range(player_count):
		var unit = create_mock_battle_unit("Player_%d" % i, true)
		state.player_units.append(unit)
		state.all_units.append(unit)

	for i in range(enemy_count):
		var unit = create_mock_battle_unit("Enemy_%d" % i, false)
		state.enemy_units.append(unit)
		state.all_units.append(unit)

	return state

# ==============================================================================
# TEST: BattleState Initialization
# ==============================================================================

func test_battle_state_initialization():
	var state = BattleState.new()

	runner.assert_equal(state.player_units.size(), 0, "player_units should start empty")
	runner.assert_equal(state.enemy_units.size(), 0, "enemy_units should start empty")
	runner.assert_equal(state.all_units.size(), 0, "all_units should start empty")
	runner.assert_equal(state.current_turn, 0, "current_turn should start at 0")
	runner.assert_equal(state.current_wave, 1, "current_wave should start at 1")
	runner.assert_equal(state.max_waves, 1, "max_waves should default to 1")
	runner.assert_equal(state.total_damage_dealt, 0, "total_damage_dealt should start at 0")
	runner.assert_equal(state.total_damage_received, 0, "total_damage_received should start at 0")
	runner.assert_equal(state.units_defeated, 0, "units_defeated should start at 0")
	runner.assert_equal(state.skills_used, 0, "skills_used should start at 0")
	runner.assert_equal(state.battle_type, "", "battle_type should start empty")
	runner.assert_equal(state.battle_id, "", "battle_id should start empty")
	runner.assert_true(state.battle_start_time > 0, "battle_start_time should be set")

# ==============================================================================
# TEST: Get Living Units
# ==============================================================================

func test_get_living_units_all_alive():
	var state = create_battle_state_with_units(2, 3)

	var living = state.get_living_units()
	runner.assert_equal(living.size(), 5, "should return all 5 units when all alive")

func test_get_living_units_some_dead():
	var state = create_battle_state_with_units(2, 3)
	state.player_units[0].is_alive = false
	state.enemy_units[1].is_alive = false

	var living = state.get_living_units()
	runner.assert_equal(living.size(), 3, "should return only 3 living units")

func test_get_living_units_all_dead():
	var state = create_battle_state_with_units(2, 2)
	for unit in state.all_units:
		unit.is_alive = false

	var living = state.get_living_units()
	runner.assert_equal(living.size(), 0, "should return empty when all dead")

# ==============================================================================
# TEST: Get Living Player Units
# ==============================================================================

func test_get_living_player_units_all_alive():
	var state = create_battle_state_with_units(3, 2)

	var living = state.get_living_player_units()
	runner.assert_equal(living.size(), 3, "should return all 3 player units")

func test_get_living_player_units_some_dead():
	var state = create_battle_state_with_units(3, 2)
	state.player_units[0].is_alive = false

	var living = state.get_living_player_units()
	runner.assert_equal(living.size(), 2, "should return 2 living player units")

func test_get_living_player_units_all_dead():
	var state = create_battle_state_with_units(2, 2)
	for unit in state.player_units:
		unit.is_alive = false

	var living = state.get_living_player_units()
	runner.assert_equal(living.size(), 0, "should return empty when all players dead")

# ==============================================================================
# TEST: Get Living Enemy Units
# ==============================================================================

func test_get_living_enemy_units_all_alive():
	var state = create_battle_state_with_units(2, 4)

	var living = state.get_living_enemy_units()
	runner.assert_equal(living.size(), 4, "should return all 4 enemy units")

func test_get_living_enemy_units_some_dead():
	var state = create_battle_state_with_units(2, 4)
	state.enemy_units[0].is_alive = false
	state.enemy_units[2].is_alive = false

	var living = state.get_living_enemy_units()
	runner.assert_equal(living.size(), 2, "should return 2 living enemy units")

func test_get_living_enemy_units_all_dead():
	var state = create_battle_state_with_units(2, 3)
	for unit in state.enemy_units:
		unit.is_alive = false

	var living = state.get_living_enemy_units()
	runner.assert_equal(living.size(), 0, "should return empty when all enemies dead")

# ==============================================================================
# TEST: Get All Units (returns duplicates)
# ==============================================================================

func test_get_all_units_returns_duplicate():
	var state = create_battle_state_with_units(2, 3)

	var units = state.get_all_units()
	runner.assert_equal(units.size(), 5, "should return all 5 units")

	# Verify it's a duplicate (modifying returned array doesn't affect original)
	units.clear()
	runner.assert_equal(state.all_units.size(), 5, "original array should be unchanged")

func test_get_player_units_returns_duplicate():
	var state = create_battle_state_with_units(3, 2)

	var units = state.get_player_units()
	runner.assert_equal(units.size(), 3, "should return 3 player units")

func test_get_enemy_units_returns_duplicate():
	var state = create_battle_state_with_units(2, 4)

	var units = state.get_enemy_units()
	runner.assert_equal(units.size(), 4, "should return 4 enemy units")

# ==============================================================================
# TEST: All Player Units Defeated
# ==============================================================================

func test_all_player_units_defeated_false_when_alive():
	var state = create_battle_state_with_units(2, 2)

	runner.assert_false(state.all_player_units_defeated(), "should be false when players alive")

func test_all_player_units_defeated_false_when_one_alive():
	var state = create_battle_state_with_units(2, 2)
	state.player_units[0].is_alive = false

	runner.assert_false(state.all_player_units_defeated(), "should be false when one player alive")

func test_all_player_units_defeated_true_when_all_dead():
	var state = create_battle_state_with_units(2, 2)
	for unit in state.player_units:
		unit.is_alive = false

	runner.assert_true(state.all_player_units_defeated(), "should be true when all players dead")

# ==============================================================================
# TEST: All Enemy Units Defeated
# ==============================================================================

func test_all_enemy_units_defeated_false_when_alive():
	var state = create_battle_state_with_units(2, 3)

	runner.assert_false(state.all_enemy_units_defeated(), "should be false when enemies alive")

func test_all_enemy_units_defeated_false_when_one_alive():
	var state = create_battle_state_with_units(2, 3)
	state.enemy_units[0].is_alive = false
	state.enemy_units[1].is_alive = false

	runner.assert_false(state.all_enemy_units_defeated(), "should be false when one enemy alive")

func test_all_enemy_units_defeated_true_when_all_dead():
	var state = create_battle_state_with_units(2, 3)
	for unit in state.enemy_units:
		unit.is_alive = false

	runner.assert_true(state.all_enemy_units_defeated(), "should be true when all enemies dead")

# ==============================================================================
# TEST: Should Battle End
# ==============================================================================

func test_should_battle_end_false_when_both_sides_alive():
	var state = create_battle_state_with_units(2, 2)

	runner.assert_false(state.should_battle_end(), "should be false when both sides alive")

func test_should_battle_end_true_when_players_defeated():
	var state = create_battle_state_with_units(2, 2)
	for unit in state.player_units:
		unit.is_alive = false

	runner.assert_true(state.should_battle_end(), "should be true when all players dead")

func test_should_battle_end_true_when_enemies_defeated_single_wave():
	var state = create_battle_state_with_units(2, 2)
	state.max_waves = 1
	state.current_wave = 1
	for unit in state.enemy_units:
		unit.is_alive = false

	runner.assert_true(state.should_battle_end(), "should be true when enemies dead and last wave")

func test_should_battle_end_false_when_enemies_defeated_more_waves():
	var state = create_battle_state_with_units(2, 2)
	state.max_waves = 3
	state.current_wave = 1
	for unit in state.enemy_units:
		unit.is_alive = false

	runner.assert_false(state.should_battle_end(), "should be false when enemies dead but more waves")

# ==============================================================================
# TEST: Record Damage Dealt
# ==============================================================================

func test_record_damage_dealt_increases_total():
	var state = BattleState.new()

	state.record_damage_dealt(100)
	runner.assert_equal(state.total_damage_dealt, 100, "should record 100 damage")

func test_record_damage_dealt_accumulates():
	var state = BattleState.new()

	state.record_damage_dealt(100)
	state.record_damage_dealt(50)
	state.record_damage_dealt(75)
	runner.assert_equal(state.total_damage_dealt, 225, "should accumulate to 225")

# ==============================================================================
# TEST: Record Damage Received
# ==============================================================================

func test_record_damage_received_increases_total():
	var state = BattleState.new()

	state.record_damage_received(80)
	runner.assert_equal(state.total_damage_received, 80, "should record 80 damage received")

func test_record_damage_received_accumulates():
	var state = BattleState.new()

	state.record_damage_received(50)
	state.record_damage_received(30)
	runner.assert_equal(state.total_damage_received, 80, "should accumulate to 80")

# ==============================================================================
# TEST: Record Unit Defeat
# ==============================================================================

func test_record_unit_defeat_increases_count():
	var state = BattleState.new()

	state.record_unit_defeat()
	runner.assert_equal(state.units_defeated, 1, "should record 1 defeat")

func test_record_unit_defeat_accumulates():
	var state = BattleState.new()

	state.record_unit_defeat()
	state.record_unit_defeat()
	state.record_unit_defeat()
	runner.assert_equal(state.units_defeated, 3, "should accumulate to 3")

# ==============================================================================
# TEST: Record Skill Use
# ==============================================================================

func test_record_skill_use_increases_count():
	var state = BattleState.new()

	state.record_skill_use()
	runner.assert_equal(state.skills_used, 1, "should record 1 skill use")

func test_record_skill_use_accumulates():
	var state = BattleState.new()

	state.record_skill_use()
	state.record_skill_use()
	runner.assert_equal(state.skills_used, 2, "should accumulate to 2")

# ==============================================================================
# TEST: Has Unit Deaths
# ==============================================================================

func test_has_unit_deaths_false_when_all_alive():
	var state = create_battle_state_with_units(3, 2)

	runner.assert_false(state.has_unit_deaths(), "should be false when all players alive")

func test_has_unit_deaths_true_when_player_dead():
	var state = create_battle_state_with_units(3, 2)
	state.player_units[1].is_alive = false

	runner.assert_true(state.has_unit_deaths(), "should be true when a player is dead")

func test_has_unit_deaths_false_when_only_enemy_dead():
	var state = create_battle_state_with_units(2, 3)
	state.enemy_units[0].is_alive = false

	runner.assert_false(state.has_unit_deaths(), "should be false when only enemies dead")

# ==============================================================================
# TEST: Get Unit By ID
# ==============================================================================

func test_get_unit_by_id_finds_player():
	var state = create_battle_state_with_units(2, 2)
	var target_id = state.player_units[0].unit_id

	var found = state.get_unit_by_id(target_id)
	runner.assert_not_null(found, "should find the unit")
	runner.assert_equal(found.unit_id, target_id, "found unit should have correct ID")

func test_get_unit_by_id_finds_enemy():
	var state = create_battle_state_with_units(2, 2)
	var target_id = state.enemy_units[1].unit_id

	var found = state.get_unit_by_id(target_id)
	runner.assert_not_null(found, "should find enemy unit")
	runner.assert_equal(found.unit_id, target_id, "found unit should have correct ID")

func test_get_unit_by_id_returns_null_for_invalid_id():
	var state = create_battle_state_with_units(2, 2)

	var found = state.get_unit_by_id("nonexistent_unit_id")
	runner.assert_null(found, "should return null for invalid ID")

# ==============================================================================
# TEST: Get Battle Statistics
# ==============================================================================

func test_get_battle_statistics_contains_all_fields():
	var state = create_battle_state_with_units(2, 3)
	state.current_turn = 5
	state.total_damage_dealt = 1000
	state.total_damage_received = 500
	state.units_defeated = 2
	state.skills_used = 10
	state.current_wave = 2
	state.max_waves = 3

	var stats = state.get_battle_statistics()

	runner.assert_true(stats.has("current_turn"), "should have current_turn")
	runner.assert_true(stats.has("duration"), "should have duration")
	runner.assert_true(stats.has("total_damage_dealt"), "should have total_damage_dealt")
	runner.assert_true(stats.has("total_damage_received"), "should have total_damage_received")
	runner.assert_true(stats.has("units_defeated"), "should have units_defeated")
	runner.assert_true(stats.has("skills_used"), "should have skills_used")
	runner.assert_true(stats.has("current_wave"), "should have current_wave")
	runner.assert_true(stats.has("max_waves"), "should have max_waves")
	runner.assert_true(stats.has("player_units_alive"), "should have player_units_alive")
	runner.assert_true(stats.has("enemy_units_alive"), "should have enemy_units_alive")

func test_get_battle_statistics_values_correct():
	var state = create_battle_state_with_units(2, 3)
	state.current_turn = 5
	state.total_damage_dealt = 1000
	state.current_wave = 2
	state.max_waves = 3
	state.enemy_units[0].is_alive = false

	var stats = state.get_battle_statistics()

	runner.assert_equal(stats["current_turn"], 5, "current_turn should be 5")
	runner.assert_equal(stats["total_damage_dealt"], 1000, "total_damage_dealt should be 1000")
	runner.assert_equal(stats["current_wave"], 2, "current_wave should be 2")
	runner.assert_equal(stats["max_waves"], 3, "max_waves should be 3")
	runner.assert_equal(stats["player_units_alive"], 2, "player_units_alive should be 2")
	runner.assert_equal(stats["enemy_units_alive"], 2, "enemy_units_alive should be 2")

# ==============================================================================
# TEST: Get Battle Duration
# ==============================================================================

func test_get_battle_duration_returns_positive():
	var state = BattleState.new()

	# Wait a tiny bit
	OS.delay_msec(10)

	var duration = state.get_battle_duration()
	runner.assert_true(duration >= 0.0, "duration should be non-negative")

# ==============================================================================
# TEST: Process End of Turn
# ==============================================================================

func test_process_end_of_turn_increments_turn():
	var state = create_battle_state_with_units(2, 2)

	runner.assert_equal(state.current_turn, 0, "should start at turn 0")
	state.process_end_of_turn()
	runner.assert_equal(state.current_turn, 1, "should be turn 1 after processing")

func test_process_end_of_turn_multiple_times():
	var state = create_battle_state_with_units(2, 2)

	state.process_end_of_turn()
	state.process_end_of_turn()
	state.process_end_of_turn()
	runner.assert_equal(state.current_turn, 3, "should be turn 3 after 3 end of turns")

# ==============================================================================
# TEST: Get Units By Speed
# ==============================================================================

func test_get_units_by_speed_sorts_descending():
	var state = BattleState.new()

	var slow_unit = create_mock_battle_unit("Slow", true)
	slow_unit.speed = 50
	var medium_unit = create_mock_battle_unit("Medium", false)
	medium_unit.speed = 100
	var fast_unit = create_mock_battle_unit("Fast", true)
	fast_unit.speed = 150

	state.player_units.append(slow_unit)
	state.player_units.append(fast_unit)
	state.enemy_units.append(medium_unit)
	state.all_units.append(slow_unit)
	state.all_units.append(fast_unit)
	state.all_units.append(medium_unit)

	var sorted = state.get_units_by_speed()

	runner.assert_equal(sorted.size(), 3, "should have 3 units")
	runner.assert_equal(sorted[0].speed, 150, "first should be fastest (150)")
	runner.assert_equal(sorted[1].speed, 100, "second should be medium (100)")
	runner.assert_equal(sorted[2].speed, 50, "third should be slowest (50)")

func test_get_units_by_speed_excludes_dead():
	var state = create_battle_state_with_units(2, 2)
	state.player_units[0].speed = 200
	state.player_units[0].is_alive = false

	var sorted = state.get_units_by_speed()
	runner.assert_equal(sorted.size(), 3, "should only have 3 living units")

# ==============================================================================
# TEST: Wave Properties
# ==============================================================================

func test_wave_starts_at_one():
	var state = BattleState.new()
	runner.assert_equal(state.current_wave, 1, "current_wave should start at 1")

func test_max_waves_default():
	var state = BattleState.new()
	runner.assert_equal(state.max_waves, 1, "max_waves should default to 1")

# ==============================================================================
# TEST: Cleanup
# ==============================================================================

func test_cleanup_clears_all_arrays():
	var state = create_battle_state_with_units(3, 4)

	runner.assert_equal(state.player_units.size(), 3, "should have 3 players before cleanup")
	runner.assert_equal(state.enemy_units.size(), 4, "should have 4 enemies before cleanup")
	runner.assert_equal(state.all_units.size(), 7, "should have 7 total before cleanup")

	state.cleanup()

	runner.assert_equal(state.player_units.size(), 0, "player_units should be empty after cleanup")
	runner.assert_equal(state.enemy_units.size(), 0, "enemy_units should be empty after cleanup")
	runner.assert_equal(state.all_units.size(), 0, "all_units should be empty after cleanup")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_empty_battle_state_living_units():
	var state = BattleState.new()

	runner.assert_equal(state.get_living_units().size(), 0, "empty state should have no living units")
	runner.assert_equal(state.get_living_player_units().size(), 0, "empty state should have no living players")
	runner.assert_equal(state.get_living_enemy_units().size(), 0, "empty state should have no living enemies")

func test_empty_battle_state_defeat_checks():
	var state = BattleState.new()

	runner.assert_true(state.all_player_units_defeated(), "empty state has all players defeated (vacuously true)")
	runner.assert_true(state.all_enemy_units_defeated(), "empty state has all enemies defeated (vacuously true)")

func test_large_damage_values():
	var state = BattleState.new()

	state.record_damage_dealt(999999999)
	runner.assert_equal(state.total_damage_dealt, 999999999, "should handle large damage values")
