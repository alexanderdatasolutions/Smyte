# Specialization.gd - Data class for god specialization paths
# At level 20+, gods can specialize into focused roles
extends Resource
class_name Specialization

# ==============================================================================
# ENUMS
# ==============================================================================
enum SpecializationType {
	COMBAT,     # Battle-focused specializations
	PRODUCTION, # Gathering/crafting focused
	SUPPORT,    # Utility and team buffs
	HYBRID      # Mixed specializations
}

# ==============================================================================
# CORE PROPERTIES
# ==============================================================================
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var type: SpecializationType = SpecializationType.COMBAT
@export var icon_path: String = ""

# ==============================================================================
# REQUIREMENTS
# ==============================================================================
@export var required_level: int = 20
@export var required_traits: Array[String] = []  # Must have one of these traits
@export var blocked_traits: Array[String] = []  # Cannot have these traits
@export var required_pantheon: String = ""  # Optional pantheon restriction
@export var prerequisite_specialization_id: String = ""  # For advanced specs

# ==============================================================================
# STAT BONUSES (percentage bonuses)
# ==============================================================================
@export var stat_bonuses: Dictionary = {}  # {"attack": 0.15, "defense": 0.10}
@export var task_bonuses: Dictionary = {}  # {"mine_ore": 0.25, "forge_equipment": 0.20}

# ==============================================================================
# SPECIAL ABILITIES
# ==============================================================================
@export var unlocked_ability_ids: Array[String] = []  # New abilities granted
@export var enhanced_ability_ids: Dictionary = {}  # {"ability_id": enhancement_level}

# ==============================================================================
# SKILL BONUSES
# ==============================================================================
@export var skill_xp_bonuses: Dictionary = {}  # {"mining": 0.25} = 25% more skill XP

# ==============================================================================
# METHODS
# ==============================================================================

func can_god_specialize(god: God) -> bool:
	"""Check if a god meets requirements for this specialization"""
	if not god:
		return false

	# Check level
	if god.level < required_level:
		return false

	# Check blocked traits
	for trait_id in blocked_traits:
		if god.has_trait(trait_id):
			return false

	# Check required traits (must have at least one)
	if required_traits.size() > 0:
		var has_required = false
		for trait_id in required_traits:
			if god.has_trait(trait_id):
				has_required = true
				break
		if not has_required:
			return false

	# Check pantheon
	if required_pantheon != "" and god.pantheon != required_pantheon:
		return false

	return true

func get_type_string() -> String:
	"""Get type as string"""
	match type:
		SpecializationType.COMBAT: return "combat"
		SpecializationType.PRODUCTION: return "production"
		SpecializationType.SUPPORT: return "support"
		SpecializationType.HYBRID: return "hybrid"
		_: return "unknown"

# ==============================================================================
# SERIALIZATION
# ==============================================================================

static func from_dict(data: Dictionary):
	"""Create a Specialization from dictionary data"""
	var script = load("res://scripts/data/Specialization.gd")
	var spec = script.new()

	spec.id = data.get("id", "")
	spec.name = data.get("name", "")
	spec.description = data.get("description", "")
	spec.icon_path = data.get("icon_path", "")

	# Parse type
	var type_str = data.get("type", "combat")
	match type_str:
		"combat": spec.type = SpecializationType.COMBAT
		"production": spec.type = SpecializationType.PRODUCTION
		"support": spec.type = SpecializationType.SUPPORT
		"hybrid": spec.type = SpecializationType.HYBRID

	# Requirements
	spec.required_level = data.get("required_level", 20)
	# Convert untyped arrays from JSON to typed arrays
	var req_traits = data.get("required_traits", [])
	for trait_id in req_traits:
		spec.required_traits.append(trait_id)
	var blk_traits = data.get("blocked_traits", [])
	for trait_id in blk_traits:
		spec.blocked_traits.append(trait_id)
	spec.required_pantheon = data.get("required_pantheon", "")
	spec.prerequisite_specialization_id = data.get("prerequisite_specialization_id", "")

	# Bonuses
	spec.stat_bonuses = data.get("stat_bonuses", {})
	spec.task_bonuses = data.get("task_bonuses", {})
	spec.skill_xp_bonuses = data.get("skill_xp_bonuses", {})

	# Abilities - convert untyped array to typed array
	var ability_ids = data.get("unlocked_ability_ids", [])
	for ability_id in ability_ids:
		spec.unlocked_ability_ids.append(ability_id)
	spec.enhanced_ability_ids = data.get("enhanced_ability_ids", {})

	return spec

func to_dict() -> Dictionary:
	"""Convert to dictionary for serialization"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"type": get_type_string(),
		"icon_path": icon_path,
		"required_level": required_level,
		"required_traits": required_traits,
		"blocked_traits": blocked_traits,
		"required_pantheon": required_pantheon,
		"prerequisite_specialization_id": prerequisite_specialization_id,
		"stat_bonuses": stat_bonuses,
		"task_bonuses": task_bonuses,
		"skill_xp_bonuses": skill_xp_bonuses,
		"unlocked_ability_ids": unlocked_ability_ids,
		"enhanced_ability_ids": enhanced_ability_ids
	}
