# test_resource_manager.gd - Unit tests for scripts/systems/resources/ResourceManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_resource_manager() -> ResourceManager:
	"""Create a fresh ResourceManager for testing"""
	var manager = ResourceManager.new()
	# Manually call _load_resource_limits since _ready won't be called
	manager._load_resource_limits()
	return manager

# ==============================================================================
# TEST: Add Resource - Basic Functionality
# ==============================================================================

func test_add_resource_increases_amount():
	var manager = create_resource_manager()

	manager.add_resource("gold", 100)
	runner.assert_equal(manager.get_resource("gold"), 100, "gold should be 100 after adding")

	manager.add_resource("gold", 50)
	runner.assert_equal(manager.get_resource("gold"), 150, "gold should be 150 after adding more")

func test_add_resource_returns_true_on_success():
	var manager = create_resource_manager()

	var result = manager.add_resource("gold", 100)
	runner.assert_true(result, "add_resource should return true on success")

func test_add_resource_zero_returns_false():
	var manager = create_resource_manager()

	var result = manager.add_resource("gold", 0)
	runner.assert_false(result, "adding 0 should return false")
	runner.assert_equal(manager.get_resource("gold"), 0, "resource should remain 0")

func test_add_resource_negative_returns_false():
	var manager = create_resource_manager()

	var result = manager.add_resource("gold", -50)
	runner.assert_false(result, "adding negative should return false")
	runner.assert_equal(manager.get_resource("gold"), 0, "resource should remain 0")

func test_add_resource_new_resource_type():
	var manager = create_resource_manager()

	manager.add_resource("custom_resource", 42)
	runner.assert_equal(manager.get_resource("custom_resource"), 42, "custom resource should be added")

# ==============================================================================
# TEST: Add Resource - With Limits
# ==============================================================================

func test_add_resource_respects_energy_limit():
	var manager = create_resource_manager()

	# Energy has limit of 100
	manager.add_resource("energy", 80)
	runner.assert_equal(manager.get_resource("energy"), 80, "energy should be 80")

	manager.add_resource("energy", 50)  # Would exceed limit
	runner.assert_equal(manager.get_resource("energy"), 100, "energy should cap at 100")

func test_add_resource_respects_arena_tokens_limit():
	var manager = create_resource_manager()

	# Arena tokens have limit of 30
	manager.add_resource("arena_tokens", 25)
	manager.add_resource("arena_tokens", 10)  # Would exceed limit
	runner.assert_equal(manager.get_resource("arena_tokens"), 30, "arena_tokens should cap at 30")

func test_add_resource_already_at_limit_returns_false():
	var manager = create_resource_manager()

	manager.add_resource("energy", 100)  # At limit
	var result = manager.add_resource("energy", 10)
	runner.assert_false(result, "adding to already-full resource should return false")
	runner.assert_equal(manager.get_resource("energy"), 100, "energy should still be at limit")

func test_add_resource_unlimited_gold():
	var manager = create_resource_manager()

	# Gold is unlimited (-1)
	manager.add_resource("gold", 999999)
	runner.assert_equal(manager.get_resource("gold"), 999999, "gold should have no cap")

	manager.add_resource("gold", 1000000)
	runner.assert_equal(manager.get_resource("gold"), 1999999, "gold should continue to increase")

func test_add_resource_unlimited_crystals():
	var manager = create_resource_manager()

	manager.add_resource("crystals", 50000)
	runner.assert_equal(manager.get_resource("crystals"), 50000, "crystals should have no cap")

func test_add_resource_unlimited_mana():
	var manager = create_resource_manager()

	manager.add_resource("mana", 100000)
	runner.assert_equal(manager.get_resource("mana"), 100000, "mana should have no cap")

# ==============================================================================
# TEST: Spend Resource - Basic Functionality
# ==============================================================================

func test_spend_resource_decreases_amount():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	manager.spend("gold", 30)
	runner.assert_equal(manager.get_resource("gold"), 70, "gold should be 70 after spending 30")

func test_spend_resource_returns_true_on_success():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var result = manager.spend("gold", 30)
	runner.assert_true(result, "spend should return true on success")

func test_spend_insufficient_returns_false():
	var manager = create_resource_manager()
	manager.add_resource("gold", 50)

	var result = manager.spend("gold", 100)
	runner.assert_false(result, "spending more than available should return false")
	runner.assert_equal(manager.get_resource("gold"), 50, "gold should remain unchanged")

func test_spend_zero_returns_false():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var result = manager.spend("gold", 0)
	runner.assert_false(result, "spending 0 should return false")

func test_spend_negative_returns_false():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var result = manager.spend("gold", -10)
	runner.assert_false(result, "spending negative should return false")

func test_spend_exact_amount():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var result = manager.spend("gold", 100)
	runner.assert_true(result, "spending exact amount should succeed")
	runner.assert_equal(manager.get_resource("gold"), 0, "gold should be 0")

func test_spend_nonexistent_resource():
	var manager = create_resource_manager()

	var result = manager.spend("nonexistent", 10)
	runner.assert_false(result, "spending nonexistent resource should return false")

# ==============================================================================
# TEST: Can Afford - Single Resource
# ==============================================================================

func test_can_afford_single_resource_true():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var can = manager.can_afford({"gold": 50})
	runner.assert_true(can, "should be able to afford 50 gold when having 100")

func test_can_afford_single_resource_exact():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var can = manager.can_afford({"gold": 100})
	runner.assert_true(can, "should be able to afford exact amount")

func test_can_afford_single_resource_false():
	var manager = create_resource_manager()
	manager.add_resource("gold", 50)

	var can = manager.can_afford({"gold": 100})
	runner.assert_false(can, "should not be able to afford 100 gold when having 50")

func test_can_afford_empty_cost():
	var manager = create_resource_manager()

	var can = manager.can_afford({})
	runner.assert_true(can, "empty cost should be affordable")

# ==============================================================================
# TEST: Can Afford - Multiple Resources
# ==============================================================================

func test_can_afford_multiple_resources_true():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.add_resource("mana", 50)

	var can = manager.can_afford({"gold": 50, "mana": 25})
	runner.assert_true(can, "should be able to afford multiple resources")

func test_can_afford_multiple_resources_one_insufficient():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.add_resource("mana", 10)

	var can = manager.can_afford({"gold": 50, "mana": 25})
	runner.assert_false(can, "should not afford if one resource is insufficient")

func test_can_afford_multiple_resources_all_insufficient():
	var manager = create_resource_manager()
	manager.add_resource("gold", 10)
	manager.add_resource("mana", 5)

	var can = manager.can_afford({"gold": 50, "mana": 25})
	runner.assert_false(can, "should not afford if all resources are insufficient")

# ==============================================================================
# TEST: Spend Resources - Atomic Transaction
# ==============================================================================

func test_spend_resources_success():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.add_resource("mana", 50)

	var result = manager.spend_resources({"gold": 30, "mana": 20})
	runner.assert_true(result, "spend_resources should succeed")
	runner.assert_equal(manager.get_resource("gold"), 70, "gold should be reduced")
	runner.assert_equal(manager.get_resource("mana"), 30, "mana should be reduced")

func test_spend_resources_atomic_on_failure():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.add_resource("mana", 10)  # Not enough mana

	var result = manager.spend_resources({"gold": 30, "mana": 20})
	runner.assert_false(result, "spend_resources should fail")
	runner.assert_equal(manager.get_resource("gold"), 100, "gold should be unchanged on failed transaction")
	runner.assert_equal(manager.get_resource("mana"), 10, "mana should be unchanged on failed transaction")

func test_spend_resources_empty_cost():
	var manager = create_resource_manager()

	var result = manager.spend_resources({})
	runner.assert_true(result, "empty cost should succeed")

# ==============================================================================
# TEST: Resource Limits
# ==============================================================================

func test_energy_limit_100():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("energy")
	runner.assert_equal(limit, 100, "energy limit should be 100")

func test_arena_tokens_limit_30():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("arena_tokens")
	runner.assert_equal(limit, 30, "arena_tokens limit should be 30")

func test_guild_tokens_limit_50():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("guild_tokens")
	runner.assert_equal(limit, 50, "guild_tokens limit should be 50")

func test_honor_points_limit_9999():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("honor_points")
	runner.assert_equal(limit, 9999, "honor_points limit should be 9999")

func test_unlimited_gold_returns_negative_one():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("gold")
	runner.assert_equal(limit, -1, "gold should be unlimited (-1)")

func test_unlimited_mana_returns_negative_one():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("mana")
	runner.assert_equal(limit, -1, "mana should be unlimited (-1)")

func test_unlimited_crystals_returns_negative_one():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("crystals")
	runner.assert_equal(limit, -1, "crystals should be unlimited (-1)")

func test_unknown_resource_limit_returns_negative_one():
	var manager = create_resource_manager()

	var limit = manager.get_resource_limit("unknown_resource")
	runner.assert_equal(limit, -1, "unknown resource should return -1 (no limit)")

# ==============================================================================
# TEST: Has Limit / Is At Limit
# ==============================================================================

func test_has_limit_true_for_energy():
	var manager = create_resource_manager()
	runner.assert_true(manager.has_limit("energy"), "energy should have a limit")

func test_has_limit_false_for_gold():
	var manager = create_resource_manager()
	runner.assert_false(manager.has_limit("gold"), "gold should not have a limit")

func test_is_at_limit_true():
	var manager = create_resource_manager()
	manager.add_resource("energy", 100)
	runner.assert_true(manager.is_at_limit("energy"), "energy at 100 should be at limit")

func test_is_at_limit_false():
	var manager = create_resource_manager()
	manager.add_resource("energy", 50)
	runner.assert_false(manager.is_at_limit("energy"), "energy at 50 should not be at limit")

func test_is_at_limit_false_for_unlimited():
	var manager = create_resource_manager()
	manager.add_resource("gold", 999999)
	runner.assert_false(manager.is_at_limit("gold"), "unlimited resource should never be at limit")

# ==============================================================================
# TEST: Set Resource
# ==============================================================================

func test_set_resource_sets_exact_value():
	var manager = create_resource_manager()
	manager.set_resource("gold", 500)
	runner.assert_equal(manager.get_resource("gold"), 500, "gold should be set to exact value")

func test_set_resource_overwrites_existing():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.set_resource("gold", 50)
	runner.assert_equal(manager.get_resource("gold"), 50, "gold should be overwritten")

func test_set_resource_can_set_zero():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.set_resource("gold", 0)
	runner.assert_equal(manager.get_resource("gold"), 0, "gold should be set to 0")

# ==============================================================================
# TEST: Get All Resources
# ==============================================================================

func test_get_all_resources_returns_copy():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)
	manager.add_resource("mana", 50)

	var all = manager.get_all_resources()
	runner.assert_equal(all.gold, 100, "all resources should include gold")
	runner.assert_equal(all.mana, 50, "all resources should include mana")

	# Modify the returned dict shouldn't affect manager
	all.gold = 9999
	runner.assert_equal(manager.get_resource("gold"), 100, "modifying copy shouldn't affect original")

func test_get_all_resources_empty():
	var manager = create_resource_manager()

	var all = manager.get_all_resources()
	runner.assert_equal(all.size(), 0, "all resources should be empty initially")

# ==============================================================================
# TEST: Award Resources
# ==============================================================================

func test_award_resources_adds_multiple():
	var manager = create_resource_manager()

	var actual = manager.award_resources({"gold": 100, "mana": 50})
	runner.assert_equal(manager.get_resource("gold"), 100, "gold should be awarded")
	runner.assert_equal(manager.get_resource("mana"), 50, "mana should be awarded")
	runner.assert_equal(actual.gold, 100, "actual awards should track gold")
	runner.assert_equal(actual.mana, 50, "actual awards should track mana")

func test_award_resources_respects_limits():
	var manager = create_resource_manager()
	manager.add_resource("energy", 80)

	var actual = manager.award_resources({"energy": 50})
	runner.assert_equal(manager.get_resource("energy"), 100, "energy should cap at limit")
	# Note: award_resources returns the requested amount, not the actual capped amount

# ==============================================================================
# TEST: Save and Load Data
# ==============================================================================

func test_get_save_data():
	var manager = create_resource_manager()
	manager.add_resource("gold", 500)
	manager.add_resource("crystals", 100)

	var save_data = manager.get_save_data()
	runner.assert_true(save_data.has("player_resources"), "save data should have player_resources")
	runner.assert_equal(save_data.player_resources.gold, 500, "save data should include gold")
	runner.assert_equal(save_data.player_resources.crystals, 100, "save data should include crystals")

func test_load_from_save():
	var manager = create_resource_manager()

	var save_data = {
		"player_resources": {
			"gold": 1000,
			"mana": 500,
			"energy": 75
		}
	}

	manager.load_from_save(save_data)
	runner.assert_equal(manager.get_resource("gold"), 1000, "gold should be loaded")
	runner.assert_equal(manager.get_resource("mana"), 500, "mana should be loaded")
	runner.assert_equal(manager.get_resource("energy"), 75, "energy should be loaded")

func test_load_from_save_overwrites_existing():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var save_data = {
		"player_resources": {
			"gold": 9999
		}
	}

	manager.load_from_save(save_data)
	runner.assert_equal(manager.get_resource("gold"), 9999, "gold should be overwritten by load")

func test_save_and_load_roundtrip():
	var manager1 = create_resource_manager()
	manager1.add_resource("gold", 12345)
	manager1.add_resource("mana", 6789)
	manager1.add_resource("crystals", 111)

	var save_data = manager1.get_save_data()

	var manager2 = create_resource_manager()
	manager2.load_from_save(save_data)

	runner.assert_equal(manager2.get_resource("gold"), 12345, "gold should survive roundtrip")
	runner.assert_equal(manager2.get_resource("mana"), 6789, "mana should survive roundtrip")
	runner.assert_equal(manager2.get_resource("crystals"), 111, "crystals should survive roundtrip")

# ==============================================================================
# TEST: Initialize New Game
# ==============================================================================

func test_initialize_new_game_clears_resources():
	var manager = create_resource_manager()
	manager.add_resource("gold", 1000)
	manager.add_resource("mana", 500)

	manager.initialize_new_game()
	runner.assert_equal(manager.get_resource("gold"), 0, "gold should be cleared")
	runner.assert_equal(manager.get_resource("mana"), 0, "mana should be cleared")

# ==============================================================================
# TEST: Signal Emissions (tracking via connection)
# ==============================================================================

func test_resource_changed_signal_emitted_on_add():
	var manager = create_resource_manager()
	var signal_received = {"received": false, "resource_id": "", "new_amount": 0, "delta": 0}

	manager.resource_changed.connect(func(rid, amount, d):
		signal_received.received = true
		signal_received.resource_id = rid
		signal_received.new_amount = amount
		signal_received.delta = d
	)

	manager.add_resource("gold", 100)

	runner.assert_true(signal_received.received, "resource_changed signal should be emitted on add")
	runner.assert_equal(signal_received.resource_id, "gold", "signal should have correct resource_id")
	runner.assert_equal(signal_received.new_amount, 100, "signal should have correct new_amount")
	runner.assert_equal(signal_received.delta, 100, "signal should have correct delta")

func test_resource_changed_signal_emitted_on_spend():
	var manager = create_resource_manager()
	manager.add_resource("gold", 100)

	var signal_received = {"received": false, "delta": 0}

	manager.resource_changed.connect(func(_rid, _amount, d):
		signal_received.received = true
		signal_received.delta = d
	)

	manager.spend("gold", 30)

	runner.assert_true(signal_received.received, "resource_changed signal should be emitted on spend")
	runner.assert_equal(signal_received.delta, -30, "delta should be negative on spend")

func test_resource_insufficient_signal_emitted():
	var manager = create_resource_manager()
	manager.add_resource("gold", 50)

	var signal_received = {"received": false, "required": 0, "available": 0}

	manager.resource_insufficient.connect(func(_rid, req, avail):
		signal_received.received = true
		signal_received.required = req
		signal_received.available = avail
	)

	manager.spend("gold", 100)

	runner.assert_true(signal_received.received, "resource_insufficient signal should be emitted")
	runner.assert_equal(signal_received.required, 100, "signal should have required amount")
	runner.assert_equal(signal_received.available, 50, "signal should have available amount")

func test_resource_limit_reached_signal_emitted():
	var manager = create_resource_manager()

	var signal_received = {"received": false, "limit": 0}

	manager.resource_limit_reached.connect(func(_rid, lim):
		signal_received.received = true
		signal_received.limit = lim
	)

	manager.add_resource("energy", 150)  # Exceeds 100 limit

	runner.assert_true(signal_received.received, "resource_limit_reached signal should be emitted")
	runner.assert_equal(signal_received.limit, 100, "signal should have correct limit")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_get_resource_nonexistent_returns_zero():
	var manager = create_resource_manager()
	runner.assert_equal(manager.get_resource("nonexistent"), 0, "nonexistent resource should return 0")

func test_multiple_add_operations():
	var manager = create_resource_manager()

	for i in range(100):
		manager.add_resource("gold", 10)

	runner.assert_equal(manager.get_resource("gold"), 1000, "100 adds of 10 should equal 1000")

func test_multiple_spend_operations():
	var manager = create_resource_manager()
	manager.add_resource("gold", 1000)

	for i in range(50):
		manager.spend("gold", 10)

	runner.assert_equal(manager.get_resource("gold"), 500, "50 spends of 10 should leave 500")

func test_large_resource_values():
	var manager = create_resource_manager()

	manager.add_resource("gold", 999999999)
	runner.assert_equal(manager.get_resource("gold"), 999999999, "should handle large values")

	manager.spend("gold", 999999998)
	runner.assert_equal(manager.get_resource("gold"), 1, "should handle large spends")

func test_debug_add_test_resources():
	var manager = create_resource_manager()

	manager.debug_add_test_resources()

	runner.assert_equal(manager.get_resource("gold"), 50000, "debug should add 50000 gold")
	runner.assert_equal(manager.get_resource("mana"), 5000, "debug should add 5000 mana")
	runner.assert_equal(manager.get_resource("crystals"), 500, "debug should add 500 crystals")
	runner.assert_equal(manager.get_resource("energy"), 80, "debug should add 80 energy")
	runner.assert_equal(manager.get_resource("arena_tokens"), 15, "debug should add 15 arena tokens")
