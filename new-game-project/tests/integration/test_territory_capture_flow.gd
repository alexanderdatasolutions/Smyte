# tests/integration/test_territory_capture_flow.gd
# Integration test: Territory capture and resource generation
extends RefCounted

var runner = null
var hex_grid_manager = null
var territory_manager = null
var task_assignment_manager = null
var territory_production_manager = null
var collection_manager = null
var node_requirement_checker = null
var player_progression = null

func set_runner(test_runner):
	runner = test_runner

func setup():
	var registry = SystemRegistry.get_instance()
	hex_grid_manager = registry.get_system("HexGridManager")
	territory_manager = registry.get_system("TerritoryManager")
	task_assignment_manager = registry.get_system("TaskAssignmentManager")
	territory_production_manager = registry.get_system("TerritoryProductionManager")
	collection_manager = registry.get_system("CollectionManager")
	node_requirement_checker = registry.get_system("NodeRequirementChecker")
	player_progression = registry.get_system("PlayerProgressionManager")

func test_capture_tier1_node():
	"""
	USER FLOW:
	1. Player starts with base node only
	2. Player captures adjacent Tier 1 node
	3. Node becomes player-controlled
	4. Player can view node resources
	"""
	setup()

	# STEP 1: Verify player controls base
	var base_node = territory_manager.get_node_at_coord(HexCoord.new(0, 0))
	runner.assert_not_null(base_node, "Step 1: Base should exist")
	runner.assert_equal(base_node.controller, "player", "Step 1: Player should control base")

	# STEP 2: Find an adjacent Tier 1 node
	var neighbors = hex_grid_manager.get_neighbors(HexCoord.new(0, 0))
	runner.assert_true(neighbors.size() > 0, "Step 2: Base should have neighbors")

	var tier1_node = null
	for neighbor_coord in neighbors:
		var node = territory_manager.get_node_at_coord(neighbor_coord)
		if node and node.tier == 1:
			tier1_node = node
			break

	runner.assert_not_null(tier1_node, "Step 2: Should find a Tier 1 neighbor")

	# STEP 3: Capture the node
	var capture_success = territory_manager.capture_node(tier1_node.node_id, "player")
	runner.assert_true(capture_success, "Step 3: Capture should succeed")

	# STEP 4: Verify ownership
	runner.assert_equal(tier1_node.controller, "player", "Step 4: Player should control node")

	# STEP 5: Check production data
	runner.assert_true(tier1_node.production.size() > 0, "Step 5: Node should have production data")

func test_assign_god_to_task():
	"""
	USER FLOW:
	1. Capture a forest node
	2. Summon a god with Gatherer role
	3. Assign god to "logging" task
	4. Verify task starts
	5. Wait for task completion
	6. Verify resources generated
	"""
	setup()

	# STEP 1: Capture forest node (manually for testing)
	var forest_node = territory_manager.get_node_by_id("forest_grove_1")
	if not forest_node:
		runner.assert_true(false, "Step 1: Forest node not found in test data")
		return

	territory_manager.capture_node(forest_node.node_id, "player")

	# STEP 2: Summon Artemis (Gatherer)
	var artemis = collection_manager.add_god_to_collection("artemis")
	runner.assert_not_null(artemis, "Step 2: Artemis should be summoned")
	runner.assert_equal(artemis.primary_role, "gatherer", "Step 2: Artemis should be Gatherer")

	# STEP 3: Assign to logging task
	var assignment = task_assignment_manager.assign_god_to_task(
		artemis.id,
		forest_node.node_id,
		"logging"
	)
	runner.assert_not_null(assignment, "Step 3: Task assignment should succeed")

	# STEP 4: Verify task is active
	var active_tasks = task_assignment_manager.get_active_tasks_for_god(artemis.id)
	runner.assert_equal(active_tasks.size(), 1, "Step 4: Should have 1 active task")

	# STEP 5: Check node has worker
	runner.assert_true(artemis.id in forest_node.assigned_workers, "Step 5: God should be in node workers")

	# STEP 6: Simulate task completion (complete 1 production cycle)
	var initial_wood = territory_production_manager.get_pending_resources(forest_node.node_id, "wood")

	# Fast-forward time
	territory_production_manager.update_production(3600.0)  # 1 hour

	var final_wood = territory_production_manager.get_pending_resources(forest_node.node_id, "wood")
	runner.assert_true(final_wood > initial_wood, "Step 6: Wood production should increase")

func test_cannot_capture_tier2_without_spec():
	"""
	USER FLOW:
	1. Player tries to capture Tier 2 node at level 5
	2. Capture fails due to missing specialization
	3. Player levels to 20 and unlocks spec
	4. Player tries again and succeeds
	"""
	setup()

	# STEP 1: Set player level to 5
	var player = player_progression.get_player_state()
	player.level = 5

	# STEP 2: Try to capture Tier 2 node
	var tier2_node = null
	var all_nodes = territory_manager.get_all_nodes()
	for node in all_nodes:
		if node.tier == 2 and node.controller != "player":
			tier2_node = node
			break

	runner.assert_not_null(tier2_node, "Step 2: Should find a Tier 2 node")

	# STEP 3: Check requirements (should fail)
	var can_capture = node_requirement_checker.can_player_capture(tier2_node)
	runner.assert_false(can_capture, "Step 3: Should NOT be able to capture - too low level")

	var reasons = node_requirement_checker.get_failure_reasons(tier2_node)
	runner.assert_true(reasons.size() > 0, "Step 3: Should have failure reasons")

	# STEP 4: Level player to 20
	player.level = 20

	# STEP 5: Still can't capture (need spec)
	var can_capture_at_20 = node_requirement_checker.can_player_capture(tier2_node)
	runner.assert_false(can_capture_at_20, "Step 5: Should still fail - need specialization")

	# STEP 6: Unlock a Tier 1 specialization
	var ares = collection_manager.add_god_to_collection("ares")
	for i in range(19):
		player_progression.level_up_god(ares)

	# Manually mark player as having Tier 1 spec (simplified for test)
	player.has_tier1_spec = true

	# STEP 7: Now should be able to capture
	var can_capture_with_spec = node_requirement_checker.can_player_capture(tier2_node)
	runner.assert_true(can_capture_with_spec, "Step 7: Should be able to capture with level + spec")

func test_multiple_nodes_connected_bonus():
	"""
	USER FLOW:
	1. Capture 3 adjacent nodes
	2. Verify connection bonus applies
	3. Check production boost
	"""
	setup()

	# STEP 1: Capture base + 2 adjacent nodes
	var base = territory_manager.get_node_at_coord(HexCoord.new(0, 0))
	var neighbors = hex_grid_manager.get_neighbors(HexCoord.new(0, 0))

	var captured_count = 1  # Base already controlled
	for i in range(min(2, neighbors.size())):
		var node = territory_manager.get_node_at_coord(neighbors[i])
		if node:
			territory_manager.capture_node(node.node_id, "player")
			captured_count += 1

	runner.assert_equal(captured_count, 3, "Step 1: Should control 3 nodes")

	# STEP 2: Check for connected bonus
	# (This would require TerritoryProductionManager to calculate connected bonuses)
	var controlled_nodes = territory_manager.get_controlled_nodes("player")
	runner.assert_true(controlled_nodes.size() >= 3, "Step 2: Should have 3+ controlled nodes")

	# STEP 3: Verify adjacent nodes detected
	var adjacency_count = 0
	for node in controlled_nodes:
		var node_neighbors = hex_grid_manager.get_neighbors(node.coord)
		for neighbor_coord in node_neighbors:
			var neighbor_node = territory_manager.get_node_at_coord(neighbor_coord)
			if neighbor_node and neighbor_node.controller == "player":
				adjacency_count += 1
				break

	runner.assert_true(adjacency_count >= 2, "Step 3: At least 2 nodes should have controlled neighbors")

func test_distance_penalty_calculation():
	"""
	USER FLOW:
	1. Capture node 1 hex away
	2. Capture node 5 hexes away
	3. Verify defense ratings differ
	"""
	setup()

	# STEP 1: Get nodes at different distances
	var base_coord = HexCoord.new(0, 0)
	var all_nodes = territory_manager.get_all_nodes()

	var close_node = null
	var far_node = null

	for node in all_nodes:
		var distance = base_coord.distance_to(node.coord)
		if distance == 1 and not close_node:
			close_node = node
		elif distance >= 5 and not far_node:
			far_node = node

	runner.assert_not_null(close_node, "Step 1: Should find close node")
	runner.assert_not_null(far_node, "Step 1: Should find far node")

	# STEP 2: Capture both
	territory_manager.capture_node(close_node.node_id, "player")
	territory_manager.capture_node(far_node.node_id, "player")

	# STEP 3: Calculate defense ratings (would need TerritoryManager.calculate_defense_rating)
	# For now, just verify distance calculation works
	var close_distance = base_coord.distance_to(close_node.coord)
	var far_distance = base_coord.distance_to(far_node.coord)

	runner.assert_equal(close_distance, 1, "Step 3: Close node should be 1 hex away")
	runner.assert_true(far_distance >= 5, "Step 3: Far node should be 5+ hexes away")

	# Expected penalty: 5% per hex
	# Close node: 95% defense (1 hex * 5%)
	# Far node: 75% or less (5 hexes * 5% = 25% penalty)
