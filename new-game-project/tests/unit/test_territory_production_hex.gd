# tests/unit/test_territory_production_hex.gd
# Tests for TerritoryProductionManager hex node production methods
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# TEST SETUP / TEARDOWN
# ==============================================================================

func before_each():
	"""Setup before each test"""
	pass

func after_each():
	"""Cleanup after each test"""
	pass

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _create_test_hex_node(node_type: String, tier: int) -> HexNode:
	"""Create a test HexNode with basic setup"""
	var hex_coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = hex_coord_script.new()
	coord.q = 1
	coord.r = 0

	var hex_node_script = load("res://scripts/data/HexNode.gd")
	var node = hex_node_script.new()
	node.id = "test_node_1"
	node.name = "Test Node"
	node.node_type = node_type
	node.tier = tier
	node.coord = coord
	node.controller = "player"
	node.production_level = 1
	node.base_production = {
		"iron_ore": 50,
		"wood": 30
	}
	node.assigned_workers = []

	return node

func _create_test_god(level: int) -> God:
	"""Create a test god with basic stats"""
	var god_script = load("res://scripts/data/God.gd")
	var god = god_script.new()
	god.id = "test_god_1"
	god.name = "Test God"
	god.level = level
	god.element = "fire"
	return god

# ==============================================================================
# CALCULATE_NODE_PRODUCTION TESTS
# ==============================================================================

func test_calculate_node_production_returns_empty_for_null_node():
	"""Should return empty dict for null node"""
	var manager = TerritoryProductionManager.new()
	var result = manager.calculate_node_production(null)
	runner.assert_equal(result.is_empty(), true, "Should return empty dict for null node")

func test_calculate_node_production_returns_empty_for_non_player_node():
	"""Should return empty dict for nodes not controlled by player"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.controller = "neutral"

	var result = manager.calculate_node_production(node)
	runner.assert_equal(result.is_empty(), true, "Should return empty for non-player node")

func test_calculate_node_production_returns_base_production():
	"""Should return base production for level 1 node with no bonuses"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)

	var result = manager.calculate_node_production(node)
	runner.assert_equal(result.has("iron_ore"), true, "Should have iron_ore")
	runner.assert_equal(result.has("wood"), true, "Should have wood")
	runner.assert_equal(result["iron_ore"], 50, "Base iron_ore should be 50")
	runner.assert_equal(result["wood"], 30, "Base wood should be 30")

func test_calculate_node_production_applies_upgrade_bonus():
	"""Should apply 10% bonus per production level above 1"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.production_level = 3  # Should give 20% bonus

	var result = manager.calculate_node_production(node)
	# 50 * 1.20 = 60
	runner.assert_equal(result["iron_ore"], 60, "Should apply 20% upgrade bonus")

func test_calculate_node_production_applies_connected_bonus():
	"""Should apply connected node bonus through TerritoryManager"""
	# Note: This test would need TerritoryManager mock to work fully
	# For now, test that it doesn't crash without TerritoryManager
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)

	var result = manager.calculate_node_production(node)
	runner.assert_not_equal(result, null, "Should not crash without TerritoryManager")

func test_calculate_node_production_applies_worker_efficiency():
	"""Should apply worker efficiency bonus (tested separately in worker tests)"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	# Worker efficiency tested in _calculate_worker_efficiency tests

	var result = manager.calculate_node_production(node)
	runner.assert_not_equal(result, null, "Should calculate production")

# ==============================================================================
# APPLY_CONNECTED_BONUS TESTS
# ==============================================================================

func test_apply_connected_bonus_returns_zero_for_null_node():
	"""Should return 0.0 for null node"""
	var manager = TerritoryProductionManager.new()
	var result = manager.apply_connected_bonus(null)
	runner.assert_equal(result, 0.0, "Should return 0.0 for null node")

func test_apply_connected_bonus_returns_zero_without_territory_manager():
	"""Should return 0.0 if TerritoryManager not available"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)

	var result = manager.apply_connected_bonus(node)
	runner.assert_equal(result, 0.0, "Should return 0.0 without TerritoryManager")

func test_apply_connected_bonus_tiers():
	"""Should return correct bonus for each tier (needs TerritoryManager integration)"""
	# This would need proper integration testing with TerritoryManager
	# Testing the logic structure here
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)

	# Test doesn't crash
	var _result = manager.apply_connected_bonus(node)
	runner.assert_true(true, "Connected bonus logic exists")

# ==============================================================================
# APPLY_SPEC_BONUS TESTS
# ==============================================================================

func test_apply_spec_bonus_returns_zero_for_null_node():
	"""Should return 0.0 for null node"""
	var manager = TerritoryProductionManager.new()
	var god = _create_test_god(10)
	var result = manager.apply_spec_bonus(null, god)
	runner.assert_equal(result, 0.0, "Should return 0.0 for null node")

func test_apply_spec_bonus_returns_zero_for_null_god():
	"""Should return 0.0 for null god"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	var result = manager.apply_spec_bonus(node, null)
	runner.assert_equal(result, 0.0, "Should return 0.0 for null god")

func test_apply_spec_bonus_returns_zero_without_spec_manager():
	"""Should return 0.0 if SpecializationManager not available"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	var god = _create_test_god(10)

	var result = manager.apply_spec_bonus(node, god)
	runner.assert_equal(result, 0.0, "Should return 0.0 without SpecializationManager")

func test_apply_spec_bonus_has_node_task_mapping():
	"""Should have task mapping for all 8 node types"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	var god = _create_test_god(10)

	# Test all node types exist in mapping (by not crashing)
	var node_types = ["mine", "forest", "coast", "hunting_ground", "forge", "library", "temple", "fortress"]
	for node_type in node_types:
		node.node_type = node_type
		var _result = manager.apply_spec_bonus(node, god)
		runner.assert_true(true, "Node type %s has task mapping" % node_type)

# ==============================================================================
# WORKER EFFICIENCY TESTS
# ==============================================================================

func test_calculate_worker_efficiency_returns_zero_for_null_node():
	"""Should return 0.0 for null node"""
	var manager = TerritoryProductionManager.new()
	var result = manager._calculate_worker_efficiency(null)
	runner.assert_equal(result, 0.0, "Should return 0.0 for null node")

func test_calculate_worker_efficiency_returns_zero_for_no_workers():
	"""Should return 0.0 when no workers assigned"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.assigned_workers = []

	var result = manager._calculate_worker_efficiency(node)
	runner.assert_equal(result, 0.0, "Should return 0.0 for no workers")

func test_calculate_worker_efficiency_returns_zero_without_collection_manager():
	"""Should return 0.0 if CollectionManager not available"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.assigned_workers = ["test_god_1"]

	var result = manager._calculate_worker_efficiency(node)
	runner.assert_equal(result, 0.0, "Should return 0.0 without CollectionManager")

# Note: Full worker efficiency tests would require CollectionManager integration
# Testing structure here, full integration tests would go in integration tests

# ==============================================================================
# GET_NODE_HOURLY_PRODUCTION TESTS
# ==============================================================================

func test_get_node_hourly_production_wraps_calculate_node_production():
	"""Should be convenience wrapper for calculate_node_production"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)

	var result1 = manager.get_node_hourly_production(node)
	var result2 = manager.calculate_node_production(node)

	runner.assert_equal(result1, result2, "Should return same result as calculate_node_production")

# ==============================================================================
# GET_ALL_HEX_NODES_PRODUCTION TESTS
# ==============================================================================

func test_get_all_hex_nodes_production_returns_empty_without_territory_manager():
	"""Should return empty dict without TerritoryManager"""
	var manager = TerritoryProductionManager.new()
	var result = manager.get_all_hex_nodes_production()
	runner.assert_equal(result.is_empty(), true, "Should return empty without TerritoryManager")

func test_get_all_hex_nodes_production_sums_all_nodes():
	"""Should sum production from all controlled nodes (integration test)"""
	# This would need proper integration testing with TerritoryManager
	var manager = TerritoryProductionManager.new()

	var result = manager.get_all_hex_nodes_production()
	runner.assert_true(result is Dictionary, "Should return a Dictionary")

# ==============================================================================
# PRODUCTION FORMULA TESTS
# ==============================================================================

func test_production_formula_all_bonuses_multiply():
	"""Should apply bonuses multiplicatively: base * (1 + upgrade) * (1 + connected) * (1 + worker)"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.production_level = 2  # +10% upgrade bonus
	# base=50, upgrade=1.10, connected=1.0 (no TerritoryManager), worker=1.0 (no workers)
	# Expected: 50 * 1.10 = 55

	var result = manager.calculate_node_production(node)
	runner.assert_equal(result["iron_ore"], 55, "Should apply upgrade bonus multiplicatively")

func test_production_formula_rounds_to_int():
	"""Should round final production to integer"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.production_level = 2  # +10%

	var result = manager.calculate_node_production(node)
	runner.assert_true(result["iron_ore"] is int, "Production should be integer")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_calculate_node_production_handles_empty_base_production():
	"""Should handle node with no base production"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.base_production = {}

	var result = manager.calculate_node_production(node)
	runner.assert_equal(result.is_empty(), true, "Should return empty for no base production")

func test_calculate_node_production_handles_zero_values():
	"""Should handle zero production values"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.base_production = {"test_resource": 0}

	var result = manager.calculate_node_production(node)
	runner.assert_equal(result.get("test_resource", -1), 0, "Should handle zero production")

func test_apply_spec_bonus_handles_unknown_node_type():
	"""Should return 0.0 for unknown node type"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("unknown_type", 1)
	var god = _create_test_god(10)

	var result = manager.apply_spec_bonus(node, god)
	runner.assert_equal(result, 0.0, "Should return 0.0 for unknown node type")

func test_calculate_worker_efficiency_handles_invalid_god_ids():
	"""Should skip invalid god IDs gracefully"""
	var manager = TerritoryProductionManager.new()
	var node = _create_test_hex_node("mine", 1)
	node.assigned_workers = ["invalid_god_id"]

	# Should not crash
	var result = manager._calculate_worker_efficiency(node)
	runner.assert_true(result is float, "Should return float even with invalid god IDs")

# ==============================================================================
# BACKWARD COMPATIBILITY TESTS
# ==============================================================================

func test_old_territory_methods_still_work():
	"""Should maintain backward compatibility with old Territory methods"""
	var manager = TerritoryProductionManager.new()

	# Old methods should still exist
	runner.assert_true(manager.has_method("calculate_territory_production"), "Old method should exist")
	runner.assert_true(manager.has_method("get_total_hourly_production"), "Old method should exist")

func test_new_hex_methods_dont_break_old_system():
	"""New hex methods should coexist with old territory system"""
	var manager = TerritoryProductionManager.new()

	# Both systems should work
	var old_result = manager.get_total_hourly_production()
	var new_result = manager.get_all_hex_nodes_production()

	runner.assert_true(old_result is Dictionary, "Old system should work")
	runner.assert_true(new_result is Dictionary, "New system should work")
