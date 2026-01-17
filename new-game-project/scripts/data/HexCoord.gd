# scripts/data/HexCoord.gd
# Data class for hexagonal grid coordinates using axial coordinate system
extends Resource
class_name HexCoord

# Axial coordinates (q, r)
# q = column, r = row
@export var q: int = 0
@export var r: int = 0

func _init(coord_q: int = 0, coord_r: int = 0):
	q = coord_q
	r = coord_r

# === COORDINATE OPERATIONS ===

func distance_to(other: HexCoord) -> int:
	"""Calculate distance to another hex coordinate using axial distance formula"""
	if other == null:
		return 0
	return (abs(q - other.q) + abs(q + r - other.q - other.r) + abs(r - other.r)) / 2

func get_neighbors() -> Array[HexCoord]:
	"""Get all 6 neighboring hex coordinates"""
	var neighbors: Array[HexCoord] = []
	# The 6 directions in axial coordinates
	var directions = [
		[1, 0],   # East
		[-1, 0],  # West
		[0, 1],   # Southeast
		[0, -1],  # Northwest
		[1, -1],  # Northeast
		[-1, 1]   # Southwest
	]

	for dir in directions:
		var script = load("res://scripts/data/HexCoord.gd")
		var neighbor = script.new(q + dir[0], r + dir[1])
		neighbors.append(neighbor)

	return neighbors

func equals(other: HexCoord) -> bool:
	"""Check if two hex coordinates are equal"""
	if other == null:
		return false
	return q == other.q and r == other.r

func as_string() -> String:
	"""Convert to string representation"""
	return "HexCoord(q=%d, r=%d)" % [q, r]

# === SERIALIZATION ===

func to_dict() -> Dictionary:
	"""Serialize to dictionary"""
	return {
		"q": q,
		"r": r
	}

static func from_dict(data: Dictionary):
	"""Create HexCoord from dictionary"""
	var script = load("res://scripts/data/HexCoord.gd")
	var coord = script.new()
	coord.q = data.get("q", 0)
	coord.r = data.get("r", 0)
	return coord

static func from_qr(coord_q: int, coord_r: int):
	"""Create HexCoord from q and r values"""
	var script = load("res://scripts/data/HexCoord.gd")
	return script.new(coord_q, coord_r)

# === HELPER METHODS ===

func get_ring(_radius: int) -> int:
	"""Get which ring this coordinate is in (distance from origin)"""
	var script = load("res://scripts/data/HexCoord.gd")
	var origin = script.new(0, 0)
	return distance_to(origin)

func is_origin() -> bool:
	"""Check if this is the origin coordinate (0,0)"""
	return q == 0 and r == 0

# Cube coordinates conversion (for some algorithms)
func to_cube() -> Dictionary:
	"""Convert to cube coordinates (x, y, z)"""
	var x = q
	var z = r
	var y = -x - z
	return {"x": x, "y": y, "z": z}

static func from_cube(x: int, _y: int, z: int):
	"""Create HexCoord from cube coordinates"""
	var script = load("res://scripts/data/HexCoord.gd")
	return script.new(x, z)
