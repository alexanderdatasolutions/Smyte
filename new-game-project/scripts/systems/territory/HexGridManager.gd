# scripts/systems/territory/HexGridManager.gd
# Manages hex grid and node lookup operations
extends Node
class_name HexGridManager

"""
HexGridManager - Core hex grid logic
RULE 2: Single responsibility - Hex grid operations only
RULE 3: Logic in systems - Uses HexCoord and HexNode data classes
RULE 1: Under 500 lines

Following CLAUDE.md architecture:
- SYSTEM LAYER: Manages hex grid state and queries
- Loads nodes from JSON
- Provides spatial queries (neighbors, rings, distance)
- Pathfinding between coordinates
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal nodes_loaded()
signal node_added(node_id: String)
signal grid_updated()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HEX_NODES_DATA_PATH = "res://data/hex_nodes.json"

# ==============================================================================
# STATE
# ==============================================================================
var _nodes: Dictionary = {}  # node_id -> HexNode
var _coord_to_node: Dictionary = {}  # "q,r" -> HexNode
var _is_loaded: bool = false
var _base_coord = null  # Divine Sanctum at (0,0)

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_initialize_base_coord()
	load_nodes_from_json()

func _initialize_base_coord() -> void:
	"""Initialize base coordinate at origin"""
	var script = load("res://scripts/data/HexCoord.gd")
	_base_coord = script.new(0, 0)

func load_nodes_from_json() -> void:
	"""Load all hex node definitions from JSON"""
	if not FileAccess.file_exists(HEX_NODES_DATA_PATH):
		push_warning("HexGridManager: Hex nodes data file not found: " + HEX_NODES_DATA_PATH)
		push_warning("HexGridManager: Starting with empty grid. Create hex_nodes.json to add nodes.")
		_is_loaded = true
		nodes_loaded.emit()
		return

	var file = FileAccess.open(HEX_NODES_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("HexGridManager: Failed to open hex nodes data file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("HexGridManager: Failed to parse hex nodes JSON: " + json.get_error_message())
		return

	var data = json.get_data()

	# Load node definitions
	if data.has("nodes"):
		for node_id in data.nodes:
			var node_data = data.nodes[node_id]
			node_data["id"] = node_id  # Ensure ID is set
			var hex_node_script = load("res://scripts/data/HexNode.gd")
			var loaded_node = hex_node_script.from_dict(node_data)
			if loaded_node:
				_add_node(loaded_node)

	_is_loaded = true
	nodes_loaded.emit()
	print("HexGridManager: Loaded %d hex nodes" % [_nodes.size()])

func _add_node(node) -> void:
	"""Internal method to add a node to the grid"""
	_nodes[node.id] = node
	var coord_key = _coord_to_key(node.coord)
	_coord_to_node[coord_key] = node

func _coord_to_key(coord) -> String:
	"""Convert coordinate to dictionary key"""
	if coord == null:
		return "0,0"
	return "%d,%d" % [coord.q, coord.r]

# ==============================================================================
# NODE QUERIES
# ==============================================================================

func get_node_at(coord):
	"""Get the node at a specific coordinate"""
	if coord == null:
		return null
	var coord_key = _coord_to_key(coord)
	return _coord_to_node.get(coord_key, null)

func get_node_by_id(node_id: String):
	"""Get a node by its ID"""
	return _nodes.get(node_id, null)

func get_all_nodes() -> Array:
	"""Get all nodes in the grid"""
	var result: Array = []
	for node in _nodes.values():
		result.append(node)
	return result

func has_node_at(coord) -> bool:
	"""Check if a node exists at coordinate"""
	if coord == null:
		return false
	var coord_key = _coord_to_key(coord)
	return _coord_to_node.has(coord_key)

# ==============================================================================
# SPATIAL QUERIES
# ==============================================================================

func get_neighbors(coord) -> Array:
	"""Get all neighboring nodes (up to 6)"""
	var neighbors: Array = []
	if coord == null:
		return neighbors

	var neighbor_coords = coord.get_neighbors()
	for neighbor_coord in neighbor_coords:
		var node = get_node_at(neighbor_coord)
		if node:
			neighbors.append(node)

	return neighbors

func get_nodes_in_ring(ring: int) -> Array:
	"""Get all nodes at a specific ring distance from base"""
	var result: Array = []

	for node in _nodes.values():
		var distance = get_distance(_base_coord, node.coord)
		if distance == ring:
			result.append(node)

	return result

func get_nodes_within_distance(center, max_distance: int) -> Array:
	"""Get all nodes within a certain distance from center"""
	var result: Array = []

	if center == null or max_distance < 0:
		return result

	for node in _nodes.values():
		var distance = get_distance(center, node.coord)
		if distance <= max_distance:
			result.append(node)

	return result

func get_distance(from, to) -> int:
	"""Get distance between two coordinates"""
	if from == null or to == null:
		return 0
	return from.distance_to(to)

func get_distance_from_base(coord) -> int:
	"""Get distance from base (0,0) to coordinate"""
	return get_distance(_base_coord, coord)

func get_base_coord():
	"""Get the base coordinate (Divine Sanctum at 0,0)"""
	return _base_coord

# ==============================================================================
# PATHFINDING
# ==============================================================================

func get_hex_path(from, to) -> Array:
	"""Get path from one coordinate to another using A* pathfinding"""
	if from == null or to == null:
		return []

	if from.equals(to):
		return [from]

	# Simple A* implementation for hex grid
	var open_set: Array = [from]
	var came_from: Dictionary = {}  # coord_key -> HexCoord
	var g_score: Dictionary = {}  # coord_key -> int (cost from start)
	var f_score: Dictionary = {}  # coord_key -> int (estimated total cost)

	var from_key = _coord_to_key(from)
	g_score[from_key] = 0
	f_score[from_key] = get_distance(from, to)

	while open_set.size() > 0:
		# Get node with lowest f_score
		var current = _get_lowest_f_score_coord(open_set, f_score)
		var current_key = _coord_to_key(current)

		if current.equals(to):
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		# Check all neighbors
		var neighbors = current.get_neighbors()
		for neighbor in neighbors:
			# Only consider neighbors that have nodes (are passable)
			if not has_node_at(neighbor):
				continue

			var neighbor_key = _coord_to_key(neighbor)
			var tentative_g_score = g_score[current_key] + 1

			if not g_score.has(neighbor_key) or tentative_g_score < g_score[neighbor_key]:
				came_from[neighbor_key] = current
				g_score[neighbor_key] = tentative_g_score
				f_score[neighbor_key] = tentative_g_score + get_distance(neighbor, to)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# No path found
	return []

func _get_lowest_f_score_coord(coords: Array, f_scores: Dictionary):
	"""Helper: Get coordinate with lowest f_score"""
	var lowest_coord = coords[0]
	var lowest_score = f_scores.get(_coord_to_key(lowest_coord), 999999)

	for coord in coords:
		var score = f_scores.get(_coord_to_key(coord), 999999)
		if score < lowest_score:
			lowest_score = score
			lowest_coord = coord

	return lowest_coord

func _reconstruct_path(came_from: Dictionary, current) -> Array:
	"""Helper: Reconstruct path from A* came_from map"""
	var path: Array = [current]
	var current_key = _coord_to_key(current)

	while came_from.has(current_key):
		current = came_from[current_key]
		current_key = _coord_to_key(current)
		path.insert(0, current)

	return path

# ==============================================================================
# FILTERING & QUERIES
# ==============================================================================

func get_nodes_by_type(node_type: String) -> Array:
	"""Get all nodes of a specific type"""
	var result: Array = []
	for node in _nodes.values():
		if node.node_type == node_type:
			result.append(node)
	return result

func get_nodes_by_tier(tier: int) -> Array:
	"""Get all nodes of a specific tier"""
	var result: Array = []
	for node in _nodes.values():
		if node.tier == tier:
			result.append(node)
	return result

func get_nodes_by_controller(controller: String) -> Array:
	"""Get all nodes controlled by a specific controller"""
	var result: Array = []
	for node in _nodes.values():
		if node.controller == controller:
			result.append(node)
	return result

func get_player_nodes() -> Array:
	"""Get all player-controlled nodes"""
	return get_nodes_by_controller("player")

func get_neutral_nodes() -> Array:
	"""Get all neutral nodes"""
	return get_nodes_by_controller("neutral")

func get_revealed_nodes() -> Array:
	"""Get all revealed nodes"""
	var result: Array = []
	for node in _nodes.values():
		if node.is_revealed:
			result.append(node)
	return result

# ==============================================================================
# GRID INFO
# ==============================================================================

func get_node_count() -> int:
	"""Get total number of nodes in grid"""
	return _nodes.size()

func get_max_ring() -> int:
	"""Get the maximum ring distance in the grid"""
	var max_ring = 0
	for node in _nodes.values():
		var ring = get_distance_from_base(node.coord)
		if ring > max_ring:
			max_ring = ring
	return max_ring

func is_loaded() -> bool:
	"""Check if grid data is loaded"""
	return _is_loaded

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get grid state for saving (node states, not definitions)"""
	var node_states = {}
	for node_id in _nodes:
		var node = _nodes[node_id]
		node_states[node_id] = node.to_dict()

	return {
		"nodes": node_states
	}

func load_save_data(save_data: Dictionary) -> void:
	"""Load grid state from save data"""
	if not save_data.has("nodes"):
		return

	var saved_nodes = save_data.nodes
	for node_id in saved_nodes:
		if _nodes.has(node_id):
			# Update existing node with saved state
			var node = _nodes[node_id]
			var saved_state = saved_nodes[node_id]

			# Update dynamic state (not static definitions)
			node.controller = saved_state.get("controller", "neutral")
			node.is_revealed = saved_state.get("is_revealed", false)
			node.is_contested = saved_state.get("is_contested", false)
			node.contested_until = saved_state.get("contested_until", 0)
			node.garrison = saved_state.get("garrison", [])
			node.assigned_workers = saved_state.get("assigned_workers", [])
			node.active_tasks = saved_state.get("active_tasks", [])
			node.production_level = saved_state.get("production_level", 1)
			node.defense_level = saved_state.get("defense_level", 1)
			node.last_raid_time = saved_state.get("last_raid_time", 0)
			node.raid_cooldown = saved_state.get("raid_cooldown", 0)

	grid_updated.emit()

# ==============================================================================
# DEBUG
# ==============================================================================

func get_debug_info() -> Dictionary:
	"""Get debug information about the grid"""
	return {
		"total_nodes": _nodes.size(),
		"max_ring": get_max_ring(),
		"player_nodes": get_player_nodes().size(),
		"neutral_nodes": get_neutral_nodes().size(),
		"revealed_nodes": get_revealed_nodes().size(),
		"is_loaded": _is_loaded
	}
