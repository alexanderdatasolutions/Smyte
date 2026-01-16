# scripts/data/God.gd - PURE DATA CLASS (NO LOGIC)
extends Resource
class_name God

enum ElementType { FIRE, WATER, EARTH, LIGHTNING, LIGHT, DARK }
enum TierType { COMMON, RARE, EPIC, LEGENDARY }

# ==============================================================================
# CORE IDENTITY - Pure data properties only
# ==============================================================================
@export var id: String
@export var name: String
@export var pantheon: String  # "greek", "norse", "egyptian"
@export var element: ElementType
@export var tier: TierType
@export var level: int = 1
@export var experience: int = 0

# ==============================================================================
# BASE COMBAT STATS - Raw values without calculation
# ==============================================================================
@export var base_hp: int
@export var base_attack: int  
@export var base_defense: int
@export var base_speed: int
@export var base_crit_rate: int = 15        # Critical Rate % (SW default: 15%)
@export var base_crit_damage: int = 50      # Critical Damage % (SW default: 50%)
@export var base_resistance: int = 15       # Resistance % (SW default: 15%)
@export var base_accuracy: int = 0          # Accuracy % (SW default: 0%)
@export var resource_generation: int       # Resources per hour

# ==============================================================================
# EQUIPMENT SYSTEM - 6 slots like Summoners War
# ==============================================================================
# Slots: 1=Weapon, 2=Armor, 3=Helm, 4=Boots, 5=Amulet, 6=Ring
@export var equipment: Array = [null, null, null, null, null, null]

# ==============================================================================
# ABILITIES - JSON format data
# ==============================================================================
@export var active_abilities: Array = []  # Array of ability dictionaries
@export var passive_abilities: Array = []  # Array of passive ability dictionaries

# Legacy abilities array for backward compatibility (deprecated)
@export var abilities: Array = []  # Ability IDs
@export var passive_ability: String = ""

# ==============================================================================
# TRAIT SYSTEM - Palworld-style innate abilities
# ==============================================================================
@export var innate_traits: Array[String] = []  # Traits from god_innate_traits (permanent)
@export var learned_traits: Array[String] = []  # Traits gained through gameplay

# ==============================================================================
# ROLE & SPECIALIZATION SYSTEM
# ==============================================================================
@export var primary_role: String = ""  # Primary role ID (fighter, gatherer, crafter, scholar, support)
@export var secondary_role: String = ""  # Optional secondary role ID (50% bonus strength)
@export var specialization_path: Array[String] = ["", "", ""]  # [tier1_id, tier2_id, tier3_id]

# ==============================================================================
# TERRITORY SYSTEM
# ==============================================================================
@export var stationed_territory: String = ""
@export var territory_role: String = ""  # "defender", "gatherer", "crafter"

# ==============================================================================
# TASK ASSIGNMENT SYSTEM - Gods can work on territory tasks
# ==============================================================================
@export var current_tasks: Array[String] = []  # Task IDs currently assigned (usually 1, more with multitask trait)
@export var task_start_times: Array[int] = []  # Unix timestamps when each task started
@export var task_progress: Dictionary = {}  # {"task_id": progress_percentage}

# ==============================================================================
# AWAKENING SYSTEM - Summoners War style
# ==============================================================================
@export var is_awakened: bool = false
@export var awakened_name: String = ""
@export var awakened_title: String = ""
@export var ascension_level: int = 0  # 0=unascended, 1=bronze, 2=silver, 3=gold, 4=diamond, 5=transcendent
@export var skill_levels: Array = [1, 1, 1, 1]  # Array[int] - Skill levels 1-10 for each skill

# ==============================================================================
# COSMETICS SYSTEM
# ==============================================================================
@export var equipped_skin_id: String = ""  # Currently equipped skin ID
@export var default_portrait_path: String = ""  # Base portrait path

# ==============================================================================
# BATTLE STATE - Runtime data
# ==============================================================================
@export var current_hp: int = 0  # Set during battle preparation
@export var status_effects: Array = []  # Active status effects
@export var position: int = -1  # Battle position (0-3)

# ==============================================================================
# SIMPLE GETTERS ONLY - No calculation logic
# ==============================================================================

func get_display_name() -> String:
	if is_awakened and awakened_name != "":
		return awakened_name
	return name

func get_full_title() -> String:
	if is_awakened and awakened_title != "":
		return awakened_title + " " + get_display_name()
	return get_display_name()

func is_equipment_slot_empty(slot: int) -> bool:
	if slot < 0 or slot >= equipment.size():
		return true
	return equipment[slot] == null

func get_equipment_in_slot(slot: int) -> Equipment:
	if slot < 0 or slot >= equipment.size():
		return null
	return equipment[slot]

# ==============================================================================
# DATA VALIDATION - Simple checks only (NO CALCULATIONS - RULE 3)
# ==============================================================================

func is_valid() -> bool:
	"""Simple data validation - RULE 3 compliant"""
	return id != "" and name != "" and base_hp > 0 and base_attack > 0

func can_level_up() -> bool:
	"""Simple level cap check - RULE 3 compliant"""
	return level < 40  # Max level cap

func has_ability(ability_id: String) -> bool:
	for ability in active_abilities:
		if ability.get("id") == ability_id:
			return true
	return false

func is_equipped() -> bool:
	# Check if god has any equipment equipped
	for eq in equipment:
		if eq != null:
			return true
	return false

func is_assigned_to_territory() -> bool:
	# Check if god is assigned to a territory role
	return stationed_territory != "" and territory_role != ""

func has_skin_equipped() -> bool:
	return equipped_skin_id != ""

func get_portrait_path() -> String:
	"""Get the current portrait path, considering equipped skin.
	Note: This returns the default path. UI code should use SkinManager
	to resolve skin-specific portraits to avoid cyclic dependencies."""
	# Pure data method - no system access here to avoid cyclic deps
	# The UI layer should call SkinManager.get_portrait_path(god_id, default_portrait_path)
	# if the god has equipped_skin_id set
	return default_portrait_path

# Static utility method
static func element_to_string(element_enum) -> String:
	match element_enum:
		ElementType.FIRE: return "fire"
		ElementType.WATER: return "water"
		ElementType.EARTH: return "earth"
		ElementType.LIGHTNING: return "lightning"
		ElementType.LIGHT: return "light"
		ElementType.DARK: return "dark"
		_: return "unknown"

# Static utility method for string to element conversion
static func string_to_element(element_string: String) -> ElementType:
	match element_string.to_lower():
		"fire": return ElementType.FIRE
		"water": return ElementType.WATER
		"earth": return ElementType.EARTH
		"lightning": return ElementType.LIGHTNING
		"light": return ElementType.LIGHT
		"dark": return ElementType.DARK
		_: return ElementType.LIGHT  # Default fallback

# Static utility method for tier conversion
static func tier_to_string(tier_enum) -> String:
	match tier_enum:
		TierType.COMMON: return "common"
		TierType.RARE: return "rare"
		TierType.EPIC: return "epic"
		TierType.LEGENDARY: return "legendary"
		_: return "unknown"

# Static utility method for string to tier conversion
static func string_to_tier(tier_string: String) -> TierType:
	match tier_string.to_lower():
		"common": return TierType.COMMON
		"rare": return TierType.RARE
		"epic": return TierType.EPIC
		"legendary": return TierType.LEGENDARY
		_: return TierType.COMMON  # Default fallback

# ==============================================================================
# TRAIT SYSTEM HELPERS - Simple getters only (logic in TraitManager)
# ==============================================================================

func get_all_traits() -> Array[String]:
	"""Get combined list of innate and learned traits"""
	var all_traits: Array[String] = []
	all_traits.append_array(innate_traits)
	all_traits.append_array(learned_traits)
	return all_traits

func has_trait(trait_id: String) -> bool:
	"""Check if god has a specific trait"""
	return trait_id in innate_traits or trait_id in learned_traits

func get_trait_count() -> int:
	"""Get total number of traits"""
	return innate_traits.size() + learned_traits.size()

# ==============================================================================
# TASK ASSIGNMENT HELPERS - Simple state checks (logic in TaskAssignmentManager)
# ==============================================================================

func is_working_on_task() -> bool:
	"""Check if god is currently assigned to any task"""
	return current_tasks.size() > 0

func get_current_task_count() -> int:
	"""Get number of tasks currently assigned"""
	return current_tasks.size()

func is_assigned_to_task(task_id: String) -> bool:
	"""Check if god is assigned to a specific task"""
	return task_id in current_tasks

func can_be_assigned_to_battle() -> bool:
	"""Check if god can be used in battle (not working on tasks)"""
	# Per design decision: must manually unassign from tasks
	return not is_working_on_task()

# ==============================================================================
# ROLE SYSTEM HELPERS - Simple state checks (logic in RoleManager)
# ==============================================================================

func has_primary_role() -> bool:
	"""Check if god has a primary role assigned"""
	return primary_role != ""

func has_secondary_role() -> bool:
	"""Check if god has a secondary role assigned"""
	return secondary_role != ""

func get_role_ids() -> Array[String]:
	"""Get all assigned role IDs"""
	var role_ids: Array[String] = []
	if primary_role != "":
		role_ids.append(primary_role)
	if secondary_role != "":
		role_ids.append(secondary_role)
	return role_ids

# ==============================================================================
# SPECIALIZATION SYSTEM HELPERS - Simple state checks (logic in SpecializationManager)
# ==============================================================================

func can_specialize() -> bool:
	"""Check if god meets basic requirements for specialization"""
	# Must be level 20+ with a primary role
	return level >= 20 and primary_role != ""

func has_specialization() -> bool:
	"""Check if god has any specialization unlocked"""
	return specialization_path[0] != ""

func get_specialization_tier() -> int:
	"""Get current specialization tier (0=none, 1-3=tier)"""
	if specialization_path[2] != "":
		return 3
	if specialization_path[1] != "":
		return 2
	if specialization_path[0] != "":
		return 1
	return 0

func get_current_specialization() -> String:
	"""Get the highest tier specialization ID"""
	if specialization_path[2] != "":
		return specialization_path[2]
	if specialization_path[1] != "":
		return specialization_path[1]
	if specialization_path[0] != "":
		return specialization_path[0]
	return ""

func get_tier_specialization(current_tier: int) -> String:
	"""Get specialization ID at specific tier (1-3)"""
	if current_tier < 1 or current_tier > 3:
		return ""
	return specialization_path[current_tier - 1]

func has_specialization_at_tier(current_tier: int) -> bool:
	"""Check if god has a specialization at a specific tier"""
	return get_tier_specialization(current_tier) != ""

func get_available_specializations() -> Array[String]:
	"""Get available specializations for next tier - delegates to SpecializationManager"""
	# This is a placeholder - actual logic is in SpecializationManager
	# UI code should call: SystemRegistry.get_system("SpecializationManager").get_available_specializations_for_god(god)
	return []

func apply_specialization(_spec_id: String, _current_tier: int) -> bool:
	"""Apply a specialization at a specific tier - delegates to SpecializationManager"""
	# This is a placeholder - actual logic is in SpecializationManager
	# Game code should call: SystemRegistry.get_system("SpecializationManager").unlock_specialization(god_id, spec_id)
	# This method is just here for API clarity
	return false
