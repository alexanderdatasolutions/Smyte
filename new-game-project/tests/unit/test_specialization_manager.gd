# test_specialization_manager.gd - Unit tests for GodSpecialization and SpecializationManager
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_spec_data_tier1() -> Dictionary:
	return {
		"id": "fighter_berserker",
		"name": "Berserker",
		"description": "Embrace primal fury",
		"icon_path": "res://assets/icons/specs/berserker.png",
		"tier": 1,
		"parent_spec": null,
		"children_specs": ["fighter_berserker_raging", "fighter_berserker_blood"],
		"role_required": "fighter",
		"level_required": 20,
		"required_traits": [],
		"blocked_traits": ["pacifist"],
		"costs": {"gold": 10000, "divine_essence": 50},
		"stat_bonuses": {"attack_percent": 0.15, "defense_percent": -0.05},
		"task_bonuses": {"combat": 0.20},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {"crit_chance_percent": 0.10},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["rage_strike"],
		"enhanced_ability_ids": {}
	}

func create_mock_spec_data_tier2() -> Dictionary:
	return {
		"id": "fighter_berserker_raging",
		"name": "Raging Warrior",
		"description": "Channel unstoppable rage",
		"icon_path": "res://assets/icons/specs/raging.png",
		"tier": 2,
		"parent_spec": "fighter_berserker",
		"children_specs": ["fighter_berserker_avatar"],
		"role_required": "fighter",
		"level_required": 30,
		"required_traits": [],
		"blocked_traits": [],
		"costs": {"gold": 50000, "divine_essence": 200, "specialization_tomes": 10},
		"stat_bonuses": {"attack_percent": 0.25},
		"task_bonuses": {"combat": 0.30},
		"resource_bonuses": {},
		"crafting_bonuses": {},
		"research_bonuses": {},
		"combat_bonuses": {"crit_chance_percent": 0.15},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["unstoppable_rage"],
		"enhanced_ability_ids": {"rage_strike": 1}
	}

func create_mock_spec_data_tier3() -> Dictionary:
	return {
		"id": "fighter_berserker_avatar",
		"name": "Avatar of Fury",
		"description": "Become pure rage incarnate",
		"icon_path": "res://assets/icons/specs/avatar.png",
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
		"combat_bonuses": {"crit_chance_percent": 0.20},
		"aura_bonuses": {},
		"unlocked_ability_ids": ["divine_wrath"],
		"enhanced_ability_ids": {"rage_strike": 2, "unstoppable_rage": 1}
	}

func create_mock_god(lvl: int = 20, role: String = "fighter") -> God:
	var god = God.new()
	god.id = "god_" + str(randi() % 10000)
	god.name = "Test God"
	god.level = lvl
	# Mock role fields (will be added in P5-01)
	god.set("primary_role", role)
	god.set("trait_ids", [])
	return god

func create_test_manager() -> SpecializationManager:
	var manager = SpecializationManager.new()

	# Manually add mock specializations
	var spec1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var spec2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())
	var spec3 = GodSpecialization.from_dict(create_mock_spec_data_tier3())

	manager._specializations["fighter_berserker"] = spec1
	manager._specializations["fighter_berserker_raging"] = spec2
	manager._specializations["fighter_berserker_avatar"] = spec3
	manager._is_loaded = true

	return manager

# ==============================================================================
# TEST: GodSpecialization Data Class - Basic Properties
# ==============================================================================

func test_spec_from_dict_creates_specialization():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_not_null(spec, "should create specialization from dict")
	runner.assert_equal(spec.id, "fighter_berserker", "should have correct id")
	runner.assert_equal(spec.name, "Berserker", "should have correct name")

func test_spec_from_dict_parses_tier():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.tier, 1, "should have tier 1")

func test_spec_from_dict_parses_parent_and_children():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.parent_spec, "", "tier 1 should have no parent")
	runner.assert_equal(spec.children_specs.size(), 2, "should have 2 children")

func test_spec_from_dict_parses_requirements():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.role_required, "fighter", "should require fighter role")
	runner.assert_equal(spec.level_required, 20, "should require level 20")

func test_spec_from_dict_parses_costs():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.costs.size(), 2, "should have 2 cost types")
	runner.assert_equal(spec.costs["gold"], 10000, "should have correct gold cost")

func test_spec_from_dict_parses_bonuses():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses["attack_percent"], 0.15, "should have attack bonus")
	runner.assert_equal(spec.task_bonuses["combat"], 0.20, "should have combat bonus")

func test_spec_from_dict_parses_abilities():
	var data = create_mock_spec_data_tier1()
	var spec = GodSpecialization.from_dict(data)

	runner.assert_equal(spec.unlocked_ability_ids.size(), 1, "should have 1 unlocked ability")
	runner.assert_true("rage_strike" in spec.unlocked_ability_ids, "should unlock rage_strike")

# ==============================================================================
# TEST: GodSpecialization Data Class - Tree Navigation
# ==============================================================================

func test_spec_is_root():
	var tier1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var tier2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())

	runner.assert_true(tier1.is_root(), "tier 1 should be root")
	runner.assert_false(tier2.is_root(), "tier 2 should not be root")

func test_spec_is_leaf():
	var tier2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())
	var tier3 = GodSpecialization.from_dict(create_mock_spec_data_tier3())

	runner.assert_false(tier2.is_leaf(), "tier 2 should not be leaf")
	runner.assert_true(tier3.is_leaf(), "tier 3 should be leaf")

func test_spec_has_parent():
	var tier1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var tier2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())

	runner.assert_false(tier1.has_parent(), "tier 1 should not have parent")
	runner.assert_true(tier2.has_parent(), "tier 2 should have parent")

func test_spec_has_children():
	var tier1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var tier3 = GodSpecialization.from_dict(create_mock_spec_data_tier3())

	runner.assert_true(tier1.has_children(), "tier 1 should have children")
	runner.assert_false(tier3.has_children(), "tier 3 should not have children")

func test_spec_get_parent_id():
	var tier2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())

	runner.assert_equal(tier2.get_parent_id(), "fighter_berserker", "should return parent id")

func test_spec_get_children_ids():
	var tier1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var children = tier1.get_children_ids()

	runner.assert_equal(children.size(), 2, "should return 2 children")
	runner.assert_true("fighter_berserker_raging" in children, "should have raging child")

# ==============================================================================
# TEST: GodSpecialization Data Class - Requirements Validation
# ==============================================================================

func test_spec_get_level_requirement():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_level_requirement(), 20, "should return level requirement")

func test_spec_get_role_requirement():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_role_requirement(), "fighter", "should return role requirement")

func test_spec_get_unlock_costs():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var costs = spec.get_unlock_costs()

	runner.assert_equal(costs.size(), 2, "should return all costs")
	runner.assert_equal(costs["gold"], 10000, "should have gold cost")

func test_spec_get_cost_amount():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_cost_amount("gold"), 10000, "should return gold cost")
	runner.assert_equal(spec.get_cost_amount("mana"), 0, "should return 0 for unknown cost")

func test_spec_has_cost_requirement():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_true(spec.has_cost_requirement(), "should have cost requirements")

func test_spec_meets_trait_requirements_with_empty_requirements():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_true(spec.meets_trait_requirements([]), "should meet empty requirements")

func test_spec_meets_trait_requirements_with_blocked_trait():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_false(spec.meets_trait_requirements(["pacifist"]), "should not meet with blocked trait")

func test_spec_meets_trait_requirements_with_required_trait():
	var data = create_mock_spec_data_tier1()
	data["required_traits"] = ["warrior"]
	var spec = GodSpecialization.from_dict(data)

	runner.assert_true(spec.meets_trait_requirements(["warrior"]), "should meet with required trait")
	runner.assert_false(spec.meets_trait_requirements(["mage"]), "should not meet without required trait")

# ==============================================================================
# TEST: GodSpecialization Data Class - Bonus Getters
# ==============================================================================

func test_spec_get_stat_bonus():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_stat_bonus("attack_percent"), 0.15, "should return attack bonus")
	runner.assert_equal(spec.get_stat_bonus("unknown"), 0.0, "should return 0 for unknown")

func test_spec_get_task_bonus():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_task_bonus("combat"), 0.20, "should return combat bonus")
	runner.assert_equal(spec.get_task_bonus("mining"), 0.0, "should return 0 for unknown")

func test_spec_get_combat_bonus():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_equal(spec.get_combat_bonus("crit_chance_percent"), 0.10, "should return crit chance")

func test_spec_get_all_stat_bonuses():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var bonuses = spec.get_all_stat_bonuses()

	runner.assert_equal(bonuses.size(), 2, "should return all stat bonuses")

func test_spec_get_all_task_bonuses():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var bonuses = spec.get_all_task_bonuses()

	runner.assert_equal(bonuses.size(), 1, "should return all task bonuses")

# ==============================================================================
# TEST: GodSpecialization Data Class - Abilities
# ==============================================================================

func test_spec_get_unlocked_abilities():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var abilities = spec.get_unlocked_abilities()

	runner.assert_equal(abilities.size(), 1, "should return unlocked abilities")
	runner.assert_true("rage_strike" in abilities, "should have rage_strike")

func test_spec_get_enhanced_abilities():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier2())
	var enhanced = spec.get_enhanced_abilities()

	runner.assert_equal(enhanced.size(), 1, "should return enhanced abilities")
	runner.assert_equal(enhanced["rage_strike"], 1, "should enhance rage_strike")

func test_spec_unlocks_ability():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())

	runner.assert_true(spec.unlocks_ability("rage_strike"), "should unlock rage_strike")
	runner.assert_false(spec.unlocks_ability("unknown"), "should not unlock unknown")

func test_spec_enhances_ability():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier2())

	runner.assert_true(spec.enhances_ability("rage_strike"), "should enhance rage_strike")
	runner.assert_false(spec.enhances_ability("unknown"), "should not enhance unknown")

# ==============================================================================
# TEST: GodSpecialization Data Class - Display
# ==============================================================================

func test_spec_get_display_name():
	var tier1 = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var tier2 = GodSpecialization.from_dict(create_mock_spec_data_tier2())
	var tier3 = GodSpecialization.from_dict(create_mock_spec_data_tier3())

	runner.assert_equal(tier1.get_display_name(), "Berserker [Tier I]", "tier 1 should have Roman I")
	runner.assert_equal(tier2.get_display_name(), "Raging Warrior [Tier II]", "tier 2 should have Roman II")
	runner.assert_equal(tier3.get_display_name(), "Avatar of Fury [Tier III]", "tier 3 should have Roman III")

func test_spec_get_tooltip():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var tooltip = spec.get_tooltip()

	runner.assert_true("Berserker" in tooltip, "tooltip should contain name")
	runner.assert_true("Level 20" in tooltip, "tooltip should contain level requirement")
	runner.assert_true("fighter" in tooltip, "tooltip should contain role requirement")

# ==============================================================================
# TEST: GodSpecialization Data Class - Serialization
# ==============================================================================

func test_spec_to_dict():
	var spec = GodSpecialization.from_dict(create_mock_spec_data_tier1())
	var dict_data = spec.to_dict()

	runner.assert_equal(dict_data["id"], "fighter_berserker", "should serialize id")
	runner.assert_equal(dict_data["tier"], 1, "should serialize tier")
	runner.assert_equal(dict_data["stat_bonuses"]["attack_percent"], 0.15, "should serialize bonuses")

func test_spec_roundtrip_serialization():
	var original_data = create_mock_spec_data_tier1()
	var spec1 = GodSpecialization.from_dict(original_data)
	var dict_data = spec1.to_dict()
	var spec2 = GodSpecialization.from_dict(dict_data)

	runner.assert_equal(spec1.id, spec2.id, "id should survive roundtrip")
	runner.assert_equal(spec1.tier, spec2.tier, "tier should survive roundtrip")
	runner.assert_equal(spec1.stat_bonuses["attack_percent"], spec2.stat_bonuses["attack_percent"], "bonuses should survive roundtrip")

# ==============================================================================
# TEST: SpecializationManager - Loading
# ==============================================================================

func test_manager_get_specialization():
	var manager = create_test_manager()
	var spec = manager.get_specialization("fighter_berserker")

	runner.assert_not_null(spec, "should get specialization")
	runner.assert_equal(spec.id, "fighter_berserker", "should have correct id")

func test_manager_get_specialization_returns_null_for_unknown():
	var manager = create_test_manager()
	var spec = manager.get_specialization("unknown_spec")

	runner.assert_null(spec, "should return null for unknown")

func test_manager_get_all_specializations():
	var manager = create_test_manager()
	var all_specs = manager.get_all_specializations()

	runner.assert_equal(all_specs.size(), 3, "should return all 3 specializations")

func test_manager_is_loaded():
	var manager = create_test_manager()

	runner.assert_true(manager.is_loaded(), "should be loaded")

func test_manager_get_specialization_count():
	var manager = create_test_manager()

	runner.assert_equal(manager.get_specialization_count(), 3, "should count specializations")

# ==============================================================================
# TEST: SpecializationManager - Queries
# ==============================================================================

func test_manager_get_specializations_by_tier():
	var manager = create_test_manager()

	var tier1 = manager.get_specializations_by_tier(1)
	var tier2 = manager.get_specializations_by_tier(2)
	var tier3 = manager.get_specializations_by_tier(3)

	runner.assert_equal(tier1.size(), 1, "should have 1 tier 1 spec")
	runner.assert_equal(tier2.size(), 1, "should have 1 tier 2 spec")
	runner.assert_equal(tier3.size(), 1, "should have 1 tier 3 spec")

func test_manager_get_specializations_by_role():
	var manager = create_test_manager()
	var fighter_specs = manager.get_specializations_by_role("fighter")

	runner.assert_equal(fighter_specs.size(), 3, "should return all fighter specs")

func test_manager_get_root_specializations():
	var manager = create_test_manager()
	var roots = manager.get_root_specializations()

	runner.assert_equal(roots.size(), 1, "should return 1 root spec")

func test_manager_get_root_specializations_filtered_by_role():
	var manager = create_test_manager()
	var fighter_roots = manager.get_root_specializations("fighter")
	var gatherer_roots = manager.get_root_specializations("gatherer")

	runner.assert_equal(fighter_roots.size(), 1, "should return 1 fighter root")
	runner.assert_equal(gatherer_roots.size(), 0, "should return 0 gatherer roots")

func test_manager_get_children_specializations():
	var manager = create_test_manager()
	var children = manager.get_children_specializations("fighter_berserker")

	runner.assert_equal(children.size(), 2, "should return 2 children")

func test_manager_get_tier_count():
	var manager = create_test_manager()

	runner.assert_equal(manager.get_tier_count(1), 1, "should count tier 1 specs")

# ==============================================================================
# TEST: SpecializationManager - God Specialization Path
# ==============================================================================

func test_manager_get_god_specialization_path_empty():
	var manager = create_test_manager()
	var god = create_mock_god()
	var path = manager.get_god_specialization_path(god.id)

	runner.assert_equal(path.size(), 0, "new god should have empty path")

func test_manager_get_god_current_specialization_empty():
	var manager = create_test_manager()
	var god = create_mock_god()
	var current = manager.get_god_current_specialization(god.id)

	runner.assert_equal(current, "", "new god should have no current specialization")

func test_manager_has_specialization():
	var manager = create_test_manager()
	var god = create_mock_god()

	runner.assert_false(manager.has_specialization(god.id), "new god should not have specialization")

func test_manager_get_god_specialization_tier():
	var manager = create_test_manager()
	var god = create_mock_god()

	runner.assert_equal(manager.get_god_specialization_tier(god.id), 0, "new god should be tier 0")

# ==============================================================================
# TEST: SpecializationManager - Eligibility
# ==============================================================================

func test_manager_can_god_unlock_specialization_level_requirement():
	var manager = create_test_manager()
	var god_low = create_mock_god(10, "fighter")
	var god_ok = create_mock_god(20, "fighter")

	runner.assert_false(manager.can_god_unlock_specialization(god_low, "fighter_berserker"), "low level should not be eligible")
	runner.assert_true(manager.can_god_unlock_specialization(god_ok, "fighter_berserker"), "level 20 should be eligible")

func test_manager_can_god_unlock_specialization_role_requirement():
	var manager = create_test_manager()
	var god_fighter = create_mock_god(20, "fighter")
	var god_gatherer = create_mock_god(20, "gatherer")

	runner.assert_true(manager.can_god_unlock_specialization(god_fighter, "fighter_berserker"), "fighter should be eligible")
	runner.assert_false(manager.can_god_unlock_specialization(god_gatherer, "fighter_berserker"), "gatherer should not be eligible")

func test_manager_can_god_unlock_specialization_parent_requirement():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	# Try to unlock tier 2 without tier 1
	runner.assert_false(manager.can_god_unlock_specialization(god, "fighter_berserker_raging"), "should not unlock tier 2 without tier 1")

	# Unlock tier 1, then try tier 2
	manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_true(manager.can_god_unlock_specialization(god, "fighter_berserker_raging"), "should unlock tier 2 after tier 1")

func test_manager_get_available_specializations_for_god_tier1():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")
	var available = manager.get_available_specializations_for_god(god)

	runner.assert_equal(available.size(), 1, "should have 1 available tier 1 spec")
	runner.assert_equal(available[0].id, "fighter_berserker", "should be berserker")

func test_manager_get_available_specializations_for_god_low_level():
	var manager = create_test_manager()
	var god = create_mock_god(10, "fighter")
	var available = manager.get_available_specializations_for_god(god)

	runner.assert_equal(available.size(), 0, "low level should have no available specs")

func test_manager_get_available_specializations_for_god_tier2():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	# Unlock tier 1
	manager.unlock_specialization(god, "fighter_berserker")

	var available = manager.get_available_specializations_for_god(god)
	runner.assert_equal(available.size(), 2, "should have 2 available tier 2 specs")

func test_manager_can_god_specialize():
	var manager = create_test_manager()
	var god_low = create_mock_god(10, "fighter")
	var god_ok = create_mock_god(20, "fighter")

	runner.assert_false(manager.can_god_specialize(god_low), "low level should not be able to specialize")
	runner.assert_true(manager.can_god_specialize(god_ok), "level 20 should be able to specialize")

# ==============================================================================
# TEST: SpecializationManager - Assignment
# ==============================================================================

func test_manager_unlock_specialization_success():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	var result = manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_true(result, "should unlock specialization")

func test_manager_unlock_specialization_updates_path():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	var path = manager.get_god_specialization_path(god.id)

	runner.assert_equal(path.size(), 3, "path should have 3 slots")
	runner.assert_equal(path[0], "fighter_berserker", "tier 1 should be set")

func test_manager_unlock_specialization_emits_signal():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	var signal_emitted = false
	manager.specialization_unlocked.connect(func(_god_id, _spec_id): signal_emitted = true)

	manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_true(signal_emitted, "should emit specialization_unlocked signal")

func test_manager_unlock_specialization_tier2():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")

	var path = manager.get_god_specialization_path(god.id)
	runner.assert_equal(path[1], "fighter_berserker_raging", "tier 2 should be set")

func test_manager_unlock_specialization_fails_for_ineligible():
	var manager = create_test_manager()
	var god = create_mock_god(10, "fighter")

	var result = manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_false(result, "should fail for low level god")

func test_manager_get_god_current_specialization():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_equal(manager.get_god_current_specialization(god.id), "fighter_berserker", "should return tier 1 spec")

	manager.unlock_specialization(god, "fighter_berserker_raging")
	runner.assert_equal(manager.get_god_current_specialization(god.id), "fighter_berserker_raging", "should return tier 2 spec")

func test_manager_get_god_tier_specialization():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")

	runner.assert_equal(manager.get_god_tier_specialization(god.id, 1), "fighter_berserker", "should get tier 1")
	runner.assert_equal(manager.get_god_tier_specialization(god.id, 2), "fighter_berserker_raging", "should get tier 2")
	runner.assert_equal(manager.get_god_tier_specialization(god.id, 3), "", "should get empty for tier 3")

func test_manager_get_god_specialization_tier_counts_correctly():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	runner.assert_equal(manager.get_god_specialization_tier(god.id), 0, "should be tier 0 initially")

	manager.unlock_specialization(god, "fighter_berserker")
	runner.assert_equal(manager.get_god_specialization_tier(god.id), 1, "should be tier 1")

	manager.unlock_specialization(god, "fighter_berserker_raging")
	runner.assert_equal(manager.get_god_specialization_tier(god.id), 2, "should be tier 2")

func test_manager_reset_specialization_path():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")

	var result = manager.reset_specialization_path(god)
	runner.assert_true(result, "should reset path")
	runner.assert_equal(manager.get_god_specialization_path(god.id).size(), 0, "path should be empty")

func test_manager_reset_specialization_tier():
	var manager = create_test_manager()
	var god = create_mock_god(40, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")
	manager.unlock_specialization(god, "fighter_berserker_avatar")

	manager.reset_specialization_tier(god, 2)

	runner.assert_equal(manager.get_god_tier_specialization(god.id, 1), "fighter_berserker", "tier 1 should remain")
	runner.assert_equal(manager.get_god_tier_specialization(god.id, 2), "", "tier 2 should be reset")
	runner.assert_equal(manager.get_god_tier_specialization(god.id, 3), "", "tier 3 should be reset")

# ==============================================================================
# TEST: SpecializationManager - Bonus Calculations
# ==============================================================================

func test_manager_get_total_stat_bonuses_for_god():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	var bonuses = manager.get_total_stat_bonuses_for_god(god)

	runner.assert_equal(bonuses["attack_percent"], 0.15, "should return attack bonus")

func test_manager_get_total_stat_bonuses_stacks_tiers():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")

	var bonuses = manager.get_total_stat_bonuses_for_god(god)
	runner.assert_equal(bonuses["attack_percent"], 0.40, "should stack tier 1 (0.15) and tier 2 (0.25)")

func test_manager_get_total_task_bonuses_for_god():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	var bonuses = manager.get_total_task_bonuses_for_god(god)

	runner.assert_equal(bonuses["combat"], 0.20, "should return combat bonus")

func test_manager_get_total_combat_bonuses_for_god():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	var bonuses = manager.get_total_combat_bonuses_for_god(god)

	runner.assert_equal(bonuses["crit_chance_percent"], 0.10, "should return crit chance")

func test_manager_get_task_bonus():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	var bonus = manager.get_task_bonus(god, "combat")

	runner.assert_equal(bonus, 0.20, "should return combat bonus")

func test_manager_get_unlocked_abilities_for_god():
	var manager = create_test_manager()
	var god = create_mock_god(30, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")

	var abilities = manager.get_unlocked_abilities_for_god(god)
	runner.assert_equal(abilities.size(), 2, "should have 2 unlocked abilities")
	runner.assert_true("rage_strike" in abilities, "should have rage_strike")
	runner.assert_true("unstoppable_rage" in abilities, "should have unstoppable_rage")

func test_manager_get_enhanced_abilities_for_god():
	var manager = create_test_manager()
	var god = create_mock_god(40, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")
	manager.unlock_specialization(god, "fighter_berserker_avatar")

	var enhanced = manager.get_enhanced_abilities_for_god(god)
	runner.assert_equal(enhanced["rage_strike"], 3, "rage_strike should be enhanced 3 times (1+2)")
	runner.assert_equal(enhanced["unstoppable_rage"], 1, "unstoppable_rage should be enhanced once")

func test_manager_get_total_bonuses_empty_for_null_god():
	var manager = create_test_manager()

	var bonuses = manager.get_total_stat_bonuses_for_god(null)
	runner.assert_equal(bonuses.size(), 0, "should return empty for null god")

func test_manager_get_total_bonuses_handles_boolean_stat():
	var manager = create_test_manager()
	var god = create_mock_god(40, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")
	manager.unlock_specialization(god, "fighter_berserker_raging")
	manager.unlock_specialization(god, "fighter_berserker_avatar")

	var bonuses = manager.get_total_stat_bonuses_for_god(god)
	runner.assert_true(bonuses.get("cc_immunity", false), "should have cc_immunity from tier 3")

# ==============================================================================
# TEST: SpecializationManager - Save/Load
# ==============================================================================

func test_manager_get_save_data():
	var manager = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager.unlock_specialization(god, "fighter_berserker")

	var save_data = manager.get_save_data()
	runner.assert_true(save_data.has("god_specialization_paths"), "should have paths in save data")

func test_manager_load_save_data():
	var manager1 = create_test_manager()
	var god = create_mock_god(20, "fighter")

	manager1.unlock_specialization(god, "fighter_berserker")
	var save_data = manager1.get_save_data()

	var manager2 = create_test_manager()
	manager2.load_save_data(save_data)

	runner.assert_equal(manager2.get_god_current_specialization(god.id), "fighter_berserker", "should restore specialization")
