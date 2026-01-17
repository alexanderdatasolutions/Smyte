# tests/integration/test_specialization_flow.gd
# Integration test: Complete specialization unlock user flow
extends RefCounted

var runner = null
var game_coordinator = null
var collection_manager = null
var resource_manager = null
var role_manager = null
var specialization_manager = null
var player_progression = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	"""Set up test environment"""
	# Get system registry
	var registry = SystemRegistry.get_instance()
	game_coordinator = registry.get_system("GameCoordinator")
	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")
	role_manager = registry.get_system("RoleManager")
	specialization_manager = registry.get_system("SpecializationManager")
	player_progression = registry.get_system("PlayerProgressionManager")

func test_complete_specialization_unlock_flow():
	"""
	USER FLOW:
	1. Player summons Ares (Fighter role)
	2. Player levels Ares to 20
	3. Player earns gold and divine essence
	4. Player navigates to specialization screen
	5. Player selects Ares
	6. Player views Berserker specialization
	7. Player checks requirements (should fail - not level 20 yet)
	8. Player levels god to 20
	9. Player checks requirements again (should pass)
	10. Player unlocks Berserker
	11. Player verifies bonuses are applied
	"""
	setup()

	# STEP 1: Summon Ares
	var ares = collection_manager.add_god_to_collection("ares")
	runner.assert_not_null(ares, "Step 1: Ares should be summoned")
	runner.assert_equal(ares.name, "Ares", "Step 1: God should be Ares")
	runner.assert_equal(ares.primary_role, "fighter", "Step 1: Ares should have Fighter role")
	runner.assert_equal(ares.level, 1, "Step 1: Should start at level 1")

	# STEP 2: Get available specializations for Fighter
	var available_specs = role_manager.get_available_specializations_for_god(ares)
	runner.assert_true(available_specs.size() > 0, "Step 2: Should have available specializations")
	runner.assert_true("fighter_berserker" in available_specs, "Step 2: Should have Berserker available")

	# STEP 3: Check Berserker requirements (should fail - level too low)
	var berserker = specialization_manager.get_specialization("fighter_berserker")
	runner.assert_not_null(berserker, "Step 3: Berserker spec should exist")

	var can_unlock_early = specialization_manager.can_unlock(ares, berserker)
	runner.assert_false(can_unlock_early, "Step 3: Should NOT be able to unlock at level 1")

	var reasons_early = specialization_manager.get_unlock_failure_reasons(ares, berserker)
	runner.assert_true(reasons_early.size() > 0, "Step 3: Should have failure reasons")
	runner.assert_true("level" in reasons_early[0].to_lower(), "Step 3: Should fail due to level")

	# STEP 4: Level Ares to 20
	for i in range(19):  # Level 1 → 20
		player_progression.level_up_god(ares)

	runner.assert_equal(ares.level, 20, "Step 4: Should be level 20")

	# STEP 5: Check requirements again (should still fail - no resources)
	var can_unlock_no_resources = specialization_manager.can_unlock(ares, berserker)
	runner.assert_false(can_unlock_no_resources, "Step 5: Should fail without resources")

	# STEP 6: Give player resources (gold + divine essence)
	resource_manager.add_resource("gold", 10000)
	resource_manager.add_resource("divine_essence", 50)

	var has_gold = resource_manager.has_resource("gold", 10000)
	var has_essence = resource_manager.has_resource("divine_essence", 50)
	runner.assert_true(has_gold, "Step 6: Should have enough gold")
	runner.assert_true(has_essence, "Step 6: Should have enough divine essence")

	# STEP 7: Check requirements (should pass now)
	var can_unlock = specialization_manager.can_unlock(ares, berserker)
	runner.assert_true(can_unlock, "Step 7: Should be able to unlock now")

	# STEP 8: Unlock Berserker
	var success = specialization_manager.unlock_specialization(ares, "fighter_berserker")
	runner.assert_true(success, "Step 8: Unlock should succeed")

	# STEP 9: Verify specialization is unlocked
	runner.assert_true(ares.has_specialization("fighter_berserker"), "Step 9: God should have Berserker")

	# STEP 10: Verify resources were consumed
	var gold_after = resource_manager.get_resource_amount("gold")
	var essence_after = resource_manager.get_resource_amount("divine_essence")
	runner.assert_equal(gold_after, 0, "Step 10: Gold should be consumed")
	runner.assert_equal(essence_after, 0, "Step 10: Divine essence should be consumed")

	# STEP 11: Verify stat bonuses are applied
	var attack_bonus = specialization_manager.get_stat_bonus_for_god(ares, "attack_percent")
	runner.assert_equal(attack_bonus, 0.15, "Step 11: Should have +15% attack from Berserker")

	var defense_bonus = specialization_manager.get_stat_bonus_for_god(ares, "defense_percent")
	runner.assert_equal(defense_bonus, -0.05, "Step 11: Should have -5% defense from Berserker")

	var crit_dmg_bonus = specialization_manager.get_stat_bonus_for_god(ares, "crit_damage_percent")
	runner.assert_equal(crit_dmg_bonus, 0.25, "Step 11: Should have +25% crit damage from Berserker")

func test_specialization_tree_progression():
	"""
	USER FLOW:
	1. Unlock Tier I (Berserker)
	2. Try to unlock Tier II without meeting requirements
	3. Meet requirements and unlock Tier II (Raging Warrior)
	4. Verify both bonuses stack
	"""
	setup()

	# Setup: Create level 20 Ares with resources
	var ares = collection_manager.add_god_to_collection("ares")
	for i in range(19):
		player_progression.level_up_god(ares)

	resource_manager.add_resource("gold", 50000)
	resource_manager.add_resource("divine_essence", 200)

	# STEP 1: Unlock Berserker (Tier I)
	var berserker_unlocked = specialization_manager.unlock_specialization(ares, "fighter_berserker")
	runner.assert_true(berserker_unlocked, "Step 1: Berserker should unlock")

	# STEP 2: Try to unlock Raging Warrior (Tier II) - should fail (need level 30)
	var raging_warrior = specialization_manager.get_specialization("fighter_raging_warrior")
	var can_unlock_early = specialization_manager.can_unlock(ares, raging_warrior)
	runner.assert_false(can_unlock_early, "Step 2: Should fail - need level 30 and parent spec")

	# STEP 3: Level to 30
	for i in range(10):  # 20 → 30
		player_progression.level_up_god(ares)

	runner.assert_equal(ares.level, 30, "Step 3: Should be level 30")

	# STEP 4: Check requirements (should pass now - has Berserker + level 30)
	var can_unlock_now = specialization_manager.can_unlock(ares, raging_warrior)
	runner.assert_true(can_unlock_now, "Step 4: Should be able to unlock Tier II now")

	# STEP 5: Unlock Raging Warrior
	var tier2_unlocked = specialization_manager.unlock_specialization(ares, "fighter_raging_warrior")
	runner.assert_true(tier2_unlocked, "Step 5: Raging Warrior should unlock")

	# STEP 6: Verify both specs are active and bonuses stack
	var spec_count = ares.get_unlocked_specializations().size()
	runner.assert_equal(spec_count, 2, "Step 6: Should have 2 specializations")

	# Berserker: +15% attack, Raging Warrior: +10% attack = 25% total
	var total_attack_bonus = specialization_manager.get_stat_bonus_for_god(ares, "attack_percent")
	runner.assert_equal(total_attack_bonus, 0.25, "Step 6: Attack bonuses should stack (15% + 10%)")

func test_wrong_role_cannot_unlock():
	"""
	USER FLOW:
	1. Summon Poseidon (Fighter role)
	2. Try to unlock Gatherer specialization
	3. Verify it fails due to wrong role
	"""
	setup()

	# STEP 1: Summon Poseidon (Fighter)
	var poseidon = collection_manager.add_god_to_collection("poseidon")
	runner.assert_equal(poseidon.primary_role, "fighter", "Step 1: Poseidon is a Fighter")

	# Level to 20 and give resources
	for i in range(19):
		player_progression.level_up_god(poseidon)
	resource_manager.add_resource("gold", 10000)
	resource_manager.add_resource("divine_essence", 50)

	# STEP 2: Try to unlock Miner (Gatherer spec)
	var miner = specialization_manager.get_specialization("gatherer_miner")
	var can_unlock = specialization_manager.can_unlock(poseidon, miner)
	runner.assert_false(can_unlock, "Step 2: Should NOT unlock - wrong role")

	var reasons = specialization_manager.get_unlock_failure_reasons(poseidon, miner)
	runner.assert_true(reasons.size() > 0, "Step 2: Should have failure reasons")
	runner.assert_true("role" in reasons[0].to_lower(), "Step 2: Should fail due to role mismatch")

func test_multiple_gods_independent_progress():
	"""
	USER FLOW:
	1. Summon Ares and Athena (both Fighters)
	2. Unlock Berserker on Ares
	3. Verify Athena does NOT have Berserker
	4. Unlock Guardian on Athena
	5. Verify each god has different specs
	"""
	setup()

	# STEP 1: Summon both gods
	var ares = collection_manager.add_god_to_collection("ares")
	var athena = collection_manager.add_god_to_collection("athena")

	# Level both to 20
	for i in range(19):
		player_progression.level_up_god(ares)
		player_progression.level_up_god(athena)

	resource_manager.add_resource("gold", 20000)
	resource_manager.add_resource("divine_essence", 100)

	# STEP 2: Unlock Berserker on Ares
	var ares_unlocked = specialization_manager.unlock_specialization(ares, "fighter_berserker")
	runner.assert_true(ares_unlocked, "Step 2: Ares should unlock Berserker")

	# STEP 3: Verify Athena does NOT have Berserker
	runner.assert_true(ares.has_specialization("fighter_berserker"), "Step 3: Ares has Berserker")
	runner.assert_false(athena.has_specialization("fighter_berserker"), "Step 3: Athena does NOT have Berserker")

	# STEP 4: Unlock Guardian on Athena
	var athena_unlocked = specialization_manager.unlock_specialization(athena, "fighter_guardian")
	runner.assert_true(athena_unlocked, "Step 4: Athena should unlock Guardian")

	# STEP 5: Verify independence
	runner.assert_true(ares.has_specialization("fighter_berserker"), "Step 5: Ares still has Berserker")
	runner.assert_false(ares.has_specialization("fighter_guardian"), "Step 5: Ares does NOT have Guardian")
	runner.assert_true(athena.has_specialization("fighter_guardian"), "Step 5: Athena has Guardian")
	runner.assert_false(athena.has_specialization("fighter_berserker"), "Step 5: Athena does NOT have Berserker")

	# Verify different stat bonuses
	var ares_attack = specialization_manager.get_stat_bonus_for_god(ares, "attack_percent")
	var athena_defense = specialization_manager.get_stat_bonus_for_god(athena, "defense_percent")

	runner.assert_equal(ares_attack, 0.15, "Step 5: Ares has +15% attack")
	runner.assert_equal(athena_defense, 0.20, "Step 5: Athena has +20% defense")
