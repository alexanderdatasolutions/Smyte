# scripts/systems/territory/NodeRequirementChecker.gd
# Checks if player can capture hex nodes based on requirements
extends Node
class_name NodeRequirementChecker

"""
NodeRequirementChecker.gd - Node unlock requirement validation system
RULE 1: Under 500 lines - Single responsibility
RULE 2: SystemRegistry pattern - Access other systems via registry
RULE 3: Logic in systems, not data classes

Following CLAUDE.md architecture:
- Checks player level requirements
- Checks adjacent garrison requirements
- Checks combat power requirements
- Integration with PlayerProgressionManager
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal requirement_check_failed(node_id: String, missing_requirements: Array)
signal node_unlocked(node_id: String)

# ==============================================================================
# DEPENDENCIES
# ==============================================================================
var _player_progression_manager: PlayerProgressionManager = null
var _collection_manager = null
var _hex_grid_manager: HexGridManager = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_resolve_dependencies()

func _resolve_dependencies() -> void:
	"""Get references to required systems"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("NodeRequirementChecker: SystemRegistry not available")
		return

	_player_progression_manager = registry.get_system("PlayerProgressionManager")
	_collection_manager = registry.get_system("CollectionManager")
	_hex_grid_manager = registry.get_system("HexGridManager")

	if not _player_progression_manager:
		push_warning("NodeRequirementChecker: PlayerProgressionManager not found")
	if not _collection_manager:
		push_warning("NodeRequirementChecker: CollectionManager not found")
	if not _hex_grid_manager:
		push_warning("NodeRequirementChecker: HexGridManager not found")

# ==============================================================================
# MAIN REQUIREMENT CHECKING
# ==============================================================================

func can_player_capture_node(node: HexNode) -> bool:
	"""Check if player meets all requirements to capture a node"""
	if not node:
		return false

	# Check all individual requirements
	var level_ok = check_level_requirement(node)
	var adjacent_ok = check_adjacent_garrison_requirement(node)

	if not level_ok:
		return false

	if not adjacent_ok:
		return false

	# Power requirement is checked during battle, not here
	# (player can attempt capture if other requirements met)

	return true

func get_missing_requirements(node: HexNode) -> Array:
	"""Get list of missing requirements as human-readable strings"""
	var missing: Array = []

	if not node:
		return missing

	# Check adjacent garrison requirement
	if not check_adjacent_garrison_requirement(node):
		missing.append("Adjacent garrisoned territory required")

	# Check level requirement
	if not check_level_requirement(node):
		var required_level = node.get_required_level()
		var current_level = _get_player_level()
		missing.append("Player Level %d (currently %d)" % [required_level, current_level])

	# Power requirement (informational)
	if not check_power_requirement(node):
		var required_power = node.capture_power_required
		var current_power = _get_player_total_power()
		missing.append("Combat Power %d (currently %d)" % [required_power, current_power])

	return missing

# ==============================================================================
# INDIVIDUAL REQUIREMENT CHECKS
# ==============================================================================

func check_level_requirement(node: HexNode) -> bool:
	"""Check if player level meets node requirement"""
	if not node:
		return false

	var required_level = node.get_required_level()
	var current_level = _get_player_level()

	return current_level >= required_level

func check_power_requirement(node: HexNode) -> bool:
	"""Check if player has enough combat power to capture node"""
	if not node:
		return false

	var required_power = node.capture_power_required
	var current_power = _get_player_total_power()

	return current_power >= required_power

func check_adjacent_garrison_requirement(node: HexNode) -> bool:
	"""Check if player has an adjacent node with a garrison to launch attack from"""
	if not node:
		return false

	# Home base (T0) doesn't require adjacent garrison
	if node.tier == 0 or node.node_type == "base":
		return true

	if not _hex_grid_manager:
		# If we can't check, be permissive
		return true

	# Get neighbors of this node
	var neighbors = _hex_grid_manager.get_neighbors(node.coord)

	for neighbor in neighbors:
		# Check if neighbor is player-controlled AND has a garrison
		if neighbor.controller == "player":
			if neighbor.garrison.size() > 0:
				return true
			# Home base always counts (can attack from home even without garrison)
			if neighbor.node_type == "base" or neighbor.id == "home_base":
				return true

	return false

# ==============================================================================
# PLAYER STAT HELPERS
# ==============================================================================

func _get_player_level() -> int:
	"""Get current player level"""
	if not _player_progression_manager:
		return 1

	return _player_progression_manager.get_player_level()

func _get_player_total_power() -> int:
	"""Get total combat power of player's collection"""
	if not _collection_manager:
		return 0

	var owned_gods = _collection_manager.get_owned_gods()
	var total_power = 0

	for god_data in owned_gods:
		total_power += _calculate_god_power(god_data)

	return total_power

func _calculate_god_power(god) -> int:
	"""Calculate a single god's combat power using GodCalculator (single source of truth)"""
	if not god:
		return 0

	# Use GodCalculator for consistent power calculation across the game
	if god is God:
		return GodCalculator.get_power_rating(god)

	# Fallback for dictionary-based god data (shouldn't happen normally)
	return int(god.get("base_hp", 0) + god.get("base_attack", 0) + god.get("base_defense", 0) + god.get("base_speed", 0))

# ==============================================================================
# REQUIREMENT DESCRIPTION HELPERS
# ==============================================================================

func get_requirement_description(node: HexNode) -> String:
	"""Get a full description of node requirements"""
	if not node:
		return "Unknown requirements"

	var parts: Array = []

	# Level
	var required_level = node.get_required_level()
	parts.append("Level %d" % required_level)

	# Power
	parts.append("%d Combat Power" % node.capture_power_required)

	return ", ".join(parts)

func get_requirement_status(node: HexNode) -> Dictionary:
	"""Get detailed status of each requirement (for UI display)"""
	if not node:
		return {}

	return {
		"adjacent_garrison": {
			"required": true,
			"met": check_adjacent_garrison_requirement(node)
		},
		"level": {
			"required": node.get_required_level(),
			"current": _get_player_level(),
			"met": check_level_requirement(node)
		},
		"power": {
			"required": node.capture_power_required,
			"current": _get_player_total_power(),
			"met": check_power_requirement(node)
		},
		"can_capture": can_player_capture_node(node)
	}

# ==============================================================================
# TIER-BASED HELPERS
# ==============================================================================

func get_unlockable_tier() -> int:
	"""Get the highest tier of nodes the player can unlock"""
	# No level requirements - tiers unlocked by adjacency and combat power
	# T4 nodes still require pvp_expansion flag (checked separately)
	return 5

func can_unlock_tier(tier: int) -> bool:
	"""Check if player can unlock nodes of this tier"""
	return get_unlockable_tier() >= tier

func get_next_tier_requirement() -> String:
	"""Get what's needed to unlock the next tier"""
	# No tier requirements anymore - just need adjacency and combat power
	return "All tiers unlocked"

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving (currently no persistent state)"""
	return {}

func load_save_data(_data: Dictionary) -> void:
	"""Load saved data (currently no persistent state)"""
	pass
