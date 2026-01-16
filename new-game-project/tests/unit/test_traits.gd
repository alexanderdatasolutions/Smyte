# test_traits.gd - Unit tests for Trait data class and TraitManager
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_trait_data() -> Dictionary:
	return {
		"id": "test_trait",
		"name": "Test Trait",
		"description": "A trait for testing",
		"category": "production",
		"rarity": "rare",
		"task_bonuses": {"mine_ore": 0.5, "forge_equipment": 0.3},
		"combat_stat_bonuses": {"attack": 0.1, "defense": 0.05},
		"allows_multitask": false,
		"multitask_count": 1,
		"multitask_efficiency": 1.0,
		"icon_path": "res://assets/icons/traits/test.png"
	}

func create_mock_multitask_trait_data() -> Dictionary:
	return {
		"id": "multitasker",
		"name": "Multitasker",
		"description": "Can work on multiple tasks",
		"category": "special",
		"rarity": "rare",
		"task_bonuses": {},
		"combat_stat_bonuses": {},
		"allows_multitask": true,
		"multitask_count": 2,
		"multitask_efficiency": 0.75,
		"icon_path": "res://assets/icons/traits/multitasker.png"
	}

func create_mock_god() -> God:
	var god = God.new()
	god.id = "god_" + str(randi() % 10000)
	god.name = "Test God"
	god.level = 10
	god.innate_traits = []
	god.learned_traits = []
	return god

# ==============================================================================
# TEST: Trait Data Class - Basic Properties
# ==============================================================================

func test_trait_from_dict_creates_trait():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_not_null(god_trait, "should create trait from dict")
	runner.assert_equal(god_trait.id, "test_trait", "should have correct id")
	runner.assert_equal(god_trait.name, "Test Trait", "should have correct name")

func test_trait_from_dict_parses_category():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.PRODUCTION, "should parse production category")

func test_trait_from_dict_parses_rarity():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.rarity, GodTrait.TraitRarity.RARE, "should parse rare rarity")

func test_trait_from_dict_parses_task_bonuses():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.task_bonuses.size(), 2, "should have 2 task bonuses")
	runner.assert_equal(god_trait.task_bonuses["mine_ore"], 0.5, "should have correct mine_ore bonus")

func test_trait_from_dict_parses_combat_bonuses():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.combat_stat_bonuses.size(), 2, "should have 2 combat bonuses")
	runner.assert_equal(god_trait.combat_stat_bonuses["attack"], 0.1, "should have correct attack bonus")

# ==============================================================================
# TEST: Trait Data Class - Task Bonuses
# ==============================================================================

func test_trait_get_task_bonus_returns_bonus():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	var bonus = god_trait.get_task_bonus("mine_ore")
	runner.assert_equal(bonus, 0.5, "should return correct bonus")

func test_trait_get_task_bonus_returns_zero_for_unknown():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	var bonus = god_trait.get_task_bonus("unknown_task")
	runner.assert_equal(bonus, 0.0, "should return 0 for unknown task")

func test_trait_get_task_bonus_with_all_bonus():
	var data = create_mock_trait_data()
	data["task_bonuses"]["all"] = 0.1
	var god_trait = GodTrait.from_dict(data)

	var bonus = god_trait.get_task_bonus("any_task")
	runner.assert_equal(bonus, 0.1, "should return 'all' bonus for any task")

func test_trait_get_task_bonus_combines_specific_and_all():
	var data = create_mock_trait_data()
	data["task_bonuses"]["all"] = 0.1
	var god_trait = GodTrait.from_dict(data)

	var bonus = god_trait.get_task_bonus("mine_ore")
	runner.assert_equal(bonus, 0.6, "should combine specific (0.5) and all (0.1) bonuses")

# ==============================================================================
# TEST: Trait Data Class - Multitask
# ==============================================================================

func test_trait_can_multitask_false_by_default():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_false(god_trait.can_multitask(), "default trait should not multitask")

func test_trait_can_multitask_true_when_enabled():
	var data = create_mock_multitask_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_true(god_trait.can_multitask(), "multitask trait should multitask")

func test_trait_multitask_count():
	var data = create_mock_multitask_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.multitask_count, 2, "should have count of 2")

func test_trait_multitask_efficiency():
	var data = create_mock_multitask_trait_data()
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.multitask_efficiency, 0.75, "should have 75% efficiency")

# ==============================================================================
# TEST: Trait Data Class - Category Parsing
# ==============================================================================

func test_trait_parses_production_category():
	var data = create_mock_trait_data()
	data["category"] = "production"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.PRODUCTION, "should parse production")

func test_trait_parses_crafting_category():
	var data = create_mock_trait_data()
	data["category"] = "crafting"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.CRAFTING, "should parse crafting")

func test_trait_parses_knowledge_category():
	var data = create_mock_trait_data()
	data["category"] = "knowledge"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.KNOWLEDGE, "should parse knowledge")

func test_trait_parses_combat_category():
	var data = create_mock_trait_data()
	data["category"] = "combat"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.COMBAT, "should parse combat")

func test_trait_parses_leadership_category():
	var data = create_mock_trait_data()
	data["category"] = "leadership"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.LEADERSHIP, "should parse leadership")

func test_trait_parses_special_category():
	var data = create_mock_trait_data()
	data["category"] = "special"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.category, GodTrait.TraitCategory.SPECIAL, "should parse special")

# ==============================================================================
# TEST: Trait Data Class - Rarity Parsing
# ==============================================================================

func test_trait_parses_common_rarity():
	var data = create_mock_trait_data()
	data["rarity"] = "common"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.rarity, GodTrait.TraitRarity.COMMON, "should parse common")

func test_trait_parses_rare_rarity():
	var data = create_mock_trait_data()
	data["rarity"] = "rare"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.rarity, GodTrait.TraitRarity.RARE, "should parse rare")

func test_trait_parses_epic_rarity():
	var data = create_mock_trait_data()
	data["rarity"] = "epic"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.rarity, GodTrait.TraitRarity.EPIC, "should parse epic")

func test_trait_parses_legendary_rarity():
	var data = create_mock_trait_data()
	data["rarity"] = "legendary"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.rarity, GodTrait.TraitRarity.LEGENDARY, "should parse legendary")

# ==============================================================================
# TEST: Trait Data Class - Serialization
# ==============================================================================

func test_trait_to_dict_preserves_data():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)
	var output = god_trait.to_dict()

	runner.assert_equal(output["id"], data["id"], "should preserve id")
	runner.assert_equal(output["name"], data["name"], "should preserve name")
	runner.assert_equal(output["description"], data["description"], "should preserve description")

func test_trait_to_dict_converts_enums_to_strings():
	var data = create_mock_trait_data()
	var god_trait = GodTrait.from_dict(data)
	var output = god_trait.to_dict()

	runner.assert_equal(output["category"], "production", "should convert category to string")
	runner.assert_equal(output["rarity"], "rare", "should convert rarity to string")

# ==============================================================================
# TEST: God Trait Methods
# ==============================================================================

func test_god_has_trait_innate():
	var god = create_mock_god()
	god.innate_traits = ["miner", "warrior"]

	runner.assert_true(god.has_trait("miner"), "should have innate trait")
	runner.assert_true(god.has_trait("warrior"), "should have innate trait")

func test_god_has_trait_learned():
	var god = create_mock_god()
	god.learned_traits = ["forgemaster"]

	runner.assert_true(god.has_trait("forgemaster"), "should have learned trait")

func test_god_has_trait_false_when_missing():
	var god = create_mock_god()
	god.innate_traits = ["miner"]

	runner.assert_false(god.has_trait("warrior"), "should not have missing trait")

func test_god_get_all_traits():
	var god = create_mock_god()
	god.innate_traits = ["miner", "warrior"]
	god.learned_traits = ["forgemaster"]

	var all_traits = god.get_all_traits()
	runner.assert_equal(all_traits.size(), 3, "should have 3 total traits")

func test_god_get_trait_count():
	var god = create_mock_god()
	god.innate_traits = ["miner"]
	god.learned_traits = ["forgemaster", "alchemist"]

	runner.assert_equal(god.get_trait_count(), 3, "should count all traits")

# ==============================================================================
# TEST: God Task Methods
# ==============================================================================

func test_god_is_working_on_task_false_when_empty():
	var god = create_mock_god()
	god.current_tasks = []

	runner.assert_false(god.is_working_on_task(), "should not be working with no tasks")

func test_god_is_working_on_task_true():
	var god = create_mock_god()
	god.current_tasks = ["mine_ore"]

	runner.assert_true(god.is_working_on_task(), "should be working with task")

func test_god_get_current_task_count():
	var god = create_mock_god()
	god.current_tasks = ["mine_ore", "forge_equipment"]

	runner.assert_equal(god.get_current_task_count(), 2, "should count tasks")

func test_god_is_assigned_to_task():
	var god = create_mock_god()
	god.current_tasks = ["mine_ore"]

	runner.assert_true(god.is_assigned_to_task("mine_ore"), "should be assigned")
	runner.assert_false(god.is_assigned_to_task("fish"), "should not be assigned")

func test_god_can_be_assigned_to_battle_when_not_working():
	var god = create_mock_god()
	god.current_tasks = []

	runner.assert_true(god.can_be_assigned_to_battle(), "should be able to battle")

func test_god_cannot_be_assigned_to_battle_when_working():
	var god = create_mock_god()
	god.current_tasks = ["mine_ore"]

	runner.assert_false(god.can_be_assigned_to_battle(), "should not battle while working")

# ==============================================================================
# TEST: Trait Category String Conversions
# ==============================================================================

func test_trait_get_category_string_production():
	var data = create_mock_trait_data()
	data["category"] = "production"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.get_category_string(), "production", "should return production")

func test_trait_get_category_string_combat():
	var data = create_mock_trait_data()
	data["category"] = "combat"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.get_category_string(), "combat", "should return combat")

func test_trait_get_rarity_string_common():
	var data = create_mock_trait_data()
	data["rarity"] = "common"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.get_rarity_string(), "common", "should return common")

func test_trait_get_rarity_string_legendary():
	var data = create_mock_trait_data()
	data["rarity"] = "legendary"
	var god_trait = GodTrait.from_dict(data)
	runner.assert_equal(god_trait.get_rarity_string(), "legendary", "should return legendary")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_trait_from_dict_with_empty_bonuses():
	var data = {
		"id": "empty_trait",
		"name": "Empty",
		"task_bonuses": {},
		"combat_stat_bonuses": {}
	}
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.task_bonuses.size(), 0, "should handle empty task bonuses")
	runner.assert_equal(god_trait.combat_stat_bonuses.size(), 0, "should handle empty combat bonuses")

func test_trait_from_dict_with_missing_fields():
	var data = {"id": "minimal"}
	var god_trait = GodTrait.from_dict(data)

	runner.assert_equal(god_trait.id, "minimal", "should handle minimal data")
	runner.assert_equal(god_trait.name, "", "should default name to empty")

func test_god_with_no_traits():
	var god = create_mock_god()

	runner.assert_equal(god.get_trait_count(), 0, "should have 0 traits")
	runner.assert_false(god.has_trait("anything"), "should not have any traits")
