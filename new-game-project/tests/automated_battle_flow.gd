# tests/automated_battle_flow.gd
# Automated test script for battle flow using Godot MCP
extends Node

# Test configuration
const WAIT_TIME_SHORT = 0.5  # Seconds between quick actions
const WAIT_TIME_MEDIUM = 1.0  # Seconds for UI transitions
const WAIT_TIME_LONG = 2.0  # Seconds for battle setup

# Test state
var test_step = 0
var test_failed = false
var failure_reason = ""

func _ready():
	print("\n========================================")
	print("AUTOMATED BATTLE FLOW TEST")
	print("========================================\n")

	# Start test sequence
	await get_tree().create_timer(1.0).timeout
	_run_test()

func _run_test():
	"""Execute the full battle flow test"""

	# Step 1: Navigate to Territory
	if not await _step_navigate_to_territory():
		_fail_test("Failed to navigate to Territory")
		return

	# Step 2: Click through tutorial (3 times)
	if not await _step_complete_tutorial():
		_fail_test("Failed to complete tutorial")
		return

	# Step 3: Select a capturable node
	if not await _step_select_capturable_node():
		_fail_test("Failed to select capturable node")
		return

	# Step 4: Select 4 gods in battle setup
	if not await _step_select_gods():
		_fail_test("Failed to select gods")
		return

	# Step 5: Start battle
	if not await _step_start_battle():
		_fail_test("Failed to start battle")
		return

	# Step 6: Test battle flow
	if not await _step_test_battle_flow():
		_fail_test("Failed battle flow test")
		return

	# All tests passed!
	_pass_test()

# ============================================================================
# TEST STEPS
# ============================================================================

func _step_navigate_to_territory() -> bool:
	"""Step 1: Click TERRITORY button from WorldView"""
	print("[STEP 1] Navigating to Territory...")

	# Check if we're on WorldView
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if not screen_manager:
		print("  ERROR: ScreenManager not found")
		return false

	var current_screen = screen_manager.get_current_screen_name()
	print("  Current screen: ", current_screen)

	if current_screen != "WorldView":
		print("  ERROR: Not on WorldView. Current screen: ", current_screen)
		return false

	# Find and click TERRITORY button
	var world_view = screen_manager.get_screen("WorldView")
	if not world_view:
		print("  ERROR: WorldView screen not found")
		return false

	var territory_button = _find_button_by_text(world_view, "TERRITORY")
	if not territory_button:
		print("  ERROR: TERRITORY button not found")
		return false

	print("  Clicking TERRITORY button...")
	territory_button.pressed.emit()

	await get_tree().create_timer(WAIT_TIME_MEDIUM).timeout

	# Verify we're on HexTerritoryMap
	current_screen = screen_manager.get_current_screen_name()
	if current_screen != "HexTerritoryMap":
		print("  ERROR: Failed to navigate to HexTerritoryMap. Current screen: ", current_screen)
		return false

	print("  SUCCESS: Navigated to Territory\n")
	return true

func _step_complete_tutorial() -> bool:
	"""Step 2: Click through tutorial dialogs (3 times)"""
	print("[STEP 2] Completing tutorial...")

	for i in range(3):
		await get_tree().create_timer(WAIT_TIME_SHORT).timeout

		# Find "Got it!" or "Next" button
		var tutorial_button = _find_tutorial_button()
		if not tutorial_button:
			print("  ERROR: Tutorial button not found on click ", i + 1)
			return false

		print("  Clicking tutorial button ", i + 1, "/3...")
		tutorial_button.pressed.emit()

	await get_tree().create_timer(WAIT_TIME_MEDIUM).timeout

	print("  SUCCESS: Tutorial completed\n")
	return true

func _step_select_capturable_node() -> bool:
	"""Step 3: Click a capturable hex node"""
	print("[STEP 3] Selecting capturable node...")

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var hex_map = screen_manager.get_screen("HexTerritoryMap")
	if not hex_map:
		print("  ERROR: HexTerritoryMap not found")
		return false

	# Find the hex grid
	var hex_grid = _find_node_by_name(hex_map, "HexGrid")
	if not hex_grid:
		print("  ERROR: HexGrid not found")
		return false

	# Find first capturable node
	var capturable_node = null
	for child in hex_grid.get_children():
		if child.has_method("is_capturable") and child.is_capturable():
			capturable_node = child
			break

	if not capturable_node:
		print("  ERROR: No capturable nodes found")
		return false

	print("  Clicking capturable node...")
	capturable_node._on_node_clicked()

	await get_tree().create_timer(WAIT_TIME_MEDIUM).timeout

	# Verify BattleSetup screen opened
	var current_screen = screen_manager.get_current_screen_name()
	if current_screen != "BattleSetup":
		print("  ERROR: BattleSetup screen not opened. Current: ", current_screen)
		return false

	print("  SUCCESS: Capturable node selected\n")
	return true

func _step_select_gods() -> bool:
	"""Step 4: Select 4 gods in battle setup"""
	print("[STEP 4] Selecting 4 gods...")

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_setup = screen_manager.get_screen("BattleSetup")
	if not battle_setup:
		print("  ERROR: BattleSetup screen not found")
		return false

	# Find available god cards
	var god_cards = _find_all_god_cards(battle_setup)
	if god_cards.size() < 4:
		print("  ERROR: Not enough god cards found. Found: ", god_cards.size())
		return false

	# Click first 4 god cards
	for i in range(4):
		await get_tree().create_timer(WAIT_TIME_SHORT).timeout
		print("  Selecting god ", i + 1, "/4...")
		god_cards[i]._on_card_clicked()

	await get_tree().create_timer(WAIT_TIME_MEDIUM).timeout

	print("  SUCCESS: 4 gods selected\n")
	return true

func _step_start_battle() -> bool:
	"""Step 5: Click START BATTLE button"""
	print("[STEP 5] Starting battle...")

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_setup = screen_manager.get_screen("BattleSetup")
	if not battle_setup:
		print("  ERROR: BattleSetup screen not found")
		return false

	# Find START BATTLE button
	var start_button = _find_button_by_text(battle_setup, "START BATTLE")
	if not start_button:
		print("  ERROR: START BATTLE button not found")
		return false

	print("  Clicking START BATTLE...")
	start_button.pressed.emit()

	await get_tree().create_timer(WAIT_TIME_LONG).timeout

	# Verify BattleScreen opened
	var current_screen = screen_manager.get_current_screen_name()
	if current_screen != "BattleScreen":
		print("  ERROR: BattleScreen not opened. Current: ", current_screen)
		return false

	print("  SUCCESS: Battle started\n")
	return true

func _step_test_battle_flow() -> bool:
	"""Step 6: Test mobile two-tap battle flow"""
	print("[STEP 6] Testing battle flow...")

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_screen = screen_manager.get_screen("BattleScreen")
	if not battle_screen:
		print("  ERROR: BattleScreen not found")
		return false

	# Test 1: Verify unit cards are visible
	print("  Test 6.1: Verifying unit cards...")
	var player_cards = _find_all_unit_cards(battle_screen, true)
	var enemy_cards = _find_all_unit_cards(battle_screen, false)

	if player_cards.is_empty():
		print("    ERROR: No player unit cards found")
		return false

	if enemy_cards.is_empty():
		print("    ERROR: No enemy unit cards found")
		return false

	print("    SUCCESS: Found ", player_cards.size(), " player cards, ", enemy_cards.size(), " enemy cards")

	# Test 2: Verify ability bar is visible
	print("  Test 6.2: Verifying ability bar...")
	var ability_bar = _find_node_by_name(battle_screen, "AbilityBar")
	if not ability_bar:
		print("    ERROR: AbilityBar not found")
		return false

	if not ability_bar.visible:
		print("    ERROR: AbilityBar not visible")
		return false

	print("    SUCCESS: AbilityBar visible")

	# Test 3: Select an ability
	print("  Test 6.3: Testing ability selection...")
	await get_tree().create_timer(WAIT_TIME_SHORT).timeout

	var skill_buttons = ability_bar.skill_buttons
	if skill_buttons.is_empty():
		print("    ERROR: No skill buttons found")
		return false

	print("    Clicking first ability...")
	skill_buttons[0].pressed.emit()

	await get_tree().create_timer(WAIT_TIME_SHORT).timeout

	# Verify skill was selected
	if not battle_screen.selected_skill:
		print("    ERROR: Skill not selected")
		return false

	print("    SUCCESS: Skill selected: ", battle_screen.selected_skill.name)

	# Test 4: Target an enemy
	print("  Test 6.4: Testing enemy targeting...")
	await get_tree().create_timer(WAIT_TIME_SHORT).timeout

	if enemy_cards.is_empty():
		print("    ERROR: No enemy cards to target")
		return false

	print("    Clicking first enemy...")
	enemy_cards[0]._on_card_clicked()

	await get_tree().create_timer(WAIT_TIME_MEDIUM).timeout

	# Verify action was executed (skill selection cleared)
	if battle_screen.selected_skill:
		print("    ERROR: Skill still selected after targeting")
		return false

	print("    SUCCESS: Enemy targeted and action executed")

	print("  SUCCESS: Battle flow working correctly\n")
	return true

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _find_button_by_text(root: Node, button_text: String) -> Button:
	"""Recursively find a button by its text"""
	if root is Button and root.text == button_text:
		return root

	for child in root.get_children():
		var result = _find_button_by_text(child, button_text)
		if result:
			return result

	return null

func _find_node_by_name(root: Node, node_name: String) -> Node:
	"""Recursively find a node by its name"""
	if root.name == node_name:
		return root

	for child in root.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result

	return null

func _find_tutorial_button() -> Button:
	"""Find tutorial 'Got it!' or 'Next' button"""
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var hex_map = screen_manager.get_screen("HexTerritoryMap")
	if not hex_map:
		return null

	# Look for common tutorial button texts
	var button_texts = ["Got it!", "Next", "Continue", "OK"]
	for text in button_texts:
		var button = _find_button_by_text(hex_map, text)
		if button:
			return button

	return null

func _find_all_god_cards(root: Node) -> Array:
	"""Find all GodCard instances"""
	var cards = []

	if root.has_method("_on_card_clicked"):
		cards.append(root)

	for child in root.get_children():
		cards.append_array(_find_all_god_cards(child))

	return cards

func _find_all_unit_cards(root: Node, is_player: bool) -> Array:
	"""Find all BattleUnitCard instances"""
	var cards = []

	if root is Panel and root.get_script() and root.get_script().resource_path.ends_with("BattleUnitCard.gd"):
		if root.battle_unit and root.battle_unit.is_player_unit == is_player:
			cards.append(root)

	for child in root.get_children():
		cards.append_array(_find_all_unit_cards(child, is_player))

	return cards

# ============================================================================
# TEST RESULT REPORTING
# ============================================================================

func _fail_test(reason: String):
	"""Mark test as failed and report"""
	test_failed = true
	failure_reason = reason

	print("\n========================================")
	print("TEST FAILED")
	print("========================================")
	print("Reason: ", reason)
	print("\nTest stopped at step ", test_step)
	print("========================================\n")

func _pass_test():
	"""Mark test as passed and report"""
	print("\n========================================")
	print("ALL TESTS PASSED!")
	print("========================================")
	print("Battle flow is working correctly:")
	print("  ✓ Territory navigation")
	print("  ✓ Tutorial completion")
	print("  ✓ Node selection")
	print("  ✓ God selection")
	print("  ✓ Battle start")
	print("  ✓ Ability selection (mobile two-tap)")
	print("  ✓ Enemy targeting")
	print("  ✓ Action execution")
	print("========================================\n")
