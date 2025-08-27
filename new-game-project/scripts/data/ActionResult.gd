# scripts/data/ActionResult.gd
# Contains the result of a battle action execution
class_name ActionResult extends RefCounted

var success: bool = false
var damage_results: Array = []  # Array[DamageResult]
var status_effects_applied: Array = []  # Array[StatusEffect]
var message: String = ""

## Get a log message describing the action result
func get_log_message() -> String:
	return message if not message.is_empty() else "Action completed"

## Add a damage result
func add_damage_result(result: DamageResult):
	damage_results.append(result)

## Add a status effect that was applied
func add_status_effect(effect: StatusEffect):
	status_effects_applied.append(effect)
