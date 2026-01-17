# tests/unit/test_node_requirements_panel.gd
extends GutTest

"""
Unit tests for NodeRequirementsPanel UI component
Tests display of unlock requirements with met/unmet status
"""

# ==============================================================================
# TEST SETUP
# ==============================================================================

var panel: NodeRequirementsPanel
var mock_checker
var mock_node: HexNode

func before_each():
	panel = NodeRequirementsPanel.new()
	mock_checker = double(NodeRequirementChecker).new()
	mock_node = _create_test_node()

	# Inject mock checker
	panel.node_requirement_checker = mock_checker

	add_child_autofree(panel)

func after_each():
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	mock_checker = null
	mock_node = null

# ==============================================================================
# HELPER METHODS
# ==============================================================================

func _create_test_node() -> HexNode:
	"""Create a test hex node"""
	var script = load("res://scripts/data/HexNode.gd")
	var node = script.new()
	node.id = "test_node_1"
	node.name = "Test Node"
	node.node_type = "mine"
	node.tier = 2
	node.controller = "neutral"
	node.capture_power_required = 5000
	node.unlock_requirements = NodeRequirements.create_tier2()
	return node

func _create_requirement_status(level_met: bool, spec_met: bool, power_met: bool, tier: int = 1, role: String = "") -> Dictionary:
	"""Create a mock requirement status dictionary"""
	return {
		"level": {
			"required": 10,
			"current": 10 if level_met else 5,
			"met": level_met
		},
		"specialization": {
			"tier_required": tier,
			"role_required": role,
			"met": spec_met
		},
		"power": {
			"required": 5000,
			"current": 5000 if power_met else 2000,
			"met": power_met
		},
		"can_capture": level_met and spec_met and power_met
	}

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_panel_initializes_hidden():
	assert_false(panel.visible, "Panel should start hidden")

func test_panel_has_correct_size():
	assert_eq(panel.custom_minimum_size.x, 400, "Panel width should be 400")
	assert_eq(panel.custom_minimum_size.y, 350, "Panel height should be 350")

func test_panel_has_null_node_initially():
	assert_null(panel.current_node, "Panel should start with null node")

func test_constants_defined():
	assert_eq(NodeRequirementsPanel.PANEL_WIDTH, 400)
	assert_eq(NodeRequirementsPanel.PANEL_HEIGHT, 350)
	assert_eq(NodeRequirementsPanel.REQUIREMENT_ROW_HEIGHT, 40)
	assert_eq(NodeRequirementsPanel.BUTTON_HEIGHT, 40)

func test_icon_constants_defined():
	assert_eq(NodeRequirementsPanel.ICON_MET, "✓")
	assert_eq(NodeRequirementsPanel.ICON_UNMET, "✗")

# ==============================================================================
# SHOW/HIDE TESTS
# ==============================================================================

func test_show_requirements_makes_visible():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	panel.show_requirements(mock_node)
	assert_true(panel.visible, "Panel should be visible after show_requirements")

func test_show_requirements_sets_current_node():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	panel.show_requirements(mock_node)
	assert_eq(panel.current_node, mock_node, "current_node should be set")

func test_hide_panel_makes_invisible():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	panel.show_requirements(mock_node)
	panel.hide_panel()
	assert_false(panel.visible, "Panel should be hidden")

func test_hide_panel_clears_current_node():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	panel.show_requirements(mock_node)
	panel.hide_panel()
	assert_null(panel.current_node, "current_node should be cleared")

func test_show_requirements_with_null_node():
	panel.show_requirements(null)
	assert_false(panel.visible, "Panel should remain hidden with null node")

# ==============================================================================
# SIGNAL TESTS
# ==============================================================================

func test_close_signal_exists():
	assert_has_signal(panel, "close_requested")

func test_close_button_emits_signal():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	panel.show_requirements(mock_node)
	watch_signals(panel)

	# Find and click close button
	var close_button = _find_button_with_text(panel, "CLOSE")
	assert_not_null(close_button, "Close button should exist")

	close_button.pressed.emit()
	assert_signal_emitted(panel, "close_requested")

# ==============================================================================
# REQUIREMENT DISPLAY TESTS
# ==============================================================================

func test_displays_level_requirement_met():
	var status = _create_requirement_status(true, true, true)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	# Check that requirement row was created
	var rows = _get_requirement_rows(panel)
	assert_gt(rows.size(), 0, "Should have at least one requirement row")

	# Check for green checkmark in level row
	var level_row = rows[0]
	var icon_label = level_row.get_child(0) as Label
	assert_eq(icon_label.text, "✓", "Level requirement should show checkmark")

func test_displays_level_requirement_unmet():
	var status = _create_requirement_status(false, true, true)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return(["Player Level 10 (currently 5)"])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	var level_row = rows[0]
	var icon_label = level_row.get_child(0) as Label
	assert_eq(icon_label.text, "✗", "Level requirement should show X")

func test_displays_specialization_requirement_met():
	var status = _create_requirement_status(true, true, true, 1)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	assert_gte(rows.size(), 2, "Should have at least 2 requirement rows")

	var spec_row = rows[1]
	var icon_label = spec_row.get_child(0) as Label
	assert_eq(icon_label.text, "✓", "Spec requirement should show checkmark")

func test_displays_specialization_requirement_unmet():
	var status = _create_requirement_status(true, false, true, 1)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return(["Any Specialization Tier 1"])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	var spec_row = rows[1]
	var icon_label = spec_row.get_child(0) as Label
	assert_eq(icon_label.text, "✗", "Spec requirement should show X")

func test_displays_role_specific_specialization():
	var status = _create_requirement_status(true, true, true, 2, "gatherer")
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	var spec_row = rows[1]
	var text_label = spec_row.get_child(1) as Label
	assert_string_contains(text_label.text, "Gatherer", "Should show role name")
	assert_string_contains(text_label.text, "Tier 2", "Should show tier")

func test_displays_power_requirement_met():
	var status = _create_requirement_status(true, true, true)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	assert_gte(rows.size(), 3, "Should have at least 3 requirement rows")

	var power_row = rows[2]
	var icon_label = power_row.get_child(0) as Label
	assert_eq(icon_label.text, "✓", "Power requirement should show checkmark")

func test_displays_power_requirement_unmet():
	var status = _create_requirement_status(true, true, false)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return(["Combat Power 5000 (currently 2000)"])

	panel.show_requirements(mock_node)

	var rows = _get_requirement_rows(panel)
	var power_row = rows[2]
	var icon_label = power_row.get_child(0) as Label
	assert_eq(icon_label.text, "✗", "Power requirement should show X")

# ==============================================================================
# EXPLANATION TESTS
# ==============================================================================

func test_displays_all_met_explanation():
	var status = _create_requirement_status(true, true, true)
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	var explanation = _get_explanation_label(panel)
	assert_not_null(explanation, "Explanation label should exist")
	assert_string_contains(explanation.text, "All requirements met", "Should show success message")

func test_displays_missing_requirements_explanation():
	var status = _create_requirement_status(false, false, false)
	var missing = [
		"Player Level 10 (currently 5)",
		"Any Specialization Tier 1",
		"Combat Power 5000 (currently 2000)"
	]
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return(missing)

	panel.show_requirements(mock_node)

	var explanation = _get_explanation_label(panel)
	assert_not_null(explanation, "Explanation label should exist")
	assert_string_contains(explanation.text, "Player Level 10", "Should mention level requirement")
	assert_string_contains(explanation.text, "Specialization Tier 1", "Should mention spec requirement")
	assert_string_contains(explanation.text, "Combat Power 5000", "Should mention power requirement")

func test_explanation_shows_bullet_points():
	var status = _create_requirement_status(false, false, true)
	var missing = [
		"Player Level 10 (currently 5)",
		"Any Specialization Tier 1"
	]
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return(missing)

	panel.show_requirements(mock_node)

	var explanation = _get_explanation_label(panel)
	assert_string_contains(explanation.text, "•", "Should use bullet points")

# ==============================================================================
# REFRESH TESTS
# ==============================================================================

func test_refresh_updates_display():
	var status1 = _create_requirement_status(false, false, false)
	stub(mock_checker, "get_requirement_status").to_return(status1)
	stub(mock_checker, "get_missing_requirements").to_return(["Player Level 10 (currently 5)"])

	panel.show_requirements(mock_node)

	var rows_before = _get_requirement_rows(panel)
	var level_row_before = rows_before[0]
	var icon_before = level_row_before.get_child(0) as Label
	assert_eq(icon_before.text, "✗", "Should show X initially")

	# Update status to met
	var status2 = _create_requirement_status(true, true, true)
	stub(mock_checker, "get_requirement_status").to_return(status2)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.refresh()

	var rows_after = _get_requirement_rows(panel)
	var level_row_after = rows_after[0]
	var icon_after = level_row_after.get_child(0) as Label
	assert_eq(icon_after.text, "✓", "Should show checkmark after refresh")

func test_refresh_with_no_node():
	panel.refresh()
	# Should not crash

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_show_requirements_twice():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)
	panel.show_requirements(mock_node)

	assert_true(panel.visible, "Panel should still be visible")
	assert_eq(panel.current_node, mock_node, "current_node should still be set")

func test_switch_nodes():
	stub(mock_checker, "get_requirement_status").to_return(_create_requirement_status(true, true, true))
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(mock_node)

	var node2 = _create_test_node()
	node2.id = "test_node_2"
	node2.name = "Test Node 2"

	panel.show_requirements(node2)

	assert_eq(panel.current_node, node2, "current_node should be updated")

func test_no_specialization_requirement():
	# Tier 1 node has no spec requirement
	var tier1_node = _create_test_node()
	tier1_node.tier = 1
	tier1_node.unlock_requirements = NodeRequirements.create_tier1()

	var status = _create_requirement_status(true, true, true, 0)  # tier 0 = no spec
	stub(mock_checker, "get_requirement_status").to_return(status)
	stub(mock_checker, "get_missing_requirements").to_return([])

	panel.show_requirements(tier1_node)

	# Should only show 2 rows: level and power (no spec)
	var rows = _get_requirement_rows(panel)
	assert_eq(rows.size(), 2, "Should only have 2 rows for tier 1 node")

# ==============================================================================
# HELPER METHODS FOR FINDING UI ELEMENTS
# ==============================================================================

func _find_button_with_text(node: Node, text: String) -> Button:
	"""Find a button with specific text"""
	for child in _get_all_descendants(node):
		if child is Button and child.text == text:
			return child
	return null

func _get_all_descendants(node: Node) -> Array:
	"""Get all descendants of a node"""
	var descendants = []
	for child in node.get_children():
		descendants.append(child)
		descendants.append_array(_get_all_descendants(child))
	return descendants

func _get_requirement_rows(node: Node) -> Array:
	"""Find the requirements list VBoxContainer and return its children"""
	for child in _get_all_descendants(node):
		if child is VBoxContainer:
			# Look for VBoxContainer that contains HBoxContainers (requirement rows)
			var has_requirement_rows = false
			for grandchild in child.get_children():
				if grandchild is HBoxContainer:
					has_requirement_rows = true
					break

			if has_requirement_rows:
				var rows = []
				for grandchild in child.get_children():
					if grandchild is HBoxContainer:
						rows.append(grandchild)
				return rows

	return []

func _get_explanation_label(node: Node) -> Label:
	"""Find the explanation label"""
	var vbox_found = false
	for child in _get_all_descendants(node):
		if child is VBoxContainer:
			# Look for VBoxContainer with "What You Need:" title
			for grandchild in child.get_children():
				if grandchild is Label and "What You Need" in grandchild.text:
					vbox_found = true
					# Next label should be the explanation
					var children = child.get_children()
					for i in range(children.size()):
						if children[i] == grandchild and i + 1 < children.size():
							if children[i + 1] is Label:
								return children[i + 1]

	return null
