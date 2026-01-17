# tests/integration/test_player_progression_and_unlocks.gd
# Integration test: Player leveling, feature unlocks, and progression gates
extends RefCounted

var runner = null
var player_progression = null
var collection_manager = null
var resource_manager = null
var dungeon_manager = null
var territory_manager = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	player_progression = registry.get_system("PlayerProgressionManager")
	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")
	dungeon_manager = registry.get_system("DungeonManager")
	territory_manager = registry.get_system("TerritoryManager")

func test_player_level_unlocks_features():
	"""
	USER FLOW:
	1. New player starts at level 1
	2. Level 5: Unlocks equipment enhancement
	3. Level 10: Unlocks dungeons
	4. Level 15: Unlocks arena
	5. Level 20: Unlocks specializations
	6. Level 30: Unlocks advanced territories
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: Start at level 1
	player.level = 1
	runner.assert_false(player_progression.is_feature_unlocked("equipment_enhancement"), "Step 1: Enhancement locked at level 1")
	runner.assert_false(player_progression.is_feature_unlocked("dungeons"), "Step 1: Dungeons locked at level 1")

	# STEP 2: Level to 5
	player.level = 5
	runner.assert_true(player_progression.is_feature_unlocked("equipment_enhancement"), "Step 2: Enhancement unlocked at level 5")

	# STEP 3: Level to 10
	player.level = 10
	runner.assert_true(player_progression.is_feature_unlocked("dungeons"), "Step 3: Dungeons unlocked at level 10")

	# STEP 4: Level to 15
	player.level = 15
	runner.assert_true(player_progression.is_feature_unlocked("arena"), "Step 4: Arena unlocked at level 15")

	# STEP 5: Level to 20
	player.level = 20
	runner.assert_true(player_progression.is_feature_unlocked("specializations"), "Step 5: Specializations unlocked at level 20")

func test_player_gains_xp_from_battles():
	"""
	USER FLOW:
	1. Player is level 1 with 0 XP
	2. Player completes dungeon run
	3. Player gains XP
	4. Player levels up after enough XP
	"""
	setup()

	var player = player_progression.get_player_state()
	player.level = 1
	player.experience = 0

	# STEP 1: Complete a dungeon (simulate)
	var xp_reward = 100
	player_progression.add_experience(xp_reward)

	# STEP 2: Verify XP gained
	runner.assert_equal(player.experience, 100, "Step 2: Should gain 100 XP")

	# STEP 3: Add more XP to trigger level up
	player_progression.add_experience(900)  # Total 1000 XP

	# STEP 4: Check for level up (assuming 1000 XP = level 2)
	runner.assert_true(player.level >= 2, "Step 4: Should level up to 2")

func test_collection_size_gates():
	"""
	USER FLOW:
	1. Player starts with max 20 god slots
	2. Player summons 20 gods
	3. Player tries to summon 21st god
	4. Summon fails - collection full
	5. Player expands slots with crystals
	6. Player can summon again
	"""
	setup()

	# STEP 1: Set collection limit
	var max_slots = collection_manager.get_max_collection_size()
	runner.assert_equal(max_slots, 20, "Step 1: Should start with 20 slots")

	# STEP 2: Fill collection
	for i in range(20):
		collection_manager.add_god_to_collection("ares")

	runner.assert_equal(collection_manager.get_god_count(), 20, "Step 2: Should have 20 gods")

	# STEP 3: Try to add 21st god
	var overflow_god = collection_manager.add_god_to_collection("poseidon")
	runner.assert_null(overflow_god, "Step 3: Should fail - collection full")

	# STEP 4: Expand collection
	resource_manager.add_resource("divine_crystals", 100)
	var expand_success = collection_manager.expand_collection_size(5)
	runner.assert_true(expand_success, "Step 4: Expansion should succeed")

	# STEP 5: Verify new limit
	var new_max = collection_manager.get_max_collection_size()
	runner.assert_equal(new_max, 25, "Step 5: Should have 25 slots now")

	# STEP 6: Add god successfully
	var new_god = collection_manager.add_god_to_collection("poseidon")
	runner.assert_not_null(new_god, "Step 6: Should add god successfully")

func test_energy_cap_increases_with_player_level():
	"""
	USER FLOW:
	1. Level 1 player has 100 energy cap
	2. Level 20 player has 150 energy cap
	3. Level 50 player has 200 energy cap
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: Level 1
	player.level = 1
	var cap_lv1 = resource_manager.get_energy_cap()
	runner.assert_equal(cap_lv1, 100, "Step 1: Level 1 should have 100 energy cap")

	# STEP 2: Level 20
	player.level = 20
	var cap_lv20 = resource_manager.get_energy_cap()
	runner.assert_equal(cap_lv20, 150, "Step 2: Level 20 should have 150 energy cap")

	# STEP 3: Level 50
	player.level = 50
	var cap_lv50 = resource_manager.get_energy_cap()
	runner.assert_equal(cap_lv50, 200, "Step 3: Level 50 should have 200 energy cap")

func test_tutorial_completion_unlocks_features():
	"""
	USER FLOW:
	1. New player in tutorial mode
	2. Tutorial gates prevent summon/dungeon access
	3. Player completes tutorial
	4. All features unlock
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: Start in tutorial
	player.tutorial_completed = false
	runner.assert_false(player_progression.can_access_feature("summon"), "Step 1: Cannot summon in tutorial")

	# STEP 2: Complete tutorial
	player_progression.complete_tutorial()

	# STEP 3: Verify features unlock
	runner.assert_true(player.tutorial_completed, "Step 3: Tutorial should be completed")
	runner.assert_true(player_progression.can_access_feature("summon"), "Step 3: Can summon after tutorial")

func test_daily_login_rewards():
	"""
	USER FLOW:
	1. Player logs in on day 1
	2. Player receives day 1 reward
	3. Player logs in on day 2
	4. Player receives day 2 reward (better)
	5. Player misses day 3
	6. Streak resets
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: Day 1 login
	var day1_reward = player_progression.claim_daily_login_reward(1)
	runner.assert_not_null(day1_reward, "Step 1: Should receive day 1 reward")
	runner.assert_true(day1_reward.has("gold"), "Step 1: Day 1 should give gold")

	# STEP 2: Day 2 login
	var day2_reward = player_progression.claim_daily_login_reward(2)
	runner.assert_not_null(day2_reward, "Step 2: Should receive day 2 reward")
	runner.assert_true(day2_reward["gold"] > day1_reward["gold"], "Step 2: Day 2 should give more gold")

	# STEP 3: Skip to day 4 (missed day 3)
	player_progression.check_login_streak(4)
	var streak = player.login_streak
	runner.assert_true(streak <= 1, "Step 3: Streak should reset after missing a day")

func test_achievement_system():
	"""
	USER FLOW:
	1. Player completes "First Summon" achievement
	2. Player receives crystals
	3. Player completes "Clear 10 Dungeons" achievement
	4. Player receives more crystals
	"""
	setup()

	# STEP 1: Summon first god (triggers achievement)
	var initial_crystals = resource_manager.get_resource_amount("divine_crystals")
	var ares = collection_manager.add_god_to_collection("ares")

	player_progression.check_achievement("first_summon")

	# STEP 2: Verify achievement reward
	var crystals_after = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_true(crystals_after > initial_crystals, "Step 2: Should receive crystals from achievement")

	# STEP 3: Complete 10 dungeons
	for i in range(10):
		player_progression.increment_stat("dungeons_cleared")

	player_progression.check_achievement("clear_10_dungeons")

	# STEP 4: Verify second achievement reward
	var crystals_final = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_true(crystals_final > crystals_after, "Step 4: Should receive more crystals from dungeon achievement")

func test_vip_level_bonuses():
	"""
	USER FLOW:
	1. Non-VIP player has standard energy regen
	2. Player purchases crystals, becomes VIP 1
	3. Energy regen increases
	4. Player purchases more, becomes VIP 5
	5. Energy regen increases more
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: Non-VIP
	player.vip_level = 0
	var base_regen = resource_manager.get_energy_regen_rate()
	runner.assert_equal(base_regen, 1.0, "Step 1: Non-VIP should have 1 energy per 5 min")

	# STEP 2: Become VIP 1 (buy $4.99 pack)
	player.vip_level = 1
	player.vip_points = 499

	var vip1_regen = resource_manager.get_energy_regen_rate()
	runner.assert_true(vip1_regen > base_regen, "Step 2: VIP 1 should have faster regen")

	# STEP 3: Become VIP 5 (buy more)
	player.vip_level = 5
	player.vip_points = 5000

	var vip5_regen = resource_manager.get_energy_regen_rate()
	runner.assert_true(vip5_regen > vip1_regen, "Step 3: VIP 5 should have even faster regen")

func test_first_time_rewards():
	"""
	USER FLOW:
	1. Player beats Fire Sanctum Beginner for first time
	2. Player receives bonus crystals (first clear)
	3. Player beats Fire Sanctum Beginner again
	4. No bonus crystals (only normal loot)
	"""
	setup()

	var player = player_progression.get_player_state()

	# STEP 1: First clear
	var initial_crystals = resource_manager.get_resource_amount("divine_crystals")
	player_progression.mark_dungeon_first_clear("fire_sanctum", "beginner")

	# STEP 2: Verify bonus
	var crystals_after = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_true(crystals_after > initial_crystals, "Step 2: Should receive first clear bonus")

	# STEP 3: Try to claim again
	var second_claim = player_progression.mark_dungeon_first_clear("fire_sanctum", "beginner")
	runner.assert_false(second_claim, "Step 3: Should NOT receive bonus twice")

	# STEP 4: Verify crystals unchanged
	var crystals_final = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_final, crystals_after, "Step 4: Crystals should not increase on repeat clear")
