# test_equipment_enhancement.gd - Unit tests for scripts/systems/equipment/EquipmentEnhancementManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_enhancement_manager() -> EquipmentEnhancementManager:
	"""Create a fresh EquipmentEnhancementManager for testing"""
	var manager = EquipmentEnhancementManager.new()
	return manager

func create_mock_equipment(rarity: Equipment.Rarity = Equipment.Rarity.COMMON, level: int = 0) -> Equipment:
	"""Create mock equipment for testing"""
	var eq = Equipment.new()
	eq.equipment_id = "test_eq_" + str(randi() % 10000)
	eq.name = "Test Equipment"
	eq.equipment_type = Equipment.EquipmentType.WEAPON
	eq.rarity = rarity
	eq.enhancement_level = level
	eq.main_stat_type = "attack"
	eq.main_stat_base = 50
	eq.main_stat_value = 50
	return eq

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_equipment_enhanced_signal_exists():
	var manager = create_enhancement_manager()
	runner.assert_true(manager.has_signal("equipment_enhanced"), "should have equipment_enhanced signal")

func test_enhancement_failed_signal_exists():
	var manager = create_enhancement_manager()
	runner.assert_true(manager.has_signal("enhancement_failed"), "should have enhancement_failed signal")

func test_blessed_oil_used_signal_exists():
	var manager = create_enhancement_manager()
	runner.assert_true(manager.has_signal("blessed_oil_used"), "should have blessed_oil_used signal")

# ==============================================================================
# TEST: Enhancement Preview
# ==============================================================================

func test_get_enhancement_preview_returns_dict():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_true(preview is Dictionary, "preview should be a dictionary")

func test_get_enhancement_preview_contains_required_fields():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_true(preview.has("can_enhance"), "preview should have can_enhance")
	runner.assert_true(preview.has("current_level"), "preview should have current_level")
	runner.assert_true(preview.has("next_level"), "preview should have next_level")
	runner.assert_true(preview.has("max_level"), "preview should have max_level")
	runner.assert_true(preview.has("success_rate"), "preview should have success_rate")
	runner.assert_true(preview.has("cost"), "preview should have cost")

func test_get_enhancement_preview_current_level():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 5)

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_equal(preview.current_level, 5, "current_level should match equipment level")

func test_get_enhancement_preview_next_level():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 5)

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_equal(preview.next_level, 6, "next_level should be current + 1")

func test_get_enhancement_preview_null_equipment():
	var manager = create_enhancement_manager()

	var preview = manager.get_enhancement_preview(null)

	runner.assert_equal(preview.size(), 0, "preview should be empty for null equipment")

func test_get_enhancement_preview_blessed_oil_fields():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_true(preview.has("blessed_oil_available"), "preview should have blessed_oil_available")
	runner.assert_true(preview.has("blessed_oil_bonus"), "preview should have blessed_oil_bonus")

func test_get_enhancement_preview_consequences_field():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var preview = manager.get_enhancement_preview(equipment)

	runner.assert_true(preview.has("consequences"), "preview should have consequences")

# ==============================================================================
# TEST: Enhancement Statistics
# ==============================================================================

func test_get_enhancement_statistics_returns_dict():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var stats = manager.get_enhancement_statistics(equipment)

	runner.assert_true(stats is Dictionary, "stats should be a dictionary")

func test_get_enhancement_statistics_contains_fields():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var stats = manager.get_enhancement_statistics(equipment)

	runner.assert_true(stats.has("current_level"), "stats should have current_level")
	runner.assert_true(stats.has("max_level"), "stats should have max_level")
	runner.assert_true(stats.has("enhancement_progress"), "stats should have enhancement_progress")
	runner.assert_true(stats.has("stat_bonuses"), "stats should have stat_bonuses")
	runner.assert_true(stats.has("total_enhancement_cost"), "stats should have total_enhancement_cost")
	runner.assert_true(stats.has("remaining_enhancement_cost"), "stats should have remaining_enhancement_cost")

func test_get_enhancement_statistics_null_equipment():
	var manager = create_enhancement_manager()

	var stats = manager.get_enhancement_statistics(null)

	runner.assert_equal(stats.size(), 0, "stats should be empty for null equipment")

func test_get_enhancement_statistics_progress():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 0)

	var stats = manager.get_enhancement_statistics(equipment)

	runner.assert_equal(stats.current_level, 0, "current_level should be 0")
	# Progress at level 0 should be 0
	runner.assert_equal(stats.enhancement_progress, 0.0, "progress should be 0 at level 0")

func test_get_enhancement_statistics_partial_progress():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 5)

	var stats = manager.get_enhancement_statistics(equipment)

	runner.assert_equal(stats.current_level, 5, "current_level should be 5")
	# Progress should be between 0 and 1 for partial enhancement
	runner.assert_true(stats.enhancement_progress > 0.0, "progress should be positive at level 5")
	runner.assert_true(stats.enhancement_progress <= 1.0, "progress should be <= 1.0")

# ==============================================================================
# TEST: Bulk Enhancement
# ==============================================================================

func test_enhance_equipment_bulk_returns_result():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var result = manager.enhance_equipment_bulk(equipment, 3)

	runner.assert_true(result is Dictionary, "result should be a dictionary")

func test_enhance_equipment_bulk_contains_fields():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var result = manager.enhance_equipment_bulk(equipment, 3)

	runner.assert_true(result.has("success"), "result should have success")
	runner.assert_true(result.has("start_level"), "result should have start_level")
	runner.assert_true(result.has("final_level"), "result should have final_level")
	runner.assert_true(result.has("attempts"), "result should have attempts")
	runner.assert_true(result.has("successes"), "result should have successes")
	runner.assert_true(result.has("failures"), "result should have failures")
	runner.assert_true(result.has("total_cost"), "result should have total_cost")
	runner.assert_true(result.has("stopped_reason"), "result should have stopped_reason")

func test_enhance_equipment_bulk_null_equipment():
	var manager = create_enhancement_manager()

	var result = manager.enhance_equipment_bulk(null, 5)

	runner.assert_false(result.success, "success should be false for null equipment")
	runner.assert_equal(result.stopped_reason, "null_equipment", "reason should be null_equipment")

func test_enhance_equipment_bulk_start_level():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 3)

	var result = manager.enhance_equipment_bulk(equipment, 5)

	runner.assert_equal(result.start_level, 3, "start_level should be initial equipment level")

func test_enhance_equipment_bulk_insufficient_resources():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	# Without proper ResourceManager setup, enhancement should fail due to resources
	var result = manager.enhance_equipment_bulk(equipment, 10)

	runner.assert_true(result.stopped_reason in ["insufficient_resources", "target_reached", "max_level_reached"],
		"should have a valid stopped reason")

# ==============================================================================
# TEST: Enhance Equipment - Basic
# ==============================================================================

func test_enhance_equipment_null_returns_false():
	var manager = create_enhancement_manager()

	var result = manager.enhance_equipment(null)
	runner.assert_false(result, "enhance with null equipment should return false")

func test_enhance_equipment_at_max_level_returns_false():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 15)  # Max level

	var result = manager.enhance_equipment(equipment)
	runner.assert_false(result, "enhance at max level should return false")

# ==============================================================================
# TEST: Max Enhancement Level by Rarity
# ==============================================================================

func test_max_enhancement_level_common():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON)
	runner.assert_equal(equipment.get_max_enhancement_level(), 15, "common max enhancement should be 15")

func test_max_enhancement_level_rare():
	var equipment = create_mock_equipment(Equipment.Rarity.RARE)
	runner.assert_equal(equipment.get_max_enhancement_level(), 15, "rare max enhancement should be 15")

func test_max_enhancement_level_epic():
	var equipment = create_mock_equipment(Equipment.Rarity.EPIC)
	runner.assert_equal(equipment.get_max_enhancement_level(), 15, "epic max enhancement should be 15")

func test_max_enhancement_level_legendary():
	var equipment = create_mock_equipment(Equipment.Rarity.LEGENDARY)
	runner.assert_equal(equipment.get_max_enhancement_level(), 15, "legendary max enhancement should be 15")

func test_max_enhancement_level_mythic():
	var equipment = create_mock_equipment(Equipment.Rarity.MYTHIC)
	runner.assert_equal(equipment.get_max_enhancement_level(), 15, "mythic max enhancement should be 15")

# ==============================================================================
# TEST: Enhancement Cost Calculation
# ==============================================================================

func test_enhancement_cost_returns_dict():
	var equipment = create_mock_equipment()
	var cost = equipment.get_enhancement_cost()
	runner.assert_true(cost is Dictionary, "cost should be a dictionary")

func test_enhancement_cost_has_resources():
	var equipment = create_mock_equipment()
	var cost = equipment.get_enhancement_cost()
	# Should have at least mana cost
	runner.assert_true(cost.has("mana") or cost.size() > 0, "cost should have resources")

func test_enhancement_cost_increases_with_level():
	var equipment_low = create_mock_equipment(Equipment.Rarity.COMMON, 1)
	var equipment_high = create_mock_equipment(Equipment.Rarity.COMMON, 10)

	var cost_low = equipment_low.get_enhancement_cost()
	var cost_high = equipment_high.get_enhancement_cost()

	# Higher level should cost more
	var low_mana = cost_low.get("mana", 0)
	var high_mana = cost_high.get("mana", 0)

	runner.assert_true(high_mana >= low_mana, "higher level should cost more or equal mana")

func test_enhancement_cost_for_level():
	var equipment = create_mock_equipment()

	var cost_1 = equipment.get_enhancement_cost_for_level(1)
	var cost_5 = equipment.get_enhancement_cost_for_level(5)
	var cost_10 = equipment.get_enhancement_cost_for_level(10)

	# All should return dictionaries
	runner.assert_true(cost_1 is Dictionary, "cost_1 should be dict")
	runner.assert_true(cost_5 is Dictionary, "cost_5 should be dict")
	runner.assert_true(cost_10 is Dictionary, "cost_10 should be dict")

# ==============================================================================
# TEST: Enhancement Success Rate
# ==============================================================================

func test_success_rate_returns_float():
	var equipment = create_mock_equipment()
	var rate = equipment.get_enhancement_success_rate()
	runner.assert_true(rate is float, "success rate should be a float")

func test_success_rate_range():
	var equipment = create_mock_equipment()
	var rate = equipment.get_enhancement_success_rate()
	runner.assert_true(rate >= 0.0, "success rate should be >= 0")
	runner.assert_true(rate <= 1.0, "success rate should be <= 1")

func test_success_rate_decreases_with_level():
	var equipment_low = create_mock_equipment(Equipment.Rarity.COMMON, 1)
	var equipment_high = create_mock_equipment(Equipment.Rarity.COMMON, 14)

	var rate_low = equipment_low.get_enhancement_success_rate()
	var rate_high = equipment_high.get_enhancement_success_rate()

	# Higher level should have lower or equal success rate
	runner.assert_true(rate_high <= rate_low, "higher level should have lower or equal success rate")

func test_success_rate_by_rarity():
	var common = create_mock_equipment(Equipment.Rarity.COMMON, 5)
	var legendary = create_mock_equipment(Equipment.Rarity.LEGENDARY, 5)

	var rate_common = common.get_enhancement_success_rate()
	var rate_legendary = legendary.get_enhancement_success_rate()

	# Both should be valid rates
	runner.assert_true(rate_common >= 0.0 and rate_common <= 1.0, "common rate should be valid")
	runner.assert_true(rate_legendary >= 0.0 and rate_legendary <= 1.0, "legendary rate should be valid")

# ==============================================================================
# TEST: Stat Bonus Per Enhancement
# ==============================================================================

func test_enhancement_stat_bonuses_returns_dict():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 5)
	var bonuses = equipment.get_enhancement_stat_bonuses()
	runner.assert_true(bonuses is Dictionary, "stat bonuses should be a dictionary")

func test_enhancement_stat_bonuses_at_level_0():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 0)
	var bonuses = equipment.get_enhancement_stat_bonuses()

	# At level 0, there should be no enhancement bonuses (or empty dict)
	var total_bonus = 0
	for key in bonuses:
		total_bonus += bonuses[key]

	runner.assert_equal(total_bonus, 0, "no bonuses at level 0")

func test_enhancement_stat_bonuses_increase_with_level():
	var equipment_low = create_mock_equipment(Equipment.Rarity.COMMON, 3)
	var equipment_high = create_mock_equipment(Equipment.Rarity.COMMON, 10)

	var bonuses_low = equipment_low.get_enhancement_stat_bonuses()
	var bonuses_high = equipment_high.get_enhancement_stat_bonuses()

	# Calculate total bonuses
	var total_low = 0
	for key in bonuses_low:
		total_low += bonuses_low[key]

	var total_high = 0
	for key in bonuses_high:
		total_high += bonuses_high[key]

	runner.assert_true(total_high >= total_low, "higher level should have >= bonuses")

# ==============================================================================
# TEST: Can Be Enhanced
# ==============================================================================

func test_can_be_enhanced_at_level_0():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 0)
	runner.assert_true(equipment.can_be_enhanced(), "should be enhanceable at level 0")

func test_can_be_enhanced_at_mid_level():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 7)
	runner.assert_true(equipment.can_be_enhanced(), "should be enhanceable at level 7")

func test_can_be_enhanced_at_max_level():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 15)
	runner.assert_false(equipment.can_be_enhanced(), "should not be enhanceable at max level")

func test_can_be_enhanced_one_below_max():
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 14)
	runner.assert_true(equipment.can_be_enhanced(), "should be enhanceable one below max")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_enhancement_preview_with_blessed_oil():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment()

	var preview_without = manager.get_enhancement_preview(equipment, false)
	var preview_with = manager.get_enhancement_preview(equipment, true)

	# Both should have valid structure
	runner.assert_true(preview_without.has("success_rate"), "preview without oil should have success_rate")
	runner.assert_true(preview_with.has("success_rate"), "preview with oil should have success_rate")

func test_bulk_enhancement_target_higher_than_max():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 10)

	var result = manager.enhance_equipment_bulk(equipment, 100)  # Way over max

	# Should clamp to max level
	runner.assert_true(result.final_level <= 15, "final level should not exceed max")

func test_equipment_destroyed_flag():
	var equipment = create_mock_equipment()
	runner.assert_false(equipment.is_destroyed, "equipment should not be destroyed initially")

	equipment.is_destroyed = true
	runner.assert_true(equipment.is_destroyed, "equipment destroyed flag should be settable")

func test_enhancement_statistics_cost_calculations():
	var manager = create_enhancement_manager()
	var equipment = create_mock_equipment(Equipment.Rarity.COMMON, 5)

	var stats = manager.get_enhancement_statistics(equipment)

	runner.assert_true(stats.total_enhancement_cost is Dictionary, "total cost should be dict")
	runner.assert_true(stats.remaining_enhancement_cost is Dictionary, "remaining cost should be dict")
