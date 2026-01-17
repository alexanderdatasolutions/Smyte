# tests/unit/test_hex_territory_tutorial.gd
# Tests for hex territory tutorial system
extends GutTest

# Test file for hex territory tutorial integration
# Verifies tutorial triggers and flow for hex map features

var tutorial_orchestrator: TutorialOrchestrator
var event_bus: EventBus

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================

func before_each():
	"""Setup test environment"""
	# Create TutorialOrchestrator instance
	tutorial_orchestrator = TutorialOrchestrator.new()
	add_child_autofree(tutorial_orchestrator)

	# Create EventBus instance
	event_bus = EventBus.new()
	add_child_autofree(event_bus)

func after_each():
	"""Cleanup test environment"""
	tutorial_orchestrator = null
	event_bus = null

# ==============================================================================
# TUTORIAL DEFINITION TESTS
# ==============================================================================

func test_hex_territory_intro_tutorial_exists():
	assert_true(tutorial_orchestrator.tutorial_steps.has("hex_territory_intro"),
		"hex_territory_intro tutorial should exist")

func test_hex_territory_intro_has_three_steps():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_territory_intro", [])
	assert_eq(steps.size(), 3, "hex_territory_intro should have 3 steps")

func test_hex_territory_intro_first_step_is_map_intro():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_territory_intro", [])
	if steps.size() > 0:
		assert_eq(steps[0].type, "hex_map_intro", "First step should be hex_map_intro")

func test_hex_territory_intro_second_step_is_node_selection():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_territory_intro", [])
	if steps.size() > 1:
		assert_eq(steps[1].type, "hex_node_selection", "Second step should be hex_node_selection")

func test_hex_territory_intro_third_step_is_node_capture():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_territory_intro", [])
	if steps.size() > 2:
		assert_eq(steps[2].type, "hex_node_capture", "Third step should be hex_node_capture")

func test_hex_specialization_unlock_tutorial_exists():
	assert_true(tutorial_orchestrator.tutorial_steps.has("hex_specialization_unlock"),
		"hex_specialization_unlock tutorial should exist")

func test_hex_specialization_unlock_has_one_step():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_specialization_unlock", [])
	assert_eq(steps.size(), 1, "hex_specialization_unlock should have 1 step")

func test_hex_specialization_unlock_step_is_spec_unlock_tier2():
	var steps = tutorial_orchestrator.tutorial_steps.get("hex_specialization_unlock", [])
	if steps.size() > 0:
		assert_eq(steps[0].type, "spec_unlock_tier2", "Step should be spec_unlock_tier2")

# ==============================================================================
# TUTORIAL STATE TESTS
# ==============================================================================

func test_can_start_hex_territory_intro_tutorial():
	var result = tutorial_orchestrator.start_tutorial("hex_territory_intro")
	assert_true(result, "Should be able to start hex_territory_intro tutorial")
	assert_true(tutorial_orchestrator.is_tutorial_active(), "Tutorial should be active")

func test_cannot_start_completed_tutorial():
	tutorial_orchestrator.completed_tutorials.append("hex_territory_intro")
	var result = tutorial_orchestrator.start_tutorial("hex_territory_intro")
	assert_false(result, "Should not be able to start completed tutorial")

func test_is_tutorial_completed_returns_true_for_completed():
	tutorial_orchestrator.completed_tutorials.append("hex_territory_intro")
	assert_true(tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"),
		"Should return true for completed tutorial")

func test_is_tutorial_completed_returns_false_for_not_completed():
	assert_false(tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"),
		"Should return false for not completed tutorial")

# ==============================================================================
# TUTORIAL SIGNAL TESTS
# ==============================================================================

func test_show_tutorial_requested_signal_exists_in_event_bus():
	# Check EventBus has the signal
	var signals_list = event_bus.get_signal_list()
	var has_signal = false
	for sig in signals_list:
		if sig.name == "show_tutorial_requested":
			has_signal = true
			break
	assert_true(has_signal, "EventBus should have show_tutorial_requested signal")

# ==============================================================================
# TUTORIAL FLOW TESTS
# ==============================================================================

func test_tutorial_advances_through_steps():
	tutorial_orchestrator.start_tutorial("hex_territory_intro")

	# Should be on step 0
	var info = tutorial_orchestrator.get_current_tutorial_info()
	assert_eq(info.step, 0, "Should start at step 0")

	# Advance to step 1
	tutorial_orchestrator.advance_tutorial()
	info = tutorial_orchestrator.get_current_tutorial_info()
	assert_eq(info.step, 1, "Should advance to step 1")

	# Advance to step 2
	tutorial_orchestrator.advance_tutorial()
	info = tutorial_orchestrator.get_current_tutorial_info()
	assert_eq(info.step, 2, "Should advance to step 2")

func test_tutorial_completes_after_all_steps():
	tutorial_orchestrator.start_tutorial("hex_territory_intro")

	# Advance through all 3 steps
	tutorial_orchestrator.advance_tutorial()
	tutorial_orchestrator.advance_tutorial()
	tutorial_orchestrator.advance_tutorial()

	# Tutorial should be completed
	assert_false(tutorial_orchestrator.is_tutorial_active(), "Tutorial should not be active")
	assert_true(tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"),
		"Tutorial should be marked as completed")

func test_get_current_tutorial_info_returns_empty_when_not_active():
	var info = tutorial_orchestrator.get_current_tutorial_info()
	assert_eq(info, {}, "Should return empty dict when no tutorial active")

func test_get_current_tutorial_info_returns_correct_data():
	tutorial_orchestrator.start_tutorial("hex_territory_intro")
	var info = tutorial_orchestrator.get_current_tutorial_info()

	assert_eq(info.name, "hex_territory_intro", "Should return correct tutorial name")
	assert_eq(info.step, 0, "Should return current step")
	assert_eq(info.total_steps, 3, "Should return total steps")

# ==============================================================================
# SKIP TUTORIAL TESTS
# ==============================================================================

func test_skip_tutorial_completes_active_tutorial():
	tutorial_orchestrator.start_tutorial("hex_territory_intro")
	tutorial_orchestrator.skip_tutorial()

	assert_false(tutorial_orchestrator.is_tutorial_active(), "Tutorial should not be active")
	assert_true(tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"),
		"Tutorial should be marked as completed")

func test_skip_tutorial_does_nothing_when_no_tutorial_active():
	tutorial_orchestrator.skip_tutorial()
	assert_false(tutorial_orchestrator.is_tutorial_active(), "No tutorial should be active")

# ==============================================================================
# SAVE/LOAD TESTS
# ==============================================================================

func test_get_tutorial_save_data_includes_completed_tutorials():
	tutorial_orchestrator.completed_tutorials.append("hex_territory_intro")
	var save_data = tutorial_orchestrator.get_tutorial_save_data()

	assert_true(save_data.has("completed_tutorials"), "Save data should have completed_tutorials")
	assert_true(save_data.completed_tutorials.has("hex_territory_intro"),
		"Save data should include completed tutorial")

func test_load_tutorial_save_data_restores_completed_tutorials():
	var save_data = {
		"completed_tutorials": ["hex_territory_intro", "hex_specialization_unlock"],
		"current_tutorial": "",
		"current_step": 0
	}

	tutorial_orchestrator.load_tutorial_save_data(save_data)

	assert_true(tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"),
		"Should restore hex_territory_intro as completed")
	assert_true(tutorial_orchestrator.is_tutorial_completed("hex_specialization_unlock"),
		"Should restore hex_specialization_unlock as completed")

func test_get_tutorial_save_data_includes_current_tutorial_when_active():
	tutorial_orchestrator.start_tutorial("hex_territory_intro")
	tutorial_orchestrator.advance_tutorial()

	var save_data = tutorial_orchestrator.get_tutorial_save_data()

	assert_eq(save_data.current_tutorial, "hex_territory_intro",
		"Should save current tutorial name")
	assert_eq(save_data.current_step, 1, "Should save current step")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_cannot_start_nonexistent_tutorial():
	var result = tutorial_orchestrator.start_tutorial("nonexistent_tutorial")
	assert_false(result, "Should not be able to start nonexistent tutorial")

func test_advance_tutorial_returns_false_when_no_tutorial_active():
	var result = tutorial_orchestrator.advance_tutorial()
	assert_false(result, "Should return false when no tutorial active")
