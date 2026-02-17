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

# Combat power required to capture node
@export var power_required: int = 1000

# ==============================================================================
# SIMPLE GETTERS ONLY - No calculation logic
# ==============================================================================

func get_description() -> String:
	"""Get a human-readable description of all requirements"""
	var parts: Array[String] = []

	# Level requirement
	parts.append("Level %d" % player_level_required)

	# Power requirement
	if power_required > 0:
		parts.append("%d Power" % power_required)

	return ", ".join(parts)

func get_short_description() -> String:
	"""Get a condensed description for UI tooltips"""
	var parts: Array[String] = []

	parts.append("Lv%d" % player_level_required)

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
		"power_required": power_required
	}

static func from_dict(data: Dictionary):
	"""Create NodeRequirements from dictionary"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()

	requirements.player_level_required = data.get("player_level_required", 1)
	requirements.power_required = data.get("power_required", 1000)

	return requirements

# ==============================================================================
# FACTORY METHODS
# ==============================================================================

static func create_tier1():
	"""Create tier 1 node requirements"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 1
	requirements.power_required = 1000
	return requirements

static func create_tier2():
	"""Create tier 2 node requirements"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 10
	requirements.power_required = 3000
	return requirements

static func create_tier3():
	"""Create tier 3 node requirements"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 20
	requirements.power_required = 7000
	return requirements

static func create_tier4():
	"""Create tier 4 node requirements"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 30
	requirements.power_required = 15000
	return requirements

static func create_tier5():
	"""Create tier 5 node requirements"""
	var script = load("res://scripts/data/NodeRequirements.gd")
	var requirements = script.new()
	requirements.player_level_required = 40
	requirements.power_required = 30000
	return requirements
