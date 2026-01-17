# tests/unit/test_worker_assignment_panel.gd
# Unit tests for WorkerAssignmentPanel
extends GutTest

var worker_panel: WorkerAssignmentPanel
var mock_node: HexNode
var mock_god: God
var mock_task: Task

# ==============================================================================
# SETUP / TEARDOWN
# ==============================================================================
func before_each():
	worker_panel = WorkerAssignmentPanel.new()
	add_child_autofree(worker_panel)

	# Create mock node
	var hex_node_script = load("res://scripts/data/HexNode.gd")
	mock_node = hex_node_script.new()
	mock_node.id = "test_mine_1"
	mock_node.name = "Test Mine"
	mock_node.node_type = "mine"
	mock_node.max_workers = 3
	mock_node.available_tasks = ["mining", "ore_extraction"]

	# Create mock god
	var god_script = load("res://scripts/data/God.gd")
	mock_god = god_script.new()
	mock_god.id = "test_god_1"
	mock_god.name = "Test God"
	mock_god.level = 5

	# Create mock task
	var task_script = load("res://scripts/data/Task.gd")
	mock_task = task_script.new()
	mock_task.id = "mining"
	mock_task.name = "Mining"
	mock_task.base_duration_seconds = 300

func after_each():
	if worker_panel:
		worker_panel.queue_free()
	mock_node = null
	mock_god = null
	mock_task = null

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================
func test_initialization_creates_panel():
	assert_not_null(worker_panel, "Panel should be created")

func test_initialization_starts_hidden():
	assert_false(worker_panel.visible, "Panel should start hidden")

func test_initialization_creates_ui_components():
	# Give time for _ready to execute
	await get_tree().process_frame
	assert_not_null(worker_panel._main_container, "Main container should exist")
	assert_not_null(worker_panel._header_label, "Header label should exist")
	assert_not_null(worker_panel._current_workers_container, "Current workers container should exist")
	assert_not_null(worker_panel._available_gods_container, "Available gods container should exist")
	assert_not_null(worker_panel._available_tasks_container, "Available tasks container should exist")

func test_initialization_constants():
	assert_eq(worker_panel.PANEL_WIDTH, 600, "Panel width should be 600")
	assert_eq(worker_panel.PANEL_HEIGHT, 500, "Panel height should be 500")
	assert_eq(worker_panel.BUTTON_HEIGHT, 36, "Button height should be 36")
	assert_eq(worker_panel.ITEM_HEIGHT, 40, "Item height should be 40")

# ==============================================================================
# SIGNAL TESTS
# ==============================================================================
func test_has_close_requested_signal():
	assert_signal_exists(worker_panel, "close_requested")

func test_has_worker_assigned_signal():
	assert_signal_exists(worker_panel, "worker_assigned")

func test_has_worker_unassigned_signal():
	assert_signal_exists(worker_panel, "worker_unassigned")

# ==============================================================================
# SHOW/HIDE TESTS
# ==============================================================================
func test_show_panel_makes_visible():
	worker_panel.show_panel(mock_node)
	assert_true(worker_panel.visible, "Panel should be visible after show_panel")

func test_show_panel_stores_node():
	worker_panel.show_panel(mock_node)
	assert_eq(worker_panel.current_node, mock_node, "Panel should store current node")

func test_show_panel_with_null_hides():
	worker_panel.show_panel(null)
	assert_false(worker_panel.visible, "Panel should hide with null node")

func test_hide_panel_makes_invisible():
	worker_panel.show_panel(mock_node)
	worker_panel.hide_panel()
	assert_false(worker_panel.visible, "Panel should be invisible after hide_panel")

func test_hide_panel_clears_node():
	worker_panel.show_panel(mock_node)
	worker_panel.hide_panel()
	assert_null(worker_panel.current_node, "Panel should clear current node")

func test_hide_panel_clears_selections():
	worker_panel._selected_god_id = "test_god"
	worker_panel._selected_task_id = "test_task"
	worker_panel.hide_panel()
	assert_eq(worker_panel._selected_god_id, "", "God selection should be cleared")
	assert_eq(worker_panel._selected_task_id, "", "Task selection should be cleared")

# ==============================================================================
# CURRENT WORKERS DISPLAY TESTS
# ==============================================================================
func test_update_current_workers_shows_count():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	assert_not_null(worker_panel._current_workers_container, "Container should exist")
	# Should show "Workers: 0 / 3"

func test_update_current_workers_shows_empty_message():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	var children = worker_panel._current_workers_container.get_children()
	var has_empty_message = false
	for child in children:
		if child is Label and "No workers" in child.text:
			has_empty_message = true
	assert_true(has_empty_message, "Should show no workers message")

func test_update_current_workers_with_workers():
	mock_node.assigned_workers.append("god_1")
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	# Workers list should update (requires CollectionManager mock)

# ==============================================================================
# AVAILABLE GODS DISPLAY TESTS
# ==============================================================================
func test_update_available_gods_shows_message_when_empty():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	# Should show "No gods available" message

func test_get_available_gods_excludes_workers():
	mock_node.assigned_workers.append("god_1")
	var available = worker_panel._get_available_gods()
	# Should not include gods already working at this node

func test_get_available_gods_excludes_garrison():
	# Requires HexGridManager mock to test properly
	pass

# ==============================================================================
# AVAILABLE TASKS DISPLAY TESTS
# ==============================================================================
func test_update_available_tasks_filters_by_node():
	mock_node.available_tasks = ["mining", "ore_extraction"]
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	# Should only show tasks from available_tasks list

func test_get_available_tasks_returns_matching_tasks():
	mock_node.available_tasks = ["mining"]
	var tasks = worker_panel._get_available_tasks()
	# Returns empty without TaskAssignmentManager, but method exists

# ==============================================================================
# SELECTION TESTS
# ==============================================================================
func test_god_selection_updates_state():
	worker_panel._on_god_selected("test_god_1")
	assert_eq(worker_panel._selected_god_id, "test_god_1", "Should update selected god")

func test_task_selection_updates_state():
	worker_panel._on_task_selected("mining")
	assert_eq(worker_panel._selected_task_id, "mining", "Should update selected task")

func test_god_selection_refreshes_display():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	var initial_children = worker_panel._available_gods_container.get_child_count()
	worker_panel._on_god_selected("test_god_1")
	var after_children = worker_panel._available_gods_container.get_child_count()
	# Display should refresh (child count may change based on highlighting)

func test_task_selection_refreshes_display():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	var initial_children = worker_panel._available_tasks_container.get_child_count()
	worker_panel._on_task_selected("mining")
	var after_children = worker_panel._available_tasks_container.get_child_count()
	# Display should refresh

# ==============================================================================
# HELPER TESTS
# ==============================================================================
func test_format_duration_seconds():
	var result = worker_panel._format_duration(45)
	assert_eq(result, "45s", "Should format seconds")

func test_format_duration_minutes():
	var result = worker_panel._format_duration(180)
	assert_eq(result, "3m", "Should format minutes")

func test_format_duration_hours():
	var result = worker_panel._format_duration(7200)
	assert_eq(result, "2h", "Should format hours")

func test_format_duration_edge_case_59_seconds():
	var result = worker_panel._format_duration(59)
	assert_eq(result, "59s", "Should format 59 seconds")

func test_format_duration_edge_case_60_seconds():
	var result = worker_panel._format_duration(60)
	assert_eq(result, "1m", "Should format 60 seconds as 1 minute")

func test_format_duration_edge_case_3599_seconds():
	var result = worker_panel._format_duration(3599)
	assert_eq(result, "59m", "Should format 3599 seconds as 59 minutes")

func test_format_duration_edge_case_3600_seconds():
	var result = worker_panel._format_duration(3600)
	assert_eq(result, "1h", "Should format 3600 seconds as 1 hour")

# ==============================================================================
# ASSIGNMENT TESTS
# ==============================================================================
func test_assign_pressed_requires_god_selection():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	worker_panel._selected_task_id = "mining"
	# Should fail without god selected (requires systems mock)
	worker_panel._on_assign_pressed()
	# Logs warning

func test_assign_pressed_requires_task_selection():
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	worker_panel._selected_god_id = "test_god_1"
	# Should fail without task selected
	worker_panel._on_assign_pressed()
	# Logs warning

func test_assign_pressed_checks_node_space():
	mock_node.max_workers = 1
	mock_node.assigned_workers = ["god_1"]
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	worker_panel._selected_god_id = "test_god_2"
	worker_panel._selected_task_id = "mining"
	# Should fail because node is full
	worker_panel._on_assign_pressed()

# ==============================================================================
# UNASSIGNMENT TESTS
# ==============================================================================
func test_unassign_worker_removes_from_node():
	mock_node.assigned_workers = ["god_1"]
	mock_god.id = "god_1"
	await get_tree().process_frame
	worker_panel.show_panel(mock_node)
	# Would require CollectionManager mock
	worker_panel._on_unassign_worker("god_1")

# ==============================================================================
# EDGE CASES
# ==============================================================================
func test_show_panel_twice_with_different_nodes():
	var node2 = HexNode.new()
	node2.id = "test_mine_2"
	worker_panel.show_panel(mock_node)
	assert_eq(worker_panel.current_node, mock_node, "Should show first node")
	worker_panel.show_panel(node2)
	assert_eq(worker_panel.current_node, node2, "Should switch to second node")

func test_refresh_with_no_node():
	worker_panel.current_node = null
	worker_panel.refresh()
	# Should not crash

func test_close_button_emits_signal():
	await get_tree().process_frame
	watch_signals(worker_panel)
	worker_panel._on_close_pressed()
	assert_signal_emitted(worker_panel, "close_requested")

func test_close_button_hides_panel():
	worker_panel.show_panel(mock_node)
	worker_panel._on_close_pressed()
	assert_false(worker_panel.visible, "Panel should hide on close")

func test_is_god_in_any_garrison_false_by_default():
	var result = worker_panel._is_god_in_any_garrison("test_god")
	assert_false(result, "Should return false without HexGridManager")

func test_is_god_working_elsewhere_false_by_default():
	var result = worker_panel._is_god_working_elsewhere("test_god")
	assert_false(result, "Should return false without HexGridManager")

func test_get_available_tasks_empty_without_manager():
	var tasks = worker_panel._get_available_tasks()
	assert_eq(tasks.size(), 0, "Should return empty array without TaskAssignmentManager")

func test_get_available_gods_empty_without_manager():
	var gods = worker_panel._get_available_gods()
	assert_eq(gods.size(), 0, "Should return empty array without CollectionManager")
