# test_tasks.gd - Unit tests for Task data class
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_task_data() -> Dictionary:
	return {
		"id": "test_task",
		"name": "Test Task",
		"description": "A task for testing",
		"category": "gathering",
		"rarity": "common",
		"required_territory_level": 1,
		"required_building_id": "basic_mine",
		"required_god_level": 5,
		"required_traits": [],
		"blocked_traits": [],
		"base_duration_seconds": 3600,
		"base_experience": 100,
		"repeatable": true,
		"max_concurrent_workers": 2,
		"resource_rewards": {"copper_ore": 10, "iron_ore": 5},
		"item_rewards": [{"id": "gem", "chance": 0.1, "min": 1, "max": 2}],
		"experience_rewards": {"god_xp": 50, "territory_xp": 20},
		"skill_id": "mining",
		"skill_xp_reward": 30,
		"skill_level_required": 10,
		"skill_level_bonus_cap": 50,
		"icon_path": "res://assets/icons/tasks/test.png",
		"animation_id": "mining"
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
# TEST: Task Data Class - Basic Properties
# ==============================================================================

func test_task_from_dict_creates_task():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_not_null(task, "should create task from dict")
	runner.assert_equal(task.id, "test_task", "should have correct id")
	runner.assert_equal(task.name, "Test Task", "should have correct name")

func test_task_from_dict_parses_category():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.category, Task.TaskCategory.GATHERING, "should parse gathering category")

func test_task_from_dict_parses_rarity():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.rarity, Task.TaskRarity.COMMON, "should parse common rarity")

func test_task_from_dict_parses_requirements():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.required_territory_level, 1, "should parse territory level")
	runner.assert_equal(task.required_building_id, "basic_mine", "should parse building id")
	runner.assert_equal(task.required_god_level, 5, "should parse god level")

func test_task_from_dict_parses_mechanics():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.base_duration_seconds, 3600, "should parse duration")
	runner.assert_equal(task.base_experience, 100, "should parse experience")
	runner.assert_true(task.repeatable, "should parse repeatable")
	runner.assert_equal(task.max_concurrent_workers, 2, "should parse max workers")

func test_task_from_dict_parses_rewards():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.resource_rewards.size(), 2, "should have 2 resource rewards")
	runner.assert_equal(task.resource_rewards["copper_ore"], 10, "should parse copper reward")
	runner.assert_equal(task.item_rewards.size(), 1, "should have 1 item reward")

func test_task_from_dict_parses_skill_data():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.skill_id, "mining", "should parse skill id")
	runner.assert_equal(task.skill_xp_reward, 30, "should parse skill xp")
	runner.assert_equal(task.skill_level_required, 10, "should parse skill level required")

# ==============================================================================
# TEST: Task Data Class - Category Parsing
# ==============================================================================

func test_task_parses_gathering_category():
	var data = create_mock_task_data()
	data["category"] = "gathering"
	var task = Task.from_dict(data)
	runner.assert_equal(task.category, Task.TaskCategory.GATHERING, "should parse gathering")

func test_task_parses_crafting_category():
	var data = create_mock_task_data()
	data["category"] = "crafting"
	var task = Task.from_dict(data)
	runner.assert_equal(task.category, Task.TaskCategory.CRAFTING, "should parse crafting")

func test_task_parses_research_category():
	var data = create_mock_task_data()
	data["category"] = "research"
	var task = Task.from_dict(data)
	runner.assert_equal(task.category, Task.TaskCategory.RESEARCH, "should parse research")

func test_task_parses_defense_category():
	var data = create_mock_task_data()
	data["category"] = "defense"
	var task = Task.from_dict(data)
	runner.assert_equal(task.category, Task.TaskCategory.DEFENSE, "should parse defense")

func test_task_parses_special_category():
	var data = create_mock_task_data()
	data["category"] = "special"
	var task = Task.from_dict(data)
	runner.assert_equal(task.category, Task.TaskCategory.SPECIAL, "should parse special")

# ==============================================================================
# TEST: Task Data Class - Rarity Parsing
# ==============================================================================

func test_task_parses_common_rarity():
	var data = create_mock_task_data()
	data["rarity"] = "common"
	var task = Task.from_dict(data)
	runner.assert_equal(task.rarity, Task.TaskRarity.COMMON, "should parse common")

func test_task_parses_uncommon_rarity():
	var data = create_mock_task_data()
	data["rarity"] = "uncommon"
	var task = Task.from_dict(data)
	runner.assert_equal(task.rarity, Task.TaskRarity.UNCOMMON, "should parse uncommon")

func test_task_parses_rare_rarity():
	var data = create_mock_task_data()
	data["rarity"] = "rare"
	var task = Task.from_dict(data)
	runner.assert_equal(task.rarity, Task.TaskRarity.RARE, "should parse rare")

func test_task_parses_epic_rarity():
	var data = create_mock_task_data()
	data["rarity"] = "epic"
	var task = Task.from_dict(data)
	runner.assert_equal(task.rarity, Task.TaskRarity.EPIC, "should parse epic")

func test_task_parses_legendary_rarity():
	var data = create_mock_task_data()
	data["rarity"] = "legendary"
	var task = Task.from_dict(data)
	runner.assert_equal(task.rarity, Task.TaskRarity.LEGENDARY, "should parse legendary")

# ==============================================================================
# TEST: Task Data Class - Duration Calculation
# ==============================================================================

func test_task_get_duration_base():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	var duration = task.get_duration_for_god(null, 0.0, 0)
	runner.assert_equal(duration, 3600, "should return base duration with no bonuses")

func test_task_get_duration_with_trait_bonus():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	var duration = task.get_duration_for_god(null, 0.2, 0)
	runner.assert_equal(duration, 2880, "should reduce duration by 20%")

func test_task_get_duration_trait_bonus_capped():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	var duration = task.get_duration_for_god(null, 0.8, 0)  # Would be 80% but capped at 50%
	runner.assert_equal(duration, 1800, "should cap reduction at 50%")

func test_task_get_duration_with_skill_bonus():
	var data = create_mock_task_data()
	data["skill_level_required"] = 10
	var task = Task.from_dict(data)

	# 20 levels above requirement = 20% reduction (capped at 30%)
	var duration = task.get_duration_for_god(null, 0.0, 30)
	runner.assert_equal(duration, 2880, "should reduce by skill level")

func test_task_get_duration_with_both_bonuses():
	var data = create_mock_task_data()
	data["skill_level_required"] = 10
	var task = Task.from_dict(data)

	# 20% trait + 20% skill (multiplicative)
	var duration = task.get_duration_for_god(null, 0.2, 30)
	runner.assert_true(duration < 2880, "should stack both bonuses")

# ==============================================================================
# TEST: Task Data Class - Reward Calculation
# ==============================================================================

func test_task_get_rewards_base():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	var rewards = task.get_rewards_for_god(null, 0.0, 0)
	runner.assert_equal(rewards["copper_ore"], 10, "should return base copper")
	runner.assert_equal(rewards["iron_ore"], 5, "should return base iron")

func test_task_get_rewards_with_trait_bonus():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	var rewards = task.get_rewards_for_god(null, 0.5, 0)  # 50% bonus
	runner.assert_equal(rewards["copper_ore"], 15, "should increase copper by 50%")
	runner.assert_equal(rewards["iron_ore"], 7, "should increase iron by 50%")

func test_task_get_rewards_with_skill_bonus():
	var data = create_mock_task_data()
	data["skill_level_required"] = 10
	var task = Task.from_dict(data)

	# 25 levels above = 50% bonus (capped)
	var rewards = task.get_rewards_for_god(null, 0.0, 35)
	runner.assert_equal(rewards["copper_ore"], 15, "should increase by skill bonus")

# ==============================================================================
# TEST: Task Data Class - God Eligibility
# ==============================================================================

func test_task_can_god_perform_with_null():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_false(task.can_god_perform(null), "should return false for null god")

func test_task_can_god_perform_level_requirement():
	var data = create_mock_task_data()
	data["required_god_level"] = 10
	var task = Task.from_dict(data)

	var god_low = create_mock_god()
	god_low.level = 5

	var god_high = create_mock_god()
	god_high.level = 15

	runner.assert_false(task.can_god_perform(god_low), "should reject low level god")
	runner.assert_true(task.can_god_perform(god_high), "should accept high level god")

func test_task_can_god_perform_blocked_trait():
	var data = create_mock_task_data()
	data["blocked_traits"] = ["cursed"]
	var task = Task.from_dict(data)

	var god = create_mock_god()
	god.level = 10
	god.innate_traits = ["cursed"]

	runner.assert_false(task.can_god_perform(god), "should reject god with blocked trait")

func test_task_can_god_perform_required_trait():
	var data = create_mock_task_data()
	data["required_traits"] = ["miner", "harvester"]
	var task = Task.from_dict(data)

	var god_without = create_mock_god()
	god_without.level = 10

	var god_with = create_mock_god()
	god_with.level = 10
	god_with.innate_traits = ["miner"]

	runner.assert_false(task.can_god_perform(god_without), "should reject without required trait")
	runner.assert_true(task.can_god_perform(god_with), "should accept with required trait")

func test_task_can_god_perform_any_required_trait():
	var data = create_mock_task_data()
	data["required_traits"] = ["miner", "harvester", "hunter"]
	var task = Task.from_dict(data)

	var god = create_mock_god()
	god.level = 10
	god.learned_traits = ["hunter"]

	runner.assert_true(task.can_god_perform(god), "should accept with any required trait")

func test_task_can_god_perform_meets_all():
	var data = create_mock_task_data()
	data["required_god_level"] = 5
	data["required_traits"] = []
	data["blocked_traits"] = []
	var task = Task.from_dict(data)

	var god = create_mock_god()
	god.level = 10

	runner.assert_true(task.can_god_perform(god), "should accept eligible god")

# ==============================================================================
# TEST: Task Data Class - String Conversions
# ==============================================================================

func test_task_get_category_string():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.get_category_string(), "gathering", "should return gathering")

func test_task_get_rarity_string():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)

	runner.assert_equal(task.get_rarity_string(), "common", "should return common")

# ==============================================================================
# TEST: Task Data Class - Serialization
# ==============================================================================

func test_task_to_dict_preserves_data():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)
	var output = task.to_dict()

	runner.assert_equal(output["id"], data["id"], "should preserve id")
	runner.assert_equal(output["name"], data["name"], "should preserve name")
	runner.assert_equal(output["base_duration_seconds"], data["base_duration_seconds"], "should preserve duration")

func test_task_to_dict_converts_enums():
	var data = create_mock_task_data()
	var task = Task.from_dict(data)
	var output = task.to_dict()

	runner.assert_equal(output["category"], "gathering", "should convert category")
	runner.assert_equal(output["rarity"], "common", "should convert rarity")

func test_task_roundtrip_serialization():
	var data = create_mock_task_data()
	var task1 = Task.from_dict(data)
	var output = task1.to_dict()
	var task2 = Task.from_dict(output)

	runner.assert_equal(task1.id, task2.id, "should roundtrip id")
	runner.assert_equal(task1.base_duration_seconds, task2.base_duration_seconds, "should roundtrip duration")
	runner.assert_equal(task1.resource_rewards.size(), task2.resource_rewards.size(), "should roundtrip rewards")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_task_from_dict_with_minimal_data():
	var data = {"id": "minimal"}
	var task = Task.from_dict(data)

	runner.assert_equal(task.id, "minimal", "should handle minimal data")
	runner.assert_equal(task.base_duration_seconds, 3600, "should default duration")

func test_task_from_dict_with_empty_rewards():
	var data = create_mock_task_data()
	data["resource_rewards"] = {}
	data["item_rewards"] = []
	var task = Task.from_dict(data)

	runner.assert_equal(task.resource_rewards.size(), 0, "should handle empty rewards")
	runner.assert_equal(task.item_rewards.size(), 0, "should handle empty items")

func test_task_with_non_repeatable():
	var data = create_mock_task_data()
	data["repeatable"] = false
	var task = Task.from_dict(data)

	runner.assert_false(task.repeatable, "should parse non-repeatable")
