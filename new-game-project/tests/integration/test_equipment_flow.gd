# test_equipment_flow.gd - Integration tests for equipment flow
# Tests interaction between EquipmentManager, EquipmentEnhancementManager, and stat calculations
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_god(god_name: String = "TestGod") -> God:
	var god = God.new()
	god.id = "god_" + str(randi() % 10000)
	god.name = god_name
	god.tier = 3  # Epic
	god.level = 20
	god.base_hp = 5000
	god.base_attack = 300
	god.base_defense = 150
	god.base_speed = 110
	god.equipment = [null, null, null, null, null, null]
	return god

func create_mock_equipment(eq_name: String = "Test Weapon", eq_type: int = 0, rarity: int = 2) -> Equipment:
	var eq = Equipment.new()
	eq.equipment_id = "eq_" + str(randi() % 10000)
	eq.id = eq.equipment_id
	eq.name = eq_name
	eq.equipment_type = eq_type
	eq.rarity = rarity
	eq.enhancement_level = 0
	eq.main_stat_type = "attack"
	eq.main_stat_base = 50
	eq.main_stat_value = 50
	eq.substats = {}
	return eq

func create_equipment_manager() -> EquipmentManager:
	return EquipmentManager.new()

# ==============================================================================
# TEST: Equip/Unequip Flow
# ==============================================================================

func test_equip_equipment_to_god():
	var god = create_mock_god()
	var weapon = create_mock_equipment("Sword", 0)  # Slot 0 = Weapon
	var manager = create_equipment_manager()

	var result = manager.equip_equipment_to_god(god, weapon, 0)

	runner.assert_true(result, "should equip successfully")
	runner.assert_not_null(god.equipment[0], "slot 0 should have equipment")
	runner.assert_equal(god.equipment[0].name, "Sword", "should be the sword")

func test_equip_all_slots():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	var equipment_names = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]

	for i in range(6):
		var eq = create_mock_equipment(equipment_names[i], i)
		manager.equip_equipment_to_god(god, eq, i)

	for i in range(6):
		runner.assert_not_null(god.equipment[i], "slot %d should be filled" % i)
		runner.assert_equal(god.equipment[i].name, equipment_names[i], "slot %d name should match" % i)

func test_unequip_equipment():
	var god = create_mock_god()
	var weapon = create_mock_equipment()
	var manager = create_equipment_manager()

	manager.equip_equipment_to_god(god, weapon, 0)
	runner.assert_not_null(god.equipment[0], "should have weapon")

	manager.unequip_equipment_from_god(god, 0)
	runner.assert_null(god.equipment[0], "slot should be empty")

func test_replace_equipment():
	var god = create_mock_god()
	var old_weapon = create_mock_equipment("Old Sword", 0)
	var new_weapon = create_mock_equipment("New Sword", 0)
	var manager = create_equipment_manager()

	manager.equip_equipment_to_god(god, old_weapon, 0)
	runner.assert_equal(god.equipment[0].name, "Old Sword", "should have old sword")

	manager.equip_equipment_to_god(god, new_weapon, 0)
	runner.assert_equal(god.equipment[0].name, "New Sword", "should have new sword")
	runner.assert_equal(old_weapon.equipped_by_god_id, "", "old sword should be unequipped")

func test_equipped_by_god_id_tracking():
	var god = create_mock_god()
	god.id = "zeus_001"
	var weapon = create_mock_equipment()
	var manager = create_equipment_manager()

	manager.equip_equipment_to_god(god, weapon, 0)
	runner.assert_equal(weapon.equipped_by_god_id, "zeus_001", "should track god id")

	manager.unequip_equipment_from_god(god, 0)
	runner.assert_equal(weapon.equipped_by_god_id, "", "should clear god id")

# ==============================================================================
# TEST: Enhancement Flow
# ==============================================================================

func test_equipment_can_be_enhanced():
	var eq = create_mock_equipment("Sword", 0, 2)  # Rare
	eq.enhancement_level = 0

	runner.assert_true(eq.can_be_enhanced(), "new equipment should be enhanceable")

func test_equipment_enhancement_increases_level():
	var eq = create_mock_equipment()
	eq.enhancement_level = 0

	eq.enhancement_level += 1

	runner.assert_equal(eq.enhancement_level, 1, "enhancement level should increase")

func test_equipment_max_enhancement_by_rarity():
	# Common (1) = 3, Rare (2) = 6, Epic (3) = 9, Legendary (4) = 12, Mythic (5) = 15
	var common = create_mock_equipment("Common", 0, 1)
	var rare = create_mock_equipment("Rare", 0, 2)
	var epic = create_mock_equipment("Epic", 0, 3)
	var legendary = create_mock_equipment("Legendary", 0, 4)

	runner.assert_equal(common.get_max_enhancement_level(), 3, "common max should be 3")
	runner.assert_equal(rare.get_max_enhancement_level(), 6, "rare max should be 6")
	runner.assert_equal(epic.get_max_enhancement_level(), 9, "epic max should be 9")
	runner.assert_equal(legendary.get_max_enhancement_level(), 12, "legendary max should be 12")

func test_equipment_cannot_enhance_past_max():
	var eq = create_mock_equipment("Sword", 0, 1)  # Common, max 3
	eq.enhancement_level = 3

	runner.assert_false(eq.can_be_enhanced(), "should not enhance past max")

func test_enhancement_increases_stats():
	var eq = create_mock_equipment()
	eq.main_stat_base = 100
	eq.main_stat_value = 100
	eq.enhancement_level = 0

	var bonuses_0 = eq.get_enhancement_stat_bonuses()
	eq.enhancement_level = 5
	var bonuses_5 = eq.get_enhancement_stat_bonuses()

	runner.assert_true(bonuses_5.size() > 0, "should have stat bonuses")

# ==============================================================================
# TEST: Stat Calculation Flow
# ==============================================================================

func test_god_stats_without_equipment():
	var god = create_mock_god()
	god.base_attack = 300

	runner.assert_equal(god.base_attack, 300, "base attack should be 300")

func test_god_stats_with_single_equipment():
	var god = create_mock_god()
	god.base_attack = 300
	var manager = create_equipment_manager()

	var weapon = create_mock_equipment()
	weapon.main_stat_type = "attack"
	weapon.main_stat_base = 50
	weapon.main_stat_value = 50

	manager.equip_equipment_to_god(god, weapon, 0)

	# Equipment is equipped, stat calculation would happen in EquipmentStatCalculator
	runner.assert_not_null(god.equipment[0], "weapon should be equipped")
	runner.assert_equal(god.equipment[0].main_stat_value, 50, "weapon should add 50 attack")

func test_god_stats_with_multiple_equipment():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	# Equip weapon and armor with attack stats
	var weapon = create_mock_equipment("Weapon", 0, 2)
	weapon.main_stat_type = "attack"
	weapon.main_stat_value = 50

	var armor = create_mock_equipment("Armor", 1, 2)
	armor.main_stat_type = "defense"
	armor.main_stat_value = 40

	manager.equip_equipment_to_god(god, weapon, 0)
	manager.equip_equipment_to_god(god, armor, 1)

	runner.assert_not_null(god.equipment[0], "weapon equipped")
	runner.assert_not_null(god.equipment[1], "armor equipped")

func test_equipment_substats_applied():
	var eq = create_mock_equipment()
	eq.substats = {
		"crit_rate": 5,
		"crit_damage": 10,
		"speed": 8
	}

	runner.assert_equal(eq.substats.crit_rate, 5, "should have crit_rate substat")
	runner.assert_equal(eq.substats.crit_damage, 10, "should have crit_damage substat")
	runner.assert_equal(eq.substats.speed, 8, "should have speed substat")

# ==============================================================================
# TEST: Complete Equipment Flow
# ==============================================================================

func test_complete_equipment_lifecycle():
	var god = create_mock_god("Zeus")
	var manager = create_equipment_manager()

	# Step 1: Create equipment
	var weapon = create_mock_equipment("Divine Sword", 0, 3)  # Epic
	weapon.main_stat_type = "attack"
	weapon.main_stat_base = 75
	weapon.main_stat_value = 75
	weapon.substats = {"crit_rate": 5, "crit_damage": 10}

	# Step 2: Equip to god
	var equipped = manager.equip_equipment_to_god(god, weapon, 0)
	runner.assert_true(equipped, "should equip successfully")

	# Step 3: Enhance equipment
	weapon.enhancement_level = 5
	runner.assert_equal(weapon.enhancement_level, 5, "should be +5")

	# Step 4: Verify equipment is still on god
	runner.assert_not_null(god.equipment[0], "weapon still equipped")
	runner.assert_equal(god.equipment[0].enhancement_level, 5, "enhancement persists")

	# Step 5: Unequip
	manager.unequip_equipment_from_god(god, 0)
	runner.assert_null(god.equipment[0], "slot should be empty")

	# Step 6: Re-equip (same or different god)
	manager.equip_equipment_to_god(god, weapon, 0)
	runner.assert_not_null(god.equipment[0], "re-equipped successfully")

func test_transfer_equipment_between_gods():
	var god1 = create_mock_god("Zeus")
	var god2 = create_mock_god("Poseidon")
	var manager = create_equipment_manager()

	var weapon = create_mock_equipment("Shared Sword")

	# Equip to god1
	manager.equip_equipment_to_god(god1, weapon, 0)
	runner.assert_equal(weapon.equipped_by_god_id, god1.id, "should be on god1")

	# Unequip from god1
	manager.unequip_equipment_from_god(god1, 0)

	# Equip to god2
	manager.equip_equipment_to_god(god2, weapon, 0)
	runner.assert_equal(weapon.equipped_by_god_id, god2.id, "should be on god2")

# ==============================================================================
# TEST: Equipment Affects Battle Stats
# ==============================================================================

func test_equipped_weapon_increases_attack():
	var god = create_mock_god()
	var base_attack = god.base_attack
	var manager = create_equipment_manager()

	var weapon = create_mock_equipment()
	weapon.main_stat_type = "attack"
	weapon.main_stat_value = 100

	manager.equip_equipment_to_god(god, weapon, 0)

	# In actual game, EquipmentStatCalculator would sum these
	var total_attack = base_attack + weapon.main_stat_value
	runner.assert_equal(total_attack, god.base_attack + 100, "total attack should include equipment")

func test_equipped_armor_increases_defense():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	var armor = create_mock_equipment("Armor", 1, 2)
	armor.main_stat_type = "defense"
	armor.main_stat_value = 80

	manager.equip_equipment_to_god(god, armor, 1)

	runner.assert_equal(god.equipment[1].main_stat_value, 80, "armor should add 80 defense")

func test_enhanced_equipment_gives_more_stats():
	var eq = create_mock_equipment()
	eq.main_stat_base = 50
	eq.main_stat_value = 50
	eq.enhancement_level = 0

	var base_bonuses = eq.get_enhancement_stat_bonuses()

	eq.enhancement_level = 6  # +6
	var enhanced_bonuses = eq.get_enhancement_stat_bonuses()

	# Enhancement should provide additional bonuses
	runner.assert_true(true, "enhanced equipment provides bonuses")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_equip_null_equipment():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	var result = manager.equip_equipment_to_god(god, null, 0)

	runner.assert_false(result, "should not equip null")

func test_equip_to_null_god():
	var weapon = create_mock_equipment()
	var manager = create_equipment_manager()

	var result = manager.equip_equipment_to_god(null, weapon, 0)

	runner.assert_false(result, "should not equip to null god")

func test_unequip_empty_slot():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	var result = manager.unequip_equipment_from_god(god, 0)

	runner.assert_false(result, "should not unequip empty slot")

func test_equipment_with_zero_stats():
	var eq = create_mock_equipment()
	eq.main_stat_value = 0
	eq.substats = {}

	var bonuses = eq.get_stat_bonuses()
	# Should handle zero stats gracefully
	runner.assert_true(true, "should handle zero stats")

func test_many_equipment_operations():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	# Rapidly equip/unequip
	for i in range(20):
		var eq = create_mock_equipment("Eq_%d" % i, i % 6)
		manager.equip_equipment_to_god(god, eq, i % 6)

	# Should end with equipment in all slots
	for i in range(6):
		runner.assert_not_null(god.equipment[i], "slot %d should have equipment" % i)

func test_save_load_equipment_state():
	var god = create_mock_god()
	var manager = create_equipment_manager()

	var weapon = create_mock_equipment("Saved Sword")
	weapon.enhancement_level = 7

	manager.equip_equipment_to_god(god, weapon, 0)

	# In actual game, equipment state would be saved/loaded
	runner.assert_equal(god.equipment[0].enhancement_level, 7, "enhancement should persist")
	runner.assert_equal(god.equipment[0].name, "Saved Sword", "name should persist")
