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
const HEX_TILES_PATH = "res://data/hex_tiles.json"

# Preload the ring generator to ensure it's available
const HexRingGeneratorScript = preload("res://scripts/systems/territory/HexRingGenerator.gd")

# ==============================================================================
# STATE
# ==============================================================================
var _nodes: Dictionary = {}  # node_id -> HexNode
var _coord_to_node: Dictionary = {}  # "q,r" -> HexNode
var _is_loaded: bool = false
var _base_coord: HexCoord = null  # Divine Sanctum at (0,0)

# Active crafts shared across all UI - {"node_id:task_id": {"node_id", "task_id", "start_time", "end_time", "task_data"}}
var _active_crafts: Dictionary = {}

# Auto-repeat settings - {"node_id:task_id": true} for tasks that should auto-repeat
var _auto_repeat_crafts: Dictionary = {}

# Signals for craft events
signal craft_completed(node_id: String, task_id: String, task_data: Dictionary)
signal craft_auto_restarted(node_id: String, task_id: String)

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_initialize_base_coord()
	load_nodes_from_json()

func _process(_delta: float) -> void:
	"""Check for completed auto-repeat crafts"""
	_check_auto_repeat_crafts()

func _initialize_base_coord() -> void:
	"""Initialize base coordinate at origin"""
	var script: GDScript = load("res://scripts/data/HexCoord.gd")
	_base_coord = script.new(0, 0) as HexCoord

func load_nodes_from_json() -> void:
	"""Load hex nodes from hex_tiles.json"""
	_load_from_hex_tiles()

func _load_from_hex_tiles() -> void:
	"""Generate hex grid from hex_tiles.json (blank tiles + special nodes)"""
	var file: FileAccess = FileAccess.open(HEX_TILES_PATH, FileAccess.READ)
	if not file:
		push_error("HexGridManager: Failed to open hex tiles file: " + HEX_TILES_PATH)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("HexGridManager: Failed to parse hex tiles JSON: %s" % json.get_error_message())
		return

	var tiles_config: Dictionary = json.get_data()
	var hex_node_script: GDScript = load("res://scripts/data/HexNode.gd")

	# Validate ring generation algorithm
	if not HexRingGeneratorScript.validate_all_rings(4):
		push_error("HexGridManager: Ring generation validation failed!")
		return

	# Load ring configuration
	var ring_config: Dictionary = tiles_config.get("ring_config", {})
	var blank_tiles: Dictionary = tiles_config.get("blank_tiles", {})
	var special_nodes: Dictionary = tiles_config.get("special_nodes", {})
	var base_node: Dictionary = tiles_config.get("base_node", {})

	# Generate Ring 0 - Base
	_create_base_node(hex_node_script, base_node)

	# Generate Rings 1-4
	for ring: int in range(1, 5):
		var ring_key: String = "ring_%d" % ring
		var ring_data: Dictionary = ring_config.get(ring_key, {})
		if ring_data.is_empty():
			continue

		var tier: int = ring_data.get("tier", ring)
		var distribution: Dictionary = ring_data.get("distribution", {"blank": ring_data.get("count", 6)})

		# Get coordinates for this ring
		var ring_coords: Array[Vector2i] = HexRingGeneratorScript.generate_ring(ring)

		# Build node list based on distribution
		var nodes_to_create: Array = []

		# Add blank tiles
		var blank_count: int = distribution.get("blank", 0)
		for i: int in range(blank_count):
			nodes_to_create.append({"type": "blank", "tier": tier})

		# Add special nodes
		for special_id: String in distribution:
			if special_id == "blank":
				continue
			var special_count: int = distribution[special_id]
			for i: int in range(special_count):
				nodes_to_create.append({"type": "special", "special_id": special_id, "tier": tier})

		# Shuffle to randomize placement
		nodes_to_create.shuffle()

		# Create nodes at ring coordinates
		for i: int in range(min(nodes_to_create.size(), ring_coords.size())):
			var coord: Vector2i = ring_coords[i]
			var node_info: Dictionary = nodes_to_create[i]

			if node_info.type == "blank":
				_create_blank_tile(hex_node_script, blank_tiles, coord, tier, i)
			else:
				var special_id: String = node_info.special_id
				var special_template: Dictionary = special_nodes.get(special_id, {})
				_create_special_node(hex_node_script, special_template, coord, special_id, i)

	_is_loaded = true
	nodes_loaded.emit()
	print("HexGridManager: Generated %d hex nodes (blank tiles + special nodes)" % _nodes.size())

func _create_base_node(hex_node_script: GDScript, base_template: Dictionary) -> void:
	"""Create the player's home base at (0,0)"""
	var hex_coord_script: GDScript = load("res://scripts/data/HexCoord.gd")

	var node_data: Dictionary = {
		"id": "home_base",
		"name": base_template.get("name", "Divine Sanctum"),
		"type": "base",
		"tier": 0,
		"coord": {"q": 0, "r": 0},
		"controller": "player",
		"is_revealed": true,
		"is_capturable": false,
		"is_buildable": false,
		"is_special_node": false,
		"fixed_production": base_template.get("fixed_production", {"mana": 100, "gold": 50}),
		"base_production": base_template.get("fixed_production", {"mana": 100, "gold": 50}),
		"max_garrison": base_template.get("max_garrison", 0),
		"max_workers": base_template.get("max_workers", 0),
		"attack_timer_hours": -1
	}

	var loaded_node: HexNode = hex_node_script.from_dict(node_data)
	if loaded_node:
		_add_node(loaded_node)

func _create_blank_tile(hex_node_script: GDScript, blank_tiles: Dictionary, coord: Vector2i, tier: int, index: int) -> void:
	"""Create a blank buildable tile"""
	var tier_key: String = "tier_%d" % tier
	var template: Dictionary = blank_tiles.get(tier_key, {})
	if template.is_empty():
		push_warning("HexGridManager: No blank tile template for tier %d" % tier)
		return

	# Pick a name from the names array
	var names: Array = template.get("names", ["Unknown Tile"])
	var tile_name: String = names[index % names.size()]

	# Generate unique ID
	var suffix: String = char(97 + (index % 26))
	if index >= 26:
		suffix = char(97 + (index / 26) - 1) + suffix
	var node_id: String = "blank_t%d_%s" % [tier, suffix]

	# Handle defender count
	var defender_count_config: Dictionary = template.get("defender_count", {"min": 1, "max": 2})
	var defender_names: Array = template.get("base_defenders", [])
	var actual_defenders: Array[String] = []
	var num_defenders: int = randi_range(defender_count_config.get("min", 1), defender_count_config.get("max", 2))
	for i: int in range(num_defenders):
		if defender_names.size() > 0:
			actual_defenders.append(defender_names[i % defender_names.size()])

	var node_data: Dictionary = {
		"id": node_id,
		"name": tile_name,
		"type": "blank",
		"tier": tier,
		"coord": {"q": coord.x, "r": coord.y},
		"controller": "neutral",
		"is_revealed": tier <= 1,
		"is_capturable": true,
		"is_buildable": true,
		"is_special_node": false,
		"is_pvp_territory": template.get("is_pvp_territory", false),
		"placed_building": "",
		"building_level": 1,
		"fixed_production": {},
		"base_production": {},
		"max_garrison": template.get("max_garrison", 2),
		"max_workers": template.get("max_workers", 3),
		"base_defenders": actual_defenders,
		"capture_power_required": template.get("capture_power_required", 2000),
		"attack_timer_hours": template.get("attack_timer_hours", 8),
		"defense_drops": template.get("defense_drops", {})
	}

	var loaded_node: HexNode = hex_node_script.from_dict(node_data)
	if loaded_node:
		_add_node(loaded_node)

func _create_special_node(hex_node_script: GDScript, template: Dictionary, coord: Vector2i, special_id: String, index: int) -> void:
	"""Create a special fixed-production node (PvP objective)"""
	if template.is_empty():
		push_warning("HexGridManager: No template for special node %s" % special_id)
		return

	var node_id: String = "%s_%d" % [special_id, index]

	# Handle defender count
	var defender_count_config: Dictionary = template.get("defender_count", {"min": 3, "max": 5})
	var defender_names: Array = template.get("base_defenders", [])
	var actual_defenders: Array[String] = []
	var num_defenders: int = randi_range(defender_count_config.get("min", 3), defender_count_config.get("max", 5))
	for i: int in range(num_defenders):
		if defender_names.size() > 0:
			actual_defenders.append(defender_names[i % defender_names.size()])

	var fixed_prod: Dictionary = template.get("fixed_production", {})

	var node_data: Dictionary = {
		"id": node_id,
		"name": template.get("name", special_id.replace("_", " ").capitalize()),
		"type": "special",
		"tier": template.get("tier", 4),
		"coord": {"q": coord.x, "r": coord.y},
		"controller": "neutral",
		"is_revealed": false,
		"is_capturable": true,
		"is_buildable": false,
		"is_special_node": true,
		"is_pvp_territory": template.get("is_pvp_territory", true),
		"placed_building": "",
		"building_level": 1,
		"fixed_production": fixed_prod,
		"base_production": fixed_prod,  # Special nodes use fixed_production as base
		"max_garrison": template.get("max_garrison", 5),
		"max_workers": template.get("max_workers", 5),
		"base_defenders": actual_defenders,
		"capture_power_required": template.get("capture_power_required", 30000),
		"attack_timer_hours": template.get("attack_timer_hours", 2),
		"defense_drops": template.get("defense_drops", {})
	}

	var loaded_node: HexNode = hex_node_script.from_dict(node_data)
	if loaded_node:
		_add_node(loaded_node)

func _add_node(node: HexNode) -> void:
	"""Internal method to add a node to the grid"""
	_nodes[node.id] = node
	var coord_key: String = _coord_to_key(node.coord)
	_coord_to_node[coord_key] = node

func _coord_to_key(coord: HexCoord) -> String:
	"""Convert coordinate to dictionary key"""
	if coord == null:
		return "0,0"
	return "%d,%d" % [coord.q, coord.r]

# ==============================================================================
# NODE QUERIES
# ==============================================================================

func get_node_at(coord: HexCoord) -> HexNode:
	"""Get the node at a specific coordinate"""
	if coord == null:
		return null
	var coord_key: String = _coord_to_key(coord)
	return _coord_to_node.get(coord_key, null)

func get_node_by_id(node_id: String) -> HexNode:
	"""Get a node by its ID"""
	return _nodes.get(node_id, null)

func get_all_nodes() -> Array:
	"""Get all nodes in the grid"""
	var result: Array = []
	for node: HexNode in _nodes.values():
		result.append(node)
	return result

func has_node_at(coord: HexCoord) -> bool:
	"""Check if a node exists at coordinate"""
	if coord == null:
		return false
	var coord_key: String = _coord_to_key(coord)
	return _coord_to_node.has(coord_key)

# ==============================================================================
# SPATIAL QUERIES
# ==============================================================================

func get_neighbors(coord: HexCoord) -> Array:
	"""Get all neighboring nodes (up to 6)"""
	var neighbors: Array = []
	if coord == null:
		return neighbors

	var neighbor_coords: Array[HexCoord] = coord.get_neighbors()
	for neighbor_coord: HexCoord in neighbor_coords:
		var node: HexNode = get_node_at(neighbor_coord)
		if node:
			neighbors.append(node)

	return neighbors

func get_nodes_in_ring(ring: int) -> Array:
	"""Get all nodes at a specific ring distance from base"""
	var result: Array = []

	for node: HexNode in _nodes.values():
		var distance: int = get_distance(_base_coord, node.coord)
		if distance == ring:
			result.append(node)

	return result

func get_nodes_within_distance(center: HexCoord, max_distance: int) -> Array:
	"""Get all nodes within a certain distance from center"""
	var result: Array = []

	if center == null or max_distance < 0:
		return result

	for node: HexNode in _nodes.values():
		var distance: int = get_distance(center, node.coord)
		if distance <= max_distance:
			result.append(node)

	return result

func get_distance(from: HexCoord, to: HexCoord) -> int:
	"""Get distance between two coordinates"""
	if from == null or to == null:
		return 0
	return from.distance_to(to)

func get_distance_from_base(coord: HexCoord) -> int:
	"""Get distance from base (0,0) to coordinate"""
	return get_distance(_base_coord, coord)

func get_base_coord() -> HexCoord:
	"""Get the base coordinate (Divine Sanctum at 0,0)"""
	return _base_coord

# ==============================================================================
# PATHFINDING
# ==============================================================================

func get_hex_path(from: HexCoord, to: HexCoord) -> Array:
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

	var from_key: String = _coord_to_key(from)
	g_score[from_key] = 0
	f_score[from_key] = get_distance(from, to)

	while open_set.size() > 0:
		# Get node with lowest f_score
		var current: HexCoord = _get_lowest_f_score_coord(open_set, f_score)
		var current_key: String = _coord_to_key(current)

		if current.equals(to):
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		# Check all neighbors
		var neighbors: Array[HexCoord] = current.get_neighbors()
		for neighbor: HexCoord in neighbors:
			# Only consider neighbors that have nodes (are passable)
			if not has_node_at(neighbor):
				continue

			var neighbor_key: String = _coord_to_key(neighbor)
			var tentative_g_score: int = g_score[current_key] + 1

			if not g_score.has(neighbor_key) or tentative_g_score < g_score[neighbor_key]:
				came_from[neighbor_key] = current
				g_score[neighbor_key] = tentative_g_score
				f_score[neighbor_key] = tentative_g_score + get_distance(neighbor, to)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# No path found
	return []

func _get_lowest_f_score_coord(coords: Array, f_scores: Dictionary) -> HexCoord:
	"""Helper: Get coordinate with lowest f_score"""
	var lowest_coord: HexCoord = coords[0]
	var lowest_score: int = f_scores.get(_coord_to_key(lowest_coord), 999999)

	for coord: HexCoord in coords:
		var score: int = f_scores.get(_coord_to_key(coord), 999999)
		if score < lowest_score:
			lowest_score = score
			lowest_coord = coord

	return lowest_coord

func _reconstruct_path(came_from: Dictionary, current: HexCoord) -> Array:
	"""Helper: Reconstruct path from A* came_from map"""
	var path: Array = [current]
	var current_key: String = _coord_to_key(current)

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
	for node: HexNode in _nodes.values():
		if node.node_type == node_type:
			result.append(node)
	return result

func get_nodes_by_tier(tier: int) -> Array:
	"""Get all nodes of a specific tier"""
	var result: Array = []
	for node: HexNode in _nodes.values():
		if node.tier == tier:
			result.append(node)
	return result

func get_nodes_by_controller(controller: String) -> Array:
	"""Get all nodes controlled by a specific controller"""
	var result: Array = []
	for node: HexNode in _nodes.values():
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
	for node: HexNode in _nodes.values():
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
	var max_ring: int = 0
	for node: HexNode in _nodes.values():
		var ring: int = get_distance_from_base(node.coord)
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
	var node_states: Dictionary = {}
	for node_id: String in _nodes:
		var node: HexNode = _nodes[node_id]
		node_states[node_id] = node.to_dict()

	return {
		"nodes": node_states,
		"active_crafts": _active_crafts.duplicate(true),
		"auto_repeat_crafts": _auto_repeat_crafts.duplicate()
	}

func load_save_data(save_data: Dictionary) -> void:
	"""Load grid state from save data"""
	if not save_data.has("nodes"):
		print("[HexGridManager] load_save_data: No 'nodes' key in save data!")
		return

	var saved_nodes: Dictionary = save_data.nodes
	print("[HexGridManager] load_save_data: Found %d saved nodes, current grid has %d nodes" % [saved_nodes.size(), _nodes.size()])

	var matched_count: int = 0
	var player_nodes_loaded: int = 0

	for node_id: String in saved_nodes:
		if _nodes.has(node_id):
			matched_count += 1
			# Update existing node with saved state
			var node: HexNode = _nodes[node_id]
			var saved_state: Dictionary = saved_nodes[node_id]

			# Update dynamic state (not static definitions)
			node.controller = saved_state.get("controller", "neutral")
			node.is_revealed = saved_state.get("is_revealed", false)
			node.is_contested = saved_state.get("is_contested", false)
			node.contested_until = saved_state.get("contested_until", 0)

			if node.controller == "player":
				player_nodes_loaded += 1

			# Update typed arrays using .assign()
			var garrison_data: Array = saved_state.get("garrison", [])
			node.garrison.assign(garrison_data)
			var workers_data: Array = saved_state.get("assigned_workers", [])
			node.assigned_workers.assign(workers_data)
			var tasks_data: Array = saved_state.get("active_tasks", [])
			node.active_tasks.assign(tasks_data)

			node.production_level = saved_state.get("production_level", 1)
			node.defense_level = saved_state.get("defense_level", 1)
			node.last_raid_time = saved_state.get("last_raid_time", 0)
			node.raid_cooldown = saved_state.get("raid_cooldown", 0)
			node.last_production_time = saved_state.get("last_production_time", 0)
			node.accumulated_resources = saved_state.get("accumulated_resources", {})

			# Building system state (new)
			node.placed_building = saved_state.get("placed_building", "")
			node.building_level = saved_state.get("building_level", 1)

			# Attack timer state
			node.attack_timer_remaining = saved_state.get("attack_timer_remaining", -1.0)
			node.last_attack_check_time = saved_state.get("last_attack_check_time", 0)
		else:
			# Log unmatched node IDs to diagnose save/load issues
			print("[HexGridManager] WARNING: Saved node '%s' not found in current grid!" % node_id)

	print("[HexGridManager] load_save_data: Matched %d/%d saved nodes, %d player-controlled" % [matched_count, saved_nodes.size(), player_nodes_loaded])

	# Restore active crafts
	if save_data.has("active_crafts"):
		_active_crafts = save_data.active_crafts.duplicate(true)

	# Restore auto-repeat settings
	if save_data.has("auto_repeat_crafts"):
		_auto_repeat_crafts = save_data.auto_repeat_crafts.duplicate()

	# Post-load fix: Ensure adjacent nodes to player-controlled nodes are revealed
	# This handles saves from before the reveal-on-capture logic was added
	_ensure_adjacent_nodes_revealed()

	grid_updated.emit()

func _ensure_adjacent_nodes_revealed() -> void:
	"""Ensure all nodes adjacent to player-controlled nodes are revealed.
	Called after loading save data to fix saves from before reveal logic was added."""
	var player_nodes: Array = get_player_nodes()
	var newly_revealed: int = 0

	for node: HexNode in player_nodes:
		var neighbors: Array = get_neighbors(node.coord)
		for neighbor: HexNode in neighbors:
			if neighbor and not neighbor.is_revealed:
				neighbor.is_revealed = true
				newly_revealed += 1

	if newly_revealed > 0:
		print("HexGridManager: Post-load revealed %d adjacent nodes" % newly_revealed)

# ==============================================================================
# CRAFT TRACKING (Shared across UI screens)
# ==============================================================================

func start_craft(node_id: String, task_id: String, task_data: Dictionary, auto_repeat: bool = false) -> bool:
	"""Start tracking a craft - called by UI when player starts crafting.
	Returns true if craft was started, false if node is at craft limit."""
	var node: HexNode = get_node_by_id(node_id)
	if not node:
		push_error("HexGridManager: Cannot start craft - node '%s' not found" % node_id)
		return false

	# Check craft limit for this node (1 craft per node by default, could be expanded based on tier)
	var current_crafts: Array = get_active_crafts_for_node(node_id)
	var max_crafts: int = _get_max_crafts_for_node(node)
	if current_crafts.size() >= max_crafts:
		push_warning("HexGridManager: Node '%s' already at craft limit (%d/%d)" % [node_id, current_crafts.size(), max_crafts])
		return false

	# Check if node has an assigned worker (required for crafting)
	if node.assigned_workers.is_empty():
		push_warning("HexGridManager: Cannot start craft - node '%s' has no assigned workers" % node_id)
		return false

	var duration_seconds: int = task_data.get("base_duration_seconds", 60)
	var current_time: int = int(Time.get_unix_time_from_system())
	var craft_key: String = "%s:%s" % [node_id, task_id]

	_active_crafts[craft_key] = {
		"task_id": task_id,
		"node_id": node_id,
		"start_time": current_time,
		"end_time": current_time + duration_seconds,
		"task_data": task_data,
		"auto_repeat": auto_repeat
	}

	# Track auto-repeat setting
	if auto_repeat:
		_auto_repeat_crafts[craft_key] = true
	elif _auto_repeat_crafts.has(craft_key):
		_auto_repeat_crafts.erase(craft_key)

	# Also add to node's active_tasks
	if not node.active_tasks.has(task_id):
		node.active_tasks.append(task_id)

	print("HexGridManager: Started craft '%s' at node '%s' (auto-repeat: %s)" % [task_id, node_id, auto_repeat])
	return true

func _get_max_crafts_for_node(node: HexNode) -> int:
	"""Get maximum concurrent crafts allowed for a node based on tier"""
	# For now, 1 craft per forge. Could expand to tier-based later.
	return 1

func get_active_crafts() -> Dictionary:
	"""Get all active crafts"""
	return _active_crafts

func get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node"""
	var result: Array = []
	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		if craft_data.get("node_id", "") == node_id:
			result.append(craft_data)
	return result

func complete_craft(node_id: String, task_id: String) -> Dictionary:
	"""Complete a craft and return its data, or empty dict if not found"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if not _active_crafts.has(craft_key):
		return {}

	var craft_data: Dictionary = _active_crafts[craft_key]
	_active_crafts.erase(craft_key)

	# Remove from node's active_tasks
	var node: HexNode = get_node_by_id(node_id)
	if node and node.active_tasks.has(task_id):
		node.active_tasks.erase(task_id)

	# Emit completion signal
	craft_completed.emit(node_id, task_id, craft_data.get("task_data", {}))

	return craft_data

func set_auto_repeat(node_id: String, task_id: String, enabled: bool) -> void:
	"""Enable or disable auto-repeat for a craft"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if enabled:
		_auto_repeat_crafts[craft_key] = true
		# Also update the active craft data if it exists
		if _active_crafts.has(craft_key):
			_active_crafts[craft_key]["auto_repeat"] = true
	else:
		_auto_repeat_crafts.erase(craft_key)
		if _active_crafts.has(craft_key):
			_active_crafts[craft_key]["auto_repeat"] = false

func is_auto_repeat_enabled(node_id: String, task_id: String) -> bool:
	"""Check if auto-repeat is enabled for a craft"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	return _auto_repeat_crafts.has(craft_key)

func cancel_craft(node_id: String, task_id: String) -> bool:
	"""Cancel a specific craft. Returns true if craft was cancelled."""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if not _active_crafts.has(craft_key):
		return false

	_active_crafts.erase(craft_key)
	_auto_repeat_crafts.erase(craft_key)

	# Remove from node's active_tasks
	var node: HexNode = get_node_by_id(node_id)
	if node and node.active_tasks.has(task_id):
		node.active_tasks.erase(task_id)

	print("HexGridManager: Cancelled craft '%s' at node '%s'" % [task_id, node_id])
	return true

func cancel_all_crafts_for_node(node_id: String) -> int:
	"""Cancel all crafts for a node. Returns number of crafts cancelled."""
	var cancelled: int = 0
	var crafts_to_cancel: Array = []

	# Find all crafts for this node
	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		if craft_data.get("node_id", "") == node_id:
			crafts_to_cancel.append(craft_data.get("task_id", ""))

	# Cancel them
	for task_id: String in crafts_to_cancel:
		if cancel_craft(node_id, task_id):
			cancelled += 1

	if cancelled > 0:
		print("HexGridManager: Cancelled %d crafts for node '%s'" % [cancelled, node_id])

	return cancelled

func _check_auto_repeat_crafts() -> void:
	"""Check for completed auto-repeat crafts and restart them"""
	var current_time: int = int(Time.get_unix_time_from_system())
	var crafts_to_restart: Array = []
	var crafts_to_cancel: Array = []

	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		var end_time: int = craft_data.get("end_time", current_time)
		var node_id: String = craft_data.get("node_id", "")

		# Check if node still has workers assigned
		var node: HexNode = get_node_by_id(node_id)
		if not node or node.assigned_workers.is_empty():
			# No workers = cancel craft
			crafts_to_cancel.append(craft_data)
			continue

		# Check if craft is complete
		if current_time >= end_time:
			var is_auto_repeat: bool = craft_data.get("auto_repeat", false) or _auto_repeat_crafts.has(craft_key)
			if is_auto_repeat:
				crafts_to_restart.append(craft_data)

	# Cancel crafts with no workers
	for craft_data: Dictionary in crafts_to_cancel:
		var node_id: String = craft_data.get("node_id", "")
		var task_id: String = craft_data.get("task_id", "")
		cancel_craft(node_id, task_id)
		print("HexGridManager: Auto-cancelled craft '%s' - no workers assigned" % task_id)

	# Process auto-restarts
	for craft_data: Dictionary in crafts_to_restart:
		var node_id: String = craft_data.get("node_id", "")
		var task_id: String = craft_data.get("task_id", "")
		var task_data: Dictionary = craft_data.get("task_data", {})

		# Double-check node still has workers (might have been cancelled above)
		var node: HexNode = get_node_by_id(node_id)
		if not node or node.assigned_workers.is_empty():
			var cancel_key: String = "%s:%s" % [node_id, task_id]
			_auto_repeat_crafts.erase(cancel_key)
			continue

		# Check if we can afford the cost
		if _can_afford_craft_cost(task_data):
			# Spend the resources
			_spend_craft_cost(task_data)

			# Award the rewards
			_award_craft_rewards(task_data)

			# Restart the craft
			var duration_seconds: int = task_data.get("base_duration_seconds", 60)
			var craft_key: String = "%s:%s" % [node_id, task_id]

			_active_crafts[craft_key] = {
				"task_id": task_id,
				"node_id": node_id,
				"start_time": current_time,
				"end_time": current_time + duration_seconds,
				"task_data": task_data,
				"auto_repeat": true
			}

			craft_auto_restarted.emit(node_id, task_id)
		else:
			# Can't afford, disable auto-repeat
			var disable_key: String = "%s:%s" % [node_id, task_id]
			_auto_repeat_crafts.erase(disable_key)

func _can_afford_craft_cost(task_data: Dictionary) -> bool:
	"""Check if player can afford the craft costs (including accumulated node resources)"""
	# Use "materials" from crafting_recipes.json (fallback to "resource_costs")
	var costs: Dictionary = task_data.get("materials", task_data.get("resource_costs", {}))
	if costs.is_empty():
		return true

	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		return true

	# First check if we can afford directly from inventory
	if resource_manager.can_afford(costs):
		return true

	# If not, check if accumulated resources on nodes can cover the deficit
	var total_available: Dictionary = _get_total_available_resources(resource_manager, costs)
	for resource_id: String in costs:
		var needed: int = costs[resource_id]
		var available: int = total_available.get(resource_id, 0)
		if available < needed:
			return false  # Not enough even with accumulated resources

	return true

func _get_total_available_resources(resource_manager: Node, costs: Dictionary) -> Dictionary:
	"""Get total resources available (inventory + accumulated on all player nodes)"""
	var total: Dictionary = {}

	# Add inventory resources
	for resource_id: String in costs:
		total[resource_id] = resource_manager.get_resource(resource_id) if resource_manager else 0

	# Add accumulated resources from all player-controlled nodes
	for node: HexNode in get_player_nodes():
		for resource_id: String in node.accumulated_resources:
			if costs.has(resource_id):  # Only count resources we need
				var amount: int = node.accumulated_resources.get(resource_id, 0)
				total[resource_id] = total.get(resource_id, 0) + amount

	return total

func _spend_craft_cost(task_data: Dictionary) -> void:
	"""Spend the resources for a craft, using accumulated resources if needed"""
	# Use "materials" from crafting_recipes.json (fallback to "resource_costs")
	var costs: Dictionary = task_data.get("materials", task_data.get("resource_costs", {}))
	if costs.is_empty():
		return

	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		return

	# Try to spend from inventory first, auto-collect from nodes if needed
	for resource_id: String in costs:
		var needed: int = costs[resource_id]
		var in_inventory: int = resource_manager.get_resource(resource_id)

		if in_inventory >= needed:
			# Can afford entirely from inventory
			resource_manager.spend(resource_id, needed)
		else:
			# Need to collect from accumulated resources first
			var deficit: int = needed - in_inventory

			# Collect from nodes to cover deficit
			_auto_collect_resource_from_nodes(resource_id, deficit, resource_manager)

			# Now spend from inventory (which should have enough after collection)
			resource_manager.spend(resource_id, needed)

func _auto_collect_resource_from_nodes(resource_id: String, amount_needed: float, resource_manager: Node) -> float:
	"""Auto-collect a specific resource from player nodes to cover craft costs"""
	var collected: float = 0.0

	for node: HexNode in get_player_nodes():
		if collected >= amount_needed:
			break

		var available: float = node.accumulated_resources.get(resource_id, 0)
		if available > 0:
			var to_collect: float = min(available, amount_needed - collected)

			# Remove from node's accumulated
			node.accumulated_resources[resource_id] = available - to_collect

			# Add to player inventory
			if resource_manager:
				resource_manager.add_resource(resource_id, to_collect)

			collected += to_collect
			print("[HexGridManager] Auto-collected %.1f %s from node %s for craft" % [to_collect, resource_id, node.id])

	return collected

func _award_craft_rewards(task_data: Dictionary) -> void:
	"""Award the rewards from a completed auto-repeat craft"""
	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		push_error("HexGridManager: Cannot award craft rewards - no ResourceManager")
		return

	# Resource rewards - use "output" from crafting_recipes.json (fallback to "resource_rewards")
	var resources: Dictionary = task_data.get("output", task_data.get("resource_rewards", {}))
	if resources.is_empty():
		push_warning("HexGridManager: No output resources found in task_data: %s" % task_data.keys())
		return

	for resource_id: String in resources.keys():
		var amount: int = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)
		print("HexGridManager: Auto-repeat craft awarded %d %s" % [amount, resource_id])

func _get_resource_manager() -> Node:
	"""Get ResourceManager via SystemRegistry"""
	var registry_script: GDScript = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		var registry: Node = registry_script.get_instance()
		if registry:
			return registry.get_system("ResourceManager")
	return null

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
		"is_loaded": _is_loaded,
		"active_crafts": _active_crafts.size()
	}
