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
# CONFIG (loaded from task_config.json)
# ==============================================================================
static var _config: Dictionary = {}
static var _config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	var file: FileAccess = FileAccess.open("res://data/task_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed
	_config_loaded = true

static func _get_node_output_config() -> Dictionary:
	_load_config()
	return _config.get("node_output", {})

static func _get_node_mappings() -> Dictionary:
	_load_config()
	return _config.get("node_mappings", {})

# ==============================================================================
# PUBLIC API
# ==============================================================================

func initialize():
	"""Initialize - called by SystemRegistry"""
	pass

func get_task_for_node(node: HexNode) -> String:
	"""Get the task name for a specific hex node type."""
	if not node:
		return "Unknown"

	var task_map: Dictionary = _get_node_mappings().get("task_map", {"resource_node": "Gathering", "forge": "Crafting", "shrine": "Meditation", "base": "Management"})
	return task_map.get(node.node_type, "Working")

func calculate_output_rate(node: HexNode, god: God) -> int:
	"""Calculate output rate per hour for a god working at a node.
	Formula: base_rate x tier_multiplier x god_level_bonus x affinity_bonus x spec_bonus
	"""
	if not node or not god:
		return 0

	_load_config()
	var output_cfg: Dictionary = _get_node_output_config()

	# Get base rate for node type
	var base_rates: Dictionary = output_cfg.get("base_rates", {"resource_node": 10, "forge": 8, "shrine": 6, "base": 1, "default": 5})
	var base_rate: int = int(base_rates.get(node.node_type, base_rates.get("default", 5)))

	# Tier multiplier: each tier increases base output
	var tier_multiplier: float = _get_tier_multiplier(node.tier)

	# God level bonus
	var level_bonus_per_level: float = float(output_cfg.get("god_level_bonus_per_level", 0.05))
	var level_bonus: float = 1.0 + (god.level * level_bonus_per_level)

	# Affinity bonus
	var affinity_bonus: float = _get_affinity_bonus(node, god)

	# Specialization bonus (from SpecializationManager)
	var spec_bonus: float = _get_specialization_bonus(node, god)

	# Calculate final output
	var output: float = base_rate * tier_multiplier * level_bonus * affinity_bonus * (1.0 + spec_bonus)

	return int(output)

func get_primary_resource(node: HexNode) -> String:
	"""Get the primary resource ID produced by a node type."""
	if not node:
		return ""

	var resource_map: Dictionary = _get_node_mappings().get("resource_map", {"resource_node": "ore", "forge": "enhancement_powder", "shrine": "divine_essence", "base": "mana"})
	return resource_map.get(node.node_type, "mana")

func get_node_affinity(node: HexNode) -> String:
	"""Get the affinity (element) associated with a node type."""
	if not node:
		return ""

	var affinity_map: Dictionary = _get_node_mappings().get("affinity_map", {"resource_node": "earth", "forge": "fire", "shrine": "light", "base": ""})
	return affinity_map.get(node.node_type, "")

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
	var tier_mults: Dictionary = _get_node_output_config().get("tier_multipliers", {"1": 1.0, "2": 1.5, "3": 2.0, "4": 3.0, "5": 4.5})
	return float(tier_mults.get(str(tier), 1.0))

func _get_affinity_bonus(node: HexNode, god: God) -> float:
	"""Calculate affinity bonus if element matches."""
	if has_affinity_match(node, god):
		return float(_get_node_output_config().get("affinity_match_multiplier", 1.5))
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
	"""Calculate a simple spec bonus when SpecializationManager isn't available."""
	var spec_tier: int = god.get_specialization_tier()
	var fallback_bonuses: Dictionary = _get_node_output_config().get("fallback_spec_bonuses", {"0": 0.0, "1": 0.5, "2": 1.0, "3": 2.0})
	return float(fallback_bonuses.get(str(spec_tier), 0.0))

func _get_relevant_tasks_for_node(node_type: String) -> Array:
	"""Get relevant task IDs for a node type (for spec bonus lookup)."""
	var relevant_map: Dictionary = _get_node_mappings().get("relevant_tasks_map", {
		"resource_node": ["gathering", "mining", "logging", "herbalism", "foraging"],
		"forge": ["smithing", "crafting", "armor_crafting", "weapon_crafting", "enchanting"],
		"shrine": ["meditation", "blessing", "divine_communion", "research"],
		"base": ["management"]
	})
	return relevant_map.get(node_type, [])

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
