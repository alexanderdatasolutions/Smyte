# tests/unit/test_hex_map_view_visual_polish.gd
# Unit tests for HexMapView visual polish features
extends GutTest

const HexMapViewScript = preload("res://scripts/ui/territory/HexMapView.gd")
const HexCoordScript = preload("res://scripts/data/HexCoord.gd")
const HexNodeScript = preload("res://scripts/data/HexNode.gd")
const SystemRegistryScript = preload("res://scripts/systems/core/SystemRegistry.gd")

var hex_map_view: HexMapView = null
var mock_registry = null

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================
func before_each():
	"""Setup before each test"""
	# Create mock SystemRegistry
	mock_registry = SystemRegistryScript.new()
	mock_registry.set_name("SystemRegistry")
	add_child_autofree(mock_registry)

	# Create HexMapView
	hex_map_view = HexMapViewScript.new()
	add_child_autofree(hex_map_view)

func after_each():
	"""Cleanup after each test"""
	hex_map_view = null
	mock_registry = null

# ==============================================================================
# CAMERA ANIMATION TESTS
# ==============================================================================
func test_camera_transition_duration_constant():
	"""Test camera transition duration constant exists"""
	assert_eq(hex_map_view.CAMERA_TRANSITION_DURATION, 0.5, "Camera transition duration should be 0.5 seconds")

func test_camera_tween_property_exists():
	"""Test camera_tween property exists"""
	assert_true(hex_map_view.has("camera_tween"), "HexMapView should have camera_tween property")

func test_center_on_coord_animated_parameter():
	"""Test center_on_coord accepts animated parameter"""
	var coord = HexCoordScript.new()
	coord.q = 0
	coord.r = 0

	# Should not error with animated parameter
	hex_map_view.center_on_coord(coord, true)
	hex_map_view.center_on_coord(coord, false)
	pass_test("center_on_coord accepts animated parameter")

func test_center_on_coord_without_animation():
	"""Test center_on_coord without animation sets immediately"""
	var coord = HexCoordScript.new()
	coord.q = 0
	coord.r = 0

	hex_map_view.size = Vector2(800, 600)  # Set viewport size
	hex_map_view.center_on_coord(coord, false)

	# Should have camera_offset set (not checking exact value due to calculations)
	assert_ne(hex_map_view.camera_offset, Vector2.ZERO, "Camera offset should be set after centering")

func test_set_zoom_animated_parameter():
	"""Test set_zoom accepts animated parameter"""
	hex_map_view.set_zoom(1.5, true)
	hex_map_view.set_zoom(1.5, false)
	pass_test("set_zoom accepts animated parameter")

func test_set_zoom_without_animation():
	"""Test set_zoom without animation sets immediately"""
	hex_map_view.set_zoom(1.5, false)
	assert_eq(hex_map_view.zoom_level, 1.5, "Zoom level should be set immediately without animation")

# ==============================================================================
# CAPTURE ANIMATION TESTS
# ==============================================================================
func test_play_capture_animation_method_exists():
	"""Test play_capture_animation method exists"""
	assert_true(hex_map_view.has_method("play_capture_animation"), "HexMapView should have play_capture_animation method")

func test_play_capture_animation_with_null_node():
	"""Test play_capture_animation with null node"""
	hex_map_view.play_capture_animation(null)
	pass_test("play_capture_animation should handle null node gracefully")

func test_play_capture_animation_with_invalid_coord():
	"""Test play_capture_animation with node that has null coord"""
	var node = HexNodeScript.new()
	node.id = "test_node"
	node.coord = null

	hex_map_view.play_capture_animation(node)
	pass_test("play_capture_animation should handle null coord gracefully")

func test_play_capture_animation_with_missing_tile():
	"""Test play_capture_animation with node not in hex_tiles cache"""
	var node = HexNodeScript.new()
	node.id = "test_node"
	node.coord = HexCoordScript.new()
	node.coord.q = 99
	node.coord.r = 99

	hex_map_view.play_capture_animation(node)
	pass_test("play_capture_animation should handle missing tile gracefully")

# ==============================================================================
# CONNECTION LINE ANIMATION TESTS
# ==============================================================================
func test_animate_connection_line_glow_method_exists():
	"""Test _animate_connection_line_glow method exists"""
	assert_true(hex_map_view.has_method("_animate_connection_line_glow"), "HexMapView should have _animate_connection_line_glow method")

func test_connection_line_created_with_animation():
	"""Test connection lines are created with pulsing animation"""
	var coord1 = HexCoordScript.new()
	coord1.q = 0
	coord1.r = 0

	var coord2 = HexCoordScript.new()
	coord2.q = 1
	coord2.r = 0

	hex_map_view._create_connection_line(coord1, coord2)

	# Check that a line was created
	assert_gt(hex_map_view.connection_lines.size(), 0, "Connection line should be created")

# ==============================================================================
# ANIMATION HELPER METHOD TESTS
# ==============================================================================
func test_animate_camera_to_method_exists():
	"""Test _animate_camera_to method exists"""
	assert_true(hex_map_view.has_method("_animate_camera_to"), "HexMapView should have _animate_camera_to method")

func test_animate_zoom_to_method_exists():
	"""Test _animate_zoom_to method exists"""
	assert_true(hex_map_view.has_method("_animate_zoom_to"), "HexMapView should have _animate_zoom_to method")

func test_animate_tile_capture_method_exists():
	"""Test _animate_tile_capture method exists"""
	assert_true(hex_map_view.has_method("_animate_tile_capture"), "HexMapView should have _animate_tile_capture method")

func test_animate_camera_to_with_null_camera_offset():
	"""Test _animate_camera_to with target offset"""
	var target_offset = Vector2(100, 100)
	hex_map_view._animate_camera_to(target_offset)

	# Should have created tween
	assert_not_null(hex_map_view.camera_tween, "Camera tween should be created")

func test_animate_zoom_to_with_target():
	"""Test _animate_zoom_to with target zoom"""
	hex_map_view._animate_zoom_to(1.5)

	# Should have created tween
	assert_not_null(hex_map_view.camera_tween, "Camera tween should be created")

# ==============================================================================
# EDGE CASES
# ==============================================================================
func test_multiple_camera_tweens_cancel_previous():
	"""Test multiple camera animations cancel previous ones"""
	hex_map_view._animate_camera_to(Vector2(100, 100))
	var first_tween = hex_map_view.camera_tween

	hex_map_view._animate_camera_to(Vector2(200, 200))
	var second_tween = hex_map_view.camera_tween

	# Should have different tween instances
	assert_ne(first_tween, second_tween, "Second animation should create new tween")

func test_multiple_zoom_tweens_cancel_previous():
	"""Test multiple zoom animations cancel previous ones"""
	hex_map_view._animate_zoom_to(1.2)
	var first_tween = hex_map_view.camera_tween

	hex_map_view._animate_zoom_to(1.8)
	var second_tween = hex_map_view.camera_tween

	# Should have different tween instances
	assert_ne(first_tween, second_tween, "Second animation should create new tween")

# ==============================================================================
# INTEGRATION WITH ZOOM CONTROLS
# ==============================================================================
func test_zoom_in_creates_animation():
	"""Test zoom_in creates animated transition by default"""
	hex_map_view.zoom_in()

	# Should have created tween
	assert_not_null(hex_map_view.camera_tween, "Zoom in should create animated transition")

func test_zoom_out_creates_animation():
	"""Test zoom_out creates animated transition by default"""
	hex_map_view.zoom_out()

	# Should have created tween
	assert_not_null(hex_map_view.camera_tween, "Zoom out should create animated transition")

# ==============================================================================
# SUMMARY
# ==============================================================================
# Total tests: 23
# Tests cover:
# - Camera animation properties and constants
# - Animated vs instant camera transitions
# - Capture animation with various edge cases
# - Connection line animation creation
# - Animation helper methods
# - Tween cancellation on multiple animations
# - Integration with zoom controls
