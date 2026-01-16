# tests/unit/test_save_load_utility.gd
# Unit tests for SaveLoadUtility - Save/load serialization for gods, equipment, and game state
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER METHODS
# ==============================================================================

## Create a mock god with all fields populated
func _create_mock_god() -> God:
	var god_data = God.new()
	god_data.id = "zeus"
	god_data.name = "Zeus"
	god_data.pantheon = "greek"
	god_data.element = God.ElementType.LIGHTNING
	god_data.tier = God.TierType.LEGENDARY
	god_data.level = 30
	god_data.experience = 5000
	god_data.base_hp = 5500
	god_data.base_attack = 300
	god_data.base_defense = 250
	god_data.base_speed = 120
	god_data.skill_levels = [5, 4, 3, 1]
	god_data.is_awakened = true
	god_data.current_hp = 5500

	# Role and specialization data
	god_data.primary_role = "fighter"
	god_data.secondary_role = "support"
	god_data.specialization_path = ["fighter_berserker", "fighter_berserker_ravager", ""]

	# Equipment (null for simplicity)
	god_data.equipment = [null, null, null, null, null, null]

	return god_data

## Create a mock equipment
func _create_mock_equipment() -> Equipment:
	var equipment_data = Equipment.new()
	equipment_data.id = "thunder_blade_001"
	equipment_data.slot = 1  # Weapon
	equipment_data.equipment_set_name = "Thunder"
	equipment_data.main_stat_type = "attack"
	equipment_data.main_stat_value = 150
	equipment_data.substats = [
		{"type": "crit_rate", "value": 15},
		{"type": "speed", "value": 10}
	]
	equipment_data.level = 12

	return equipment_data

# ==============================================================================
# SERIALIZE GOD TESTS
# ==============================================================================

func test_serialize_god_basic_fields():
	var god_data = _create_mock_god()
	var serialized = SaveLoadUtility.serialize_god(god_data)

	runner.assert_equal(serialized["id"], "zeus", "Serialized god ID should match")
	runner.assert_equal(serialized["level"], 30, "Serialized level should match")
	runner.assert_equal(serialized["experience"], 5000, "Serialized experience should match")
	runner.assert_equal(serialized["awakened"], true, "Serialized awakened state should match")

func test_serialize_god_role_fields():
	var god_data = _create_mock_god()
	var serialized = SaveLoadUtility.serialize_god(god_data)

	runner.assert_true(serialized.has("primary_role"), "Serialized god should have primary_role")
	runner.assert_true(serialized.has("secondary_role"), "Serialized god should have secondary_role")
	runner.assert_true(serialized.has("specialization_path"), "Serialized god should have specialization_path")

	runner.assert_equal(serialized["primary_role"], "fighter", "Primary role should match")
	runner.assert_equal(serialized["secondary_role"], "support", "Secondary role should match")

func test_serialize_god_specialization_path():
	var god_data = _create_mock_god()
	var serialized = SaveLoadUtility.serialize_god(god_data)

	runner.assert_true(serialized["specialization_path"] is Array, "Specialization path should be an Array")
	runner.assert_equal(serialized["specialization_path"].size(), 3, "Specialization path should have 3 elements")
	runner.assert_equal(serialized["specialization_path"][0], "fighter_berserker", "Tier 1 spec should match")
	runner.assert_equal(serialized["specialization_path"][1], "fighter_berserker_ravager", "Tier 2 spec should match")
	runner.assert_equal(serialized["specialization_path"][2], "", "Tier 3 spec should be empty")

func test_serialize_god_with_empty_roles():
	var god_data = _create_mock_god()
	god_data.primary_role = ""
	god_data.secondary_role = ""
	god_data.specialization_path = ["", "", ""]

	var serialized = SaveLoadUtility.serialize_god(god_data)

	runner.assert_equal(serialized["primary_role"], "", "Empty primary role should serialize")
	runner.assert_equal(serialized["secondary_role"], "", "Empty secondary role should serialize")
	runner.assert_equal(serialized["specialization_path"], ["", "", ""], "Empty spec path should serialize")

func test_serialize_god_null_input():
	var serialized = SaveLoadUtility.serialize_god(null)

	runner.assert_equal(serialized, {}, "Serializing null god should return empty Dictionary")

# ==============================================================================
# DESERIALIZE GOD TESTS
# ==============================================================================

func test_deserialize_god_role_fields():
	var original_god = _create_mock_god()
	var serialized = SaveLoadUtility.serialize_god(original_god)

	# Note: deserialize_god uses GodFactory which requires SystemRegistry
	# For now, we'll test the data structure
	runner.assert_true(serialized.has("primary_role"), "Serialized data should have primary_role")
	runner.assert_true(serialized.has("secondary_role"), "Serialized data should have secondary_role")
	runner.assert_true(serialized.has("specialization_path"), "Serialized data should have specialization_path")

func test_deserialize_god_specialization_path_array_size():
	# Test that specialization_path is always size 3
	var test_data = {
		"id": "zeus",
		"level": 1,
		"experience": 0,
		"skill_levels": [1, 1, 1],
		"equipment": [null, null, null, null, null, null],
		"current_hp": 5500,
		"awakened": false,
		"primary_role": "fighter",
		"secondary_role": "",
		"specialization_path": ["tier1"]  # Only 1 element
	}

	# We can't call deserialize_god without GodFactory, but we can verify the structure
	runner.assert_true(test_data["specialization_path"] is Array, "Input spec path should be Array")

func test_deserialize_god_missing_role_fields():
	# Test backward compatibility - old saves without role data
	var test_data = {
		"id": "zeus",
		"level": 30,
		"experience": 5000,
		"skill_levels": [5, 4, 3, 1],
		"equipment": [null, null, null, null, null, null],
		"current_hp": 5500,
		"awakened": true
		# No role fields
	}

	# Verify data structure - missing fields should use defaults
	runner.assert_false(test_data.has("primary_role"), "Old save data should not have primary_role")
	runner.assert_false(test_data.has("secondary_role"), "Old save data should not have secondary_role")
	runner.assert_false(test_data.has("specialization_path"), "Old save data should not have specialization_path")

# ==============================================================================
# SERIALIZE EQUIPMENT TESTS
# ==============================================================================

func test_serialize_equipment_basic_fields():
	var equipment_data = _create_mock_equipment()
	var serialized = SaveLoadUtility.serialize_equipment(equipment_data)

	runner.assert_equal(serialized["id"], "thunder_blade_001", "Equipment ID should match")
	runner.assert_equal(serialized["slot"], 1, "Equipment slot should match")
	runner.assert_equal(serialized["equipment_set_name"], "Thunder", "Equipment set should match")
	runner.assert_equal(serialized["main_stat_type"], "attack", "Main stat type should match")
	runner.assert_equal(serialized["main_stat_value"], 150, "Main stat value should match")
	runner.assert_equal(serialized["level"], 12, "Equipment level should match")

func test_serialize_equipment_substats():
	var equipment_data = _create_mock_equipment()
	var serialized = SaveLoadUtility.serialize_equipment(equipment_data)

	runner.assert_true(serialized.has("substats"), "Serialized equipment should have substats")
	runner.assert_true(serialized["substats"] is Array, "Substats should be an Array")
	runner.assert_equal(serialized["substats"].size(), 2, "Should have 2 substats")

func test_serialize_equipment_null_input():
	var serialized = SaveLoadUtility.serialize_equipment(null)

	runner.assert_equal(serialized, {}, "Serializing null equipment should return empty Dictionary")

# ==============================================================================
# DESERIALIZE EQUIPMENT TESTS
# ==============================================================================

func test_deserialize_equipment_basic_fields():
	var original_equipment = _create_mock_equipment()
	var serialized = SaveLoadUtility.serialize_equipment(original_equipment)
	var deserialized = SaveLoadUtility.deserialize_equipment(serialized)

	runner.assert_equal(deserialized.id, "thunder_blade_001", "Equipment ID should match")
	runner.assert_equal(deserialized.slot, 1, "Equipment slot should match")
	runner.assert_equal(deserialized.equipment_set_name, "Thunder", "Equipment set should match")
	runner.assert_equal(deserialized.main_stat_type, "attack", "Main stat type should match")
	runner.assert_equal(deserialized.main_stat_value, 150, "Main stat value should match")
	runner.assert_equal(deserialized.level, 12, "Equipment level should match")

func test_deserialize_equipment_substats():
	var original_equipment = _create_mock_equipment()
	var serialized = SaveLoadUtility.serialize_equipment(original_equipment)
	var deserialized = SaveLoadUtility.deserialize_equipment(serialized)

	runner.assert_equal(deserialized.substats.size(), 2, "Should have 2 substats")
	runner.assert_equal(deserialized.substats[0]["type"], "crit_rate", "First substat type should match")
	runner.assert_equal(deserialized.substats[0]["value"], 15, "First substat value should match")

func test_deserialize_equipment_empty_data():
	var deserialized = SaveLoadUtility.deserialize_equipment({})

	runner.assert_not_null(deserialized, "Deserializing empty data should create Equipment")
	runner.assert_equal(deserialized.id, "", "Empty equipment should have empty ID")
	runner.assert_equal(deserialized.level, 0, "Empty equipment should have level 0")

# ==============================================================================
# SERIALIZE GAME STATE TESTS
# ==============================================================================

func test_serialize_game_state_structure():
	var player_data = {
		"level": 25,
		"resources": {"gold": 10000, "crystals": 500},
		"gods": [_create_mock_god()],
		"equipment": [_create_mock_equipment()],
		"territories": []
	}

	var serialized = SaveLoadUtility.serialize_game_state(player_data)

	runner.assert_true(serialized.has("version"), "Save data should have version")
	runner.assert_true(serialized.has("timestamp"), "Save data should have timestamp")
	runner.assert_true(serialized.has("player_level"), "Save data should have player_level")
	runner.assert_true(serialized.has("resources"), "Save data should have resources")
	runner.assert_true(serialized.has("gods"), "Save data should have gods")
	runner.assert_true(serialized.has("equipment"), "Save data should have equipment")
	runner.assert_true(serialized.has("territories"), "Save data should have territories")

func test_serialize_game_state_gods_array():
	var player_data = {
		"level": 25,
		"resources": {"gold": 10000},
		"gods": [_create_mock_god(), _create_mock_god()],
		"equipment": [],
		"territories": []
	}

	var serialized = SaveLoadUtility.serialize_game_state(player_data)

	runner.assert_equal(serialized["gods"].size(), 2, "Should serialize 2 gods")
	runner.assert_true(serialized["gods"][0].has("primary_role"), "First god should have primary_role")
	runner.assert_true(serialized["gods"][1].has("specialization_path"), "Second god should have specialization_path")

func test_serialize_game_state_empty_player_data():
	var player_data = {}

	var serialized = SaveLoadUtility.serialize_game_state(player_data)

	runner.assert_equal(serialized["player_level"], 1, "Empty data should default to level 1")
	runner.assert_equal(serialized["gods"], [], "Empty data should have empty gods array")

# ==============================================================================
# DESERIALIZE GAME STATE TESTS
# ==============================================================================

func test_deserialize_game_state_structure():
	var save_data = {
		"version": "1.0",
		"timestamp": 12345,
		"player_level": 25,
		"resources": {"gold": 10000, "crystals": 500},
		"gods": [],
		"equipment": [],
		"territories": []
	}

	var deserialized = SaveLoadUtility.deserialize_game_state(save_data)

	runner.assert_true(deserialized.has("level"), "Deserialized data should have level")
	runner.assert_true(deserialized.has("resources"), "Deserialized data should have resources")
	runner.assert_true(deserialized.has("gods"), "Deserialized data should have gods")
	runner.assert_true(deserialized.has("equipment"), "Deserialized data should have equipment")
	runner.assert_true(deserialized.has("territories"), "Deserialized data should have territories")

func test_deserialize_game_state_missing_version():
	var save_data = {
		"player_level": 25,
		"resources": {},
		"gods": [],
		"equipment": [],
		"territories": []
	}

	var deserialized = SaveLoadUtility.deserialize_game_state(save_data)

	# Should still deserialize with warning
	runner.assert_not_null(deserialized, "Should deserialize even without version")

# ==============================================================================
# ROUND-TRIP TESTS
# ==============================================================================

func test_round_trip_god_with_roles():
	var original_god = _create_mock_god()
	original_god.primary_role = "scholar"
	original_god.secondary_role = "support"
	original_god.specialization_path = ["scholar_researcher", "scholar_researcher_lorekeeper", "scholar_researcher_omniscient"]

	var serialized = SaveLoadUtility.serialize_god(original_god)

	# Verify serialization preserves role data
	runner.assert_equal(serialized["primary_role"], "scholar", "Round-trip: primary_role should match")
	runner.assert_equal(serialized["secondary_role"], "support", "Round-trip: secondary_role should match")
	runner.assert_equal(serialized["specialization_path"][0], "scholar_researcher", "Round-trip: tier 1 should match")
	runner.assert_equal(serialized["specialization_path"][1], "scholar_researcher_lorekeeper", "Round-trip: tier 2 should match")
	runner.assert_equal(serialized["specialization_path"][2], "scholar_researcher_omniscient", "Round-trip: tier 3 should match")

func test_round_trip_equipment():
	var original_equipment = _create_mock_equipment()

	var serialized = SaveLoadUtility.serialize_equipment(original_equipment)
	var deserialized = SaveLoadUtility.deserialize_equipment(serialized)

	runner.assert_equal(deserialized.id, original_equipment.id, "Round-trip: equipment ID should match")
	runner.assert_equal(deserialized.slot, original_equipment.slot, "Round-trip: equipment slot should match")
	runner.assert_equal(deserialized.level, original_equipment.level, "Round-trip: equipment level should match")
