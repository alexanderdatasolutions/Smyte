# scripts/data/God.gd
extends Resource
class_name God

const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")
const StatusEffect = preload("res://scripts/data/StatusEffect.gd")

signal level_up(god)

enum ElementType { FIRE, WATER, EARTH, LIGHTNING, LIGHT, DARK }
enum TierType { COMMON, RARE, EPIC, LEGENDARY }

@export var id: String
@export var name: String
@export var pantheon: String  # "greek", "norse", "egyptian"
@export var element: ElementType
@export var tier: TierType
@export var level: int = 1
@export var experience: int = 0

# Combat Stats
@export var base_hp: int
@export var base_attack: int  
@export var base_defense: int
@export var base_speed: int
@export var base_crit_rate: int = 15        # Critical Rate % (SW default: 15%)
@export var base_crit_damage: int = 50      # Critical Damage % (SW default: 50%)
@export var base_resistance: int = 15       # Resistance % (SW default: 15%)
@export var base_accuracy: int = 0          # Accuracy % (SW default: 0%)
@export var resource_generation: int       # Resources per hour

# Equipment System (6 slots like Summoners War)
# Slots: 1=Weapon, 2=Armor, 3=Helm, 4=Boots, 5=Amulet, 6=Ring
@export var equipped_runes: Array = [null, null, null, null, null, null]  # 6 equipment slots

# Abilities - Updated to use JSON format
@export var active_abilities: Array = []  # Array of ability dictionaries
@export var passive_abilities: Array = []  # Array of passive ability dictionaries

# Legacy abilities array for backward compatibility (deprecated)
@export var abilities: Array = []  # Ability IDs
@export var passive_ability: String = ""

# Territory assignment
@export var stationed_territory: String = ""

# Awakening system (Summoners War style)
@export var is_awakened: bool = false
@export var awakened_name: String = ""
@export var awakened_title: String = ""
@export var ascension_level: int = 0  # 0=unascended, 1=bronze, 2=silver, 3=gold, 4=diamond, 5=transcendent
@export var skill_levels: Array[int] = [1, 1, 1, 1]  # Skill levels 1-10 for each skill
@export var awakening_stat_bonuses: Dictionary = {}  # Stat bonuses from awakening

# Battle state (not saved)
var current_hp: int = 0
var status_effects: Array[StatusEffect] = []
var shield_hp: int = 0

# Create god from JSON configuration
static func create_from_json(god_id: String) -> God:
	var god_config = GameDataLoader.get_god_config(god_id)
	if god_config.is_empty():
		print("Error: Could not find god configuration for ID: ", god_id)
		return null
	
	var god = God.new()
	god.id = god_config.id
	god.name = god_config.name
	god.pantheon = god_config.pantheon
	
	# Convert element string to enum
	god.element = string_to_element(god_config.element)
	
	# Convert tier string to enum
	god.tier = string_to_tier(god_config.tier)
	
	# Base stats
	god.base_hp = god_config.base_stats.hp
	god.base_attack = god_config.base_stats.attack
	god.base_defense = god_config.base_stats.defense
	god.base_speed = god_config.base_stats.speed
	god.resource_generation = god_config.get("resource_generation", 10)
	
	# Abilities - Load detailed ability data from JSON
	god.active_abilities = god_config.get("active_abilities", [])
	god.passive_abilities = god_config.get("passive_abilities", [])
	
	# Legacy support - extract ability IDs for backward compatibility
	god.abilities = []
	for ability in god.active_abilities:
		if ability.has("id"):
			god.abilities.append(ability.id)
	
	# Legacy passive ability
	if god.passive_abilities.size() > 0 and god.passive_abilities[0].has("id"):
		god.passive_ability = god.passive_abilities[0].id
	else:
		god.passive_ability = ""
	
	# Check if this is an awakened god based on ID
	if god_id.ends_with("_awakened"):
		god.is_awakened = true
		print("DEBUG: Marked god %s as awakened" % god_id)
	
	# Initialize battle stats
	god.level = 1
	god.experience = 0
	god.current_hp = god.get_max_hp()
	
	return god

# Utility functions for converting strings to enums
static func string_to_element(element_string: String) -> ElementType:
	match element_string.to_lower():
		"fire":
			return ElementType.FIRE
		"water":
			return ElementType.WATER
		"earth":
			return ElementType.EARTH
		"lightning":
			return ElementType.LIGHTNING
		"light":
			return ElementType.LIGHT
		"dark":
			return ElementType.DARK
		_:
			print("Warning: Unknown element string: ", element_string)
			return ElementType.FIRE

static func string_to_tier(tier_string: String) -> TierType:
	match tier_string.to_lower():
		"common":
			return TierType.COMMON
		"rare":
			return TierType.RARE
		"epic":
			return TierType.EPIC
		"legendary":
			return TierType.LEGENDARY
		_:
			print("Warning: Unknown tier string: ", tier_string)
			return TierType.COMMON

# Calculated stats based on level, tier, and equipment
func get_current_hp() -> int:
	var base_stat = base_hp + (level * 10) + (int(tier) * 50)
	var equipment_bonus = _get_equipment_stat_bonus("hp")
	return int(base_stat * (1.0 + _get_stat_modifier("hp"))) + equipment_bonus

func get_max_hp() -> int:
	return get_current_hp()  # Alias for battle system

func get_current_attack() -> int:
	var base_stat = base_attack + (level * 8) + (int(tier) * 40)
	var equipment_bonus = _get_equipment_stat_bonus("attack")
	return int((base_stat + equipment_bonus) * (1.0 + _get_stat_modifier("attack")))

func get_current_defense() -> int:
	var base_stat = base_defense + (level * 6) + (int(tier) * 30)
	var equipment_bonus = _get_equipment_stat_bonus("defense")
	return int((base_stat + equipment_bonus) * (1.0 + _get_stat_modifier("defense")))

func get_current_speed() -> int:
	var base_stat = base_speed + (level * 4) + (int(tier) * 20)
	var equipment_bonus = _get_equipment_stat_bonus("speed")
	return int((base_stat + equipment_bonus) * (1.0 + _get_stat_modifier("speed")))

func get_current_crit_rate() -> int:
	"""Get current critical rate percentage (15-100%)"""
	var base_stat = base_crit_rate + (level * 0.5) + (int(tier) * 5)
	return int(base_stat * (1.0 + _get_stat_modifier("crit_rate")))

func get_current_crit_damage() -> int:
	"""Get current critical damage percentage (50-300%)"""
	var base_stat = base_crit_damage + (level * 1.0) + (int(tier) * 10)
	return int(base_stat * (1.0 + _get_stat_modifier("crit_damage")))

func get_current_accuracy() -> int:
	"""Get current accuracy percentage (0-85%)"""
	var base_stat = base_accuracy + (int(tier) * 5)
	return int(base_stat * (1.0 + _get_stat_modifier("accuracy")))

func get_current_resistance() -> int:
	"""Get current resistance percentage (15-100%)"""
	var base_stat = base_resistance + (level * 0.3) + (int(tier) * 5)
	return int(base_stat * (1.0 + _get_stat_modifier("resistance")))

func _get_equipment_stat_bonus(stat_type: String) -> int:
	"""Get total equipment stat bonus - integrates with Equipment system"""
	var total_bonus = 0
	
	# Sum bonuses from all equipped equipment
	for equipment in equipped_runes:
		if equipment != null and equipment is Equipment:
			var bonuses = equipment.get_stat_bonuses()
			total_bonus += bonuses.get(stat_type, 0)
	
	# Add set bonuses if EquipmentManager is available in GameManager
	if GameManager and GameManager.has_method("get_equipment_manager"):
		var equipment_manager = GameManager.get_equipment_manager()
		if equipment_manager and equipment_manager.has_method("get_equipped_set_bonuses"):
			var set_bonuses = equipment_manager.get_equipped_set_bonuses(self)
			total_bonus += set_bonuses.get(stat_type, 0)
	
	return total_bonus

func _get_stat_modifier(stat_name: String) -> float:
	"""Get total modifier for a stat from all status effects and awakening bonuses"""
	var total_modifier = 0.0
	
	# Add status effect modifiers
	for effect in status_effects:
		total_modifier += effect.get_stat_modifier(stat_name)
	
	# Add awakening bonuses
	if is_awakened:
		total_modifier += get_awakening_stat_bonus(stat_name)
	
	# Add ascension bonuses
	total_modifier += get_ascension_bonus(stat_name)
	
	return total_modifier

func get_ascension_bonus(_stat_name: String) -> float:
	"""Get stat bonus from ascension level"""
	if ascension_level == 0:
		return 0.0
		
	# Each ascension level gives 5% bonus to all stats
	return ascension_level * 0.05

func get_power_rating() -> int:
	return get_current_hp() + get_current_attack() + get_current_defense() + get_current_speed()

func get_tier_multiplier() -> float:
	match tier:
		TierType.COMMON:
			return 1.0
		TierType.RARE:
			return 1.5
		TierType.EPIC:
			return 2.0
		TierType.LEGENDARY:
			return 2.5
	return 1.0

func get_experience_to_next_level() -> int:
	# Summoners War style exponential XP scaling
	if level >= 40:
		return 0  # Max level reached
	
	# SW XP formula approximation - gets much harder at higher levels
	var base_xp = 100
	var level_multiplier = pow(level, 1.8)  # Exponential growth
	return int(base_xp * level_multiplier)

func add_experience(amount: int):
	experience += amount
	while experience >= get_experience_to_next_level() and level < 40:  # Max level 40
		experience -= get_experience_to_next_level()
		level += 1
		# Heal to full on level up
		current_hp = get_max_hp()
		print("%s leveled up to %d!" % [name, level])
		level_up.emit(self)

func prepare_for_battle():
	# Initialize HP for battle
	if current_hp <= 0:
		current_hp = get_max_hp()

func heal_full():
	current_hp = get_max_hp()

func get_element_name() -> String:
	match element:
		ElementType.FIRE:
			return "Fire"
		ElementType.WATER:
			return "Water"
		ElementType.EARTH:
			return "Earth"
		ElementType.LIGHTNING:
			return "Lightning"
		ElementType.LIGHT:
			return "Light"
		ElementType.DARK:
			return "Dark"
	return "Unknown"

func get_tier_name() -> String:
	match tier:
		TierType.COMMON:
			return "Common"
		TierType.RARE:
			return "Rare"
		TierType.EPIC:
			return "Epic"
		TierType.LEGENDARY:
			return "Legendary"
	return "Unknown"

# Helper methods for the new JSON ability system
func get_active_ability_by_id(ability_id: String) -> Dictionary:
	"""Get an active ability by its ID"""
	for ability in active_abilities:
		if ability.get("id", "") == ability_id:
			return ability
	return {}

func get_random_active_ability() -> Dictionary:
	"""Get a random active ability for battle use"""
	if active_abilities.size() > 0:
		var ability = active_abilities[randi() % active_abilities.size()]
		# Ensure the ability is a valid dictionary
		if ability is Dictionary and not ability.is_empty():
			return ability
	
	# Return empty dictionary if no valid abilities found
	return {}

func has_valid_abilities() -> bool:
	"""Check if god has any valid active abilities"""
	if active_abilities.size() == 0:
		return false
	
	for ability in active_abilities:
		if ability is Dictionary and not ability.is_empty():
			return true
	
	return false

func has_active_ability(ability_id: String) -> bool:
	"""Check if god has a specific active ability"""
	for ability in active_abilities:
		if ability.get("id", "") == ability_id:
			return true
	return false

func get_ability_names() -> Array[String]:
	"""Get list of ability names for UI display"""
	var names: Array[String] = []
	for ability in active_abilities:
		names.append(ability.get("name", "Unknown Ability"))
	return names

func get_passive_ability_descriptions() -> Array[String]:
	"""Get descriptions of all passive abilities"""
	var descriptions: Array[String] = []
	for passive in passive_abilities:
		var desc = "%s: %s" % [passive.get("name", "Unknown"), passive.get("description", "No description")]
		descriptions.append(desc)
	return descriptions

# Status Effect Management
func add_status_effect(effect: StatusEffect):
	"""Add a status effect to this god"""
	# Check for immunity
	if has_debuff_immunity() and effect.effect_type == StatusEffect.EffectType.DEBUFF:
		print("%s is immune to %s" % [name, effect.name])
		return false
	
	# Check if effect can stack
	var existing_effect = get_status_effect(effect.id)
	if existing_effect:
		if effect.can_stack and existing_effect.stacks < existing_effect.max_stacks:
			existing_effect.stacks += 1
			existing_effect.duration = max(existing_effect.duration, effect.duration)
			print("%s now has %s (x%d)" % [name, effect.name, existing_effect.stacks])
		else:
			# Refresh duration if same effect
			existing_effect.duration = effect.duration
			print("%s refreshed %s duration" % [name, effect.name])
	else:
		status_effects.append(effect)
		print("%s gained %s!" % [name, effect.name])
	
	return true

func remove_status_effect(effect_id: String):
	"""Remove a specific status effect"""
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].id == effect_id:
			print("%s lost %s" % [name, status_effects[i].name])
			status_effects.remove_at(i)
			return true
	return false

func get_status_effect(effect_id: String) -> StatusEffect:
	"""Get a specific status effect by ID"""
	for effect in status_effects:
		if effect.id == effect_id:
			return effect
	return null

func has_status_effect(effect_id: String) -> bool:
	"""Check if god has a specific status effect"""
	return get_status_effect(effect_id) != null

func has_debuff_immunity() -> bool:
	"""Check if god is immune to debuffs"""
	for effect in status_effects:
		if effect.immune_to_debuffs:
			return true
	return false

func has_damage_immunity() -> bool:
	"""Check if god has damage immunity"""
	for effect in status_effects:
		if effect.immune_to_damage:
			return true
	return false

func can_act() -> bool:
	"""Check if god can take actions (not stunned/feared/etc)"""
	for effect in status_effects:
		if effect.prevents_action:
			return false
	return true

func can_use_abilities() -> bool:
	"""Check if god can use abilities (not silenced)"""
	if not can_act():
		return false
	for effect in status_effects:
		if effect.prevents_abilities:
			return false
	return true

func process_turn_start_effects() -> Dictionary:
	"""Process all status effects at start of turn"""
	var results = {"total_damage": 0, "total_healing": 0, "messages": []}
	
	# Process each effect
	for i in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		var effect_result = effect.apply_turn_effects(self)
		
		# Apply damage
		if effect_result.damage > 0:
			var actual_damage = take_damage(effect_result.damage)
			results.total_damage += actual_damage
		
		# Apply healing
		if effect_result.healing > 0:
			var actual_healing = heal(effect_result.healing)
			results.total_healing += actual_healing
		
		# Add messages
		results.messages.append_array(effect_result.messages)
		
		# Remove expired effects
		if effect.is_expired():
			print("%s's %s expired" % [name, effect.name])
			status_effects.remove_at(i)
	
	return results

func take_damage(damage: int) -> int:
	"""Take damage, considering shields and immunities"""
	if has_damage_immunity():
		return 0
	
	var actual_damage = damage
	
	# Apply shields first
	if shield_hp > 0:
		var shield_absorbed = min(shield_hp, actual_damage)
		shield_hp -= shield_absorbed
		actual_damage -= shield_absorbed
		if shield_absorbed > 0:
			print("%s's shield absorbed %d damage" % [name, shield_absorbed])
	
	# Apply remaining damage to HP
	if actual_damage > 0:
		current_hp = max(0, current_hp - actual_damage)
	
	return damage  # Return original damage for battle log

func heal(amount: int) -> int:
	"""Heal the god, returns actual amount healed"""
	if current_hp >= get_max_hp():
		return 0
	
	var actual_heal = min(amount, get_max_hp() - current_hp)
	current_hp += actual_heal
	return actual_heal

func clear_all_status_effects():
	"""Remove all status effects (for battle end)"""
	status_effects.clear()
	shield_hp = 0

func get_buffs() -> Array[StatusEffect]:
	"""Get all buff effects"""
	var buffs: Array[StatusEffect] = []
	for effect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.BUFF or effect.effect_type == StatusEffect.EffectType.HOT:
			buffs.append(effect)
	return buffs

# Awakening System Methods
func can_awaken() -> bool:
	"""Check if god meets awakening requirements - Summoners War style"""
	if is_awakened:
		return false
		
	# Check basic requirements - max level required for awakening
	if level < 40:
		return false
		
	# In Summoners War, awakening only requires max level + materials
	# Skill levels are separate upgrades and not required for awakening
	# Materials check is done in GameManager/AwakeningSystem
	return true

func awaken(awakening_data: Dictionary) -> bool:
	"""Awaken the god with new powers"""
	if not can_awaken():
		return false
		
	is_awakened = true
	awakened_name = awakening_data.get("awakened_name", name + " (Awakened)")
	awakened_title = awakening_data.get("new_title", "Awakened")
	awakening_stat_bonuses = awakening_data.get("stat_bonuses", {})
	
	# Apply visual changes, enhanced skills, etc. would be handled by UI/Battle systems
	print("%s has awakened into %s - %s!" % [name, awakened_name, awakened_title])
	
	return true

func get_display_name() -> String:
	"""Get the name to display (awakened name if awakened)"""
	return awakened_name if is_awakened else name

func get_display_title() -> String:
	"""Get the title to display"""
	return awakened_title if is_awakened else get_tier_name()

func upgrade_skill(skill_index: int) -> bool:
	"""Upgrade a specific skill level"""
	if skill_index < 0 or skill_index >= skill_levels.size():
		return false
		
	if skill_levels[skill_index] >= 10:
		return false  # Already maxed
		
	skill_levels[skill_index] += 1
	print("%s's skill %d upgraded to level %d" % [name, skill_index + 1, skill_levels[skill_index]])
	return true

func ascend(new_level: int) -> bool:
	"""Ascend the god to a higher tier"""
	if new_level <= ascension_level or new_level > 5:
		return false
		
	ascension_level = new_level
	var ascension_names = ["Unascended", "Bronze", "Silver", "Gold", "Diamond", "Transcendent"]
	print("%s ascended to %s tier!" % [name, ascension_names[ascension_level]])
	return true

func get_ascension_name() -> String:
	"""Get the ascension tier name"""
	var ascension_names = ["Unascended", "Bronze", "Silver", "Gold", "Diamond", "Transcendent"]
	if ascension_level >= 0 and ascension_level < ascension_names.size():
		return ascension_names[ascension_level]
	return "Unknown"

func get_awakening_stat_bonus(stat_name: String) -> float:
	"""Get the awakening bonus for a specific stat"""
	if not is_awakened:
		return 0.0
	return awakening_stat_bonuses.get(stat_name, 0.0)

func get_debuffs() -> Array[StatusEffect]:
	"""Get all debuff effects"""
	var debuffs: Array[StatusEffect] = []
	for effect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT:
			debuffs.append(effect)
	return debuffs

func get_sprite() -> Texture2D:
	"""Get the sprite texture for this god (awakened or normal)"""
	var sprite_name: String
	
	if is_awakened:
		# For awakened gods, convert ID format from "godname_awakened" to "awakened_godname.png"
		var base_god_name = id.to_lower()
		if base_god_name.ends_with("_awakened"):
			base_god_name = base_god_name.replace("_awakened", "")
		sprite_name = "awakened_" + base_god_name + ".png"
	else:
		# For normal gods, use the format "godname.png"
		var base_god_name = id.to_lower()
		if base_god_name.ends_with("_awakened"):
			base_god_name = base_god_name.replace("_awakened", "")
		sprite_name = base_god_name + ".png"
	
	var sprite_path = "res://assets/gods/" + sprite_name
	
	# Try to load the sprite
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path)
	else:
		print("DEBUG: Sprite not found at %s" % sprite_path)
		# Fallback: if awakened sprite doesn't exist, try normal sprite
		if is_awakened:
			var base_god_name = id.to_lower()
			if base_god_name.ends_with("_awakened"):
				base_god_name = base_god_name.replace("_awakened", "")
			var fallback_path = "res://assets/gods/" + base_god_name + ".png"
			if ResourceLoader.exists(fallback_path):
				return load(fallback_path)
		
		# If no sprite found, return null (calling code should handle this)
		return null

func has_sprite() -> bool:
	"""Check if this god has a sprite available"""
	return get_sprite() != null
