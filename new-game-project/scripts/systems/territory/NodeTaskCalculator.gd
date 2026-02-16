# scripts/systems/territory/NodeTaskCalculator.gd
# Single responsibility: Calculate task outputs for hex nodes
extends Node
class_name NodeTaskCalculator

"""
NodeTaskCalculator.gd - Node task and output calculation system
RULE 5: Uses SystemRegistry for all system access
RULE 2: Single responsibility - ONLY calculates tasks/output rates for hex nodes
RULE 3: Pure calculations - validate, calculate, return

Following plan.md task 4:
- get_task_for_node(node: HexNode) -> task name
- calculate_output_rate(node: HexNode, god: God) -> rate/hour
- Mine nodes: ore per hour, Forest: wood, Coast: fish
- Output scales: node tier × worker god level × affinity bonus
- Affinity bonus: matching affinity = 1.5x output
"""

# ==============================================================================
# NODE TYPE TO TASK MAPPING (v3.0 - Simplified 3 types + base)
# ==============================================================================

# Map node types to their primary task
const NODE_TASK_MAP = {
	"resource_node": "Gathering",
	"forge": "Crafting",
	"shrine": "Meditation",
	"base": "Management"
}

# Map node types to their primary output resource
const NODE_RESOURCE_MAP = {
	"resource_node": "ore",
	"forge": "enhancement_powder",
	"shrine": "divine_essence",
	"base": "mana"
}

# Node type to affinity mapping (for bonus calculations)
const NODE_AFFINITY_MAP = {
	"resource_node": "earth",
	"forge": "fire",
	"shrine": "light",
	"base": ""
}

# Base output rates per hour (tier 1)
const BASE_OUTPUT_RATES = {
	"resource_node": 10,
	"forge": 8,
	"shrine": 6,
	"base": 1
}

# ==============================================================================
# PUBLIC API
# ==============================================================================

func initialize():
	"""Initialize - called by SystemRegistry"""
	pass

func get_task_for_node(node: HexNode) -> String:
	"""Get the task name for a specific hex node type.
	Returns human-readable task name (e.g., 'Mining', 'Gathering').
	"""
	if not node:
		return "Unknown"

	return NODE_TASK_MAP.get(node.node_type, "Working")

func calculate_output_rate(node: HexNode, god: God) -> int:
	"""Calculate output rate per hour for a god working at a node.

	Formula: base_rate × tier_multiplier × god_level_bonus × affinity_bonus × spec_bonus

	Args:
		node: The HexNode being worked
		god: The God assigned as worker

	Returns:
		int: Resources generated per hour
	"""
	if not node or not god:
		return 0

	# Get base rate for node type
	var base_rate = BASE_OUTPUT_RATES.get(node.node_type, 5)

	# Tier multiplier: each tier increases base output
	var tier_multiplier = _get_tier_multiplier(node.tier)

	# God level bonus: 5% per level
	var level_bonus = 1.0 + (god.level * 0.05)

	# Affinity bonus: 1.5x if god's element matches node's affinity
	var affinity_bonus = _get_affinity_bonus(node, god)

	# Specialization bonus (from SpecializationManager)
	var spec_bonus = _get_specialization_bonus(node, god)

	# Calculate final output
	var output = base_rate * tier_multiplier * level_bonus * affinity_bonus * (1.0 + spec_bonus)

	return int(output)

func get_primary_resource(node: HexNode) -> String:
	"""Get the primary resource ID produced by a node type."""
	if not node:
		return ""

	return NODE_RESOURCE_MAP.get(node.node_type, "mana")

func get_node_affinity(node: HexNode) -> String:
	"""Get the affinity (element) associated with a node type."""
	if not node:
		return ""

	return NODE_AFFINITY_MAP.get(node.node_type, "")

func has_affinity_match(node: HexNode, god: God) -> bool:
	"""Check if a god's element matches the node's affinity."""
	if not node or not god:
		return false

	var node_affinity = get_node_affinity(node)
	if node_affinity.is_empty():
		return false

	var god_element = God.element_to_string(god.element).to_lower()
	return god_element == node_affinity

func get_output_display_text(node: HexNode, god: God) -> String:
	"""Get formatted output text for a god at a node.
	Returns string like 'Mining: +12 ore/hr'
	"""
	if not node or not god:
		return "No output"

	var task_name = get_task_for_node(node)
	var rate = calculate_output_rate(node, god)
	var resource_id = get_primary_resource(node)
	var resource_name = _get_resource_short_name(resource_id)

	return "%s: +%d %s/hr" % [task_name, rate, resource_name]

# ==============================================================================
# PRIVATE HELPER METHODS
# ==============================================================================

func _get_tier_multiplier(tier: int) -> float:
	"""Get output multiplier based on node tier."""
	match tier:
		1: return 1.0
		2: return 1.5
		3: return 2.0
		4: return 3.0
		5: return 4.5
		_: return 1.0

func _get_affinity_bonus(node: HexNode, god: God) -> float:
	"""Calculate affinity bonus (1.5x if element matches)."""
	if has_affinity_match(node, god):
		return 1.5
	return 1.0

func _get_specialization_bonus(node: HexNode, god: God) -> float:
	"""Get specialization bonus from god's spec for this node type."""
	if not node or not god:
		return 0.0

	# Try to use SpecializationManager if available
	var spec_manager = SystemRegistry.get_instance().get_system("SpecializationManager")
	if not spec_manager:
		return _calculate_fallback_spec_bonus(god)

	# Check for spec bonuses related to this node type
	if spec_manager.has_method("get_total_task_bonuses_for_god"):
		var task_bonuses = spec_manager.get_total_task_bonuses_for_god(god)
		var relevant_tasks = _get_relevant_tasks_for_node(node.node_type)

		var best_bonus = 0.0
		for task_id in relevant_tasks:
			var bonus = task_bonuses.get(task_id, 0.0)
			if bonus > best_bonus:
				best_bonus = bonus

		return best_bonus

	return _calculate_fallback_spec_bonus(god)

func _calculate_fallback_spec_bonus(god: God) -> float:
	"""Calculate a simple spec bonus when SpecializationManager isn't available.
	Based on spec tier: tier1=0.5, tier2=1.0, tier3=2.0
	"""
	var spec_tier = god.get_specialization_tier()
	match spec_tier:
		1: return 0.5   # 50% bonus
		2: return 1.0   # 100% bonus
		3: return 2.0   # 200% bonus
		_: return 0.0

func _get_relevant_tasks_for_node(node_type: String) -> Array:
	"""Get relevant task IDs for a node type (for spec bonus lookup)."""
	match node_type:
		"resource_node": return ["gathering", "mining", "logging", "herbalism", "foraging"]
		"forge": return ["smithing", "crafting", "armor_crafting", "weapon_crafting", "enchanting"]
		"shrine": return ["meditation", "blessing", "divine_communion", "research"]
		"base": return ["management"]
		_: return []

func _get_resource_short_name(resource_id: String) -> String:
	"""Convert resource ID to short display name."""
	match resource_id:
		# Crafting materials
		"ore": return "ore"
		"wood": return "wood"
		"herbs": return "herbs"
		"monster_parts": return "parts"
		"refined_metal": return "metal"
		"quality_timber": return "timber"
		"rare_herbs": return "rare herbs"
		"beast_scales": return "scales"
		"magic_crystals": return "crystals"
		"forging_flame": return "flame"
		"celestial_ore": return "celestial"
		"dragon_parts": return "dragon"
		# Enhancement
		"enhancement_powder": return "powder"
		"socket_crystal": return "socket"
		"blessed_oil": return "oil"
		# Divine
		"divine_essence": return "essence"
		"awakening_essence": return "awakening"
		"ascension_crystal": return "ascension"
		"mana_crystals": return "mana crystals"
		# Currency
		"mana": return "mana"
		"gold": return "gold"
		"divine_crystals": return "crystals"
		_: return resource_id.replace("_", " ")
