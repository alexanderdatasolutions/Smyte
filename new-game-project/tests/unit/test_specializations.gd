# test_specializations.gd - Unit tests for Specialization data class
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_specialization_data() -> Dictionary:
	return {
		"id": "test_spec",
		"name": "Test Specialization",
		"description": "A specialization for testing",
		"type": "combat",
		"icon_path": "res://assets/icons/specs/test.png",
		"required_level": 20,
		"required_traits": ["warrior"],
		"blocked_traits": ["pacifist"],
		"required_pantheon": "",
		"prerequisite_specialization_id": "",
		"stat_bonuses": {"attack": 0.15, "defense": 0.10},
		"task_bonuses": {"train": 0.25, "defend": 0.20},
		"skill_xp_bonuses": {"combat": 0.20},
		"unlocked_ability_ids": ["power_strike"],
		"enhanced_ability_ids": {"basic_attack": 2}
	}

func create_mock_god() -> God:
	var god = God.new()
	god.id = "god_" + str(randi() % 10000)
	god.name = "Test God"
	god.level = 25
	god.pantheon = "greek"
	god.innate_traits = ["warrior"]
	god.learned_traits = []
	return god

# ==============================================================================
# TEST: Specialization Data Class - Basic Properties
# ==============================================================================

func test_specialization_from_dict_creates_spec():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_not_null(spec, "should create specialization from dict")
	runner.assert_equal(spec.id, "test_spec", "should have correct id")
	runner.assert_equal(spec.name, "Test Specialization", "should have correct name")

func test_specialization_from_dict_parses_type():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.type, Specialization.SpecializationType.COMBAT, "should parse combat type")

func test_specialization_from_dict_parses_requirements():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.required_level, 20, "should parse required level")
	runner.assert_equal(spec.required_traits.size(), 1, "should parse required traits")
	runner.assert_equal(spec.blocked_traits.size(), 1, "should parse blocked traits")

func test_specialization_from_dict_parses_bonuses():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses.size(), 2, "should have 2 stat bonuses")
	runner.assert_equal(spec.stat_bonuses["attack"], 0.15, "should parse attack bonus")
	runner.assert_equal(spec.task_bonuses.size(), 2, "should have 2 task bonuses")

func test_specialization_from_dict_parses_abilities():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.unlocked_ability_ids.size(), 1, "should have 1 unlocked ability")
	runner.assert_true("power_strike" in spec.unlocked_ability_ids, "should include power_strike")

# ==============================================================================
# TEST: Specialization Type Parsing
# ==============================================================================

func test_specialization_parses_combat_type():
	var data = create_mock_specialization_data()
	data["type"] = "combat"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.type, Specialization.SpecializationType.COMBAT, "should parse combat")

func test_specialization_parses_production_type():
	var data = create_mock_specialization_data()
	data["type"] = "production"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.type, Specialization.SpecializationType.PRODUCTION, "should parse production")

func test_specialization_parses_support_type():
	var data = create_mock_specialization_data()
	data["type"] = "support"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.type, Specialization.SpecializationType.SUPPORT, "should parse support")

func test_specialization_parses_hybrid_type():
	var data = create_mock_specialization_data()
	data["type"] = "hybrid"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.type, Specialization.SpecializationType.HYBRID, "should parse hybrid")

# ==============================================================================
# TEST: God Eligibility
# ==============================================================================

func test_specialization_can_god_specialize_with_null():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)

	runner.assert_false(spec.can_god_specialize(null), "should return false for null god")

func test_specialization_can_god_specialize_level_requirement():
	var data = create_mock_specialization_data()
	data["required_level"] = 20
	data["required_traits"] = []
	var spec = Specialization.from_dict(data)

	var god_low = create_mock_god()
	god_low.level = 15

	var god_high = create_mock_god()
	god_high.level = 25

	runner.assert_false(spec.can_god_specialize(god_low), "should reject low level god")
	runner.assert_true(spec.can_god_specialize(god_high), "should accept high level god")

func test_specialization_can_god_specialize_required_trait():
	var data = create_mock_specialization_data()
	data["required_traits"] = ["warrior"]
	var spec = Specialization.from_dict(data)

	var god_without = create_mock_god()
	god_without.innate_traits = ["scholar"]

	var god_with = create_mock_god()
	god_with.innate_traits = ["warrior"]

	runner.assert_false(spec.can_god_specialize(god_without), "should reject without trait")
	runner.assert_true(spec.can_god_specialize(god_with), "should accept with trait")

func test_specialization_can_god_specialize_blocked_trait():
	var data = create_mock_specialization_data()
	data["required_traits"] = []
	data["blocked_traits"] = ["pacifist"]
	var spec = Specialization.from_dict(data)

	var god = create_mock_god()
	god.learned_traits = ["pacifist"]

	runner.assert_false(spec.can_god_specialize(god), "should reject with blocked trait")

func test_specialization_can_god_specialize_pantheon():
	var data = create_mock_specialization_data()
	data["required_traits"] = []
	data["required_pantheon"] = "norse"
	var spec = Specialization.from_dict(data)

	var god_greek = create_mock_god()
	god_greek.pantheon = "greek"

	var god_norse = create_mock_god()
	god_norse.pantheon = "norse"

	runner.assert_false(spec.can_god_specialize(god_greek), "should reject wrong pantheon")
	runner.assert_true(spec.can_god_specialize(god_norse), "should accept correct pantheon")

func test_specialization_can_god_specialize_meets_all():
	var data = create_mock_specialization_data()
	data["required_traits"] = ["warrior"]
	data["blocked_traits"] = []
	var spec = Specialization.from_dict(data)

	var god = create_mock_god()
	god.level = 25
	god.innate_traits = ["warrior"]

	runner.assert_true(spec.can_god_specialize(god), "should accept eligible god")

# ==============================================================================
# TEST: String Conversions
# ==============================================================================

func test_specialization_get_type_string_combat():
	var data = create_mock_specialization_data()
	data["type"] = "combat"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.get_type_string(), "combat", "should return combat")

func test_specialization_get_type_string_production():
	var data = create_mock_specialization_data()
	data["type"] = "production"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.get_type_string(), "production", "should return production")

func test_specialization_get_type_string_support():
	var data = create_mock_specialization_data()
	data["type"] = "support"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.get_type_string(), "support", "should return support")

func test_specialization_get_type_string_hybrid():
	var data = create_mock_specialization_data()
	data["type"] = "hybrid"
	var spec = Specialization.from_dict(data)
	runner.assert_equal(spec.get_type_string(), "hybrid", "should return hybrid")

# ==============================================================================
# TEST: Serialization
# ==============================================================================

func test_specialization_to_dict_preserves_data():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["id"], data["id"], "should preserve id")
	runner.assert_equal(output["name"], data["name"], "should preserve name")
	runner.assert_equal(output["required_level"], data["required_level"], "should preserve level")

func test_specialization_to_dict_converts_type():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["type"], "combat", "should convert type to string")

func test_specialization_to_dict_preserves_bonuses():
	var data = create_mock_specialization_data()
	var spec = Specialization.from_dict(data)
	var output = spec.to_dict()

	runner.assert_equal(output["stat_bonuses"]["attack"], 0.15, "should preserve attack bonus")
	runner.assert_equal(output["task_bonuses"]["train"], 0.25, "should preserve task bonus")

func test_specialization_roundtrip_serialization():
	var data = create_mock_specialization_data()
	var spec1 = Specialization.from_dict(data)
	var output = spec1.to_dict()
	var spec2 = Specialization.from_dict(output)

	runner.assert_equal(spec1.id, spec2.id, "should roundtrip id")
	runner.assert_equal(spec1.required_level, spec2.required_level, "should roundtrip level")
	runner.assert_equal(spec1.stat_bonuses.size(), spec2.stat_bonuses.size(), "should roundtrip bonuses")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_specialization_from_dict_minimal():
	var data = {"id": "minimal"}
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.id, "minimal", "should handle minimal data")
	runner.assert_equal(spec.required_level, 20, "should default level to 20")

func test_specialization_from_dict_empty_requirements():
	var data = create_mock_specialization_data()
	data["required_traits"] = []
	data["blocked_traits"] = []
	data["required_pantheon"] = ""
	var spec = Specialization.from_dict(data)

	var god = create_mock_god()
	god.innate_traits = []

	runner.assert_true(spec.can_god_specialize(god), "should accept with no requirements")

func test_specialization_with_prerequisite():
	var data = create_mock_specialization_data()
	data["prerequisite_specialization_id"] = "basic_warrior"
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.prerequisite_specialization_id, "basic_warrior", "should parse prerequisite")

func test_specialization_negative_stat_bonus():
	var data = create_mock_specialization_data()
	data["stat_bonuses"] = {"attack": 0.25, "defense": -0.10}
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses["defense"], -0.10, "should handle negative bonuses")

func test_specialization_empty_bonuses():
	var data = create_mock_specialization_data()
	data["stat_bonuses"] = {}
	data["task_bonuses"] = {}
	data["skill_xp_bonuses"] = {}
	var spec = Specialization.from_dict(data)

	runner.assert_equal(spec.stat_bonuses.size(), 0, "should handle empty stat bonuses")
	runner.assert_equal(spec.task_bonuses.size(), 0, "should handle empty task bonuses")
