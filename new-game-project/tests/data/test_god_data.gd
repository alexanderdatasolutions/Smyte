# test_god_data.gd - Unit tests for scripts/data/God.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_valid_god() -> God:
	"""Create a valid god for testing"""
	var god = God.new()
	god.id = "test_god_001"
	god.name = "Test God"
	god.pantheon = "greek"
	god.element = God.ElementType.FIRE
	god.tier = God.TierType.RARE
	god.level = 1
	god.base_hp = 1000
	god.base_attack = 100
	god.base_defense = 50
	god.base_speed = 100
	god.base_crit_rate = 15
	god.base_crit_damage = 50
	god.base_resistance = 15
	god.base_accuracy = 0
	return god

func create_awakened_god() -> God:
	"""Create an awakened god for testing"""
	var god = create_valid_god()
	god.is_awakened = true
	god.awakened_name = "Awakened Test God"
	god.awakened_title = "The Powerful"
	return god

# ==============================================================================
# TEST: God Creation with Valid Data
# ==============================================================================

func test_god_creation_with_valid_data():
	var god = create_valid_god()

	runner.assert_equal(god.id, "test_god_001", "id should match")
	runner.assert_equal(god.name, "Test God", "name should match")
	runner.assert_equal(god.pantheon, "greek", "pantheon should match")
	runner.assert_equal(god.element, God.ElementType.FIRE, "element should be FIRE")
	runner.assert_equal(god.tier, God.TierType.RARE, "tier should be RARE")
	runner.assert_equal(god.level, 1, "level should be 1")

# ==============================================================================
# TEST: Default Stats
# ==============================================================================

func test_god_default_stats():
	var god = God.new()

	runner.assert_equal(god.level, 1, "default level should be 1")
	runner.assert_equal(god.experience, 0, "default experience should be 0")
	runner.assert_equal(god.base_crit_rate, 15, "default crit_rate should be 15")
	runner.assert_equal(god.base_crit_damage, 50, "default crit_damage should be 50")
	runner.assert_equal(god.base_resistance, 15, "default resistance should be 15")
	runner.assert_equal(god.base_accuracy, 0, "default accuracy should be 0")
	runner.assert_equal(god.is_awakened, false, "default is_awakened should be false")
	runner.assert_equal(god.ascension_level, 0, "default ascension_level should be 0")

# ==============================================================================
# TEST: Equipment Slots Count
# ==============================================================================

func test_god_equipment_slots_count():
	var god = create_valid_god()

	runner.assert_equal(god.equipment.size(), 6, "should have 6 equipment slots")

	# All slots should be null initially
	for i in range(6):
		runner.assert_null(god.equipment[i], "slot %d should be null" % i)

# ==============================================================================
# TEST: Element to String Conversion
# ==============================================================================

func test_god_element_to_string_conversion():
	runner.assert_equal(God.element_to_string(God.ElementType.FIRE), "fire", "FIRE should convert to 'fire'")
	runner.assert_equal(God.element_to_string(God.ElementType.WATER), "water", "WATER should convert to 'water'")
	runner.assert_equal(God.element_to_string(God.ElementType.EARTH), "earth", "EARTH should convert to 'earth'")
	runner.assert_equal(God.element_to_string(God.ElementType.LIGHTNING), "lightning", "LIGHTNING should convert to 'lightning'")
	runner.assert_equal(God.element_to_string(God.ElementType.LIGHT), "light", "LIGHT should convert to 'light'")
	runner.assert_equal(God.element_to_string(God.ElementType.DARK), "dark", "DARK should convert to 'dark'")
	runner.assert_equal(God.element_to_string(-1), "unknown", "invalid element should return 'unknown'")

# ==============================================================================
# TEST: String to Element Conversion
# ==============================================================================

func test_god_string_to_element_conversion():
	runner.assert_equal(God.string_to_element("fire"), God.ElementType.FIRE, "'fire' should convert to FIRE")
	runner.assert_equal(God.string_to_element("water"), God.ElementType.WATER, "'water' should convert to WATER")
	runner.assert_equal(God.string_to_element("earth"), God.ElementType.EARTH, "'earth' should convert to EARTH")
	runner.assert_equal(God.string_to_element("lightning"), God.ElementType.LIGHTNING, "'lightning' should convert to LIGHTNING")
	runner.assert_equal(God.string_to_element("light"), God.ElementType.LIGHT, "'light' should convert to LIGHT")
	runner.assert_equal(God.string_to_element("dark"), God.ElementType.DARK, "'dark' should convert to DARK")

	# Case insensitivity
	runner.assert_equal(God.string_to_element("FIRE"), God.ElementType.FIRE, "'FIRE' should convert to FIRE (case insensitive)")
	runner.assert_equal(God.string_to_element("Fire"), God.ElementType.FIRE, "'Fire' should convert to FIRE (case insensitive)")

	# Default fallback
	runner.assert_equal(God.string_to_element("invalid"), God.ElementType.LIGHT, "invalid string should default to LIGHT")

# ==============================================================================
# TEST: Tier to String Conversion
# ==============================================================================

func test_god_tier_to_string_conversion():
	runner.assert_equal(God.tier_to_string(God.TierType.COMMON), "common", "COMMON should convert to 'common'")
	runner.assert_equal(God.tier_to_string(God.TierType.RARE), "rare", "RARE should convert to 'rare'")
	runner.assert_equal(God.tier_to_string(God.TierType.EPIC), "epic", "EPIC should convert to 'epic'")
	runner.assert_equal(God.tier_to_string(God.TierType.LEGENDARY), "legendary", "LEGENDARY should convert to 'legendary'")
	runner.assert_equal(God.tier_to_string(-1), "unknown", "invalid tier should return 'unknown'")

# ==============================================================================
# TEST: String to Tier Conversion
# ==============================================================================

func test_god_string_to_tier_conversion():
	runner.assert_equal(God.string_to_tier("common"), God.TierType.COMMON, "'common' should convert to COMMON")
	runner.assert_equal(God.string_to_tier("rare"), God.TierType.RARE, "'rare' should convert to RARE")
	runner.assert_equal(God.string_to_tier("epic"), God.TierType.EPIC, "'epic' should convert to EPIC")
	runner.assert_equal(God.string_to_tier("legendary"), God.TierType.LEGENDARY, "'legendary' should convert to LEGENDARY")

	# Case insensitivity
	runner.assert_equal(God.string_to_tier("COMMON"), God.TierType.COMMON, "'COMMON' should convert to COMMON (case insensitive)")
	runner.assert_equal(God.string_to_tier("Legendary"), God.TierType.LEGENDARY, "'Legendary' should convert to LEGENDARY (case insensitive)")

	# Default fallback
	runner.assert_equal(God.string_to_tier("invalid"), God.TierType.COMMON, "invalid string should default to COMMON")

# ==============================================================================
# TEST: is_valid Returns True for Valid God
# ==============================================================================

func test_god_is_valid_returns_true_for_valid_god():
	var god = create_valid_god()

	runner.assert_true(god.is_valid(), "valid god should return true")

# ==============================================================================
# TEST: is_valid Returns False for Empty ID
# ==============================================================================

func test_god_is_valid_returns_false_for_empty_id():
	var god = create_valid_god()
	god.id = ""

	runner.assert_false(god.is_valid(), "god with empty id should return false")

# ==============================================================================
# TEST: is_valid Returns False for Empty Name
# ==============================================================================

func test_god_is_valid_returns_false_for_empty_name():
	var god = create_valid_god()
	god.name = ""

	runner.assert_false(god.is_valid(), "god with empty name should return false")

# ==============================================================================
# TEST: is_valid Returns False for Zero HP
# ==============================================================================

func test_god_is_valid_returns_false_for_zero_hp():
	var god = create_valid_god()
	god.base_hp = 0

	runner.assert_false(god.is_valid(), "god with zero base_hp should return false")

# ==============================================================================
# TEST: is_valid Returns False for Zero Attack
# ==============================================================================

func test_god_is_valid_returns_false_for_zero_attack():
	var god = create_valid_god()
	god.base_attack = 0

	runner.assert_false(god.is_valid(), "god with zero base_attack should return false")

# ==============================================================================
# TEST: can_level_up Below Max
# ==============================================================================

func test_god_can_level_up_below_max():
	var god = create_valid_god()
	god.level = 1

	runner.assert_true(god.can_level_up(), "level 1 god should be able to level up")

	god.level = 39
	runner.assert_true(god.can_level_up(), "level 39 god should be able to level up")

# ==============================================================================
# TEST: can_level_up At Max Returns False
# ==============================================================================

func test_god_can_level_up_at_max_returns_false():
	var god = create_valid_god()
	god.level = 40

	runner.assert_false(god.can_level_up(), "level 40 god should NOT be able to level up")

	god.level = 41
	runner.assert_false(god.can_level_up(), "level 41+ god should NOT be able to level up")

# ==============================================================================
# TEST: Display Name (Non-Awakened)
# ==============================================================================

func test_god_get_display_name_not_awakened():
	var god = create_valid_god()

	runner.assert_equal(god.get_display_name(), "Test God", "non-awakened god should return regular name")

# ==============================================================================
# TEST: Display Name (Awakened)
# ==============================================================================

func test_god_get_display_name_awakened():
	var god = create_awakened_god()

	runner.assert_equal(god.get_display_name(), "Awakened Test God", "awakened god should return awakened name")

# ==============================================================================
# TEST: Display Name (Awakened but No Awakened Name)
# ==============================================================================

func test_god_get_display_name_awakened_without_awakened_name():
	var god = create_valid_god()
	god.is_awakened = true
	god.awakened_name = ""

	runner.assert_equal(god.get_display_name(), "Test God", "awakened god without awakened_name should return regular name")

# ==============================================================================
# TEST: Full Title (Non-Awakened)
# ==============================================================================

func test_god_get_full_title_not_awakened():
	var god = create_valid_god()

	runner.assert_equal(god.get_full_title(), "Test God", "non-awakened god full title should be just the name")

# ==============================================================================
# TEST: Full Title (Awakened)
# ==============================================================================

func test_god_get_full_title_awakened():
	var god = create_awakened_god()

	runner.assert_equal(god.get_full_title(), "The Powerful Awakened Test God", "awakened god full title should include title")

# ==============================================================================
# TEST: Equipment Slot Empty Check
# ==============================================================================

func test_god_is_equipment_slot_empty():
	var god = create_valid_god()

	# All slots should be empty initially
	for i in range(6):
		runner.assert_true(god.is_equipment_slot_empty(i), "slot %d should be empty" % i)

	# Invalid slot indices should return true (empty)
	runner.assert_true(god.is_equipment_slot_empty(-1), "negative slot should be treated as empty")
	runner.assert_true(god.is_equipment_slot_empty(6), "slot 6 (out of bounds) should be treated as empty")
	runner.assert_true(god.is_equipment_slot_empty(100), "slot 100 (out of bounds) should be treated as empty")

# ==============================================================================
# TEST: Get Equipment in Slot
# ==============================================================================

func test_god_get_equipment_in_slot():
	var god = create_valid_god()

	# Empty slots return null
	for i in range(6):
		runner.assert_null(god.get_equipment_in_slot(i), "empty slot %d should return null" % i)

	# Invalid slots return null
	runner.assert_null(god.get_equipment_in_slot(-1), "negative slot should return null")
	runner.assert_null(god.get_equipment_in_slot(6), "out of bounds slot should return null")

# ==============================================================================
# TEST: has_ability
# ==============================================================================

func test_god_has_ability():
	var god = create_valid_god()
	god.active_abilities = [
		{"id": "ability_1", "name": "Fireball"},
		{"id": "ability_2", "name": "Heal"}
	]

	runner.assert_true(god.has_ability("ability_1"), "should have ability_1")
	runner.assert_true(god.has_ability("ability_2"), "should have ability_2")
	runner.assert_false(god.has_ability("ability_3"), "should NOT have ability_3")
	runner.assert_false(god.has_ability(""), "should NOT have empty ability id")

# ==============================================================================
# TEST: has_ability with Empty Abilities
# ==============================================================================

func test_god_has_ability_empty_array():
	var god = create_valid_god()
	god.active_abilities = []

	runner.assert_false(god.has_ability("any_ability"), "god with no abilities should return false")

# ==============================================================================
# TEST: is_equipped
# ==============================================================================

func test_god_is_equipped_false_when_no_equipment():
	var god = create_valid_god()

	runner.assert_false(god.is_equipped(), "god with no equipment should return false")

# ==============================================================================
# TEST: is_assigned_to_territory
# ==============================================================================

func test_god_is_assigned_to_territory_false_when_not_assigned():
	var god = create_valid_god()

	runner.assert_false(god.is_assigned_to_territory(), "god not assigned to territory should return false")

func test_god_is_assigned_to_territory_false_when_partial_assignment():
	var god = create_valid_god()
	god.stationed_territory = "test_territory"
	god.territory_role = ""

	runner.assert_false(god.is_assigned_to_territory(), "god with only territory but no role should return false")

	god.stationed_territory = ""
	god.territory_role = "defender"

	runner.assert_false(god.is_assigned_to_territory(), "god with only role but no territory should return false")

func test_god_is_assigned_to_territory_true_when_fully_assigned():
	var god = create_valid_god()
	god.stationed_territory = "test_territory"
	god.territory_role = "defender"

	runner.assert_true(god.is_assigned_to_territory(), "god with both territory and role should return true")

# ==============================================================================
# TEST: Skill Levels Array
# ==============================================================================

func test_god_skill_levels_default():
	var god = God.new()

	runner.assert_array_size(god.skill_levels, 4, "should have 4 skill levels")
	for i in range(4):
		runner.assert_equal(god.skill_levels[i], 1, "skill %d should default to level 1" % i)

# ==============================================================================
# TEST: Battle State Defaults
# ==============================================================================

func test_god_battle_state_defaults():
	var god = God.new()

	runner.assert_equal(god.current_hp, 0, "current_hp should default to 0")
	runner.assert_array_size(god.status_effects, 0, "status_effects should be empty")
	runner.assert_equal(god.position, -1, "position should default to -1")
