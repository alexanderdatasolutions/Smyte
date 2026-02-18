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
- Delegates craft tracking to HexCraftManager
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal nodes_loaded()
signal node_added(node_id: String)
signal grid_updated()

# Forwarded from HexCraftManager for external callers
signal craft_completed(node_id: String, task_id: String, task_data: Dictionary)
signal craft_auto_restarted(node_id: String, task_id: String)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HEX_TILES_PATH = "res://data/hex_tiles.json"

# Preload the ring generator to ensure it's available
const HexRingGeneratorScript = preload("res://scripts/systems/territory/HexRingGenerator.gd")
const HexCraftManagerScript = preload("res://scripts/systems/territory/HexCraftManager.gd")

# ==============================================================================
# STATE
# ==============================================================================
var _nodes: Dictionary = {}  # node_id -> HexNode
var _coord_to_node: Dictionary = {}  # "q,r" -> HexNode
var _is_loaded: bool = false
var _base_coord: HexCoord = null  # Divine Sanctum at (0,0)
var _craft_manager: Node = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_initialize_craft_manager()
	_initialize_base_coord()
	load_nodes_from_json()

func _initialize_craft_manager() -> void:
	"""Create and initialize the craft manager as a child node"""
	_craft_manager = HexCraftManagerScript.new()
	_craft_manager.name = "HexCraftManager"
	add_child(_craft_manager)
	_craft_manager.initialize(self)

	# Forward craft signals
	_craft_manager.craft_completed.connect(func(node_id: String, task_id: String, task_data: Dictionary) -> void:
		craft_completed.emit(node_id, task_id, task_data))
	_craft_manager.craft_auto_restarted.connect(func(node_id: String, task_id: String) -> void:
		craft_auto_restarted.emit(node_id, task_id))

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

func _create_base_node(hex_node_script: GDScript, base_template: Dictionary) -> void:
	"""Create the player's home base at (0,0)"""
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
		"base_production": fixed_prod,
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
	"""Get grid state for saving - ONLY dynamic player state, not template data.
	Reduces save size by ~90% by not duplicating static hex_tiles.json data."""
	var node_states: Dictionary = {}
	for node_id: String in _nodes:
		var node: HexNode = _nodes[node_id]
		# Only save nodes that have player modifications
		if node.has_player_modifications():
			node_states[node_id] = node.to_save_dict()

	var save: Dictionary = {"nodes": node_states}

	# Include craft data from craft manager
	if _craft_manager:
		var craft_save: Dictionary = _craft_manager.get_save_data()
		save["active_crafts"] = craft_save.get("active_crafts", {})
		save["auto_repeat_crafts"] = craft_save.get("auto_repeat_crafts", {})

	return save

func load_save_data(save_data: Dictionary) -> void:
	"""Load grid state from save data"""
	if not save_data.has("nodes"):
		return

	var saved_nodes: Dictionary = save_data.nodes

	for node_id: String in saved_nodes:
		if _nodes.has(node_id):
			# Update existing node with saved state
			var node: HexNode = _nodes[node_id]
			var saved_state: Dictionary = saved_nodes[node_id]

			# Update dynamic state (not static definitions)
			node.controller = saved_state.get("controller", "neutral")
			node.is_revealed = saved_state.get("is_revealed", false)
			node.is_contested = saved_state.get("is_contested", false)
			node.contested_until = saved_state.get("contested_until", 0)

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

			# Building system state
			node.placed_building = saved_state.get("placed_building", "")
			node.building_level = saved_state.get("building_level", 1)

			# Attack timer state
			node.attack_timer_remaining = saved_state.get("attack_timer_remaining", -1.0)
			node.last_attack_check_time = saved_state.get("last_attack_check_time", 0)

	# Restore craft data via craft manager
	if _craft_manager:
		_craft_manager.load_save_data(save_data)

	# Post-load fix: Restore building names/types from placed_building data
	_restore_building_names_from_save()

	# Post-load fix: Ensure adjacent nodes to player-controlled nodes are revealed
	_ensure_adjacent_nodes_revealed()

	grid_updated.emit()

func _restore_building_names_from_save() -> void:
	"""Restore node names and types from placed_building after loading.
	Building names aren't saved (to reduce save size), so we restore them from BuildingManager."""
	var registry: Node = SystemRegistry.get_instance()
	var building_manager: Node = registry.get_system("BuildingManager") if registry else null
	if not building_manager:
		return

	for node: HexNode in _nodes.values():
		if not node.placed_building.is_empty():
			var building: Dictionary = building_manager.get_building(node.placed_building)
			if not building.is_empty():
				node.name = building.get("name", node.placed_building.replace("_", " ").capitalize())
				node.node_type = building.get("category", "building")
				node.max_workers = building_manager.get_max_workers(node.placed_building)

func _ensure_adjacent_nodes_revealed() -> void:
	"""Ensure all nodes adjacent to player-controlled nodes are revealed.
	Called after loading save data to fix saves from before reveal logic was added."""
	var player_nodes: Array = get_player_nodes()
	for node: HexNode in player_nodes:
		var neighbors: Array = get_neighbors(node.coord)
		for neighbor: HexNode in neighbors:
			if neighbor and not neighbor.is_revealed:
				neighbor.is_revealed = true

# ==============================================================================
# CRAFT TRACKING (Delegated to HexCraftManager)
# ==============================================================================

func start_craft(node_id: String, task_id: String, task_data: Dictionary, auto_repeat: bool = false) -> bool:
	"""Start tracking a craft. Delegated to HexCraftManager."""
	return _craft_manager.start_craft(node_id, task_id, task_data, auto_repeat)

func get_active_crafts() -> Dictionary:
	"""Get all active crafts. Delegated to HexCraftManager."""
	return _craft_manager.get_active_crafts()

func get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node. Delegated to HexCraftManager."""
	return _craft_manager.get_active_crafts_for_node(node_id)

func complete_craft(node_id: String, task_id: String) -> Dictionary:
	"""Complete a craft. Delegated to HexCraftManager."""
	return _craft_manager.complete_craft(node_id, task_id)

func set_auto_repeat(node_id: String, task_id: String, enabled: bool) -> void:
	"""Enable or disable auto-repeat. Delegated to HexCraftManager."""
	_craft_manager.set_auto_repeat(node_id, task_id, enabled)

func is_auto_repeat_enabled(node_id: String, task_id: String) -> bool:
	"""Check if auto-repeat is enabled. Delegated to HexCraftManager."""
	return _craft_manager.is_auto_repeat_enabled(node_id, task_id)

func cancel_craft(node_id: String, task_id: String) -> bool:
	"""Cancel a specific craft. Delegated to HexCraftManager."""
	return _craft_manager.cancel_craft(node_id, task_id)

func cancel_all_crafts_for_node(node_id: String) -> int:
	"""Cancel all crafts for a node. Delegated to HexCraftManager."""
	return _craft_manager.cancel_all_crafts_for_node(node_id)

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
		"active_crafts": _craft_manager.get_active_crafts().size() if _craft_manager else 0
	}
