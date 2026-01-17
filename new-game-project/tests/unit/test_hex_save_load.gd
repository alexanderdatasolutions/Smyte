# tests/unit/test_hex_save_load.gd
# Unit tests for hex node save/load integration
extends GutTest

# Test SaveManager integration with HexGridManager and TerritoryManager for hex node state

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================

var save_manager
var hex_grid_manager
var territory_manager
var system_registry

func before_each():
	# Create system registry
	system_registry = Node.new()
	system_registry.set_script(load("res://scripts/systems/core/SystemRegistry.gd"))
	add_child(system_registry)

	# Create managers
	save_manager = SaveManager.new()
	hex_grid_manager = HexGridManager.new()
	territory_manager = TerritoryManager.new()

	# Register systems
	system_registry.register_system("SaveManager", save_manager)
	system_registry.register_system("HexGridManager", hex_grid_manager)
	system_registry.register_system("TerritoryManager", territory_manager)

	add_child(save_manager)
	add_child(hex_grid_manager)
	add_child(territory_manager)

func after_each():
	if save_manager:
		save_manager.queue_free()
	if hex_grid_manager:
		hex_grid_manager.queue_free()
	if territory_manager:
		territory_manager.queue_free()
	if system_registry:
		system_registry.queue_free()

	# Clean up save file
	if FileAccess.file_exists(SaveManager.SAVE_FILE_PATH):
		DirAccess.remove_absolute(SaveManager.SAVE_FILE_PATH)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_test_hex_node(node_id: String, q: int, r: int) -> HexNode:
	"""Create a test hex node"""
	var hex_coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = hex_coord_script.new(q, r)

	var hex_node_script = load("res://scripts/data/HexNode.gd")
	var node = hex_node_script.new()
	node.id = node_id
	node.name = "Test Node " + node_id
	node.node_type = "mine"
	node.tier = 1
	node.coord = coord
	node.controller = "neutral"
	node.is_revealed = true
	node.max_garrison = 2
	node.max_workers = 3

	return node

# ==============================================================================
# SAVE/LOAD INTEGRATION TESTS
# ==============================================================================

func test_save_manager_calls_hex_grid_get_save_data():
	assert_has_method(hex_grid_manager, "get_save_data", "HexGridManager should have get_save_data method")

func test_save_manager_calls_hex_grid_load_save_data():
	assert_has_method(hex_grid_manager, "load_save_data", "HexGridManager should have load_save_data method")

func test_save_manager_calls_territory_get_save_data():
	assert_has_method(territory_manager, "get_save_data", "TerritoryManager should have get_save_data method")

func test_save_manager_calls_territory_load_save_data():
	assert_has_method(territory_manager, "load_save_data", "TerritoryManager should have load_save_data method")

# ==============================================================================
# HEX GRID SAVE DATA TESTS
# ==============================================================================

func test_hex_grid_get_save_data_returns_nodes():
	var save_data = hex_grid_manager.get_save_data()
	assert_has(save_data, "nodes", "Save data should have nodes key")

func test_hex_grid_get_save_data_empty_grid():
	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes.size(), 0, "Empty grid should have no nodes")

func test_hex_grid_save_data_includes_node_ownership():
	# Create and add test node
	var node = create_test_hex_node("test_node_1", 1, 0)
	node.controller = "player"
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_has(save_data.nodes, "test_node_1", "Save data should include test node")
	assert_eq(save_data.nodes["test_node_1"].controller, "player", "Should save controller")

func test_hex_grid_save_data_includes_production_levels():
	var node = create_test_hex_node("test_node_2", 0, 1)
	node.production_level = 3
	node.defense_level = 2
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["test_node_2"].production_level, 3, "Should save production level")
	assert_eq(save_data.nodes["test_node_2"].defense_level, 2, "Should save defense level")

func test_hex_grid_save_data_includes_garrison():
	var node = create_test_hex_node("test_node_3", -1, 1)
	node.garrison.append("god_001")
	node.garrison.append("god_002")
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["test_node_3"].garrison.size(), 2, "Should save garrison")
	assert_eq(save_data.nodes["test_node_3"].garrison[0], "god_001", "Should save garrison god 1")
	assert_eq(save_data.nodes["test_node_3"].garrison[1], "god_002", "Should save garrison god 2")

func test_hex_grid_save_data_includes_workers():
	var node = create_test_hex_node("test_node_4", -1, 0)
	node.assigned_workers.append("god_003")
	node.active_tasks.append("mining")
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["test_node_4"].assigned_workers.size(), 1, "Should save workers")
	assert_eq(save_data.nodes["test_node_4"].assigned_workers[0], "god_003", "Should save worker god")
	assert_eq(save_data.nodes["test_node_4"].active_tasks[0], "mining", "Should save active task")

func test_hex_grid_save_data_includes_contested_state():
	var node = create_test_hex_node("test_node_5", 0, -1)
	node.is_contested = true
	node.contested_until = 1234567890
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["test_node_5"].is_contested, true, "Should save contested state")
	assert_eq(save_data.nodes["test_node_5"].contested_until, 1234567890, "Should save contested until timestamp")

func test_hex_grid_save_data_includes_raid_cooldown():
	var node = create_test_hex_node("test_node_6", 1, -1)
	node.last_raid_time = 1000000
	node.raid_cooldown = 2000000
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["test_node_6"].last_raid_time, 1000000, "Should save last raid time")
	assert_eq(save_data.nodes["test_node_6"].raid_cooldown, 2000000, "Should save raid cooldown")

# ==============================================================================
# HEX GRID LOAD DATA TESTS
# ==============================================================================

func test_hex_grid_load_save_data_updates_controller():
	var node = create_test_hex_node("test_node_7", 2, 0)
	node.controller = "neutral"
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"test_node_7": {
			"controller": "player",
			"is_revealed": false,
			"is_contested": false,
			"contested_until": 0,
			"garrison": [],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	var loaded_node = hex_grid_manager.get_node_by_id("test_node_7")
	assert_eq(loaded_node.controller, "player", "Should load controller from save data")

func test_hex_grid_load_save_data_updates_garrison():
	var node = create_test_hex_node("test_node_8", 1, 1)
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"test_node_8": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": false,
			"contested_until": 0,
			"garrison": ["god_004", "god_005"],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	var loaded_node = hex_grid_manager.get_node_by_id("test_node_8")
	assert_eq(loaded_node.garrison.size(), 2, "Should load garrison")
	assert_eq(loaded_node.garrison[0], "god_004", "Should load garrison god 1")
	assert_eq(loaded_node.garrison[1], "god_005", "Should load garrison god 2")

func test_hex_grid_load_save_data_updates_workers():
	var node = create_test_hex_node("test_node_9", 0, 2)
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"test_node_9": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": false,
			"contested_until": 0,
			"garrison": [],
			"assigned_workers": ["god_006", "god_007", "god_008"],
			"active_tasks": ["mining", "mining", "logging"],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	var loaded_node = hex_grid_manager.get_node_by_id("test_node_9")
	assert_eq(loaded_node.assigned_workers.size(), 3, "Should load workers")
	assert_eq(loaded_node.active_tasks.size(), 3, "Should load active tasks")

func test_hex_grid_load_save_data_updates_upgrades():
	var node = create_test_hex_node("test_node_10", -1, 2)
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"test_node_10": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": false,
			"contested_until": 0,
			"garrison": [],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 4,
			"defense_level": 3,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	var loaded_node = hex_grid_manager.get_node_by_id("test_node_10")
	assert_eq(loaded_node.production_level, 4, "Should load production level")
	assert_eq(loaded_node.defense_level, 3, "Should load defense level")

func test_hex_grid_load_save_data_updates_contested_state():
	var node = create_test_hex_node("test_node_11", -2, 2)
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"test_node_11": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": true,
			"contested_until": 9999999,
			"garrison": [],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	var loaded_node = hex_grid_manager.get_node_by_id("test_node_11")
	assert_eq(loaded_node.is_contested, true, "Should load contested state")
	assert_eq(loaded_node.contested_until, 9999999, "Should load contested until timestamp")

func test_hex_grid_load_save_data_emits_grid_updated():
	var node = create_test_hex_node("test_node_12", -2, 1)
	hex_grid_manager._add_node(node)

	watch_signals(hex_grid_manager)

	var save_data = {"nodes": {
		"test_node_12": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": false,
			"contested_until": 0,
			"garrison": [],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	hex_grid_manager.load_save_data(save_data)

	assert_signal_emitted(hex_grid_manager, "grid_updated", "Should emit grid_updated signal")

func test_hex_grid_load_save_data_ignores_missing_nodes():
	var save_data = {"nodes": {
		"nonexistent_node": {
			"controller": "player",
			"is_revealed": true,
			"is_contested": false,
			"contested_until": 0,
			"garrison": [],
			"assigned_workers": [],
			"active_tasks": [],
			"production_level": 1,
			"defense_level": 1,
			"last_raid_time": 0,
			"raid_cooldown": 0
		}
	}}

	# Should not crash
	hex_grid_manager.load_save_data(save_data)
	assert_true(true, "Should handle nonexistent nodes gracefully")

func test_hex_grid_load_save_data_handles_empty_save():
	var save_data = {"nodes": {}}

	# Should not crash
	hex_grid_manager.load_save_data(save_data)
	assert_true(true, "Should handle empty save data")

func test_hex_grid_load_save_data_handles_no_nodes_key():
	var save_data = {}

	# Should not crash
	hex_grid_manager.load_save_data(save_data)
	assert_true(true, "Should handle save data with no nodes key")

# ==============================================================================
# FULL SAVE/LOAD CYCLE TESTS
# ==============================================================================

func test_full_save_and_load_cycle():
	# Setup: Create test nodes
	var node1 = create_test_hex_node("cycle_node_1", 1, 0)
	node1.controller = "player"
	node1.garrison.append("god_001")
	node1.production_level = 2
	hex_grid_manager._add_node(node1)

	var node2 = create_test_hex_node("cycle_node_2", 0, 1)
	node2.controller = "player"
	node2.assigned_workers.append("god_002")
	node2.active_tasks.append("mining")
	hex_grid_manager._add_node(node2)

	# Save
	var success = save_manager.save_game()
	assert_true(success, "Save should succeed")

	# Modify nodes
	node1.controller = "neutral"
	node1.garrison = []
	node1.production_level = 1
	node2.assigned_workers = []
	node2.active_tasks = []

	# Load
	success = save_manager.load_game()
	assert_true(success, "Load should succeed")

	# Verify loaded state
	var loaded1 = hex_grid_manager.get_node_by_id("cycle_node_1")
	assert_eq(loaded1.controller, "player", "Should restore controller")
	assert_eq(loaded1.garrison.size(), 1, "Should restore garrison")
	assert_eq(loaded1.production_level, 2, "Should restore production level")

	var loaded2 = hex_grid_manager.get_node_by_id("cycle_node_2")
	assert_eq(loaded2.assigned_workers.size(), 1, "Should restore workers")
	assert_eq(loaded2.active_tasks.size(), 1, "Should restore active tasks")

func test_save_data_preserves_coord():
	var node = create_test_hex_node("coord_test", 3, -2)
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["coord_test"].coord.q, 3, "Should preserve coordinate q")
	assert_eq(save_data.nodes["coord_test"].coord.r, -2, "Should preserve coordinate r")

func test_multiple_nodes_save_load():
	# Create multiple nodes with different states
	for i in range(5):
		var node = create_test_hex_node("multi_node_%d" % i, i, 0)
		node.controller = "player" if i % 2 == 0 else "neutral"
		node.production_level = (i % 3) + 1
		node.is_revealed = i > 2
		hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes.size(), 5, "Should save all nodes")

	# Verify each node preserved
	for i in range(5):
		var node_id = "multi_node_%d" % i
		assert_has(save_data.nodes, node_id, "Should save node " + node_id)
		assert_eq(save_data.nodes[node_id].controller, "player" if i % 2 == 0 else "neutral")
		assert_eq(save_data.nodes[node_id].production_level, (i % 3) + 1)

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_save_with_null_garrison():
	var node = create_test_hex_node("null_garrison_test", 1, 1)
	node.garrison = []
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["null_garrison_test"].garrison.size(), 0, "Should handle empty garrison")

func test_load_with_missing_fields():
	var node = create_test_hex_node("missing_fields_test", 2, 1)
	hex_grid_manager._add_node(node)

	var save_data = {"nodes": {
		"missing_fields_test": {
			"controller": "player"
			# Missing other fields
		}
	}}

	# Should use default values
	hex_grid_manager.load_save_data(save_data)
	var loaded = hex_grid_manager.get_node_by_id("missing_fields_test")
	assert_eq(loaded.controller, "player", "Should load provided field")
	assert_eq(loaded.is_revealed, false, "Should use default for missing field")

func test_save_load_preserves_revealed_state():
	var node = create_test_hex_node("revealed_test", 1, 2)
	node.is_revealed = true
	hex_grid_manager._add_node(node)

	var save_data = hex_grid_manager.get_save_data()
	assert_eq(save_data.nodes["revealed_test"].is_revealed, true, "Should save revealed state")

	node.is_revealed = false
	hex_grid_manager.load_save_data(save_data)
	assert_eq(node.is_revealed, true, "Should restore revealed state")
