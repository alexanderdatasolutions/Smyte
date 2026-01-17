# tests/unit/test_hex_map_view.gd
# Unit tests for HexMapView UI component
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_hex_map_view_initialization():
	"""Test HexMapView initializes properly"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_not_null(map_view, "HexMapView should be created")
	runner.assert_equal(map_view.zoom_level, 1.0, "Initial zoom should be 1.0")
	runner.assert_equal(map_view.camera_offset, Vector2.ZERO, "Initial camera offset should be zero")
	runner.assert_false(map_view.is_panning, "Should not be panning initially")
	runner.assert_null(map_view.selected_node, "No node should be selected initially")

	map_view.free()

func test_hex_map_view_has_required_signals():
	"""Test HexMapView has all required signals"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_true(map_view.has_signal("hex_selected"), "Should have hex_selected signal")
	runner.assert_true(map_view.has_signal("hex_hovered"), "Should have hex_hovered signal")
	runner.assert_true(map_view.has_signal("view_changed"), "Should have view_changed signal")

	map_view.free()

func test_hex_map_view_constants():
	"""Test HexMapView has correct constants"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_equal(map_view.HEX_WIDTH, 80.0, "HEX_WIDTH should be 80.0")
	runner.assert_equal(map_view.HEX_HEIGHT, 92.0, "HEX_HEIGHT should be 92.0")
	runner.assert_equal(map_view.MIN_ZOOM, 0.5, "MIN_ZOOM should be 0.5")
	runner.assert_equal(map_view.MAX_ZOOM, 2.0, "MAX_ZOOM should be 2.0")
	runner.assert_equal(map_view.ZOOM_STEP, 0.1, "ZOOM_STEP should be 0.1")

	map_view.free()

# ==============================================================================
# ZOOM TESTS
# ==============================================================================

func test_zoom_in():
	"""Test zooming in"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var initial_zoom = map_view.zoom_level
	map_view.zoom_in()
	runner.assert_equal(map_view.zoom_level, initial_zoom + 0.1, "Zoom should increase by ZOOM_STEP")

	map_view.free()

func test_zoom_out():
	"""Test zooming out"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var initial_zoom = map_view.zoom_level
	map_view.zoom_out()
	runner.assert_equal(map_view.zoom_level, initial_zoom - 0.1, "Zoom should decrease by ZOOM_STEP")

	map_view.free()

func test_zoom_limits():
	"""Test zoom is clamped to min/max"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	# Test max zoom
	map_view.set_zoom(5.0)
	runner.assert_equal(map_view.zoom_level, 2.0, "Zoom should be clamped to MAX_ZOOM")

	# Test min zoom
	map_view.set_zoom(0.1)
	runner.assert_equal(map_view.zoom_level, 0.5, "Zoom should be clamped to MIN_ZOOM")

	map_view.free()

func test_get_zoom():
	"""Test get_zoom returns current zoom level"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	map_view.set_zoom(1.5)
	runner.assert_equal(map_view.get_zoom(), 1.5, "get_zoom should return current zoom level")

	map_view.free()

# ==============================================================================
# CAMERA TESTS
# ==============================================================================

func test_get_camera_offset():
	"""Test get_camera_offset returns current offset"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	map_view.camera_offset = Vector2(100, 200)
	runner.assert_equal(map_view.get_camera_offset(), Vector2(100, 200), "Should return current camera offset")

	map_view.free()

func test_panning_state():
	"""Test panning state management"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_false(map_view.is_panning, "Should not be panning initially")

	map_view.is_panning = true
	runner.assert_true(map_view.is_panning, "Should be panning when set")

	map_view.free()

# ==============================================================================
# NODE SELECTION TESTS
# ==============================================================================

func test_select_node():
	"""Test node selection"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var hex_node_script = load("res://scripts/data/HexNode.gd")
	var coord_script = load("res://scripts/data/HexCoord.gd")

	var coord = coord_script.new(1, 0)
	var node = hex_node_script.new()
	node.id = "test_node"
	node.coord = coord

	map_view.select_node(node)
	runner.assert_equal(map_view.selected_node, node, "Should select the node")
	runner.assert_equal(map_view.selected_node.id, "test_node", "Selected node should have correct ID")

	node.free()
	coord.free()
	map_view.free()

func test_select_null_node():
	"""Test selecting null node"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	# Select null
	map_view.select_node(null)
	runner.assert_null(map_view.selected_node, "Should handle null selection")

	map_view.free()

func test_deselect_previous_node():
	"""Test deselecting previous node when selecting new one"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var hex_node_script = load("res://scripts/data/HexNode.gd")
	var coord_script = load("res://scripts/data/HexCoord.gd")

	# Select first node
	var coord1 = coord_script.new(1, 0)
	var node1 = hex_node_script.new()
	node1.id = "node1"
	node1.coord = coord1

	map_view.select_node(node1)
	runner.assert_equal(map_view.selected_node.id, "node1", "First node should be selected")

	# Select second node
	var coord2 = coord_script.new(2, 0)
	var node2 = hex_node_script.new()
	node2.id = "node2"
	node2.coord = coord2

	map_view.select_node(node2)
	runner.assert_equal(map_view.selected_node.id, "node2", "Second node should be selected")
	runner.assert_not_equal(map_view.selected_node, node1, "First node should be deselected")

	node1.free()
	node2.free()
	coord1.free()
	coord2.free()
	map_view.free()

# ==============================================================================
# COORDINATE CONVERSION TESTS
# ==============================================================================

func test_coord_to_screen_position_origin():
	"""Test converting origin coordinate to screen position"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(0, 0)

	var pos = map_view._coord_to_screen_position(coord)
	runner.assert_equal(pos, Vector2.ZERO, "Origin should map to (0, 0)")

	coord.free()
	map_view.free()

func test_coord_to_screen_position_positive():
	"""Test converting positive coordinates to screen position"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(2, 1)

	var pos = map_view._coord_to_screen_position(coord)
	var expected_x = 2 * map_view.HEX_HORIZONTAL_SPACING
	var expected_y = 1 * map_view.HEX_VERTICAL_SPACING + map_view.HEX_VERTICAL_OFFSET  # Odd column offset

	runner.assert_equal(pos.x, expected_x, "X position should be correct")
	runner.assert_equal(pos.y, expected_y, "Y position should be correct with odd column offset")

	coord.free()
	map_view.free()

func test_coord_to_screen_position_negative():
	"""Test converting negative coordinates to screen position"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(-2, -1)

	var pos = map_view._coord_to_screen_position(coord)
	var expected_x = -2 * map_view.HEX_HORIZONTAL_SPACING
	var expected_y = -1 * map_view.HEX_VERTICAL_SPACING  # Even column, no offset

	runner.assert_equal(pos.x, expected_x, "X position should handle negative q")
	runner.assert_equal(pos.y, expected_y, "Y position should handle negative r")

	coord.free()
	map_view.free()

func test_coord_to_screen_position_null():
	"""Test converting null coordinate"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var pos = map_view._coord_to_screen_position(null)
	runner.assert_equal(pos, Vector2.ZERO, "Null coord should return Vector2.ZERO")

	map_view.free()

func test_coord_to_key():
	"""Test coordinate to cache key conversion"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(3, -2)

	var key = map_view._coord_to_key(coord)
	runner.assert_equal(key, "3,-2", "Key should be formatted as q,r")

	coord.free()
	map_view.free()

func test_coord_to_key_null():
	"""Test null coordinate to key conversion"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var key = map_view._coord_to_key(null)
	runner.assert_equal(key, "", "Null coord should return empty string")

	map_view.free()

# ==============================================================================
# CENTER CAMERA TESTS
# ==============================================================================

func test_center_on_coord():
	"""Test centering camera on a coordinate"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()
	map_view.size = Vector2(800, 600)

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(1, 1)

	map_view.center_on_coord(coord)
	# After centering, camera_offset should be set
	runner.assert_not_equal(map_view.camera_offset, Vector2.ZERO, "Camera offset should be updated")

	coord.free()
	map_view.free()

func test_center_on_null_coord():
	"""Test centering on null coordinate"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var initial_offset = map_view.camera_offset
	map_view.center_on_coord(null)
	runner.assert_equal(map_view.camera_offset, initial_offset, "Camera should not move for null coord")

	map_view.free()

# ==============================================================================
# TILE CACHE TESTS
# ==============================================================================

func test_tile_cache_initialization():
	"""Test tile cache is initialized empty"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_equal(map_view.hex_tiles.size(), 0, "Tile cache should start empty")

	map_view.free()

func test_connection_lines_initialization():
	"""Test connection lines array is initialized empty"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	runner.assert_equal(map_view.connection_lines.size(), 0, "Connection lines should start empty")

	map_view.free()

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_multiple_zoom_operations():
	"""Test multiple zoom operations in sequence"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	map_view.zoom_in()
	map_view.zoom_in()
	map_view.zoom_out()

	runner.assert_equal(map_view.zoom_level, 1.1, "Zoom should be correct after multiple operations")

	map_view.free()

func test_zoom_at_limits():
	"""Test zoom operations at limits"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	# Zoom to max
	map_view.set_zoom(2.0)
	map_view.zoom_in()
	runner.assert_equal(map_view.zoom_level, 2.0, "Should stay at max zoom")

	# Zoom to min
	map_view.set_zoom(0.5)
	map_view.zoom_out()
	runner.assert_equal(map_view.zoom_level, 0.5, "Should stay at min zoom")

	map_view.free()

func test_select_same_node_twice():
	"""Test selecting the same node twice"""
	var script = load("res://scripts/ui/territory/HexMapView.gd")
	var map_view = script.new()

	var hex_node_script = load("res://scripts/data/HexNode.gd")
	var coord_script = load("res://scripts/data/HexCoord.gd")

	var coord = coord_script.new(1, 0)
	var node = hex_node_script.new()
	node.id = "test_node"
	node.coord = coord

	map_view.select_node(node)
	map_view.select_node(node)

	runner.assert_equal(map_view.selected_node, node, "Should still be selected")

	node.free()
	coord.free()
	map_view.free()
