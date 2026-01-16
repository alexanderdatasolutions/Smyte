# test_equipment_manager.gd - Unit tests for scripts/systems/equipment/EquipmentManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_god(god_id: String = "", god_name: String = "TestGod") -> God:
	"""Create a mock God for testing"""
	var god = God.new()
	god.id = god_id if god_id != "" else "god_" + str(randi() % 10000)
	god.name = god_name
	god.pantheon = "greek"
	god.element = God.ElementType.FIRE
	god.tier = God.TierType.RARE
	god.level = 1
	god.base_hp = 1000
	god.base_attack = 200
	god.base_defense = 100
	god.base_speed = 100
	god.equipment = [null, null, null, null, null, null]  # 6 slots
	return god

func create_mock_equipment(equipment_id: String = "", eq_type: Equipment.EquipmentType = Equipment.EquipmentType.WEAPON) -> Equipment:
	"""Create a mock Equipment for testing"""
	var eq = Equipment.new()
	eq.equipment_id = equipment_id if equipment_id != "" else "eq_" + str(randi() % 10000)
	eq.name = "Test Equipment"
	eq.equipment_type = eq_type
	eq.rarity = Equipment.Rarity.RARE
	eq.enhancement_level = 0
	eq.main_stat_type = "attack"
	eq.main_stat_base = 50
	eq.main_stat_value = 50
	eq.substats = {}
	return eq

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_equipment_equipped_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("equipment_equipped"), "should have equipment_equipped signal")

func test_equipment_unequipped_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("equipment_unequipped"), "should have equipment_unequipped signal")

func test_equipment_enhanced_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("equipment_enhanced"), "should have equipment_enhanced signal")

func test_equipment_crafted_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("equipment_crafted"), "should have equipment_crafted signal")

func test_socket_unlocked_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("socket_unlocked"), "should have socket_unlocked signal")

func test_gem_socketed_signal_exists():
	var manager = EquipmentManager.new()
	runner.assert_true(manager.has_signal("gem_socketed"), "should have gem_socketed signal")

# ==============================================================================
# TEST: Equip Equipment to God
# ==============================================================================

func test_equip_equipment_to_god_success():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var equipment = create_mock_equipment("sword_001")

	var result = manager.equip_equipment_to_god(god, equipment, 0)

	runner.assert_true(result, "equip should succeed")
	runner.assert_not_null(god.equipment[0], "slot 0 should have equipment")

func test_equip_equipment_updates_god_equipment_array():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var equipment = create_mock_equipment("sword_001")

	manager.equip_equipment_to_god(god, equipment, 0)

	runner.assert_equal(god.equipment[0], equipment, "slot should contain the equipment")

func test_equip_equipment_sets_equipped_by_god_id():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var equipment = create_mock_equipment("sword_001")

	manager.equip_equipment_to_god(god, equipment, 0)

	runner.assert_equal(equipment.equipped_by_god_id, "zeus_001", "equipment should reference god id")

func test_equip_equipment_null_god_returns_false():
	var manager = EquipmentManager.new()
	var equipment = create_mock_equipment()

	var result = manager.equip_equipment_to_god(null, equipment, 0)
	runner.assert_false(result, "equip with null god should fail")

func test_equip_equipment_null_equipment_returns_false():
	var manager = EquipmentManager.new()
	var god = create_mock_god()

	var result = manager.equip_equipment_to_god(god, null, 0)
	runner.assert_false(result, "equip with null equipment should fail")

func test_equip_equipment_different_slots():
	var manager = EquipmentManager.new()
	var god = create_mock_god()

	for slot in range(6):
		var equipment = create_mock_equipment("eq_" + str(slot))
		var result = manager.equip_equipment_to_god(god, equipment, slot)
		runner.assert_true(result, "equip to slot %d should succeed" % slot)

	runner.assert_equal(god.equipment.size(), 6, "should have 6 equipped items")
	for slot in range(6):
		runner.assert_not_null(god.equipment[slot], "slot %d should not be null" % slot)

func test_equip_equipment_replaces_existing():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var old_equipment = create_mock_equipment("old_sword")
	var new_equipment = create_mock_equipment("new_sword")

	manager.equip_equipment_to_god(god, old_equipment, 0)
	manager.equip_equipment_to_god(god, new_equipment, 0)

	runner.assert_equal(god.equipment[0], new_equipment, "slot should have new equipment")
	runner.assert_equal(old_equipment.equipped_by_god_id, "", "old equipment should be unequipped")

# ==============================================================================
# TEST: Unequip Equipment from God
# ==============================================================================

func test_unequip_equipment_from_god_success():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var equipment = create_mock_equipment("sword_001")

	manager.equip_equipment_to_god(god, equipment, 0)
	var result = manager.unequip_equipment_from_god(god, 0)

	runner.assert_true(result, "unequip should succeed")
	runner.assert_null(god.equipment[0], "slot should be null after unequip")

func test_unequip_clears_equipped_by_god_id():
	var manager = EquipmentManager.new()
	var god = create_mock_god("zeus_001")
	var equipment = create_mock_equipment("sword_001")

	manager.equip_equipment_to_god(god, equipment, 0)
	manager.unequip_equipment_from_god(god, 0)

	runner.assert_equal(equipment.equipped_by_god_id, "", "equipped_by_god_id should be cleared")

func test_unequip_null_god_returns_false():
	var manager = EquipmentManager.new()

	var result = manager.unequip_equipment_from_god(null, 0)
	runner.assert_false(result, "unequip with null god should fail")

func test_unequip_invalid_slot_returns_false():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	god.equipment = [null, null, null, null, null, null]

	var result = manager.unequip_equipment_from_god(god, 10)
	runner.assert_false(result, "unequip from invalid slot should fail")

func test_unequip_empty_slot_returns_false():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	god.equipment = [null, null, null, null, null, null]

	var result = manager.unequip_equipment_from_god(god, 0)
	runner.assert_false(result, "unequip from empty slot should fail")

# ==============================================================================
# TEST: Get Equipped Equipment
# ==============================================================================

func test_get_equipped_equipment_returns_array():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	god.equipment = [null, null, null, null, null, null]

	var equipped = manager.get_equipped_equipment(god)
	runner.assert_equal(equipped.size(), 6, "should return equipment array")

func test_get_equipped_equipment_null_god_returns_empty():
	var manager = EquipmentManager.new()

	var equipped = manager.get_equipped_equipment(null)
	runner.assert_equal(equipped.size(), 0, "should return empty for null god")

func test_get_equipped_equipment_contains_equipped_items():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	var equipment = create_mock_equipment("sword_001")

	manager.equip_equipment_to_god(god, equipment, 0)
	var equipped = manager.get_equipped_equipment(god)

	runner.assert_equal(equipped[0], equipment, "should contain equipped item")

# ==============================================================================
# TEST: Equipment Slot Type Count (6 slots)
# ==============================================================================

func test_six_equipment_slots():
	var manager = EquipmentManager.new()
	var god = create_mock_god()

	# Equip to all 6 slots
	for i in range(6):
		var eq = create_mock_equipment("eq_" + str(i))
		manager.equip_equipment_to_god(god, eq, i)

	var equipped = manager.get_equipped_equipment(god)
	var non_null_count = 0
	for item in equipped:
		if item != null:
			non_null_count += 1

	runner.assert_equal(non_null_count, 6, "should have 6 equipment slots")

# ==============================================================================
# TEST: Equipment Type Enum Values
# ==============================================================================

func test_equipment_type_weapon_value():
	runner.assert_equal(Equipment.EquipmentType.WEAPON, 0, "WEAPON should be 0")

func test_equipment_type_armor_value():
	runner.assert_equal(Equipment.EquipmentType.ARMOR, 1, "ARMOR should be 1")

func test_equipment_type_helm_value():
	runner.assert_equal(Equipment.EquipmentType.HELM, 2, "HELM should be 2")

func test_equipment_type_boots_value():
	runner.assert_equal(Equipment.EquipmentType.BOOTS, 3, "BOOTS should be 3")

func test_equipment_type_amulet_value():
	runner.assert_equal(Equipment.EquipmentType.AMULET, 4, "AMULET should be 4")

func test_equipment_type_ring_value():
	runner.assert_equal(Equipment.EquipmentType.RING, 5, "RING should be 5")

# ==============================================================================
# TEST: Public API Methods
# ==============================================================================

func test_get_public_api_returns_array():
	var manager = EquipmentManager.new()

	var api = manager.get_public_api()
	runner.assert_true(api is Array, "should return array")
	runner.assert_true(api.size() > 0, "should have API methods listed")

func test_get_public_api_contains_key_methods():
	var manager = EquipmentManager.new()

	var api = manager.get_public_api()

	runner.assert_true("add_equipment_to_inventory" in api, "should list add_equipment_to_inventory")
	runner.assert_true("equip_equipment_to_god" in api, "should list equip_equipment_to_god")
	runner.assert_true("unequip_equipment_from_god" in api, "should list unequip_equipment_from_god")
	runner.assert_true("enhance_equipment" in api, "should list enhance_equipment")
	runner.assert_true("craft_equipment" in api, "should list craft_equipment")

# ==============================================================================
# TEST: Equipment Creation from Data
# ==============================================================================

func test_create_equipment_from_data():
	var manager = EquipmentManager.new()

	var data = {
		"id": "test_sword",
		"name": "Test Sword",
		"type": 0,
		"rarity": 2,
		"slot": 1,
		"level": 5,
		"main_stat_type": "attack",
		"main_stat_base": 100,
		"max_sockets": 2
	}

	var equipment = manager._create_equipment_from_data(data)

	runner.assert_not_null(equipment, "should create equipment")
	runner.assert_equal(equipment.id, "test_sword", "id should match")
	runner.assert_equal(equipment.name, "Test Sword", "name should match")

func test_create_equipment_from_data_with_substats():
	var manager = EquipmentManager.new()

	var data = {
		"id": "test_sword",
		"name": "Test Sword",
		"substats": {"crit_rate": 5, "crit_damage": 10}
	}

	var equipment = manager._create_equipment_from_data(data)

	runner.assert_equal(equipment.substats.crit_rate, 5, "crit_rate substat should be set")
	runner.assert_equal(equipment.substats.crit_damage, 10, "crit_damage substat should be set")

func test_create_equipment_from_data_with_sockets():
	var manager = EquipmentManager.new()

	var data = {
		"id": "test_ring",
		"name": "Test Ring",
		"max_sockets": 3
	}

	var equipment = manager._create_equipment_from_data(data)

	runner.assert_equal(equipment.max_sockets, 3, "max_sockets should be 3")
	runner.assert_equal(equipment.sockets.size(), 3, "should have 3 socket entries")
	runner.assert_true(equipment.sockets[0].unlocked, "first socket should be unlocked")
	runner.assert_false(equipment.sockets[1].unlocked, "second socket should be locked")
	runner.assert_false(equipment.sockets[2].unlocked, "third socket should be locked")

func test_create_equipment_from_empty_data():
	var manager = EquipmentManager.new()

	var equipment = manager._create_equipment_from_data({})

	runner.assert_not_null(equipment, "should create equipment even with empty data")
	runner.assert_equal(equipment.name, "Unknown Equipment", "should have default name")

# ==============================================================================
# TEST: Save/Load Equipment Data
# ==============================================================================

func test_save_equipment_data_structure():
	var manager = EquipmentManager.new()

	var save_data = manager.save_equipment_data()

	runner.assert_true(save_data.has("inventory"), "save data should have inventory")
	runner.assert_true(save_data.has("gems"), "save data should have gems")

# ==============================================================================
# TEST: Equipment Summary
# ==============================================================================

func test_get_equipment_summary_structure():
	var manager = EquipmentManager.new()

	var summary = manager.get_equipment_summary()

	runner.assert_true(summary.has("inventory"), "summary should have inventory")
	runner.assert_true(summary.has("crafting"), "summary should have crafting")
	runner.assert_true(summary.has("enhancement"), "summary should have enhancement")
	runner.assert_true(summary.has("sockets"), "summary should have sockets")

# ==============================================================================
# TEST: God Equipment Stats (without full system)
# ==============================================================================

func test_get_god_equipment_stats_null_god():
	var manager = EquipmentManager.new()

	var stats = manager.get_god_equipment_stats(null)
	runner.assert_equal(stats.size(), 0, "should return empty for null god")

func test_get_god_equipment_stats_structure():
	var manager = EquipmentManager.new()
	var god = create_mock_god()

	var stats = manager.get_god_equipment_stats(god)

	# Even without SystemRegistry, it should return a proper structure
	runner.assert_true(stats.has("equipped_count"), "should have equipped_count")
	runner.assert_true(stats.has("total_enhancement_level"), "should have total_enhancement_level")
	runner.assert_true(stats.has("socketed_gems"), "should have socketed_gems")
	runner.assert_true(stats.has("stat_bonuses"), "should have stat_bonuses")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_equip_creates_equipment_array_if_missing():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	god.equipment = null  # Clear equipment array

	var equipment = create_mock_equipment()
	var result = manager.equip_equipment_to_god(god, equipment, 0)

	runner.assert_true(result, "should succeed even if equipment array was null")
	runner.assert_not_null(god.equipment, "should create equipment array")
	runner.assert_equal(god.equipment.size(), 6, "should have 6 slots")

func test_equip_expands_equipment_array_if_too_small():
	var manager = EquipmentManager.new()
	var god = create_mock_god()
	god.equipment = [null, null]  # Only 2 slots

	var equipment = create_mock_equipment()
	var result = manager.equip_equipment_to_god(god, equipment, 5)

	runner.assert_true(result, "should succeed even if equipment array was small")
	runner.assert_equal(god.equipment.size(), 6, "should expand to 6 slots")

func test_multiple_equip_unequip_cycles():
	var manager = EquipmentManager.new()
	var god = create_mock_god()

	for i in range(10):
		var equipment = create_mock_equipment("cycle_eq_" + str(i))
		manager.equip_equipment_to_god(god, equipment, 0)
		runner.assert_not_null(god.equipment[0], "slot should have equipment after cycle %d equip" % i)

		manager.unequip_equipment_from_god(god, 0)
		runner.assert_null(god.equipment[0], "slot should be null after cycle %d unequip" % i)
