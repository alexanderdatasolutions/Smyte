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
- Building upgrade costs
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal building_placed(node_id: String, building_id: String)
signal building_removed(node_id: String, building_id: String)
signal building_upgraded(node_id: String, building_id: String, new_level: int)
signal buildings_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const BUILDINGS_PATH = "res://data/buildings.json"

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
	"""Load building templates from JSON"""
	var file = FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if not file:
		push_error("BuildingManager: Failed to open buildings file: %s" % BUILDINGS_PATH)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("BuildingManager: Failed to parse buildings JSON: %s" % json.get_error_message())
		return

	var data = json.get_data()

	# Load categories
	_categories = data.get("building_categories", {})

	# Load buildings
	var buildings_data = data.get("buildings", {})
	for building_id in buildings_data:
		var building = buildings_data[building_id].duplicate(true)
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
	buildings_loaded.emit()
	print("BuildingManager: Loaded %d building templates" % _buildings.size())

# ==============================================================================
# BUILDING QUERIES
# ==============================================================================

func get_building(building_id: String) -> Dictionary:
	"""Get building template by ID"""
	return _buildings.get(building_id, {})

func get_all_buildings() -> Dictionary:
	"""Get all building templates"""
	return _buildings

func get_buildings_by_category(category: String) -> Array:
	"""Get all buildings in a category"""
	var result: Array = []
	for building_id in _buildings:
		var building = _buildings[building_id]
		if building.get("category", "") == category:
			result.append(building)
	return result

func get_buildings_by_tier(tier: int) -> Array:
	"""Get all buildings of a specific tier or lower"""
	var result: Array = []
	for building_id in _buildings:
		var building = _buildings[building_id]
		if building.get("tier", 1) <= tier:
			result.append(building)
	return result

func get_available_buildings_for_tile(node: HexNode) -> Array:
	"""Get buildings that can be placed on this tile"""
	if not node or not node.can_place_building():
		return []

	var max_tier = node.get_max_building_tier()
	return get_buildings_by_tier(max_tier)

func get_category(category_id: String) -> Dictionary:
	"""Get category info"""
	return _categories.get(category_id, {})

func get_all_categories() -> Dictionary:
	"""Get all categories"""
	return _categories

func is_loaded() -> bool:
	"""Check if buildings are loaded"""
	return _is_loaded

# ==============================================================================
# BUILDING PRODUCTION
# ==============================================================================

func get_building_production(building_id: String, level: int = 1) -> Dictionary:
	"""Get production output for a building at a specific level"""
	var building = get_building(building_id)
	if building.is_empty():
		return {}

	var base_production = building.get("production", {})
	if base_production.is_empty():
		return {}

	# Apply level scaling
	var level_key = "level_%d" % level
	var multiplier = _upgrade_scaling.get(level_key, 1.0)

	var scaled_production: Dictionary = {}
	for resource_id in base_production:
		scaled_production[resource_id] = int(base_production[resource_id] * multiplier)

	return scaled_production

func get_building_consumption(building_id: String, level: int = 1) -> Dictionary:
	"""Get resource consumption for processing buildings (input cost)"""
	var building = get_building(building_id)
	if building.is_empty():
		return {}

	var base_consumption = building.get("consumes", {})
	if base_consumption.is_empty():
		return {}

	# Apply level scaling to consumption too
	var level_key = "level_%d" % level
	var multiplier = _upgrade_scaling.get(level_key, 1.0)

	var scaled_consumption: Dictionary = {}
	for resource_id in base_consumption:
		scaled_consumption[resource_id] = int(base_consumption[resource_id] * multiplier)

	return scaled_consumption

func get_building_effects(building_id: String) -> Dictionary:
	"""Get special effects for infrastructure buildings"""
	var building = get_building(building_id)
	return building.get("effects", {})

func get_net_production(building_id: String, level: int = 1) -> Dictionary:
	"""Get net production (production - consumption) for display"""
	var production = get_building_production(building_id, level)
	var consumption = get_building_consumption(building_id, level)

	var net: Dictionary = production.duplicate()

	# Subtract consumption
	for resource_id in consumption:
		var consumed = consumption[resource_id]
		if net.has(resource_id):
			net[resource_id] -= consumed
		else:
			net[resource_id] = -consumed

	return net

# ==============================================================================
# BUILDING COSTS
# ==============================================================================

func get_build_cost(building_id: String) -> Dictionary:
	"""Get cost to construct a building"""
	var building = get_building(building_id)
	return building.get("build_cost", {})

func get_upgrade_cost(building_id: String, current_level: int) -> Dictionary:
	"""Get cost to upgrade building to next level"""
	var building = get_building(building_id)
	var base_cost = building.get("build_cost", {})
	var cost_multiplier = building.get("upgrade_cost_multiplier", 1.5)

	# Cost scales exponentially with level
	var total_multiplier = pow(cost_multiplier, current_level)

	var upgrade_cost: Dictionary = {}
	for resource_id in base_cost:
		upgrade_cost[resource_id] = int(base_cost[resource_id] * total_multiplier)

	return upgrade_cost

func get_build_time(building_id: String) -> int:
	"""Get construction time in minutes"""
	var building = get_building(building_id)
	return building.get("build_time_minutes", 30)

func get_max_level(building_id: String) -> int:
	"""Get maximum upgrade level for a building"""
	var building = get_building(building_id)
	return building.get("max_level", 5)

func get_max_workers(building_id: String) -> int:
	"""Get maximum workers for a building"""
	var building = get_building(building_id)
	return building.get("max_workers", 3)

# ==============================================================================
# BUILDING PLACEMENT
# ==============================================================================

func can_place_building(node: HexNode, building_id: String) -> Dictionary:
	"""Check if a building can be placed on a tile
	Returns: {"can_place": bool, "reason": String}
	"""
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

	var building = get_building(building_id)
	if building.is_empty():
		return {"can_place": false, "reason": "Unknown building type"}

	# Check tier requirement
	var building_tier = building.get("tier", 1)
	if building_tier > node.get_max_building_tier():
		return {"can_place": false, "reason": "Requires Tier %d tile (this is Tier %d)" % [building_tier, node.tier]}

	# Building selection is FREE - no cost check needed
	return {"can_place": true, "reason": ""}

func place_building(node: HexNode, building_id: String) -> bool:
	"""Place a building on a tile
	Returns: true if successful
	"""
	var check = can_place_building(node, building_id)
	if not check.can_place:
		push_warning("BuildingManager: Cannot place building - %s" % check.reason)
		return false

	# Building selection is FREE - no resources spent

	# Place the building
	node.placed_building = building_id
	node.building_level = 1
	node.max_workers = get_max_workers(building_id)

	# Update node name and type to reflect the building
	var building = get_building(building_id)
	node.name = building.get("name", building_id.replace("_", " ").capitalize())
	node.node_type = building.get("category", "building")

	# Clear base_production (will be calculated from building)
	node.base_production = {}

	building_placed.emit(node.id, building_id)
	print("BuildingManager: Placed %s on tile %s" % [building_id, node.id])
	return true

func remove_building(node: HexNode, refund_percent: float = 0.5) -> bool:
	"""Remove a building from a tile (with partial refund)
	Returns: true if successful
	"""
	if not node or node.placed_building.is_empty():
		return false

	var building_id = node.placed_building

	# Calculate refund
	if refund_percent > 0:
		var cost = get_build_cost(building_id)
		var refund: Dictionary = {}
		for resource_id in cost:
			refund[resource_id] = int(cost[resource_id] * refund_percent)
		_add_resources(refund)
		print("BuildingManager: Refunded %s for removing %s" % [refund, building_id])

	# Clear the building
	node.placed_building = ""
	node.building_level = 1
	node.base_production = {}
	node.max_workers = 3  # Reset to default

	# Reset node name and type to blank tile
	node.name = "Empty Tile (T%d)" % node.tier
	node.node_type = ""

	building_removed.emit(node.id, building_id)
	print("BuildingManager: Removed %s from tile %s" % [building_id, node.id])
	return true

func can_upgrade_building(node: HexNode) -> Dictionary:
	"""Check if building can be upgraded
	Returns: {"can_upgrade": bool, "reason": String}
	"""
	if not node or node.placed_building.is_empty():
		return {"can_upgrade": false, "reason": "No building to upgrade"}

	var building_id = node.placed_building
	var current_level = node.building_level
	var max_level = get_max_level(building_id)

	if current_level >= max_level:
		return {"can_upgrade": false, "reason": "Already at max level"}

	var cost = get_upgrade_cost(building_id, current_level)
	if not _can_afford(cost):
		return {"can_upgrade": false, "reason": "Insufficient resources"}

	return {"can_upgrade": true, "reason": ""}

func upgrade_building(node: HexNode) -> bool:
	"""Upgrade a building to the next level
	Returns: true if successful
	"""
	var check = can_upgrade_building(node)
	if not check.can_upgrade:
		push_warning("BuildingManager: Cannot upgrade - %s" % check.reason)
		return false

	var building_id = node.placed_building
	var cost = get_upgrade_cost(building_id, node.building_level)

	if not _spend_resources(cost):
		push_error("BuildingManager: Failed to spend resources for upgrade")
		return false

	node.building_level += 1

	building_upgraded.emit(node.id, building_id, node.building_level)
	print("BuildingManager: Upgraded %s to level %d on tile %s" % [building_id, node.building_level, node.id])
	return true

# ==============================================================================
# RESOURCE HELPERS (via SystemRegistry)
# ==============================================================================

func _can_afford(cost: Dictionary) -> bool:
	"""Check if player can afford the cost"""
	var resource_manager = _get_resource_manager()
	if not resource_manager:
		return true  # Fail open if no manager

	for resource_id in cost:
		var amount = cost[resource_id]
		if resource_manager.get_resource(resource_id) < amount:
			return false

	return true

func _spend_resources(cost: Dictionary) -> bool:
	"""Spend resources for construction"""
	var resource_manager = _get_resource_manager()
	if not resource_manager:
		return true  # Fail open if no manager

	for resource_id in cost:
		var amount = cost[resource_id]
		if not resource_manager.spend(resource_id, amount):
			# Try to rollback (best effort)
			push_error("BuildingManager: Failed to spend %d %s" % [amount, resource_id])
			return false

	return true

func _add_resources(resources: Dictionary) -> void:
	"""Add resources to player (for refunds)"""
	var resource_manager = _get_resource_manager()
	if not resource_manager:
		return

	for resource_id in resources:
		var amount = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

func _get_resource_manager():
	"""Get ResourceManager via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("ResourceManager")
	return null

# ==============================================================================
# DEBUG
# ==============================================================================

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"total_buildings": _buildings.size(),
		"categories": _categories.keys(),
		"is_loaded": _is_loaded
	}
