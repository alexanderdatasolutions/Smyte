# scripts/data/NodeRequirements.gd
# Data class for hex node unlock requirements
extends Resource
class_name NodeRequirements

"""
NodeRequirements.gd - Pure data class for node unlock requirements
RULE 3: NO LOGIC IN DATA CLASSES - Only properties and simple getters
RULE 1: Under 500 lines - Data only

Following CLAUDE.md architecture:
- DATA LAYER: Think database tables
- ONLY properties, NO complex methods
- Logic belongs in NodeRequirementChecker system
"""

# ==============================================================================
# REQUIREMENT PROPERTIES
# ==============================================================================

# Player level requirement
@export var player_level_required: int = 1

# Specialization tier requirement (0=none, 1=tier1, 2=tier2, 3=tier3)
@export var specialization_tier_required: int = 0

# Specialization role requirement (optional, for tier 4+ nodes)
# Empty string means no role requirement
# Valid values: "fighter", "gatherer", "crafter", "scholar", "support"
@export var specialization_role_required: String = ""

# Combat power required to capture node
@export var power_required: int = 1000

# ==============================================================================
# SIMPLE GETTERS ONLY - No calculation logic
# ==============================================================================

func requires_specialization() -> bool:
	"""Check if any specialization is required"""
	return specialization_tier_required > 0

func requires_role_match() -> bool:
	"""Check if specific role match is required"""
	return specialization_role_required != ""

func get_spec_tier_name() -> String:
	"""Get human-readable specialization tier name"""
	match specialization_tier_required:
		0: return "None"
		1: return "Tier 1"
		2: return "Tier 2"
		3: return "Tier 3"
		_: return "Unknown"

func get_role_display_name() -> String:
	"""Get human-readable role name"""
	if specialization_role_required == "":
		return "Any"

	match specialization_role_required:
		"fighter": return "Fighter"
		"gatherer": return "Gatherer"
		"crafter": return "Crafter"
		"scholar": return "Scholar"
		"support": return "Support"
		_: return specialization_role_required.capitalize()

func get_description() -> String:
	"""Get a human-readable description of all requirements"""
	var parts: Array[String] = []

	# Level requirement
	parts.append("Level %d" % player_level_required)

	# Specialization requirement
	if specialization_tier_required > 0:
		if specialization_role_required != "":
			parts.append("%s Specialization %s" % [get_role_display_name(), get_spec_tier_name()])
		else:
			parts.append("Any Specialization %s" % get_spec_tier_name())

	# Power requirement
	if power_required > 0:
		parts.append("%d Power" % power_required)

	return ", ".join(parts)

func get_short_description() -> String:
	"""Get a condensed description for UI tooltips"""
	var parts: Array[String] = []

	parts.append("Lv%d" % player_level_required)

	if specialization_tier_required > 0:
		if specialization_role_required != "":
			parts.append("%s T%d" % [specialization_role_required.capitalize(), specialization_tier_required])
		else:
			parts.append("Spec T%d" % specialization_tier_required)

	if power_required > 1000:
		parts.append("%dk Power" % (power_required / 1000))

	return " | ".join(parts)

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func to_dict() -> Dictionary:
	"""Serialize to dictionary for saving"""
	return {
		"player_level_required": player_level_required,
		"specialization_tier_required": specialization_tier_required,
		"specialization_role_required": specialization_role_required,
		"power_required": power_required
	}

static func from_dict(data: Dictionary):
	"""Create NodeRequirements from dictionary"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()

	requirements.player_level_required = data.get("player_level_required", 1)
	requirements.specialization_tier_required = data.get("specialization_tier_required", 0)
	requirements.specialization_role_required = data.get("specialization_role_required", "")
	requirements.power_required = data.get("power_required", 1000)

	return requirements

# ==============================================================================
# FACTORY METHODS
# ==============================================================================

static func create_tier1():
	"""Create tier 1 node requirements (no specialization needed)"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 1
	requirements.specialization_tier_required = 0
	requirements.power_required = 1000
	return requirements

static func create_tier2():
	"""Create tier 2 node requirements (tier 1 spec needed)"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 10
	requirements.specialization_tier_required = 1
	requirements.power_required = 3000
	return requirements

static func create_tier3():
	"""Create tier 3 node requirements (tier 2 spec needed)"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 20
	requirements.specialization_tier_required = 2
	requirements.power_required = 7000
	return requirements

static func create_tier4(role: String):
	"""Create tier 4 node requirements (tier 2 spec + role match needed)"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 30
	requirements.specialization_tier_required = 2
	requirements.specialization_role_required = role
	requirements.power_required = 15000
	return requirements

static func create_tier5():
	"""Create tier 5 node requirements (tier 3 spec needed)"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 40
	requirements.specialization_tier_required = 3
	requirements.power_required = 30000
	return requirements
