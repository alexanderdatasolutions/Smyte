# scripts/ui/components/SpecializationTree.gd
# Visual tree container component for displaying specialization paths
# Renders nodes in a tree layout with connecting lines showing parent/child relationships
class_name SpecializationTree extends Control

# ==============================================================================
# SIGNALS
# ==============================================================================
signal node_selected(spec_id: String)
signal node_hovered(spec_id: String, tooltip_text: String)
signal node_unhovered()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const NODE_HORIZONTAL_SPACING = 160  # Space between nodes horizontally
const NODE_VERTICAL_SPACING = 180    # Space between tier rows
const CONNECTION_COLOR = Color(0.5, 0.5, 0.5, 0.8)
const CONNECTION_WIDTH = 2.0

# ==============================================================================
# PROPERTIES
# ==============================================================================
var god_data: God = null
var role_id: String = ""
var specialization_manager: SpecializationManager = null

# Internal state
var _nodes: Dictionary = {}  # spec_id -> SpecializationNode
var _node_positions: Dictionary = {}  # spec_id -> Vector2
var _connections: Array[Dictionary] = []  # [{from: spec_id, to: spec_id}]

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready():
	# Will be setup via external call
	pass

func _draw():
	"""Draw connection lines between nodes"""
	for connection in _connections:
		var from_id = connection["from"]
		var to_id = connection["to"]

		if _node_positions.has(from_id) and _node_positions.has(to_id):
			var from_pos = _node_positions[from_id]
			var to_pos = _node_positions[to_id]

			# Draw line from bottom of parent to top of child
			var start_point = from_pos + Vector2(70, 160)  # Bottom center of node (140/2 = 70)
			var end_point = to_pos + Vector2(70, 0)  # Top center of node

			draw_line(start_point, end_point, CONNECTION_COLOR, CONNECTION_WIDTH)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func setup(god: God, role: String, spec_manager: SpecializationManager):
	"""Setup the tree with god data and role filter"""
	god_data = god
	role_id = role
	specialization_manager = spec_manager

	if specialization_manager:
		_build_tree()

func refresh():
	"""Refresh the tree (e.g., after god levels up or unlocks a specialization)"""
	if specialization_manager:
		_build_tree()

func clear_tree():
	"""Clear all nodes and connections"""
	for node in _nodes.values():
		if is_instance_valid(node):
			node.queue_free()

	_nodes.clear()
	_node_positions.clear()
	_connections.clear()
	queue_redraw()

# ==============================================================================
# TREE BUILDING
# ==============================================================================

func _build_tree():
	"""Build the entire specialization tree"""
	clear_tree()

	if not specialization_manager or not god_data or role_id == "":
		return

	# Get all root specializations for this role (tier 1)
	var root_specs = specialization_manager.get_root_specializations(role_id)
	if root_specs.is_empty():
		return

	# Build tree structure starting from roots
	var tier_1_nodes: Array[GodSpecialization] = []
	var tier_2_nodes: Array[GodSpecialization] = []
	var tier_3_nodes: Array[GodSpecialization] = []

	# Collect all nodes by tier
	for root in root_specs:
		tier_1_nodes.append(root)

		# Get tier 2 children
		for tier_2_id in root.get_children_ids():
			var tier_2_spec = specialization_manager.get_specialization(tier_2_id)
			if tier_2_spec:
				tier_2_nodes.append(tier_2_spec)

				# Get tier 3 children
				for tier_3_id in tier_2_spec.get_children_ids():
					var tier_3_spec = specialization_manager.get_specialization(tier_3_id)
					if tier_3_spec:
						tier_3_nodes.append(tier_3_spec)

	# Calculate layout positions
	_calculate_layout(tier_1_nodes, tier_2_nodes, tier_3_nodes)

	# Create nodes
	_create_nodes(tier_1_nodes, tier_2_nodes, tier_3_nodes)

	# Build connection list
	_build_connections(tier_1_nodes, tier_2_nodes, tier_3_nodes)

	# Update size to fit all nodes
	_update_container_size()

	# Redraw connections
	queue_redraw()

func _calculate_layout(tier_1_nodes: Array, tier_2_nodes: Array, tier_3_nodes: Array):
	"""Calculate node positions in the tree"""
	_node_positions.clear()

	var all_tiers = [tier_1_nodes, tier_2_nodes, tier_3_nodes]

	for tier_idx in range(3):
		var tier_nodes = all_tiers[tier_idx]
		if tier_nodes.is_empty():
			continue

		var y_position = tier_idx * NODE_VERTICAL_SPACING

		# For tier 1: simple horizontal layout
		if tier_idx == 0:
			_layout_tier_horizontal(tier_nodes, y_position)
		else:
			# For tier 2 and 3: position under parents
			_layout_tier_under_parents(tier_nodes, y_position)

func _layout_tier_horizontal(nodes: Array, y_pos: float):
	"""Layout nodes horizontally"""
	var total_width = nodes.size() * NODE_HORIZONTAL_SPACING
	var start_x = 0

	for i in range(nodes.size()):
		var spec = nodes[i]
		var x_pos = start_x + (i * NODE_HORIZONTAL_SPACING)
		_node_positions[spec.id] = Vector2(x_pos, y_pos)

func _layout_tier_under_parents(nodes: Array, y_pos: float):
	"""Layout nodes under their parents"""
	# Group nodes by parent
	var parent_groups: Dictionary = {}  # parent_id -> [child_specs]

	for spec in nodes:
		var parent_id = spec.get_parent_id()
		if parent_id == "":
			continue

		if not parent_groups.has(parent_id):
			parent_groups[parent_id] = []
		parent_groups[parent_id].append(spec)

	# Position each group under its parent
	for parent_id in parent_groups:
		if not _node_positions.has(parent_id):
			continue

		var parent_pos = _node_positions[parent_id]
		var children = parent_groups[parent_id]

		# Calculate positions for children
		if children.size() == 1:
			# Single child: center under parent
			_node_positions[children[0].id] = Vector2(parent_pos.x, y_pos)
		else:
			# Multiple children: spread them out
			var children_width = (children.size() - 1) * NODE_HORIZONTAL_SPACING
			var start_x = parent_pos.x - (children_width / 2)

			for i in range(children.size()):
				var child = children[i]
				var x_pos = start_x + (i * NODE_HORIZONTAL_SPACING)
				_node_positions[child.id] = Vector2(x_pos, y_pos)

func _create_nodes(tier_1_nodes: Array, tier_2_nodes: Array, tier_3_nodes: Array):
	"""Create SpecializationNode instances for all nodes"""
	var all_nodes = tier_1_nodes + tier_2_nodes + tier_3_nodes

	for spec in all_nodes:
		var node_state = _get_node_state(spec)
		var node = _create_specialization_node(spec, node_state)

		if node and _node_positions.has(spec.id):
			node.position = _node_positions[spec.id]
			add_child(node)
			_nodes[spec.id] = node

func _create_specialization_node(spec: GodSpecialization, state: SpecializationNode.NodeState) -> SpecializationNode:
	"""Create a single SpecializationNode instance"""
	var node = SpecializationNode.new()
	node.setup(spec, god_data, state)

	# Connect signals
	node.node_selected.connect(_on_node_selected)
	node.node_hovered.connect(_on_node_hovered)
	node.node_unhovered.connect(_on_node_unhovered)

	return node

func _build_connections(tier_1_nodes: Array, tier_2_nodes: Array, tier_3_nodes: Array):
	"""Build list of parent-child connections"""
	_connections.clear()

	var all_nodes = tier_1_nodes + tier_2_nodes + tier_3_nodes

	for spec in all_nodes:
		for child_id in spec.get_children_ids():
			_connections.append({
				"from": spec.id,
				"to": child_id
			})

func _update_container_size():
	"""Update container size to fit all nodes"""
	var max_x = 0.0
	var max_y = 0.0

	for pos in _node_positions.values():
		max_x = max(max_x, pos.x + 140)  # Node width
		max_y = max(max_y, pos.y + 160)  # Node height

	custom_minimum_size = Vector2(max_x, max_y)

# ==============================================================================
# NODE STATE CALCULATION
# ==============================================================================

func _get_node_state(spec: GodSpecialization) -> SpecializationNode.NodeState:
	"""Determine the state of a node based on god's current status"""
	if not god_data or not specialization_manager:
		return SpecializationNode.NodeState.LOCKED

	# Check if already unlocked
	if _is_specialization_unlocked(spec.id):
		return SpecializationNode.NodeState.UNLOCKED

	# Check if available (requirements met)
	if _can_unlock_specialization(spec):
		return SpecializationNode.NodeState.AVAILABLE

	# Otherwise locked
	return SpecializationNode.NodeState.LOCKED

func _is_specialization_unlocked(spec_id: String) -> bool:
	"""Check if god has already unlocked this specialization"""
	if not god_data:
		return false

	var path = god_data.specialization_path
	return spec_id in path

func _can_unlock_specialization(spec: GodSpecialization) -> bool:
	"""Check if god can currently unlock this specialization"""
	if not god_data or not specialization_manager:
		return false

	# Use SpecializationManager's eligibility check
	return specialization_manager.can_god_unlock_specialization(god_data, spec.id)

# ==============================================================================
# SELECTION MANAGEMENT
# ==============================================================================

func select_node(spec_id: String):
	"""Programmatically select a node"""
	# Deselect all
	for node in _nodes.values():
		if is_instance_valid(node):
			node.set_selected(false)

	# Select target
	if _nodes.has(spec_id):
		var node = _nodes[spec_id]
		if is_instance_valid(node):
			node.set_selected(true)

func deselect_all():
	"""Deselect all nodes"""
	for node in _nodes.values():
		if is_instance_valid(node):
			node.set_selected(false)

func get_selected_node_id() -> String:
	"""Get the currently selected node ID"""
	for spec_id in _nodes:
		var node = _nodes[spec_id]
		if is_instance_valid(node) and node.is_selected:
			return spec_id
	return ""

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_node_selected(spec_id: String):
	"""Handle node selection"""
	# Deselect all others
	for node in _nodes.values():
		if is_instance_valid(node):
			node.set_selected(false)

	# Select this one
	if _nodes.has(spec_id):
		var node = _nodes[spec_id]
		if is_instance_valid(node):
			node.set_selected(true)

	# Emit signal
	node_selected.emit(spec_id)

func _on_node_hovered(spec_id: String):
	"""Handle node hover"""
	if _nodes.has(spec_id):
		var node = _nodes[spec_id]
		if is_instance_valid(node):
			var tooltip_text = node.get_tooltip_text()
			node_hovered.emit(spec_id, tooltip_text)

func _on_node_unhovered():
	"""Handle node unhover"""
	node_unhovered.emit()
