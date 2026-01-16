# test_collection_manager.gd - Unit tests for scripts/systems/collection/CollectionManager.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_collection_manager() -> CollectionManager:
	"""Create a fresh CollectionManager for testing"""
	var manager = CollectionManager.new()
	return manager

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
	god.base_crit_rate = 15
	god.base_crit_damage = 50
	return god

func create_mock_equipment(equipment_id: String = "") -> Equipment:
	"""Create a mock Equipment for testing"""
	var eq = Equipment.new()
	eq.equipment_id = equipment_id if equipment_id != "" else "eq_" + str(randi() % 10000)
	eq.name = "Test Equipment"
	eq.equipment_type = Equipment.EquipmentType.WEAPON
	eq.rarity = Equipment.Rarity.RARE
	return eq

# ==============================================================================
# TEST: Add God to Collection
# ==============================================================================

func test_add_god_to_collection():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")

	var result = manager.add_god(god)

	runner.assert_true(result, "add_god should return true on success")
	runner.assert_equal(manager.gods.size(), 1, "collection should have 1 god")

func test_add_god_returns_true():
	var manager = create_collection_manager()
	var god = create_mock_god()

	var result = manager.add_god(god)
	runner.assert_true(result, "add_god should return true on success")

func test_add_god_null_returns_false():
	var manager = create_collection_manager()

	var result = manager.add_god(null)
	runner.assert_false(result, "add_god with null should return false")

func test_add_multiple_gods():
	var manager = create_collection_manager()
	var god1 = create_mock_god("zeus_001", "Zeus")
	var god2 = create_mock_god("poseidon_001", "Poseidon")
	var god3 = create_mock_god("athena_001", "Athena")

	manager.add_god(god1)
	manager.add_god(god2)
	manager.add_god(god3)

	runner.assert_equal(manager.gods.size(), 3, "collection should have 3 gods")

# ==============================================================================
# TEST: Has God
# ==============================================================================

func test_has_god_returns_true_when_owned():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	runner.assert_true(manager.has_god("zeus_001"), "has_god should return true for owned god")

func test_has_god_returns_false_when_not_owned():
	var manager = create_collection_manager()

	runner.assert_false(manager.has_god("nonexistent_god"), "has_god should return false for unowned god")

func test_has_god_returns_false_for_empty_collection():
	var manager = create_collection_manager()

	runner.assert_false(manager.has_god("any_god"), "has_god should return false for empty collection")

# ==============================================================================
# TEST: Duplicate God Handling
# ==============================================================================

func test_add_duplicate_god_returns_false():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")

	manager.add_god(god)
	var result = manager.add_god(god)

	runner.assert_false(result, "adding duplicate god should return false")
	runner.assert_equal(manager.gods.size(), 1, "collection should still have only 1 god")

func test_add_god_with_same_id_returns_false():
	var manager = create_collection_manager()
	var god1 = create_mock_god("zeus_001", "Zeus")
	var god2 = create_mock_god("zeus_001", "Zeus Copy")

	manager.add_god(god1)
	var result = manager.add_god(god2)

	runner.assert_false(result, "adding god with same id should return false")
	runner.assert_equal(manager.gods.size(), 1, "collection should still have only 1 god")

# ==============================================================================
# TEST: Remove God from Collection
# ==============================================================================

func test_remove_god_from_collection():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var result = manager.remove_god(god)

	runner.assert_true(result, "remove_god should return true on success")
	runner.assert_equal(manager.gods.size(), 0, "collection should be empty after removal")

func test_remove_god_returns_false_when_not_in_collection():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")

	var result = manager.remove_god(god)
	runner.assert_false(result, "remove_god should return false when god not in collection")

func test_remove_god_null_returns_false():
	var manager = create_collection_manager()

	var result = manager.remove_god(null)
	runner.assert_false(result, "remove_god with null should return false")

func test_remove_god_updates_has_god():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	runner.assert_true(manager.has_god("zeus_001"), "should have god before removal")

	manager.remove_god(god)
	runner.assert_false(manager.has_god("zeus_001"), "should not have god after removal")

func test_remove_one_of_multiple_gods():
	var manager = create_collection_manager()
	var god1 = create_mock_god("zeus_001", "Zeus")
	var god2 = create_mock_god("poseidon_001", "Poseidon")
	manager.add_god(god1)
	manager.add_god(god2)

	manager.remove_god(god1)

	runner.assert_equal(manager.gods.size(), 1, "should have 1 god remaining")
	runner.assert_false(manager.has_god("zeus_001"), "zeus should be removed")
	runner.assert_true(manager.has_god("poseidon_001"), "poseidon should remain")

# ==============================================================================
# TEST: Get All Gods
# ==============================================================================

func test_get_all_gods_empty():
	var manager = create_collection_manager()

	var all_gods = manager.get_all_gods()
	runner.assert_equal(all_gods.size(), 0, "should return empty array for empty collection")

func test_get_all_gods_returns_copy():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var all_gods = manager.get_all_gods()
	runner.assert_equal(all_gods.size(), 1, "should return all gods")

	# Modify the returned array
	all_gods.clear()
	runner.assert_equal(manager.gods.size(), 1, "modifying copy should not affect original")

func test_get_all_gods_contains_correct_gods():
	var manager = create_collection_manager()
	var god1 = create_mock_god("zeus_001", "Zeus")
	var god2 = create_mock_god("poseidon_001", "Poseidon")
	manager.add_god(god1)
	manager.add_god(god2)

	var all_gods = manager.get_all_gods()

	runner.assert_equal(all_gods.size(), 2, "should return 2 gods")

	var ids = []
	for g in all_gods:
		ids.append(g.id)

	runner.assert_true(ids.has("zeus_001"), "should contain zeus")
	runner.assert_true(ids.has("poseidon_001"), "should contain poseidon")

# ==============================================================================
# TEST: Get God by ID
# ==============================================================================

func test_get_god_by_id_found():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var found = manager.get_god_by_id("zeus_001")

	runner.assert_not_null(found, "should find god by id")
	runner.assert_equal(found.id, "zeus_001", "found god should have correct id")
	runner.assert_equal(found.name, "Zeus", "found god should have correct name")

func test_get_god_by_id_not_found():
	var manager = create_collection_manager()

	var found = manager.get_god_by_id("nonexistent")
	runner.assert_null(found, "should return null for nonexistent god")

func test_get_god_by_id_returns_same_reference():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var found = manager.get_god_by_id("zeus_001")

	# Modify the found god
	found.level = 99

	# Check if original is affected
	runner.assert_equal(god.level, 99, "should return same reference")

# ==============================================================================
# TEST: Update God
# ==============================================================================

func test_update_god_success():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	god.level = 50
	var result = manager.update_god(god)

	runner.assert_true(result, "update_god should return true")

func test_update_god_not_in_collection_returns_false():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")

	var result = manager.update_god(god)
	runner.assert_false(result, "update_god should return false for god not in collection")

func test_update_god_null_returns_false():
	var manager = create_collection_manager()

	var result = manager.update_god(null)
	runner.assert_false(result, "update_god with null should return false")

# ==============================================================================
# TEST: God Equipment Management
# ==============================================================================

func test_get_god_equipment_empty():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var equipment = manager.get_god_equipment("zeus_001")
	runner.assert_equal(equipment.size(), 6, "god should have 6 equipment slots")

func test_get_god_equipment_nonexistent_god():
	var manager = create_collection_manager()

	var equipment = manager.get_god_equipment("nonexistent")
	runner.assert_equal(equipment.size(), 0, "should return empty array for nonexistent god")

func test_update_god_equipment():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var eq = create_mock_equipment("sword_001")
	var result = manager.update_god_equipment("zeus_001", 0, eq)

	runner.assert_true(result, "update_god_equipment should return true")

func test_update_god_equipment_nonexistent_god():
	var manager = create_collection_manager()
	var eq = create_mock_equipment()

	var result = manager.update_god_equipment("nonexistent", 0, eq)
	runner.assert_false(result, "should return false for nonexistent god")

func test_update_god_equipment_retrieval():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var eq = create_mock_equipment("sword_001")
	manager.update_god_equipment("zeus_001", 0, eq)

	var equipment = manager.get_god_equipment("zeus_001")
	runner.assert_not_null(equipment[0], "slot 0 should have equipment")
	runner.assert_equal(equipment[0].equipment_id, "sword_001", "should have correct equipment")

func test_update_god_equipment_multiple_slots():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var weapon = create_mock_equipment("weapon_001")
	var armor = create_mock_equipment("armor_001")
	var helm = create_mock_equipment("helm_001")

	manager.update_god_equipment("zeus_001", 0, weapon)
	manager.update_god_equipment("zeus_001", 1, armor)
	manager.update_god_equipment("zeus_001", 2, helm)

	var equipment = manager.get_god_equipment("zeus_001")
	runner.assert_equal(equipment[0].equipment_id, "weapon_001", "slot 0 should have weapon")
	runner.assert_equal(equipment[1].equipment_id, "armor_001", "slot 1 should have armor")
	runner.assert_equal(equipment[2].equipment_id, "helm_001", "slot 2 should have helm")

func test_update_god_equipment_can_set_null():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	var eq = create_mock_equipment()
	manager.update_god_equipment("zeus_001", 0, eq)
	manager.update_god_equipment("zeus_001", 0, null)

	var equipment = manager.get_god_equipment("zeus_001")
	runner.assert_null(equipment[0], "slot should be null after setting to null")

# ==============================================================================
# TEST: Lookup Index
# ==============================================================================

func test_gods_by_id_index_populated():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	runner.assert_true(manager.gods_by_id.has("zeus_001"), "gods_by_id should have entry")

func test_gods_by_id_index_cleared_on_remove():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)
	manager.remove_god(god)

	runner.assert_false(manager.gods_by_id.has("zeus_001"), "gods_by_id should not have entry after removal")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_add_many_gods():
	var manager = create_collection_manager()

	for i in range(100):
		var god = create_mock_god("god_" + str(i), "God " + str(i))
		manager.add_god(god)

	runner.assert_equal(manager.gods.size(), 100, "should handle 100 gods")

func test_remove_all_gods():
	var manager = create_collection_manager()
	var god1 = create_mock_god("zeus_001", "Zeus")
	var god2 = create_mock_god("poseidon_001", "Poseidon")
	manager.add_god(god1)
	manager.add_god(god2)

	manager.remove_god(god1)
	manager.remove_god(god2)

	runner.assert_equal(manager.gods.size(), 0, "collection should be empty")
	runner.assert_equal(manager.gods_by_id.size(), 0, "index should be empty")

func test_add_remove_add_same_god():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")

	manager.add_god(god)
	manager.remove_god(god)
	var result = manager.add_god(god)

	runner.assert_true(result, "should be able to re-add removed god")
	runner.assert_equal(manager.gods.size(), 1, "should have 1 god")

func test_collection_with_equipment_array():
	var manager = create_collection_manager()

	# Verify equipment array exists
	runner.assert_equal(manager.equipment.size(), 0, "equipment array should be initialized empty")

func test_get_god_after_modification():
	var manager = create_collection_manager()
	var god = create_mock_god("zeus_001", "Zeus")
	manager.add_god(god)

	# Modify god through collection
	var found = manager.get_god_by_id("zeus_001")
	found.level = 40
	found.name = "Modified Zeus"

	# Get again and verify changes persisted
	var found2 = manager.get_god_by_id("zeus_001")
	runner.assert_equal(found2.level, 40, "level change should persist")
	runner.assert_equal(found2.name, "Modified Zeus", "name change should persist")
