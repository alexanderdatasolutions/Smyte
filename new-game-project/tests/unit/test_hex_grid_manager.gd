# tests/unit/test_hex_grid_manager.gd
# Unit tests for HexGridManager system
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# SETUP & TEARDOWN
# ==============================================================================

func _create_test_manager() -> HexGridManager:
	"""Create a test HexGridManager instance"""
	var manager = HexGridManager.new()
	return manager

func _create_test_node(node_id: String, q: int, r: int, tier: int = 1, node_type: String = "mine") -> HexNode:
	"""Create a test HexNode"""
	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(q, r)

	var node_script = load("res://scripts/data/HexNode.gd")
	var node = node_script.new()
	node.id = node_id
	node.name = node_id.capitalize()
	node.coord = coord
	node.tier = tier
	node.node_type = node_type
	node.controller = "neutral"
	return node

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_manager_initializes() -> void:
	"""Test that manager initializes properly"""
	var manager = _create_test_manager()
	runner.assert_not_null(manager, "Manager should be created")
	runner.assert_not_null(manager.get_base_coord(), "Base coord should be initialized")

func test_base_coord_is_origin() -> void:
	"""Test that base coordinate is at origin (0,0)"""
	var manager = _create_test_manager()
	var base = manager.get_base_coord()
	runner.assert_equal(base.q, 0, "Base coord q should be 0")
	runner.assert_equal(base.r, 0, "Base coord r should be 0")

func test_manager_loads_without_json() -> void:
	"""Test that manager handles missing hex_nodes.json gracefully"""
	var manager = _create_test_manager()
	manager._ready()
	# Should not crash, just emit warning
	runner.assert_equal(manager.get_node_count(), 0, "Should have 0 nodes when JSON missing")

# ==============================================================================
# NODE QUERY TESTS
# ==============================================================================

func test_get_node_at_returns_null_for_empty_grid() -> void:
	"""Test getting node at coordinate returns null when no nodes"""
	var manager = _create_test_manager()
	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(1, 0)
	var node = manager.get_node_at(coord)
	runner.assert_null(node, "Should return null for empty grid")

func test_get_node_at_returns_correct_node() -> void:
	"""Test getting node at coordinate returns correct node"""
	var manager = _create_test_manager()
	var test_node = _create_test_node("test_mine", 1, 0)
	manager._add_node(test_node)

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(1, 0)
	var retrieved = manager.get_node_at(coord)

	runner.assert_not_null(retrieved, "Should find node")
	runner.assert_equal(retrieved.id, "test_mine", "Should return correct node")

func test_get_node_by_id_works() -> void:
	"""Test getting node by ID"""
	var manager = _create_test_manager()
	var test_node = _create_test_node("test_forge", 0, 1)
	manager._add_node(test_node)

	var retrieved = manager.get_node_by_id("test_forge")
	runner.assert_not_null(retrieved, "Should find node by ID")
	runner.assert_equal(retrieved.id, "test_forge", "Should return correct node")

func test_get_all_nodes_returns_all() -> void:
	"""Test getting all nodes"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("node1", 1, 0))
	manager._add_node(_create_test_node("node2", 0, 1))
	manager._add_node(_create_test_node("node3", -1, 1))

	var all_nodes = manager.get_all_nodes()
	runner.assert_equal(all_nodes.size(), 3, "Should have 3 nodes")

func test_has_node_at_works() -> void:
	"""Test checking if node exists at coordinate"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("node1", 2, -1))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord1 = coord_script.new(2, -1)
	var coord2 = coord_script.new(3, 0)

	runner.assert_true(manager.has_node_at(coord1), "Should have node at (2,-1)")
	runner.assert_false(manager.has_node_at(coord2), "Should not have node at (3,0)")

# ==============================================================================
# SPATIAL QUERY TESTS
# ==============================================================================

func test_get_neighbors_returns_adjacent_nodes() -> void:
	"""Test getting neighboring nodes"""
	var manager = _create_test_manager()

	# Create center node and all 6 neighbors
	var center = _create_test_node("center", 0, 0)
	manager._add_node(center)
	manager._add_node(_create_test_node("n1", 1, 0))
	manager._add_node(_create_test_node("n2", -1, 0))
	manager._add_node(_create_test_node("n3", 0, 1))
	manager._add_node(_create_test_node("n4", 0, -1))
	manager._add_node(_create_test_node("n5", 1, -1))
	manager._add_node(_create_test_node("n6", -1, 1))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var center_coord = coord_script.new(0, 0)
	var neighbors = manager.get_neighbors(center_coord)

	runner.assert_equal(neighbors.size(), 6, "Should have 6 neighbors")

func test_get_neighbors_with_partial_neighbors() -> void:
	"""Test getting neighbors when some are missing"""
	var manager = _create_test_manager()

	# Create center and only 2 neighbors
	manager._add_node(_create_test_node("center", 0, 0))
	manager._add_node(_create_test_node("n1", 1, 0))
	manager._add_node(_create_test_node("n2", 0, 1))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var center_coord = coord_script.new(0, 0)
	var neighbors = manager.get_neighbors(center_coord)

	runner.assert_equal(neighbors.size(), 2, "Should have 2 neighbors")

func test_get_nodes_in_ring_works() -> void:
	"""Test getting nodes in specific ring"""
	var manager = _create_test_manager()

	# Ring 0 (base)
	manager._add_node(_create_test_node("base", 0, 0))

	# Ring 1 (6 nodes)
	manager._add_node(_create_test_node("r1_n1", 1, 0))
	manager._add_node(_create_test_node("r1_n2", -1, 0))

	# Ring 2 (nodes further out)
	manager._add_node(_create_test_node("r2_n1", 2, 0))
	manager._add_node(_create_test_node("r2_n2", 0, 2))

	var ring0 = manager.get_nodes_in_ring(0)
	var ring1 = manager.get_nodes_in_ring(1)
	var ring2 = manager.get_nodes_in_ring(2)

	runner.assert_equal(ring0.size(), 1, "Ring 0 should have 1 node")
	runner.assert_equal(ring1.size(), 2, "Ring 1 should have 2 nodes")
	runner.assert_equal(ring2.size(), 2, "Ring 2 should have 2 nodes")

func test_get_nodes_within_distance_works() -> void:
	"""Test getting nodes within distance"""
	var manager = _create_test_manager()

	manager._add_node(_create_test_node("base", 0, 0))
	manager._add_node(_create_test_node("near1", 1, 0))
	manager._add_node(_create_test_node("near2", 0, 1))
	manager._add_node(_create_test_node("far1", 3, 0))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var center = coord_script.new(0, 0)
	var close_nodes = manager.get_nodes_within_distance(center, 1)
	var all_nodes = manager.get_nodes_within_distance(center, 10)

	runner.assert_equal(close_nodes.size(), 3, "Should have 3 nodes within distance 1")
	runner.assert_equal(all_nodes.size(), 4, "Should have all 4 nodes within distance 10")

func test_get_distance_works() -> void:
	"""Test distance calculation"""
	var manager = _create_test_manager()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord1 = coord_script.new(0, 0)
	var coord2 = coord_script.new(3, 0)
	var coord3 = coord_script.new(2, 2)

	runner.assert_equal(manager.get_distance(coord1, coord2), 3, "Distance should be 3")
	runner.assert_equal(manager.get_distance(coord1, coord3), 4, "Distance should be 4")

func test_get_distance_from_base_works() -> void:
	"""Test distance from base calculation"""
	var manager = _create_test_manager()

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord1 = coord_script.new(2, 0)
	var coord2 = coord_script.new(-1, 2)

	runner.assert_equal(manager.get_distance_from_base(coord1), 2, "Distance from base should be 2")
	runner.assert_equal(manager.get_distance_from_base(coord2), 3, "Distance from base should be 3")

# ==============================================================================
# PATHFINDING TESTS
# ==============================================================================

func test_get_path_same_coord_returns_single_element() -> void:
	"""Test path from coord to itself"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("node", 0, 0))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(0, 0)
	var path = manager.get_path(coord, coord)

	runner.assert_equal(path.size(), 1, "Path to self should have 1 element")

func test_get_path_adjacent_nodes() -> void:
	"""Test path between adjacent nodes"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("n1", 0, 0))
	manager._add_node(_create_test_node("n2", 1, 0))

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var from = coord_script.new(0, 0)
	var to = coord_script.new(1, 0)
	var path = manager.get_hex_path(from, to)

	runner.assert_equal(path.size(), 2, "Path should have 2 coordinates")
	runner.assert_true(path[0].equals(from), "Path should start at from")
	runner.assert_true(path[path.size()-1].equals(to), "Path should end at to")

func test_get_path_no_path_returns_empty() -> void:
	"""Test path when no connection exists"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("n1", 0, 0))
	manager._add_node(_create_test_node("n2", 5, 5))
	# No nodes in between - no path possible

	var coord_script = load("res://scripts/data/HexCoord.gd")
	var from = coord_script.new(0, 0)
	var to = coord_script.new(5, 5)
	var path = manager.get_hex_path(from, to)

	runner.assert_equal(path.size(), 0, "Should return empty array when no path")

# ==============================================================================
# FILTERING TESTS
# ==============================================================================

func test_get_nodes_by_type_works() -> void:
	"""Test filtering nodes by type"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("mine1", 0, 0, 1, "mine"))
	manager._add_node(_create_test_node("mine2", 1, 0, 1, "mine"))
	manager._add_node(_create_test_node("forest1", 0, 1, 1, "forest"))

	var mines = manager.get_nodes_by_type("mine")
	var forests = manager.get_nodes_by_type("forest")

	runner.assert_equal(mines.size(), 2, "Should have 2 mines")
	runner.assert_equal(forests.size(), 1, "Should have 1 forest")

func test_get_nodes_by_tier_works() -> void:
	"""Test filtering nodes by tier"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("t1_node1", 0, 0, 1))
	manager._add_node(_create_test_node("t1_node2", 1, 0, 1))
	manager._add_node(_create_test_node("t2_node1", 0, 1, 2))
	manager._add_node(_create_test_node("t3_node1", -1, 0, 3))

	var tier1 = manager.get_nodes_by_tier(1)
	var tier2 = manager.get_nodes_by_tier(2)
	var tier3 = manager.get_nodes_by_tier(3)

	runner.assert_equal(tier1.size(), 2, "Should have 2 tier 1 nodes")
	runner.assert_equal(tier2.size(), 1, "Should have 1 tier 2 node")
	runner.assert_equal(tier3.size(), 1, "Should have 1 tier 3 node")

func test_get_nodes_by_controller_works() -> void:
	"""Test filtering nodes by controller"""
	var manager = _create_test_manager()

	var node1 = _create_test_node("player1", 0, 0)
	node1.controller = "player"
	manager._add_node(node1)

	var node2 = _create_test_node("player2", 1, 0)
	node2.controller = "player"
	manager._add_node(node2)

	var node3 = _create_test_node("enemy1", 0, 1)
	node3.controller = "enemy_123"
	manager._add_node(node3)

	var node4 = _create_test_node("neutral1", -1, 0)
	node4.controller = "neutral"
	manager._add_node(node4)

	var player_nodes = manager.get_player_nodes()
	var neutral_nodes = manager.get_neutral_nodes()

	runner.assert_equal(player_nodes.size(), 2, "Should have 2 player nodes")
	runner.assert_equal(neutral_nodes.size(), 1, "Should have 1 neutral node")

func test_get_revealed_nodes_works() -> void:
	"""Test filtering revealed nodes"""
	var manager = _create_test_manager()

	var node1 = _create_test_node("revealed1", 0, 0)
	node1.is_revealed = true
	manager._add_node(node1)

	var node2 = _create_test_node("revealed2", 1, 0)
	node2.is_revealed = true
	manager._add_node(node2)

	var node3 = _create_test_node("hidden", 0, 1)
	node3.is_revealed = false
	manager._add_node(node3)

	var revealed = manager.get_revealed_nodes()
	runner.assert_equal(revealed.size(), 2, "Should have 2 revealed nodes")

# ==============================================================================
# GRID INFO TESTS
# ==============================================================================

func test_get_node_count_works() -> void:
	"""Test node count"""
	var manager = _create_test_manager()
	runner.assert_equal(manager.get_node_count(), 0, "Should start with 0 nodes")

	manager._add_node(_create_test_node("node1", 0, 0))
	manager._add_node(_create_test_node("node2", 1, 0))
	runner.assert_equal(manager.get_node_count(), 2, "Should have 2 nodes")

func test_get_max_ring_works() -> void:
	"""Test max ring calculation"""
	var manager = _create_test_manager()
	manager._add_node(_create_test_node("base", 0, 0))
	runner.assert_equal(manager.get_max_ring(), 0, "Max ring should be 0")

	manager._add_node(_create_test_node("ring1", 1, 0))
	runner.assert_equal(manager.get_max_ring(), 1, "Max ring should be 1")

	manager._add_node(_create_test_node("ring3", 3, 0))
	runner.assert_equal(manager.get_max_ring(), 3, "Max ring should be 3")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_null_coord_handling() -> void:
	"""Test handling of null coordinates"""
	var manager = _create_test_manager()
	var node = manager.get_node_at(null)
	var has_node = manager.has_node_at(null)
	var neighbors = manager.get_neighbors(null)

	runner.assert_null(node, "Should return null for null coord")
	runner.assert_false(has_node, "Should return false for null coord")
	runner.assert_equal(neighbors.size(), 0, "Should return empty array for null coord")

func test_negative_distance_query() -> void:
	"""Test negative distance in queries"""
	var manager = _create_test_manager()
	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new(0, 0)
	var nodes = manager.get_nodes_within_distance(coord, -1)

	runner.assert_equal(nodes.size(), 0, "Should return empty for negative distance")

func test_empty_grid_queries() -> void:
	"""Test queries on empty grid"""
	var manager = _create_test_manager()

	runner.assert_equal(manager.get_all_nodes().size(), 0, "All nodes should be empty")
	runner.assert_equal(manager.get_player_nodes().size(), 0, "Player nodes should be empty")
	runner.assert_equal(manager.get_nodes_in_ring(1).size(), 0, "Ring 1 should be empty")
	runner.assert_equal(manager.get_max_ring(), 0, "Max ring should be 0")
