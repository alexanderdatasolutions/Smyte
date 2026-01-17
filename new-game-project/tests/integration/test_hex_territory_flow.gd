# tests/integration/test_hex_territory_flow.gd
# Integration tests for hex territory system
# Tests interaction between HexGridManager, TerritoryManager, NodeRequirementChecker, and TerritoryProductionManager
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_test_god(god_id: String, level: int = 1, base_hp: int = 1000, base_attack: int = 150, base_defense: int = 100, base_speed: int = 80) -> God:
	"""Create a test god with specified stats"""
	var god_script = load("res://scripts/data/God.gd")
	var god_instance = god_script.new()
	god_instance.id = god_id
	god_instance.name = god_id.capitalize()
	god_instance.level = level
	god_instance.base_hp = base_hp
	god_instance.base_attack = base_attack
	god_instance.base_defense = base_defense
	god_instance.base_speed = base_speed
	god_instance.tier = God.TierType.RARE
	god_instance.element = God.ElementType.FIRE
	god_instance.pantheon = "greek"
	god_instance.is_awakened = false
	god_instance.ascension_level = 0
	god_instance.specialization_path = ["", "", ""]
	return god_instance

func create_test_hex_node(node_id: String, q: int, r: int, tier: int = 1, node_type: String = "mine") -> HexNode:
	"""Create a test hex node"""
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
	# Use .assign() for typed arrays in Godot 4.5
	node.garrison.assign([])
	node.assigned_workers.assign([])
	node.active_tasks.assign([])
	node.base_defenders.assign([])
	node.available_tasks.assign(["mining", "gather_stone"])
	node.max_garrison = 2
	node.max_workers = 3
	node.production_level = 1
	node.defense_level = 1
	node.base_production = {"iron_ore": 30, "stone": 20}

	# Set requirements based on tier
	if tier == 1:
		node.unlock_requirements = {"player_level": 1, "specialization_tier": 0, "specialization_role": ""}
	elif tier == 2:
		node.unlock_requirements = {"player_level": 10, "specialization_tier": 1, "specialization_role": ""}
	elif tier == 3:
		node.unlock_requirements = {"player_level": 20, "specialization_tier": 2, "specialization_role": ""}
	elif tier == 4:
		node.unlock_requirements = {"player_level": 30, "specialization_tier": 2, "specialization_role": "gatherer"}
	elif tier == 5:
		node.unlock_requirements = {"player_level": 40, "specialization_tier": 3, "specialization_role": ""}

	return node

func create_test_managers() -> Dictionary:
	"""Create instances of all required managers for testing with SystemRegistry mock"""
	var managers = {}

	# Create managers
	var hex_grid_manager = HexGridManager.new()
	hex_grid_manager._initialize_base_coord()
	managers["hex_grid"] = hex_grid_manager

	var territory_manager = TerritoryManager.new()
	managers["territory"] = territory_manager

	var production_manager = TerritoryProductionManager.new()
	managers["production"] = production_manager

	var requirement_checker = NodeRequirementChecker.new()
	managers["requirement_checker"] = requirement_checker

	# Register managers in SystemRegistry for integration testing
	var registry = SystemRegistry.get_instance()
	if registry:
		registry._register_system("HexGridManager", hex_grid_manager)
		registry._register_system("TerritoryManager", territory_manager)
		registry._register_system("TerritoryProductionManager", production_manager)
		registry._register_system("NodeRequirementChecker", requirement_checker)

	return managers

# ==============================================================================
# TEST: Full Capture Flow
# ==============================================================================

func test_capture_flow_tier1_success():
	"""Test capturing a tier 1 node successfully"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create tier 1 node
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	hex_grid._add_node(node)

	# Capture the node
	var coord = node.coord
	var success = territory_mgr.capture_node(coord)

	runner.assert_true(success, "Should successfully capture tier 1 node")
	runner.assert_true(territory_mgr.is_hex_node_controlled(coord), "Node should be controlled")
	runner.assert_equal(node.controller, "player", "Node controller should be player")

func test_capture_flow_already_controlled():
	"""Test attempting to capture already controlled node fails"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create and capture node
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	hex_grid._add_node(node)
	var coord = node.coord

	territory_mgr.capture_node(coord)

	# Try to capture again
	var success = territory_mgr.capture_node(coord)

	runner.assert_false(success, "Should not capture already controlled node")

func test_capture_updates_controlled_nodes():
	"""Test capturing multiple nodes updates controlled nodes list"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create multiple nodes
	var node1 = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	var node2 = create_test_hex_node("forest_1", 0, 1, 1, "forest")
	hex_grid._add_node(node1)
	hex_grid._add_node(node2)

	# Capture both
	territory_mgr.capture_node(node1.coord)
	territory_mgr.capture_node(node2.coord)

	var controlled = territory_mgr.get_controlled_nodes()

	runner.assert_equal(controlled.size(), 2, "Should have 2 controlled nodes")

func test_lose_node_removes_from_controlled():
	"""Test losing a node removes it from controlled list"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create and capture node
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	hex_grid._add_node(node)
	var coord = node.coord

	territory_mgr.capture_node(coord)
	runner.assert_true(territory_mgr.is_hex_node_controlled(coord), "Node should be controlled")

	# Lose the node
	territory_mgr.lose_node(coord)

	runner.assert_false(territory_mgr.is_hex_node_controlled(coord), "Node should not be controlled")
	runner.assert_equal(node.controller, "neutral", "Node controller should be neutral")

# ==============================================================================
# TEST: Production with Bonuses
# ==============================================================================

func test_production_basic_calculation():
	"""Test basic production calculation without bonuses"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var production_mgr = managers["production"]

	# Create node with base production
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	node.base_production = {"iron_ore": 100}
	node.production_level = 1
	hex_grid._add_node(node)

	var production = production_mgr.calculate_node_production(node)

	runner.assert_equal(production.get("iron_ore", 0), 100, "Should have base production of 100")

func test_production_with_upgrade_bonus():
	"""Test production calculation with upgrade bonuses"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var production_mgr = managers["production"]

	# Create node with upgrades
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	node.base_production = {"iron_ore": 100}
	node.production_level = 3  # 2 upgrades = +20%
	hex_grid._add_node(node)

	var production = production_mgr.calculate_node_production(node)

	runner.assert_equal(production.get("iron_ore", 0), 120, "Should have 20% upgrade bonus (100 * 1.2)")

func test_production_with_connected_bonus():
	"""Test production with connected node bonuses"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]
	var production_mgr = managers["production"]

	# Create center node and 2 neighbors
	var node_center = create_test_hex_node("mine_center", 0, 0, 1, "mine")
	var node_neighbor1 = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	var node_neighbor2 = create_test_hex_node("mine_2", 0, 1, 1, "mine")

	node_center.base_production = {"iron_ore": 100}
	node_center.production_level = 1

	hex_grid._add_node(node_center)
	hex_grid._add_node(node_neighbor1)
	hex_grid._add_node(node_neighbor2)

	# Capture all nodes
	territory_mgr.capture_node(node_center.coord)
	territory_mgr.capture_node(node_neighbor1.coord)
	territory_mgr.capture_node(node_neighbor2.coord)

	# Check connected bonus (2 connected = +10%)
	var bonus = production_mgr.apply_connected_bonus(node_center)
	runner.assert_equal(bonus, 0.1, "Should have 10% bonus for 2 connected nodes")

	var production = production_mgr.calculate_node_production(node_center)
	runner.assert_equal(production.get("iron_ore", 0), 110, "Should have 10% connected bonus (100 * 1.1)")

func test_production_with_three_connected():
	"""Test production with 3 connected nodes gives 20% bonus"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]
	var production_mgr = managers["production"]

	# Create center node and 3 neighbors
	var node_center = create_test_hex_node("mine_center", 0, 0, 1, "mine")
	var node_n1 = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	var node_n2 = create_test_hex_node("mine_2", 0, 1, 1, "mine")
	var node_n3 = create_test_hex_node("mine_3", -1, 1, 1, "mine")

	node_center.base_production = {"iron_ore": 100}

	hex_grid._add_node(node_center)
	hex_grid._add_node(node_n1)
	hex_grid._add_node(node_n2)
	hex_grid._add_node(node_n3)

	# Capture all
	territory_mgr.capture_node(node_center.coord)
	territory_mgr.capture_node(node_n1.coord)
	territory_mgr.capture_node(node_n2.coord)
	territory_mgr.capture_node(node_n3.coord)

	# Check 3 connected = +20%
	var bonus = production_mgr.apply_connected_bonus(node_center)
	runner.assert_equal(bonus, 0.2, "Should have 20% bonus for 3 connected nodes")

func test_production_with_four_plus_connected():
	"""Test production with 4+ connected nodes gives 30% bonus"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]
	var production_mgr = managers["production"]

	# Create center node and 4 neighbors
	var node_center = create_test_hex_node("mine_center", 0, 0, 1, "mine")
	var neighbors = [
		create_test_hex_node("n1", 1, 0, 1, "mine"),
		create_test_hex_node("n2", 0, 1, 1, "mine"),
		create_test_hex_node("n3", -1, 1, 1, "mine"),
		create_test_hex_node("n4", -1, 0, 1, "mine")
	]

	node_center.base_production = {"iron_ore": 100}

	hex_grid._add_node(node_center)
	for neighbor in neighbors:
		hex_grid._add_node(neighbor)
		territory_mgr.capture_node(neighbor.coord)

	territory_mgr.capture_node(node_center.coord)

	# Check 4+ connected = +30%
	var bonus = production_mgr.apply_connected_bonus(node_center)
	runner.assert_equal(bonus, 0.3, "Should have 30% bonus for 4+ connected nodes")

func test_production_multiple_resources():
	"""Test production calculation with multiple resource types"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var production_mgr = managers["production"]

	# Create node with multiple resources
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	node.base_production = {"iron_ore": 100, "stone": 50, "copper_ore": 30}
	node.production_level = 1
	hex_grid._add_node(node)

	var production = production_mgr.calculate_node_production(node)

	runner.assert_equal(production.get("iron_ore", 0), 100, "Should have 100 iron ore")
	runner.assert_equal(production.get("stone", 0), 50, "Should have 50 stone")
	runner.assert_equal(production.get("copper_ore", 0), 30, "Should have 30 copper ore")

# ==============================================================================
# TEST: Garrison Defense Calculation
# ==============================================================================

func test_garrison_empty_node():
	"""Test defense calculation with no garrison"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create node at distance 1
	var node = create_test_hex_node("mine_1", 1, 0, 1, "mine")
	hex_grid._add_node(node)
	territory_mgr.capture_node(node.coord)

	var defense = territory_mgr.get_node_defense_rating(node.coord)

	runner.assert_equal(defense, 0.0, "Empty garrison should have 0 defense")

func test_garrison_distance_penalty():
	"""Test distance penalty reduces defense rating"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create node at distance 2 from base (0,0)
	var node = create_test_hex_node("mine_far", 2, 0, 1, "mine")
	hex_grid._add_node(node)

	var penalty = territory_mgr.calculate_distance_penalty(node.coord)

	runner.assert_equal(penalty, 0.1, "Distance 2 should have 10% penalty (5% per hex)")

func test_garrison_distance_penalty_capped():
	"""Test distance penalty is capped at 95%"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create node at distance 20 from base
	var node = create_test_hex_node("mine_far", 20, 0, 1, "mine")
	hex_grid._add_node(node)

	var penalty = territory_mgr.calculate_distance_penalty(node.coord)

	runner.assert_equal(penalty, 0.95, "Distance penalty should cap at 95%")

func test_garrison_connected_bonus_defense():
	"""Test connected nodes provide defense bonus"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create center and 2 neighbors
	var node_center = create_test_hex_node("center", 0, 0, 1, "mine")
	var node_n1 = create_test_hex_node("n1", 1, 0, 1, "mine")
	var node_n2 = create_test_hex_node("n2", 0, 1, 1, "mine")

	hex_grid._add_node(node_center)
	hex_grid._add_node(node_n1)
	hex_grid._add_node(node_n2)

	territory_mgr.capture_node(node_center.coord)
	territory_mgr.capture_node(node_n1.coord)
	territory_mgr.capture_node(node_n2.coord)

	# Check connected bonus (2 connected = +10%)
	var bonus = territory_mgr.get_connected_bonus(node_center.coord)
	runner.assert_equal(bonus, 0.1, "2 connected nodes should give 10% defense bonus")

# ==============================================================================
# TEST: Connected Node Bonuses
# ==============================================================================

func test_connected_count_no_neighbors():
	"""Test connected count with no captured neighbors"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create center node
	var node = create_test_hex_node("center", 1, 1, 1, "mine")
	hex_grid._add_node(node)
	territory_mgr.capture_node(node.coord)

	var count = territory_mgr.get_connected_node_count(node.coord)

	runner.assert_equal(count, 0, "Should have 0 connected nodes")

func test_connected_count_one_neighbor():
	"""Test connected count with 1 captured neighbor"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create 2 adjacent nodes
	var node1 = create_test_hex_node("node1", 1, 0, 1, "mine")
	var node2 = create_test_hex_node("node2", 2, 0, 1, "mine")  # Adjacent to node1

	hex_grid._add_node(node1)
	hex_grid._add_node(node2)

	territory_mgr.capture_node(node1.coord)
	territory_mgr.capture_node(node2.coord)

	var count = territory_mgr.get_connected_node_count(node1.coord)

	runner.assert_equal(count, 1, "Should have 1 connected node")

func test_connected_count_ignores_enemy_nodes():
	"""Test connected count ignores non-player controlled nodes"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create 2 adjacent nodes, only capture one
	var node1 = create_test_hex_node("node1", 1, 0, 1, "mine")
	var node2 = create_test_hex_node("node2", 2, 0, 1, "mine")

	hex_grid._add_node(node1)
	hex_grid._add_node(node2)

	territory_mgr.capture_node(node1.coord)
	# Don't capture node2 - leave as neutral

	var count = territory_mgr.get_connected_node_count(node1.coord)

	runner.assert_equal(count, 0, "Should not count neutral neighbors")

func test_connected_bonus_tiers():
	"""Test connected bonus tiers (0%, 10%, 20%, 30%)"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create center and 4 neighbors
	var center = create_test_hex_node("center", 0, 0, 1, "mine")
	var neighbors = [
		create_test_hex_node("n1", 1, 0, 1, "mine"),
		create_test_hex_node("n2", 0, 1, 1, "mine"),
		create_test_hex_node("n3", -1, 1, 1, "mine"),
		create_test_hex_node("n4", -1, 0, 1, "mine")
	]

	hex_grid._add_node(center)
	for neighbor in neighbors:
		hex_grid._add_node(neighbor)

	territory_mgr.capture_node(center.coord)

	# 0 connected
	var bonus = territory_mgr.get_connected_bonus(center.coord)
	runner.assert_equal(bonus, 0.0, "0 connected should give 0% bonus")

	# 2 connected
	territory_mgr.capture_node(neighbors[0].coord)
	territory_mgr.capture_node(neighbors[1].coord)
	bonus = territory_mgr.get_connected_bonus(center.coord)
	runner.assert_equal(bonus, 0.1, "2 connected should give 10% bonus")

	# 3 connected
	territory_mgr.capture_node(neighbors[2].coord)
	bonus = territory_mgr.get_connected_bonus(center.coord)
	runner.assert_equal(bonus, 0.2, "3 connected should give 20% bonus")

	# 4+ connected
	territory_mgr.capture_node(neighbors[3].coord)
	bonus = territory_mgr.get_connected_bonus(center.coord)
	runner.assert_equal(bonus, 0.3, "4+ connected should give 30% bonus")

# ==============================================================================
# TEST: Integration Scenarios
# ==============================================================================

func test_full_territory_expansion():
	"""Test expanding territory from base across multiple tiers"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]

	# Create base and ring 1 nodes
	var base = create_test_hex_node("base", 0, 0, 0, "base")
	var ring1_nodes = [
		create_test_hex_node("r1_1", 1, 0, 1, "mine"),
		create_test_hex_node("r1_2", 0, 1, 1, "forest"),
		create_test_hex_node("r1_3", -1, 1, 1, "coast")
	]

	hex_grid._add_node(base)
	for node in ring1_nodes:
		hex_grid._add_node(node)

	# Capture base
	base.controller = "player"

	# Capture all ring 1 nodes
	for node in ring1_nodes:
		var success = territory_mgr.capture_node(node.coord)
		runner.assert_true(success, "Should capture ring 1 node: " + node.id)

	# Verify all captured
	var controlled = territory_mgr.get_controlled_nodes()
	runner.assert_equal(controlled.size(), 3, "Should have 3 controlled nodes")

func test_production_with_all_bonuses():
	"""Test production calculation with upgrade, connected, and worker bonuses"""
	var managers = create_test_managers()
	var hex_grid = managers["hex_grid"]
	var territory_mgr = managers["territory"]
	var production_mgr = managers["production"]

	# Create center node with neighbors
	var node = create_test_hex_node("mine_center", 0, 0, 1, "mine")
	node.base_production = {"iron_ore": 100}
	node.production_level = 3  # +20% upgrade bonus
	node.assigned_workers = ["worker1"]  # +10% worker bonus

	var neighbor1 = create_test_hex_node("n1", 1, 0, 1, "mine")
	var neighbor2 = create_test_hex_node("n2", 0, 1, 1, "mine")

	hex_grid._add_node(node)
	hex_grid._add_node(neighbor1)
	hex_grid._add_node(neighbor2)

	territory_mgr.capture_node(node.coord)
	territory_mgr.capture_node(neighbor1.coord)
	territory_mgr.capture_node(neighbor2.coord)

	# Calculate production with all bonuses
	# Base: 100
	# Upgrade: 100 * 1.2 = 120
	# Connected (2): 120 * 1.1 = 132
	# Worker (1): 132 * 1.1 = 145.2 → 145
	var production = production_mgr.calculate_node_production(node)

	runner.assert_greater_than(production.get("iron_ore", 0), 140, "Should have significant production bonus")
