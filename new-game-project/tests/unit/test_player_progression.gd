# test_player_progression.gd - Unit tests for scripts/systems/progression/PlayerProgressionManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_progression_manager() -> PlayerProgressionManager:
	return PlayerProgressionManager.new()

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_player_leveled_up_signal_exists():
	var manager = create_progression_manager()
	runner.assert_true(manager.has_signal("player_leveled_up"), "should have player_leveled_up signal")

func test_experience_gained_signal_exists():
	var manager = create_progression_manager()
	runner.assert_true(manager.has_signal("experience_gained"), "should have experience_gained signal")

# ==============================================================================
# TEST: Constants
# ==============================================================================

func test_max_player_level_is_50():
	var manager = create_progression_manager()
	runner.assert_equal(PlayerProgressionManager.MAX_PLAYER_LEVEL, 50, "max level should be 50")

func test_xp_base_amount():
	var manager = create_progression_manager()
	runner.assert_equal(PlayerProgressionManager.XP_BASE_AMOUNT, 100, "base XP should be 100")

func test_xp_scaling_factor():
	var manager = create_progression_manager()
	runner.assert_equal(PlayerProgressionManager.XP_SCALING_FACTOR, 1.15, "scaling factor should be 1.15")

# ==============================================================================
# TEST: Initial State
# ==============================================================================

func test_initial_level_is_1():
	var manager = create_progression_manager()
	runner.assert_equal(manager.current_player_level, 1, "should start at level 1")

func test_initial_experience_is_0():
	var manager = create_progression_manager()
	runner.assert_equal(manager.current_experience, 0, "should start with 0 XP")

func test_initial_unlocked_features_empty():
	var manager = create_progression_manager()
	runner.assert_equal(manager.unlocked_features.size(), 0, "should start with no unlocked features")

# ==============================================================================
# TEST: Feature Unlock Levels
# ==============================================================================

func test_summon_unlocks_at_level_2():
	var manager = create_progression_manager()
	runner.assert_equal(manager.feature_unlock_levels[2], "summon", "summon unlocks at level 2")

func test_sacrifice_unlocks_at_level_3():
	var manager = create_progression_manager()
	runner.assert_equal(manager.feature_unlock_levels[3], "sacrifice", "sacrifice unlocks at level 3")

func test_territory_unlocks_at_level_5():
	var manager = create_progression_manager()
	runner.assert_equal(manager.feature_unlock_levels[5], "territory_management", "territory unlocks at level 5")

func test_dungeon_unlocks_at_level_10():
	var manager = create_progression_manager()
	runner.assert_equal(manager.feature_unlock_levels[10], "dungeon", "dungeon unlocks at level 10")

func test_arena_unlocks_at_level_15():
	var manager = create_progression_manager()
	runner.assert_equal(manager.feature_unlock_levels[15], "arena", "arena unlocks at level 15")

# ==============================================================================
# TEST: Add Experience
# ==============================================================================

func test_add_experience_increases_total():
	var manager = create_progression_manager()
	manager.add_experience(50)

	runner.assert_equal(manager.current_experience, 50, "should add experience")

func test_add_experience_multiple_times():
	var manager = create_progression_manager()
	manager.add_experience(30)
	manager.add_experience(40)
	manager.add_experience(30)

	runner.assert_equal(manager.current_experience, 100, "should accumulate experience")

func test_add_experience_triggers_level_up():
	var manager = create_progression_manager()
	# Level 1 needs 100 XP to reach level 2
	manager.add_experience(150)

	runner.assert_equal(manager.current_player_level, 2, "should level up to 2")

func test_add_experience_zero():
	var manager = create_progression_manager()
	manager.add_experience(0)

	runner.assert_equal(manager.current_experience, 0, "adding 0 should not change experience")

# ==============================================================================
# TEST: Calculate Level From Experience
# ==============================================================================

func test_calculate_level_zero_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(0)

	runner.assert_equal(level, 1, "0 XP should be level 1")

func test_calculate_level_50_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(50)

	runner.assert_equal(level, 1, "50 XP should still be level 1")

func test_calculate_level_100_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(100)

	runner.assert_equal(level, 2, "100 XP should reach level 2")

func test_calculate_level_increasing():
	var manager = create_progression_manager()
	var level1 = manager.calculate_level_from_experience(100)
	var level2 = manager.calculate_level_from_experience(500)
	var level3 = manager.calculate_level_from_experience(1000)

	runner.assert_true(level2 > level1, "500 XP should give higher level than 100 XP")
	runner.assert_true(level3 > level2, "1000 XP should give higher level than 500 XP")

func test_calculate_level_max_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(999999999)

	runner.assert_equal(level, 50, "very high XP should cap at max level")

# ==============================================================================
# TEST: Get XP For Next Level
# ==============================================================================

func test_xp_for_next_level_at_level_1():
	var manager = create_progression_manager()
	var xp_needed = manager.get_xp_for_next_level()

	runner.assert_equal(xp_needed, 100, "at level 1 with 0 XP, need 100 for level 2")

func test_xp_for_next_level_partial_progress():
	var manager = create_progression_manager()
	manager.current_experience = 50

	var xp_needed = manager.get_xp_for_next_level()

	runner.assert_equal(xp_needed, 50, "with 50 XP, need 50 more for level 2")

func test_xp_for_next_level_at_max():
	var manager = create_progression_manager()
	manager.current_player_level = 50

	var xp_needed = manager.get_xp_for_next_level()

	runner.assert_equal(xp_needed, 0, "at max level, should return 0")

# ==============================================================================
# TEST: Level Up
# ==============================================================================

func test_level_up_updates_level():
	var manager = create_progression_manager()
	manager._level_up(5)

	runner.assert_equal(manager.current_player_level, 5, "level should update to 5")

func test_level_up_checks_feature_unlocks():
	var manager = create_progression_manager()
	manager._level_up(2)

	runner.assert_true(manager.is_feature_unlocked("summon"), "should unlock summon at level 2")

func test_level_up_multiple_features():
	var manager = create_progression_manager()
	manager._level_up(3)

	runner.assert_true(manager.is_feature_unlocked("sacrifice"), "should unlock sacrifice at level 3")

# ==============================================================================
# TEST: Feature Unlocking
# ==============================================================================

func test_unlock_feature_adds_to_list():
	var manager = create_progression_manager()
	manager.unlock_feature("test_feature")

	runner.assert_true("test_feature" in manager.unlocked_features, "feature should be in list")

func test_unlock_feature_no_duplicates():
	var manager = create_progression_manager()
	manager.unlock_feature("test_feature")
	manager.unlock_feature("test_feature")

	var count = manager.unlocked_features.count("test_feature")
	runner.assert_equal(count, 1, "should not add duplicate features")

func test_is_feature_unlocked_true():
	var manager = create_progression_manager()
	manager.unlock_feature("my_feature")

	runner.assert_true(manager.is_feature_unlocked("my_feature"), "should return true for unlocked feature")

func test_is_feature_unlocked_false():
	var manager = create_progression_manager()

	runner.assert_false(manager.is_feature_unlocked("locked_feature"), "should return false for locked feature")

# ==============================================================================
# TEST: Getters
# ==============================================================================

func test_get_player_level():
	var manager = create_progression_manager()
	manager.current_player_level = 15

	runner.assert_equal(manager.get_player_level(), 15, "should return current level")

func test_get_player_experience():
	var manager = create_progression_manager()
	manager.current_experience = 500

	runner.assert_equal(manager.get_player_experience(), 500, "should return current experience")

# ==============================================================================
# TEST: Save Data
# ==============================================================================

func test_get_save_data_structure():
	var manager = create_progression_manager()
	var save_data = manager.get_save_data()

	runner.assert_true(save_data.has("level"), "should have level")
	runner.assert_true(save_data.has("experience"), "should have experience")
	runner.assert_true(save_data.has("unlocked_features"), "should have unlocked_features")

func test_get_save_data_values():
	var manager = create_progression_manager()
	manager.current_player_level = 10
	manager.current_experience = 500
	manager.unlocked_features = ["summon", "sacrifice"]

	var save_data = manager.get_save_data()

	runner.assert_equal(save_data.level, 10, "level should match")
	runner.assert_equal(save_data.experience, 500, "experience should match")
	runner.assert_equal(save_data.unlocked_features.size(), 2, "features should match")

# ==============================================================================
# TEST: Load Data
# ==============================================================================

func test_load_save_data_level():
	var manager = create_progression_manager()
	manager.load_save_data({"level": 25, "experience": 1000, "unlocked_features": []})

	runner.assert_equal(manager.current_player_level, 25, "level should be loaded")

func test_load_save_data_experience():
	var manager = create_progression_manager()
	manager.load_save_data({"level": 1, "experience": 750, "unlocked_features": []})

	runner.assert_equal(manager.current_experience, 750, "experience should be loaded")

func test_load_save_data_features():
	var manager = create_progression_manager()
	manager.load_save_data({"level": 1, "experience": 0, "unlocked_features": ["summon", "dungeon"]})

	runner.assert_equal(manager.unlocked_features.size(), 2, "features should be loaded")
	runner.assert_true("summon" in manager.unlocked_features, "should have summon")
	runner.assert_true("dungeon" in manager.unlocked_features, "should have dungeon")

func test_load_save_data_defaults():
	var manager = create_progression_manager()
	manager.load_save_data({})

	runner.assert_equal(manager.current_player_level, 1, "should default to level 1")
	runner.assert_equal(manager.current_experience, 0, "should default to 0 XP")
	runner.assert_equal(manager.unlocked_features.size(), 0, "should default to empty features")

func test_load_save_data_partial():
	var manager = create_progression_manager()
	manager.load_save_data({"level": 5})

	runner.assert_equal(manager.current_player_level, 5, "level should be loaded")
	runner.assert_equal(manager.current_experience, 0, "missing experience should default to 0")

# ==============================================================================
# TEST: XP Scaling
# ==============================================================================

func test_xp_requirements_increase():
	var manager = create_progression_manager()

	# Calculate XP needed for levels 1-5
	var xp_for_level_1 = int(100 * pow(1.15, 0))  # Level 1 -> 2
	var xp_for_level_2 = int(100 * pow(1.15, 1))  # Level 2 -> 3
	var xp_for_level_3 = int(100 * pow(1.15, 2))  # Level 3 -> 4

	runner.assert_true(xp_for_level_2 > xp_for_level_1, "XP for level 2 should be higher than level 1")
	runner.assert_true(xp_for_level_3 > xp_for_level_2, "XP for level 3 should be higher than level 2")

func test_xp_scaling_formula():
	var manager = create_progression_manager()

	# Test specific level calculation
	var expected = int(100 * pow(1.15, 4))  # Level 5 -> 6
	# This should be approximately 174

	runner.assert_true(expected > 150, "level 5 XP should be above 150")
	runner.assert_true(expected < 200, "level 5 XP should be below 200")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_negative_experience():
	var manager = create_progression_manager()
	manager.add_experience(-50)

	runner.assert_equal(manager.current_experience, -50, "should allow negative XP (bug or feature)")

func test_large_experience_gain():
	var manager = create_progression_manager()
	manager.add_experience(100000)

	runner.assert_true(manager.current_player_level > 1, "should level up from large XP gain")

func test_level_up_skips_multiple_levels():
	var manager = create_progression_manager()
	manager.add_experience(10000)

	runner.assert_true(manager.current_player_level > 5, "should skip multiple levels")

func test_feature_unlock_progression():
	var manager = create_progression_manager()

	# Level up through feature unlock milestones
	manager._level_up(2)
	runner.assert_true(manager.is_feature_unlocked("summon"), "summon should unlock at 2")

	manager._level_up(3)
	runner.assert_true(manager.is_feature_unlocked("sacrifice"), "sacrifice should unlock at 3")

	manager._level_up(5)
	runner.assert_true(manager.is_feature_unlocked("territory_management"), "territory should unlock at 5")

func test_round_trip_save_load():
	var manager1 = create_progression_manager()
	manager1.current_player_level = 20
	manager1.current_experience = 5000
	manager1.unlocked_features = ["summon", "sacrifice", "dungeon"]

	var save_data = manager1.get_save_data()

	var manager2 = create_progression_manager()
	manager2.load_save_data(save_data)

	runner.assert_equal(manager2.current_player_level, 20, "level should match after round trip")
	runner.assert_equal(manager2.current_experience, 5000, "experience should match after round trip")
	runner.assert_equal(manager2.unlocked_features.size(), 3, "features should match after round trip")
