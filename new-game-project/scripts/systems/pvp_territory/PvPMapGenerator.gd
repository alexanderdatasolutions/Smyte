# scripts/systems/pvp_territory/PvPMapGenerator.gd
# Generates large PvP hex maps with center objectives and edge spawning
extends RefCounted
class_name PvPMapGenerator

"""
PvPMapGenerator - Creates dynamic 8-player PvP hex maps
RULE 2: Single responsibility - ONLY generates PvP map layouts
RULE 1: Under 500 lines

Map Structure (~800 hexes for 8 players):
- Ring 0-3: TIER 5 (PvP-Exclusive) - 37 high-value contested objectives
- Ring 4-6: Tier 4 (78 nodes) - Secondary contested area
- Ring 7-9: Tier 3 (108 nodes) - Middle ground (expand inward)
- Ring 10-11: PLAYER SPAWNS - Starting positions
- Ring 12-14: Tier 2 (198 nodes) - Expansion outward
- Ring 15-16: Tier 1 (186 nodes) - Outer frontier

Players spawn in the MIDDLE and can expand BOTH directions:
- Inward toward high-value contested center (tiers 5-3)
- Outward into lower-value frontier (tiers 2-1)
"""

# ==============================================================================
# CONSTANTS
# ==============================================================================

const MAX_PLAYERS := 8
const INITIAL_RINGS := 16  # Rings 0-16 = ~817 hexes
const SPAWN_RING_OFFSET := 11  # Players spawn at ring 11 (middle of map)
const STARTER_HEXES := 5  # Additional hexes around spawn point

# Objective node templates for center rings
const CENTER_OBJECTIVES := [
	{
		"name": "Divine Nexus",
		"value": 100,
		"production": {"divine_essence": 50, "mana": 100}
	}
]

const RING_1_OBJECTIVES := [
	{"name": "Celestial Vein", "value": 50, "production": {"celestial_ore": 30}},
	{"name": "Eternal Pyre", "value": 50, "production": {"ember_essence": 30}},
	{"name": "Spirit Well", "value": 50, "production": {"spirit_dust": 30}},
	{"name": "Dragon's Rest", "value": 50, "production": {"dragon_scale": 15}},
	{"name": "Ancient Archive", "value": 50, "production": {"ancient_tome": 10}},
	{"name": "Shadow Rift", "value": 50, "production": {"shadow_essence": 30}}
]

const RING_2_OBJECTIVES := [
	{"name": "Gold Deposit", "value": 30, "production": {"gold": 200}},
	{"name": "Mana Spring", "value": 30, "production": {"mana": 150}},
	{"name": "Crystal Cave", "value": 30, "production": {"crystals": 50}},
	{"name": "Soul Shrine", "value": 30, "production": {"soul_fragments": 25}},
	{"name": "Runic Pillar", "value": 30, "production": {"rune_stones": 20}},
	{"name": "Life Font", "value": 30, "production": {"vitality": 40}},
	{"name": "Storm Altar", "value": 30, "production": {"storm_essence": 25}},
	{"name": "Void Gate", "value": 30, "production": {"void_shards": 15}},
	{"name": "Titan's Forge", "value": 30, "production": {"titan_metal": 20}},
	{"name": "Phoenix Nest", "value": 30, "production": {"phoenix_ash": 15}},
	{"name": "Ice Throne", "value": 30, "production": {"frost_crystal": 25}},
	{"name": "Earth Heart", "value": 30, "production": {"terra_core": 20}}
]

const OUTER_OBJECTIVES := [
	{"name": "Minor Shrine", "value": 15, "production": {"gold": 50}},
	{"name": "Resource Cache", "value": 15, "production": {"mana": 40}},
	{"name": "Scout Tower", "value": 10, "production": {"gold": 30}},
	{"name": "Trading Post", "value": 10, "production": {"gold": 40, "mana": 20}}
]

# Territory name pools by tier
const TERRITORY_NAMES := {
	1: ["Frontier", "Outpost", "Watch", "Clearing", "Camp", "Trail", "Path"],
	2: ["Plains", "Hills", "Woods", "Crossing", "Ford", "Vale", "Glen"],
	3: ["Highlands", "Forest", "Basin", "Ridge", "Hollow", "Marsh", "Glade"],
	4: ["Domain", "Stronghold", "Fortress", "Citadel", "Bastion", "Keep"],
	5: ["Sanctum", "Nexus", "Throne", "Crown", "Pinnacle", "Apex"]
}


# ==============================================================================
# MAP GENERATION
# ==============================================================================

static func generate_initial_map() -> Dictionary:
	"""Generate the initial map structure (before any players join)

	Creates ~800 hexes for epic 8-player battles.
	Tier 5 is PvP-EXCLUSIVE (rings 0-3, ~37 nodes near center).

	Tier Distribution:
	- Rings 0-3: Tier 5 (37 nodes) - PvP exclusive, highly contested
	- Rings 4-6: Tier 4 (78 nodes) - Secondary contested area
	- Rings 7-10: Tier 3 (162 nodes) - Middle ground
	- Rings 11-14: Tier 2 (234 nodes) - Expansion territory
	- Rings 15-16: Tier 1 (186 nodes) - Outer territory

	Returns:
		Dictionary with:
		- hexes: Dictionary[String, PvPHexNode] keyed by hex ID
		- config: Map configuration data
	"""
	var hexes: Dictionary = {}
	var name_counters: Dictionary = {}  # Track used names

	# ==== TIER 5: PvP-EXCLUSIVE CENTER (Rings 0-3) ====
	# Ring 0: Legendary center objective
	var center_node: PvPHexNode = _create_center_objective()
	hexes[center_node.id] = center_node

	# Ring 1: 6 high-value tier 5 objectives
	var ring_1_coords: Array[Vector2i] = HexRingGenerator.generate_ring(1)
	for i in range(ring_1_coords.size()):
		var coord: Vector2i = ring_1_coords[i]
		var template: Dictionary = RING_1_OBJECTIVES[i % RING_1_OBJECTIVES.size()]
		var node: PvPHexNode = PvPHexNode.create_objective_node(
			coord.x, coord.y,
			template["name"],
			template["value"],
			template["production"]
		)
		node.tier = 5
		hexes[node.id] = node

	# Ring 2: 12 tier 5 objectives
	var ring_2_coords: Array[Vector2i] = HexRingGenerator.generate_ring(2)
	for i in range(ring_2_coords.size()):
		var coord: Vector2i = ring_2_coords[i]
		var template: Dictionary = RING_2_OBJECTIVES[i % RING_2_OBJECTIVES.size()]
		var node: PvPHexNode = PvPHexNode.create_objective_node(
			coord.x, coord.y,
			template["name"],
			template["value"],
			template["production"]
		)
		node.tier = 5
		hexes[node.id] = node

	# Ring 3: 18 tier 5 territories (contested approaches to center)
	var ring_3_coords: Array[Vector2i] = HexRingGenerator.generate_ring(3)
	for i in range(ring_3_coords.size()):
		var coord: Vector2i = ring_3_coords[i]
		if i % 3 == 0:  # Every 3rd is an objective
			var template: Dictionary = OUTER_OBJECTIVES[i % OUTER_OBJECTIVES.size()]
			var node: PvPHexNode = PvPHexNode.create_objective_node(
				coord.x, coord.y,
				template["name"] + " Prime",
				template["value"] * 2,
				template["production"]
			)
			node.tier = 5
			hexes[node.id] = node
		else:
			var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 5, name_counters)
			hexes[node.id] = node

	# ==== TIER 4: SECONDARY CONTESTED (Rings 4-6) ====
	for ring: int in range(4, 7):
		var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
		for i in range(ring_coords.size()):
			var coord: Vector2i = ring_coords[i]
			if i % 5 == 0:  # Occasional objectives
				var template: Dictionary = OUTER_OBJECTIVES[i % OUTER_OBJECTIVES.size()]
				var node: PvPHexNode = PvPHexNode.create_objective_node(
					coord.x, coord.y,
					template["name"],
					template["value"],
					template["production"]
				)
				node.tier = 4
				hexes[node.id] = node
			else:
				var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 4, name_counters)
				hexes[node.id] = node

	# ==== TIER 3: CONTESTED MIDDLE (Rings 7-9) - Expand INWARD from spawn ====
	for ring: int in range(7, 10):
		var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
		for i in range(ring_coords.size()):
			var coord: Vector2i = ring_coords[i]
			if i % 8 == 0:  # Rare objectives
				var template: Dictionary = OUTER_OBJECTIVES[i % OUTER_OBJECTIVES.size()]
				var node: PvPHexNode = PvPHexNode.create_objective_node(
					coord.x, coord.y,
					template["name"],
					int(template["value"] * 0.7),
					template["production"]
				)
				node.tier = 3
				hexes[node.id] = node
			else:
				var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 3, name_counters)
				hexes[node.id] = node

	# ==== TIER 2: SPAWN BUFFER ZONE (Rings 10-11) - Where players start ====
	for ring: int in range(10, 12):
		var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
		for coord: Vector2i in ring_coords:
			var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 2, name_counters)
			hexes[node.id] = node

	# ==== TIER 2: OUTWARD EXPANSION (Rings 12-14) ====
	for ring: int in range(12, 15):
		var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
		for coord: Vector2i in ring_coords:
			var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 2, name_counters)
			hexes[node.id] = node

	# ==== TIER 1: OUTER FRONTIER (Rings 15-16) ====
	for ring: int in range(15, 17):
		var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
		for coord: Vector2i in ring_coords:
			var node: PvPHexNode = _create_named_territory(coord.x, coord.y, 1, name_counters)
			hexes[node.id] = node

	var config := {
		"current_max_ring": INITIAL_RINGS,
		"player_count": 0,
		"spawn_positions": _calculate_spawn_positions(MAX_PLAYERS),
		"created_at": Time.get_unix_time_from_system()
	}

	return {"hexes": hexes, "config": config}


static func _create_center_objective() -> PvPHexNode:
	"""Create the legendary center objective"""
	var template: Dictionary = CENTER_OBJECTIVES[0]
	var node := PvPHexNode.create_objective_node(
		0, 0,
		template["name"],
		template["value"],
		template["production"]
	)
	node.id = "center_objective"
	node.tier = 5  # Legendary tier
	node.capture_power_required = 50000  # Very high requirement
	return node


static func _create_named_territory(q: int, r: int, tier: int, name_counters: Dictionary) -> PvPHexNode:
	"""Create a territory with a procedural name"""
	var names: Array[String] = []
	var raw_names: Array = TERRITORY_NAMES.get(tier, TERRITORY_NAMES[1])
	for n: String in raw_names:
		names.append(n)
	var base_name: String = names[randi() % names.size()]

	# Add a unique suffix
	if not name_counters.has(base_name):
		name_counters[base_name] = 0
	name_counters[base_name] += 1

	var full_name: String = base_name
	if name_counters[base_name] > 1:
		full_name = "%s %s" % [base_name, _number_to_roman(name_counters[base_name])]

	var node: PvPHexNode = PvPHexNode.create_blank_node(q, r, tier)
	node.name = full_name
	return node


static func _number_to_roman(num: int) -> String:
	"""Convert number to roman numeral (for territory naming)"""
	if num <= 1:
		return ""
	if num == 2:
		return "II"
	if num == 3:
		return "III"
	if num == 4:
		return "IV"
	if num == 5:
		return "V"
	if num == 6:
		return "VI"
	if num == 7:
		return "VII"
	if num == 8:
		return "VIII"
	if num == 9:
		return "IX"
	if num == 10:
		return "X"
	return str(num)


# ==============================================================================
# PLAYER SPAWN EXPANSION
# ==============================================================================

static func _calculate_spawn_positions(num_players: int) -> Array[Vector2i]:
	"""Calculate equidistant spawn positions for players

	All spawn positions are at the same ring distance from center,
	evenly distributed around the ring.
	"""
	var spawn_ring: int = SPAWN_RING_OFFSET
	var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(spawn_ring)
	var positions: Array[Vector2i] = []

	# Calculate spacing to distribute players evenly
	var spacing: int = ring_coords.size() / num_players

	for i: int in range(num_players):
		var index: int = int(i * spacing) % ring_coords.size()
		positions.append(ring_coords[index])

	return positions


static func get_spawn_position_for_player(player_index: int, existing_spawns: Array[Vector2i]) -> Vector2i:
	"""Get spawn position for a new player

	Args:
		player_index: Index of the player (0-7)
		existing_spawns: Already used spawn positions

	Returns:
		Vector2i coordinate for the player's spawn
	"""
	var spawn_ring: int = SPAWN_RING_OFFSET
	var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(spawn_ring)
	var spacing: int = ring_coords.size() / MAX_PLAYERS

	# Get the ideal position for this player index
	var ideal_index: int = int(player_index * spacing) % ring_coords.size()
	var position: Vector2i = ring_coords[ideal_index]

	# If position is taken, find nearest available
	if position in existing_spawns:
		for offset: int in range(1, ring_coords.size()):
			var check_idx: int = (ideal_index + offset) % ring_coords.size()
			var check_pos: Vector2i = ring_coords[check_idx]
			if check_pos not in existing_spawns:
				return check_pos

	return position


static func generate_spawn_hexes_for_player(
	spawn_coord: Vector2i,
	player_uid: String,
	player_name: String,
	existing_hexes: Dictionary
) -> Dictionary:
	"""Generate spawn node and claim starter hexes for a new player

	IMPORTANT: This function now CLAIMS existing hexes rather than creating new ones.
	The spawn node replaces the existing hex at spawn_coord.
	Adjacent hexes are claimed from existing_hexes (ownership transferred).

	Args:
		spawn_coord: The player's spawn position
		player_uid: Firebase user ID
		player_name: Display name
		existing_hexes: Current hex dictionary - MODIFIED IN PLACE for claimed hexes

	Returns:
		Dictionary with spawn node to add (starter hexes are claimed in-place)
	"""
	var new_hexes: Dictionary = {}

	# Create the spawn node (protected) - replaces existing hex at this coord
	var spawn_node: PvPHexNode = PvPHexNode.create_spawn_node(
		spawn_coord.x, spawn_coord.y,
		player_uid, player_name
	)
	new_hexes[spawn_node.id] = spawn_node

	# Claim existing hexes adjacent to spawn (ring 1 from spawn)
	var neighbors: Array[Vector2i] = HexRingGenerator.get_neighbors(spawn_coord)
	var starter_count: int = 0

	for neighbor: Vector2i in neighbors:
		if starter_count >= STARTER_HEXES:
			break

		var hex_id := PvPHexNode.coord_to_id(neighbor.x, neighbor.y)

		# CLAIM existing hex (don't create new ones)
		if existing_hexes.has(hex_id):
			var hex: PvPHexNode = existing_hexes[hex_id]
			if hex.is_neutral() and not hex.is_spawn_node:
				hex.controller_uid = player_uid
				hex.controller_display_name = player_name
				hex.last_captured_at = int(Time.get_unix_time_from_system())
				starter_count += 1

	# Also claim some ring 2 hexes around spawn
	var ring_2: Array[Vector2i] = _generate_ring_at(spawn_coord, 2)
	var ring_2_count: int = 0
	for coord: Vector2i in ring_2:
		if ring_2_count >= 4:  # Give 4 ring-2 hexes
			break
		var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)
		if existing_hexes.has(hex_id):
			var hex: PvPHexNode = existing_hexes[hex_id]
			if hex.is_neutral() and not hex.is_spawn_node:
				hex.controller_uid = player_uid
				hex.controller_display_name = player_name
				hex.last_captured_at = int(Time.get_unix_time_from_system())
				ring_2_count += 1

	return new_hexes


# ==============================================================================
# MAP EXPANSION
# ==============================================================================

static func expand_map_for_new_player(
	current_hexes: Dictionary,
	current_max_ring: int,
	_player_index: int
) -> Dictionary:
	"""Expand map edge when a new player joins

	Creates new ring of hexes if needed to accommodate spawn.

	Args:
		current_hexes: Existing hex dictionary
		current_max_ring: Current maximum ring distance
		_player_index: Index of joining player (0-7)

	Returns:
		Dictionary of new hexes to add (not including spawn hexes)
	"""
	var new_hexes: Dictionary = {}
	var spawn_ring: int = SPAWN_RING_OFFSET

	# If spawn ring doesn't exist yet, create it and intermediate rings
	if current_max_ring < spawn_ring:
		for ring: int in range(current_max_ring + 1, spawn_ring + 1):
			var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(ring)
			var tier: int = clampi(3 - (ring - current_max_ring), 1, 2)  # Lower tiers for outer rings
			for coord: Vector2i in ring_coords:
				var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)
				if not current_hexes.has(hex_id) and not new_hexes.has(hex_id):
					var node: PvPHexNode = PvPHexNode.create_blank_node(coord.x, coord.y, tier)
					new_hexes[hex_id] = node

	return new_hexes


# ==============================================================================
# RESPAWN SUPPORT
# ==============================================================================

static func find_respawn_position(
	_eliminated_uid: String,
	current_hexes: Dictionary,
	current_max_ring: int
) -> Vector2i:
	"""Find a new spawn position for an eliminated player

	Looks for available positions at the edge of the map.

	Args:
		_eliminated_uid: The player who needs respawn
		current_hexes: Current hex dictionary
		current_max_ring: Current maximum ring distance

	Returns:
		Vector2i coordinate for respawn, or Vector2i.ZERO if none found
	"""
	# Look for empty positions at the edge ring
	var edge_ring: int = current_max_ring
	var ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(edge_ring)

	# Find positions that aren't owned by anyone
	var available: Array[Vector2i] = []
	for coord: Vector2i in ring_coords:
		var hex_id := PvPHexNode.coord_to_id(coord.x, coord.y)
		if current_hexes.has(hex_id):
			var hex: PvPHexNode = current_hexes[hex_id]
			if hex.is_neutral() and not hex.is_spawn_node:
				available.append(coord)

	if available.is_empty():
		# Expand to new ring
		var new_ring: int = edge_ring + 1
		var new_ring_coords: Array[Vector2i] = HexRingGenerator.generate_ring(new_ring)
		if not new_ring_coords.is_empty():
			return new_ring_coords[0]
		return Vector2i.ZERO

	# Pick a random available position
	return available[randi() % available.size()]


# ==============================================================================
# UTILITIES
# ==============================================================================

static func _generate_ring_at(center: Vector2i, ring_distance: int) -> Array[Vector2i]:
	"""Generate ring coordinates around a specific center point (not origin)"""
	var ring: Array[Vector2i] = HexRingGenerator.generate_ring(ring_distance)
	var result: Array[Vector2i] = []
	for coord: Vector2i in ring:
		result.append(coord + center)
	return result


static func get_ring_for_coord(coord: Vector2i) -> int:
	"""Get which ring a coordinate belongs to"""
	return HexRingGenerator.get_ring_distance(coord)


static func get_adjacent_player_hexes(
	coord: Vector2i,
	player_uid: String,
	hexes: Dictionary
) -> Array[PvPHexNode]:
	"""Get adjacent hexes controlled by a specific player"""
	var result: Array[PvPHexNode] = []
	var neighbors: Array[Vector2i] = HexRingGenerator.get_neighbors(coord)

	for neighbor: Vector2i in neighbors:
		var hex_id := PvPHexNode.coord_to_id(neighbor.x, neighbor.y)
		if hexes.has(hex_id):
			var hex: PvPHexNode = hexes[hex_id]
			if hex.controller_uid == player_uid:
				result.append(hex)

	return result


static func count_player_hexes(player_uid: String, hexes: Dictionary) -> int:
	"""Count total hexes controlled by a player"""
	var count: int = 0
	for hex: PvPHexNode in hexes.values():
		if hex.controller_uid == player_uid:
			count += 1
	return count


static func get_player_objective_score(player_uid: String, hexes: Dictionary) -> int:
	"""Calculate total objective value for a player"""
	var score: int = 0
	for hex: PvPHexNode in hexes.values():
		if hex.controller_uid == player_uid and hex.is_objective:
			score += hex.objective_value
	return score


static func get_total_hex_count() -> int:
	"""Get estimated total hex count for display purposes"""
	# Ring 0: 1
	# Ring n: 6*n hexes
	# Rings 0-16: 1 + 6 + 12 + ... + 96 = 817 hexes
	# This gives ~100 hexes per player for 8-player battles
	var total: int = 1  # center
	for ring: int in range(1, INITIAL_RINGS + 1):
		total += 6 * ring
	return total


static func get_tier_distribution() -> Dictionary:
	"""Get breakdown of hexes by tier for display"""
	# Rings 0-3: 37, Rings 4-6: 78, Rings 7-9: 108
	# Rings 10-14: 330 (tier 2), Rings 15-16: 186 (tier 1)
	return {
		5: 37,   # Rings 0-3 (PvP-exclusive center)
		4: 78,   # Rings 4-6 (secondary contested)
		3: 108,  # Rings 7-9 (expand inward target)
		2: 330,  # Rings 10-14 (spawn zone + outward)
		1: 186   # Rings 15-16 (outer frontier)
	}
