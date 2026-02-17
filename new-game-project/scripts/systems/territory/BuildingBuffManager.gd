# scripts/systems/territory/BuildingBuffManager.gd
# Calculates and applies buffs from garrison buildings to nearby hexes
extends Node
class_name BuildingBuffManager

signal buff_radius_changed(source_coord: HexCoord, radius: int, buff_type: String)

var _buildings_data: Dictionary = {}
var _hex_grid_manager = null
var _cached_buffs: Dictionary = {}  # coord_key -> Dictionary of accumulated buffs

func _ready() -> void:
	name = "BuildingBuffManager"
	_load_buildings_data()

func _load_buildings_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if not file:
		push_error("BuildingBuffManager: Could not load buildings.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_buildings_data = parsed.get("buildings", {})

func initialize() -> void:
	"""Initialize buff manager - gets HexGridManager from SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		_hex_grid_manager = registry.get_system("HexGridManager")
	if _hex_grid_manager:
		recalculate_all_buffs()

# ==============================================================================
# BUFF CALCULATION
# ==============================================================================

func recalculate_all_buffs() -> void:
	"""Recalculate all buffs for all hexes"""
	_cached_buffs.clear()

	if not _hex_grid_manager:
		return

	var all_nodes: Array = _hex_grid_manager.get_all_nodes()

	# First find all buildings with buff_radius
	for node in all_nodes:
		if not node or not node.is_controlled_by_player():
			continue
		if node.placed_building.is_empty():
			continue

		var building_data: Dictionary = _buildings_data.get(node.placed_building, {})
		var buff_radius: int = building_data.get("buff_radius", 0)
		var buff_effects: Dictionary = building_data.get("buff_effects", {})

		if buff_radius <= 0 or buff_effects.is_empty():
			continue

		# Apply buffs to all hexes within radius
		_apply_buffs_from_building(node.coord, buff_radius, buff_effects, node.building_level)

func _apply_buffs_from_building(source_coord: HexCoord, radius: int, buff_effects: Dictionary, building_level: int) -> void:
	"""Apply buffs from a building to all hexes within radius"""
	if not _hex_grid_manager:
		return

	# Get all hexes within radius
	var affected_hexes: Array = _hex_grid_manager.get_nodes_within_distance(source_coord, radius)

	# Level scaling for buffs (5% bonus per level)
	var level_multiplier: float = 1.0 + (building_level - 1) * 0.05

	for hex_node in affected_hexes:
		if not hex_node:
			continue

		var coord_key: String = _coord_to_key(hex_node.coord)
		if not _cached_buffs.has(coord_key):
			_cached_buffs[coord_key] = {}

		# Accumulate buffs (multiple buildings can stack)
		for effect_key in buff_effects:
			var base_value: float = buff_effects[effect_key]
			var scaled_value: float = base_value * level_multiplier

			if _cached_buffs[coord_key].has(effect_key):
				_cached_buffs[coord_key][effect_key] += scaled_value
			else:
				_cached_buffs[coord_key][effect_key] = scaled_value

func get_buffs_for_hex(coord: HexCoord) -> Dictionary:
	"""Get all active buffs for a specific hex"""
	if not coord:
		return {}
	return _cached_buffs.get(_coord_to_key(coord), {})

func get_defense_bonus(coord: HexCoord) -> float:
	"""Get the total defense bonus for a hex"""
	var buffs: Dictionary = get_buffs_for_hex(coord)
	return buffs.get("defense_bonus", 0.0)

func get_production_bonus(coord: HexCoord) -> float:
	"""Get the total production bonus for a hex"""
	var buffs: Dictionary = get_buffs_for_hex(coord)
	return buffs.get("production_bonus", 0.0)

func get_garrison_bonus(coord: HexCoord) -> int:
	"""Get the bonus garrison slots for a hex"""
	var buffs: Dictionary = get_buffs_for_hex(coord)
	return int(buffs.get("garrison_bonus", 0))

func get_attack_timer_bonus(coord: HexCoord) -> float:
	"""Get the attack timer bonus hours for a hex"""
	var buffs: Dictionary = get_buffs_for_hex(coord)
	return buffs.get("attack_timer_bonus", 0.0)

# ==============================================================================
# BUFF RADIUS VISUALIZATION
# ==============================================================================

func get_building_buff_radius(building_id: String) -> int:
	"""Get the buff radius for a building type"""
	var building_data: Dictionary = _buildings_data.get(building_id, {})
	return building_data.get("buff_radius", 0)

func get_building_buff_effects(building_id: String) -> Dictionary:
	"""Get the buff effects for a building type"""
	var building_data: Dictionary = _buildings_data.get(building_id, {})
	return building_data.get("buff_effects", {})

func get_hexes_in_buff_radius(source_coord: HexCoord, building_id: String) -> Array:
	"""Get all hex coords that would be affected by a building at source_coord"""
	if not _hex_grid_manager or not source_coord:
		return []

	var radius: int = get_building_buff_radius(building_id)
	if radius <= 0:
		return []

	return _hex_grid_manager.get_nodes_within_distance(source_coord, radius)

func get_buff_summary_text(coord: HexCoord) -> String:
	"""Get a formatted text summary of buffs for UI display"""
	var buffs: Dictionary = get_buffs_for_hex(coord)
	if buffs.is_empty():
		return ""

	var lines: Array[String] = []

	if buffs.has("defense_bonus"):
		lines.append("+%d%% Defense" % int(buffs.defense_bonus * 100))
	if buffs.has("production_bonus"):
		lines.append("+%d%% Production" % int(buffs.production_bonus * 100))
	if buffs.has("garrison_bonus"):
		lines.append("+%d Garrison Slots" % int(buffs.garrison_bonus))
	if buffs.has("attack_timer_bonus"):
		lines.append("+%dh Attack Timer" % int(buffs.attack_timer_bonus))

	return "\n".join(lines)

# ==============================================================================
# HELPER
# ==============================================================================

func _coord_to_key(coord: HexCoord) -> String:
	if not coord:
		return ""
	return "%d,%d" % [coord.q, coord.r]

func on_building_placed(hex_node: HexNode) -> void:
	"""Called when a building is placed - recalculate buffs"""
	recalculate_all_buffs()

	var building_data: Dictionary = _buildings_data.get(hex_node.placed_building, {})
	var buff_radius: int = building_data.get("buff_radius", 0)
	if buff_radius > 0:
		buff_radius_changed.emit(hex_node.coord, buff_radius, "placed")

func on_building_removed(coord: HexCoord) -> void:
	"""Called when a building is removed - recalculate buffs"""
	recalculate_all_buffs()
	buff_radius_changed.emit(coord, 0, "removed")
