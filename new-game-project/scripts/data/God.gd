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
# TERRITORY SYSTEM
# ==============================================================================
@export var stationed_territory: String = ""
@export var territory_role: String = ""  # "defender", "gatherer", "crafter"

# ==============================================================================
# AWAKENING SYSTEM - Summoners War style
# ==============================================================================
@export var is_awakened: bool = false
@export var awakened_name: String = ""
@export var awakened_title: String = ""
@export var ascension_level: int = 0  # 0=unascended, 1=bronze, 2=silver, 3=gold, 4=diamond, 5=transcendent
@export var skill_levels: Array = [1, 1, 1, 1]  # Array[int] - Skill levels 1-10 for each skill

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
