# scripts/systems/collection/GodFactory.gd
# Single responsibility: Create and initialize God instances
extends RefCounted
class_name GodFactory

# ==============================================================================
# GOD FACTORY - Handle god creation and initialization
# ==============================================================================

static func create_from_json(god_id: String) -> God:
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	var god_data = config_manager.get_god_config(god_id)
	
	if not god_data:
		push_error("God data not found for ID: " + god_id)
		return null
	
	var god = God.new()
	god.id = god_id
	god.name = god_data.get("name", "Unknown God")
	god.pantheon = god_data.get("pantheon", "unknown")
	god.element = string_to_element(god_data.get("element", "fire"))
	god.tier = string_to_tier(god_data.get("tier", "common"))
	
	# Base stats - handle nested base_stats structure
	var base_stats = god_data.get("base_stats", {})
	god.base_hp = base_stats.get("hp", god_data.get("base_hp", 100))
	god.base_attack = base_stats.get("attack", god_data.get("base_attack", 50))
	god.base_defense = base_stats.get("defense", god_data.get("base_defense", 30))
	god.base_speed = base_stats.get("speed", god_data.get("base_speed", 100))
	god.base_crit_rate = base_stats.get("crit_rate", god_data.get("base_crit_rate", 15))
	god.base_crit_damage = base_stats.get("crit_damage", god_data.get("base_crit_damage", 50))
	god.base_resistance = base_stats.get("resistance", god_data.get("base_resistance", 15))
	god.base_accuracy = base_stats.get("accuracy", god_data.get("base_accuracy", 0))
	god.resource_generation = god_data.get("resource_generation", 10)
	
	# Abilities
	god.active_abilities = god_data.get("active_abilities", [])
	god.passive_abilities = god_data.get("passive_abilities", [])
	
	# Awakening data
	god.awakened_name = god_data.get("awakened_name", god.name)
	god.awakened_title = god_data.get("awakened_title", "")
	
	# Initialize equipment slots (6 slots as per prompt.prompt.md)
	god.equipment = [null, null, null, null, null, null]
	
	return god

static func string_to_element(element_string: String) -> God.ElementType:
	match element_string.to_lower():
		"fire":
			return God.ElementType.FIRE
		"water":
			return God.ElementType.WATER
		"earth":
			return God.ElementType.EARTH
		"lightning":
			return God.ElementType.LIGHTNING
		"light":
			return God.ElementType.LIGHT
		"dark":
			return God.ElementType.DARK
		_:
			push_warning("Unknown element type: " + element_string + ". Defaulting to FIRE.")
			return God.ElementType.FIRE

static func element_to_string(element_type: God.ElementType) -> String:
	match element_type:
		God.ElementType.FIRE:
			return "fire"
		God.ElementType.WATER:
			return "water"
		God.ElementType.EARTH:
			return "earth"
		God.ElementType.LIGHTNING:
			return "lightning"
		God.ElementType.LIGHT:
			return "light"
		God.ElementType.DARK:
			return "dark"
		_:
			return "fire"

static func string_to_tier(tier_string: String) -> God.TierType:
	match tier_string.to_lower():
		"common":
			return God.TierType.COMMON
		"rare":
			return God.TierType.RARE
		"epic":
			return God.TierType.EPIC
		"legendary":
			return God.TierType.LEGENDARY
		_:
			push_warning("Unknown tier type: " + tier_string + ". Defaulting to COMMON.")
			return God.TierType.COMMON

static func tier_to_string(tier_type: God.TierType) -> String:
	match tier_type:
		God.TierType.COMMON:
			return "common"
		God.TierType.RARE:
			return "rare"
		God.TierType.EPIC:
			return "epic"
		God.TierType.LEGENDARY:
			return "legendary"
		_:
			return "common"
