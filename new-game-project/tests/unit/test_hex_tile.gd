# tests/unit/test_hex_tile.gd
# Unit tests for HexTile UI component
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER METHODS
# ==============================================================================
func _create_test_hex_node() -> HexNode:
	"""Create a test hex node with default values"""
	var node = HexNode.new()
	node.id = "test_node_1"
	node.name = "Test Node"
	node.node_type = "mine"
	node.tier = 2
	node.controller = "neutral"
	node.is_revealed = true
	node.is_contested = false
	node.max_garrison = 3
	node.max_workers = 4
	node.garrison = []
	node.assigned_workers = []

	var coord = HexCoord.new()
	coord.q = 1
	coord.r = 0
	node.coord = coord

	return node

func _create_hex_tile() -> HexTile:
	"""Create a HexTile instance for testing"""
	var script = load("res://scripts/ui/territory/HexTile.gd")
	var tile = script.new()
	return tile

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================
func test_hex_tile_creates_successfully():
	var tile = _create_hex_tile()
	runner.assert_not_null(tile, "HexTile should be created")
	runner.assert_equal(tile.is_locked, false, "Should not be locked by default")
	runner.assert_equal(tile.is_hovered, false, "Should not be hovered by default")

func test_hex_tile_has_correct_minimum_size():
	var tile = _create_hex_tile()
	tile._ready()
	var expected_size = Vector2(80, 92)
	runner.assert_equal(tile.custom_minimum_size, expected_size, "Should have correct minimum size")

func test_hex_tile_mouse_filter_is_stop():
	var tile = _create_hex_tile()
	tile._ready()
	runner.assert_equal(tile.mouse_filter, Control.MOUSE_FILTER_STOP, "Should stop mouse events")

# ==============================================================================
# NODE DATA TESTS
# ==============================================================================
func test_set_node_assigns_node_data():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node, false)

	runner.assert_equal(tile.node_data, node, "Node data should be assigned")
	runner.assert_equal(tile.is_locked, false, "Should not be locked")

func test_set_node_with_locked_flag():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node, true)

	runner.assert_equal(tile.node_data, node, "Node data should be assigned")
	runner.assert_equal(tile.is_locked, true, "Should be locked")

func test_update_state_changes_locked_status():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node, false)

	tile.update_state(true)
	runner.assert_equal(tile.is_locked, true, "Should be locked after update")

	tile.update_state(false)
	runner.assert_equal(tile.is_locked, false, "Should be unlocked after update")

# ==============================================================================
# UTILITY METHOD TESTS
# ==============================================================================
func test_get_node_id_returns_correct_id():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node)

	runner.assert_equal(tile.get_node_id(), "test_node_1", "Should return correct node ID")

func test_get_node_id_with_no_data():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_equal(tile.get_node_id(), "", "Should return empty string with no data")

func test_get_node_coord_returns_correct_coord():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node)

	var coord = tile.get_node_coord()
	runner.assert_not_null(coord, "Should return coord")
	runner.assert_equal(coord.q, 1, "Coord q should match")
	runner.assert_equal(coord.r, 0, "Coord r should match")

func test_get_node_coord_with_no_data():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_null(tile.get_node_coord(), "Should return null with no data")

# ==============================================================================
# STATE DESCRIPTION TESTS
# ==============================================================================
func test_get_node_state_description_neutral():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.controller = "neutral"
	node.is_contested = false
	tile.set_node(node, false)

	runner.assert_equal(tile.get_node_state_description(), "Neutral", "Should be neutral")

func test_get_node_state_description_controlled():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.controller = "player"
	node.is_contested = false
	tile.set_node(node, false)

	runner.assert_equal(tile.get_node_state_description(), "Controlled", "Should be controlled")

func test_get_node_state_description_enemy():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.controller = "enemy_123"
	node.is_contested = false
	tile.set_node(node, false)

	runner.assert_equal(tile.get_node_state_description(), "Enemy", "Should be enemy")

func test_get_node_state_description_contested():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.controller = "player"
	node.is_contested = true
	tile.set_node(node, false)

	runner.assert_equal(tile.get_node_state_description(), "Contested", "Should be contested")

func test_get_node_state_description_locked():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	tile.set_node(node, true)

	runner.assert_equal(tile.get_node_state_description(), "Locked", "Should be locked")

func test_get_node_state_description_no_data():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_equal(tile.get_node_state_description(), "No Data", "Should say no data")

# ==============================================================================
# SIGNAL EMISSION TESTS
# ==============================================================================
func test_hex_tile_has_hex_clicked_signal():
	var tile = _create_hex_tile()
	var has_signal = tile.has_signal("hex_clicked")
	runner.assert_true(has_signal, "Should have hex_clicked signal")

func test_hex_tile_has_hex_hovered_signal():
	var tile = _create_hex_tile()
	var has_signal = tile.has_signal("hex_hovered")
	runner.assert_true(has_signal, "Should have hex_hovered signal")

func test_hex_tile_has_hex_unhovered_signal():
	var tile = _create_hex_tile()
	var has_signal = tile.has_signal("hex_unhovered")
	runner.assert_true(has_signal, "Should have hex_unhovered signal")

# ==============================================================================
# VISUAL STATE TESTS (Component Existence)
# ==============================================================================
func test_visual_components_created_on_ready():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_not_null(tile._background_panel, "Background panel should exist")
	runner.assert_not_null(tile._icon_texture, "Icon texture should exist")
	runner.assert_not_null(tile._tier_label, "Tier label should exist")
	runner.assert_not_null(tile._garrison_indicator, "Garrison indicator should exist")
	runner.assert_not_null(tile._state_overlay, "State overlay should exist")

func test_garrison_indicator_hidden_by_default():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_false(tile._garrison_indicator.visible, "Garrison indicator should be hidden initially")

func test_state_overlay_hidden_by_default():
	var tile = _create_hex_tile()
	tile._ready()

	runner.assert_false(tile._state_overlay.visible, "State overlay should be hidden initially")

# ==============================================================================
# HIGHLIGHT TESTS
# ==============================================================================
func test_highlight_shows_overlay():
	var tile = _create_hex_tile()
	tile._ready()

	tile.highlight(true)
	runner.assert_true(tile._state_overlay.visible, "Overlay should be visible when highlighted")

func test_highlight_hides_overlay():
	var tile = _create_hex_tile()
	tile._ready()

	tile.highlight(true)
	tile.highlight(false)
	runner.assert_false(tile._state_overlay.visible, "Overlay should be hidden when not highlighted")

# ==============================================================================
# TIER COLOR TESTS
# ==============================================================================
func test_tier_colors_defined_for_all_tiers():
	var tile = _create_hex_tile()
	var tier_colors = tile.TIER_COLORS

	runner.assert_true(tier_colors.has(1), "Should have tier 1 color")
	runner.assert_true(tier_colors.has(2), "Should have tier 2 color")
	runner.assert_true(tier_colors.has(3), "Should have tier 3 color")
	runner.assert_true(tier_colors.has(4), "Should have tier 4 color")
	runner.assert_true(tier_colors.has(5), "Should have tier 5 color")

# ==============================================================================
# NODE TYPE ICON TESTS
# ==============================================================================
func test_node_type_icons_defined_for_all_types():
	var tile = _create_hex_tile()
	var icons = tile.NODE_TYPE_ICONS

	runner.assert_true(icons.has("mine"), "Should have mine icon")
	runner.assert_true(icons.has("forest"), "Should have forest icon")
	runner.assert_true(icons.has("coast"), "Should have coast icon")
	runner.assert_true(icons.has("hunting_ground"), "Should have hunting_ground icon")
	runner.assert_true(icons.has("forge"), "Should have forge icon")
	runner.assert_true(icons.has("library"), "Should have library icon")
	runner.assert_true(icons.has("temple"), "Should have temple icon")
	runner.assert_true(icons.has("fortress"), "Should have fortress icon")

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================
func test_set_node_with_null_node():
	var tile = _create_hex_tile()
	tile._ready()

	tile.set_node(null)
	runner.assert_null(tile.node_data, "Node data should be null")

func test_update_visuals_with_no_node_data():
	var tile = _create_hex_tile()
	tile._ready()

	# Should not crash
	tile._update_visuals()
	runner.assert_true(true, "Should not crash with no node data")

func test_multiple_node_assignments():
	var tile = _create_hex_tile()
	tile._ready()

	var node1 = _create_test_hex_node()
	node1.id = "node_1"

	var node2 = _create_test_hex_node()
	node2.id = "node_2"

	tile.set_node(node1)
	runner.assert_equal(tile.get_node_id(), "node_1", "Should have first node ID")

	tile.set_node(node2)
	runner.assert_equal(tile.get_node_id(), "node_2", "Should have second node ID")

# ==============================================================================
# GARRISON INDICATOR TESTS
# ==============================================================================
func test_garrison_indicator_shown_when_garrison_present():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.garrison = ["god_1", "god_2"]
	tile.set_node(node)

	runner.assert_true(tile._garrison_indicator.visible, "Garrison indicator should be visible")

func test_garrison_indicator_hidden_when_no_garrison():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.garrison = []
	tile.set_node(node)

	runner.assert_false(tile._garrison_indicator.visible, "Garrison indicator should be hidden")

# ==============================================================================
# TIER STARS TESTS
# ==============================================================================
func test_tier_stars_correct_for_tier_1():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.tier = 1
	tile.set_node(node)

	runner.assert_equal(tile._tier_label.text, "★", "Should show 1 star for tier 1")

func test_tier_stars_correct_for_tier_5():
	var tile = _create_hex_tile()
	tile._ready()

	var node = _create_test_hex_node()
	node.tier = 5
	tile.set_node(node)

	runner.assert_equal(tile._tier_label.text, "★★★★★", "Should show 5 stars for tier 5")
