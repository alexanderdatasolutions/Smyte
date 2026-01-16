# test_god_progression.gd - Unit tests for scripts/systems/progression/GodProgressionManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_progression_manager() -> GodProgressionManager:
	return GodProgressionManager.new()

func create_mock_god(god_name: String = "TestGod", tier: int = 1) -> God:
	"""Create a mock God for testing"""
	var god = God.new()
	god.id = "god_" + str(randi() % 10000)
	god.name = god_name
	god.tier = tier
	god.level = 1
	god.experience = 0
	god.base_hp = 1000
	god.base_attack = 100
	god.base_defense = 50
	god.base_speed = 100
	god.current_hp = god.base_hp
	god.is_awakened = false
	return god

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_god_leveled_up_signal_exists():
	var manager = create_progression_manager()
	runner.assert_true(manager.has_signal("god_leveled_up"), "should have god_leveled_up signal")

func test_god_experience_gained_signal_exists():
	var manager = create_progression_manager()
	runner.assert_true(manager.has_signal("god_experience_gained"), "should have god_experience_gained signal")

func test_god_awakened_signal_exists():
	var manager = create_progression_manager()
	runner.assert_true(manager.has_signal("god_awakened"), "should have god_awakened signal")

# ==============================================================================
# TEST: Constants
# ==============================================================================

func test_max_god_level():
	runner.assert_equal(GodProgressionManager.MAX_GOD_LEVEL, 40, "max god level should be 40")

func test_awakened_max_level():
	runner.assert_equal(GodProgressionManager.AWAKENED_MAX_LEVEL, 50, "awakened max level should be 50")

func test_xp_base_amount():
	runner.assert_equal(GodProgressionManager.XP_BASE_AMOUNT, 200, "XP base should be 200")

func test_xp_scaling_factor():
	runner.assert_equal(GodProgressionManager.XP_SCALING_FACTOR, 1.2, "XP scaling should be 1.2")

# ==============================================================================
# TEST: Stat Bonuses Per Level
# ==============================================================================

func test_common_tier_bonuses():
	var manager = create_progression_manager()
	var bonuses = manager.stat_bonuses_per_level[1]

	runner.assert_equal(bonuses.attack, 10, "common attack bonus should be 10")
	runner.assert_equal(bonuses.defense, 8, "common defense bonus should be 8")
	runner.assert_equal(bonuses.hp, 25, "common HP bonus should be 25")
	runner.assert_equal(bonuses.speed, 2, "common speed bonus should be 2")

func test_rare_tier_bonuses():
	var manager = create_progression_manager()
	var bonuses = manager.stat_bonuses_per_level[2]

	runner.assert_equal(bonuses.attack, 12, "rare attack bonus should be 12")
	runner.assert_equal(bonuses.defense, 10, "rare defense bonus should be 10")

func test_epic_tier_bonuses():
	var manager = create_progression_manager()
	var bonuses = manager.stat_bonuses_per_level[3]

	runner.assert_equal(bonuses.attack, 15, "epic attack bonus should be 15")

func test_legendary_tier_bonuses():
	var manager = create_progression_manager()
	var bonuses = manager.stat_bonuses_per_level[4]

	runner.assert_equal(bonuses.attack, 20, "legendary attack bonus should be 20")

func test_mythic_tier_bonuses():
	var manager = create_progression_manager()
	var bonuses = manager.stat_bonuses_per_level[5]

	runner.assert_equal(bonuses.attack, 25, "mythic attack bonus should be 25")
	runner.assert_equal(bonuses.hp, 65, "mythic HP bonus should be 65")

# ==============================================================================
# TEST: Add Experience to God
# ==============================================================================

func test_add_experience_increases_total():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.add_experience_to_god(god, 100)

	runner.assert_equal(god.experience, 100, "should add experience")

func test_add_experience_accumulates():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.add_experience_to_god(god, 50)
	manager.add_experience_to_god(god, 75)

	runner.assert_equal(god.experience, 125, "should accumulate experience")

func test_add_experience_null_god():
	var manager = create_progression_manager()

	# Should not throw
	manager.add_experience_to_god(null, 100)

	runner.assert_true(true, "should handle null god gracefully")

func test_add_experience_zero_amount():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.add_experience_to_god(god, 0)

	runner.assert_equal(god.experience, 0, "should not add zero experience")

func test_add_experience_negative_amount():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.add_experience_to_god(god, -50)

	runner.assert_equal(god.experience, 0, "should not add negative experience")

func test_add_experience_triggers_level_up():
	var manager = create_progression_manager()
	var god = create_mock_god()
	# Level 2 requires 200 XP (base amount)
	manager.add_experience_to_god(god, 250)

	runner.assert_equal(god.level, 2, "should level up with enough XP")

# ==============================================================================
# TEST: Calculate Level From Experience
# ==============================================================================

func test_calculate_level_zero_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(0)

	runner.assert_equal(level, 1, "0 XP should be level 1")

func test_calculate_level_some_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(100)

	runner.assert_equal(level, 1, "100 XP should still be level 1")

func test_calculate_level_200_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(200)

	runner.assert_equal(level, 2, "200 XP should reach level 2")

func test_calculate_level_high_xp():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(50000)

	runner.assert_true(level > 10, "high XP should reach high level")

func test_calculate_level_respects_max():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(999999999, false)

	runner.assert_equal(level, 40, "non-awakened should cap at 40")

func test_calculate_level_awakened_higher_cap():
	var manager = create_progression_manager()
	var level = manager.calculate_level_from_experience(999999999, true)

	runner.assert_equal(level, 50, "awakened should cap at 50")

# ==============================================================================
# TEST: Calculate XP For Level
# ==============================================================================

func test_xp_for_level_1():
	var manager = create_progression_manager()
	var xp = manager.calculate_xp_for_level(1)

	runner.assert_equal(xp, 0, "level 1 needs 0 XP")

func test_xp_for_level_2():
	var manager = create_progression_manager()
	var xp = manager.calculate_xp_for_level(2)

	runner.assert_equal(xp, 200, "level 2 needs 200 XP")

func test_xp_for_level_increases():
	var manager = create_progression_manager()
	var xp_lvl2 = manager.calculate_xp_for_level(2)
	var xp_lvl5 = manager.calculate_xp_for_level(5)
	var xp_lvl10 = manager.calculate_xp_for_level(10)

	runner.assert_true(xp_lvl5 > xp_lvl2, "level 5 should need more than level 2")
	runner.assert_true(xp_lvl10 > xp_lvl5, "level 10 should need more than level 5")

# ==============================================================================
# TEST: Calculate Total XP For Level
# ==============================================================================

func test_total_xp_for_level_1():
	var manager = create_progression_manager()
	var xp = manager.calculate_total_xp_for_level(1)

	runner.assert_equal(xp, 0, "level 1 needs 0 total XP")

func test_total_xp_for_level_2():
	var manager = create_progression_manager()
	var xp = manager.calculate_total_xp_for_level(2)

	runner.assert_equal(xp, 200, "level 2 needs 200 total XP")

func test_total_xp_for_level_3():
	var manager = create_progression_manager()
	var xp = manager.calculate_total_xp_for_level(3)
	# Level 2 (200) + Level 3 (200 * 1.2 = 240)
	var expected = 200 + int(200 * 1.2)

	runner.assert_equal(xp, expected, "level 3 needs sum of level 2 and 3 XP")

# ==============================================================================
# TEST: Get XP To Next Level
# ==============================================================================

func test_xp_to_next_level_at_level_1():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 1
	god.experience = 0

	var xp_needed = manager.get_xp_to_next_level(god)

	runner.assert_equal(xp_needed, 200, "need 200 XP from level 1 to 2")

func test_xp_to_next_level_with_progress():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 1
	god.experience = 100

	var xp_needed = manager.get_xp_to_next_level(god)

	runner.assert_equal(xp_needed, 100, "with 100 XP, need 100 more")

func test_xp_to_next_level_null_god():
	var manager = create_progression_manager()

	var xp_needed = manager.get_xp_to_next_level(null)

	runner.assert_equal(xp_needed, 0, "should return 0 for null god")

func test_xp_to_next_level_at_max():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 40
	god.is_awakened = false

	var xp_needed = manager.get_xp_to_next_level(god)

	runner.assert_equal(xp_needed, 0, "should return 0 at max level")

func test_xp_to_next_level_awakened_can_continue():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 40
	god.is_awakened = true
	god.experience = manager.calculate_total_xp_for_level(40)

	var xp_needed = manager.get_xp_to_next_level(god)

	runner.assert_true(xp_needed > 0, "awakened god at 40 can still level up")

# ==============================================================================
# TEST: Level Up God
# ==============================================================================

func test_level_up_updates_level():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager._level_up_god(god, 1, 5)

	runner.assert_equal(god.level, 5, "level should update to 5")

func test_level_up_increases_attack():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 1)  # Common tier
	var initial_attack = god.base_attack

	manager._level_up_god(god, 1, 2)  # 1 level gained

	runner.assert_equal(god.base_attack, initial_attack + 10, "attack should increase by tier bonus")

func test_level_up_increases_defense():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 1)
	var initial_defense = god.base_defense

	manager._level_up_god(god, 1, 2)

	runner.assert_equal(god.base_defense, initial_defense + 8, "defense should increase")

func test_level_up_increases_hp():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 1)
	var initial_hp = god.base_hp

	manager._level_up_god(god, 1, 2)

	runner.assert_equal(god.base_hp, initial_hp + 25, "HP should increase")

func test_level_up_increases_speed():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 1)
	var initial_speed = god.base_speed

	manager._level_up_god(god, 1, 2)

	runner.assert_equal(god.base_speed, initial_speed + 2, "speed should increase")

func test_level_up_heals_to_full():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.current_hp = 500  # Damaged

	manager._level_up_god(god, 1, 2)

	runner.assert_equal(god.current_hp, god.base_hp, "should heal to full on level up")

func test_level_up_multiple_levels():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 1)
	var initial_attack = god.base_attack

	manager._level_up_god(god, 1, 5)  # 4 levels gained

	runner.assert_equal(god.base_attack, initial_attack + (10 * 4), "attack should increase for all levels")

func test_level_up_higher_tier_more_stats():
	var manager = create_progression_manager()
	var common = create_mock_god("Common", 1)
	var legendary = create_mock_god("Legendary", 4)

	manager._level_up_god(common, 1, 2)
	manager._level_up_god(legendary, 1, 2)

	# Legendary gets 20 attack per level, common gets 10
	runner.assert_true(legendary.base_attack > common.base_attack, "higher tier should get more stats")

# ==============================================================================
# TEST: Can Level Up
# ==============================================================================

func test_can_level_up_with_enough_xp():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.experience = 250  # More than needed for level 2

	runner.assert_true(manager.can_level_up(god), "should be able to level up")

func test_can_level_up_without_enough_xp():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.experience = 50  # Not enough for level 2

	runner.assert_false(manager.can_level_up(god), "should not be able to level up")

func test_can_level_up_at_max_level():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 40
	god.is_awakened = false
	god.experience = 999999

	runner.assert_false(manager.can_level_up(god), "should not level up at max")

func test_can_level_up_null_god():
	var manager = create_progression_manager()

	runner.assert_false(manager.can_level_up(null), "should return false for null")

# ==============================================================================
# TEST: Handle God Awakening
# ==============================================================================

func test_awakening_sets_flag():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.handle_god_awakening(god)

	runner.assert_true(god.is_awakened, "should set is_awakened to true")

func test_awakening_null_god():
	var manager = create_progression_manager()

	# Should not throw
	manager.handle_god_awakening(null)

	runner.assert_true(true, "should handle null gracefully")

func test_awakened_god_higher_level_cap():
	var manager = create_progression_manager()
	var god = create_mock_god()
	god.level = 40
	god.experience = 999999999

	manager.handle_god_awakening(god)

	# After awakening, god can now level up beyond 40
	var max_level = manager.calculate_level_from_experience(god.experience, true)
	runner.assert_equal(max_level, 50, "awakened should have max level 50")

# ==============================================================================
# TEST: XP Scaling
# ==============================================================================

func test_xp_requirements_scale():
	var manager = create_progression_manager()

	var xp_2 = manager.calculate_xp_for_level(2)
	var xp_10 = manager.calculate_xp_for_level(10)
	var xp_30 = manager.calculate_xp_for_level(30)

	runner.assert_true(xp_10 > xp_2, "level 10 should need more XP than level 2")
	runner.assert_true(xp_30 > xp_10, "level 30 should need more XP than level 10")

func test_xp_scaling_exponential():
	var manager = create_progression_manager()

	# XP = 200 * 1.2^(level-2)
	var expected_lvl5 = int(200 * pow(1.2, 3))  # level 5
	var actual = manager.calculate_xp_for_level(5)

	runner.assert_equal(actual, expected_lvl5, "XP should follow exponential formula")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_level_up_from_1_to_1():
	var manager = create_progression_manager()
	var god = create_mock_god()
	var initial_attack = god.base_attack

	manager._level_up_god(god, 1, 1)  # 0 levels gained

	runner.assert_equal(god.base_attack, initial_attack, "no stats gained for 0 levels")

func test_unknown_tier_uses_common():
	var manager = create_progression_manager()
	var god = create_mock_god("Unknown", 99)  # Invalid tier
	var initial_attack = god.base_attack

	manager._level_up_god(god, 1, 2)

	# Should use tier 1 (common) bonuses as fallback
	runner.assert_equal(god.base_attack, initial_attack + 10, "should use common tier bonuses")

func test_experience_overflow():
	var manager = create_progression_manager()
	var god = create_mock_god()

	manager.add_experience_to_god(god, 999999999)

	runner.assert_equal(god.level, 40, "should cap at max level")
	runner.assert_equal(god.experience, 999999999, "should keep full experience")

func test_multi_level_stat_calculation():
	var manager = create_progression_manager()
	var god = create_mock_god("Zeus", 3)  # Epic tier: 15 attack per level
	var initial_attack = god.base_attack

	manager._level_up_god(god, 1, 10)  # 9 levels gained

	runner.assert_equal(god.base_attack, initial_attack + (15 * 9), "should calculate multi-level correctly")
