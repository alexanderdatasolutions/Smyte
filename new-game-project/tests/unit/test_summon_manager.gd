# test_summon_manager.gd - Unit tests for scripts/systems/collection/SummonManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_summon_manager() -> SummonManager:
	"""Create a fresh SummonManager for testing"""
	var manager = SummonManager.new()
	return manager

# ==============================================================================
# TEST: Pity Counter Initialization
# ==============================================================================

func test_pity_counter_initialization():
	var manager = create_summon_manager()

	runner.assert_equal(manager.pity_counter.rare, 0, "rare pity counter should start at 0")
	runner.assert_equal(manager.pity_counter.epic, 0, "epic pity counter should start at 0")
	runner.assert_equal(manager.pity_counter.legendary, 0, "legendary pity counter should start at 0")

func test_pity_counter_structure():
	var manager = create_summon_manager()

	runner.assert_true(manager.pity_counter.has("rare"), "pity counter should have rare")
	runner.assert_true(manager.pity_counter.has("epic"), "pity counter should have epic")
	runner.assert_true(manager.pity_counter.has("legendary"), "pity counter should have legendary")

# ==============================================================================
# TEST: Summon Rates
# ==============================================================================

func test_summon_rates_basic():
	var manager = create_summon_manager()

	var rates = manager._get_summon_rates("basic")

	runner.assert_equal(rates.common, 70.0, "basic common rate should be 70%")
	runner.assert_equal(rates.rare, 25.0, "basic rare rate should be 25%")
	runner.assert_equal(rates.epic, 4.5, "basic epic rate should be 4.5%")
	runner.assert_equal(rates.legendary, 0.5, "basic legendary rate should be 0.5%")

func test_summon_rates_premium():
	var manager = create_summon_manager()

	var rates = manager._get_summon_rates("premium")

	runner.assert_equal(rates.common, 50.0, "premium common rate should be 50%")
	runner.assert_equal(rates.rare, 35.0, "premium rare rate should be 35%")
	runner.assert_equal(rates.epic, 12.0, "premium epic rate should be 12%")
	runner.assert_equal(rates.legendary, 3.0, "premium legendary rate should be 3%")

func test_summon_rates_free_daily():
	var manager = create_summon_manager()

	var rates = manager._get_summon_rates("free_daily")

	runner.assert_equal(rates.common, 80.0, "free daily common rate should be 80%")
	runner.assert_equal(rates.rare, 18.0, "free daily rare rate should be 18%")
	runner.assert_equal(rates.epic, 2.0, "free daily epic rate should be 2%")
	runner.assert_equal(rates.legendary, 0.0, "free daily legendary rate should be 0%")

func test_summon_rates_soul_based():
	var manager = create_summon_manager()

	var rates = manager._get_summon_rates("soul_based")

	runner.assert_equal(rates.common, 60.0, "soul based common rate should be 60%")
	runner.assert_equal(rates.rare, 30.0, "soul based rare rate should be 30%")
	runner.assert_equal(rates.epic, 8.0, "soul based epic rate should be 8%")
	runner.assert_equal(rates.legendary, 2.0, "soul based legendary rate should be 2%")

func test_summon_rates_unknown_type():
	var manager = create_summon_manager()

	var rates = manager._get_summon_rates("unknown")

	runner.assert_equal(rates.common, 85.0, "unknown type should fallback to 85% common")
	runner.assert_equal(rates.rare, 13.0, "unknown type should fallback to 13% rare")
	runner.assert_equal(rates.epic, 2.0, "unknown type should fallback to 2% epic")
	runner.assert_equal(rates.legendary, 0.0, "unknown type should fallback to 0% legendary")

func test_summon_rates_total_100_percent():
	var manager = create_summon_manager()

	var summon_types = ["basic", "premium", "free_daily", "soul_based"]
	for summon_type in summon_types:
		var rates = manager._get_summon_rates(summon_type)
		var total = rates.common + rates.rare + rates.epic + rates.legendary
		runner.assert_equal(total, 100.0, "%s rates should sum to 100%%" % summon_type)

# ==============================================================================
# TEST: Pity System - Hard Pity
# ==============================================================================

func test_hard_pity_legendary_at_100():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 100

	var rates = manager._get_summon_rates("basic")
	var modified = manager._apply_pity_system(rates)

	runner.assert_equal(modified.legendary, 100.0, "legendary should be 100% at 100 pity")
	runner.assert_equal(modified.epic, 0.0, "epic should be 0% at legendary hard pity")
	runner.assert_equal(modified.rare, 0.0, "rare should be 0% at legendary hard pity")
	runner.assert_equal(modified.common, 0.0, "common should be 0% at legendary hard pity")

func test_hard_pity_epic_at_50():
	var manager = create_summon_manager()
	manager.pity_counter.epic = 50
	manager.pity_counter.legendary = 0

	var rates = manager._get_summon_rates("basic")
	var modified = manager._apply_pity_system(rates)

	# Epic pity guarantees epic or better
	var epic_plus = modified.epic + modified.legendary
	runner.assert_true(epic_plus >= 99.5, "epic pity should guarantee epic or better (got %f)" % epic_plus)

func test_hard_pity_legendary_resets_on_legendary():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 99

	manager._update_pity_counters("legendary")

	runner.assert_equal(manager.pity_counter.legendary, 0, "legendary pity should reset on legendary pull")

func test_hard_pity_epic_resets_on_epic():
	var manager = create_summon_manager()
	manager.pity_counter.epic = 49

	manager._update_pity_counters("epic")

	runner.assert_equal(manager.pity_counter.epic, 0, "epic pity should reset on epic pull")

# ==============================================================================
# TEST: Pity Counter Updates
# ==============================================================================

func test_pity_counter_increments_on_common():
	var manager = create_summon_manager()

	manager._update_pity_counters("common")

	runner.assert_equal(manager.pity_counter.legendary, 1, "legendary pity should increment on common")
	runner.assert_equal(manager.pity_counter.epic, 1, "epic pity should increment on common")
	runner.assert_equal(manager.pity_counter.rare, 1, "rare pity should increment on common")

func test_pity_counter_increments_on_rare():
	var manager = create_summon_manager()

	manager._update_pity_counters("rare")

	runner.assert_equal(manager.pity_counter.legendary, 1, "legendary pity should increment on rare")
	runner.assert_equal(manager.pity_counter.epic, 1, "epic pity should increment on rare")
	runner.assert_equal(manager.pity_counter.rare, 0, "rare pity should reset on rare")

func test_pity_counter_resets_on_epic():
	var manager = create_summon_manager()
	manager.pity_counter.epic = 40
	manager.pity_counter.rare = 20

	manager._update_pity_counters("epic")

	runner.assert_equal(manager.pity_counter.epic, 0, "epic pity should reset on epic")
	runner.assert_equal(manager.pity_counter.rare, 0, "rare pity should reset on epic")
	runner.assert_equal(manager.pity_counter.legendary, 1, "legendary pity should increment on epic")

func test_pity_counter_resets_all_on_legendary():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 90
	manager.pity_counter.epic = 40
	manager.pity_counter.rare = 20

	manager._update_pity_counters("legendary")

	runner.assert_equal(manager.pity_counter.legendary, 0, "legendary pity should reset")
	runner.assert_equal(manager.pity_counter.epic, 0, "epic pity should reset")
	runner.assert_equal(manager.pity_counter.rare, 0, "rare pity should reset")

func test_pity_counter_accumulates():
	var manager = create_summon_manager()

	for i in range(10):
		manager._update_pity_counters("common")

	runner.assert_equal(manager.pity_counter.legendary, 10, "legendary pity should accumulate")
	runner.assert_equal(manager.pity_counter.epic, 10, "epic pity should accumulate")

# ==============================================================================
# TEST: Soft Pity
# ==============================================================================

func test_soft_pity_legendary_starts_at_75():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 74

	var rates = manager._get_summon_rates("basic")
	var modified_74 = manager._apply_pity_system(rates)

	manager.pity_counter.legendary = 75
	var modified_75 = manager._apply_pity_system(manager._get_summon_rates("basic"))

	# At 74, no bonus; at 75, bonus starts
	runner.assert_equal(modified_74.legendary, rates.legendary, "no bonus at 74 pity")
	runner.assert_true(modified_75.legendary > rates.legendary, "bonus should start at 75 pity")

func test_soft_pity_epic_starts_at_35():
	var manager = create_summon_manager()
	manager.pity_counter.epic = 34

	var rates = manager._get_summon_rates("basic")
	var modified_34 = manager._apply_pity_system(rates)

	manager.pity_counter.epic = 35
	var modified_35 = manager._apply_pity_system(manager._get_summon_rates("basic"))

	runner.assert_equal(modified_34.epic, rates.epic, "no epic bonus at 34 pity")
	runner.assert_true(modified_35.epic > rates.epic, "epic bonus should start at 35 pity")

func test_soft_pity_legendary_increases_rate():
	var manager = create_summon_manager()
	var rates = manager._get_summon_rates("basic")
	var base_legendary = rates.legendary

	manager.pity_counter.legendary = 80
	var modified = manager._apply_pity_system(rates)

	# At 80 pity: bonus = (80-75) * 0.5 = 2.5
	var expected = base_legendary + 2.5
	runner.assert_equal(modified.legendary, expected, "legendary rate should increase by (pity-75)*0.5")

# ==============================================================================
# TEST: Tier String to Number Conversion
# ==============================================================================

func test_tier_string_to_number_common():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("common"), 1, "common should be 1")

func test_tier_string_to_number_rare():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("rare"), 2, "rare should be 2")

func test_tier_string_to_number_epic():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("epic"), 3, "epic should be 3")

func test_tier_string_to_number_legendary():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("legendary"), 4, "legendary should be 4")

func test_tier_string_to_number_invalid():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("invalid"), -1, "invalid tier should return -1")

func test_tier_string_to_number_case_insensitive():
	var manager = create_summon_manager()
	runner.assert_equal(manager._tier_string_to_number("COMMON"), 1, "should be case insensitive")
	runner.assert_equal(manager._tier_string_to_number("Rare"), 2, "should be case insensitive")
	runner.assert_equal(manager._tier_string_to_number("LEGENDARY"), 4, "should be case insensitive")

# ==============================================================================
# TEST: Random Tier Selection
# ==============================================================================

func test_random_tier_returns_valid_tier():
	var manager = create_summon_manager()
	var rates = {"common": 25.0, "rare": 25.0, "epic": 25.0, "legendary": 25.0}

	var valid_tiers = ["common", "rare", "epic", "legendary"]
	for i in range(20):
		var tier = manager._get_random_tier(rates)
		runner.assert_true(tier in valid_tiers, "tier should be valid: %s" % tier)

func test_random_tier_distribution_heavily_weighted():
	var manager = create_summon_manager()
	var rates = {"common": 99.0, "rare": 1.0, "epic": 0.0, "legendary": 0.0}

	var common_count = 0
	for i in range(100):
		var tier = manager._get_random_tier(rates)
		if tier == "common":
			common_count += 1

	# With 99% rate, should get mostly commons
	runner.assert_true(common_count >= 80, "heavily weighted common should appear often (got %d/100)" % common_count)

func test_random_tier_fallback_to_common():
	var manager = create_summon_manager()
	var rates = {}  # Empty rates

	var tier = manager._get_random_tier(rates)
	runner.assert_equal(tier, "common", "should fallback to common with empty rates")

# ==============================================================================
# TEST: Daily Free Summon
# ==============================================================================

func test_can_use_daily_free_summon_initially_true():
	var manager = create_summon_manager()

	runner.assert_true(manager.can_use_daily_free_summon(), "should be able to use daily free summon initially")

func test_daily_free_summon_updates_date():
	var manager = create_summon_manager()
	var current_date = Time.get_date_string_from_system()

	manager.last_free_summon_date = current_date

	runner.assert_false(manager.can_use_daily_free_summon(), "should not be able to use daily free summon twice on same day")

func test_daily_free_summon_resets_next_day():
	var manager = create_summon_manager()
	manager.last_free_summon_date = "2020-01-01"  # Past date

	runner.assert_true(manager.can_use_daily_free_summon(), "should be able to use daily free summon on new day")

# ==============================================================================
# TEST: Weekly Premium Summon
# ==============================================================================

func test_can_use_weekly_premium_summon_initially_true():
	var manager = create_summon_manager()

	runner.assert_true(manager.can_use_weekly_premium_summon(), "should be able to use weekly premium initially")

func test_can_use_weekly_premium_with_empty_date():
	var manager = create_summon_manager()
	manager.last_weekly_premium_date = ""

	runner.assert_true(manager.can_use_weekly_premium_summon(), "should allow with empty date")

# ==============================================================================
# TEST: Save and Load Data
# ==============================================================================

func test_get_save_data_structure():
	var manager = create_summon_manager()

	var save_data = manager.get_save_data()

	runner.assert_true(save_data.has("pity_counter"), "save data should have pity_counter")
	runner.assert_true(save_data.has("last_free_summon_date"), "save data should have last_free_summon_date")
	runner.assert_true(save_data.has("daily_free_used"), "save data should have daily_free_used")
	runner.assert_true(save_data.has("last_weekly_premium_date"), "save data should have last_weekly_premium_date")
	runner.assert_true(save_data.has("weekly_premium_used"), "save data should have weekly_premium_used")

func test_save_pity_counter():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 50
	manager.pity_counter.epic = 30
	manager.pity_counter.rare = 10

	var save_data = manager.get_save_data()

	runner.assert_equal(save_data.pity_counter.legendary, 50, "saved legendary pity should be 50")
	runner.assert_equal(save_data.pity_counter.epic, 30, "saved epic pity should be 30")
	runner.assert_equal(save_data.pity_counter.rare, 10, "saved rare pity should be 10")

func test_load_save_data():
	var manager = create_summon_manager()

	var save_data = {
		"pity_counter": {"legendary": 75, "epic": 40, "rare": 15},
		"last_free_summon_date": "2024-01-15",
		"daily_free_used": true,
		"last_weekly_premium_date": "2024-01-10",
		"weekly_premium_used": true
	}

	manager.load_save_data(save_data)

	runner.assert_equal(manager.pity_counter.legendary, 75, "loaded legendary pity should be 75")
	runner.assert_equal(manager.pity_counter.epic, 40, "loaded epic pity should be 40")
	runner.assert_equal(manager.pity_counter.rare, 15, "loaded rare pity should be 15")
	runner.assert_equal(manager.last_free_summon_date, "2024-01-15", "loaded free summon date")
	runner.assert_true(manager.daily_free_used, "loaded daily_free_used")
	runner.assert_equal(manager.last_weekly_premium_date, "2024-01-10", "loaded weekly premium date")
	runner.assert_true(manager.weekly_premium_used, "loaded weekly_premium_used")

func test_save_and_load_roundtrip():
	var manager1 = create_summon_manager()
	manager1.pity_counter.legendary = 80
	manager1.pity_counter.epic = 45
	manager1.last_free_summon_date = "2024-06-01"
	manager1.daily_free_used = true

	var save_data = manager1.get_save_data()

	var manager2 = create_summon_manager()
	manager2.load_save_data(save_data)

	runner.assert_equal(manager2.pity_counter.legendary, 80, "legendary pity should survive roundtrip")
	runner.assert_equal(manager2.pity_counter.epic, 45, "epic pity should survive roundtrip")
	runner.assert_equal(manager2.last_free_summon_date, "2024-06-01", "date should survive roundtrip")
	runner.assert_true(manager2.daily_free_used, "daily_free_used should survive roundtrip")

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_summon_completed_signal_exists():
	var manager = create_summon_manager()
	runner.assert_true(manager.has_signal("summon_completed"), "should have summon_completed signal")

func test_summon_failed_signal_exists():
	var manager = create_summon_manager()
	runner.assert_true(manager.has_signal("summon_failed"), "should have summon_failed signal")

func test_multi_summon_completed_signal_exists():
	var manager = create_summon_manager()
	runner.assert_true(manager.has_signal("multi_summon_completed"), "should have multi_summon_completed signal")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_pity_counter_high_values():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 200

	var rates = manager._get_summon_rates("basic")
	var modified = manager._apply_pity_system(rates)

	runner.assert_equal(modified.legendary, 100.0, "should guarantee legendary at very high pity")

func test_empty_save_data_load():
	var manager = create_summon_manager()

	manager.load_save_data({})

	# Should still have default values
	runner.assert_equal(manager.pity_counter.legendary, 0, "should keep default pity on empty load")

func test_partial_save_data_load():
	var manager = create_summon_manager()
	manager.pity_counter.legendary = 50

	manager.load_save_data({"pity_counter": {"legendary": 25}})

	runner.assert_equal(manager.pity_counter.legendary, 25, "should update legendary pity")
	# Note: epic and rare might be undefined in loaded data
