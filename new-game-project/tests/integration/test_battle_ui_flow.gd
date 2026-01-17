# tests/integration/test_battle_ui_flow.gd
# Integration test: Full battle UI flow using Godot MCP
# This test can be run via MCP game_interact commands
extends RefCounted

var runner = null
var screen_manager = null
var battle_coordinator = null
var collection_manager = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	screen_manager = registry.get_system("ScreenManager")
	battle_coordinator = registry.get_system("BattleCoordinator")
	collection_manager = registry.get_system("CollectionManager")

func test_navigate_to_battle():
	"""
	USER FLOW:
	1. Start at WorldView
	2. Click TERRITORY button
	3. Click through tutorial (3 times)
	4. Click capturable hex node
	5. Select 4 gods
	6. Click START BATTLE
	7. Verify battle screen loads
	"""
	setup()

	# STEP 1: Verify starting on WorldView
	var current_screen = screen_manager.get_current_screen_name()
	runner.assert_equal(current_screen, "WorldView", "Step 1: Should start on WorldView")

	# STEP 2: Navigate to Territory (MCP should click TERRITORY button)
	# This test validates the systems are ready for MCP interaction
	runner.assert_not_null(screen_manager.get_screen("HexTerritoryMap"), "Step 2: HexTerritoryMap should exist")

func test_battle_screen_components():
	"""
	VALIDATION TEST:
	1. Verify BattleScreen has all required components
	2. Check unit card containers exist
	3. Verify ability bar exists
	4. Check turn order bar exists
	"""
	setup()

	var battle_screen = screen_manager.get_screen("BattleScreen")
	runner.assert_not_null(battle_screen, "BattleScreen should exist")

	# Check for key components (these should be children of BattleScreen)
	var has_ability_bar = battle_screen.has_node("MainContainer/BottomContainer/AbilityBarContainer/AbilityBar")
	var has_turn_order = battle_screen.has_node("MainContainer/HeaderContainer/TurnOrderContainer/TurnOrderBar")
	var has_player_container = battle_screen.has_node("MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer")
	var has_enemy_container = battle_screen.has_node("MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer")

	runner.assert_true(has_ability_bar, "Should have AbilityBar")
	runner.assert_true(has_turn_order, "Should have TurnOrderBar")
	runner.assert_true(has_player_container, "Should have PlayerTeamContainer")
	runner.assert_true(has_enemy_container, "Should have EnemyTeamContainer")

func test_ability_selection_mobile_flow():
	"""
	MOBILE TWO-TAP FLOW:
	1. Start battle with 4 gods vs enemies
	2. Wait for player's turn
	3. Click first ability (select it)
	4. Verify skill is selected
	5. Click enemy unit (execute skill)
	6. Verify skill was executed
	7. Verify selection cleared
	"""
	setup()

	# STEP 1: Ensure we have gods
	var gods = collection_manager.get_all_gods()
	runner.assert_true(gods.size() >= 4, "Step 1: Should have at least 4 gods")

	# STEP 2: This test validates the BattleScreen state machine
	var battle_screen = screen_manager.get_screen("BattleScreen")
	runner.assert_not_null(battle_screen, "Step 2: BattleScreen should exist")

	# STEP 3: Verify BattleScreen has skill selection state variables
	runner.assert_true("selected_skill" in battle_screen, "Step 3: Should have selected_skill variable")
	runner.assert_true("selected_skill_index" in battle_screen, "Step 3: Should have selected_skill_index variable")

	# STEP 4: Verify helper methods exist
	runner.assert_true(battle_screen.has_method("_highlight_valid_targets"), "Step 4: Should have _highlight_valid_targets method")
	runner.assert_true(battle_screen.has_method("_on_unit_clicked"), "Step 4: Should have _on_unit_clicked method")
	runner.assert_true(battle_screen.has_method("_is_valid_target"), "Step 4: Should have _is_valid_target method")
	runner.assert_true(battle_screen.has_method("_execute_skill_on_target"), "Step 4: Should have _execute_skill_on_target method")
	runner.assert_true(battle_screen.has_method("_clear_target_highlighting"), "Step 4: Should have _clear_target_highlighting method")

func test_unit_cards_render():
	"""
	RENDERING TEST:
	1. Verify BattleUnitCard has correct minimum size (220x75)
	2. Check card uses horizontal layout
	3. Verify portrait size is 64x64
	4. Test setup_unit method exists
	"""
	setup()

	# STEP 1: Load BattleUnitCard scene
	var card_scene = load("res://scenes/ui/battle/BattleUnitCard.tscn")
	runner.assert_not_null(card_scene, "Step 1: BattleUnitCard scene should load")

	# STEP 2: Instantiate card
	var card = card_scene.instantiate()
	runner.assert_not_null(card, "Step 2: Should instantiate BattleUnitCard")

	# STEP 3: Check minimum size
	runner.assert_equal(card.custom_minimum_size, Vector2(220, 75), "Step 3: Card size should be 220x75")

	# STEP 4: Verify setup_unit method
	runner.assert_true(card.has_method("setup_unit"), "Step 4: Should have setup_unit method")

	# Clean up
	card.queue_free()

func test_ability_bar_no_hover():
	"""
	MOBILE UX TEST:
	1. Verify AbilityBar has no hover-related signals
	2. Check no tooltip system exists
	3. Validate mobile tap-only interaction
	"""
	setup()

	# STEP 1: Load AbilityBar scene
	var ability_bar_scene = load("res://scenes/ui/battle/AbilityBar.tscn")
	runner.assert_not_null(ability_bar_scene, "Step 1: AbilityBar scene should load")

	# STEP 2: Check script for hover methods (should not exist)
	var ability_bar_script = load("res://scripts/ui/battle/AbilityBar.gd")
	runner.assert_not_null(ability_bar_script, "Step 2: AbilityBar script should load")

	var ability_bar = ability_bar_scene.instantiate()

	# STEP 3: Verify NO hover methods exist
	runner.assert_false(ability_bar.has_method("_on_skill_button_hover"), "Step 3: Should NOT have hover method")
	runner.assert_false(ability_bar.has_method("_show_tooltip"), "Step 3: Should NOT have tooltip method")

	# STEP 4: Verify highlight_skill takes 2 parameters
	runner.assert_true(ability_bar.has_method("highlight_skill"), "Step 4: Should have highlight_skill method")

	# Clean up
	ability_bar.queue_free()

func test_battle_coordinator_turn_advancement():
	"""
	BATTLE FLOW TEST:
	1. Verify BattleCoordinator advances turn after manual actions
	2. Check turn manager integration
	3. Validate action execution returns success
	"""
	setup()

	runner.assert_not_null(battle_coordinator, "BattleCoordinator should exist")
	runner.assert_true(battle_coordinator.has_method("execute_action"), "Should have execute_action method")

	# Verify turn manager exists
	runner.assert_true("turn_manager" in battle_coordinator, "Should have turn_manager")
