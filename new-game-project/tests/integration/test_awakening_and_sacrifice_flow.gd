# tests/integration/test_awakening_and_sacrifice_flow.gd
# Integration test: Awakening gods and sacrificing duplicates
extends RefCounted

var runner = null
var collection_manager = null
var awakening_system = null
var sacrifice_manager = null
var resource_manager = null
var player_progression = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	collection_manager = registry.get_system("CollectionManager")
	awakening_system = registry.get_system("AwakeningSystem")
	sacrifice_manager = registry.get_system("SacrificeManager")
	resource_manager = registry.get_system("ResourceManager")
	player_progression = registry.get_system("PlayerProgressionManager")

func test_complete_awakening_flow():
	"""
	USER FLOW:
	1. Summon Ares (Fire element)
	2. Farm Fire Sanctum to get essences
	3. Collect 20 High Fire Essences
	4. Awaken Ares
	5. Verify awakened state (name change, stat boost)
	"""
	setup()

	# STEP 1: Summon Ares
	var ares = collection_manager.add_god_to_collection("ares")
	runner.assert_not_null(ares, "Step 1: Ares should be summoned")
	runner.assert_false(ares.is_awakened, "Step 1: Should not be awakened initially")

	var original_name = ares.name
	var base_hp = ares.get_stat("hp")

	# STEP 2: Give awakening materials
	resource_manager.add_resource("fire_essence_low", 10)
	resource_manager.add_resource("fire_essence_mid", 15)
	resource_manager.add_resource("fire_essence_high", 20)

	# STEP 3: Check awakening requirements
	var can_awaken = awakening_system.can_awaken(ares)
	runner.assert_true(can_awaken, "Step 3: Should be able to awaken with materials")

	# STEP 4: Awaken Ares
	var awaken_success = awakening_system.awaken_god(ares)
	runner.assert_true(awaken_success, "Step 4: Awakening should succeed")

	# STEP 5: Verify awakened state
	runner.assert_true(ares.is_awakened, "Step 5: Should be awakened")
	runner.assert_not_equal(ares.name, original_name, "Step 5: Name should change after awakening")

	var awakened_hp = ares.get_stat("hp")
	runner.assert_true(awakened_hp > base_hp, "Step 5: Stats should increase after awakening")

	# STEP 6: Verify essences consumed
	var essences_left = resource_manager.get_resource_amount("fire_essence_high")
	runner.assert_equal(essences_left, 0, "Step 6: High essences should be consumed")

func test_cannot_awaken_without_materials():
	"""
	USER FLOW:
	1. Summon Ares
	2. Try to awaken without materials
	3. Awakening fails
	4. Check failure reasons
	"""
	setup()

	var ares = collection_manager.add_god_to_collection("ares")

	# STEP 1: Try to awaken with no materials
	var can_awaken = awakening_system.can_awaken(ares)
	runner.assert_false(can_awaken, "Step 1: Should NOT be able to awaken without materials")

	var reasons = awakening_system.get_awakening_failure_reasons(ares)
	runner.assert_true(reasons.size() > 0, "Step 1: Should have failure reasons")
	runner.assert_true("essence" in reasons[0].to_lower(), "Step 1: Should fail due to missing essences")

func test_sacrifice_duplicate_gods():
	"""
	USER FLOW:
	1. Summon 3 copies of Ares
	2. Sacrifice 2 copies to power up the main one
	3. Verify main Ares gets XP
	4. Verify duplicates are removed from collection
	"""
	setup()

	# STEP 1: Summon 3 Ares
	var ares1 = collection_manager.add_god_to_collection("ares")
	var ares2 = collection_manager.add_god_to_collection("ares")
	var ares3 = collection_manager.add_god_to_collection("ares")

	runner.assert_equal(collection_manager.get_god_count(), 3, "Step 1: Should have 3 gods")

	var initial_level = ares1.level

	# STEP 2: Sacrifice ares2 and ares3 to ares1
	var sacrifice_ids = [ares2.id, ares3.id]
	var sacrifice_success = sacrifice_manager.sacrifice_gods(ares1.id, sacrifice_ids)
	runner.assert_true(sacrifice_success, "Step 2: Sacrifice should succeed")

	# STEP 3: Verify main god gained XP
	runner.assert_true(ares1.level > initial_level or ares1.experience > 0, "Step 3: Should gain XP or level")

	# STEP 4: Verify duplicates removed
	runner.assert_equal(collection_manager.get_god_count(), 1, "Step 4: Should only have 1 god left")
	runner.assert_null(collection_manager.get_god_by_id(ares2.id), "Step 4: Ares2 should be removed")
	runner.assert_null(collection_manager.get_god_by_id(ares3.id), "Step 4: Ares3 should be removed")

func test_sacrifice_different_rarity_bonuses():
	"""
	USER FLOW:
	1. Summon Common Ares
	2. Summon Rare Zeus
	3. Sacrifice Zeus to Ares
	4. Verify Ares gets more XP than normal (rarer god = more XP)
	"""
	setup()

	var ares = collection_manager.add_god_to_collection("ares")  # Common
	var zeus = collection_manager.add_god_to_collection("zeus")  # Legendary

	var initial_xp = ares.experience

	# STEP 1: Sacrifice legendary to common
	var sacrifice_success = sacrifice_manager.sacrifice_gods(ares.id, [zeus.id])
	runner.assert_true(sacrifice_success, "Step 1: Sacrifice should succeed")

	# STEP 2: Verify bonus XP for higher rarity
	var gained_xp = ares.experience - initial_xp
	# Legendary should give 4x XP compared to common (tier 4 vs tier 1)
	runner.assert_true(gained_xp > 1000, "Step 2: Should get significant XP from legendary god")

func test_awakening_unlocks_second_skill():
	"""
	USER FLOW:
	1. Summon Ares (has 1 active skill)
	2. Awaken Ares
	3. Verify second skill is unlocked
	"""
	setup()

	var ares = collection_manager.add_god_to_collection("ares")

	# STEP 1: Check initial skills
	var skills_before = ares.active_abilities.size()
	runner.assert_true(skills_before > 0, "Step 1: Should have at least 1 skill")

	# STEP 2: Give materials and awaken
	resource_manager.add_resource("fire_essence_low", 10)
	resource_manager.add_resource("fire_essence_mid", 15)
	resource_manager.add_resource("fire_essence_high", 20)

	awakening_system.awaken_god(ares)

	# STEP 3: Check skills after awakening
	var skills_after = ares.active_abilities.size()
	runner.assert_true(skills_after >= skills_before, "Step 3: Should have same or more skills after awakening")

	# Check if awakened abilities are added
	var has_awakened_skill = false
	for ability in ares.active_abilities:
		if "awakened" in ability.to_lower() or ability != ares.active_abilities[0]:
			has_awakened_skill = true
			break

	runner.assert_true(has_awakened_skill, "Step 3: Should have awakening-related abilities")

func test_cannot_sacrifice_god_in_use():
	"""
	USER FLOW:
	1. Summon 2 Ares
	2. Assign Ares2 to a territory task
	3. Try to sacrifice Ares2
	4. Sacrifice fails - god is busy
	"""
	setup()

	var ares1 = collection_manager.add_god_to_collection("ares")
	var ares2 = collection_manager.add_god_to_collection("ares")

	# STEP 1: Mark ares2 as "in use" (simplified for test)
	ares2.is_busy = true

	# STEP 2: Try to sacrifice busy god
	var sacrifice_success = sacrifice_manager.sacrifice_gods(ares1.id, [ares2.id])
	runner.assert_false(sacrifice_success, "Step 2: Should NOT sacrifice god that's in use")

func test_bulk_sacrifice_limits():
	"""
	USER FLOW:
	1. Summon 6 copies of same god
	2. Try to sacrifice all 5 extras at once
	3. Verify max sacrifice limit (if exists)
	"""
	setup()

	# STEP 1: Summon 6 Ares
	var main_ares = collection_manager.add_god_to_collection("ares")
	var sacrifice_ids = []

	for i in range(5):
		var duplicate = collection_manager.add_god_to_collection("ares")
		sacrifice_ids.append(duplicate.id)

	runner.assert_equal(collection_manager.get_god_count(), 6, "Step 1: Should have 6 gods")

	# STEP 2: Sacrifice all 5 at once
	var sacrifice_success = sacrifice_manager.sacrifice_gods(main_ares.id, sacrifice_ids)
	runner.assert_true(sacrifice_success, "Step 2: Bulk sacrifice should succeed")

	# STEP 3: Verify only 1 left
	runner.assert_equal(collection_manager.get_god_count(), 1, "Step 3: Should have 1 god left")

	# STEP 4: Verify main god got XP from all 5
	runner.assert_true(main_ares.level >= 2, "Step 4: Should level up from 5 sacrifices")
