# test_god_specialization.gd - Unit tests for GodSpecialization data class
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_tier1_spec_data() -> Dictionary:
	return {
		"id": "fighter_berserker",
		"name": "Berserker",
		"description": "Embrace primal fury and overwhelming offense",
		"icon_path": "res://assets/icons/specs/fighter_berserker.png",
		"tier": 1,
		"parent_spec": null,
		"children_specs": ["fighter_berserker_raging", "fighter_berserker_blood"],
		"role_required": "fighter",
		"level_required": 20,
		"required_traits": [],
		"blocked_traits": [],
		"costs": {"gold": 10000, "divine_essence": 50},
		"stat_bonuses": {"attack_percent": 0.15, "defense_percent": -0.05},
		"task_bonuses": {"combat": 0.20},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {"crit_damage_percent": 0.25},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["rage_strike"],
		"enhanced_ability_ids": {}
	}

func create_mock_tier2_spec_data() -> Dictionary:
	return {
		"id": "fighter_berserker_raging",
		"name": "Raging Warrior",
		"description": "Channel unstoppable rage for maximum damage",
		"icon_path": "res://assets/icons/specs/fighter_berserker_raging.png",
		"tier": 2,
		"parent_spec": "fighter_berserker",
		"children_specs": ["fighter_berserker_avatar"],
		"role_required": "fighter",
		"level_required": 30,
		"required_traits": ["warrior"],
		"blocked_traits": ["healer"],
		"costs": {"gold": 50000, "divine_essence": 200, "specialization_tomes": 10},
		"stat_bonuses": {"attack_percent": 0.25, "defense_percent": -0.10},
		"task_bonuses": {"combat": 0.30},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {"crit_damage_percent": 0.40},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["unstoppable_rage"],
		"enhanced_ability_ids": {"rage_strike": 2}
	}

func create_mock_tier3_spec_data() -> Dictionary:
	return {
		"id": "fighter_berserker_avatar",
		"name": "Avatar of Fury",
		"description": "Become the incarnation of pure rage",
		"icon_path": "res://assets/icons/specs/fighter_berserker_avatar.png",
		"tier": 3,
		"parent_spec": "fighter_berserker_raging",
		"children_specs": [],
		"role_required": "fighter",
		"level_required": 40,
		"required_traits": [],
		"blocked_traits": [],
		"costs": {"gold": 200000, "divine_essence": 1000, "specialization_tomes": 50, "legendary_scroll": 1},
		"stat_bonuses": {"attack_percent": 0.40, "cc_immunity": true},
		"task_bonuses": {},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["divine_wrath"],
		"enhanced_ability_ids": {"rage_strike": 3, "unstoppable_rage": 1}
	}

func create_mock_gatherer_spec_data() -> Dictionary:
	return {
		"id": "gatherer_miner",
		"name": "Miner",
		"description": "Expert at extracting ore and gems",
		"icon_path": "res://assets/icons/specs/gatherer_miner.png",
		"tier": 1,
		"parent_spec": null,
		"children_specs": ["gatherer_miner_gem", "gatherer_miner_deep"],
		"role_required": "gatherer",
		"level_required": 20,
		"required_traits": [],
		"blocked_traits": [],
		"costs": {"gold": 10000, "divine_essence": 50},
		"stat_bonuses": {"hp_percent": 0.10},
		"task_bonuses": {"mining": 0.30},
		"resource_bonuses": {"gather_yield_percent": 0.25, "rare_chance_percent": 0.10},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["efficient_mining"],
		"enhanced_ability_ids": {}
	}

# ==============================================================================
# TEST: GodSpecialization Data Class - Basic Properties
# ==============================================================================

func test_spec_from_dict_creates_spec():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_not_null(spec, "should create spec from dict")
	runner.assert_equal(spec.id, "fighter_berserker", "should have correct id")
	runner.assert_equal(spec.name, "Berserker", "should have correct name")

func test_spec_from_dict_parses_description():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.description, "Embrace primal fury and overwhelming offense", "should have correct description")

func test_spec_from_dict_parses_icon_path():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.icon_path, "res://assets/icons/specs/fighter_berserker.png", "should parse icon path")

# ==============================================================================
# TEST: GodSpecialization Data Class - Tree Structure
# ==============================================================================

func test_spec_from_dict_parses_tier():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.tier, 1, "should parse tier 1")

func test_spec_from_dict_parses_tier_2():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.tier, 2, "should parse tier 2")

func test_spec_from_dict_parses_tier_3():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.tier, 3, "should parse tier 3")

func test_spec_from_dict_parses_parent_spec():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.parent_spec, "fighter_berserker", "should parse parent spec")

func test_spec_from_dict_parses_null_parent_spec():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.parent_spec, "", "should convert null parent to empty string")

func test_spec_from_dict_parses_children_specs():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.children_specs.size(), 2, "should have 2 children")
	runner.assert_true("fighter_berserker_raging" in spec.children_specs, "should have first child")
	runner.assert_true("fighter_berserker_blood" in spec.children_specs, "should have second child")

func test_spec_from_dict_parses_empty_children():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.children_specs.size(), 0, "should have no children")

# ==============================================================================
# TEST: GodSpecialization Data Class - Tree Navigation
# ==============================================================================

func test_spec_is_root_tier1():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.is_root(), "tier 1 should be root")

func test_spec_is_root_tier2():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.is_root(), "tier 2 should not be root")

func test_spec_is_leaf_tier3():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.is_leaf(), "tier 3 with no children should be leaf")

func test_spec_is_leaf_tier1():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.is_leaf(), "tier 1 with children should not be leaf")

func test_spec_has_parent_tier2():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.has_parent(), "tier 2 should have parent")

func test_spec_has_parent_tier1():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.has_parent(), "tier 1 should not have parent")

func test_spec_has_children_tier1():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.has_children(), "tier 1 should have children")

func test_spec_has_children_tier3():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.has_children(), "tier 3 should not have children")

func test_spec_get_parent_id():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var parent_id = spec.get_parent_id()
	runner.assert_equal(parent_id, "fighter_berserker", "should return parent id")

func test_spec_get_parent_id_empty_for_root():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var parent_id = spec.get_parent_id()
	runner.assert_equal(parent_id, "", "should return empty for root")

func test_spec_get_children_ids():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var children = spec.get_children_ids()
	runner.assert_equal(children.size(), 2, "should return 2 children")
	runner.assert_true("fighter_berserker_raging" in children, "should contain first child")

func test_spec_get_children_ids_returns_copy():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var children = spec.get_children_ids()
	children.append("new_child")

	var original = spec.get_children_ids()
	runner.assert_equal(original.size(), 2, "should not modify original")

func test_spec_get_tier():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.get_tier(), 2, "should return tier 2")

# ==============================================================================
# TEST: GodSpecialization Data Class - Requirements
# ==============================================================================

func test_spec_from_dict_parses_role_required():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.role_required, "fighter", "should parse role requirement")

func test_spec_from_dict_parses_level_required():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.level_required, 20, "should parse level requirement")

func test_spec_from_dict_parses_required_traits():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.required_traits.size(), 1, "should have 1 required trait")
	runner.assert_true("warrior" in spec.required_traits, "should have warrior trait")

func test_spec_from_dict_parses_blocked_traits():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.blocked_traits.size(), 1, "should have 1 blocked trait")
	runner.assert_true("healer" in spec.blocked_traits, "should have healer blocked")

func test_spec_from_dict_parses_costs():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.costs.size(), 2, "should have 2 cost types")
	runner.assert_equal(spec.costs["gold"], 10000, "should have gold cost")
	runner.assert_equal(spec.costs["divine_essence"], 50, "should have essence cost")

func test_spec_from_dict_parses_all_cost_types():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.costs.size(), 4, "should have 4 cost types")
	runner.assert_equal(spec.costs["gold"], 200000, "should have gold")
	runner.assert_equal(spec.costs["divine_essence"], 1000, "should have essence")
	runner.assert_equal(spec.costs["specialization_tomes"], 50, "should have tomes")
	runner.assert_equal(spec.costs["legendary_scroll"], 1, "should have scroll")

func test_spec_get_level_requirement():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.get_level_requirement(), 30, "should return level requirement")

func test_spec_get_role_requirement():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.get_role_requirement(), "fighter", "should return role requirement")

func test_spec_get_unlock_costs():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var costs = spec.get_unlock_costs()
	runner.assert_equal(costs.size(), 2, "should return all costs")
	runner.assert_equal(costs["gold"], 10000, "should have correct gold")

func test_spec_get_unlock_costs_returns_copy():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var costs = spec.get_unlock_costs()
	costs["new_cost"] = 999

	var original = spec.get_unlock_costs()
	runner.assert_false(original.has("new_cost"), "should not modify original")

func test_spec_get_cost_amount():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.get_cost_amount("gold"), 10000, "should return gold cost")
	runner.assert_equal(spec.get_cost_amount("divine_essence"), 50, "should return essence cost")

func test_spec_get_cost_amount_unknown():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.get_cost_amount("unknown"), 0, "should return 0 for unknown cost")

func test_spec_has_cost_requirement_true():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.has_cost_requirement(), "should have costs")

func test_spec_has_cost_requirement_false():
	var data = create_mock_tier1_spec_data()
	data["costs"] = {}
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.has_cost_requirement(), "should not have costs")

func test_spec_meets_trait_requirements_no_requirements():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var god_traits = ["warrior", "miner"]
	runner.assert_true(spec.meets_trait_requirements(god_traits), "should meet when no requirements")

func test_spec_meets_trait_requirements_has_required():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var god_traits = ["warrior", "miner"]
	runner.assert_true(spec.meets_trait_requirements(god_traits), "should meet with required trait")

func test_spec_meets_trait_requirements_missing_required():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var god_traits = ["miner", "fisher"]
	runner.assert_false(spec.meets_trait_requirements(god_traits), "should fail without required trait")

func test_spec_meets_trait_requirements_has_blocked():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var god_traits = ["warrior", "healer"]
	runner.assert_false(spec.meets_trait_requirements(god_traits), "should fail with blocked trait")

func test_spec_meets_trait_requirements_complex():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	# Has required (warrior), no blocked traits
	var god_traits = ["warrior", "miner", "commander"]
	runner.assert_true(spec.meets_trait_requirements(god_traits), "should meet complex requirements")

# ==============================================================================
# TEST: GodSpecialization Data Class - Stat Bonuses
# ==============================================================================

func test_spec_from_dict_parses_stat_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses.size(), 2, "should have 2 stat bonuses")
	runner.assert_equal(spec.stat_bonuses["attack_percent"], 0.15, "should have attack bonus")
	runner.assert_equal(spec.stat_bonuses["defense_percent"], -0.05, "should have defense penalty")

func test_spec_from_dict_parses_boolean_stat_bonus():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.stat_bonuses.has("cc_immunity"), "should have cc_immunity")
	runner.assert_equal(spec.stat_bonuses["cc_immunity"], true, "should be true")

func test_spec_get_stat_bonus_float():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_stat_bonus("attack_percent")
	runner.assert_equal(bonus, 0.15, "should return float bonus")

func test_spec_get_stat_bonus_bool():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_stat_bonus("cc_immunity")
	runner.assert_equal(bonus, true, "should return bool bonus")

func test_spec_get_stat_bonus_unknown():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_stat_bonus("unknown_stat")
	runner.assert_equal(bonus, 0.0, "should return 0.0 for unknown")

func test_spec_get_all_stat_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_stat_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")
	runner.assert_equal(bonuses["attack_percent"], 0.15, "should have correct values")

func test_spec_get_all_stat_bonuses_returns_copy():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_stat_bonuses()
	bonuses["new_stat"] = 0.5

	var original = spec.get_all_stat_bonuses()
	runner.assert_false(original.has("new_stat"), "should not modify original")

# ==============================================================================
# TEST: GodSpecialization Data Class - Task Bonuses
# ==============================================================================

func test_spec_from_dict_parses_task_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.task_bonuses.size(), 1, "should have 1 task bonus")
	runner.assert_equal(spec.task_bonuses["combat"], 0.20, "should have combat bonus")

func test_spec_get_task_bonus():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_task_bonus("mining")
	runner.assert_equal(bonus, 0.30, "should return task bonus")

func test_spec_get_task_bonus_unknown():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_task_bonus("unknown_task")
	runner.assert_equal(bonus, 0.0, "should return 0.0 for unknown")

func test_spec_get_all_task_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_task_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")
	runner.assert_equal(bonuses["combat"], 0.20, "should have correct values")

func test_spec_get_all_task_bonuses_returns_copy():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_task_bonuses()
	bonuses["new_task"] = 0.5

	var original = spec.get_all_task_bonuses()
	runner.assert_false(original.has("new_task"), "should not modify original")

# ==============================================================================
# TEST: GodSpecialization Data Class - Resource Bonuses
# ==============================================================================

func test_spec_from_dict_parses_resource_bonuses():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.resource_bonuses.size(), 2, "should have 2 resource bonuses")
	runner.assert_equal(spec.resource_bonuses["gather_yield_percent"], 0.25, "should have yield bonus")
	runner.assert_equal(spec.resource_bonuses["rare_chance_percent"], 0.10, "should have rare chance")

func test_spec_get_resource_bonus():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_resource_bonus("gather_yield_percent")
	runner.assert_equal(bonus, 0.25, "should return resource bonus")

func test_spec_get_resource_bonus_unknown():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_resource_bonus("unknown_resource")
	runner.assert_equal(bonus, 0.0, "should return 0.0 for unknown")

func test_spec_get_all_resource_bonuses():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_resource_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")
	runner.assert_equal(bonuses["gather_yield_percent"], 0.25, "should have correct values")

func test_spec_get_all_resource_bonuses_returns_copy():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_resource_bonuses()
	bonuses["new_resource"] = 0.5

	var original = spec.get_all_resource_bonuses()
	runner.assert_false(original.has("new_resource"), "should not modify original")

# ==============================================================================
# TEST: GodSpecialization Data Class - Other Bonus Types
# ==============================================================================

func test_spec_get_crafting_bonus():
	var data = create_mock_tier1_spec_data()
	data["crafting_bonuses"] = {"quality_percent": 0.20}
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_crafting_bonus("quality_percent")
	runner.assert_equal(bonus, 0.20, "should return crafting bonus")

func test_spec_get_research_bonus():
	var data = create_mock_tier1_spec_data()
	data["research_bonuses"] = {"research_speed_percent": 0.30}
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_research_bonus("research_speed_percent")
	runner.assert_equal(bonus, 0.30, "should return research bonus")

func test_spec_get_combat_bonus():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_combat_bonus("crit_damage_percent")
	runner.assert_equal(bonus, 0.25, "should return combat bonus")

func test_spec_get_aura_bonus():
	var data = create_mock_tier1_spec_data()
	data["aura_bonuses"] = {"ally_efficiency_percent": 0.15}
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_aura_bonus("ally_efficiency_percent")
	runner.assert_equal(bonus, 0.15, "should return aura bonus")

func test_spec_get_all_crafting_bonuses():
	var data = create_mock_tier1_spec_data()
	data["crafting_bonuses"] = {"quality_percent": 0.20, "masterwork_chance": 0.05}
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_crafting_bonuses()
	runner.assert_equal(bonuses.size(), 2, "should return all bonuses")

func test_spec_get_all_research_bonuses():
	var data = create_mock_tier1_spec_data()
	data["research_bonuses"] = {"research_speed_percent": 0.30}
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_research_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")

func test_spec_get_all_combat_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_combat_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")
	runner.assert_equal(bonuses["crit_damage_percent"], 0.25, "should have correct value")

func test_spec_get_all_aura_bonuses():
	var data = create_mock_tier1_spec_data()
	data["aura_bonuses"] = {"ally_efficiency_percent": 0.15}
	var spec = GodSpecialization.from_dict(data)

	var bonuses = spec.get_all_aura_bonuses()
	runner.assert_equal(bonuses.size(), 1, "should return all bonuses")

# ==============================================================================
# TEST: GodSpecialization Data Class - Abilities
# ==============================================================================

func test_spec_from_dict_parses_unlocked_abilities():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.unlocked_ability_ids.size(), 1, "should have 1 unlocked ability")
	runner.assert_true("rage_strike" in spec.unlocked_ability_ids, "should have rage_strike")

func test_spec_from_dict_parses_enhanced_abilities():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.enhanced_ability_ids.size(), 1, "should have 1 enhanced ability")
	runner.assert_equal(spec.enhanced_ability_ids["rage_strike"], 2, "should enhance to level 2")

func test_spec_from_dict_parses_multiple_enhanced_abilities():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.enhanced_ability_ids.size(), 2, "should have 2 enhanced abilities")
	runner.assert_equal(spec.enhanced_ability_ids["rage_strike"], 3, "should enhance rage_strike to level 3")
	runner.assert_equal(spec.enhanced_ability_ids["unstoppable_rage"], 1, "should enhance unstoppable_rage to level 1")

func test_spec_get_unlocked_abilities():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var abilities = spec.get_unlocked_abilities()
	runner.assert_equal(abilities.size(), 1, "should return all abilities")
	runner.assert_true("rage_strike" in abilities, "should contain rage_strike")

func test_spec_get_unlocked_abilities_returns_copy():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var abilities = spec.get_unlocked_abilities()
	abilities.append("new_ability")

	var original = spec.get_unlocked_abilities()
	runner.assert_equal(original.size(), 1, "should not modify original")

func test_spec_get_enhanced_abilities():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var enhanced = spec.get_enhanced_abilities()
	runner.assert_equal(enhanced.size(), 1, "should return all enhanced")
	runner.assert_equal(enhanced["rage_strike"], 2, "should have correct level")

func test_spec_get_enhanced_abilities_returns_copy():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var enhanced = spec.get_enhanced_abilities()
	enhanced["new_ability"] = 5

	var original = spec.get_enhanced_abilities()
	runner.assert_false(original.has("new_ability"), "should not modify original")

func test_spec_unlocks_ability_true():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.unlocks_ability("rage_strike"), "should unlock rage_strike")

func test_spec_unlocks_ability_false():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.unlocks_ability("unknown_ability"), "should not unlock unknown")

func test_spec_enhances_ability_true():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.enhances_ability("rage_strike"), "should enhance rage_strike")

func test_spec_enhances_ability_false():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_false(spec.enhances_ability("rage_strike"), "should not enhance if not in dict")

# ==============================================================================
# TEST: GodSpecialization Data Class - Display Methods
# ==============================================================================

func test_spec_get_display_name_tier1():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var display = spec.get_display_name()
	runner.assert_equal(display, "Berserker [Tier I]", "should show tier I")

func test_spec_get_display_name_tier2():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var display = spec.get_display_name()
	runner.assert_equal(display, "Raging Warrior [Tier II]", "should show tier II")

func test_spec_get_display_name_tier3():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var display = spec.get_display_name()
	runner.assert_equal(display, "Avatar of Fury [Tier III]", "should show tier III")

func test_spec_get_tooltip_contains_name():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Berserker"), "should contain name")

func test_spec_get_tooltip_contains_description():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Embrace primal fury"), "should contain description")

func test_spec_get_tooltip_contains_requirements():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Requirements"), "should have requirements section")
	runner.assert_true(tooltip.contains("Level 20"), "should show level requirement")
	runner.assert_true(tooltip.contains("Fighter"), "should show role requirement")

func test_spec_get_tooltip_contains_parent():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Parent:"), "should have parent section")
	runner.assert_true(tooltip.contains("fighter_berserker"), "should show parent id")

func test_spec_get_tooltip_contains_costs():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Unlock Costs"), "should have costs section")
	runner.assert_true(tooltip.contains("Gold: 10000"), "should show gold cost")
	runner.assert_true(tooltip.contains("Divine Essence: 50"), "should show essence cost")

func test_spec_get_tooltip_contains_all_costs():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Specialization Tomes: 50"), "should show tomes")
	runner.assert_true(tooltip.contains("Legendary Scroll: 1"), "should show scroll")

func test_spec_get_tooltip_contains_stat_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Stat Bonuses"), "should have stat bonuses section")
	runner.assert_true(tooltip.contains("15%"), "should show attack bonus")

func test_spec_get_tooltip_contains_boolean_stat():
	var data = create_mock_tier3_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Cc Immunity"), "should show boolean stat")

func test_spec_get_tooltip_contains_task_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Task Bonuses"), "should have task bonuses section")
	runner.assert_true(tooltip.contains("Combat"), "should show combat task")

func test_spec_get_tooltip_contains_resource_bonuses():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Resource Bonuses"), "should have resource bonuses section")
	runner.assert_true(tooltip.contains("Gather Yield"), "should show gather yield")

func test_spec_get_tooltip_contains_unlocked_abilities():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Unlocked Abilities"), "should have abilities section")
	runner.assert_true(tooltip.contains("Rage Strike"), "should show rage strike")

func test_spec_get_tooltip_contains_children():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var tooltip = spec.get_tooltip()
	runner.assert_true(tooltip.contains("Advanced Specializations"), "should have children section")
	runner.assert_true(tooltip.contains("fighter_berserker_raging"), "should show children")

# ==============================================================================
# TEST: GodSpecialization Data Class - Serialization
# ==============================================================================

func test_spec_to_dict_preserves_basic_data():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["id"], data["id"], "should preserve id")
	runner.assert_equal(output["name"], data["name"], "should preserve name")
	runner.assert_equal(output["description"], data["description"], "should preserve description")
	runner.assert_equal(output["icon_path"], data["icon_path"], "should preserve icon")

func test_spec_to_dict_preserves_tree_structure():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["tier"], 2, "should preserve tier")
	runner.assert_equal(output["parent_spec"], "fighter_berserker", "should preserve parent")
	runner.assert_equal(output["children_specs"].size(), 1, "should preserve children")

func test_spec_to_dict_preserves_requirements():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["role_required"], "fighter", "should preserve role")
	runner.assert_equal(output["level_required"], 30, "should preserve level")
	runner.assert_equal(output["required_traits"].size(), 1, "should preserve required traits")
	runner.assert_equal(output["blocked_traits"].size(), 1, "should preserve blocked traits")

func test_spec_to_dict_preserves_costs():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["costs"]["gold"], 10000, "should preserve gold cost")
	runner.assert_equal(output["costs"]["divine_essence"], 50, "should preserve essence cost")

func test_spec_to_dict_preserves_stat_bonuses():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["stat_bonuses"]["attack_percent"], 0.15, "should preserve stat bonuses")

func test_spec_to_dict_preserves_all_bonus_types():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["task_bonuses"]["mining"], 0.30, "should preserve task bonuses")
	runner.assert_equal(output["resource_bonuses"]["gather_yield_percent"], 0.25, "should preserve resource bonuses")

func test_spec_to_dict_preserves_abilities():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["unlocked_ability_ids"].size(), 1, "should preserve unlocked abilities")
	runner.assert_equal(output["enhanced_ability_ids"]["rage_strike"], 2, "should preserve enhanced abilities")

func test_spec_round_trip_serialization():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)
	var output = spec.to_dict()
	var restored = GodSpecialization.from_dict(output)

	runner.assert_equal(restored.id, spec.id, "should restore id")
	runner.assert_equal(restored.name, spec.name, "should restore name")
	runner.assert_equal(restored.tier, spec.tier, "should restore tier")
	runner.assert_equal(restored.parent_spec, spec.parent_spec, "should restore parent")
	runner.assert_equal(restored.level_required, spec.level_required, "should restore level requirement")

# ==============================================================================
# TEST: GodSpecialization Data Class - Edge Cases
# ==============================================================================

func test_spec_from_dict_with_empty_bonuses():
	var data = {
		"id": "empty_spec",
		"name": "Empty",
		"tier": 1,
		"role_required": "fighter",
		"level_required": 20,
		"stat_bonuses": {},
		"task_bonuses": {},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {},
		"aura_bonuses": {},
		"unlocked_ability_ids": [],
		"enhanced_ability_ids": {}
	}
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses.size(), 0, "should handle empty stat bonuses")
	runner.assert_equal(spec.task_bonuses.size(), 0, "should handle empty task bonuses")
	runner.assert_equal(spec.unlocked_ability_ids.size(), 0, "should handle empty abilities")

func test_spec_from_dict_with_missing_fields():
	var data = {"id": "minimal", "name": "Minimal"}
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.id, "minimal", "should handle minimal data")
	runner.assert_equal(spec.tier, 1, "should default to tier 1")
	runner.assert_equal(spec.level_required, 20, "should default to level 20")

func test_spec_from_dict_with_null_parent():
	var data = create_mock_tier1_spec_data()
	data["parent_spec"] = null
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.parent_spec, "", "should convert null to empty string")
	runner.assert_true(spec.is_root(), "should be root")

func test_spec_from_dict_with_empty_arrays():
	var data = create_mock_tier1_spec_data()
	data["children_specs"] = []
	data["required_traits"] = []
	data["blocked_traits"] = []
	data["unlocked_ability_ids"] = []
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.children_specs.size(), 0, "should handle empty children")
	runner.assert_equal(spec.required_traits.size(), 0, "should handle empty required traits")
	runner.assert_equal(spec.blocked_traits.size(), 0, "should handle empty blocked traits")
	runner.assert_equal(spec.unlocked_ability_ids.size(), 0, "should handle empty abilities")

func test_spec_tier_validation_invalid():
	var data = create_mock_tier1_spec_data()
	data["tier"] = 99
	var spec = GodSpecialization.from_dict(data)

	# get_display_name handles invalid tier gracefully
	var display = spec.get_display_name()
	runner.assert_true(display.contains("?"), "should handle invalid tier")

func test_spec_meets_trait_requirements_empty_arrays():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var god_traits = []
	runner.assert_true(spec.meets_trait_requirements(god_traits), "should meet with empty god traits")

func test_spec_negative_stat_bonus():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var bonus = spec.get_stat_bonus("defense_percent")
	runner.assert_equal(bonus, -0.05, "should handle negative bonus")

func test_spec_all_bonus_getters_return_copies():
	var data = create_mock_gatherer_spec_data()
	var spec = GodSpecialization.from_dict(data)

	# Modify all returned dictionaries
	spec.get_all_stat_bonuses()["new_stat"] = 1.0
	spec.get_all_task_bonuses()["new_task"] = 1.0
	spec.get_all_resource_bonuses()["new_resource"] = 1.0
	spec.get_all_crafting_bonuses()["new_craft"] = 1.0
	spec.get_all_research_bonuses()["new_research"] = 1.0
	spec.get_all_combat_bonuses()["new_combat"] = 1.0
	spec.get_all_aura_bonuses()["new_aura"] = 1.0

	# Verify originals unchanged
	runner.assert_false(spec.stat_bonuses.has("new_stat"), "stat bonuses should be unchanged")
	runner.assert_false(spec.task_bonuses.has("new_task"), "task bonuses should be unchanged")
	runner.assert_false(spec.resource_bonuses.has("new_resource"), "resource bonuses should be unchanged")

func test_spec_children_specs_typed_array():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var children = spec.children_specs
	runner.assert_equal(typeof(children), TYPE_ARRAY, "should be an array")
	runner.assert_equal(children.size(), 2, "should have correct size")

func test_spec_required_traits_typed_array():
	var data = create_mock_tier2_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var traits = spec.required_traits
	runner.assert_equal(typeof(traits), TYPE_ARRAY, "should be an array")
	runner.assert_equal(traits.size(), 1, "should have correct size")

func test_spec_unlocked_abilities_typed_array():
	var data = create_mock_tier1_spec_data()
	var spec = GodSpecialization.from_dict(data)

	var abilities = spec.unlocked_ability_ids
	runner.assert_equal(typeof(abilities), TYPE_ARRAY, "should be an array")
	runner.assert_equal(abilities.size(), 1, "should have correct size")
