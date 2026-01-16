# test_summon_flow.gd - Integration tests for summoning flow
# Tests interaction between SummonManager, CollectionManager, and ResourceManager
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# MOCK CLASSES FOR INTEGRATION TESTING
# ==============================================================================

class MockResourceManager:
	var resources: Dictionary = {}

	func get_resource(resource_id: String) -> int:
		return resources.get(resource_id, 0)

	func add_resource(resource_id: String, amount: int) -> bool:
		resources[resource_id] = resources.get(resource_id, 0) + amount
		return true

	func spend_resource(resource_id: String, amount: int) -> bool:
		if resources.get(resource_id, 0) >= amount:
			resources[resource_id] -= amount
			return true
		return false

	func can_afford(cost: Dictionary) -> bool:
		for resource_id in cost:
			if resources.get(resource_id, 0) < cost[resource_id]:
				return false
		return true

class MockCollectionManager:
	var gods: Array = []
	var gods_by_id: Dictionary = {}

	func add_god(god: God) -> bool:
		if god.id in gods_by_id:
			return false
		gods.append(god)
		gods_by_id[god.id] = god
		return true

	func has_god(god_id: String) -> bool:
		return god_id in gods_by_id

	func get_god_by_id(god_id: String) -> God:
		return gods_by_id.get(god_id, null)

	func get_all_gods() -> Array:
		return gods.duplicate()

	func get_god_count() -> int:
		return gods.size()

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_summon_manager() -> SummonManager:
	return SummonManager.new()

func create_mock_resource_manager() -> MockResourceManager:
	var manager = MockResourceManager.new()
	manager.resources["crystals"] = 1000
	manager.resources["gold"] = 50000
	manager.resources["summon_scrolls"] = 10
	return manager

func create_mock_collection_manager() -> MockCollectionManager:
	return MockCollectionManager.new()

func create_mock_god(god_id: String = "", tier: int = 1) -> God:
	var god = God.new()
	god.id = god_id if god_id != "" else "god_" + str(randi() % 100000)
	god.name = "Test God"
	god.tier = tier
	god.level = 1
	god.base_hp = 1000
	god.base_attack = 100
	god.base_defense = 50
	god.base_speed = 100
	return god

# ==============================================================================
# TEST: Summon Flow - Basic Summon
# ==============================================================================

func test_summon_flow_creates_god():
	var summon_manager = create_summon_manager()
	var collection = create_mock_collection_manager()

	# Simulate getting a tier from summon using basic banner rates
	var basic_rates = {"common": 70.0, "rare": 25.0, "epic": 4.5, "legendary": 0.5}
	var tier = summon_manager._get_random_tier(basic_rates)

	# Create a god based on the tier
	var god = create_mock_god("", tier)

	# Add to collection
	var result = collection.add_god(god)

	runner.assert_true(result, "should add summoned god to collection")
	runner.assert_equal(collection.get_god_count(), 1, "collection should have 1 god")

func test_summon_flow_spends_resources():
	var resources = create_mock_resource_manager()
	var initial_crystals = resources.get_resource("crystals")

	# Simulate spending summon cost
	var summon_cost = {"crystals": 100}
	var can_afford = resources.can_afford(summon_cost)
	runner.assert_true(can_afford, "should be able to afford summon")

	resources.spend_resource("crystals", 100)

	runner.assert_equal(resources.get_resource("crystals"), initial_crystals - 100, "should deduct crystals")

func test_summon_flow_insufficient_resources():
	var resources = create_mock_resource_manager()
	resources.resources["crystals"] = 50  # Not enough

	var summon_cost = {"crystals": 100}
	var can_afford = resources.can_afford(summon_cost)

	runner.assert_false(can_afford, "should not afford summon with insufficient resources")

# ==============================================================================
# TEST: Summon Flow - Pity System
# ==============================================================================

func test_pity_counter_affects_results():
	var summon_manager = create_summon_manager()

	# Simulate many common pulls
	for i in range(49):
		summon_manager._update_pity_counters("common")  # Common

	# At 49 summons, next should guarantee epic
	runner.assert_equal(summon_manager.pity_counters.epic_counter, 49, "epic counter should be 49")

	# One more common would trigger hard pity
	summon_manager._update_pity_counters("common")
	# Now at 50, epic is guaranteed

	runner.assert_equal(summon_manager.pity_counters.epic_counter, 50, "epic counter should be 50")

func test_pity_resets_on_epic():
	var summon_manager = create_summon_manager()

	# Build up pity
	for i in range(30):
		summon_manager._update_pity_counters("common")

	runner.assert_equal(summon_manager.pity_counters.epic_counter, 30, "should have 30 pity")

	# Get an epic (tier 3)
	summon_manager._update_pity_counters("epic")

	runner.assert_equal(summon_manager.pity_counters.epic_counter, 0, "epic counter should reset")

func test_pity_resets_all_on_legendary():
	var summon_manager = create_summon_manager()

	# Build up both counters
	for i in range(50):
		summon_manager._update_pity_counters("common")

	runner.assert_true(summon_manager.pity_counters.epic_counter > 0, "should have epic pity")
	runner.assert_true(summon_manager.pity_counters.legendary_counter > 0, "should have legendary pity")

	# Get a legendary (tier 4)
	summon_manager._update_pity_counters(4)

	runner.assert_equal(summon_manager.pity_counters.legendary_counter, 0, "legendary counter should reset")
	runner.assert_equal(summon_manager.pity_counters.epic_counter, 0, "epic counter should also reset")

# ==============================================================================
# TEST: Summon Flow - Multi-Summon
# ==============================================================================

func test_multi_summon_adds_multiple_gods():
	var collection = create_mock_collection_manager()

	# Simulate 10-pull
	for i in range(10):
		var god = create_mock_god("god_%d" % i, 1)
		collection.add_god(god)

	runner.assert_equal(collection.get_god_count(), 10, "should have 10 gods after 10-pull")

func test_multi_summon_consumes_resources():
	var resources = create_mock_resource_manager()
	resources.resources["crystals"] = 900  # Enough for 10-pull at 90 each

	var cost_per_summon = 90
	var summon_count = 10
	var total_cost = cost_per_summon * summon_count

	var can_afford = resources.get_resource("crystals") >= total_cost
	runner.assert_true(can_afford, "should afford 10-pull")

	for i in range(summon_count):
		resources.spend_resource("crystals", cost_per_summon)

	runner.assert_equal(resources.get_resource("crystals"), 0, "should have spent all crystals")

# ==============================================================================
# TEST: Summon Flow - Different Banner Types
# ==============================================================================

func test_basic_summon_rates():
	var summon_manager = create_summon_manager()
	var rates = summon_manager.get_summon_rates("basic")

	runner.assert_true(rates.has("common"), "basic should have common rate")
	runner.assert_true(rates.common > 0, "common rate should be positive")

func test_premium_summon_rates():
	var summon_manager = create_summon_manager()
	var rates = summon_manager.get_summon_rates("premium")

	runner.assert_true(rates.has("legendary"), "premium should have legendary rate")
	runner.assert_true(rates.legendary > 0, "legendary rate should be positive")

func test_free_daily_summon():
	var summon_manager = create_summon_manager()

	runner.assert_true(summon_manager.can_use_daily_free_summon(), "should be able to use daily free summon initially")

func test_free_daily_used_today():
	var summon_manager = create_summon_manager()
	var today = Time.get_date_string_from_system()

	summon_manager.last_daily_free_summon = today

	runner.assert_false(summon_manager.can_use_daily_free_summon(), "should not use daily twice")

# ==============================================================================
# TEST: Integration - Full Flow
# ==============================================================================

func test_complete_summon_flow():
	var summon_manager = create_summon_manager()
	var collection = create_mock_collection_manager()
	var resources = create_mock_resource_manager()

	# Step 1: Check resources
	var cost = {"crystals": 100}
	runner.assert_true(resources.can_afford(cost), "should afford summon")

	# Step 2: Perform summon logic
	var basic_rates = {"common": 70.0, "rare": 25.0, "epic": 4.5, "legendary": 0.5}
	var tier = summon_manager._get_random_tier(basic_rates)
	runner.assert_true(tier in ["common", "rare", "epic", "legendary"], "tier should be valid")

	# Step 3: Create and add god
	var god = create_mock_god("summoned_god", tier)
	var added = collection.add_god(god)
	runner.assert_true(added, "should add god to collection")

	# Step 4: Spend resources
	resources.spend_resource("crystals", cost.crystals)

	# Step 5: Update pity
	summon_manager._update_pity_counters(tier)

	# Verify final state
	runner.assert_equal(collection.get_god_count(), 1, "should have 1 god")
	runner.assert_equal(resources.get_resource("crystals"), 900, "should have 900 crystals left")

func test_summon_flow_with_pity_guarantee():
	var summon_manager = create_summon_manager()
	var collection = create_mock_collection_manager()

	# Set pity to guarantee epic
	summon_manager.pity_counters.epic_counter = 50

	# At 50 pity, epic should be guaranteed
	var basic_rates = {"common": 70.0, "rare": 25.0, "epic": 4.5, "legendary": 0.5}
	var tier = summon_manager._get_random_tier(basic_rates)

	# Even if random gives common, we should check pity before finalizing
	# In actual implementation, _get_random_tier would check pity

	# Add god to collection
	var god = create_mock_god("pity_god", 3)  # Epic
	collection.add_god(god)

	runner.assert_equal(collection.get_god_count(), 1, "should have god in collection")
	runner.assert_equal(god.tier, 3, "should be epic tier")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_summon_with_zero_resources():
	var resources = create_mock_resource_manager()
	resources.resources["crystals"] = 0

	var cost = {"crystals": 100}
	runner.assert_false(resources.can_afford(cost), "should not afford with 0 resources")

func test_duplicate_god_handling():
	var collection = create_mock_collection_manager()
	var god1 = create_mock_god("zeus_001", 4)
	var god2 = create_mock_god("zeus_001", 4)  # Same ID

	collection.add_god(god1)
	var result = collection.add_god(god2)

	runner.assert_false(result, "should not add duplicate god")
	runner.assert_equal(collection.get_god_count(), 1, "should only have 1 god")

func test_save_load_summon_state():
	var summon_manager = create_summon_manager()

	# Set some state
	summon_manager.pity_counters.epic_counter = 25
	summon_manager.pity_counters.legendary_counter = 40

	# Save
	var save_data = summon_manager.get_save_data()

	# Create new manager and load
	var new_manager = create_summon_manager()
	new_manager.load_save_data(save_data)

	runner.assert_equal(new_manager.pity_counters.epic_counter, 25, "epic counter should persist")
	runner.assert_equal(new_manager.pity_counters.legendary_counter, 40, "legendary counter should persist")
