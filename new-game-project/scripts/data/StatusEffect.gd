# StatusEffect.gd - Status effect system for battle
extends Resource
class_name StatusEffect

enum EffectType {
	BUFF,
	DEBUFF,
	DOT,  # Damage over time
	HOT   # Heal over time
}

@export var id: String
@export var name: String
@export var description: String
@export var effect_type: EffectType
@export var duration: int = 3
@export var stacks: int = 1
@export var can_stack: bool = false
@export var max_stacks: int = 5

# Effect values
@export var stat_modifier: Dictionary = {}  # "attack": 0.5, "defense": 0.3, etc.
@export var damage_per_turn: float = 0.0
@export var heal_per_turn: float = 0.0
@export var shield_value: int = 0
@export var prevents_action: bool = false
@export var prevents_abilities: bool = false
@export var immune_to_debuffs: bool = false
@export var immune_to_damage: bool = false

# Additional effect properties
@export var dot_damage: int = 0  # Flat damage over time
@export var damage_immunity: bool = false
@export var charmed: bool = false
@export var untargetable: bool = false
@export var counter_attack: bool = false
@export var reflect_damage: float = 0.0  # Percentage of damage to reflect

# Status-specific boolean flags
@export var frozen: bool = false
@export var sleeping: bool = false
@export var silenced: bool = false
@export var provoked: bool = false

# Visual properties
@export var icon_path: String = ""
@export var color: Color = Color.WHITE

func _init(effect_id: String = "", effect_name: String = ""):
	id = effect_id
	name = effect_name

func apply_turn_effects(target) -> Dictionary:
	"""Apply effects at start of turn, returns effect results"""
	var results = {"damage": 0, "healing": 0, "messages": []}
	
	# Damage over time
	if damage_per_turn > 0:
		var turn_dot_damage = 0
		if target is God:
			turn_dot_damage = int(target.get_max_hp() * damage_per_turn * stacks)
		else:
			turn_dot_damage = int(target.hp * damage_per_turn * stacks)
		
		results.damage = turn_dot_damage
		results.messages.append("%s takes %d %s damage!" % [_get_target_name(target), turn_dot_damage, name])
	
	# Flat damage over time (from dot_damage property)
	if dot_damage > 0:
		var flat_damage = dot_damage * stacks
		results.damage += flat_damage
		results.messages.append("%s takes %d %s damage!" % [_get_target_name(target), flat_damage, name])
	
	# Heal over time
	if heal_per_turn > 0:
		var hot_healing = 0
		if target is God:
			hot_healing = int(target.get_max_hp() * heal_per_turn * stacks)
		else:
			hot_healing = int(target.hp * heal_per_turn * stacks)
		
		results.healing = hot_healing
		results.messages.append("%s recovers %d HP from %s!" % [_get_target_name(target), hot_healing, name])
	
	# Reduce duration
	duration -= 1
	
	return results

func get_stat_modifier(stat_name: String) -> float:
	"""Get the modifier for a specific stat"""
	return stat_modifier.get(stat_name, 0.0) * stacks

func is_expired() -> bool:
	return duration <= 0

func _get_target_name(target) -> String:
	if target is God:
		return target.name
	else:
		return target.get("name", "Enemy")

# Helper function to get attack stat from caster
static func _get_attack(caster) -> int:
	if caster is God:
		return caster.get_current_attack()
	else:
		return caster.get("attack", 100)  # Fallback for enemies

# Factory methods for common effects - ALL SCALED TO SUMMONERS WAR SPECS
static func create_stun(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("stun", "Stunned")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.prevents_action = true
	effect.description = "Stunned, cannot act"
	effect.color = Color.YELLOW
	return effect

static func create_burn(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("burn", "Burning")
	effect.effect_type = EffectType.DOT
	effect.duration = turns
	# Summoners War: 15% max HP per turn
	effect.damage_per_turn = 0.15
	effect.description = "Takes 15% max HP fire damage each turn"
	effect.color = Color.ORANGE_RED
	effect.can_stack = false  # Burns don't stack in SW
	return effect

static func create_continuous_damage(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("continuous_damage", "Continuous Damage")
	effect.effect_type = EffectType.DOT
	effect.duration = turns
	# Summoners War: 15% max HP per turn (same as burn)
	effect.damage_per_turn = 0.15
	effect.description = "Takes 15% max HP damage each turn"
	effect.color = Color.RED
	effect.can_stack = true  # Continuous damage can stack in SW
	return effect

static func create_regeneration(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("regeneration", "Regeneration")
	effect.effect_type = EffectType.HOT
	effect.duration = turns
	# Summoners War: 15% max HP per turn
	effect.heal_per_turn = 0.15
	effect.description = "Recovers 15% max HP each turn"
	effect.color = Color.GREEN
	return effect

static func create_attack_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("attack_boost", "Attack Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 50% attack increase
	effect.stat_modifier["attack"] = 0.5
	effect.description = "Attack increased by 50%"
	effect.color = Color.RED
	print("BUFF SCALING: Attack Boost = +50% ATK for %d turns" % turns)
	return effect

static func create_defense_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("defense_boost", "Defense Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 50% defense increase
	effect.stat_modifier["defense"] = 0.5
	effect.description = "Defense increased by 50%"
	effect.color = Color.BLUE
	return effect

static func create_speed_boost(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("speed_boost", "Speed Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 30% speed increase, 2 turns duration
	effect.stat_modifier["speed"] = 0.3
	effect.description = "Speed increased by 30%"
	effect.color = Color.CYAN
	return effect

static func create_shield(caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("shield", "Shield")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: shield_value = caster.attack * 0.5
	var caster_attack = _get_attack(caster)
	var shield_amount = int(caster_attack * 0.5)
	effect.shield_value = shield_amount
	effect.description = "Absorbs %d damage" % shield_amount
	effect.color = Color.LIGHT_BLUE
	print("SHIELD SCALING: %s ATK(%d) × 0.5 = %d shield HP" % [caster.name if caster else "Unknown", caster_attack, shield_amount])
	return effect

static func create_fear(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("fear", "Feared")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.prevents_action = true  # Simplified - in full game could be chance-based
	effect.description = "Too scared to act"
	effect.color = Color.PURPLE
	return effect

static func create_slow(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("slow", "Slowed")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: 50% speed reduction
	effect.stat_modifier["speed"] = -0.5
	effect.description = "Speed reduced by 50%"
	effect.color = Color.DARK_BLUE
	return effect

static func create_debuff_immunity(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("debuff_immunity", "Debuff Immunity")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	effect.immune_to_debuffs = true
	effect.description = "Immune to negative effects"
	effect.color = Color.GOLD
	return effect

static func create_accuracy_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("accuracy_boost", "Accuracy Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 50% accuracy boost
	effect.stat_modifier["accuracy"] = 0.5
	effect.description = "Accuracy increased by 50%"
	effect.color = Color.YELLOW
	return effect

static func create_evasion_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("evasion_boost", "Evasion Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Evasion increase - makes unit harder to hit
	effect.stat_modifier["evasion"] = 0.3
	effect.description = "Evasion increased by 30%"
	effect.color = Color.CYAN
	return effect

static func create_crit_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("crit_boost", "Critical Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 30% crit chance boost + 20% crit damage boost
	effect.stat_modifier["critical_chance"] = 0.3
	effect.stat_modifier["critical_damage"] = 0.2
	effect.description = "Critical hit chance increased by 30%, critical damage increased by 20%"
	effect.color = Color.ORANGE
	return effect

static func create_critical_damage_boost(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("crit_damage_boost", "Critical Damage Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Pure critical damage enhancement
	effect.stat_modifier["critical_damage"] = 0.5
	effect.description = "Critical hit damage increased by 50%"
	effect.color = Color.CRIMSON
	return effect

static func create_wisdom_boost(_caster, turns: int = 5) -> StatusEffect:
	var effect = StatusEffect.new("wisdom_boost", "Wisdom Boost")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	effect.stat_modifier["magic_power"] = 0.20
	effect.stat_modifier["cooldown_reduction"] = 0.10
	effect.description = "Enhanced magical abilities"
	effect.color = Color.CYAN
	return effect

static func create_analyze_weakness(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("analyze_weakness", "Analyzed")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: Marked for Death - 25% more damage taken
	effect.stat_modifier["damage_taken"] = 0.25
	effect.description = "Takes 25% more damage from all sources"
	effect.color = Color.DARK_RED
	return effect

static func create_marked_for_death(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("marked_for_death", "Marked for Death")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: 25% damage increase taken
	effect.stat_modifier["damage_taken"] = 0.25
	effect.description = "Takes 25% more damage from all sources"
	effect.color = Color.DARK_RED
	return effect

static func create_defense_reduction(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("defense_reduction", "Defense Down")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: 30% defense reduction
	effect.stat_modifier["defense"] = -0.3
	effect.description = "Defense reduced by 30%"
	effect.color = Color.ORANGE_RED
	return effect

static func create_attack_reduction(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("attack_reduction", "Attack Down")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: 30% attack reduction
	effect.stat_modifier["attack"] = -0.3
	effect.description = "Attack reduced by 30%"
	effect.color = Color.ORANGE_RED
	return effect

static func create_damage_immunity(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("damage_immunity", "Damage Immunity")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	effect.damage_immunity = true
	effect.description = "Immune to all damage"
	effect.color = Color.GOLD
	return effect

static func create_charm(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("charm", "Charmed")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.charmed = true
	effect.description = "Attacks own allies"
	effect.color = Color.PINK
	return effect

static func create_untargetable(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("untargetable", "Untargetable")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	effect.untargetable = true
	effect.description = "Cannot be targeted by attacks"
	effect.color = Color.LIGHT_GRAY
	return effect

static func create_counter_attack(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("counter_attack", "Counter Attack")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	effect.counter_attack = true
	effect.description = "75% chance to counter-attack when attacked"
	effect.color = Color.ORANGE
	return effect

static func create_blind(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("blind", "Blinded")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: 50% accuracy reduction
	effect.stat_modifier["accuracy"] = -0.5
	effect.description = "Accuracy reduced by 50%"
	effect.color = Color.BLACK
	return effect

static func create_reflect_damage(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("reflect_damage", "Damage Reflection")
	effect.effect_type = EffectType.BUFF
	effect.duration = turns
	# Summoners War: 30% damage reflection
	effect.reflect_damage = 0.30
	effect.description = "Reflects 30% damage back to attackers"
	effect.color = Color.SILVER
	return effect

static func create_immobilize(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("immobilize", "Immobilized")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.prevents_action = true
	effect.description = "Cannot move or act"
	effect.color = Color.GRAY
	return effect

static func create_curse(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("curse", "Cursed")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: Reduces healing by 50%
	effect.stat_modifier["healing_received"] = -0.5
	effect.description = "Healing effects reduced by 50%"
	effect.color = Color.PURPLE
	return effect

static func create_bleed(_caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("bleed", "Bleeding")
	effect.effect_type = EffectType.DOT
	effect.duration = turns
	# Summoners War: 10% max HP per turn, ignores defense
	effect.damage_per_turn = 0.10
	effect.description = "Takes 10% max HP damage each turn (ignores defense)"
	effect.color = Color.DARK_RED
	return effect

# Additional status effects for complete Summoners War system
static func create_poison(caster, turns: int = 3) -> StatusEffect:
	var effect = StatusEffect.new("poison", "Poisoned")
	effect.effect_type = EffectType.DOT
	effect.duration = turns
	# Summoners War: 5% max HP per turn + caster attack * 0.08
	var base_damage = caster.max_health * 0.05
	var scaled_damage = _get_attack(caster) * 0.08
	effect.damage_per_turn = (base_damage + scaled_damage) / caster.max_health  # Convert back to percentage
	effect.description = "Takes poison damage each turn (5% HP + 8% caster attack)"
	effect.color = Color.GREEN
	return effect

static func create_freeze(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("freeze", "Frozen")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.prevents_action = true
	effect.frozen = true
	effect.description = "Completely frozen, cannot act"
	effect.color = Color.LIGHT_BLUE
	return effect

static func create_sleep(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("sleep", "Sleeping")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.prevents_action = true
	effect.sleeping = true
	effect.description = "Asleep, cannot act (breaks on damage)"
	effect.color = Color.LIGHT_GRAY
	return effect

static func create_silence(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("silence", "Silenced")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.silenced = true
	effect.description = "Cannot use abilities"
	effect.color = Color.PURPLE
	return effect

static func create_heal_block(_caster, turns: int = 2) -> StatusEffect:
	var effect = StatusEffect.new("heal_block", "Heal Block")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	# Summoners War: Completely blocks all healing
	effect.stat_modifier["healing_received"] = -1.0  # -100% healing
	effect.description = "Cannot recover HP"
	effect.color = Color.DARK_RED
	return effect

static func create_provoke(_caster, turns: int = 1) -> StatusEffect:
	var effect = StatusEffect.new("provoke", "Provoked")
	effect.effect_type = EffectType.DEBUFF
	effect.duration = turns
	effect.provoked = true
	effect.description = "Must attack the provoker"
	effect.color = Color.RED
	return effect
