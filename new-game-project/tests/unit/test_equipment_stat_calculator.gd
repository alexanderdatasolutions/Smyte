# test_equipment_stat_calculator.gd - Unit tests for scripts/systems/equipment/EquipmentStatCalculator.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_stat_calculator() -> EquipmentStatCalculator:
	"""Create a fresh EquipmentStatCalculator for testing"""
	var calculator = EquipmentStatCalculator.new()
	return calculator

func create_mock_god(god_id: String = "", god_name: String = "TestGod") -> God:
	"""Create a mock God for testing"""
	var god = God.new()
	god.id = god_id if god_id != "" else "god_" + str(randi() % 10000)
	god.name = god_name
	god.pantheon = "greek"
	god.element = God.ElementType.FIRE
	god.tier = God.TierType.RARE
	god.level = 1
	god.base_hp = 1000
	god.base_attack = 200
	god.base_defense = 100
	god.base_speed = 100
	god.base_crit_rate = 15
	god.base_crit_damage = 50
	god.base_resistance = 15
	god.base_accuracy = 0
	god.equipment = [null, null, null, null, null, null]
	return god

func create_mock_equipment(equipment_id: String = "", main_stat: String = "attack", main_value: int = 50) -> Equipment:
	"""Create mock equipment for testing"""
	var eq = Equipment.new()
	eq.equipment_id = equipment_id if equipment_id != "" else "eq_" + str(randi() % 10000)
	eq.name = "Test Equipment"
	eq.equipment_type = Equipment.EquipmentType.WEAPON
	eq.rarity = Equipment.Rarity.COMMON
	eq.enhancement_level = 0
	eq.level = 0
	eq.main_stat_type = main_stat
	eq.main_stat_base = main_value
	eq.main_stat_value = main_value
	eq.substats = []
	eq.equipment_set_name = ""
	return eq

# ==============================================================================
# TEST: God Total Stats Calculation
# ==============================================================================

func test_calculate_god_total_stats_returns_dict():
	var calculator = create_stat_calculator()
	var god = create_mock_god()

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_true(stats is Dictionary, "should return dictionary")

func test_calculate_god_total_stats_contains_all_stats():
	var calculator = create_stat_calculator()
	var god = create_mock_god()

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_true(stats.has("hp"), "should have hp")
	runner.assert_true(stats.has("attack"), "should have attack")
	runner.assert_true(stats.has("defense"), "should have defense")
	runner.assert_true(stats.has("speed"), "should have speed")
	runner.assert_true(stats.has("crit_rate"), "should have crit_rate")
	runner.assert_true(stats.has("crit_damage"), "should have crit_damage")
	runner.assert_true(stats.has("resistance"), "should have resistance")
	runner.assert_true(stats.has("accuracy"), "should have accuracy")

func test_calculate_god_total_stats_base_values():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.base_hp = 5000
	god.base_attack = 300
	god.base_defense = 200

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_equal(stats.hp, 5000, "hp should match base_hp")
	runner.assert_equal(stats.attack, 300, "attack should match base_attack")
	runner.assert_equal(stats.defense, 200, "defense should match base_defense")

func test_calculate_god_total_stats_null_god():
	var calculator = create_stat_calculator()

	var stats = calculator.calculate_god_total_stats(null)

	runner.assert_equal(stats.size(), 0, "should return empty for null god")

func test_calculate_god_total_stats_with_equipment():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.base_attack = 200

	var weapon = create_mock_equipment("weapon_001", "attack", 100)
	god.equipment[0] = weapon

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_equal(stats.attack, 300, "attack should be base + equipment (200 + 100)")

func test_calculate_god_total_stats_with_multiple_equipment():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.base_attack = 200
	god.base_defense = 100

	var weapon = create_mock_equipment("weapon_001", "attack", 50)
	var armor = create_mock_equipment("armor_001", "defense", 75)
	god.equipment[0] = weapon
	god.equipment[1] = armor

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_equal(stats.attack, 250, "attack should include weapon bonus")
	runner.assert_equal(stats.defense, 175, "defense should include armor bonus")

# ==============================================================================
# TEST: Equipment Power Rating Calculation
# ==============================================================================

func test_calculate_equipment_power_rating_returns_int():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var power = calculator.calculate_equipment_power_rating(equipment)

	runner.assert_true(power is int, "power should be an integer")

func test_calculate_equipment_power_rating_basic():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment("test", "attack", 100)

	var power = calculator.calculate_equipment_power_rating(equipment)

	runner.assert_true(power > 0, "power should be positive")

func test_calculate_equipment_power_rating_null():
	var calculator = create_stat_calculator()

	var power = calculator.calculate_equipment_power_rating(null)

	runner.assert_equal(power, 0, "power should be 0 for null equipment")

func test_power_rating_increases_with_main_stat():
	var calculator = create_stat_calculator()
	var eq_low = create_mock_equipment("low", "attack", 50)
	var eq_high = create_mock_equipment("high", "attack", 200)

	var power_low = calculator.calculate_equipment_power_rating(eq_low)
	var power_high = calculator.calculate_equipment_power_rating(eq_high)

	runner.assert_true(power_high > power_low, "higher main stat should have higher power")

func test_power_rating_rarity_multiplier():
	var calculator = create_stat_calculator()

	var eq_common = create_mock_equipment("common", "attack", 100)
	eq_common.rarity = Equipment.Rarity.COMMON

	var eq_legendary = create_mock_equipment("legendary", "attack", 100)
	eq_legendary.rarity = Equipment.Rarity.LEGENDARY

	var power_common = calculator.calculate_equipment_power_rating(eq_common)
	var power_legendary = calculator.calculate_equipment_power_rating(eq_legendary)

	runner.assert_true(power_legendary > power_common, "legendary should have higher power than common")

# ==============================================================================
# TEST: Equipment Display Info
# ==============================================================================

func test_get_equipment_display_info_returns_dict():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var info = calculator.get_equipment_display_info(equipment)

	runner.assert_true(info is Dictionary, "should return dictionary")

func test_get_equipment_display_info_contains_fields():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var info = calculator.get_equipment_display_info(equipment)

	runner.assert_true(info.has("name"), "should have name")
	runner.assert_true(info.has("type"), "should have type")
	runner.assert_true(info.has("rarity"), "should have rarity")
	runner.assert_true(info.has("level"), "should have level")
	runner.assert_true(info.has("power_rating"), "should have power_rating")
	runner.assert_true(info.has("main_stat"), "should have main_stat")

func test_get_equipment_display_info_null():
	var calculator = create_stat_calculator()

	var info = calculator.get_equipment_display_info(null)

	runner.assert_equal(info.size(), 0, "should return empty for null equipment")

func test_get_equipment_display_info_name():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()
	equipment.name = "Legendary Sword"

	var info = calculator.get_equipment_display_info(equipment)

	runner.assert_equal(info.name, "Legendary Sword", "name should match")

func test_get_equipment_display_info_substats():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var info = calculator.get_equipment_display_info(equipment)

	runner.assert_true(info.has("substats"), "should have substats")
	runner.assert_true(info.substats is Array, "substats should be array")

# ==============================================================================
# TEST: Set Bonus Calculation
# ==============================================================================

func test_calculate_set_bonuses_returns_dict():
	var calculator = create_stat_calculator()
	var god = create_mock_god()

	var bonuses = calculator.calculate_set_bonuses(god)

	runner.assert_true(bonuses is Dictionary, "should return dictionary")

func test_calculate_set_bonuses_null_god():
	var calculator = create_stat_calculator()

	var bonuses = calculator.calculate_set_bonuses(null)

	runner.assert_equal(bonuses.size(), 0, "should return empty for null god")

func test_calculate_set_bonuses_no_equipment():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.equipped_equipment = []

	var bonuses = calculator.calculate_set_bonuses(god)

	runner.assert_equal(bonuses.size(), 0, "should return empty for no equipment")

# ==============================================================================
# TEST: Enhancement Preview
# ==============================================================================

func test_get_enhancement_preview_returns_dict():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var preview = calculator.get_enhancement_preview(equipment)

	runner.assert_true(preview is Dictionary, "should return dictionary")

func test_get_enhancement_preview_null():
	var calculator = create_stat_calculator()

	var preview = calculator.get_enhancement_preview(null)

	runner.assert_equal(preview.size(), 0, "should return empty for null equipment")

func test_get_enhancement_preview_contains_fields():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()

	var preview = calculator.get_enhancement_preview(equipment)

	runner.assert_true(preview.has("can_enhance"), "should have can_enhance")
	runner.assert_true(preview.has("current_level"), "should have current_level")
	runner.assert_true(preview.has("next_level"), "should have next_level")
	runner.assert_true(preview.has("main_stat_increase"), "should have main_stat_increase")
	runner.assert_true(preview.has("success_rate"), "should have success_rate")
	runner.assert_true(preview.has("cost"), "should have cost")

func test_get_enhancement_preview_at_max_level():
	var calculator = create_stat_calculator()
	var equipment = create_mock_equipment()
	equipment.level = 15  # Max level

	var preview = calculator.get_enhancement_preview(equipment)

	runner.assert_false(preview.can_enhance, "should not be enhanceable at max")
	runner.assert_equal(preview.reason, "Max level reached", "should have reason")

func test_get_enhancement_preview_success_rate_decreases():
	var calculator = create_stat_calculator()
	var eq_low = create_mock_equipment()
	eq_low.level = 1

	var eq_high = create_mock_equipment()
	eq_high.level = 10

	var preview_low = calculator.get_enhancement_preview(eq_low)
	var preview_high = calculator.get_enhancement_preview(eq_high)

	runner.assert_true(preview_high.success_rate <= preview_low.success_rate,
		"higher level should have lower or equal success rate")

func test_get_enhancement_preview_cost_increases():
	var calculator = create_stat_calculator()
	var eq_low = create_mock_equipment()
	eq_low.level = 1

	var eq_high = create_mock_equipment()
	eq_high.level = 10

	var preview_low = calculator.get_enhancement_preview(eq_low)
	var preview_high = calculator.get_enhancement_preview(eq_high)

	# Assuming cost has mana
	var cost_low = preview_low.cost.get("mana", 0)
	var cost_high = preview_high.cost.get("mana", 0)

	runner.assert_true(cost_high >= cost_low, "higher level should cost more or equal")

# ==============================================================================
# TEST: Static Constants
# ==============================================================================

func test_slot_type_names_contains_all_types():
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.WEAPON), "should have WEAPON")
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.ARMOR), "should have ARMOR")
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.HELM), "should have HELM")
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.BOOTS), "should have BOOTS")
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.AMULET), "should have AMULET")
	runner.assert_true(EquipmentStatCalculator.SLOT_TYPE_NAMES.has(Equipment.EquipmentType.RING), "should have RING")

func test_slot_type_names_values():
	runner.assert_equal(EquipmentStatCalculator.SLOT_TYPE_NAMES[Equipment.EquipmentType.WEAPON], "Weapon", "WEAPON name")
	runner.assert_equal(EquipmentStatCalculator.SLOT_TYPE_NAMES[Equipment.EquipmentType.ARMOR], "Armor", "ARMOR name")
	runner.assert_equal(EquipmentStatCalculator.SLOT_TYPE_NAMES[Equipment.EquipmentType.HELM], "Helm", "HELM name")
	runner.assert_equal(EquipmentStatCalculator.SLOT_TYPE_NAMES[Equipment.EquipmentType.BOOTS], "Boots", "BOOTS name")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_god_with_null_equipment_array():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.equipment = null

	var stats = calculator.calculate_god_total_stats(god)

	# Should still return base stats without crashing
	runner.assert_equal(stats.hp, god.base_hp, "should return base hp even with null equipment")

func test_god_with_partial_equipment():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.base_attack = 200

	# Only slot 2 has equipment
	var helm = create_mock_equipment("helm_001", "defense", 30)
	god.equipment[2] = helm

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_equal(stats.defense, god.base_defense + 30, "defense should include helm")
	runner.assert_equal(stats.attack, 200, "attack should be base only")

func test_equipment_with_substats():
	var calculator = create_stat_calculator()
	var god = create_mock_god()
	god.base_crit_rate = 15

	var equipment = create_mock_equipment("ring", "attack", 50)
	equipment.substats = [
		{"type": "crit_rate", "value": 5},
		{"type": "crit_damage", "value": 10}
	]
	god.equipment[5] = equipment

	var stats = calculator.calculate_god_total_stats(god)

	runner.assert_equal(stats.crit_rate, 20, "crit_rate should include substat (15 + 5)")
	runner.assert_equal(stats.crit_damage, 60, "crit_damage should include substat (50 + 10)")

func test_power_rating_with_substats():
	var calculator = create_stat_calculator()

	var eq_no_substats = create_mock_equipment("basic", "attack", 100)
	eq_no_substats.substats = []

	var eq_with_substats = create_mock_equipment("better", "attack", 100)
	eq_with_substats.substats = [
		{"type": "crit_rate", "value": 10},
		{"type": "speed", "value": 20}
	]

	var power_no_sub = calculator.calculate_equipment_power_rating(eq_no_substats)
	var power_with_sub = calculator.calculate_equipment_power_rating(eq_with_substats)

	runner.assert_true(power_with_sub >= power_no_sub, "equipment with substats should have >= power")
