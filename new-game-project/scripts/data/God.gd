# scripts/data/God.gd - PURE DATA CLASS (NO LOGIC)
extends Resource
class_name God

enum ElementType { FIRE, WATER, EARTH, LIGHTNING, LIGHT, DARK }
enum TierType { COMMON, RARE, EPIC, LEGENDARY }

# ==============================================================================
# CONFIG - Loaded from JSON files (static cache)
# ==============================================================================
static var _config: Dictionary = {}
static var _config_loaded: bool = false
static var _progression_config: Dictionary = {}
static var _progression_loaded: bool = false

static func _load_god_config() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	var file := FileAccess.open("res://data/god_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed

static func _load_progression_config() -> void:
	if _progression_loaded:
		return
	_progression_loaded = true
	var file := FileAccess.open("res://data/progression_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_progression_config = parsed

# Level config comes from progression_config.json (single source of truth)
static func get_max_level() -> int:
	_load_progression_config()
	return _progression_config.get("god_leveling", {}).get("max_god_level", 999)

static func get_awakened_max_level() -> int:
	_load_progression_config()
	return _progression_config.get("god_leveling", {}).get("awakened_max_level", 999)

static func get_soft_cap_level() -> int:
	"""Level where diminishing returns begin (not a hard cap)"""
	_load_progression_config()
	return _progression_config.get("god_leveling", {}).get("soft_cap_level", 40)

# Default stats come from god_config.json
static func get_default_crit_rate() -> int:
	_load_god_config()
	return _config.get("default_stats", {}).get("crit_rate", 15)

static func get_default_crit_damage() -> int:
	_load_god_config()
	return _config.get("default_stats", {}).get("crit_damage", 50)

static func get_default_resistance() -> int:
	_load_god_config()
	return _config.get("default_stats", {}).get("resistance", 15)

static func get_default_accuracy() -> int:
	_load_god_config()
	return _config.get("default_stats", {}).get("accuracy", 0)

# Legacy const aliases for backward compatibility with @export defaults and external callers
# These keep the same values as fallback defaults; config overrides via static methods above
const MAX_LEVEL: int = 999  # No hard cap - use get_soft_cap_level() for diminishing returns threshold
const SOFT_CAP_LEVEL: int = 40  # Where diminishing returns begin
const DEFAULT_CRIT_RATE: int = 15
const DEFAULT_CRIT_DAMAGE: int = 50
const DEFAULT_RESISTANCE: int = 15
const DEFAULT_ACCURACY: int = 0

# ==============================================================================
# CORE IDENTITY - Pure data properties only
# ==============================================================================
@export var id: String  # Unique instance ID (e.g., "zeus_1707664823_abc123")
@export var template_id: String  # Base god template ID (e.g., "zeus")
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
@export var base_crit_rate: int = DEFAULT_CRIT_RATE
@export var base_crit_damage: int = DEFAULT_CRIT_DAMAGE
@export var base_resistance: int = DEFAULT_RESISTANCE
@export var base_accuracy: int = DEFAULT_ACCURACY
@export var resource_generation: int       # Resources per hour

# ==============================================================================
# EQUIPMENT SYSTEM - 6 slots like Summoners War
# ==============================================================================
# Slots: 1=Weapon, 2=Armor, 3=Helm, 4=Boots, 5=Amulet, 6=Ring
# Contains Equipment or null (empty slot) - untyped for JSON deserialization compatibility
@export var equipment: Array = [null, null, null, null, null, null]

# ==============================================================================
# ABILITIES - JSON format data
# ==============================================================================
@export var active_abilities: Array = []  # Array[Dictionary] - untyped: assigned from JSON parse
@export var passive_abilities: Array = []  # Array[Dictionary] - untyped: assigned from JSON parse

# Legacy abilities array for backward compatibility (deprecated)
@export var abilities: Array = []  # Array[String] - untyped: assigned from JSON parse, legacy field
@export var passive_ability: String = ""

# ==============================================================================
# LEADER SKILL - Summoners War style (first god in team applies bonus)
# ==============================================================================
# Structure: {"type": "attack", "value": 33, "area": "all"} or {"area": "fire"}
@export var leader_skill: Dictionary = {}

# ==============================================================================
# TRAIT SYSTEM - Palworld-style innate abilities
# ==============================================================================
@export var innate_traits: Array[String] = []  # Traits from god_innate_traits (permanent)
@export var learned_traits: Array[String] = []  # Traits gained through gameplay

# ==============================================================================
# ROLE SYSTEM
# ==============================================================================
@export var primary_role: String = ""  # Primary role ID (fighter, gatherer, crafter, scholar, support)
@export var secondary_role: String = ""  # Optional secondary role ID (50% bonus strength)

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
# COLLECTION TRACKING
# ==============================================================================
@export var summon_time: int = 0  # Unix timestamp when god was summoned/acquired

# ==============================================================================
# AWAKENING SYSTEM - Summoners War style
# ==============================================================================
@export var is_awakened: bool = false
@export var awakened_name: String = ""
@export var awakened_title: String = ""
@export var ascension_level: int = 0  # 0=unascended, 1=bronze, 2=silver, 3=gold, 4=diamond, 5=transcendent
@export var skill_levels: Array[int] = [1, 1, 1, 1]

# ==============================================================================
# COSMETICS SYSTEM
# ==============================================================================
@export var equipped_skin_id: String = ""  # Currently equipped skin ID
@export var default_portrait_path: String = ""  # Base portrait path

# ==============================================================================
# BATTLE STATE - Runtime data
# ==============================================================================
@export var current_hp: int = 0  # Set during battle preparation
@export var status_effects: Array[StatusEffect] = []
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
	"""Check if god can level up (no hard cap, but technically limited to 999)"""
	return level < God.get_max_level()

func is_past_soft_cap() -> bool:
	"""Check if god has leveled past the soft cap (diminishing returns zone)"""
	return level >= God.get_soft_cap_level()

func has_ability(ability_id: String) -> bool:
	for ability: Dictionary in active_abilities:
		if ability.get("id") == ability_id:
			return true
	return false

func is_equipped() -> bool:
	# Check if god has any equipment equipped
	for eq: Variant in equipment:
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
static func element_to_string(element_enum: ElementType) -> String:
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
static func tier_to_string(tier_enum: TierType) -> String:
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

