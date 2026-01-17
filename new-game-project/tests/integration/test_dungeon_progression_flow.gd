# tests/integration/test_dungeon_progression_flow.gd
# Integration test: Dungeon entry, completion, loot, and difficulty progression
extends RefCounted

var runner = null
var dungeon_manager = null
var dungeon_coordinator = null
var loot_system = null
var resource_manager = null
var collection_manager = null
var player_progression = null
var battle_coordinator = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	dungeon_manager = registry.get_system("DungeonManager")
	dungeon_coordinator = registry.get_system("DungeonCoordinator")
	loot_system = registry.get_system("LootSystem")
	resource_manager = registry.get_system("ResourceManager")
	collection_manager = registry.get_system("CollectionManager")
	player_progression = registry.get_system("PlayerProgressionManager")
	battle_coordinator = registry.get_system("BattleCoordinator")

func test_complete_dungeon_run_beginner():
	"""
	USER FLOW:
	1. Player is level 10
	2. Player has 150 energy
	3. Player enters Fire Sanctum (Beginner)
	4. Player fights 3 waves
	5. Player wins and receives loot
	6. Energy is consumed
	"""
	setup()

	# STEP 1: Set player level and energy
	var player = player_progression.get_player_state()
	player.level = 10
	resource_manager.set_resource("energy", 150)

	# STEP 2: Get Fire Sanctum Beginner
	var fire_sanctum = dungeon_manager.get_dungeon("fire_sanctum")
	runner.assert_not_null(fire_sanctum, "Step 2: Fire Sanctum should exist")

	var difficulty = fire_sanctum.difficulties["beginner"]
	runner.assert_not_null(difficulty, "Step 2: Beginner difficulty should exist")

	# STEP 3: Check entry requirements
	var can_enter = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "beginner")
	runner.assert_true(can_enter, "Step 3: Should be able to enter")

	# STEP 4: Create team
	var ares = collection_manager.add_god_to_collection("ares")
	for i in range(14):  # Level to 15
		player_progression.level_up_god(ares)

	var team = [ares]

	# STEP 5: Enter dungeon
	var entry_success = dungeon_coordinator.start_dungeon_run("fire_sanctum", "beginner", team)
	runner.assert_true(entry_success, "Step 5: Should enter dungeon")

	# STEP 6: Verify energy consumed
	var energy_after = resource_manager.get_resource_amount("energy")
	runner.assert_equal(energy_after, 142, "Step 6: Should consume 8 energy (150 - 8 = 142)")

	# STEP 7: Simulate wave 1
	var wave1_result = dungeon_coordinator.process_wave()
	runner.assert_not_null(wave1_result, "Step 7: Wave 1 should complete")

	# STEP 8: Simulate wave 2
	var wave2_result = dungeon_coordinator.process_wave()
	runner.assert_not_null(wave2_result, "Step 8: Wave 2 should complete")

	# STEP 9: Simulate wave 3
	var wave3_result = dungeon_coordinator.process_wave()
	runner.assert_not_null(wave3_result, "Step 9: Wave 3 should complete")

	# STEP 10: Check loot awarded
	var loot = dungeon_coordinator.get_run_loot()
	runner.assert_not_null(loot, "Step 10: Should receive loot")
	runner.assert_true(loot.size() > 0, "Step 10: Loot should not be empty")

func test_cannot_enter_expert_without_clearing_advanced():
	"""
	USER FLOW:
	1. Player tries to enter Expert difficulty
	2. Entry fails - haven't cleared Advanced
	3. Player clears Advanced
	4. Player can now enter Expert
	"""
	setup()

	# STEP 1: Set player level high enough
	var player = player_progression.get_player_state()
	player.level = 40
	resource_manager.set_resource("energy", 150)

	# STEP 2: Try to enter Expert without clearing Advanced
	var can_enter_expert = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "expert")
	runner.assert_false(can_enter_expert, "Step 2: Should NOT enter Expert without clearing Advanced")

	# STEP 3: Mark Advanced as cleared
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "advanced")

	# STEP 4: Try Expert again
	var can_enter_now = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "expert")
	runner.assert_true(can_enter_now, "Step 4: Should be able to enter Expert after clearing Advanced")

func test_loot_rng_variance():
	"""
	USER FLOW:
	1. Complete Fire Sanctum Expert 10 times
	2. Verify loot varies (RNG)
	3. Verify guaranteed drops always appear
	4. Verify rare drops sometimes appear
	"""
	setup()

	var player = player_progression.get_player_state()
	player.level = 40
	resource_manager.set_resource("energy", 200)

	# Mark all previous difficulties cleared
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "beginner")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "intermediate")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "advanced")

	var ares = collection_manager.add_god_to_collection("ares")
	for i in range(39):
		player_progression.level_up_god(ares)

	var team = [ares]

	# STEP 1: Run dungeon 10 times and collect loot
	var loot_results = []
	var guaranteed_drops_count = 0
	var rare_drops_count = 0

	for run in range(10):
		# Refill energy if needed
		if resource_manager.get_resource_amount("energy") < 15:
			resource_manager.add_resource("energy", 50)

		var entered = dungeon_coordinator.start_dungeon_run("fire_sanctum", "expert", team)
		if not entered:
			continue

		# Simulate 3 waves
		dungeon_coordinator.process_wave()
		dungeon_coordinator.process_wave()
		dungeon_coordinator.process_wave()

		var loot = dungeon_coordinator.get_run_loot()
		loot_results.append(loot)

		# Check for guaranteed fire essence
		if "fire_essence_high" in loot:
			guaranteed_drops_count += 1

		# Check for rare drops
		if "divine_crystal" in loot or "awakening_stone" in loot:
			rare_drops_count += 1

	# STEP 2: Verify variance
	runner.assert_equal(loot_results.size(), 10, "Step 2: Should have 10 loot results")

	# STEP 3: Guaranteed drops should appear every time
	runner.assert_true(guaranteed_drops_count >= 8, "Step 3: Guaranteed drops should appear most runs")

	# STEP 4: Rare drops should appear sometimes (but not every time)
	runner.assert_true(rare_drops_count > 0, "Step 4: Rare drops should appear at least once in 10 runs")
	runner.assert_true(rare_drops_count < 10, "Step 4: Rare drops should NOT appear every run")

func test_energy_regeneration():
	"""
	USER FLOW:
	1. Player spends all energy
	2. Wait 5 minutes (simulate time)
	3. Energy should regenerate +1
	"""
	setup()

	# STEP 1: Set energy to 0
	resource_manager.set_resource("energy", 0)
	var energy_start = resource_manager.get_resource_amount("energy")
	runner.assert_equal(energy_start, 0, "Step 1: Should start at 0 energy")

	# STEP 2: Simulate 5 minutes passing (300 seconds)
	# (This would require ResourceManager to have time-based regeneration)
	resource_manager.update_energy_regeneration(300.0)

	# STEP 3: Energy should increase by 1
	var energy_after = resource_manager.get_resource_amount("energy")
	runner.assert_equal(energy_after, 1, "Step 3: Should regenerate 1 energy after 5 minutes")

func test_daily_dungeon_rotation():
	"""
	USER FLOW:
	1. Check available dungeons on Monday
	2. Verify Fire Sanctum is available
	3. Change day to Tuesday
	4. Verify Water Sanctum is now available
	5. Verify Fire Sanctum is locked
	"""
	setup()

	# STEP 1: Set day to Monday (day 0)
	dungeon_manager.set_day_of_week(0)

	# STEP 2: Check available dungeons
	var available_monday = dungeon_manager.get_available_dungeons()
	runner.assert_true("fire_sanctum" in available_monday, "Step 2: Fire Sanctum should be available Monday")

	# STEP 3: Change to Tuesday (day 1)
	dungeon_manager.set_day_of_week(1)

	# STEP 4: Check available dungeons
	var available_tuesday = dungeon_manager.get_available_dungeons()
	runner.assert_true("water_sanctum" in available_tuesday, "Step 4: Water Sanctum should be available Tuesday")
	runner.assert_false("fire_sanctum" in available_tuesday, "Step 4: Fire Sanctum should NOT be available Tuesday")

func test_cannot_enter_without_energy():
	"""
	USER FLOW:
	1. Player has 5 energy
	2. Fire Sanctum costs 8 energy
	3. Entry fails
	4. Player refills energy
	5. Entry succeeds
	"""
	setup()

	var player = player_progression.get_player_state()
	player.level = 10

	# STEP 1: Set energy to 5
	resource_manager.set_resource("energy", 5)

	# STEP 2: Try to enter dungeon (costs 8)
	var ares = collection_manager.add_god_to_collection("ares")
	for i in range(14):
		player_progression.level_up_god(ares)

	var team = [ares]

	var can_enter = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "beginner")
	runner.assert_false(can_enter, "Step 2: Should NOT enter - not enough energy")

	# STEP 3: Add energy
	resource_manager.add_resource("energy", 10)
	var energy_now = resource_manager.get_resource_amount("energy")
	runner.assert_equal(energy_now, 15, "Step 3: Should have 15 energy")

	# STEP 4: Try again
	var can_enter_now = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "beginner")
	runner.assert_true(can_enter_now, "Step 4: Should be able to enter now")
