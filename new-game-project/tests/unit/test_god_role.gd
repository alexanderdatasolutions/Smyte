# test_god_role.gd - Unit tests for GodRole data class
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_role_data() -> Dictionary:
	return {
		"id": "test_role",
		"name": "Test Role",
		"description": "A role for testing",
		"role_type": "fighter",
		"icon": "res://assets/icons/role_test.png",
		"stat_bonuses": {"attack_percent": 0.15, "defense_percent": 0.10},
		"task_bonuses": {"combat": 0.20, "defense": 0.15},
		"task_penalties": {"crafting": -0.10, "research": -0.05},
		"resource_bonuses": {"gather_yield_percent": 0.10},
		"crafting_bonuses": {"quality_percent": 0.05},
		"aura_bonuses": {"ally_efficiency_percent": 0.10},
		"other_bonuses": {"xp_gain_percent": 0.15},
		"specialization_trees": ["berserker", "guardian"]
	}

func create_mock_gatherer_role_data() -> Dictionary:
	return {
		"id": "gatherer",
		"name": "Gatherer",
		"description": "Gods of nature and harvest",
		"role_type": "gatherer",
		"icon": "res://assets/icons/role_gatherer.png",
		"stat_bonuses": {"hp_percent": 0.05},
		"task_bonuses": {"mining": 0.25, "harvesting": 0.25},
		"task_penalties": {"research": -0.10},
		"resource_bonuses": {"gather_yield_percent": 0.25, "rare_chance_percent": 0.10},
		"specialization_trees": ["miner", "fisher", "herbalist"]
	}

# ==============================================================================
# TEST: GodRole Data Class - Basic Properties
# ==============================================================================

func test_role_from_dict_creates_role():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_not_null(god_role, "should create role from dict")
	runner.assert_equal(god_role.id, "test_role", "should have correct id")
	runner.assert_equal(god_role.name, "Test Role", "should have correct name")

func test_role_from_dict_parses_description():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.description, "A role for testing", "should have correct description")

func test_role_from_dict_parses_icon_path():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.icon_path, "res://assets/icons/role_test.png", "should parse icon path")

# ==============================================================================
# TEST: GodRole Data Class - Role Type Enum
# ==============================================================================

func test_role_from_dict_parses_fighter_type():
	var data = create_mock_role_data()
	data["role_type"] = "fighter"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.role_type, GodRole.RoleType.FIGHTER, "should parse fighter")

func test_role_from_dict_parses_gatherer_type():
	var data = create_mock_role_data()
	data["role_type"] = "gatherer"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.role_type, GodRole.RoleType.GATHERER, "should parse gatherer")

func test_role_from_dict_parses_crafter_type():
	var data = create_mock_role_data()
	data["role_type"] = "crafter"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.role_type, GodRole.RoleType.CRAFTER, "should parse crafter")

func test_role_from_dict_parses_scholar_type():
	var data = create_mock_role_data()
	data["role_type"] = "scholar"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.role_type, GodRole.RoleType.SCHOLAR, "should parse scholar")

func test_role_from_dict_parses_support_type():
	var data = create_mock_role_data()
	data["role_type"] = "support"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.role_type, GodRole.RoleType.SUPPORT, "should parse support")

func test_role_type_to_string_fighter():
	var result = GodRole.role_type_to_string(GodRole.RoleType.FIGHTER)
	runner.assert_equal(result, "fighter", "should convert FIGHTER to fighter")

func test_role_type_to_string_gatherer():
	var result = GodRole.role_type_to_string(GodRole.RoleType.GATHERER)
	runner.assert_equal(result, "gatherer", "should convert GATHERER to gatherer")

func test_role_type_to_string_crafter():
	var result = GodRole.role_type_to_string(GodRole.RoleType.CRAFTER)
	runner.assert_equal(result, "crafter", "should convert CRAFTER to crafter")

func test_role_type_to_string_scholar():
	var result = GodRole.role_type_to_string(GodRole.RoleType.SCHOLAR)
	runner.assert_equal(result, "scholar", "should convert SCHOLAR to scholar")

func test_role_type_to_string_support():
	var result = GodRole.role_type_to_string(GodRole.RoleType.SUPPORT)
	runner.assert_equal(result, "support", "should convert SUPPORT to support")

func test_string_to_role_type_fighter():
	var result = GodRole.string_to_role_type("fighter")
	runner.assert_equal(result, GodRole.RoleType.FIGHTER, "should convert fighter to FIGHTER")

func test_string_to_role_type_case_insensitive():
	var result = GodRole.string_to_role_type("FIGHTER")
	runner.assert_equal(result, GodRole.RoleType.FIGHTER, "should handle uppercase")

func test_string_to_role_type_unknown_defaults_to_fighter():
	var result = GodRole.string_to_role_type("unknown")
	runner.assert_equal(result, GodRole.RoleType.FIGHTER, "should default to FIGHTER for unknown")

# ==============================================================================
# TEST: GodRole Data Class - Stat Bonuses
# ==============================================================================

func test_role_from_dict_parses_stat_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.stat_bonuses.size(), 2, "should have 2 stat bonuses")
	runner.assert_equal(god_role.stat_bonuses["attack_percent"], 0.15, "should have correct attack bonus")
	runner.assert_equal(god_role.stat_bonuses["defense_percent"], 0.10, "should have correct defense bonus")

func test_role_get_stat_bonus_returns_bonus():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_stat_bonus("attack_percent")
	runner.assert_equal(bonus, 0.15, "should return correct bonus")

func test_role_get_stat_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_stat_bonus("unknown_stat")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown stat")

func test_role_has_stat_bonus_true():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_true(god_role.has_stat_bonus("attack_percent"), "should have attack bonus")

func test_role_has_stat_bonus_false():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_false(god_role.has_stat_bonus("unknown"), "should not have unknown stat")

func test_role_get_all_stat_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_stat_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")
	runner.assert_equal(bonuses["attack_percent"], 0.15, "should have correct values")

func test_role_get_all_stat_bonuses_returns_copy():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_stat_bonuses()
	bonuses["new_stat"] = 0.5

	runner.assert_false(god_role.has_stat_bonus("new_stat"), "should not modify original")

# ==============================================================================
# TEST: GodRole Data Class - Task Bonuses
# ==============================================================================

func test_role_from_dict_parses_task_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.task_bonuses.size(), 2, "should have 2 task bonuses")
	runner.assert_equal(god_role.task_bonuses["combat"], 0.20, "should have correct combat bonus")
	runner.assert_equal(god_role.task_bonuses["defense"], 0.15, "should have correct defense bonus")

func test_role_get_task_bonus_returns_bonus():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_task_bonus("combat")
	runner.assert_equal(bonus, 0.20, "should return correct bonus")

func test_role_get_task_bonus_returns_penalty():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_task_bonus("crafting")
	runner.assert_equal(bonus, -0.10, "should return penalty")

func test_role_get_task_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_task_bonus("unknown_task")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown task")

func test_role_has_task_bonus_true():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_true(god_role.has_task_bonus("combat"), "should have combat bonus")

func test_role_has_task_bonus_false():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_false(god_role.has_task_bonus("unknown"), "should not have unknown task")

func test_role_has_task_penalty_true():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_true(god_role.has_task_penalty("crafting"), "should have crafting penalty")

func test_role_has_task_penalty_false():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_false(god_role.has_task_penalty("combat"), "should not have combat penalty")

func test_role_get_all_task_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_task_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")
	runner.assert_equal(bonuses["combat"], 0.20, "should have correct values")

func test_role_get_all_task_penalties():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var penalties = god_role.get_all_task_penalties()
	runner.assert_equal(penalties.size(), 2, "should return all penalties")
	runner.assert_equal(penalties["crafting"], -0.10, "should have correct values")

# ==============================================================================
# TEST: GodRole Data Class - Task Penalties
# ==============================================================================

func test_role_from_dict_parses_task_penalties():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.task_penalties.size(), 2, "should have 2 task penalties")
	runner.assert_equal(god_role.task_penalties["crafting"], -0.10, "should have correct crafting penalty")
	runner.assert_equal(god_role.task_penalties["research"], -0.05, "should have correct research penalty")

# ==============================================================================
# TEST: GodRole Data Class - Resource Bonuses
# ==============================================================================

func test_role_from_dict_parses_resource_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.resource_bonuses.size(), 1, "should have 1 resource bonus")
	runner.assert_equal(god_role.resource_bonuses["gather_yield_percent"], 0.10, "should have correct bonus")

func test_role_get_resource_bonus_returns_bonus():
	var data = create_mock_gatherer_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_resource_bonus("gather_yield_percent")
	runner.assert_equal(bonus, 0.25, "should return correct bonus")

func test_role_get_resource_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_resource_bonus("unknown_resource")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown resource")

func test_role_get_all_resource_bonuses():
	var data = create_mock_gatherer_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_resource_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")
	runner.assert_equal(bonuses["gather_yield_percent"], 0.25, "should have correct values")

func test_role_get_all_resource_bonuses_returns_copy():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_resource_bonuses()
	bonuses["new_resource"] = 0.5

	var original = god_role.get_all_resource_bonuses()
	runner.assert_false(original.has("new_resource"), "should not modify original")

# ==============================================================================
# TEST: GodRole Data Class - Crafting Bonuses
# ==============================================================================

func test_role_from_dict_parses_crafting_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.crafting_bonuses.size(), 1, "should have 1 crafting bonus")
	runner.assert_equal(god_role.crafting_bonuses["quality_percent"], 0.05, "should have correct bonus")

func test_role_get_crafting_bonus_returns_bonus():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_crafting_bonus("quality_percent")
	runner.assert_equal(bonus, 0.05, "should return correct bonus")

func test_role_get_crafting_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_crafting_bonus("unknown_bonus")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown bonus")

func test_role_get_all_crafting_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_crafting_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")
	runner.assert_equal(bonuses["quality_percent"], 0.05, "should have correct values")

# ==============================================================================
# TEST: GodRole Data Class - Aura Bonuses
# ==============================================================================

func test_role_from_dict_parses_aura_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.aura_bonuses.size(), 1, "should have 1 aura bonus")
	runner.assert_equal(god_role.aura_bonuses["ally_efficiency_percent"], 0.10, "should have correct bonus")

func test_role_get_aura_bonus_returns_bonus():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_aura_bonus("ally_efficiency_percent")
	runner.assert_equal(bonus, 0.10, "should return correct bonus")

func test_role_get_aura_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_aura_bonus("unknown_aura")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown aura")

func test_role_get_all_aura_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_aura_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")
	runner.assert_equal(bonuses["ally_efficiency_percent"], 0.10, "should have correct values")

# ==============================================================================
# TEST: GodRole Data Class - Other Bonuses
# ==============================================================================

func test_role_from_dict_parses_other_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.other_bonuses.size(), 1, "should have 1 other bonus")
	runner.assert_equal(god_role.other_bonuses["xp_gain_percent"], 0.15, "should have correct bonus")

func test_role_get_other_bonus_returns_bonus():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_other_bonus("xp_gain_percent")
	runner.assert_equal(bonus, 0.15, "should return correct bonus")

func test_role_get_other_bonus_returns_zero_for_unknown():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_other_bonus("unknown_bonus")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown bonus")

func test_role_get_all_other_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var bonuses = god_role.get_all_other_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")
	runner.assert_equal(bonuses["xp_gain_percent"], 0.15, "should have correct values")

# ==============================================================================
# TEST: GodRole Data Class - Specialization Trees
# ==============================================================================

func test_role_from_dict_parses_specialization_trees():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.specialization_trees.size(), 2, "should have 2 specialization trees")
	runner.assert_true("berserker" in god_role.specialization_trees, "should have berserker tree")
	runner.assert_true("guardian" in god_role.specialization_trees, "should have guardian tree")

func test_role_get_specialization_trees():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var trees = god_role.get_specialization_trees()
	runner.assert_equal(trees.size(), 2, "should return all trees")
	runner.assert_true("berserker" in trees, "should contain berserker")

func test_role_get_specialization_trees_returns_copy():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var trees = god_role.get_specialization_trees()
	trees.append("new_tree")

	var original = god_role.get_specialization_trees()
	runner.assert_equal(original.size(), 2, "should not modify original")

func test_role_has_specialization_tree_true():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_true(god_role.has_specialization_tree("berserker"), "should have berserker tree")

func test_role_has_specialization_tree_false():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	runner.assert_false(god_role.has_specialization_tree("unknown"), "should not have unknown tree")

# ==============================================================================
# TEST: GodRole Data Class - Display Methods
# ==============================================================================

func test_role_get_display_name():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var display = god_role.get_display_name()
	runner.assert_equal(display, "Test Role", "should return name")

func test_role_get_tooltip_contains_name():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("Test Role"), "should contain role name")

func test_role_get_tooltip_contains_description():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("A role for testing"), "should contain description")

func test_role_get_tooltip_contains_stat_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("Stat Bonuses"), "should have stat bonuses section")
	runner.assert_true(tooltip.contains("15%"), "should show attack bonus")

func test_role_get_tooltip_contains_task_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("Task Bonuses"), "should have task bonuses section")
	runner.assert_true(tooltip.contains("Combat"), "should show combat bonus")

func test_role_get_tooltip_contains_task_penalties():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("Task Penalties"), "should have penalties section")
	runner.assert_true(tooltip.contains("Crafting"), "should show crafting penalty")

func test_role_get_tooltip_contains_specializations():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	var tooltip = god_role.get_tooltip()
	runner.assert_true(tooltip.contains("Available Specializations"), "should have spec section")
	runner.assert_true(tooltip.contains("Berserker"), "should show berserker")

# ==============================================================================
# TEST: GodRole Data Class - Serialization
# ==============================================================================

func test_role_to_dict_preserves_basic_data():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["id"], data["id"], "should preserve id")
	runner.assert_equal(output["name"], data["name"], "should preserve name")
	runner.assert_equal(output["description"], data["description"], "should preserve description")

func test_role_to_dict_converts_role_type_to_string():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["role_type"], "fighter", "should convert role_type to string")

func test_role_to_dict_preserves_stat_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["stat_bonuses"]["attack_percent"], 0.15, "should preserve stat bonuses")

func test_role_to_dict_preserves_task_bonuses():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["task_bonuses"]["combat"], 0.20, "should preserve task bonuses")

func test_role_to_dict_preserves_task_penalties():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["task_penalties"]["crafting"], -0.10, "should preserve task penalties")

func test_role_to_dict_preserves_specialization_trees():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()

	runner.assert_equal(output["specialization_trees"].size(), 2, "should preserve spec trees")
	runner.assert_true("berserker" in output["specialization_trees"], "should have berserker")

func test_role_round_trip_serialization():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)
	var output = god_role.to_dict()
	var restored = GodRole.from_dict(output)

	runner.assert_equal(restored.id, god_role.id, "should restore id")
	runner.assert_equal(restored.name, god_role.name, "should restore name")
	runner.assert_equal(restored.role_type, god_role.role_type, "should restore role_type")

# ==============================================================================
# TEST: GodRole Data Class - Edge Cases
# ==============================================================================

func test_role_from_dict_with_empty_bonuses():
	var data = {
		"id": "empty_role",
		"name": "Empty",
		"role_type": "fighter",
		"stat_bonuses": {},
		"task_bonuses": {},
		"task_penalties": {},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"aura_bonuses": {},
		"other_bonuses": {},
		"specialization_trees": []
	}
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.stat_bonuses.size(), 0, "should handle empty stat bonuses")
	runner.assert_equal(god_role.task_bonuses.size(), 0, "should handle empty task bonuses")
	runner.assert_equal(god_role.specialization_trees.size(), 0, "should handle empty trees")

func test_role_from_dict_with_missing_fields():
	var data = {"id": "minimal", "name": "Minimal"}
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.id, "minimal", "should handle minimal data")
	runner.assert_equal(god_role.name, "Minimal", "should handle minimal data")
	runner.assert_equal(god_role.role_type, GodRole.RoleType.FIGHTER, "should default to FIGHTER")

func test_role_from_dict_with_null_bonuses():
	var data = {
		"id": "null_role",
		"name": "Null",
		"role_type": "fighter"
	}
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.stat_bonuses.size(), 0, "should default to empty dict")
	runner.assert_equal(god_role.task_bonuses.size(), 0, "should default to empty dict")

func test_role_with_negative_task_bonuses():
	var data = create_mock_role_data()
	data["task_bonuses"]["negative_task"] = -0.5
	var god_role = GodRole.from_dict(data)

	var bonus = god_role.get_task_bonus("negative_task")
	runner.assert_equal(bonus, -0.5, "should handle negative bonuses in task_bonuses")

func test_role_specialization_trees_typed_array():
	var data = create_mock_role_data()
	var god_role = GodRole.from_dict(data)

	# Verify it's a typed array by checking type
	var trees = god_role.specialization_trees
	runner.assert_equal(typeof(trees), TYPE_ARRAY, "should be an array")
	runner.assert_equal(trees.size(), 2, "should have correct size")

func test_role_icon_path_mapping():
	var data = create_mock_role_data()
	data["icon"] = "res://test_icon.png"
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.icon_path, "res://test_icon.png", "should map 'icon' to 'icon_path'")

func test_role_empty_specialization_trees():
	var data = create_mock_role_data()
	data["specialization_trees"] = []
	var god_role = GodRole.from_dict(data)

	runner.assert_equal(god_role.specialization_trees.size(), 0, "should handle empty trees")
	runner.assert_false(god_role.has_specialization_tree("any"), "should not have any trees")

func test_role_mixed_bonus_types():
	var data = create_mock_gatherer_role_data()
	var god_role = GodRole.from_dict(data)

	# Has task_bonuses but no task_penalties, resource_bonuses but no crafting/aura/other
	runner.assert_equal(god_role.task_bonuses.size(), 2, "should have task bonuses")
	runner.assert_equal(god_role.resource_bonuses.size(), 2, "should have resource bonuses")
	runner.assert_equal(god_role.crafting_bonuses.size(), 0, "should have no crafting bonuses")
