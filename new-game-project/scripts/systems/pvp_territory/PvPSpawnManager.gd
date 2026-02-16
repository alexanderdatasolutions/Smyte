# scripts/systems/pvp_territory/PvPSpawnManager.gd
# Manages player spawning and respawning in PvP hex maps
extends RefCounted
class_name PvPSpawnManager

"""
PvPSpawnManager - Handles player spawn allocation and respawn mechanics
RULE 2: Single responsibility - ONLY manages player spawning
RULE 1: Under 500 lines

Features:
- Fair equidistant spawn allocation
- Respawn at edge when eliminated
- Starter hex generation
- Spawn position reservation
"""

# ==============================================================================
# CONSTANTS
# ==============================================================================

const MAX_PLAYERS := 8
const SPAWN_RING := 4  # Players spawn at ring 4
const STARTER_HEXES_COUNT := 3  # Additional hexes given at spawn
const RESPAWN_COOLDOWN_SECONDS := 60  # Delay before respawn is available


# ==============================================================================
# SPAWN ALLOCATION
# ==============================================================================

## Allocate a spawn position for a new player joining the map
## Returns spawn coordinate and list of starter hex coordinates
static func allocate_spawn(
	player_uid: String,
	player_name: String,
	existing_players: Array,  # Array of player data dicts
	existing_hexes: Dictionary  # PvPHexNode keyed by ID
) -> Dictionary:
	"""Allocate spawn position and starter hexes for a new player

	Args:
		player_uid: Firebase user ID
		player_name: Display name
		existing_players: Array of existing player data
		existing_hexes: Current hex map state

	Returns:
		Dictionary with:
		- spawn_coord: Vector2i
		- spawn_node: PvPHexNode
		- starter_hexes: Array[PvPHexNode]
		- success: bool
		- error: String (if failed)
	"""
	# Check player limit
	if existing_players.size() >= MAX_PLAYERS:
		return {
			"success": false,
			"error": "Map is full (%d/%d players)" % [existing_players.size(), MAX_PLAYERS]
		}

	# Get taken spawn positions
	var taken_spawns: Array[Vector2i] = []
	for player_data: Dictionary in existing_players:
		if player_data.has("spawn_coord"):
			var coord_data: Dictionary = player_data["spawn_coord"]
			taken_spawns.append(Vector2i(coord_data.get("q", 0), coord_data.get("r", 0)))

	# Calculate spawn position
	var player_index := existing_players.size()
	var spawn_coord := PvPMapGenerator.get_spawn_position_for_player(player_index, taken_spawns)

	# Create spawn node
	var spawn_node := PvPHexNode.create_spawn_node(
		spawn_coord.x, spawn_coord.y,
		player_uid, player_name
	)

	# Generate starter hexes
	var starter_hexes := _generate_starter_hexes(
		spawn_coord, player_uid, player_name, existing_hexes
	)

	return {
		"success": true,
		"spawn_coord": spawn_coord,
		"spawn_node": spawn_node,
		"starter_hexes": starter_hexes
	}


## Generate starter hexes adjacent to spawn point
static func _generate_starter_hexes(
	spawn_coord: Vector2i,
	player_uid: String,
	player_name: String,
	existing_hexes: Dictionary
) -> Array[PvPHexNode]:
	"""Generate the initial hexes around a player's spawn"""
	var starter_hexes: Array[PvPHexNode] = []
	var neighbors := HexRingGenerator.get_neighbors(spawn_coord)
	var created_count := 0

	for neighbor: Vector2i in neighbors:
		if created_count >= STARTER_HEXES_COUNT:
			break

		var hex_id := PvPHexNode.coord_to_id(neighbor.x, neighbor.y)

		# Skip if hex already exists and is owned
		if existing_hexes.has(hex_id):
			var existing: PvPHexNode = existing_hexes[hex_id]
			if not existing.is_neutral():
				continue

		# Create or claim the hex
		var hex := PvPHexNode.create_blank_node(neighbor.x, neighbor.y, 1)
		hex.controller_uid = player_uid
		hex.controller_display_name = player_name
		hex.last_captured_at = Time.get_unix_time_from_system()
		starter_hexes.append(hex)
		created_count += 1

	return starter_hexes


# ==============================================================================
# RESPAWN MECHANICS
# ==============================================================================

## Check if a player needs respawn (lost all hexes)
static func check_needs_respawn(
	player_uid: String,
	hexes: Dictionary
) -> bool:
	"""Check if player has no remaining hexes (needs respawn)"""
	for hex: PvPHexNode in hexes.values():
		if hex.controller_uid == player_uid:
			return false
	return true


## Calculate respawn position for eliminated player
static func calculate_respawn_position(
	eliminated_uid: String,
	hexes: Dictionary,
	current_max_ring: int
) -> Dictionary:
	"""Find the best respawn position for an eliminated player

	Args:
		eliminated_uid: Player who was eliminated
		hexes: Current hex map state
		current_max_ring: Maximum ring in current map

	Returns:
		Dictionary with:
		- coord: Vector2i
		- needs_expansion: bool (if new ring needs to be created)
		- new_ring: int (if expansion needed)
	"""
	# First, try to find an empty spot at the edge
	var edge_coords := HexRingGenerator.generate_ring(current_max_ring)
	var available: Array[Vector2i] = []

	for coord: Vector2i in edge_coords:
		var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)
		if hexes.has(hex_id):
			var hex: PvPHexNode = hexes[hex_id]
			# Only use truly neutral hexes (not spawn nodes)
			if hex.is_neutral() and not hex.is_spawn_node:
				available.append(coord)
		else:
			# Position doesn't exist yet - can be used
			available.append(coord)

	if not available.is_empty():
		# Pick position furthest from other players' spawn points
		var best_coord := _find_best_respawn_coord(available, hexes)
		return {
			"coord": best_coord,
			"needs_expansion": false,
			"new_ring": current_max_ring
		}

	# No available positions - need to expand map
	var new_ring := current_max_ring + 1
	var new_ring_coords := HexRingGenerator.generate_ring(new_ring)

	if new_ring_coords.is_empty():
		# Fallback to center of new ring
		return {
			"coord": Vector2i(new_ring, 0),
			"needs_expansion": true,
			"new_ring": new_ring
		}

	return {
		"coord": new_ring_coords[0],
		"needs_expansion": true,
		"new_ring": new_ring
	}


## Find the best respawn coordinate (furthest from other spawns)
static func _find_best_respawn_coord(
	available: Array[Vector2i],
	hexes: Dictionary
) -> Vector2i:
	"""Pick the coordinate with maximum distance to nearest enemy spawn"""
	var spawn_coords: Array[Vector2i] = []

	# Find all existing spawn nodes
	for hex: PvPHexNode in hexes.values():
		if hex.is_spawn_node and hex.coord:
			spawn_coords.append(Vector2i(hex.coord.q, hex.coord.r))

	if spawn_coords.is_empty():
		# No other spawns, pick random
		return available[randi() % available.size()]

	# Find position with maximum minimum distance to any spawn
	var best_coord: Vector2i = available[0]
	var best_min_distance := 0

	for coord: Vector2i in available:
		var min_distance := 999
		for spawn: Vector2i in spawn_coords:
			var distance := HexRingGenerator.get_ring_distance(coord - spawn)
			if distance < min_distance:
				min_distance = distance
		if min_distance > best_min_distance:
			best_min_distance = min_distance
			best_coord = coord

	return best_coord


## Execute respawn for an eliminated player
static func execute_respawn(
	player_uid: String,
	player_name: String,
	hexes: Dictionary,
	current_max_ring: int
) -> Dictionary:
	"""Perform full respawn process for an eliminated player

	Args:
		player_uid: Player being respawned
		player_name: Player's display name
		hexes: Current hex map state
		current_max_ring: Current maximum ring

	Returns:
		Dictionary with:
		- success: bool
		- spawn_node: PvPHexNode
		- starter_hexes: Array[PvPHexNode]
		- expansion_hexes: Array[PvPHexNode] (if map expanded)
		- new_max_ring: int
	"""
	# Find respawn position
	var position_result := calculate_respawn_position(player_uid, hexes, current_max_ring)
	var spawn_coord: Vector2i = position_result["coord"]
	var needs_expansion: bool = position_result["needs_expansion"]
	var new_max_ring: int = position_result["new_ring"]

	var expansion_hexes: Array[PvPHexNode] = []

	# Generate expansion ring if needed
	if needs_expansion:
		var new_ring_coords := HexRingGenerator.generate_ring(new_max_ring)
		for coord: Vector2i in new_ring_coords:
			var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)
			if not hexes.has(hex_id):
				var hex := PvPHexNode.create_blank_node(coord.x, coord.y, 1)
				expansion_hexes.append(hex)

	# Create spawn node
	var spawn_node := PvPHexNode.create_spawn_node(
		spawn_coord.x, spawn_coord.y,
		player_uid, player_name
	)

	# Generate starter hexes
	# Merge existing hexes with expansion for availability check
	var combined_hexes := hexes.duplicate()
	for hex in expansion_hexes:
		combined_hexes[hex.id] = hex

	var starter_hexes := _generate_starter_hexes(
		spawn_coord, player_uid, player_name, combined_hexes
	)

	return {
		"success": true,
		"spawn_node": spawn_node,
		"starter_hexes": starter_hexes,
		"expansion_hexes": expansion_hexes,
		"new_max_ring": new_max_ring
	}


# ==============================================================================
# VALIDATION
# ==============================================================================

## Check if a spawn position is valid
static func is_valid_spawn_position(
	coord: Vector2i,
	hexes: Dictionary
) -> bool:
	"""Check if coordinate can be used as a spawn position"""
	var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)

	# Check if position is already a spawn
	if hexes.has(hex_id):
		var hex: PvPHexNode = hexes[hex_id]
		if hex.is_spawn_node:
			return false
		# Must be neutral or non-existent
		if not hex.is_neutral():
			return false

	return true


## Get all current spawn positions on the map
static func get_all_spawn_positions(hexes: Dictionary) -> Array[Vector2i]:
	"""Return list of all spawn node coordinates"""
	var spawns: Array[Vector2i] = []
	for hex: PvPHexNode in hexes.values():
		if hex.is_spawn_node and hex.coord:
			spawns.append(Vector2i(hex.coord.q, hex.coord.r))
	return spawns


## Get spawn node for a specific player
static func get_player_spawn_node(
	player_uid: String,
	hexes: Dictionary
) -> PvPHexNode:
	"""Find a player's current spawn node (if any)"""
	for hex: PvPHexNode in hexes.values():
		if hex.is_spawn_node and hex.spawn_owner_uid == player_uid:
			return hex
	return null
