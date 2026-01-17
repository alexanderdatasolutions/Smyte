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
# NODE TYPE TO TASK MAPPING
# ==============================================================================

# Map node types to their primary task
const NODE_TASK_MAP = {
	"mine": "Mining",
	"forest": "Gathering",
	"coast": "Fishing",
	"hunting_ground": "Hunting",
	"forge": "Smithing",
	"library": "Research",
	"temple": "Meditation",
	"fortress": "Garrison Duty",
	"base": "Management"
}

# Map node types to their primary output resource
const NODE_RESOURCE_MAP = {
	"mine": "iron_ore",
	"forest": "wood",
	"coast": "fish",
	"hunting_ground": "pelts",
	"forge": "iron_ingots",
	"library": "research_points",
	"temple": "divine_essence",
	"fortress": "gold",
	"base": "mana"
}

# Secondary resources by node type (tier 2+)
const NODE_SECONDARY_RESOURCES = {
	"mine": ["copper_ore", "stone"],
	"forest": ["herbs", "fiber"],
	"coast": ["salt", "pearls"],
	"hunting_ground": ["bones"],
	"forge": ["steel_ingots"],
	"library": ["scrolls", "knowledge_crystals"],
	"temple": ["mana_crystals"],
	"fortress": []
}

# Node type to affinity mapping (for bonus calculations)
const NODE_AFFINITY_MAP = {
	"mine": "earth",
	"forest": "earth",
	"coast": "water",
	"hunting_ground": "fire",
	"forge": "fire",
	"library": "light",
	"temple": "light",
	"fortress": "dark"
}

# Base output rates per hour (tier 1)
const BASE_OUTPUT_RATES = {
	"mine": 10,
	"forest": 12,
	"coast": 8,
	"hunting_ground": 6,
	"forge": 5,
	"library": 4,
	"temple": 3,
	"fortress": 2,
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

func get_task_display_name(node: HexNode) -> String:
	"""Get formatted task name for UI display.
	Returns format like 'Mining (Tier 2)'
	"""
	if not node:
		return "Unknown Task"

	var task_name = get_task_for_node(node)
	return "%s (Tier %d)" % [task_name, node.tier]

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

func calculate_output_with_details(node: HexNode, god: God) -> Dictionary:
	"""Calculate output rate with breakdown of all bonuses.
	Useful for UI tooltips showing how output is calculated.

	Returns:
		Dictionary with keys: total, base, tier_mult, level_bonus, affinity_bonus, spec_bonus
	"""
	if not node or not god:
		return {"total": 0}

	var base_rate = BASE_OUTPUT_RATES.get(node.node_type, 5)
	var tier_mult = _get_tier_multiplier(node.tier)
	var level_bonus = 1.0 + (god.level * 0.05)
	var affinity_bonus = _get_affinity_bonus(node, god)
	var spec_bonus = _get_specialization_bonus(node, god)

	var total = int(base_rate * tier_mult * level_bonus * affinity_bonus * (1.0 + spec_bonus))

	return {
		"total": total,
		"base_rate": base_rate,
		"tier_multiplier": tier_mult,
		"level_bonus": level_bonus,
		"affinity_bonus": affinity_bonus,
		"spec_bonus": spec_bonus,
		"resource_id": get_primary_resource(node),
		"resource_name": _get_resource_display_name(node)
	}

func get_primary_resource(node: HexNode) -> String:
	"""Get the primary resource ID produced by a node type."""
	if not node:
		return ""

	return NODE_RESOURCE_MAP.get(node.node_type, "mana")

func get_secondary_resources(node: HexNode) -> Array:
	"""Get secondary resources produced by a node (tier 2+)."""
	if not node or node.tier < 2:
		return []

	return NODE_SECONDARY_RESOURCES.get(node.node_type, [])

func get_all_resources(node: HexNode) -> Array:
	"""Get all resources a node can produce (primary + secondary)."""
	if not node:
		return []

	var resources = [get_primary_resource(node)]
	if node.tier >= 2:
		resources.append_array(get_secondary_resources(node))

	return resources

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

func calculate_total_node_output(node: HexNode) -> Dictionary:
	"""Calculate total output from all workers assigned to a node.

	Returns:
		Dictionary of {"resource_id": total_per_hour}
	"""
	if not node:
		return {}

	var total_output = {}
	var primary_resource = get_primary_resource(node)
	total_output[primary_resource] = 0

	# Get CollectionManager for worker gods
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager:
		return total_output

	# Calculate output from each worker
	for god_id in node.assigned_workers:
		var god = collection_manager.get_god_by_id(god_id)
		if god:
			var rate = calculate_output_rate(node, god)
			total_output[primary_resource] = total_output.get(primary_resource, 0) + rate

	# Add secondary resources for tier 2+ nodes with workers
	if node.tier >= 2 and node.assigned_workers.size() > 0:
		var secondary = get_secondary_resources(node)
		for resource_id in secondary:
			# Secondary resources at 30% of primary rate
			var secondary_rate = int(total_output[primary_resource] * 0.3)
			if secondary_rate > 0:
				total_output[resource_id] = secondary_rate

	return total_output

func format_output_rate(rate: int, resource_id: String) -> String:
	"""Format output rate for display in UI.
	Returns string like '+12 ore/hr' or '+5 fish/hr'
	"""
	var resource_name = _get_resource_short_name(resource_id)
	return "+%d %s/hr" % [rate, resource_name]

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
		"mine": return ["mining", "mine_ore", "mine_gems", "deep_mining"]
		"forest": return ["logging", "herbalism", "foraging", "gathering"]
		"coast": return ["fishing", "pearl_diving", "salt_harvesting"]
		"hunting_ground": return ["hunting", "tracking", "monster_hunting"]
		"forge": return ["smithing", "armor_crafting", "weapon_crafting"]
		"library": return ["research", "scroll_crafting", "training"]
		"temple": return ["meditation", "blessing", "divine_communion"]
		"fortress": return ["garrison_duty", "combat_training", "defense_building"]
		_: return []

func _get_resource_display_name(node: HexNode) -> String:
	"""Get human-readable resource name for a node's output."""
	var resource_id = get_primary_resource(node)
	return _get_resource_short_name(resource_id)

func _get_resource_short_name(resource_id: String) -> String:
	"""Convert resource ID to short display name."""
	match resource_id:
		"iron_ore": return "ore"
		"copper_ore": return "copper"
		"wood": return "wood"
		"herbs": return "herbs"
		"fiber": return "fiber"
		"fish": return "fish"
		"salt": return "salt"
		"pearls": return "pearls"
		"pelts": return "pelts"
		"bones": return "bones"
		"iron_ingots": return "ingots"
		"steel_ingots": return "steel"
		"research_points": return "research"
		"scrolls": return "scrolls"
		"knowledge_crystals": return "knowledge"
		"divine_essence": return "essence"
		"mana_crystals": return "mana"
		"gold": return "gold"
		"mana": return "mana"
		_: return resource_id.replace("_", " ")
