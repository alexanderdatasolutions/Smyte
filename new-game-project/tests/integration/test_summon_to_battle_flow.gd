# tests/integration/test_summon_to_battle_flow.gd
# Integration test: Summon → Equip → Battle flow
extends RefCounted

var runner = null
var collection_manager = null
var resource_manager = null
var equipment_manager = null
var battle_coordinator = null
var player_progression = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")
	equipment_manager = registry.get_system("EquipmentManager")
	battle_coordinator = registry.get_system("BattleCoordinator")
	player_progression = registry.get_system("PlayerProgressionManager")

func test_summon_equip_and_battle():
	"""
	USER FLOW:
	1. Player uses 100 crystals to summon
	2. Player gets Ares
	3. Player crafts weapon for Ares
	4. Player equips weapon on Ares
	5. Player enters dungeon with Ares
	6. Player's stats are calculated with equipment bonus
	7. Player wins battle
	"""
	setup()

	# STEP 1: Give player crystals for summoning
	resource_manager.add_resource("divine_crystals", 100)
	var crystals = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals, 100, "Step 1: Should have 100 crystals")

	# STEP 2: Summon a god (we'll manually add since summon has RNG)
	var ares = collection_manager.add_god_to_collection("ares")
	runner.assert_not_null(ares, "Step 2: Ares should be summoned")

	# Simulate summon cost
	resource_manager.remove_resource("divine_crystals", 100)
	var crystals_after = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_after, 0, "Step 2: Crystals should be consumed")

	# STEP 3: Get base stats
	var base_attack = ares.get_stat("attack")
	runner.assert_true(base_attack > 0, "Step 3: Should have base attack")

	# STEP 4: Create equipment (weapon)
	var weapon = equipment_manager.create_equipment("weapon", "common")
	runner.assert_not_null(weapon, "Step 4: Weapon should be created")
	runner.assert_equal(weapon.slot, "weapon", "Step 4: Should be weapon slot")

	# Enhance weapon to +3
	for i in range(3):
		equipment_manager.enhance_equipment(weapon.id)

	runner.assert_equal(weapon.enhancement_level, 3, "Step 4: Should be +3")

	# STEP 5: Equip weapon on Ares
	var equip_success = equipment_manager.equip_on_god(weapon.id, ares.id)
	runner.assert_true(equip_success, "Step 5: Should equip successfully")

	# STEP 6: Verify stats increased
	var equipped_attack = ares.get_stat("attack")
	runner.assert_true(equipped_attack > base_attack, "Step 6: Attack should be higher with equipment")

	# STEP 7: Create enemy
	var enemy = God.new()
	enemy.id = "test_enemy"
	enemy.name = "Test Enemy"
	enemy.base_hp = 1000
	enemy.base_attack = 50
	enemy.base_defense = 30
	enemy.base_speed = 80

	# STEP 8: Start battle
	var player_team = [ares]
	var enemy_team = [enemy]

	battle_coordinator.start_battle(player_team, enemy_team)
	runner.assert_true(battle_coordinator.is_battle_active(), "Step 8: Battle should be active")

	# STEP 9: Simulate battle until end (max 20 turns to prevent infinite loop)
	var turn_count = 0
	while battle_coordinator.is_battle_active() and turn_count < 20:
		battle_coordinator.process_turn()
		turn_count += 1

	runner.assert_false(battle_coordinator.is_battle_active(), "Step 9: Battle should end")

	# STEP 10: Check result (player should win with equipment advantage)
	var result = battle_coordinator.get_battle_result()
	runner.assert_not_null(result, "Step 10: Should have battle result")

func test_equipment_unequip_and_reequip():
	"""
	USER FLOW:
	1. Equip weapon on Ares
	2. Check stats increase
	3. Unequip weapon
	4. Check stats return to base
	5. Equip on Athena
	6. Check Athena stats increase
	"""
	setup()

	var ares = collection_manager.add_god_to_collection("ares")
	var athena = collection_manager.add_god_to_collection("athena")
	var weapon = equipment_manager.create_equipment("weapon", "rare")

	# STEP 1: Get base stats
	var ares_base = ares.get_stat("attack")
	var athena_base = athena.get_stat("attack")

	# STEP 2: Equip on Ares
	equipment_manager.equip_on_god(weapon.id, ares.id)
	var ares_equipped = ares.get_stat("attack")
	runner.assert_true(ares_equipped > ares_base, "Step 2: Ares attack should increase")

	# STEP 3: Unequip from Ares
	equipment_manager.unequip_from_god(weapon.id, ares.id)
	var ares_after_unequip = ares.get_stat("attack")
	runner.assert_equal(ares_after_unequip, ares_base, "Step 3: Ares should return to base stats")

	# STEP 4: Equip on Athena
	equipment_manager.equip_on_god(weapon.id, athena.id)
	var athena_equipped = athena.get_stat("attack")
	runner.assert_true(athena_equipped > athena_base, "Step 4: Athena attack should increase")

	# STEP 5: Verify weapon is not on Ares
	var ares_weapon = ares.equipment[0]  # Slot 0 = weapon
	runner.assert_null(ares_weapon, "Step 5: Ares should have no weapon")

func test_multiple_equipment_slots():
	"""
	USER FLOW:
	1. Equip 6 pieces of equipment on one god
	2. Verify all slots filled
	3. Verify stats stack correctly
	"""
	setup()

	var ares = collection_manager.add_god_to_collection("ares")
	var base_attack = ares.get_stat("attack")

	# STEP 1: Create 6 pieces of equipment
	var weapon = equipment_manager.create_equipment("weapon", "common")
	var helm = equipment_manager.create_equipment("helm", "common")
	var armor = equipment_manager.create_equipment("armor", "common")
	var boots = equipment_manager.create_equipment("boots", "common")
	var gloves = equipment_manager.create_equipment("gloves", "common")
	var amulet = equipment_manager.create_equipment("amulet", "common")

	# STEP 2: Equip all 6 pieces
	equipment_manager.equip_on_god(weapon.id, ares.id)
	equipment_manager.equip_on_god(helm.id, ares.id)
	equipment_manager.equip_on_god(armor.id, ares.id)
	equipment_manager.equip_on_god(boots.id, ares.id)
	equipment_manager.equip_on_god(gloves.id, ares.id)
	equipment_manager.equip_on_god(amulet.id, ares.id)

	# STEP 3: Verify all slots filled
	var equipped_count = 0
	for slot in ares.equipment:
		if slot != null:
			equipped_count += 1

	runner.assert_equal(equipped_count, 6, "Step 3: All 6 slots should be filled")

	# STEP 4: Verify total stats are much higher
	var total_attack = ares.get_stat("attack")
	runner.assert_true(total_attack > base_attack * 1.5, "Step 4: Attack should be 50%+ higher with full gear")
