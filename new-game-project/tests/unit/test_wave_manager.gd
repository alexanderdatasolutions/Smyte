# test_wave_manager.gd - Unit tests for scripts/systems/battle/WaveManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_wave_manager() -> WaveManager:
	return WaveManager.new()

func create_mock_enemy(enemy_id: String = "") -> Dictionary:
	"""Create a mock enemy dictionary for wave data"""
	return {
		"id": enemy_id if enemy_id != "" else "enemy_" + str(randi() % 10000),
		"name": "Mock Enemy",
		"hp": 500,
		"attack": 100,
		"defense": 50
	}

func create_waves_data(wave_count: int, enemies_per_wave: int = 3) -> Array:
	"""Create mock wave data with multiple waves"""
	var waves = []
	for w in range(wave_count):
		var wave = []
		for e in range(enemies_per_wave):
			wave.append(create_mock_enemy("wave%d_enemy%d" % [w + 1, e + 1]))
		waves.append(wave)
	return waves

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_wave_started_signal_exists():
	var manager = create_wave_manager()
	runner.assert_true(manager.has_signal("wave_started"), "should have wave_started signal")

func test_wave_completed_signal_exists():
	var manager = create_wave_manager()
	runner.assert_true(manager.has_signal("wave_completed"), "should have wave_completed signal")

func test_all_waves_completed_signal_exists():
	var manager = create_wave_manager()
	runner.assert_true(manager.has_signal("all_waves_completed"), "should have all_waves_completed signal")

# ==============================================================================
# TEST: Setup Waves
# ==============================================================================

func test_setup_waves_sets_wave_data():
	var manager = create_wave_manager()
	var waves = create_waves_data(3)

	manager.setup_waves(waves)

	runner.assert_equal(manager.wave_data.size(), 3, "should have 3 waves")

func test_setup_waves_sets_max_waves():
	var manager = create_wave_manager()
	var waves = create_waves_data(5)

	manager.setup_waves(waves)

	runner.assert_equal(manager.max_waves, 5, "max_waves should be 5")

func test_setup_waves_resets_current_wave():
	var manager = create_wave_manager()
	manager.current_wave = 3  # Simulate previous battle
	var waves = create_waves_data(5)

	manager.setup_waves(waves)

	runner.assert_equal(manager.current_wave, 0, "current_wave should reset to 0")

func test_setup_waves_empty_array():
	var manager = create_wave_manager()

	manager.setup_waves([])

	runner.assert_equal(manager.max_waves, 0, "max_waves should be 0 for empty waves")

func test_setup_waves_duplicates_data():
	var manager = create_wave_manager()
	var waves = create_waves_data(2)
	var original_size = waves.size()

	manager.setup_waves(waves)
	manager.wave_data.append([])  # Modify internal data

	runner.assert_equal(waves.size(), original_size, "original waves should not be modified")

# ==============================================================================
# TEST: Start Wave
# ==============================================================================

func test_start_wave_returns_true_for_valid_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	var result = manager.start_wave(1)

	runner.assert_true(result, "should return true for valid wave")

func test_start_wave_sets_current_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	manager.start_wave(2)

	runner.assert_equal(manager.current_wave, 2, "current_wave should be 2")

func test_start_wave_returns_false_for_wave_zero():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	var result = manager.start_wave(0)

	runner.assert_false(result, "should return false for wave 0")

func test_start_wave_returns_false_for_negative_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	var result = manager.start_wave(-1)

	runner.assert_false(result, "should return false for negative wave")

func test_start_wave_returns_false_for_wave_exceeding_max():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	var result = manager.start_wave(4)

	runner.assert_false(result, "should return false for wave exceeding max")

func test_start_wave_first_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(5))

	var result = manager.start_wave(1)

	runner.assert_true(result, "should be able to start first wave")
	runner.assert_equal(manager.current_wave, 1, "current_wave should be 1")

func test_start_wave_last_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(5))

	var result = manager.start_wave(5)

	runner.assert_true(result, "should be able to start last wave")
	runner.assert_equal(manager.current_wave, 5, "current_wave should be 5")

# ==============================================================================
# TEST: Complete Current Wave
# ==============================================================================

func test_complete_current_wave_advances_to_next():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(1)

	manager.complete_current_wave()

	runner.assert_equal(manager.current_wave, 2, "should advance to wave 2")

func test_complete_current_wave_does_nothing_when_no_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	# Don't start a wave

	manager.complete_current_wave()

	runner.assert_equal(manager.current_wave, 0, "should stay at 0 when no wave started")

func test_complete_final_wave_stays_at_max():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(3)

	manager.complete_current_wave()

	runner.assert_equal(manager.current_wave, 3, "should stay at final wave")

func test_complete_all_waves_sequentially():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(1)

	manager.complete_current_wave()  # 1 -> 2
	runner.assert_equal(manager.current_wave, 2, "should be at wave 2")

	manager.complete_current_wave()  # 2 -> 3
	runner.assert_equal(manager.current_wave, 3, "should be at wave 3")

	manager.complete_current_wave()  # 3 -> end
	runner.assert_equal(manager.current_wave, 3, "should stay at wave 3 after completion")

# ==============================================================================
# TEST: Get Current Wave
# ==============================================================================

func test_get_current_wave_returns_zero_initially():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	runner.assert_equal(manager.get_current_wave(), 0, "should return 0 initially")

func test_get_current_wave_returns_correct_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(2)

	runner.assert_equal(manager.get_current_wave(), 2, "should return current wave number")

# ==============================================================================
# TEST: Get Wave Count
# ==============================================================================

func test_get_wave_count_returns_zero_when_empty():
	var manager = create_wave_manager()

	runner.assert_equal(manager.get_wave_count(), 0, "should return 0 when no waves set")

func test_get_wave_count_returns_correct_count():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(5))

	runner.assert_equal(manager.get_wave_count(), 5, "should return correct wave count")

# ==============================================================================
# TEST: Is Final Wave
# ==============================================================================

func test_is_final_wave_false_initially():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	runner.assert_false(manager.is_final_wave(), "should be false when no wave started")

func test_is_final_wave_false_on_first_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(1)

	runner.assert_false(manager.is_final_wave(), "should be false on first wave")

func test_is_final_wave_false_on_middle_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(2)

	runner.assert_false(manager.is_final_wave(), "should be false on middle wave")

func test_is_final_wave_true_on_last_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(3)

	runner.assert_true(manager.is_final_wave(), "should be true on last wave")

func test_is_final_wave_single_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(1))
	manager.start_wave(1)

	runner.assert_true(manager.is_final_wave(), "should be true on single wave dungeon")

# ==============================================================================
# TEST: Get Current Wave Enemies
# ==============================================================================

func test_get_current_wave_enemies_returns_empty_when_no_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	var enemies = manager.get_current_wave_enemies()

	runner.assert_equal(enemies.size(), 0, "should return empty when no wave started")

func test_get_current_wave_enemies_returns_correct_enemies():
	var manager = create_wave_manager()
	var waves = create_waves_data(3, 4)  # 3 waves, 4 enemies each
	manager.setup_waves(waves)
	manager.start_wave(1)

	var enemies = manager.get_current_wave_enemies()

	runner.assert_equal(enemies.size(), 4, "should return 4 enemies for wave 1")

func test_get_current_wave_enemies_different_waves():
	var manager = create_wave_manager()
	var waves = [
		[create_mock_enemy("a1"), create_mock_enemy("a2")],  # 2 enemies
		[create_mock_enemy("b1"), create_mock_enemy("b2"), create_mock_enemy("b3")],  # 3 enemies
		[create_mock_enemy("c1")]  # 1 enemy (boss wave)
	]
	manager.setup_waves(waves)

	manager.start_wave(1)
	runner.assert_equal(manager.get_current_wave_enemies().size(), 2, "wave 1 should have 2 enemies")

	manager.start_wave(2)
	runner.assert_equal(manager.get_current_wave_enemies().size(), 3, "wave 2 should have 3 enemies")

	manager.start_wave(3)
	runner.assert_equal(manager.get_current_wave_enemies().size(), 1, "wave 3 should have 1 enemy")

func test_get_current_wave_enemies_returns_empty_for_invalid_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.current_wave = 10  # Force invalid wave

	var enemies = manager.get_current_wave_enemies()

	runner.assert_equal(enemies.size(), 0, "should return empty for invalid wave")

# ==============================================================================
# TEST: Get Next Wave Enemies
# ==============================================================================

func test_get_next_wave_enemies_returns_first_wave_initially():
	var manager = create_wave_manager()
	var waves = create_waves_data(3, 5)
	manager.setup_waves(waves)

	var enemies = manager.get_next_wave_enemies()

	runner.assert_equal(enemies.size(), 5, "should return first wave enemies")

func test_get_next_wave_enemies_returns_wave_2_during_wave_1():
	var manager = create_wave_manager()
	var waves = [
		[create_mock_enemy("a1"), create_mock_enemy("a2")],
		[create_mock_enemy("b1"), create_mock_enemy("b2"), create_mock_enemy("b3")],
		[create_mock_enemy("c1")]
	]
	manager.setup_waves(waves)
	manager.start_wave(1)

	var enemies = manager.get_next_wave_enemies()

	runner.assert_equal(enemies.size(), 3, "should return wave 2 enemies")

func test_get_next_wave_enemies_returns_empty_on_final_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(3)

	var enemies = manager.get_next_wave_enemies()

	runner.assert_equal(enemies.size(), 0, "should return empty on final wave")

# ==============================================================================
# TEST: Reset
# ==============================================================================

func test_reset_clears_wave_data():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))

	manager.reset()

	runner.assert_equal(manager.wave_data.size(), 0, "wave_data should be empty")

func test_reset_clears_current_wave():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(2)

	manager.reset()

	runner.assert_equal(manager.current_wave, 0, "current_wave should be 0")

func test_reset_clears_max_waves():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(5))

	manager.reset()

	runner.assert_equal(manager.max_waves, 0, "max_waves should be 0")

func test_reset_then_setup_new_waves():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(3))
	manager.start_wave(2)

	manager.reset()
	manager.setup_waves(create_waves_data(5))

	runner.assert_equal(manager.max_waves, 5, "should be able to setup new waves after reset")
	runner.assert_equal(manager.current_wave, 0, "current_wave should be 0 after new setup")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_single_enemy_wave():
	var manager = create_wave_manager()
	var waves = [[create_mock_enemy("boss")]]  # Single enemy, single wave
	manager.setup_waves(waves)
	manager.start_wave(1)

	runner.assert_equal(manager.get_current_wave_enemies().size(), 1, "should handle single enemy wave")
	runner.assert_true(manager.is_final_wave(), "single wave should be final")

func test_many_waves():
	var manager = create_wave_manager()
	var waves = create_waves_data(100)
	manager.setup_waves(waves)

	runner.assert_equal(manager.max_waves, 100, "should handle many waves")
	runner.assert_true(manager.start_wave(50), "should be able to start wave 50")
	runner.assert_equal(manager.current_wave, 50, "current_wave should be 50")

func test_empty_wave():
	var manager = create_wave_manager()
	var waves = [[], [create_mock_enemy()], []]  # Wave 1 and 3 are empty
	manager.setup_waves(waves)
	manager.start_wave(1)

	runner.assert_equal(manager.get_current_wave_enemies().size(), 0, "should handle empty wave")

func test_wave_progression_full_cycle():
	var manager = create_wave_manager()
	manager.setup_waves(create_waves_data(4))

	runner.assert_equal(manager.current_wave, 0, "should start at 0")

	manager.start_wave(1)
	runner.assert_equal(manager.current_wave, 1, "should be at wave 1")
	runner.assert_false(manager.is_final_wave(), "wave 1 is not final")

	manager.complete_current_wave()
	runner.assert_equal(manager.current_wave, 2, "should be at wave 2")

	manager.complete_current_wave()
	runner.assert_equal(manager.current_wave, 3, "should be at wave 3")

	manager.complete_current_wave()
	runner.assert_equal(manager.current_wave, 4, "should be at wave 4")
	runner.assert_true(manager.is_final_wave(), "wave 4 is final")

	manager.complete_current_wave()
	runner.assert_equal(manager.current_wave, 4, "should stay at wave 4 after final completion")

func test_restart_same_waves():
	var manager = create_wave_manager()
	var waves = create_waves_data(3)
	manager.setup_waves(waves)
	manager.start_wave(1)
	manager.complete_current_wave()
	manager.complete_current_wave()

	# Reset and restart
	manager.reset()
	manager.setup_waves(waves)
	manager.start_wave(1)

	runner.assert_equal(manager.current_wave, 1, "should be able to restart from wave 1")

# ==============================================================================
# TEST: Data Integrity
# ==============================================================================

func test_wave_data_contains_correct_enemies():
	var manager = create_wave_manager()
	var enemy1 = {"id": "goblin", "name": "Goblin", "hp": 100}
	var enemy2 = {"id": "orc", "name": "Orc", "hp": 200}
	var waves = [[enemy1, enemy2]]
	manager.setup_waves(waves)
	manager.start_wave(1)

	var enemies = manager.get_current_wave_enemies()

	runner.assert_equal(enemies[0].id, "goblin", "first enemy should be goblin")
	runner.assert_equal(enemies[1].id, "orc", "second enemy should be orc")

func test_wave_enemies_have_correct_properties():
	var manager = create_wave_manager()
	var boss = {
		"id": "dragon_boss",
		"name": "Ancient Dragon",
		"hp": 10000,
		"attack": 500,
		"defense": 300
	}
	var waves = [[boss]]
	manager.setup_waves(waves)
	manager.start_wave(1)

	var enemies = manager.get_current_wave_enemies()

	runner.assert_equal(enemies[0].name, "Ancient Dragon", "boss name should match")
	runner.assert_equal(enemies[0].hp, 10000, "boss HP should match")
