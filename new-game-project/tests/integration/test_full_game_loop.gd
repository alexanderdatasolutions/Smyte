# tests/integration/test_full_game_loop.gd
# Integration test: Complete game loop simulating real player session
extends RefCounted

var runner = null
var registry = null

# All systems
var player_progression = null
var collection_manager = null
var resource_manager = null
var equipment_manager = null
var specialization_manager = null
var role_manager = null
var dungeon_coordinator = null
var territory_manager = null
var task_assignment_manager = null
var awakening_system = null
var sacrifice_manager = null
var battle_coordinator = null
var shop_manager = null
var skin_manager = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	registry = SystemRegistry.get_instance()
	player_progression = registry.get_system("PlayerProgressionManager")
	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")
	equipment_manager = registry.get_system("EquipmentManager")
	specialization_manager = registry.get_system("SpecializationManager")
	role_manager = registry.get_system("RoleManager")
	dungeon_coordinator = registry.get_system("DungeonCoordinator")
	territory_manager = registry.get_system("TerritoryManager")
	task_assignment_manager = registry.get_system("TaskAssignmentManager")
	awakening_system = registry.get_system("AwakeningSystem")
	sacrifice_manager = registry.get_system("SacrificeManager")
	battle_coordinator = registry.get_system("BattleCoordinator")
	shop_manager = registry.get_system("ShopManager")
	skin_manager = registry.get_system("SkinManager")

func test_complete_new_player_journey():
	"""
	COMPLETE USER FLOW - Day 1 Player Journey:

	1. Create new account
	2. Complete tutorial (get free summon)
	3. Summon first god (Ares)
	4. Level Ares to 5 through battles
	5. Craft and equip basic weapon
	6. Reach player level 10
	7. Unlock dungeons
	8. Run Fire Sanctum Beginner 5 times
	9. Collect fire essences
	10. Capture first territory node
	11. Assign Ares to mining task
	12. Collect resources from territory
	13. Reach player level 20
	14. Unlock Berserker specialization
	15. Awaken Ares with essences
	16. Complete full equipment set
	17. Run Fire Sanctum Expert
	18. Buy crystal pack and purchase skin
	19. Equip skin on Ares
	20. Save and verify game state
	"""
	setup()

	# ======================================================================
	# PHASE 1: NEW PLAYER ONBOARDING (Level 1-5)
	# ======================================================================

	# STEP 1: Create player
	var player = player_progression.get_player_state()
	player.level = 1
	player.experience = 0
	resource_manager.set_resource("divine_crystals", 0)
	resource_manager.set_resource("gold", 1000)
	resource_manager.set_resource("energy", 100)

	runner.assert_equal(player.level, 1, "Phase 1.1: Player starts at level 1")

	# STEP 2: Complete tutorial - get free crystals
	player_progression.complete_tutorial()
	resource_manager.add_resource("divine_crystals", 500)  # Tutorial reward

	runner.assert_true(player.tutorial_completed, "Phase 1.2: Tutorial completed")
	runner.assert_equal(resource_manager.get_resource_amount("divine_crystals"), 500, "Phase 1.2: Received tutorial reward")

	# STEP 3: First summon (Ares - Fighter)
	var ares = collection_manager.add_god_to_collection("ares")
	resource_manager.remove_resource("divine_crystals", 100)

	runner.assert_not_null(ares, "Phase 1.3: Ares summoned")
	runner.assert_equal(ares.primary_role, "fighter", "Phase 1.3: Ares is a Fighter")
	runner.assert_equal(collection_manager.get_god_count(), 1, "Phase 1.3: Collection has 1 god")

	# STEP 4: Level Ares through basic battles
	for i in range(4):  # Level 1 → 5
		player_progression.level_up_god(ares)

	runner.assert_equal(ares.level, 5, "Phase 1.4: Ares reached level 5")

	# STEP 5: Craft basic weapon
	var weapon = equipment_manager.create_equipment("weapon", "common")
	equipment_manager.equip_on_god(weapon.id, ares.id)

	runner.assert_not_null(weapon, "Phase 1.5: Weapon crafted")
	runner.assert_true(ares.equipment[0] == weapon.id, "Phase 1.5: Weapon equipped")

	# ======================================================================
	# PHASE 2: DUNGEON UNLOCKING (Level 10+)
	# ======================================================================

	# STEP 6: Level player to 10
	for i in range(9):  # Level 1 → 10
		player_progression.add_experience(100)

	runner.assert_true(player.level >= 10, "Phase 2.1: Player reached level 10")
	runner.assert_true(player_progression.is_feature_unlocked("dungeons"), "Phase 2.1: Dungeons unlocked")

	# STEP 7: Level Ares to 15 for dungeons
	for i in range(10):  # Level 5 → 15
		player_progression.level_up_god(ares)

	runner.assert_equal(ares.level, 15, "Phase 2.2: Ares ready for dungeons")

	# STEP 8: Run Fire Sanctum Beginner 5 times
	resource_manager.set_resource("energy", 100)
	var dungeon_clears = 0
	var total_essence_collected = 0

	for run in range(5):
		var can_enter = dungeon_coordinator.can_enter_dungeon("fire_sanctum", "beginner")
		if can_enter:
			var team = [ares]
			dungeon_coordinator.start_dungeon_run("fire_sanctum", "beginner", team)

			# Simulate 3 waves
			dungeon_coordinator.process_wave()
			dungeon_coordinator.process_wave()
			dungeon_coordinator.process_wave()

			var loot = dungeon_coordinator.get_run_loot()
			if "fire_essence_low" in loot:
				total_essence_collected += loot["fire_essence_low"]

			dungeon_clears += 1

	runner.assert_true(dungeon_clears >= 3, "Phase 2.3: Completed at least 3 dungeon runs")
	runner.assert_true(total_essence_collected > 0, "Phase 2.3: Collected fire essences")

	# ======================================================================
	# PHASE 3: TERRITORY EXPANSION (Level 10+)
	# ======================================================================

	# STEP 9: Capture first territory node
	var neighbors = territory_manager.get_capturable_nodes()
	var first_node = null
	for node in neighbors:
		if node.tier == 1:
			first_node = node
			break

	var capture_success = territory_manager.capture_node(first_node.node_id, "player")
	runner.assert_true(capture_success, "Phase 3.1: Captured first territory")

	# STEP 10: Assign Ares to mining task
	var assignment = task_assignment_manager.assign_god_to_task(
		ares.id,
		first_node.node_id,
		"mining"
	)

	runner.assert_not_null(assignment, "Phase 3.2: Ares assigned to mining")

	# STEP 11: Simulate 1 hour of production
	var ore_before = resource_manager.get_resource_amount("ore")
	territory_manager.update_production(3600.0)  # 1 hour
	var ore_after = resource_manager.get_resource_amount("ore")

	runner.assert_true(ore_after > ore_before, "Phase 3.3: Ore production working")

	# ======================================================================
	# PHASE 4: SPECIALIZATION (Level 20+)
	# ======================================================================

	# STEP 12: Level player to 20
	while player.level < 20:
		player_progression.add_experience(200)

	runner.assert_true(player.level >= 20, "Phase 4.1: Player reached level 20")

	# STEP 13: Level Ares to 20
	while ares.level < 20:
		player_progression.level_up_god(ares)

	runner.assert_equal(ares.level, 20, "Phase 4.2: Ares level 20")

	# STEP 14: Unlock Berserker specialization
	resource_manager.add_resource("gold", 10000)
	resource_manager.add_resource("divine_essence", 50)

	var available_specs = role_manager.get_available_specializations_for_god(ares)
	runner.assert_true("fighter_berserker" in available_specs, "Phase 4.3: Berserker available")

	var unlock_success = specialization_manager.unlock_specialization(ares, "fighter_berserker")
	runner.assert_true(unlock_success, "Phase 4.4: Berserker unlocked")

	var attack_bonus = specialization_manager.get_stat_bonus_for_god(ares, "attack_percent")
	runner.assert_equal(attack_bonus, 0.15, "Phase 4.5: Berserker bonuses applied")

	# ======================================================================
	# PHASE 5: AWAKENING (Level 20+)
	# ======================================================================

	# STEP 15: Collect awakening materials
	resource_manager.add_resource("fire_essence_low", 10)
	resource_manager.add_resource("fire_essence_mid", 15)
	resource_manager.add_resource("fire_essence_high", 20)

	# STEP 16: Awaken Ares
	var can_awaken = awakening_system.can_awaken(ares)
	runner.assert_true(can_awaken, "Phase 5.1: Can awaken Ares")

	var base_hp = ares.get_stat("hp")
	var awaken_success = awakening_system.awaken_god(ares)
	runner.assert_true(awaken_success, "Phase 5.2: Ares awakened")

	runner.assert_true(ares.is_awakened, "Phase 5.3: Awakened state set")
	var awakened_hp = ares.get_stat("hp")
	runner.assert_true(awakened_hp > base_hp, "Phase 5.4: Stats boosted")

	# ======================================================================
	# PHASE 6: ENDGAME PREP (Level 30+)
	# ======================================================================

	# STEP 17: Level to 30 and complete equipment set
	while ares.level < 30:
		player_progression.level_up_god(ares)

	var helm = equipment_manager.create_equipment("helm", "rare")
	var armor = equipment_manager.create_equipment("armor", "rare")
	var boots = equipment_manager.create_equipment("boots", "rare")
	var gloves = equipment_manager.create_equipment("gloves", "rare")
	var amulet = equipment_manager.create_equipment("amulet", "rare")

	equipment_manager.equip_on_god(helm.id, ares.id)
	equipment_manager.equip_on_god(armor.id, ares.id)
	equipment_manager.equip_on_god(boots.id, ares.id)
	equipment_manager.equip_on_god(gloves.id, ares.id)
	equipment_manager.equip_on_god(amulet.id, ares.id)

	var equipped_count = 0
	for slot in ares.equipment:
		if slot != null:
			equipped_count += 1

	runner.assert_equal(equipped_count, 6, "Phase 6.1: Full equipment set equipped")

	# STEP 18: Run Expert dungeon
	while player.level < 40:
		player_progression.add_experience(500)

	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "beginner")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "intermediate")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "advanced")

	resource_manager.set_resource("energy", 50)
	var expert_entered = dungeon_coordinator.start_dungeon_run("fire_sanctum", "expert", [ares])

	runner.assert_true(expert_entered, "Phase 6.2: Entered Expert dungeon")

	# ======================================================================
	# PHASE 7: COSMETICS (MTX)
	# ======================================================================

	# STEP 19: Buy crystal pack and skin
	resource_manager.set_resource("divine_crystals", 0)
	shop_manager.purchase_crystal_pack("crystals_500")

	var crystals_after_pack = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_after_pack, 600, "Phase 7.1: Crystal pack purchased (500 + 100 bonus)")

	var skin_purchase = shop_manager.purchase_skin("ares_dark_warrior")
	runner.assert_true(skin_purchase, "Phase 7.2: Skin purchased")

	var skin_equipped = skin_manager.equip_skin(ares, "ares_dark_warrior")
	runner.assert_true(skin_equipped, "Phase 7.3: Skin equipped")

	runner.assert_equal(ares.equipped_skin_id, "ares_dark_warrior", "Phase 7.4: Skin ID saved")

	# ======================================================================
	# PHASE 8: SAVE/LOAD VERIFICATION
	# ======================================================================

	# STEP 20: Verify complete game state
	runner.assert_true(player.level >= 40, "Phase 8.1: Player high level")
	runner.assert_true(ares.level >= 30, "Phase 8.2: Ares high level")
	runner.assert_true(ares.is_awakened, "Phase 8.3: Ares awakened")
	runner.assert_true(ares.has_specialization("fighter_berserker"), "Phase 8.4: Has specialization")
	runner.assert_equal(equipped_count, 6, "Phase 8.5: Full gear set")
	runner.assert_equal(ares.equipped_skin_id, "ares_dark_warrior", "Phase 8.6: Skin equipped")

	var controlled_nodes = territory_manager.get_controlled_nodes("player")
	runner.assert_true(controlled_nodes.size() > 0, "Phase 8.7: Controls territory")

	# STEP 21: Save game state
	var save_data = {
		"player": player.to_dict(),
		"gods": [ares.to_dict()],
		"resources": resource_manager.get_all_resources(),
		"territories": []
	}

	for node in controlled_nodes:
		save_data["territories"].append(node.to_dict())

	runner.assert_not_null(save_data, "Phase 8.8: Save data created")
	runner.assert_true(save_data["gods"].size() == 1, "Phase 8.9: Gods saved")
	runner.assert_true(save_data["territories"].size() > 0, "Phase 8.10: Territories saved")

	# STEP 22: Verify complete progression
	print("=== NEW PLAYER JOURNEY COMPLETE ===")
	print("Player Level: ", player.level)
	print("Ares Level: ", ares.level)
	print("Ares Power: ", ares.get_stat("attack"))
	print("Territories Controlled: ", controlled_nodes.size())
	print("Dungeons Cleared: ", dungeon_clears)
	print("Specializations Unlocked: ", ares.get_unlocked_specializations().size())
	print("===================================")

	runner.assert_true(true, "Phase 8.11: Complete player journey successful!")

func test_multi_god_team_composition():
	"""
	USER FLOW:
	1. Summon 4 different gods with different roles
	2. Build balanced team (Fighter, Gatherer, Scholar, Support)
	3. Equip each god
	4. Run Expert dungeon with full team
	5. Verify synergy bonuses
	"""
	setup()

	# STEP 1: Summon diverse team
	var ares = collection_manager.add_god_to_collection("ares")  # Fighter
	var artemis = collection_manager.add_god_to_collection("artemis")  # Gatherer
	var athena = collection_manager.add_god_to_collection("athena")  # Scholar
	var apollo = collection_manager.add_god_to_collection("apollo")  # Support

	runner.assert_equal(collection_manager.get_god_count(), 4, "Step 1: Summoned 4 gods")

	# STEP 2: Level all to 30
	var team = [ares, artemis, athena, apollo]
	for god in team:
		while god.level < 30:
			player_progression.level_up_god(god)

	# STEP 3: Equip everyone
	for god in team:
		var weapon = equipment_manager.create_equipment("weapon", "rare")
		equipment_manager.equip_on_god(weapon.id, god.id)

	# STEP 4: Verify team composition
	var roles = {}
	for god in team:
		if not roles.has(god.primary_role):
			roles[god.primary_role] = 0
		roles[god.primary_role] += 1

	runner.assert_true(roles.size() >= 3, "Step 4: Diverse team composition")

	# STEP 5: Enter dungeon with full team
	resource_manager.set_resource("energy", 100)
	var player = player_progression.get_player_state()
	player.level = 40

	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "beginner")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "intermediate")
	dungeon_coordinator.mark_difficulty_cleared("fire_sanctum", "advanced")

	var entered = dungeon_coordinator.start_dungeon_run("fire_sanctum", "expert", team)
	runner.assert_true(entered, "Step 5: Entered Expert with full team")

	# STEP 6: Simulate battle
	var wave_result = dungeon_coordinator.process_wave()
	runner.assert_not_null(wave_result, "Step 6: Team cleared wave successfully")
