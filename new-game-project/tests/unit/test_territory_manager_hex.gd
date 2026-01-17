# tests/unit/test_territory_manager_hex.gd
# Unit tests for TerritoryManager hex integration
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# SETUP
# ==============================================================================

func _create_mock_hex_coord(q: int, r: int):
	"""Create a HexCoord for testing"""
	var script = load("res://scripts/data/HexCoord.gd")
	return script.new(q, r)

func _create_mock_hex_node(node_id: String, q: int, r: int, tier: int = 1):
	"""Create a HexNode for testing"""
	var script = load("res://scripts/data/HexNode.gd")
	var node = script.new()
	node.id = node_id
	node.name = node_id.capitalize()
	node.node_type = "mine"
	node.tier = tier
	node.coord = _create_mock_hex_coord(q, r)
	node.controller = "neutral"
	node.is_revealed = false
	node.max_garrison = 2
	node.max_workers = 3
	node.capture_power_required = 5000
	node.production_level = 1
	node.defense_level = 1
	return node

func _create_mock_god(god_id: String, level: int = 1):
	"""Create a mock God object for testing"""
	var script = load("res://scripts/data/God.gd")
	var god_obj = script.new()
	god_obj.id = god_id
	god_obj.name = god_id.capitalize()
	god_obj.level = level
	god_obj.current_hp = 1000
	god_obj.attack = 100
	god_obj.defense = 80
	god_obj.speed = 60
	god_obj.awakening_level = 0
	return god_obj

# ==============================================================================
# CAPTURE NODE TESTS
# ==============================================================================

func test_capture_node_success():
	"""Capturing a node should mark it as player-controlled"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()
	var requirement_checker = NodeRequirementChecker.new()

	# Register systems
	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)
	registry.register_system("NodeRequirementChecker", requirement_checker)

	# Create and add test node
	var test_node = _create_mock_hex_node("test_node", 1, 0, 1)
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	# Mock player level
	var player_manager = PlayerProgressionManager.new()
	player_manager._player_level = 1
	registry.register_system("PlayerProgressionManager", player_manager)

	# Capture the node
	var coord = _create_mock_hex_coord(1, 0)
	var result = manager.capture_node(coord)

	runner.assert_true(result, "Capture should succeed")
	runner.assert_equal(test_node.controller, "player", "Node should be player-controlled")
	runner.assert_true(test_node.is_revealed, "Node should be revealed")
	runner.assert_true(test_node.id in manager.controlled_territories, "Node should be in controlled list")

func test_capture_node_no_node_at_coord():
	"""Capturing non-existent node should fail"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	var coord = _create_mock_hex_coord(5, 5)
	var result = manager.capture_node(coord)

	runner.assert_false(result, "Capture should fail for non-existent node")

func test_capture_node_requirements_not_met():
	"""Capturing node with unmet requirements should fail"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()
	var requirement_checker = NodeRequirementChecker.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)
	registry.register_system("NodeRequirementChecker", requirement_checker)

	# Create high-tier node
	var test_node = _create_mock_hex_node("high_tier_node", 2, 0, 5)
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["2,0"] = test_node

	# Mock low level player
	var player_manager = PlayerProgressionManager.new()
	player_manager._player_level = 1
	registry.register_system("PlayerProgressionManager", player_manager)

	# Try to capture
	var coord = _create_mock_hex_coord(2, 0)
	var result = manager.capture_node(coord)

	runner.assert_false(result, "Capture should fail - requirements not met")

# ==============================================================================
# LOSE NODE TESTS
# ==============================================================================

func test_lose_node_success():
	"""Losing a controlled node should reset it to neutral"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create player-controlled node
	var test_node = _create_mock_hex_node("test_node", 1, 0)
	test_node.controller = "player"
	test_node.garrison = ["god1", "god2"]
	test_node.assigned_workers = ["god3"]
	test_node.active_tasks = ["task1"]
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	manager.controlled_territories.append(test_node.id)

	# Lose the node
	var coord = _create_mock_hex_coord(1, 0)
	var result = manager.lose_node(coord)

	runner.assert_true(result, "Lose node should succeed")
	runner.assert_equal(test_node.controller, "neutral", "Node should be neutral")
	runner.assert_equal(test_node.garrison.size(), 0, "Garrison should be cleared")
	runner.assert_equal(test_node.assigned_workers.size(), 0, "Workers should be cleared")
	runner.assert_equal(test_node.active_tasks.size(), 0, "Tasks should be cleared")
	runner.assert_false(test_node.id in manager.controlled_territories, "Node should not be in controlled list")

func test_lose_node_not_controlled():
	"""Losing a non-controlled node should fail"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create neutral node
	var test_node = _create_mock_hex_node("test_node", 1, 0)
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	var coord = _create_mock_hex_coord(1, 0)
	var result = manager.lose_node(coord)

	runner.assert_false(result, "Cannot lose node not controlled by player")

# ==============================================================================
# DEFENSE RATING TESTS
# ==============================================================================

func test_node_defense_rating_no_garrison():
	"""Defense rating should be 0 for empty garrison"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	var test_node = _create_mock_hex_node("test_node", 1, 0)
	test_node.controller = "player"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	var coord = _create_mock_hex_coord(1, 0)
	var defense = manager.get_node_defense_rating(coord)

	runner.assert_equal(defense, 0.0, "Defense should be 0 with no garrison")

func test_node_defense_rating_with_garrison():
	"""Defense rating should calculate from garrison gods"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()
	var collection_manager = CollectionManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)
	registry.register_system("CollectionManager", collection_manager)

	# Create node with garrison
	var test_node = _create_mock_hex_node("test_node", 1, 0)
	test_node.controller = "player"
	test_node.garrison = ["god1"]
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	# Add god to collection
	var god_obj = _create_mock_god("god1", 10)
	collection_manager._gods_by_id[god_obj.id] = god_obj

	var coord = _create_mock_hex_coord(1, 0)
	var defense = manager.get_node_defense_rating(coord)

	runner.assert_true(defense > 0, "Defense should be positive with garrison")

func test_defense_rating_distance_penalty():
	"""Defense rating should decrease with distance from base"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()
	hex_grid._base_coord = _create_mock_hex_coord(0, 0)

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create far node
	var test_node = _create_mock_hex_node("test_node", 5, 0)
	test_node.controller = "player"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["5,0"] = test_node

	var coord = _create_mock_hex_coord(5, 0)
	var penalty = manager.calculate_distance_penalty(coord)

	# 5 hexes away = 5 * 0.05 = 0.25 penalty
	runner.assert_equal(penalty, 0.25, "Distance penalty should be 5% per hex")

# ==============================================================================
# CONNECTED BONUS TESTS
# ==============================================================================

func test_connected_bonus_no_neighbors():
	"""No connected bonus with no controlled neighbors"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	var test_node = _create_mock_hex_node("test_node", 1, 0)
	test_node.controller = "player"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	var coord = _create_mock_hex_coord(1, 0)
	var bonus = manager.get_connected_bonus(coord)

	runner.assert_equal(bonus, 0.0, "No bonus with 0-1 connected neighbors")

func test_connected_bonus_two_neighbors():
	"""2 connected neighbors = +10% bonus"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create center node
	var center_node = _create_mock_hex_node("center", 0, 0)
	center_node.controller = "player"
	hex_grid._nodes[center_node.id] = center_node
	hex_grid._coord_to_node["0,0"] = center_node

	# Create 2 controlled neighbors
	var neighbor1 = _create_mock_hex_node("n1", 1, 0)
	neighbor1.controller = "player"
	hex_grid._nodes[neighbor1.id] = neighbor1
	hex_grid._coord_to_node["1,0"] = neighbor1

	var neighbor2 = _create_mock_hex_node("n2", 0, 1)
	neighbor2.controller = "player"
	hex_grid._nodes[neighbor2.id] = neighbor2
	hex_grid._coord_to_node["0,1"] = neighbor2

	var coord = _create_mock_hex_coord(0, 0)
	var bonus = manager.get_connected_bonus(coord)

	runner.assert_equal(bonus, 0.10, "2 connected = +10% bonus")

func test_connected_bonus_three_neighbors():
	"""3 connected neighbors = +20% bonus"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create center node
	var center_node = _create_mock_hex_node("center", 0, 0)
	center_node.controller = "player"
	hex_grid._nodes[center_node.id] = center_node
	hex_grid._coord_to_node["0,0"] = center_node

	# Create 3 controlled neighbors
	for i in range(3):
		var coords = [[1,0], [0,1], [-1,1]]
		var neighbor = _create_mock_hex_node("n" + str(i), coords[i][0], coords[i][1])
		neighbor.controller = "player"
		hex_grid._nodes[neighbor.id] = neighbor
		hex_grid._coord_to_node[str(coords[i][0]) + "," + str(coords[i][1])] = neighbor

	var coord = _create_mock_hex_coord(0, 0)
	var bonus = manager.get_connected_bonus(coord)

	runner.assert_equal(bonus, 0.20, "3 connected = +20% bonus")

func test_connected_bonus_four_plus_neighbors():
	"""4+ connected neighbors = +30% bonus"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create center node
	var center_node = _create_mock_hex_node("center", 0, 0)
	center_node.controller = "player"
	hex_grid._nodes[center_node.id] = center_node
	hex_grid._coord_to_node["0,0"] = center_node

	# Create 4 controlled neighbors
	for i in range(4):
		var coords = [[1,0], [0,1], [-1,1], [-1,0]]
		var neighbor = _create_mock_hex_node("n" + str(i), coords[i][0], coords[i][1])
		neighbor.controller = "player"
		hex_grid._nodes[neighbor.id] = neighbor
		hex_grid._coord_to_node[str(coords[i][0]) + "," + str(coords[i][1])] = neighbor

	var coord = _create_mock_hex_coord(0, 0)
	var bonus = manager.get_connected_bonus(coord)

	runner.assert_equal(bonus, 0.30, "4+ connected = +30% bonus")

# ==============================================================================
# QUERY TESTS
# ==============================================================================

func test_get_controlled_nodes():
	"""Get all player-controlled hex nodes"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create mix of nodes
	var player_node1 = _create_mock_hex_node("player1", 1, 0)
	player_node1.controller = "player"
	hex_grid._nodes[player_node1.id] = player_node1

	var player_node2 = _create_mock_hex_node("player2", 0, 1)
	player_node2.controller = "player"
	hex_grid._nodes[player_node2.id] = player_node2

	var neutral_node = _create_mock_hex_node("neutral", 2, 0)
	hex_grid._nodes[neutral_node.id] = neutral_node

	var nodes = manager.get_controlled_nodes()

	runner.assert_equal(nodes.size(), 2, "Should return 2 player nodes")

func test_is_hex_node_controlled():
	"""Check if specific hex coordinate is controlled"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	var test_node = _create_mock_hex_node("test", 1, 0)
	test_node.controller = "player"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	var coord = _create_mock_hex_coord(1, 0)
	var controlled = manager.is_hex_node_controlled(coord)

	runner.assert_true(controlled, "Node should be controlled")

func test_get_connected_node_count():
	"""Count adjacent controlled nodes"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create center node
	var center_node = _create_mock_hex_node("center", 0, 0)
	center_node.controller = "player"
	hex_grid._nodes[center_node.id] = center_node
	hex_grid._coord_to_node["0,0"] = center_node

	# Create 2 controlled neighbors
	var neighbor1 = _create_mock_hex_node("n1", 1, 0)
	neighbor1.controller = "player"
	hex_grid._nodes[neighbor1.id] = neighbor1
	hex_grid._coord_to_node["1,0"] = neighbor1

	var neighbor2 = _create_mock_hex_node("n2", 0, 1)
	neighbor2.controller = "player"
	hex_grid._nodes[neighbor2.id] = neighbor2
	hex_grid._coord_to_node["0,1"] = neighbor2

	# Create 1 neutral neighbor
	var neutral = _create_mock_hex_node("neutral", -1, 0)
	hex_grid._nodes[neutral.id] = neutral
	hex_grid._coord_to_node["-1,0"] = neutral

	var coord = _create_mock_hex_coord(0, 0)
	var count = manager.get_connected_node_count(coord)

	runner.assert_equal(count, 2, "Should count 2 connected nodes")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_capture_node_no_hex_grid_manager():
	"""Capture should fail gracefully without HexGridManager"""
	var manager = TerritoryManager.new()

	var coord = _create_mock_hex_coord(1, 0)
	var result = manager.capture_node(coord)

	runner.assert_false(result, "Should fail without HexGridManager")

func test_connected_bonus_neutral_node():
	"""Connected bonus should be 0 for neutral node"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	var test_node = _create_mock_hex_node("test", 1, 0)
	test_node.controller = "neutral"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["1,0"] = test_node

	var coord = _create_mock_hex_coord(1, 0)
	var bonus = manager.get_connected_bonus(coord)

	runner.assert_equal(bonus, 0.0, "Neutral node should have no bonus")

func test_defense_penalty_capped_at_95_percent():
	"""Distance penalty should cap at 95%"""
	var manager = TerritoryManager.new()
	var hex_grid = HexGridManager.new()
	hex_grid._base_coord = _create_mock_hex_coord(0, 0)

	var registry = SystemRegistry.get_instance()
	registry.register_system("HexGridManager", hex_grid)

	# Create very far node (20 hexes away)
	var test_node = _create_mock_hex_node("test", 20, 0)
	test_node.controller = "player"
	hex_grid._nodes[test_node.id] = test_node
	hex_grid._coord_to_node["20,0"] = test_node

	var coord = _create_mock_hex_coord(20, 0)
	var penalty = manager.calculate_distance_penalty(coord)

	runner.assert_equal(penalty, 0.95, "Penalty should cap at 95%")
