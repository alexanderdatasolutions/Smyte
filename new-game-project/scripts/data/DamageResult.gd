# scripts/data/DamageResult.gd
# Contains the result of a damage calculation
class_name DamageResult extends RefCounted

var total: int = 0
var base_damage: int = 0
var is_critical: bool = false
var is_glancing: bool = false
var is_blocked: bool = false
var damage_type: String = "physical"
var element_multiplier: float = 1.0

# Detailed calculation breakdown for tooltips
var attacker_attack: int = 0
var target_defense: int = 0
var skill_multiplier: float = 1.0
var crit_multiplier: float = 1.0
var glancing_multiplier: float = 1.0
var variance_multiplier: float = 1.0
var raw_damage: float = 0.0  # Before variance
var attacker_name: String = ""
var target_name: String = ""
var skill_name: String = ""

func _init(damage: int = 0, critical: bool = false, glancing: bool = false):
	total = damage
	base_damage = damage
	is_critical = critical
	is_glancing = glancing

## Get damage description for UI
func get_description() -> String:
	var desc = str(total) + " damage"
	if is_critical:
		desc += " (CRIT!)"
	elif is_glancing:
		desc += " (glancing)"
	return desc

## Get detailed calculation breakdown for tooltip
func get_calculation_breakdown() -> String:
	var lines: Array = []

	# Header
	if skill_name and not skill_name.is_empty():
		lines.append("%s → %s (%s)" % [attacker_name, target_name, skill_name])
	else:
		lines.append("%s → %s (Basic Attack)" % [attacker_name, target_name])

	lines.append("")

	# Formula explanation
	lines.append("ATK × Mult × (1000 / (1140 + 3.5×DEF))")
	lines.append("")

	# Values
	lines.append("ATK: %d" % attacker_attack)
	lines.append("DEF: %d" % target_defense)
	lines.append("Skill Mult: %.0f%%" % (skill_multiplier * 100))

	# Damage reduction from defense
	var def_reduction = 1000.0 / (1140.0 + 3.5 * target_defense)
	lines.append("DEF Reduction: %.1f%%" % (def_reduction * 100))

	# Base damage before modifiers
	lines.append("")
	lines.append("Base Damage: %d" % int(raw_damage / crit_multiplier / glancing_multiplier))

	# Modifiers
	if is_critical:
		lines.append("Crit Mult: +%.0f%%" % ((crit_multiplier - 1.0) * 100))
	if is_glancing:
		lines.append("Glancing: -30%")
	if element_multiplier > 1.0:
		lines.append("Element Advantage: +%.0f%%" % ((element_multiplier - 1.0) * 100))
	elif element_multiplier < 1.0:
		lines.append("Element Disadvantage: -%.0f%%" % ((1.0 - element_multiplier) * 100))

	lines.append("Variance: %.0f%%" % (variance_multiplier * 100))

	lines.append("")
	lines.append("Final: %d" % total)

	return "\n".join(lines)
