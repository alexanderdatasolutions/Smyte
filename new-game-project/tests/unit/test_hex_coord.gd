# tests/unit/test_hex_coord.gd - Unit tests for HexCoord data class
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_coord(coord_q: int, coord_r: int) -> HexCoord:
	"""Helper to create a HexCoord"""
	var script = load("res://scripts/data/HexCoord.gd")
	return script.new(coord_q, coord_r)

# ==============================================================================
# TEST: Basic Creation
# ==============================================================================

func test_hex_coord_creation_with_init():
	var coord = create_coord(5, 3)

	runner.assert_equal(coord.q, 5, "q coordinate should be 5")
	runner.assert_equal(coord.r, 3, "r coordinate should be 3")

func test_hex_coord_default_values():
	var coord = create_coord(0, 0)

	runner.assert_equal(coord.q, 0, "default q should be 0")
	runner.assert_equal(coord.r, 0, "default r should be 0")

func test_hex_coord_from_qr():
	var coord = HexCoord.from_qr(7, -2)

	runner.assert_equal(coord.q, 7, "q should be 7")
	runner.assert_equal(coord.r, -2, "r should be -2")

# ==============================================================================
# TEST: Distance Calculations
# ==============================================================================

func test_distance_to_same_coordinate():
	var coord1 = create_coord(3, 2)
	var coord2 = create_coord(3, 2)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 0, "distance to same coordinate should be 0")

func test_distance_to_adjacent_coordinate():
	var origin = create_coord(0, 0)
	var adjacent = create_coord(1, 0)

	var distance = origin.distance_to(adjacent)
	runner.assert_equal(distance, 1, "distance to adjacent hex should be 1")

func test_distance_horizontal():
	var coord1 = create_coord(0, 0)
	var coord2 = create_coord(3, 0)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 3, "horizontal distance should be 3")

func test_distance_vertical():
	var coord1 = create_coord(0, 0)
	var coord2 = create_coord(0, 4)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 4, "vertical distance should be 4")

func test_distance_diagonal():
	var coord1 = create_coord(0, 0)
	var coord2 = create_coord(2, -2)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 2, "diagonal distance should be 2")

func test_distance_complex_path():
	var coord1 = create_coord(1, 2)
	var coord2 = create_coord(4, -1)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 3, "complex path distance should be 3")

func test_distance_negative_coordinates():
	var coord1 = create_coord(-2, -3)
	var coord2 = create_coord(-5, -1)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 3, "distance with negative coords should work")

func test_distance_to_null():
	var coord = create_coord(5, 5)

	var distance = coord.distance_to(null)
	runner.assert_equal(distance, 0, "distance to null should be 0")

func test_distance_symmetry():
	var coord1 = create_coord(2, 3)
	var coord2 = create_coord(5, 1)

	var dist1 = coord1.distance_to(coord2)
	var dist2 = coord2.distance_to(coord1)
	runner.assert_equal(dist1, dist2, "distance should be symmetric")

# ==============================================================================
# TEST: Neighbor Finding
# ==============================================================================

func test_get_neighbors_count():
	var origin = create_coord(0, 0)
	var neighbors = origin.get_neighbors()

	runner.assert_equal(neighbors.size(), 6, "should have exactly 6 neighbors")

func test_get_neighbors_all_distance_one():
	var origin = create_coord(0, 0)
	var neighbors = origin.get_neighbors()

	for neighbor in neighbors:
		var distance = origin.distance_to(neighbor)
		runner.assert_equal(distance, 1, "all neighbors should be distance 1")

func test_get_neighbors_coordinates():
	var origin = create_coord(0, 0)
	var neighbors = origin.get_neighbors()

	# Expected neighbors in axial coordinates
	var expected = [
		[1, 0],   # East
		[-1, 0],  # West
		[0, 1],   # Southeast
		[0, -1],  # Northwest
		[1, -1],  # Northeast
		[-1, 1]   # Southwest
	]

	runner.assert_equal(neighbors.size(), expected.size(), "should have all expected neighbors")

func test_get_neighbors_offset_coordinate():
	var coord = create_coord(3, 2)
	var neighbors = coord.get_neighbors()

	runner.assert_equal(neighbors.size(), 6, "offset coord should also have 6 neighbors")

	# Verify all neighbors are adjacent
	for neighbor in neighbors:
		var distance = coord.distance_to(neighbor)
		runner.assert_equal(distance, 1, "all neighbors should be adjacent")

# ==============================================================================
# TEST: Equality
# ==============================================================================

func test_equals_same_coordinates():
	var coord1 = create_coord(5, 3)
	var coord2 = create_coord(5, 3)

	runner.assert_true(coord1.equals(coord2), "coordinates with same q,r should be equal")

func test_equals_different_coordinates():
	var coord1 = create_coord(5, 3)
	var coord2 = create_coord(5, 4)

	runner.assert_false(coord1.equals(coord2), "coordinates with different values should not be equal")

func test_equals_null():
	var coord = create_coord(5, 3)

	runner.assert_false(coord.equals(null), "coordinate should not equal null")

func test_equals_negative_coords():
	var coord1 = create_coord(-2, -3)
	var coord2 = create_coord(-2, -3)

	runner.assert_true(coord1.equals(coord2), "negative coordinates should work with equals")

# ==============================================================================
# TEST: String Representation
# ==============================================================================

func test_to_string_format():
	var coord = create_coord(5, 3)
	var string_rep = coord.as_string()

	runner.assert_true(string_rep.contains("5"), "string should contain q value")
	runner.assert_true(string_rep.contains("3"), "string should contain r value")

func test_to_string_negative():
	var coord = create_coord(-2, -4)
	var string_rep = coord.as_string()

	runner.assert_true(string_rep.contains("-2"), "string should contain negative q")
	runner.assert_true(string_rep.contains("-4"), "string should contain negative r")

# ==============================================================================
# TEST: Serialization
# ==============================================================================

func test_to_dict():
	var coord = create_coord(7, -3)
	var dict_data = coord.to_dict()

	runner.assert_equal(dict_data["q"], 7, "dict should contain q")
	runner.assert_equal(dict_data["r"], -3, "dict should contain r")

func test_from_dict():
	var data = {"q": 9, "r": -5}
	var coord = HexCoord.from_dict(data)

	runner.assert_equal(coord.q, 9, "q should be loaded from dict")
	runner.assert_equal(coord.r, -5, "r should be loaded from dict")

func test_from_dict_missing_values():
	var data = {}
	var coord = HexCoord.from_dict(data)

	runner.assert_equal(coord.q, 0, "missing q should default to 0")
	runner.assert_equal(coord.r, 0, "missing r should default to 0")

func test_serialization_round_trip():
	var original = create_coord(13, -7)
	var dict_data = original.to_dict()
	var restored = HexCoord.from_dict(dict_data)

	runner.assert_true(original.equals(restored), "round trip serialization should preserve coordinate")

# ==============================================================================
# TEST: Ring Calculation
# ==============================================================================

func test_get_ring_origin():
	var origin = create_coord(0, 0)
	var ring = origin.get_ring(0)

	runner.assert_equal(ring, 0, "origin should be in ring 0")

func test_get_ring_adjacent():
	var coord = create_coord(1, 0)
	var ring = coord.get_ring(0)

	runner.assert_equal(ring, 1, "adjacent hex should be in ring 1")

func test_get_ring_distance():
	var coord = create_coord(3, 0)
	var ring = coord.get_ring(0)

	runner.assert_equal(ring, 3, "coordinate at distance 3 should be in ring 3")

func test_is_origin_true():
	var origin = create_coord(0, 0)

	runner.assert_true(origin.is_origin(), "0,0 should be origin")

func test_is_origin_false():
	var coord = create_coord(1, 0)

	runner.assert_false(coord.is_origin(), "non-zero coordinate should not be origin")

# ==============================================================================
# TEST: Cube Coordinate Conversion
# ==============================================================================

func test_to_cube_origin():
	var origin = create_coord(0, 0)
	var cube = origin.to_cube()

	runner.assert_equal(cube["x"], 0, "origin cube x should be 0")
	runner.assert_equal(cube["y"], 0, "origin cube y should be 0")
	runner.assert_equal(cube["z"], 0, "origin cube z should be 0")

func test_to_cube_conversion():
	var coord = create_coord(2, 3)
	var cube = coord.to_cube()

	runner.assert_equal(cube["x"], 2, "cube x should equal q")
	runner.assert_equal(cube["z"], 3, "cube z should equal r")
	runner.assert_equal(cube["x"] + cube["y"] + cube["z"], 0, "cube coords should sum to 0")

func test_from_cube():
	var coord = HexCoord.from_cube(4, -7, 3)

	runner.assert_equal(coord.q, 4, "q should come from cube x")
	runner.assert_equal(coord.r, 3, "r should come from cube z")

func test_cube_round_trip():
	var original = create_coord(5, -2)
	var cube = original.to_cube()
	var restored = HexCoord.from_cube(cube["x"], cube["y"], cube["z"])

	runner.assert_true(original.equals(restored), "cube round trip should preserve coordinate")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_large_coordinates():
	var coord1 = create_coord(100, -50)
	var coord2 = create_coord(-30, 80)

	var distance = coord1.distance_to(coord2)
	runner.assert_true(distance > 0, "should handle large coordinate distances")

func test_zero_coordinate_operations():
	var zero = create_coord(0, 0)
	var neighbors = zero.get_neighbors()

	runner.assert_equal(neighbors.size(), 6, "zero coordinate should have neighbors")

func test_coordinate_with_same_q_different_r():
	var coord1 = create_coord(5, 2)
	var coord2 = create_coord(5, 8)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 6, "distance along same q should work")

func test_coordinate_with_same_r_different_q():
	var coord1 = create_coord(2, 5)
	var coord2 = create_coord(8, 5)

	var distance = coord1.distance_to(coord2)
	runner.assert_equal(distance, 6, "distance along same r should work")
