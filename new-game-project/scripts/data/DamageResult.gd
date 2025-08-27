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
