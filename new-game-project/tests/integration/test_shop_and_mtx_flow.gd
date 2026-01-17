# tests/integration/test_shop_and_mtx_flow.gd
# Integration test: Shop purchases, skin application, crystal usage
extends RefCounted

var runner = null
var shop_manager = null
var skin_manager = null
var resource_manager = null
var collection_manager = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	shop_manager = registry.get_system("ShopManager")
	skin_manager = registry.get_system("SkinManager")
	resource_manager = registry.get_system("ResourceManager")
	collection_manager = registry.get_system("CollectionManager")

func test_purchase_crystals_and_buy_skin():
	"""
	USER FLOW:
	1. Player has 0 crystals
	2. Player "purchases" crystal pack ($4.99 → 500 crystals)
	3. Crystals are added to account
	4. Player buys god skin for 500 crystals
	5. Skin is unlocked
	6. Crystals are consumed
	"""
	setup()

	# STEP 1: Verify starting crystals
	var crystals_start = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_start, 0, "Step 1: Should start with 0 crystals")

	# STEP 2: Purchase crystal pack
	var pack_id = "crystals_500"  # $4.99 pack
	var purchase_success = shop_manager.purchase_crystal_pack(pack_id)
	runner.assert_true(purchase_success, "Step 2: Crystal purchase should succeed")

	# STEP 3: Verify crystals added
	var crystals_after = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_after, 600, "Step 3: Should have 500 + 100 bonus = 600 crystals")

	# STEP 4: Check available skins
	var available_skins = shop_manager.get_available_skins()
	runner.assert_true(available_skins.size() > 0, "Step 4: Should have skins available")

	# STEP 5: Buy a skin (assume 500 crystal skin exists)
	var skin_id = "ares_dark_warrior"
	var skin = shop_manager.get_skin(skin_id)
	runner.assert_not_null(skin, "Step 5: Skin should exist")

	var purchase_skin_success = shop_manager.purchase_skin(skin_id)
	runner.assert_true(purchase_skin_success, "Step 5: Skin purchase should succeed")

	# STEP 6: Verify crystals consumed
	var crystals_final = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_final, 100, "Step 6: Should have 100 crystals left (600 - 500)")

	# STEP 7: Verify skin owned
	runner.assert_true(skin_manager.owns_skin(skin_id), "Step 7: Should own skin")

func test_equip_skin_on_god():
	"""
	USER FLOW:
	1. Player owns skin for Ares
	2. Player summons Ares
	3. Player equips skin on Ares
	4. Verify Ares portrait changes
	"""
	setup()

	# STEP 1: Give player crystals and buy skin
	resource_manager.add_resource("divine_crystals", 500)
	shop_manager.purchase_skin("ares_dark_warrior")

	# STEP 2: Summon Ares
	var ares = collection_manager.add_god_to_collection("ares")
	runner.assert_not_null(ares, "Step 2: Ares should be summoned")

	var original_portrait = ares.get_portrait_path()

	# STEP 3: Equip skin
	var equip_success = skin_manager.equip_skin(ares, "ares_dark_warrior")
	runner.assert_true(equip_success, "Step 3: Skin equip should succeed")

	# STEP 4: Verify equipped skin
	runner.assert_equal(ares.equipped_skin_id, "ares_dark_warrior", "Step 4: Skin should be equipped")

	var new_portrait = ares.get_portrait_path()
	runner.assert_not_equal(new_portrait, original_portrait, "Step 4: Portrait should change")

func test_cannot_buy_skin_without_crystals():
	"""
	USER FLOW:
	1. Player has 100 crystals
	2. Player tries to buy 500-crystal skin
	3. Purchase fails
	"""
	setup()

	# STEP 1: Give insufficient crystals
	resource_manager.set_resource("divine_crystals", 100)

	# STEP 2: Try to buy expensive skin
	var purchase_success = shop_manager.purchase_skin("ares_dark_warrior")  # 500 crystals
	runner.assert_false(purchase_success, "Step 2: Should fail - not enough crystals")

	# STEP 3: Verify crystals not consumed
	var crystals_after = resource_manager.get_resource_amount("divine_crystals")
	runner.assert_equal(crystals_after, 100, "Step 3: Crystals should remain unchanged")

	# STEP 4: Verify skin not owned
	runner.assert_false(skin_manager.owns_skin("ares_dark_warrior"), "Step 4: Should not own skin")

func test_cannot_equip_skin_for_wrong_god():
	"""
	USER FLOW:
	1. Player owns Ares skin
	2. Player tries to equip it on Poseidon
	3. Equip fails
	"""
	setup()

	# STEP 1: Buy Ares skin
	resource_manager.add_resource("divine_crystals", 500)
	shop_manager.purchase_skin("ares_dark_warrior")

	# STEP 2: Summon Poseidon
	var poseidon = collection_manager.add_god_to_collection("poseidon")

	# STEP 3: Try to equip Ares skin on Poseidon
	var equip_success = skin_manager.equip_skin(poseidon, "ares_dark_warrior")
	runner.assert_false(equip_success, "Step 3: Should fail - wrong god")

	# STEP 4: Verify no skin equipped
	runner.assert_equal(poseidon.equipped_skin_id, "", "Step 4: Poseidon should have no skin")

func test_unequip_skin():
	"""
	USER FLOW:
	1. Equip skin on Ares
	2. Unequip skin
	3. Verify portrait returns to default
	"""
	setup()

	# STEP 1: Setup
	resource_manager.add_resource("divine_crystals", 500)
	shop_manager.purchase_skin("ares_dark_warrior")
	var ares = collection_manager.add_god_to_collection("ares")

	var default_portrait = ares.get_portrait_path()

	# STEP 2: Equip skin
	skin_manager.equip_skin(ares, "ares_dark_warrior")
	var skinned_portrait = ares.get_portrait_path()

	runner.assert_not_equal(skinned_portrait, default_portrait, "Step 2: Should be different with skin")

	# STEP 3: Unequip skin
	var unequip_success = skin_manager.unequip_skin(ares)
	runner.assert_true(unequip_success, "Step 3: Unequip should succeed")

	# STEP 4: Verify back to default
	var final_portrait = ares.get_portrait_path()
	runner.assert_equal(final_portrait, default_portrait, "Step 4: Should return to default portrait")

func test_skin_persists_after_save_load():
	"""
	USER FLOW:
	1. Buy and equip skin
	2. Save game
	3. Load game
	4. Verify skin still equipped
	"""
	setup()

	# STEP 1: Buy and equip
	resource_manager.add_resource("divine_crystals", 500)
	shop_manager.purchase_skin("ares_dark_warrior")
	var ares = collection_manager.add_god_to_collection("ares")
	skin_manager.equip_skin(ares, "ares_dark_warrior")

	runner.assert_equal(ares.equipped_skin_id, "ares_dark_warrior", "Step 1: Skin should be equipped")

	# STEP 2: Save to dict
	var save_data = ares.to_dict()
	runner.assert_true(save_data.has("equipped_skin_id"), "Step 2: Save should include skin data")
	runner.assert_equal(save_data["equipped_skin_id"], "ares_dark_warrior", "Step 2: Skin ID should be saved")

	# STEP 3: Load from dict (simulate load)
	var loaded_god = God.new()
	loaded_god.from_dict(save_data)

	# STEP 4: Verify skin persisted
	runner.assert_equal(loaded_god.equipped_skin_id, "ares_dark_warrior", "Step 4: Skin should persist after load")

func test_purchase_history_tracking():
	"""
	USER FLOW:
	1. Buy 3 different crystal packs
	2. Check purchase history
	3. Verify all purchases recorded
	"""
	setup()

	# STEP 1: Buy multiple packs
	shop_manager.purchase_crystal_pack("crystals_100")
	shop_manager.purchase_crystal_pack("crystals_500")
	shop_manager.purchase_crystal_pack("crystals_1200")

	# STEP 2: Get purchase history
	var history = shop_manager.get_purchase_history()
	runner.assert_equal(history.size(), 3, "Step 2: Should have 3 purchases")

	# STEP 3: Verify crystals total
	var total_crystals = resource_manager.get_resource_amount("divine_crystals")
	# 100+10 + 500+100 + 1200+300 = 2210
	runner.assert_equal(total_crystals, 2210, "Step 3: Should have correct total crystals with bonuses")

func test_shop_item_filtering():
	"""
	USER FLOW:
	1. Player summons Ares and Poseidon
	2. Player opens shop
	3. Shop shows only skins for owned gods
	"""
	setup()

	# STEP 1: Summon gods
	var ares = collection_manager.add_god_to_collection("ares")
	var poseidon = collection_manager.add_god_to_collection("poseidon")

	# STEP 2: Get available skins (filtered by owned gods)
	var available_skins = shop_manager.get_available_skins_for_owned_gods()

	# STEP 3: Verify only Ares and Poseidon skins appear
	var has_ares_skin = false
	var has_poseidon_skin = false
	var has_other_god_skin = false

	for skin in available_skins:
		if skin.god_id == "ares":
			has_ares_skin = true
		elif skin.god_id == "poseidon":
			has_poseidon_skin = true
		else:
			has_other_god_skin = true

	runner.assert_true(has_ares_skin, "Step 3: Should show Ares skins")
	runner.assert_true(has_poseidon_skin, "Step 3: Should show Poseidon skins")
	runner.assert_false(has_other_god_skin, "Step 3: Should NOT show skins for gods not owned")
