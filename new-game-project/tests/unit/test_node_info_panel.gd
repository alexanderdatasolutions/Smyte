# tests/unit/test_node_info_panel.gd
extends GutTest

"""
Unit tests for NodeInfoPanel UI component
Tests display, signals, and interaction handling
"""

var panel: NodeInfoPanel
var mock_hex_node: HexNode
var mock_collection_manager
var mock_territory_manager
var mock_production_manager
var mock_node_requirement_checker

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================

func before_each():
	"""Setup before each test"""
	panel = NodeInfoPanel.new()
	_setup_mock_systems()
	_setup_mock_node()

func after_each():
	"""Cleanup after each test"""
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	mock_hex_node = null

func _setup_mock_systems():
	"""Setup mock system managers"""
	# Note: In real tests, would inject mocks via SystemRegistry
	# For unit tests, we'll verify initialization
	pass

func _setup_mock_node():
	"""Setup a mock hex node"""
	mock_hex_node = HexNode.new()
	mock_hex_node.id = "test_node_1"
	mock_hex_node.name = "Test Mine"
	mock_hex_node.node_type = "mine"
	mock_hex_node.tier = 2
	mock_hex_node.controller = "player"
	mock_hex_node.max_garrison = 3
	mock_hex_node.max_workers = 4
	mock_hex_node.garrison = []
	mock_hex_node.assigned_workers = []
	mock_hex_node.base_production = {"iron_ore": 50, "copper_ore": 30}

	# Create coordinate
	var script = load("res://scripts/data/HexCoord.gd")
	var coord = script.new()
	coord.q = 1
	coord.r = 0
	mock_hex_node.coord = coord

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_initialization():
	"""Test panel initializes correctly"""
	assert_not_null(panel, "Panel should be created")
	assert_false(panel.visible, "Panel should start hidden")
	assert_null(panel.current_node, "Should have no current node")
	assert_false(panel.is_locked, "Should not be locked initially")

func test_has_required_signals():
	"""Test panel has required signals"""
	assert_has_signal(panel, "capture_requested")
	assert_has_signal(panel, "manage_workers_requested")
	assert_has_signal(panel, "manage_garrison_requested")
	assert_has_signal(panel, "close_requested")

func test_constants_defined():
	"""Test constants are defined"""
	assert_eq(panel.PANEL_WIDTH, 350)
	assert_eq(panel.PANEL_HEIGHT, 500)
	assert_eq(panel.BUTTON_HEIGHT, 40)

# ==============================================================================
# SHOW/HIDE TESTS
# ==============================================================================

func test_show_node():
	"""Test showing node info"""
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(panel.current_node, mock_hex_node, "Should store node reference")
	assert_false(panel.is_locked, "Should not be locked")

func test_show_locked_node():
	"""Test showing locked node"""
	panel.show_node(mock_hex_node, true)

	assert_true(panel.visible, "Panel should be visible")
	assert_true(panel.is_locked, "Should be locked")

func test_show_null_node():
	"""Test showing null node hides panel"""
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible initially")

	panel.show_node(null, false)
	assert_false(panel.visible, "Panel should be hidden")
	assert_null(panel.current_node, "Should clear node reference")

func test_hide_panel():
	"""Test hiding panel"""
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

	panel.hide_panel()
	assert_false(panel.visible, "Panel should be hidden")
	assert_null(panel.current_node, "Should clear node reference")

func test_refresh():
	"""Test refreshing panel display"""
	panel.show_node(mock_hex_node, false)

	# Modify node
	mock_hex_node.name = "Updated Mine"

	panel.refresh()
	assert_eq(panel.current_node, mock_hex_node, "Should still have node reference")

# ==============================================================================
# NODE STATE TESTS
# ==============================================================================

func test_show_player_controlled_node():
	"""Test showing player-controlled node"""
	mock_hex_node.controller = "player"
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_false(panel.is_locked, "Player node should not be locked")

func test_show_neutral_node():
	"""Test showing neutral node"""
	mock_hex_node.controller = "neutral"
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

func test_show_enemy_node():
	"""Test showing enemy-controlled node"""
	mock_hex_node.controller = "enemy_player_123"
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

func test_show_contested_node():
	"""Test showing contested node"""
	mock_hex_node.is_contested = true
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

# ==============================================================================
# TIER TESTS
# ==============================================================================

func test_show_tier_1_node():
	"""Test showing tier 1 node"""
	mock_hex_node.tier = 1
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

func test_show_tier_5_node():
	"""Test showing tier 5 legendary node"""
	mock_hex_node.tier = 5
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

# ==============================================================================
# GARRISON TESTS
# ==============================================================================

func test_show_node_with_garrison():
	"""Test showing node with garrison"""
	mock_hex_node.garrison = ["god_1", "god_2"]
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_garrison_count(), 2, "Should have 2 garrison")

func test_show_node_empty_garrison():
	"""Test showing node with empty garrison"""
	mock_hex_node.garrison = []
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_garrison_count(), 0, "Should have 0 garrison")

func test_show_node_full_garrison():
	"""Test showing node with full garrison"""
	mock_hex_node.max_garrison = 3
	mock_hex_node.garrison = ["god_1", "god_2", "god_3"]
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_garrison_count(), 3, "Should have full garrison")

# ==============================================================================
# WORKERS TESTS
# ==============================================================================

func test_show_node_with_workers():
	"""Test showing node with workers"""
	mock_hex_node.assigned_workers = ["god_3", "god_4"]
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_worker_count(), 2, "Should have 2 workers")

func test_show_node_empty_workers():
	"""Test showing node with no workers"""
	mock_hex_node.assigned_workers = []
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_worker_count(), 0, "Should have 0 workers")

func test_show_node_full_workers():
	"""Test showing node with full workers"""
	mock_hex_node.max_workers = 4
	mock_hex_node.assigned_workers = ["god_1", "god_2", "god_3", "god_4"]
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.get_worker_count(), 4, "Should have full workers")

# ==============================================================================
# PRODUCTION TESTS
# ==============================================================================

func test_show_node_with_production():
	"""Test showing node with production"""
	mock_hex_node.base_production = {"iron_ore": 50, "stone": 30}
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_false(mock_hex_node.base_production.is_empty(), "Should have production")

func test_show_node_no_production():
	"""Test showing node with no production"""
	mock_hex_node.base_production = {}
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")

func test_show_node_multiple_resources():
	"""Test showing node producing multiple resources"""
	mock_hex_node.base_production = {
		"iron_ore": 50,
		"copper_ore": 30,
		"stone": 20,
		"gems": 10
	}
	panel.show_node(mock_hex_node, false)

	assert_true(panel.visible, "Panel should be visible")
	assert_eq(mock_hex_node.base_production.size(), 4, "Should have 4 resources")

# ==============================================================================
# NODE TYPE TESTS
# ==============================================================================

func test_show_mine_node():
	"""Test showing mine node"""
	mock_hex_node.node_type = "mine"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_forest_node():
	"""Test showing forest node"""
	mock_hex_node.node_type = "forest"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_coast_node():
	"""Test showing coast node"""
	mock_hex_node.node_type = "coast"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_hunting_ground_node():
	"""Test showing hunting ground node"""
	mock_hex_node.node_type = "hunting_ground"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_forge_node():
	"""Test showing forge node"""
	mock_hex_node.node_type = "forge"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_library_node():
	"""Test showing library node"""
	mock_hex_node.node_type = "library"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_temple_node():
	"""Test showing temple node"""
	mock_hex_node.node_type = "temple"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

func test_show_fortress_node():
	"""Test showing fortress node"""
	mock_hex_node.node_type = "fortress"
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_show_node_twice():
	"""Test showing same node twice"""
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should still be visible")
	assert_eq(panel.current_node, mock_hex_node, "Should still have same node")

func test_show_different_nodes():
	"""Test switching between nodes"""
	panel.show_node(mock_hex_node, false)
	assert_eq(panel.current_node, mock_hex_node, "Should have first node")

	var node2 = HexNode.new()
	node2.id = "test_node_2"
	node2.name = "Test Forest"
	node2.node_type = "forest"
	node2.tier = 1

	panel.show_node(node2, false)
	assert_eq(panel.current_node, node2, "Should have second node")

func test_show_locked_then_unlocked():
	"""Test changing lock state"""
	panel.show_node(mock_hex_node, true)
	assert_true(panel.is_locked, "Should be locked")

	panel.show_node(mock_hex_node, false)
	assert_false(panel.is_locked, "Should be unlocked")

func test_refresh_with_no_node():
	"""Test refreshing with no node"""
	panel.refresh()
	# Should not crash
	assert_null(panel.current_node, "Should have no node")

func test_hide_then_show():
	"""Test hiding then showing"""
	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible")

	panel.hide_panel()
	assert_false(panel.visible, "Panel should be hidden")

	panel.show_node(mock_hex_node, false)
	assert_true(panel.visible, "Panel should be visible again")
