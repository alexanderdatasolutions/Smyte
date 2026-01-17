# tests/unit/test_node_requirements.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# BASIC CREATION & INITIALIZATION
# ==============================================================================

func test_creates_empty_node_requirements():
	var req = NodeRequirements.new()
	runner.assert_not_null(req, "Should create NodeRequirements instance")
	runner.assert_equal(req.player_level_required, 1, "Default level should be 1")
	runner.assert_equal(req.specialization_tier_required, 0, "Default spec tier should be 0")
	runner.assert_equal(req.specialization_role_required, "", "Default role should be empty")
	runner.assert_equal(req.power_required, 1000, "Default power should be 1000")

func test_creates_node_requirements_with_properties():
	var req = NodeRequirements.new()
	req.player_level_required = 20
	req.specialization_tier_required = 2
	req.specialization_role_required = "gatherer"
	req.power_required = 5000

	runner.assert_equal(req.player_level_required, 20, "Level should be 20")
	runner.assert_equal(req.specialization_tier_required, 2, "Spec tier should be 2")
	runner.assert_equal(req.specialization_role_required, "gatherer", "Role should be gatherer")
	runner.assert_equal(req.power_required, 5000, "Power should be 5000")

# ==============================================================================
# REQUIREMENT CHECKS
# ==============================================================================

func test_requires_specialization_when_tier_zero():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 0
	runner.assert_false(req.requires_specialization(), "Should not require spec at tier 0")

func test_requires_specialization_when_tier_one():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 1
	runner.assert_true(req.requires_specialization(), "Should require spec at tier 1")

func test_requires_specialization_when_tier_two():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 2
	runner.assert_true(req.requires_specialization(), "Should require spec at tier 2")

func test_requires_specialization_when_tier_three():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 3
	runner.assert_true(req.requires_specialization(), "Should require spec at tier 3")

func test_requires_role_match_when_empty():
	var req = NodeRequirements.new()
	req.specialization_role_required = ""
	runner.assert_false(req.requires_role_match(), "Should not require role match when empty")

func test_requires_role_match_when_set():
	var req = NodeRequirements.new()
	req.specialization_role_required = "fighter"
	runner.assert_true(req.requires_role_match(), "Should require role match when set")

# ==============================================================================
# DISPLAY NAMES
# ==============================================================================

func test_get_spec_tier_name_none():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 0
	runner.assert_equal(req.get_spec_tier_name(), "None", "Tier 0 should be None")

func test_get_spec_tier_name_tier1():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 1
	runner.assert_equal(req.get_spec_tier_name(), "Tier 1", "Tier 1 should be Tier 1")

func test_get_spec_tier_name_tier2():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 2
	runner.assert_equal(req.get_spec_tier_name(), "Tier 2", "Tier 2 should be Tier 2")

func test_get_spec_tier_name_tier3():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 3
	runner.assert_equal(req.get_spec_tier_name(), "Tier 3", "Tier 3 should be Tier 3")

func test_get_role_display_name_empty():
	var req = NodeRequirements.new()
	req.specialization_role_required = ""
	runner.assert_equal(req.get_role_display_name(), "Any", "Empty role should be Any")

func test_get_role_display_name_fighter():
	var req = NodeRequirements.new()
	req.specialization_role_required = "fighter"
	runner.assert_equal(req.get_role_display_name(), "Fighter", "fighter should be Fighter")

func test_get_role_display_name_gatherer():
	var req = NodeRequirements.new()
	req.specialization_role_required = "gatherer"
	runner.assert_equal(req.get_role_display_name(), "Gatherer", "gatherer should be Gatherer")

func test_get_role_display_name_crafter():
	var req = NodeRequirements.new()
	req.specialization_role_required = "crafter"
	runner.assert_equal(req.get_role_display_name(), "Crafter", "crafter should be Crafter")

func test_get_role_display_name_scholar():
	var req = NodeRequirements.new()
	req.specialization_role_required = "scholar"
	runner.assert_equal(req.get_role_display_name(), "Scholar", "scholar should be Scholar")

func test_get_role_display_name_support():
	var req = NodeRequirements.new()
	req.specialization_role_required = "support"
	runner.assert_equal(req.get_role_display_name(), "Support", "support should be Support")

# ==============================================================================
# DESCRIPTIONS
# ==============================================================================

func test_get_description_tier1():
	var req = NodeRequirements.new()
	req.player_level_required = 1
	req.specialization_tier_required = 0
	req.power_required = 1000

	var desc = req.get_description()
	runner.assert_true(desc.contains("Level 1"), "Should contain level")
	runner.assert_true(desc.contains("1000 Power"), "Should contain power")
	runner.assert_false(desc.contains("Specialization"), "Should not contain spec for tier 0")

func test_get_description_tier2():
	var req = NodeRequirements.new()
	req.player_level_required = 10
	req.specialization_tier_required = 1
	req.power_required = 3000

	var desc = req.get_description()
	runner.assert_true(desc.contains("Level 10"), "Should contain level 10")
	runner.assert_true(desc.contains("Any Specialization Tier 1"), "Should contain spec tier 1")
	runner.assert_true(desc.contains("3000 Power"), "Should contain power 3000")

func test_get_description_tier3():
	var req = NodeRequirements.new()
	req.player_level_required = 20
	req.specialization_tier_required = 2
	req.power_required = 7000

	var desc = req.get_description()
	runner.assert_true(desc.contains("Level 20"), "Should contain level 20")
	runner.assert_true(desc.contains("Any Specialization Tier 2"), "Should contain spec tier 2")
	runner.assert_true(desc.contains("7000 Power"), "Should contain power 7000")

func test_get_description_tier4_with_role():
	var req = NodeRequirements.new()
	req.player_level_required = 30
	req.specialization_tier_required = 2
	req.specialization_role_required = "gatherer"
	req.power_required = 15000

	var desc = req.get_description()
	runner.assert_true(desc.contains("Level 30"), "Should contain level 30")
	runner.assert_true(desc.contains("Gatherer Specialization Tier 2"), "Should contain gatherer spec tier 2")
	runner.assert_true(desc.contains("15000 Power"), "Should contain power 15000")

func test_get_description_tier5():
	var req = NodeRequirements.new()
	req.player_level_required = 40
	req.specialization_tier_required = 3
	req.power_required = 30000

	var desc = req.get_description()
	runner.assert_true(desc.contains("Level 40"), "Should contain level 40")
	runner.assert_true(desc.contains("Any Specialization Tier 3"), "Should contain spec tier 3")
	runner.assert_true(desc.contains("30000 Power"), "Should contain power 30000")

func test_get_short_description_tier1():
	var req = NodeRequirements.new()
	req.player_level_required = 1
	req.specialization_tier_required = 0
	req.power_required = 1000

	var desc = req.get_short_description()
	runner.assert_true(desc.contains("Lv1"), "Should contain Lv1")
	runner.assert_true(desc.contains("1k Power"), "Should contain 1k Power")

func test_get_short_description_tier2():
	var req = NodeRequirements.new()
	req.player_level_required = 10
	req.specialization_tier_required = 1
	req.power_required = 3000

	var desc = req.get_short_description()
	runner.assert_true(desc.contains("Lv10"), "Should contain Lv10")
	runner.assert_true(desc.contains("Spec T1"), "Should contain Spec T1")
	runner.assert_true(desc.contains("3k Power"), "Should contain 3k Power")

func test_get_short_description_tier4_with_role():
	var req = NodeRequirements.new()
	req.player_level_required = 30
	req.specialization_tier_required = 2
	req.specialization_role_required = "fighter"
	req.power_required = 15000

	var desc = req.get_short_description()
	runner.assert_true(desc.contains("Lv30"), "Should contain Lv30")
	runner.assert_true(desc.contains("Fighter T2"), "Should contain Fighter T2")
	runner.assert_true(desc.contains("15k Power"), "Should contain 15k Power")

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func test_to_dict():
	var req = NodeRequirements.new()
	req.player_level_required = 20
	req.specialization_tier_required = 2
	req.specialization_role_required = "gatherer"
	req.power_required = 7000

	var dict = req.to_dict()
	runner.assert_equal(dict["player_level_required"], 20, "Level should serialize")
	runner.assert_equal(dict["specialization_tier_required"], 2, "Spec tier should serialize")
	runner.assert_equal(dict["specialization_role_required"], "gatherer", "Role should serialize")
	runner.assert_equal(dict["power_required"], 7000, "Power should serialize")

func test_from_dict():
	var data = {
		"player_level_required": 30,
		"specialization_tier_required": 3,
		"specialization_role_required": "crafter",
		"power_required": 20000
	}

	var req = NodeRequirements.from_dict(data)
	runner.assert_equal(req.player_level_required, 30, "Level should deserialize")
	runner.assert_equal(req.specialization_tier_required, 3, "Spec tier should deserialize")
	runner.assert_equal(req.specialization_role_required, "crafter", "Role should deserialize")
	runner.assert_equal(req.power_required, 20000, "Power should deserialize")

func test_from_dict_with_defaults():
	var data = {}
	var req = NodeRequirements.from_dict(data)

	runner.assert_equal(req.player_level_required, 1, "Level should use default")
	runner.assert_equal(req.specialization_tier_required, 0, "Spec tier should use default")
	runner.assert_equal(req.specialization_role_required, "", "Role should use default")
	runner.assert_equal(req.power_required, 1000, "Power should use default")

func test_roundtrip_serialization():
	var original = NodeRequirements.new()
	original.player_level_required = 25
	original.specialization_tier_required = 2
	original.specialization_role_required = "scholar"
	original.power_required = 12000

	var dict = original.to_dict()
	var restored = NodeRequirements.from_dict(dict)

	runner.assert_equal(restored.player_level_required, 25, "Level should roundtrip")
	runner.assert_equal(restored.specialization_tier_required, 2, "Spec tier should roundtrip")
	runner.assert_equal(restored.specialization_role_required, "scholar", "Role should roundtrip")
	runner.assert_equal(restored.power_required, 12000, "Power should roundtrip")

# ==============================================================================
# FACTORY METHODS
# ==============================================================================

func test_create_tier1():
	var req = NodeRequirements.create_tier1()
	runner.assert_equal(req.player_level_required, 1, "Tier 1 should require level 1")
	runner.assert_equal(req.specialization_tier_required, 0, "Tier 1 should not require spec")
	runner.assert_equal(req.power_required, 1000, "Tier 1 should require 1000 power")

func test_create_tier2():
	var req = NodeRequirements.create_tier2()
	runner.assert_equal(req.player_level_required, 10, "Tier 2 should require level 10")
	runner.assert_equal(req.specialization_tier_required, 1, "Tier 2 should require tier 1 spec")
	runner.assert_equal(req.power_required, 3000, "Tier 2 should require 3000 power")

func test_create_tier3():
	var req = NodeRequirements.create_tier3()
	runner.assert_equal(req.player_level_required, 20, "Tier 3 should require level 20")
	runner.assert_equal(req.specialization_tier_required, 2, "Tier 3 should require tier 2 spec")
	runner.assert_equal(req.power_required, 7000, "Tier 3 should require 7000 power")

func test_create_tier4():
	var req = NodeRequirements.create_tier4("fighter")
	runner.assert_equal(req.player_level_required, 30, "Tier 4 should require level 30")
	runner.assert_equal(req.specialization_tier_required, 2, "Tier 4 should require tier 2 spec")
	runner.assert_equal(req.specialization_role_required, "fighter", "Tier 4 should require fighter role")
	runner.assert_equal(req.power_required, 15000, "Tier 4 should require 15000 power")

func test_create_tier5():
	var req = NodeRequirements.create_tier5()
	runner.assert_equal(req.player_level_required, 40, "Tier 5 should require level 40")
	runner.assert_equal(req.specialization_tier_required, 3, "Tier 5 should require tier 3 spec")
	runner.assert_equal(req.power_required, 30000, "Tier 5 should require 30000 power")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_negative_level():
	var req = NodeRequirements.new()
	req.player_level_required = -5
	runner.assert_equal(req.player_level_required, -5, "Should allow negative level (validation in checker)")

func test_high_spec_tier():
	var req = NodeRequirements.new()
	req.specialization_tier_required = 10
	runner.assert_equal(req.specialization_tier_required, 10, "Should allow high spec tier (validation in checker)")

func test_unknown_role():
	var req = NodeRequirements.new()
	req.specialization_role_required = "unknown_role"
	runner.assert_equal(req.get_role_display_name(), "Unknown_role", "Should capitalize unknown role")

func test_zero_power():
	var req = NodeRequirements.new()
	req.power_required = 0
	runner.assert_equal(req.power_required, 0, "Should allow zero power")

func test_very_high_power():
	var req = NodeRequirements.new()
	req.power_required = 999999999
	runner.assert_equal(req.power_required, 999999999, "Should allow very high power")
