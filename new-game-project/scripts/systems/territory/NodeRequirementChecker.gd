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
- Checks specialization tier requirements
- Checks specialization role matching for tier 4+ nodes
- Checks combat power requirements
- Integration with SpecializationManager and PlayerProgressionManager
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal requirement_check_failed(node_id: String, missing_requirements: Array)
signal node_unlocked(node_id: String)

# ==============================================================================
# DEPENDENCIES
# ==============================================================================
var _specialization_manager: SpecializationManager = null
var _player_progression_manager: PlayerProgressionManager = null
var _collection_manager = null

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

	_specialization_manager = registry.get_system("SpecializationManager")
	_player_progression_manager = registry.get_system("PlayerProgressionManager")
	_collection_manager = registry.get_system("CollectionManager")

	if not _specialization_manager:
		push_warning("NodeRequirementChecker: SpecializationManager not found")
	if not _player_progression_manager:
		push_warning("NodeRequirementChecker: PlayerProgressionManager not found")
	if not _collection_manager:
		push_warning("NodeRequirementChecker: CollectionManager not found")

# ==============================================================================
# MAIN REQUIREMENT CHECKING
# ==============================================================================

func can_player_capture_node(node: HexNode) -> bool:
	"""Check if player meets all requirements to capture a node"""
	if not node:
		return false

	# Check all individual requirements
	if not check_level_requirement(node):
		return false

	if not check_specialization_requirement(node):
		return false

	# Power requirement is checked during battle, not here
	# (player can attempt capture if other requirements met)

	return true

func get_missing_requirements(node: HexNode) -> Array:
	"""Get list of missing requirements as human-readable strings"""
	var missing: Array = []

	if not node:
		return missing

	# Check level requirement
	if not check_level_requirement(node):
		var required_level = node.get_required_level()
		var current_level = _get_player_level()
		missing.append("Player Level %d (currently %d)" % [required_level, current_level])

	# Check specialization requirement
	if not check_specialization_requirement(node):
		var spec_tier = node.get_required_spec_tier()
		var spec_role = node.get_required_spec_role()

		if spec_role != "":
			missing.append("%s Specialization Tier %d" % [spec_role.capitalize(), spec_tier])
		elif spec_tier > 0:
			missing.append("Any Specialization Tier %d" % spec_tier)

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

func check_specialization_requirement(node: HexNode) -> bool:
	"""Check if player has required specialization tier and role"""
	if not node:
		return false

	var required_tier = node.get_required_spec_tier()
	var required_role = node.get_required_spec_role()

	# No specialization required
	if required_tier == 0:
		return true

	# Check if player has ANY god with required specialization tier
	if required_role == "":
		return _has_any_specialization_tier(required_tier)

	# Check if player has a god with required tier AND role
	return _has_specialization_tier_with_role(required_tier, required_role)

func check_power_requirement(node: HexNode) -> bool:
	"""Check if player has enough combat power to capture node"""
	if not node:
		return false

	var required_power = node.capture_power_required
	var current_power = _get_player_total_power()

	return current_power >= required_power

# ==============================================================================
# SPECIALIZATION CHECKING HELPERS
# ==============================================================================

func _has_any_specialization_tier(tier: int) -> bool:
	"""Check if player has any god with at least this specialization tier"""
	if not _specialization_manager or not _collection_manager:
		return false

	var owned_gods = _collection_manager.get_owned_gods()

	for god_data in owned_gods:
		var god_tier = _specialization_manager.get_god_specialization_tier(god_data.id)
		if god_tier >= tier:
			return true

	return false

func _has_specialization_tier_with_role(tier: int, role: String) -> bool:
	"""Check if player has a god with required specialization tier AND role"""
	if not _specialization_manager or not _collection_manager:
		return false

	var owned_gods = _collection_manager.get_owned_gods()

	for god_data in owned_gods:
		# Check if god has the right role
		if god_data.primary_role != role:
			continue

		# Check if god has required tier
		var god_tier = _specialization_manager.get_god_specialization_tier(god_data.id)
		if god_tier >= tier:
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
	"""Calculate a single god's combat power"""
	if not god:
		return 0

	# Base power from stats
	var power = 0
	power += god.hp / 10.0  # HP contributes less
	power += god.attack * 2.0  # Attack is most important
	power += god.defense * 1.5  # Defense is valuable
	power += god.speed * 0.5  # Speed matters less

	# Level bonus
	power += god.level * 50

	# Awakening bonus
	power += god.awakening_level * 500

	return int(power)

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

	# Specialization
	var spec_tier = node.get_required_spec_tier()
	var spec_role = node.get_required_spec_role()

	if spec_tier > 0:
		if spec_role != "":
			parts.append("%s Specialization Tier %d" % [spec_role.capitalize(), spec_tier])
		else:
			parts.append("Any Specialization Tier %d" % spec_tier)

	# Power
	parts.append("%d Combat Power" % node.capture_power_required)

	return ", ".join(parts)

func get_requirement_status(node: HexNode) -> Dictionary:
	"""Get detailed status of each requirement (for UI display)"""
	if not node:
		return {}

	return {
		"level": {
			"required": node.get_required_level(),
			"current": _get_player_level(),
			"met": check_level_requirement(node)
		},
		"specialization": {
			"tier_required": node.get_required_spec_tier(),
			"role_required": node.get_required_spec_role(),
			"met": check_specialization_requirement(node)
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
	var player_level = _get_player_level()

	# Tier 1: Level 1+
	if player_level >= 1:
		# Tier 5: Level 40+, Tier 3 spec
		if player_level >= 40 and _has_any_specialization_tier(3):
			return 5
		# Tier 4: Level 30+, Tier 2 spec
		elif player_level >= 30 and _has_any_specialization_tier(2):
			return 4
		# Tier 3: Level 20+, Tier 2 spec
		elif player_level >= 20 and _has_any_specialization_tier(2):
			return 3
		# Tier 2: Level 10+, Tier 1 spec
		elif player_level >= 10 and _has_any_specialization_tier(1):
			return 2
		else:
			return 1

	return 1

func can_unlock_tier(tier: int) -> bool:
	"""Check if player can unlock nodes of this tier"""
	return get_unlockable_tier() >= tier

func get_next_tier_requirement() -> String:
	"""Get what's needed to unlock the next tier"""
	var current_tier = get_unlockable_tier()

	if current_tier >= 5:
		return "Maximum tier unlocked"

	var next_tier = current_tier + 1
	var player_level = _get_player_level()

	match next_tier:
		2:
			if player_level < 10:
				return "Reach Level 10"
			else:
				return "Unlock any Tier 1 Specialization"
		3:
			if player_level < 20:
				return "Reach Level 20"
			else:
				return "Unlock any Tier 2 Specialization"
		4:
			if player_level < 30:
				return "Reach Level 30"
			else:
				return "Unlock any Tier 2 Specialization"
		5:
			if player_level < 40:
				return "Reach Level 40"
			else:
				return "Unlock any Tier 3 Specialization"

	return "Unknown"

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving (currently no persistent state)"""
	return {}

func load_save_data(_data: Dictionary) -> void:
	"""Load saved data (currently no persistent state)"""
	pass
