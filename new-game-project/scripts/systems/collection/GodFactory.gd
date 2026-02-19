# scripts/systems/collection/GodFactory.gd
# Single responsibility: Create and initialize God instances
extends RefCounted
class_name GodFactory

# ==============================================================================
# GOD FACTORY - Handle god creation and initialization
# ==============================================================================

static func create_from_json(god_id: String) -> God:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		push_error("SystemRegistry not available")
		return null
	var config_manager: Variant = registry.get_system("ConfigurationManager")
	if not config_manager:
		push_error("ConfigurationManager not available")
		return null
	var god_data: Dictionary = config_manager.get_god_config(god_id)

	if not god_data:
		push_error("God data not found for ID: " + god_id)
		return null

	var god: God = God.new()
	# Generate unique instance ID while preserving template ID
	god.template_id = god_id
	god.id = _generate_unique_id(god_id)
	god.name = god_data.get("name", "Unknown God")
	god.pantheon = god_data.get("pantheon", "unknown")
	god.element = parse_element(god_data.get("element", "fire"))
	god.tier = parse_tier(god_data.get("tier", "common"))
	
	# Base stats - handle nested base_stats structure
	var base_stats: Dictionary = god_data.get("base_stats", {})
	god.base_hp = base_stats.get("hp", god_data.get("base_hp", 100))
	god.base_attack = base_stats.get("attack", god_data.get("base_attack", 50))
	god.base_defense = base_stats.get("defense", god_data.get("base_defense", 30))
	god.base_speed = base_stats.get("speed", god_data.get("base_speed", 100))
	god.base_crit_rate = base_stats.get("crit_rate", god_data.get("base_crit_rate", God.get_default_crit_rate()))
	god.base_crit_damage = base_stats.get("crit_damage", god_data.get("base_crit_damage", God.get_default_crit_damage()))
	god.base_resistance = base_stats.get("resistance", god_data.get("base_resistance", God.get_default_resistance()))
	god.base_accuracy = base_stats.get("accuracy", god_data.get("base_accuracy", God.get_default_accuracy()))
	god.resource_generation = god_data.get("resource_generation", 10)
	
	# Abilities - support both new and legacy formats
	god.active_abilities = god_data.get("active_abilities", [])
	god.passive_abilities = god_data.get("passive_abilities", [])

	# Legacy abilities array - populate from ability_ids for backward compatibility
	var ability_ids: Array = god_data.get("ability_ids", [])
	if not ability_ids.is_empty():
		god.abilities = ability_ids  # BattleUnit still uses this field
	elif not god.active_abilities.is_empty():
		# Extract IDs from active_abilities (for awakened gods with inline ability definitions)
		var extracted_ids: Array = []
		for ability: Dictionary in god.active_abilities:
			var ability_id: String = ability.get("id", "")
			if ability_id != "":
				extracted_ids.append(ability_id)
		god.abilities = extracted_ids

	# Leader skill - applies when this god is first in team (like Summoners War)
	var leader_skill_data: Variant = god_data.get("leader_skill", {})
	if leader_skill_data is Dictionary:
		god.leader_skill = leader_skill_data

	# Awakening data
	god.awakened_name = god_data.get("awakened_name", god.name)
	god.awakened_title = god_data.get("awakened_title", "")
	
	# Initialize equipment slots (6 slots as per prompt.prompt.md)
	god.equipment = [null, null, null, null, null, null]

	# Initialize traits from god definition
	var trait_manager: Variant = registry.get_system("TraitManager")
	if trait_manager:
		trait_manager.initialize_god_traits(god, god_id)

	# Initialize role from god definition
	var role_manager: Variant = registry.get_system("RoleManager")
	if role_manager:
		role_manager.initialize_god_role(god, god_data)

	return god

static func parse_element(element_value: Variant) -> God.ElementType:
	# Handle both integer, float, and string formats
	if element_value is int or element_value is float:
		var index: int = int(element_value)
		match index:
			0:
				return God.ElementType.FIRE
			1:
				return God.ElementType.WATER
			2:
				return God.ElementType.EARTH
			3:
				return God.ElementType.LIGHTNING
			4:
				return God.ElementType.LIGHT
			5:
				return God.ElementType.DARK
			_:
				push_warning("Unknown element index: " + str(index) + ". Defaulting to FIRE.")
				return God.ElementType.FIRE
	elif element_value is String:
		return string_to_element(element_value)
	else:
		push_warning("Invalid element type. Expected int/float or String. Defaulting to FIRE.")
		return God.ElementType.FIRE

static func parse_tier(tier_value: Variant) -> God.TierType:
	# Handle both integer, float, and string formats
	if tier_value is int or tier_value is float:
		var index: int = int(tier_value)
		match index:
			1:
				return God.TierType.COMMON
			2:
				return God.TierType.RARE
			3:
				return God.TierType.EPIC
			4:
				return God.TierType.LEGENDARY
			_:
				push_warning("Unknown tier index: " + str(index) + ". Defaulting to COMMON.")
				return God.TierType.COMMON
	elif tier_value is String:
		return string_to_tier(tier_value)
	else:
		push_warning("Invalid tier type. Expected int/float or String. Defaulting to COMMON.")
		return God.TierType.COMMON

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

static func _generate_unique_id(template_id: String) -> String:
	var timestamp: int = int(Time.get_unix_time_from_system())
	var random_part: int = randi() % 100000
	return "%s_%d_%05d" % [template_id, timestamp, random_part]

## Reset a god's base stats to their original template values
## Keeps level, XP, equipment, etc. - only resets base_hp, base_attack, base_defense, base_speed
static func reset_base_stats_to_template(god: God) -> bool:
	if not god or god.template_id.is_empty():
		return false

	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return false
	var config_manager: Variant = registry.get_system("ConfigurationManager")
	if not config_manager:
		return false

	var god_data: Dictionary = config_manager.get_god_config(god.template_id)
	if god_data.is_empty():
		push_warning("GodFactory: Could not find template for " + god.template_id)
		return false

	# Reset base stats to template values
	var base_stats: Dictionary = god_data.get("base_stats", {})
	god.base_hp = base_stats.get("hp", god_data.get("base_hp", 100))
	god.base_attack = base_stats.get("attack", god_data.get("base_attack", 50))
	god.base_defense = base_stats.get("defense", god_data.get("base_defense", 30))
	god.base_speed = base_stats.get("speed", god_data.get("base_speed", 100))
	god.base_crit_rate = base_stats.get("crit_rate", god_data.get("base_crit_rate", God.get_default_crit_rate()))
	god.base_crit_damage = base_stats.get("crit_damage", god_data.get("base_crit_damage", God.get_default_crit_damage()))
	god.base_resistance = base_stats.get("resistance", god_data.get("base_resistance", God.get_default_resistance()))
	god.base_accuracy = base_stats.get("accuracy", god_data.get("base_accuracy", God.get_default_accuracy()))

	return true

## Migrate all gods in a collection to have correct base stats
## Call this once after loading a save to fix gods with inflated stats
static func migrate_collection_base_stats(gods: Array) -> int:
	var fixed_count: int = 0
	for god: Variant in gods:
		if god is God:
			if reset_base_stats_to_template(god):
				fixed_count += 1
	if fixed_count > 0:
		print("GodFactory: Reset base stats for %d gods" % fixed_count)
	return fixed_count
