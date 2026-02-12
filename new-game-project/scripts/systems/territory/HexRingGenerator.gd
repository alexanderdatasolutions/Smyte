# scripts/systems/territory/HexRingGenerator.gd
# Programmatic hex ring generation - creates proper concentric hex rings
extends RefCounted
class_name HexRingGenerator

"""
HexRingGenerator - Generates proper concentric hex rings algorithmically
RULE 2: Single responsibility - ONLY generates hex coordinates in rings
RULE 1: Under 500 lines

Hex Ring Math:
- Ring 0: 1 tile (center)
- Ring N: exactly 6*N tiles forming a complete ring
- Uses axial coordinates (q, r)

This replaces manual coordinate placement in JSON with robust, scalable generation.
"""

# ==============================================================================
# CONSTANTS - Axial coordinate directions for hex grid
# ==============================================================================

# The 6 directions in axial coordinates (clockwise from East)
const DIRECTIONS = [
	Vector2i(1, 0),   # E
	Vector2i(1, -1),  # NE
	Vector2i(0, -1),  # NW
	Vector2i(-1, 0),  # W
	Vector2i(-1, 1),  # SW
	Vector2i(0, 1)    # SE
]

# Direction names for debugging
const DIRECTION_NAMES = ["E", "NE", "NW", "W", "SW", "SE"]

# ==============================================================================
# RING GENERATION
# ==============================================================================

## Generate all coordinates for a single ring at distance N from center
## Ring 0 returns [(0,0)], Ring 1 returns 6 coords, Ring N returns 6*N coords
static func generate_ring(ring_distance: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []

	# Ring 0 is just the center
	if ring_distance == 0:
		coords.append(Vector2i(0, 0))
		return coords

	# Start at the E direction, scaled by ring distance
	var current = Vector2i(ring_distance, 0)

	# Walk around the ring - 6 sides, ring_distance steps per side
	for side in range(6):
		# Direction to walk for this side (perpendicular to radius)
		# We walk in direction (side + 2) % 6 for ring_distance steps
		var walk_dir = DIRECTIONS[(side + 2) % 6]

		for step in range(ring_distance):
			coords.append(current)
			current = current + walk_dir

	return coords

## Generate all coordinates from ring 0 to max_ring (inclusive)
static func generate_all_rings(max_ring: int) -> Array[Vector2i]:
	var all_coords: Array[Vector2i] = []

	for ring in range(max_ring + 1):
		all_coords.append_array(generate_ring(ring))

	return all_coords

## Generate coordinates for a filled hex area (all tiles within distance)
static func generate_filled_hex(radius: int) -> Array[Vector2i]:
	return generate_all_rings(radius)

## Get the ring distance of a coordinate from center (0,0)
static func get_ring_distance(coord: Vector2i) -> int:
	# Hex distance formula for axial coordinates
	return (abs(coord.x) + abs(coord.x + coord.y) + abs(coord.y)) / 2

## Get neighbors of a coordinate
static func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		neighbors.append(coord + dir)
	return neighbors

## Check if two coordinates are adjacent
static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff = b - a
	for dir in DIRECTIONS:
		if diff == dir:
			return true
	return false

# ==============================================================================
# NODE DISTRIBUTION - Assigns node types evenly across rings
# ==============================================================================

## Node types to distribute (excluding base which is always at center)
const NODE_TYPES = ["resource_node", "forge", "shrine"]

## Generate node assignments for a ring, distributing types evenly
## Returns Array of {coord: Vector2i, type: String, index: int}
static func distribute_nodes_in_ring(ring_distance: int) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []

	# Ring 0 is always the base
	if ring_distance == 0:
		nodes.append({
			"coord": Vector2i(0, 0),
			"type": "base",
			"index": 0
		})
		return nodes

	var ring_coords = generate_ring(ring_distance)
	var num_coords = ring_coords.size()
	var num_types = NODE_TYPES.size()

	# Distribute node types evenly around the ring
	# For ring 1 (6 nodes): 2 of each type
	# For ring 2 (12 nodes): 4 of each type
	# etc.
	for i in range(num_coords):
		var type_index = i % num_types
		var type_count = i / num_types  # How many of this type already placed

		nodes.append({
			"coord": ring_coords[i],
			"type": NODE_TYPES[type_index],
			"index": type_count  # 0, 1, 2... for naming (a, b, c...)
		})

	return nodes

## Generate complete node layout for all tiers
## max_tier: Maximum tier to generate (0-4 typically)
## Returns Array of node data ready for HexNode creation
static func generate_full_layout(tier_to_ring: Dictionary = {}) -> Array[Dictionary]:
	var all_nodes: Array[Dictionary] = []

	# Explicitly iterate tiers 0-4 in order to avoid dictionary iteration issues
	for tier in range(5):  # 0, 1, 2, 3, 4
		var ring = tier  # Ring distance equals tier number
		var ring_nodes = distribute_nodes_in_ring(ring)

		for node_data in ring_nodes:
			node_data["tier"] = tier
			node_data["ring"] = ring
			all_nodes.append(node_data)

	return all_nodes

# ==============================================================================
# DEBUG / VISUALIZATION
# ==============================================================================

## Print ASCII visualization of a ring layout
static func print_ring_layout(max_ring: int) -> void:
	print("=== Hex Ring Layout (rings 0-%d) ===" % max_ring)

	for ring in range(max_ring + 1):
		var coords = generate_ring(ring)
		print("Ring %d (%d tiles):" % [ring, coords.size()])

		var coord_strs = []
		for coord in coords:
			coord_strs.append("(%d,%d)" % [coord.x, coord.y])
		print("  " + ", ".join(coord_strs))

	print("Total tiles: %d" % generate_all_rings(max_ring).size())

## Validate that all coordinates in a ring are correct distance from center
static func validate_ring(ring_distance: int) -> bool:
	var coords = generate_ring(ring_distance)

	for coord in coords:
		var actual_distance = get_ring_distance(coord)
		if actual_distance != ring_distance:
			push_error("Ring validation failed: (%d,%d) has distance %d, expected %d" % [
				coord.x, coord.y, actual_distance, ring_distance
			])
			return false

	return true

## Validate all rings up to max_ring
static func validate_all_rings(max_ring: int) -> bool:
	for ring in range(max_ring + 1):
		if not validate_ring(ring):
			return false

		# Also validate ring size
		var expected_size = 1 if ring == 0 else 6 * ring
		var actual_size = generate_ring(ring).size()
		if actual_size != expected_size:
			push_error("Ring %d has %d tiles, expected %d" % [ring, actual_size, expected_size])
			return false

	return true
