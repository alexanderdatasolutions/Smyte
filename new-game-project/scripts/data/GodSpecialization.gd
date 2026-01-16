# scripts/data/GodSpecialization.gd
# Data class for god specialization tree nodes
# Gods can specialize at level 20/30/40 to unlock powerful bonuses and abilities
# Note: Named GodSpecialization to match GodTrait, GodRole naming convention
extends Resource
class_name GodSpecialization

# ==============================================================================
# CORE PROPERTIES
# ==============================================================================
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon_path: String = ""

# ==============================================================================
# TREE STRUCTURE
# ==============================================================================
@export var tier: int = 1  # 1 = Level 20, 2 = Level 30, 3 = Level 40
@export var parent_spec: String = ""  # Parent specialization ID (null for tier 1)
@export var children_specs: Array[String] = []  # Child specialization IDs

# ==============================================================================
# REQUIREMENTS
# ==============================================================================
@export var role_required: String = ""  # Role ID required (fighter, gatherer, etc.)
@export var level_required: int = 20
@export var required_traits: Array[String] = []  # Optional: must have one of these traits
@export var blocked_traits: Array[String] = []  # Cannot have these traits

# Unlock costs
@export var costs: Dictionary = {}  # {"gold": 10000, "divine_essence": 50}

# ==============================================================================
# BONUSES
# ==============================================================================

# Stat bonuses (multiplicative percentages or boolean flags)
# e.g., {"attack_percent": 0.15, "defense_percent": 0.10, "cc_immunity": true}
@export var stat_bonuses: Dictionary = {}

# Task efficiency bonuses (multiplicative percentages)
# e.g., {"combat": 0.30, "mining": 0.25}
@export var task_bonuses: Dictionary = {}

# Resource gathering bonuses
# e.g., {"gather_yield_percent": 0.20, "rare_chance_percent": 0.15}
@export var resource_bonuses: Dictionary = {}

# Crafting-specific bonuses
# e.g., {"quality_percent": 0.25, "masterwork_chance": 0.10}
@export var crafting_bonuses: Dictionary = {}

# Research/XP bonuses
# e.g., {"research_speed_percent": 0.30, "xp_gain_percent": 0.20}
@export var research_bonuses: Dictionary = {}

# Combat-specific bonuses
# e.g., {"crit_chance_percent": 0.15, "lifesteal_percent": 0.05}
@export var combat_bonuses: Dictionary = {}

# Aura/leadership bonuses
# e.g., {"ally_efficiency_percent": 0.20, "territory_defense_percent": 0.15}
@export var aura_bonuses: Dictionary = {}

# ==============================================================================
# ABILITIES
# ==============================================================================
@export var unlocked_ability_ids: Array[String] = []  # New abilities granted
@export var enhanced_ability_ids: Dictionary = {}  # {"ability_id": enhancement_level}

# ==============================================================================
# TREE NAVIGATION
# ==============================================================================

func is_root() -> bool:
	"""Check if this is a root node (tier 1)"""
	return parent_spec == "" or parent_spec == null

func is_leaf() -> bool:
	"""Check if this is a leaf node (no children)"""
	return children_specs.is_empty()

func has_parent() -> bool:
	"""Check if this node has a parent"""
	return not is_root()

func has_children() -> bool:
	"""Check if this node has children"""
	return not is_leaf()

func get_parent_id() -> String:
	"""Get parent specialization ID"""
	return parent_spec if parent_spec else ""

func get_children_ids() -> Array[String]:
	"""Get child specialization IDs"""
	return children_specs.duplicate()

func get_tier() -> int:
	"""Get specialization tier (1-3)"""
	return tier

# ==============================================================================
# REQUIREMENTS VALIDATION
# ==============================================================================

func get_level_requirement() -> int:
	"""Get minimum level required"""
	return level_required

func get_role_requirement() -> String:
	"""Get required role ID"""
	return role_required

func get_unlock_costs() -> Dictionary:
	"""Get unlock costs"""
	return costs.duplicate()

func get_cost_amount(resource_type: String) -> int:
	"""Get cost for a specific resource type"""
	return costs.get(resource_type, 0)

func has_cost_requirement() -> bool:
	"""Check if this specialization has unlock costs"""
	return not costs.is_empty()

func meets_trait_requirements(god_traits: Array) -> bool:
	"""Check if god's traits meet requirements"""
	# Check blocked traits
	for trait_id in blocked_traits:
		if trait_id in god_traits:
			return false

	# Check required traits (must have at least one if any are specified)
	if not required_traits.is_empty():
		var has_required = false
		for trait_id in required_traits:
			if trait_id in god_traits:
				has_required = true
				break
		if not has_required:
			return false

	return true

# ==============================================================================
# BONUS GETTERS
# ==============================================================================

func get_stat_bonus(stat_name: String):
	"""Get stat bonus value (can be float or bool)"""
	return stat_bonuses.get(stat_name, 0.0)

func get_task_bonus(task_id: String) -> float:
	"""Get task efficiency bonus"""
	return task_bonuses.get(task_id, 0.0)

func get_resource_bonus(bonus_type: String) -> float:
	"""Get resource gathering bonus"""
	return resource_bonuses.get(bonus_type, 0.0)

func get_crafting_bonus(bonus_type: String) -> float:
	"""Get crafting bonus"""
	return crafting_bonuses.get(bonus_type, 0.0)

func get_research_bonus(bonus_type: String) -> float:
	"""Get research bonus"""
	return research_bonuses.get(bonus_type, 0.0)

func get_combat_bonus(bonus_type: String) -> float:
	"""Get combat bonus"""
	return combat_bonuses.get(bonus_type, 0.0)

func get_aura_bonus(bonus_type: String) -> float:
	"""Get aura/leadership bonus"""
	return aura_bonuses.get(bonus_type, 0.0)

func get_all_stat_bonuses() -> Dictionary:
	"""Get all stat bonuses"""
	return stat_bonuses.duplicate()

func get_all_task_bonuses() -> Dictionary:
	"""Get all task bonuses"""
	return task_bonuses.duplicate()

func get_all_resource_bonuses() -> Dictionary:
	"""Get all resource bonuses"""
	return resource_bonuses.duplicate()

func get_all_crafting_bonuses() -> Dictionary:
	"""Get all crafting bonuses"""
	return crafting_bonuses.duplicate()

func get_all_research_bonuses() -> Dictionary:
	"""Get all research bonuses"""
	return research_bonuses.duplicate()

func get_all_combat_bonuses() -> Dictionary:
	"""Get all combat bonuses"""
	return combat_bonuses.duplicate()

func get_all_aura_bonuses() -> Dictionary:
	"""Get all aura bonuses"""
	return aura_bonuses.duplicate()

# ==============================================================================
# ABILITIES
# ==============================================================================

func get_unlocked_abilities() -> Array[String]:
	"""Get list of unlocked ability IDs"""
	return unlocked_ability_ids.duplicate()

func get_enhanced_abilities() -> Dictionary:
	"""Get enhanced abilities with their levels"""
	return enhanced_ability_ids.duplicate()

func unlocks_ability(ability_id: String) -> bool:
	"""Check if this specialization unlocks an ability"""
	return ability_id in unlocked_ability_ids

func enhances_ability(ability_id: String) -> bool:
	"""Check if this specialization enhances an ability"""
	return enhanced_ability_ids.has(ability_id)

# ==============================================================================
# DISPLAY
# ==============================================================================

func get_display_name() -> String:
	"""Get formatted display name with tier"""
	var tier_roman = ["I", "II", "III"][tier - 1] if tier >= 1 and tier <= 3 else "?"
	return "%s [Tier %s]" % [name, tier_roman]

func get_tooltip() -> String:
	"""Get full tooltip text"""
	var tooltip = "%s\n%s\n\n" % [name, description]

	# Requirements
	tooltip += "Requirements:\n"
	tooltip += "  • Level %d\n" % level_required
	if role_required != "":
		tooltip += "  • Role: %s\n" % role_required.capitalize()
	if has_parent():
		tooltip += "  • Parent: %s\n" % parent_spec

	# Costs
	if has_cost_requirement():
		tooltip += "\nUnlock Costs:\n"
		if costs.has("gold"):
			tooltip += "  • Gold: %d\n" % costs["gold"]
		if costs.has("divine_essence"):
			tooltip += "  • Divine Essence: %d\n" % costs["divine_essence"]
		if costs.has("specialization_tomes"):
			tooltip += "  • Specialization Tomes: %d\n" % costs["specialization_tomes"]
		if costs.has("legendary_scroll"):
			tooltip += "  • Legendary Scroll: %d\n" % costs["legendary_scroll"]

	# Stat bonuses
	if not stat_bonuses.is_empty():
		tooltip += "\nStat Bonuses:\n"
		for stat_name in stat_bonuses:
			var value = stat_bonuses[stat_name]
			if typeof(value) == TYPE_BOOL:
				if value:
					tooltip += "  • %s\n" % stat_name.replace("_", " ").capitalize()
			else:
				var prefix = "+" if value >= 0 else ""
				tooltip += "  • %s: %s%d%%\n" % [stat_name.replace("_percent", "").replace("_", " ").capitalize(), prefix, int(value * 100)]

	# Task bonuses
	if not task_bonuses.is_empty():
		tooltip += "\nTask Bonuses:\n"
		for task_id in task_bonuses:
			tooltip += "  • %s: +%d%%\n" % [task_id.replace("_", " ").capitalize(), int(task_bonuses[task_id] * 100)]

	# Resource bonuses
	if not resource_bonuses.is_empty():
		tooltip += "\nResource Bonuses:\n"
		for bonus_name in resource_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(resource_bonuses[bonus_name] * 100)]

	# Crafting bonuses
	if not crafting_bonuses.is_empty():
		tooltip += "\nCrafting Bonuses:\n"
		for bonus_name in crafting_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(crafting_bonuses[bonus_name] * 100)]

	# Research bonuses
	if not research_bonuses.is_empty():
		tooltip += "\nResearch Bonuses:\n"
		for bonus_name in research_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(research_bonuses[bonus_name] * 100)]

	# Combat bonuses
	if not combat_bonuses.is_empty():
		tooltip += "\nCombat Bonuses:\n"
		for bonus_name in combat_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(combat_bonuses[bonus_name] * 100)]

	# Aura bonuses
	if not aura_bonuses.is_empty():
		tooltip += "\nAura Effects:\n"
		for bonus_name in aura_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(aura_bonuses[bonus_name] * 100)]

	# Abilities
	if not unlocked_ability_ids.is_empty():
		tooltip += "\nUnlocked Abilities:\n"
		for ability_id in unlocked_ability_ids:
			tooltip += "  • %s\n" % ability_id.replace("_", " ").capitalize()

	# Children
	if has_children():
		tooltip += "\nAdvanced Specializations:\n"
		for child_id in children_specs:
			tooltip += "  • %s\n" % child_id.replace("_", " ").capitalize()

	return tooltip

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func to_dict() -> Dictionary:
	"""Convert to dictionary for serialization"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"icon_path": icon_path,
		"tier": tier,
		"parent_spec": parent_spec,
		"children_specs": children_specs.duplicate(),
		"role_required": role_required,
		"level_required": level_required,
		"required_traits": required_traits.duplicate(),
		"blocked_traits": blocked_traits.duplicate(),
		"costs": costs.duplicate(),
		"stat_bonuses": stat_bonuses.duplicate(),
		"task_bonuses": task_bonuses.duplicate(),
		"resource_bonuses": resource_bonuses.duplicate(),
		"crafting_bonuses": crafting_bonuses.duplicate(),
		"research_bonuses": research_bonuses.duplicate(),
		"combat_bonuses": combat_bonuses.duplicate(),
		"aura_bonuses": aura_bonuses.duplicate(),
		"unlocked_ability_ids": unlocked_ability_ids.duplicate(),
		"enhanced_ability_ids": enhanced_ability_ids.duplicate()
	}

static func from_dict(data: Dictionary):
	"""Create specialization from dictionary - using load().new() pattern for Godot 4.5"""
	var script = load("res://scripts/data/GodSpecialization.gd")
	var new_spec = script.new()

	# Core properties
	new_spec.id = data.get("id", "")
	new_spec.name = data.get("name", "")
	new_spec.description = data.get("description", "")
	new_spec.icon_path = data.get("icon_path", "")

	# Tree structure
	new_spec.tier = data.get("tier", 1)
	var parent_value = data.get("parent_spec", "")
	new_spec.parent_spec = parent_value if parent_value != null else ""

	# Convert children_specs array
	var children_data = data.get("children_specs", [])
	for child_id in children_data:
		new_spec.children_specs.append(str(child_id))

	# Requirements
	new_spec.role_required = data.get("role_required", "")
	new_spec.level_required = data.get("level_required", 20)

	# Convert required_traits array
	var req_traits_data = data.get("required_traits", [])
	for trait_id in req_traits_data:
		new_spec.required_traits.append(str(trait_id))

	# Convert blocked_traits array
	var blocked_traits_data = data.get("blocked_traits", [])
	for trait_id in blocked_traits_data:
		new_spec.blocked_traits.append(str(trait_id))

	# Costs
	new_spec.costs = data.get("costs", {})

	# Bonuses
	new_spec.stat_bonuses = data.get("stat_bonuses", {})
	new_spec.task_bonuses = data.get("task_bonuses", {})
	new_spec.resource_bonuses = data.get("resource_bonuses", {})
	new_spec.crafting_bonuses = data.get("crafting_bonuses", {})
	new_spec.research_bonuses = data.get("research_bonuses", {})
	new_spec.combat_bonuses = data.get("combat_bonuses", {})
	new_spec.aura_bonuses = data.get("aura_bonuses", {})

	# Abilities
	var ability_ids_data = data.get("unlocked_ability_ids", [])
	for ability_id in ability_ids_data:
		new_spec.unlocked_ability_ids.append(str(ability_id))
	new_spec.enhanced_ability_ids = data.get("enhanced_ability_ids", {})

	return new_spec
