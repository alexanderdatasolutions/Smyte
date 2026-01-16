# test_territory_manager.gd - Unit tests for scripts/systems/territory/TerritoryManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_territory_manager() -> TerritoryManager:
	var manager = TerritoryManager.new()
	# Set up some mock territory data for testing
	manager.territory_data = {
		"olympus": {
			"id": "olympus",
			"name": "Mount Olympus",
			"tier": 5,
			"element": "divine",
			"type": "divine",
			"level": 1,
			"max_level": 10,
			"base_resource_rate": 500,
			"max_stages": 10,
			"current_stage": 0
		},
		"athens": {
			"id": "athens",
			"name": "Athens",
			"tier": 3,
			"element": "wisdom",
			"type": "city",
			"level": 2,
			"max_level": 10,
			"base_resource_rate": 200,
			"max_stages": 5,
			"current_stage": 0
		},
		"sparta": {
			"id": "sparta",
			"name": "Sparta",
			"tier": 4,
			"element": "war",
			"type": "city",
			"level": 1,
			"max_level": 8,
			"base_resource_rate": 300,
			"max_stages": 8,
			"current_stage": 0
		},
		"underworld": {
			"id": "underworld",
			"name": "The Underworld",
			"tier": 5,
			"element": "death",
			"type": "realm",
			"level": 1,
			"max_level": 15,
			"base_resource_rate": 400,
			"max_stages": 15,
			"current_stage": 0
		}
	}
	return manager

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_territory_captured_signal_exists():
	var manager = create_territory_manager()
	runner.assert_true(manager.has_signal("territory_captured"), "should have territory_captured signal")

func test_territory_lost_signal_exists():
	var manager = create_territory_manager()
	runner.assert_true(manager.has_signal("territory_lost"), "should have territory_lost signal")

func test_territory_upgraded_signal_exists():
	var manager = create_territory_manager()
	runner.assert_true(manager.has_signal("territory_upgraded"), "should have territory_upgraded signal")

# ==============================================================================
# TEST: Initial State
# ==============================================================================

func test_initial_controlled_territories_empty():
	var manager = create_territory_manager()
	runner.assert_equal(manager.controlled_territories.size(), 0, "should start with no controlled territories")

func test_initial_territory_data():
	var manager = create_territory_manager()
	runner.assert_true(manager.territory_data.size() > 0, "should have territory data")

# ==============================================================================
# TEST: Capture Territory
# ==============================================================================

func test_capture_territory_success():
	var manager = create_territory_manager()
	var result = manager.capture_territory("olympus")

	runner.assert_true(result, "should return true on successful capture")
	runner.assert_true("olympus" in manager.controlled_territories, "should add to controlled territories")

func test_capture_territory_already_controlled():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var result = manager.capture_territory("olympus")

	runner.assert_false(result, "should return false for already controlled territory")

func test_capture_territory_unknown():
	var manager = create_territory_manager()
	var result = manager.capture_territory("nonexistent_territory")

	runner.assert_false(result, "should return false for unknown territory")

func test_capture_multiple_territories():
	var manager = create_territory_manager()

	manager.capture_territory("olympus")
	manager.capture_territory("athens")
	manager.capture_territory("sparta")

	runner.assert_equal(manager.controlled_territories.size(), 3, "should have 3 controlled territories")

# ==============================================================================
# TEST: Lose Territory
# ==============================================================================

func test_lose_territory_success():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var result = manager.lose_territory("olympus")

	runner.assert_true(result, "should return true on successful loss")
	runner.assert_false("olympus" in manager.controlled_territories, "should remove from controlled territories")

func test_lose_territory_not_controlled():
	var manager = create_territory_manager()
	var result = manager.lose_territory("olympus")

	runner.assert_false(result, "should return false for uncontrolled territory")

func test_lose_territory_removes_only_target():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")
	manager.capture_territory("athens")

	manager.lose_territory("olympus")

	runner.assert_false("olympus" in manager.controlled_territories, "olympus should be removed")
	runner.assert_true("athens" in manager.controlled_territories, "athens should remain")

# ==============================================================================
# TEST: Is Territory Controlled
# ==============================================================================

func test_is_territory_controlled_true():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	runner.assert_true(manager.is_territory_controlled("olympus"), "should return true for controlled territory")

func test_is_territory_controlled_false():
	var manager = create_territory_manager()

	runner.assert_false(manager.is_territory_controlled("olympus"), "should return false for uncontrolled territory")

# ==============================================================================
# TEST: Get Controlled Territories
# ==============================================================================

func test_get_controlled_territories_empty():
	var manager = create_territory_manager()
	var territories = manager.get_controlled_territories()

	runner.assert_equal(territories.size(), 0, "should return empty array when none controlled")

func test_get_controlled_territories_returns_all():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")
	manager.capture_territory("athens")

	var territories = manager.get_controlled_territories()

	runner.assert_equal(territories.size(), 2, "should return all controlled territories")

func test_get_controlled_territories_returns_copy():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var territories = manager.get_controlled_territories()
	territories.append("fake_territory")

	runner.assert_equal(manager.controlled_territories.size(), 1, "original should not be modified")

# ==============================================================================
# TEST: Get Territory Info
# ==============================================================================

func test_get_territory_info_returns_data():
	var manager = create_territory_manager()
	var info = manager.get_territory_info("olympus")

	runner.assert_equal(info.name, "Mount Olympus", "should return territory name")
	runner.assert_equal(info.tier, 5, "should return territory tier")

func test_get_territory_info_unknown():
	var manager = create_territory_manager()
	var info = manager.get_territory_info("nonexistent")

	runner.assert_equal(info.size(), 0, "should return empty dict for unknown territory")

# ==============================================================================
# TEST: Get Territory Count
# ==============================================================================

func test_get_territory_count_zero():
	var manager = create_territory_manager()
	runner.assert_equal(manager.get_territory_count(), 0, "should return 0 when none controlled")

func test_get_territory_count_multiple():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")
	manager.capture_territory("athens")
	manager.capture_territory("sparta")

	runner.assert_equal(manager.get_territory_count(), 3, "should return correct count")

# ==============================================================================
# TEST: Get Territories By Type
# ==============================================================================

func test_get_territories_by_type_city():
	var manager = create_territory_manager()
	manager.capture_territory("athens")
	manager.capture_territory("sparta")
	manager.capture_territory("olympus")

	var cities = manager.get_territories_by_type("city")

	runner.assert_equal(cities.size(), 2, "should return 2 cities")
	runner.assert_true("athens" in cities, "should include athens")
	runner.assert_true("sparta" in cities, "should include sparta")

func test_get_territories_by_type_no_matches():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var forests = manager.get_territories_by_type("forest")

	runner.assert_equal(forests.size(), 0, "should return empty for no matches")

func test_get_territories_by_type_only_controlled():
	var manager = create_territory_manager()
	# Only capture athens, not sparta (both are cities)
	manager.capture_territory("athens")

	var cities = manager.get_territories_by_type("city")

	runner.assert_equal(cities.size(), 1, "should only return controlled territories")

# ==============================================================================
# TEST: Calculate Max Territories
# ==============================================================================

func test_calculate_max_territories_level_1():
	var manager = create_territory_manager()
	var max = manager._calculate_max_territories(1)

	runner.assert_equal(max, 3, "level 1 should have 3 max territories")

func test_calculate_max_territories_level_5():
	var manager = create_territory_manager()
	var max = manager._calculate_max_territories(5)

	runner.assert_equal(max, 3, "level 5 should still have 3 max territories")

func test_calculate_max_territories_level_6():
	var manager = create_territory_manager()
	var max = manager._calculate_max_territories(6)

	runner.assert_equal(max, 4, "level 6 should have 4 max territories")

func test_calculate_max_territories_level_11():
	var manager = create_territory_manager()
	var max = manager._calculate_max_territories(11)

	runner.assert_equal(max, 5, "level 11 should have 5 max territories")

func test_calculate_max_territories_level_50():
	var manager = create_territory_manager()
	var max = manager._calculate_max_territories(50)

	runner.assert_equal(max, 12, "level 50 should have 12 max territories")

# ==============================================================================
# TEST: Upgrade Cost
# ==============================================================================

func test_get_upgrade_cost_level_2():
	var manager = create_territory_manager()
	var cost = manager._get_upgrade_cost("olympus", 2)

	runner.assert_true(cost.has("mana"), "should have mana cost")
	runner.assert_true(cost.has("materials"), "should have materials cost")
	runner.assert_equal(cost.mana, 1000, "level 2 mana cost should be 1000")

func test_get_upgrade_cost_level_3():
	var manager = create_territory_manager()
	var cost = manager._get_upgrade_cost("olympus", 3)

	runner.assert_equal(cost.mana, 1500, "level 3 mana cost should be 1500")

func test_get_upgrade_cost_increases_with_level():
	var manager = create_territory_manager()
	var cost_2 = manager._get_upgrade_cost("olympus", 2)
	var cost_5 = manager._get_upgrade_cost("olympus", 5)

	runner.assert_true(cost_5.mana > cost_2.mana, "higher level should cost more")

# ==============================================================================
# TEST: Get Territory Resource Rate
# ==============================================================================

func test_get_territory_resource_rate():
	var manager = create_territory_manager()
	var rate = manager.get_territory_resource_rate("olympus")

	runner.assert_equal(rate, 500, "olympus should have 500 resource rate")

func test_get_territory_resource_rate_different_territory():
	var manager = create_territory_manager()
	var rate = manager.get_territory_resource_rate("athens")

	runner.assert_equal(rate, 200, "athens should have 200 resource rate")

func test_get_territory_resource_rate_unknown():
	var manager = create_territory_manager()
	var rate = manager.get_territory_resource_rate("nonexistent")

	runner.assert_equal(rate, 100, "unknown should return default 100")

# ==============================================================================
# TEST: Save Data
# ==============================================================================

func test_get_save_data_structure():
	var manager = create_territory_manager()
	var save_data = manager.get_save_data()

	runner.assert_true(save_data.has("controlled_territories"), "should have controlled_territories")
	runner.assert_true(save_data.has("territory_data"), "should have territory_data")

func test_get_save_data_includes_controlled():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")
	manager.capture_territory("athens")

	var save_data = manager.get_save_data()

	runner.assert_equal(save_data.controlled_territories.size(), 2, "should save controlled territories")
	runner.assert_true("olympus" in save_data.controlled_territories, "should include olympus")

func test_get_save_data_returns_copies():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var save_data = manager.get_save_data()
	save_data.controlled_territories.append("fake")

	runner.assert_equal(manager.controlled_territories.size(), 1, "original should not be modified")

# ==============================================================================
# TEST: Load Data
# ==============================================================================

func test_load_save_data_controlled():
	var manager = create_territory_manager()
	manager.load_save_data({
		"controlled_territories": ["olympus", "athens"],
		"territory_data": {}
	})

	runner.assert_equal(manager.controlled_territories.size(), 2, "should load controlled territories")
	runner.assert_true("olympus" in manager.controlled_territories, "should include olympus")

func test_load_save_data_defaults():
	var manager = create_territory_manager()
	manager.load_save_data({})

	runner.assert_equal(manager.controlled_territories.size(), 0, "should default to empty")

func test_load_save_data_merges_territory_data():
	var manager = create_territory_manager()
	manager.load_save_data({
		"controlled_territories": [],
		"territory_data": {
			"olympus": {"level": 5}
		}
	})

	runner.assert_equal(manager.territory_data.olympus.level, 5, "should merge saved level")

# ==============================================================================
# TEST: Create Territory From Config
# ==============================================================================

func test_create_territory_from_config():
	var manager = create_territory_manager()
	var config = {
		"name": "Test Land",
		"tier": 3,
		"element": "fire"
	}

	var territory = manager._create_territory_from_config("test_land", config)

	runner.assert_equal(territory.id, "test_land", "should set id")
	runner.assert_equal(territory.name, "Test Land", "should set name")
	runner.assert_equal(territory.tier, 3, "should set tier")
	runner.assert_equal(territory.element, "fire", "should set element")

func test_create_territory_from_config_defaults():
	var manager = create_territory_manager()
	var territory = manager._create_territory_from_config("empty", {})

	runner.assert_equal(territory.tier, 1, "tier should default to 1")
	runner.assert_equal(territory.element, "neutral", "element should default to neutral")
	runner.assert_equal(territory.base_resource_rate, 100, "resource rate should default to 100")

func test_create_territory_from_config_controller_controlled():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	var territory = manager._create_territory_from_config("olympus", manager.territory_data.olympus)

	runner.assert_equal(territory.controller, "player", "controlled should be player")

func test_create_territory_from_config_controller_enemy():
	var manager = create_territory_manager()
	var territory = manager._create_territory_from_config("olympus", manager.territory_data.olympus)

	runner.assert_equal(territory.controller, "enemy", "uncontrolled should be enemy")

# ==============================================================================
# TEST: Can Attack Territory
# ==============================================================================

func test_can_attack_territory_uncontrolled():
	var manager = create_territory_manager()
	runner.assert_true(manager._can_attack_territory("olympus"), "should be able to attack uncontrolled")

func test_can_attack_territory_controlled():
	var manager = create_territory_manager()
	manager.capture_territory("olympus")

	runner.assert_false(manager._can_attack_territory("olympus"), "should not attack controlled territory")

# ==============================================================================
# TEST: Is Territory Completed
# ==============================================================================

func test_is_territory_completed_false():
	var manager = create_territory_manager()
	runner.assert_false(manager._is_territory_completed("olympus"), "should not be completed at stage 0")

func test_is_territory_completed_true():
	var manager = create_territory_manager()
	manager.territory_data.olympus.current_stage = 10  # max_stages is 10

	runner.assert_true(manager._is_territory_completed("olympus"), "should be completed at max stage")

# ==============================================================================
# TEST: Collect Resources
# ==============================================================================

func test_collect_all_resources_empty():
	var manager = create_territory_manager()
	var result = manager.collect_all_resources()

	runner.assert_equal(result.territory_count, 0, "should have 0 territories")
	runner.assert_equal(result.total_collected, 0, "should collect 0 total")

func test_get_pending_resources_returns_empty():
	var manager = create_territory_manager()
	var pending = manager.get_pending_resources("olympus")

	runner.assert_equal(pending.size(), 0, "pending resources not implemented yet")

func test_collect_territory_resources_returns_empty():
	var manager = create_territory_manager()
	var collected = manager.collect_territory_resources("olympus")

	runner.assert_equal(collected.total, 0, "collection not implemented yet")

# ==============================================================================
# TEST: Sum Dictionary Values
# ==============================================================================

func test_sum_dictionary_values_empty():
	var manager = create_territory_manager()
	var sum = manager._sum_dictionary_values({})

	runner.assert_equal(sum, 0, "empty dict should sum to 0")

func test_sum_dictionary_values_single():
	var manager = create_territory_manager()
	var sum = manager._sum_dictionary_values({"gold": 100})

	runner.assert_equal(sum, 100, "should sum single value")

func test_sum_dictionary_values_multiple():
	var manager = create_territory_manager()
	var sum = manager._sum_dictionary_values({"gold": 100, "mana": 50, "gems": 25})

	runner.assert_equal(sum, 175, "should sum all values")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_capture_and_lose_sequence():
	var manager = create_territory_manager()

	manager.capture_territory("olympus")
	runner.assert_true(manager.is_territory_controlled("olympus"), "should be controlled")

	manager.lose_territory("olympus")
	runner.assert_false(manager.is_territory_controlled("olympus"), "should not be controlled")

	manager.capture_territory("olympus")
	runner.assert_true(manager.is_territory_controlled("olympus"), "should be controlled again")

func test_round_trip_save_load():
	var manager1 = create_territory_manager()
	manager1.capture_territory("olympus")
	manager1.capture_territory("athens")

	var save_data = manager1.get_save_data()

	var manager2 = create_territory_manager()
	manager2.load_save_data(save_data)

	runner.assert_equal(manager2.controlled_territories.size(), 2, "should restore controlled count")
	runner.assert_true("olympus" in manager2.controlled_territories, "should restore olympus")
	runner.assert_true("athens" in manager2.controlled_territories, "should restore athens")
