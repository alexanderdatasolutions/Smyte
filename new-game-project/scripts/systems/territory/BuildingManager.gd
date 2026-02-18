# scripts/systems/territory/BuildingManager.gd
# Manages building templates, placement, and production calculations
extends Node
class_name BuildingManager

"""
BuildingManager - Building system for hex tiles
RULE 2: Single responsibility - Building data and placement logic only
RULE 5: Uses SystemRegistry for all system access

Handles:
- Loading building templates from buildings.json
- Building placement/removal on tiles
- Building production calculations
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal building_placed(node_id: String, building_id: String)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const BUILDINGS_PATH: String = "res://data/buildings.json"

# ==============================================================================
# STATE
# ==============================================================================
var _buildings: Dictionary = {}  # building_id -> building template
var _categories: Dictionary = {}  # category_id -> category info
var _upgrade_scaling: Dictionary = {}  # level -> multiplier
var _is_loaded: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	load_buildings()

func load_buildings() -> void:
	var file := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if not file:
		push_error("BuildingManager: Failed to open buildings file: %s" % BUILDINGS_PATH)
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("BuildingManager: Failed to parse buildings JSON: %s" % json.get_error_message())
		return

	var data: Dictionary = json.get_data()

	# Load categories
	_categories = data.get("building_categories", {})

	# Load buildings
	var buildings_data: Dictionary = data.get("buildings", {})
	for building_id: String in buildings_data:
		var building: Dictionary = buildings_data[building_id].duplicate(true)
		building["id"] = building_id
		_buildings[building_id] = building

	# Load upgrade scaling
	_upgrade_scaling = data.get("upgrade_scaling", {
		"level_1": 1.0,
		"level_2": 1.15,
		"level_3": 1.35,
		"level_4": 1.60,
		"level_5": 2.00
	})

	_is_loaded = true

# ==============================================================================
# BUILDING QUERIES
# ==============================================================================

func get_building(building_id: String) -> Dictionary:
	return _buildings.get(building_id, {})

func get_buildings_by_tier(tier: int) -> Array:
	var result: Array = []
	for building_id: String in _buildings:
		var building: Dictionary = _buildings[building_id]
		if building.get("tier", 1) <= tier:
			result.append(building)
	return result

func get_available_buildings_for_tile(node: HexNode) -> Array:
	if not node or not node.can_place_building():
		return []

	var max_tier: int = node.get_max_building_tier()
	return get_buildings_by_tier(max_tier)

# ==============================================================================
# BUILDING PRODUCTION
# ==============================================================================

func get_building_production(building_id: String, level: int = 1) -> Dictionary:
	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return {}

	var base_production: Dictionary = building.get("production", {})
	if base_production.is_empty():
		return {}

	# Apply level scaling
	var level_key: String = "level_%d" % level
	var multiplier: float = _upgrade_scaling.get(level_key, 1.0)

	var scaled_production: Dictionary = {}
	for resource_id: String in base_production:
		scaled_production[resource_id] = int(base_production[resource_id] * multiplier)

	return scaled_production

# ==============================================================================
# BUILDING COSTS
# ==============================================================================

func get_build_cost(building_id: String) -> Dictionary:
	var building: Dictionary = get_building(building_id)
	return building.get("build_cost", {})

func get_max_workers(building_id: String) -> int:
	var building: Dictionary = get_building(building_id)
	return building.get("max_workers", 3)

# ==============================================================================
# BUILDING PLACEMENT
# ==============================================================================

func can_place_building(node: HexNode, building_id: String) -> Dictionary:
	if not node:
		return {"can_place": false, "reason": "Invalid tile"}

	if not node.can_place_building():
		if node.is_special_node:
			return {"can_place": false, "reason": "Special nodes cannot have buildings"}
		if not node.is_buildable:
			return {"can_place": false, "reason": "This tile is not buildable"}
		if not node.placed_building.is_empty():
			return {"can_place": false, "reason": "Tile already has a building"}
		if node.controller != "player":
			return {"can_place": false, "reason": "You don't control this tile"}

	var building: Dictionary = get_building(building_id)
	if building.is_empty():
		return {"can_place": false, "reason": "Unknown building type"}

	# Check tier requirement
	var building_tier: int = building.get("tier", 1)
	if building_tier > node.get_max_building_tier():
		return {"can_place": false, "reason": "Requires Tier %d tile (this is Tier %d)" % [building_tier, node.tier]}

	return {"can_place": true, "reason": ""}

func place_building(node: HexNode, building_id: String) -> bool:
	var check: Dictionary = can_place_building(node, building_id)
	if not check.can_place:
		push_warning("BuildingManager: Cannot place building - %s" % check.reason)
		return false

	# Place the building
	node.placed_building = building_id
	node.building_level = 1
	node.max_workers = get_max_workers(building_id)

	# Update node name and type to reflect the building
	var building: Dictionary = get_building(building_id)
	node.name = building.get("name", building_id.replace("_", " ").capitalize())
	node.node_type = building.get("category", "building")

	# Clear base_production (will be calculated from building)
	node.base_production = {}

	building_placed.emit(node.id, building_id)

	# Trigger save to persist the new building
	var registry: Node = SystemRegistry.get_instance()
	var event_bus: Node = registry.get_system("EventBus") if registry else null
	if event_bus:
		event_bus.save_requested.emit()

	return true

func remove_building(node: HexNode, refund_percent: float = 0.5) -> bool:
	if not node or node.placed_building.is_empty():
		return false

	var building_id: String = node.placed_building

	# Calculate refund
	if refund_percent > 0:
		var cost: Dictionary = get_build_cost(building_id)
		var refund: Dictionary = {}
		for resource_id: String in cost:
			refund[resource_id] = int(cost[resource_id] * refund_percent)
		_add_resources(refund)

	# Clear the building
	node.placed_building = ""
	node.building_level = 1
	node.base_production = {}
	node.max_workers = 3  # Reset to default

	# Reset node name and type to blank tile
	node.name = "Empty Tile (T%d)" % node.tier
	node.node_type = ""

	# Trigger save to persist the building removal
	var registry: Node = SystemRegistry.get_instance()
	var event_bus: Node = registry.get_system("EventBus") if registry else null
	if event_bus:
		event_bus.save_requested.emit()

	return true

# ==============================================================================
# RESOURCE HELPERS (via SystemRegistry)
# ==============================================================================

func _add_resources(resources: Dictionary) -> void:
	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		return

	for resource_id: String in resources:
		var amount: int = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

func _get_resource_manager() -> Node:
	var registry := SystemRegistry.get_instance()
	if registry:
		return registry.get_system("ResourceManager")
	return null
