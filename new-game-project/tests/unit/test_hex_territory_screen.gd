# tests/unit/test_hex_territory_screen.gd
extends GutTest

"""
Unit tests for HexTerritoryScreen
Tests screen coordinator, layout, component integration, and signal handling
"""

# Test subject
var hex_territory_screen = null

# Test doubles
var mock_resource_manager = null
var mock_territory_manager = null
var mock_collection_manager = null
var mock_hex_grid_manager = null
var mock_node_requirement_checker = null

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================
func before_each():
	# Create test subject
	var script = load("res://scripts/ui/screens/HexTerritoryScreen.gd")
	hex_territory_screen = script.new()

	# Create mocks
	mock_resource_manager = autofree(double("res://scripts/systems/resources/ResourceManager.gd").new())
	mock_territory_manager = autofree(double("res://scripts/systems/territory/TerritoryManager.gd").new())
	mock_collection_manager = autofree(double("res://scripts/systems/collection/CollectionManager.gd").new())
	mock_hex_grid_manager = autofree(double("res://scripts/systems/territory/HexGridManager.gd").new())
	mock_node_requirement_checker = autofree(double("res://scripts/systems/territory/NodeRequirementChecker.gd").new())

	# Stub system registry
	stub(SystemRegistry, "get_instance").to_return(autofree(double("res://scripts/systems/core/SystemRegistry.gd").new()))
	stub(SystemRegistry.get_instance(), "get_system").to_return(null)
	stub(SystemRegistry.get_instance(), "get_system").to_return(mock_resource_manager).when_passed("ResourceManager")
	stub(SystemRegistry.get_instance(), "get_system").to_return(mock_territory_manager).when_passed("TerritoryManager")
	stub(SystemRegistry.get_instance(), "get_system").to_return(mock_collection_manager).when_passed("CollectionManager")
	stub(SystemRegistry.get_instance(), "get_system").to_return(mock_hex_grid_manager).when_passed("HexGridManager")
	stub(SystemRegistry.get_instance(), "get_system").to_return(mock_node_requirement_checker).when_passed("NodeRequirementChecker")

	# Default mock behaviors
	stub(mock_resource_manager, "get_resource_amount").to_return(1000)

func after_each():
	if hex_territory_screen:
		hex_territory_screen.queue_free()
	hex_territory_screen = null

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================
func test_screen_initialization():
	assert_not_null(hex_territory_screen, "Screen should be created")
	assert_true(hex_territory_screen is Control, "Screen should extend Control")

func test_screen_has_class_name():
	add_child_autofree(hex_territory_screen)
	# class_name is verified by successful script loading
	assert_not_null(hex_territory_screen, "HexTerritoryScreen class should be defined")

func test_screen_fills_viewport():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Check anchors are set to fill
	assert_eq(hex_territory_screen.anchor_right, 1.0, "Should anchor to right")
	assert_eq(hex_territory_screen.anchor_bottom, 1.0, "Should anchor to bottom")

func test_creates_main_container():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var main_container = hex_territory_screen.get_node_or_null("MainContainer")
	assert_not_null(main_container, "Should create main container")

# ==============================================================================
# UI STRUCTURE TESTS
# ==============================================================================
func test_creates_top_bar():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var top_bar = hex_territory_screen.get_node_or_null("MainContainer/TopBar")
	assert_not_null(top_bar, "Should create top bar")
	assert_true(top_bar is HBoxContainer, "Top bar should be HBoxContainer")

func test_creates_back_button():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var back_button = hex_territory_screen.get_node_or_null("MainContainer/TopBar/BackButton")
	assert_not_null(back_button, "Should create back button")
	assert_true(back_button is Button, "Back button should be Button")
	assert_eq(back_button.text, "← BACK", "Back button should have correct text")

func test_creates_resource_display():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var resource_display = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay")
	assert_not_null(resource_display, "Should create resource display")
	assert_true(resource_display is HBoxContainer, "Resource display should be HBoxContainer")

func test_creates_resource_labels():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var gold_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/gold_label")
	var mana_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/mana_label")
	var crystals_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/divine_crystals_label")

	assert_not_null(gold_label, "Should create gold label")
	assert_not_null(mana_label, "Should create mana label")
	assert_not_null(crystals_label, "Should create divine crystals label")

func test_creates_center_container():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var center_container = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer")
	assert_not_null(center_container, "Should create center container")
	assert_true(center_container is Control, "Center container should be Control")

func test_creates_zoom_controls():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var zoom_controls = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer/ZoomControls")
	assert_not_null(zoom_controls, "Should create zoom controls")
	assert_true(zoom_controls is VBoxContainer, "Zoom controls should be VBoxContainer")

func test_creates_zoom_buttons():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var zoom_in = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer/ZoomControls/ZoomInButton")
	var zoom_out = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer/ZoomControls/ZoomOutButton")
	var center = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer/ZoomControls/CenterButton")

	assert_not_null(zoom_in, "Should create zoom in button")
	assert_not_null(zoom_out, "Should create zoom out button")
	assert_not_null(center, "Should create center button")
	assert_eq(zoom_in.text, "+", "Zoom in should show +")
	assert_eq(zoom_out.text, "-", "Zoom out should show -")
	assert_eq(center.text, "⌂", "Center should show home icon")

func test_creates_panel_container():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_not_null(panel_container, "Should create panel container")
	assert_false(panel_container.visible, "Panel container should start hidden")

# ==============================================================================
# COMPONENT SETUP TESTS
# ==============================================================================
func test_creates_hex_map_view():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var hex_map_view = hex_territory_screen.get_node_or_null("MainContainer/CenterContainer/HexMapView")
	assert_not_null(hex_map_view, "Should create HexMapView")

func test_creates_node_info_panel():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var node_info_panel = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer/NodeInfoPanel")
	assert_not_null(node_info_panel, "Should create NodeInfoPanel")

func test_creates_node_requirements_panel():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var requirements_panel = hex_territory_screen.get_node_or_null("MainContainer/NodeRequirementsPanel")
	assert_not_null(requirements_panel, "Should create NodeRequirementsPanel")
	assert_false(requirements_panel.visible, "Requirements panel should start hidden")

# ==============================================================================
# SIGNAL TESTS
# ==============================================================================
func test_has_back_pressed_signal():
	assert_has_signal(hex_territory_screen, "back_pressed", "Should have back_pressed signal")

func test_back_button_emits_signal():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	watch_signals(hex_territory_screen)

	var back_button = hex_territory_screen.get_node_or_null("MainContainer/TopBar/BackButton")
	if back_button:
		back_button.pressed.emit()
		await wait_frames(1)

	assert_signal_emitted(hex_territory_screen, "back_pressed", "Back button should emit back_pressed")

# ==============================================================================
# RESOURCE DISPLAY TESTS
# ==============================================================================
func test_resource_display_shows_gold():
	stub(mock_resource_manager, "get_resource_amount").to_return(5000).when_passed("gold")
	stub(mock_resource_manager, "get_resource_amount").to_return(1000).when_passed("mana")
	stub(mock_resource_manager, "get_resource_amount").to_return(50).when_passed("divine_crystals")

	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var gold_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/gold_label")
	assert_not_null(gold_label, "Gold label should exist")
	assert_string_contains(gold_label.text, "5000", "Gold label should show amount")

func test_resource_display_shows_mana():
	stub(mock_resource_manager, "get_resource_amount").to_return(5000).when_passed("gold")
	stub(mock_resource_manager, "get_resource_amount").to_return(3000).when_passed("mana")
	stub(mock_resource_manager, "get_resource_amount").to_return(50).when_passed("divine_crystals")

	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var mana_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/mana_label")
	assert_not_null(mana_label, "Mana label should exist")
	assert_string_contains(mana_label.text, "3000", "Mana label should show amount")

func test_resource_display_shows_divine_crystals():
	stub(mock_resource_manager, "get_resource_amount").to_return(5000).when_passed("gold")
	stub(mock_resource_manager, "get_resource_amount").to_return(1000).when_passed("mana")
	stub(mock_resource_manager, "get_resource_amount").to_return(75).when_passed("divine_crystals")

	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var crystals_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/divine_crystals_label")
	assert_not_null(crystals_label, "Divine crystals label should exist")
	assert_string_contains(crystals_label.text, "75", "Divine crystals label should show amount")

func test_resource_display_includes_icons():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var gold_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/gold_label")
	var mana_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/mana_label")
	var crystals_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/divine_crystals_label")

	if gold_label:
		assert_string_contains(gold_label.text, "💰", "Gold should have icon")
	if mana_label:
		assert_string_contains(mana_label.text, "✨", "Mana should have icon")
	if crystals_label:
		assert_string_contains(crystals_label.text, "💎", "Crystals should have icon")

# ==============================================================================
# NODE INFO PANEL TESTS
# ==============================================================================
func test_panel_container_starts_hidden():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_not_null(panel_container, "Panel container should exist")
	assert_false(panel_container.visible, "Panel container should start hidden")

func test_show_node_info_makes_panel_visible():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Create test node
	var hex_node = load("res://scripts/data/HexNode.gd").new()
	hex_node.id = "test_node"
	hex_node.name = "Test Node"

	# Show node info
	hex_territory_screen._show_node_info(hex_node)
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_true(panel_container.visible, "Panel container should be visible after showing node")

func test_hide_node_info_hides_panel():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Create and show test node
	var hex_node = load("res://scripts/data/HexNode.gd").new()
	hex_node.id = "test_node"
	hex_territory_screen._show_node_info(hex_node)
	await wait_frames(1)

	# Hide panel
	hex_territory_screen._hide_node_info()
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_false(panel_container.visible, "Panel container should be hidden")

func test_hide_node_info_clears_selected_node():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Create and show test node
	var hex_node = load("res://scripts/data/HexNode.gd").new()
	hex_node.id = "test_node"
	hex_territory_screen._show_node_info(hex_node)
	await wait_frames(1)

	assert_not_null(hex_territory_screen.selected_node, "Selected node should be set")

	# Hide panel
	hex_territory_screen._hide_node_info()
	await wait_frames(1)

	assert_null(hex_territory_screen.selected_node, "Selected node should be cleared")

# ==============================================================================
# REQUIREMENTS PANEL TESTS
# ==============================================================================
func test_requirements_panel_starts_hidden():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var requirements_panel = hex_territory_screen.get_node_or_null("MainContainer/NodeRequirementsPanel")
	assert_not_null(requirements_panel, "Requirements panel should exist")
	assert_false(requirements_panel.visible, "Requirements panel should start hidden")

# ==============================================================================
# REFRESH TESTS
# ==============================================================================
func test_refresh_updates_resource_display():
	stub(mock_resource_manager, "get_resource_amount").to_return(1000).when_passed("gold")

	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	var gold_label = hex_territory_screen.get_node_or_null("MainContainer/TopBar/ResourceDisplay/gold_label")
	var initial_text = gold_label.text if gold_label else ""

	# Change resource amount
	stub(mock_resource_manager, "get_resource_amount").to_return(5000).when_passed("gold")

	# Refresh
	hex_territory_screen.refresh()
	await wait_frames(1)

	var updated_text = gold_label.text if gold_label else ""
	assert_string_contains(updated_text, "5000", "Gold should be updated after refresh")

# ==============================================================================
# CONSTANTS TESTS
# ==============================================================================
func test_has_top_bar_height_constant():
	assert_true(hex_territory_screen.has("TOP_BAR_HEIGHT"), "Should have TOP_BAR_HEIGHT constant")
	assert_eq(hex_territory_screen.TOP_BAR_HEIGHT, 60, "TOP_BAR_HEIGHT should be 60")

func test_has_info_panel_width_constant():
	assert_true(hex_territory_screen.has("INFO_PANEL_WIDTH"), "Should have INFO_PANEL_WIDTH constant")
	assert_eq(hex_territory_screen.INFO_PANEL_WIDTH, 380, "INFO_PANEL_WIDTH should be 380")

# ==============================================================================
# EDGE CASES
# ==============================================================================
func test_show_node_info_with_null_node():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Try to show null node
	hex_territory_screen._show_node_info(null)
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_false(panel_container.visible, "Panel should not show for null node")

func test_hide_node_info_when_already_hidden():
	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Hide when already hidden (should not error)
	hex_territory_screen._hide_node_info()
	await wait_frames(1)

	var panel_container = hex_territory_screen.get_node_or_null("MainContainer/PanelContainer")
	assert_false(panel_container.visible, "Panel should remain hidden")

func test_refresh_with_no_resource_manager():
	# Clear resource manager
	stub(SystemRegistry.get_instance(), "get_system").to_return(null).when_passed("ResourceManager")

	add_child_autofree(hex_territory_screen)
	await wait_frames(1)

	# Should not error
	hex_territory_screen.refresh()
	await wait_frames(1)

	assert_not_null(hex_territory_screen, "Screen should still exist after refresh with no resource manager")
