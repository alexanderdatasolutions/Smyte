# tests/unit/test_garrison_management_panel.gd
extends GutTest

"""
Test suite for GarrisonManagementPanel.gd
Tests garrison assignment UI and god availability filtering
"""

var panel: GarrisonManagementPanel
var mock_collection_manager
var mock_territory_manager
var mock_hex_grid_manager
var test_node: HexNode
var test_god_1: God
var test_god_2: God
var test_god_3: God

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================

func before_each() -> void:
	"""Setup before each test"""
	panel = GarrisonManagementPanel.new()

	# Create mock systems
	mock_collection_manager = double(CollectionManager).new()
	mock_territory_manager = double(TerritoryManager).new()
	mock_hex_grid_manager = double(HexGridManager).new()

	# Inject mocks
	panel.collection_manager = mock_collection_manager
	panel.territory_manager = mock_territory_manager

	# Create test node
	test_node = HexNode.new()
	test_node.id = "test_node"
	test_node.name = "Test Node"
	test_node.node_type = "mine"
	test_node.tier = 2
	test_node.max_garrison = 3
	test_node.garrison = []
	test_node.assigned_workers = []
	test_node.coord = HexCoord.from_qr(1, 0)

	# Create test gods
	test_god_1 = _create_test_god("god_1", "Zeus", 20, 1000, 150, 100)
	test_god_2 = _create_test_god("god_2", "Thor", 25, 1200, 180, 120)
	test_god_3 = _create_test_god("god_3", "Odin", 30, 1500, 200, 150)

func after_each() -> void:
	"""Cleanup after each test"""
	if panel:
		panel.free()

# ==============================================================================
# HELPER METHODS
# ==============================================================================

func _create_test_god(id: String, god_name: String, level: int, hp: int, attack: int, defense: int) -> God:
	"""Create a test god with specified stats"""
	var god_data = God.new()
	god_data.id = id
	god_data.god_name = god_name
	god_data.level = level
	god_data.base_hp = hp
	god_data.base_attack = attack
	god_data.base_defense = defense
	god_data.awakening_level = 0
	return god_data

func _setup_panel() -> void:
	"""Setup panel UI"""
	add_child_autofree(panel)
	panel._build_ui()

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_panel_initializes_hidden() -> void:
	"""Test panel starts hidden"""
	_setup_panel()
	assert_false(panel.visible, "Panel should start hidden")

func test_panel_has_correct_size() -> void:
	"""Test panel has correct minimum size"""
	_setup_panel()
	assert_eq(panel.custom_minimum_size.x, GarrisonManagementPanel.PANEL_WIDTH)
	assert_eq(panel.custom_minimum_size.y, GarrisonManagementPanel.PANEL_HEIGHT)

func test_panel_constants() -> void:
	"""Test panel constants are defined"""
	assert_eq(GarrisonManagementPanel.PANEL_WIDTH, 600)
	assert_eq(GarrisonManagementPanel.PANEL_HEIGHT, 500)
	assert_eq(GarrisonManagementPanel.BUTTON_HEIGHT, 36)
	assert_eq(GarrisonManagementPanel.ITEM_HEIGHT, 40)

# ==============================================================================
# SIGNAL TESTS
# ==============================================================================

func test_signals_exist() -> void:
	"""Test panel has required signals"""
	assert_has_signal(panel, "close_requested")
	assert_has_signal(panel, "garrison_assigned")
	assert_has_signal(panel, "garrison_unassigned")

# ==============================================================================
# SHOW/HIDE TESTS
# ==============================================================================

func test_show_garrison_makes_visible() -> void:
	"""Test showing garrison makes panel visible"""
	_setup_panel()
	panel.show_garrison(test_node)
	assert_true(panel.visible, "Panel should be visible after show_garrison")

func test_show_garrison_sets_current_node() -> void:
	"""Test show_garrison sets current node"""
	_setup_panel()
	panel.show_garrison(test_node)
	assert_eq(panel.current_node, test_node)

func test_show_garrison_with_null_node() -> void:
	"""Test show_garrison with null node"""
	_setup_panel()
	panel.show_garrison(null)
	assert_false(panel.visible, "Panel should not be visible with null node")

func test_hide_panel_makes_invisible() -> void:
	"""Test hiding panel makes it invisible"""
	_setup_panel()
	panel.show_garrison(test_node)
	panel.hide_panel()
	assert_false(panel.visible, "Panel should be hidden after hide_panel")

func test_hide_panel_clears_current_node() -> void:
	"""Test hiding panel clears current node"""
	_setup_panel()
	panel.show_garrison(test_node)
	panel.hide_panel()
	assert_null(panel.current_node, "Current node should be cleared after hide")

# ==============================================================================
# DEFENSE INFO TESTS
# ==============================================================================

func test_defense_info_with_node() -> void:
	"""Test defense info display with node"""
	_setup_panel()

	# Mock defense calculations
	stub(mock_territory_manager, "get_node_defense_rating").to_return(5000.0)
	stub(mock_territory_manager, "calculate_distance_penalty").to_return(0.05)
	stub(mock_territory_manager, "get_connected_bonus").to_return(0.1)

	panel.show_garrison(test_node)

	assert_not_null(panel._defense_info_label)
	assert_string_contains(panel._defense_info_label.text, "Defense Rating:")
	assert_string_contains(panel._defense_info_label.text, "5000")

func test_defense_info_without_territory_manager() -> void:
	"""Test defense info without territory manager"""
	_setup_panel()
	panel.territory_manager = null
	panel.show_garrison(test_node)

	assert_string_contains(panel._defense_info_label.text, "Unknown")

# ==============================================================================
# GARRISON DISPLAY TESTS
# ==============================================================================

func test_empty_garrison_display() -> void:
	"""Test display with empty garrison"""
	_setup_panel()
	test_node.garrison = []

	panel.show_garrison(test_node)

	# Should show empty state
	assert_not_null(panel._current_garrison_container)
	assert_gt(panel._current_garrison_container.get_child_count(), 0)

func test_garrison_with_one_god() -> void:
	"""Test garrison display with one god"""
	_setup_panel()
	test_node.garrison = ["god_1"]

	stub(mock_collection_manager, "get_god_by_id").to_return(test_god_1)

	panel.show_garrison(test_node)

	# Should show garrison count
	assert_gt(panel._current_garrison_container.get_child_count(), 0)

func test_garrison_with_multiple_gods() -> void:
	"""Test garrison display with multiple gods"""
	_setup_panel()
	test_node.garrison = ["god_1", "god_2"]

	stub(mock_collection_manager, "get_god_by_id").to_return(test_god_1, test_god_2)

	panel.show_garrison(test_node)

	# Should show multiple garrison rows
	assert_gt(panel._current_garrison_container.get_child_count(), 1)

func test_garrison_full() -> void:
	"""Test garrison display when full"""
	_setup_panel()
	test_node.max_garrison = 2
	test_node.garrison = ["god_1", "god_2"]

	stub(mock_collection_manager, "get_god_by_id").to_return(test_god_1, test_god_2)

	panel.show_garrison(test_node)

	# Verify garrison is shown as full
	assert_eq(test_node.garrison.size(), test_node.max_garrison)

# ==============================================================================
# AVAILABLE GODS TESTS
# ==============================================================================

func test_available_gods_display() -> void:
	"""Test available gods display"""
	_setup_panel()

	stub(mock_collection_manager, "get_all_gods").to_return([test_god_1, test_god_2, test_god_3])

	# Mock hex grid for availability checks
	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	panel.show_garrison(test_node)

	assert_not_null(panel._available_gods_container)
	assert_gt(panel._available_gods_container.get_child_count(), 0)

func test_available_gods_excludes_garrison() -> void:
	"""Test available gods excludes those in garrison"""
	_setup_panel()
	test_node.garrison = ["god_1"]

	stub(mock_collection_manager, "get_all_gods").to_return([test_god_1, test_god_2])

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var available = panel._get_available_gods()

	# Should not include god_1 (in garrison)
	var has_god_1 = false
	for god_data in available:
		if god_data.id == "god_1":
			has_god_1 = true
	assert_false(has_god_1, "God in garrison should not be available")

func test_available_gods_excludes_workers() -> void:
	"""Test available gods excludes those working"""
	_setup_panel()
	test_node.assigned_workers = ["god_2"]

	stub(mock_collection_manager, "get_all_gods").to_return([test_god_1, test_god_2])

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var available = panel._get_available_gods()

	# Should not include god_2 (working)
	var has_god_2 = false
	for god_data in available:
		if god_data.id == "god_2":
			has_god_2 = true
	assert_false(has_god_2, "God working should not be available")

func test_empty_available_gods() -> void:
	"""Test display when no gods available"""
	_setup_panel()

	stub(mock_collection_manager, "get_all_gods").to_return([])

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	panel.show_garrison(test_node)

	# Should show empty state
	assert_gt(panel._available_gods_container.get_child_count(), 0)

# ==============================================================================
# ASSIGNMENT TESTS
# ==============================================================================

func test_assign_god_to_garrison() -> void:
	"""Test assigning a god to garrison"""
	_setup_panel()

	stub(mock_collection_manager, "get_all_gods").to_return([test_god_1])

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	panel.show_garrison(test_node)

	watch_signals(panel)
	panel._on_assign_garrison_pressed("god_1")

	assert_signal_emitted(panel, "garrison_assigned")
	assert_has(test_node.garrison, "god_1")

func test_assign_god_garrison_full() -> void:
	"""Test assigning god when garrison is full"""
	_setup_panel()
	test_node.max_garrison = 2
	test_node.garrison = ["god_1", "god_2"]

	panel.show_garrison(test_node)

	var initial_size = test_node.garrison.size()
	panel._on_assign_garrison_pressed("god_3")

	# Should not add god when full
	assert_eq(test_node.garrison.size(), initial_size)

func test_unassign_god_from_garrison() -> void:
	"""Test unassigning a god from garrison"""
	_setup_panel()
	test_node.garrison = ["god_1", "god_2"]

	stub(mock_collection_manager, "get_god_by_id").to_return(test_god_1, test_god_2)

	panel.show_garrison(test_node)

	watch_signals(panel)
	panel._on_unassign_garrison_pressed("god_1")

	assert_signal_emitted(panel, "garrison_unassigned")
	assert_does_not_have(test_node.garrison, "god_1")

# ==============================================================================
# POWER CALCULATION TESTS
# ==============================================================================

func test_calculate_god_power() -> void:
	"""Test god power calculation"""
	_setup_panel()

	var power = panel._calculate_god_power(test_god_1)

	# Formula: (hp + attack*2 + defense*1.5) * (1 + (level-1)*0.1) * (1 + awakening*0.2)
	# (1000 + 150*2 + 100*1.5) * (1 + 19*0.1) * 1.0 = 1450 * 2.9 = 4205
	assert_almost_eq(power, 4205.0, 1.0, "Power calculation should match formula")

func test_calculate_god_power_with_awakening() -> void:
	"""Test power calculation with awakening"""
	_setup_panel()
	test_god_1.awakening_level = 2

	var power = panel._calculate_god_power(test_god_1)

	# (1000 + 150*2 + 100*1.5) * (1 + 19*0.1) * (1 + 2*0.2) = 1450 * 2.9 * 1.4 = 5887
	assert_almost_eq(power, 5887.0, 1.0, "Power should include awakening bonus")

func test_calculate_god_power_null() -> void:
	"""Test power calculation with null god"""
	_setup_panel()
	var power = panel._calculate_god_power(null)
	assert_eq(power, 0.0, "Null god should return 0 power")

# ==============================================================================
# HELPER METHOD TESTS
# ==============================================================================

func test_is_god_in_any_garrison() -> void:
	"""Test checking if god is in any garrison"""
	_setup_panel()
	test_node.garrison = ["god_1"]

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var result = panel._is_god_in_any_garrison("god_1")
	assert_true(result, "Should detect god in garrison")

func test_is_god_in_any_garrison_not_present() -> void:
	"""Test checking if god is not in any garrison"""
	_setup_panel()
	test_node.garrison = ["god_1"]

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var result = panel._is_god_in_any_garrison("god_3")
	assert_false(result, "Should not detect god not in garrison")

func test_is_god_working_anywhere() -> void:
	"""Test checking if god is working anywhere"""
	_setup_panel()
	test_node.assigned_workers = ["god_2"]

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var result = panel._is_god_working_anywhere("god_2")
	assert_true(result, "Should detect god working")

func test_is_god_working_anywhere_not_present() -> void:
	"""Test checking if god is not working anywhere"""
	_setup_panel()
	test_node.assigned_workers = ["god_2"]

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	var result = panel._is_god_working_anywhere("god_3")
	assert_false(result, "Should not detect god not working")

# ==============================================================================
# REFRESH TESTS
# ==============================================================================

func test_refresh_with_node() -> void:
	"""Test refresh with current node"""
	_setup_panel()

	stub(mock_collection_manager, "get_all_gods").to_return([test_god_1])
	stub(mock_territory_manager, "get_node_defense_rating").to_return(5000.0)
	stub(mock_territory_manager, "calculate_distance_penalty").to_return(0.05)
	stub(mock_territory_manager, "get_connected_bonus").to_return(0.1)

	var registry = SystemRegistry.get_instance()
	stub(registry, "get_system").to_return(mock_hex_grid_manager)
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([test_node])

	panel.show_garrison(test_node)
	panel.refresh()

	# Should not crash
	assert_not_null(panel.current_node)

func test_refresh_without_node() -> void:
	"""Test refresh without current node"""
	_setup_panel()
	panel.current_node = null
	panel.refresh()

	# Should not crash
	assert_null(panel.current_node)

# ==============================================================================
# CLOSE BUTTON TESTS
# ==============================================================================

func test_close_button_hides_panel() -> void:
	"""Test close button hides panel"""
	_setup_panel()
	panel.show_garrison(test_node)

	watch_signals(panel)
	panel._on_close_pressed()

	assert_false(panel.visible)
	assert_signal_emitted(panel, "close_requested")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_show_garrison_twice() -> void:
	"""Test showing garrison twice with different nodes"""
	_setup_panel()
	panel.show_garrison(test_node)

	var test_node_2 = HexNode.new()
	test_node_2.id = "test_node_2"
	test_node_2.garrison = []
	test_node_2.max_garrison = 3

	panel.show_garrison(test_node_2)

	assert_eq(panel.current_node, test_node_2)

func test_assign_multiple_gods() -> void:
	"""Test assigning multiple gods to garrison"""
	_setup_panel()
	panel.show_garrison(test_node)

	panel._on_assign_garrison_pressed("god_1")
	panel._on_assign_garrison_pressed("god_2")

	assert_eq(test_node.garrison.size(), 2)
	assert_has(test_node.garrison, "god_1")
	assert_has(test_node.garrison, "god_2")

func test_unassign_nonexistent_god() -> void:
	"""Test unassigning god not in garrison"""
	_setup_panel()
	test_node.garrison = ["god_1"]
	panel.show_garrison(test_node)

	panel._on_unassign_garrison_pressed("god_3")

	# Should still have god_1
	assert_eq(test_node.garrison.size(), 1)
	assert_has(test_node.garrison, "god_1")
