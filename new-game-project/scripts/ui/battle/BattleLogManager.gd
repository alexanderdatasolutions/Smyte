# BattleLogManager.gd - Manages battle log display
# Single responsibility: Display battle messages and events
class_name BattleLogManager extends Node

signal log_updated

var log_entries: Array[String] = []
var max_log_entries: int = 50
var log_display: RichTextLabel = null

func initialize_log_display(display: RichTextLabel):
	"""Set the log display reference"""
	log_display = display
	clear_log()

func clear_log():
	"""Clear all log entries"""
	log_entries.clear()
	_update_display()

func add_message(message: String):
	"""Add a message to the battle log"""
	log_entries.append(message)
	
	# Limit log size
	while log_entries.size() > max_log_entries:
		log_entries.pop_front()
	
	_update_display()
	log_updated.emit()

func add_damage_log(attacker, target, damage_info):
	"""Add a damage log entry"""
	var attacker_name = attacker.name if attacker is God else attacker.get("name", "Unknown")
	var target_name = target.name if target is God else target.get("name", "Unknown")
	var damage = damage_info.get("total", damage_info) if damage_info is Dictionary else damage_info
	
	var message = "%s attacks %s for %s damage!" % [attacker_name, target_name, damage]
	add_message(message)

func add_skill_log(caster, skill_name: String, targets: Array):
	"""Add a skill usage log entry"""
	var caster_name = caster.name if caster is God else caster.get("name", "Unknown")
	var target_names = []
	
	for target in targets:
		var target_name = target.name if target is God else target.get("name", "Unknown")
		target_names.append(target_name)
	
	var message = "%s uses %s on %s!" % [caster_name, skill_name, ", ".join(target_names)]
	add_message(message)

func add_status_log(target, effect_name: String, applied: bool):
	"""Add a status effect log entry"""
	var target_name = target.name if target is God else target.get("name", "Unknown")
	var action = "gains" if applied else "loses"
	var message = "%s %s %s!" % [target_name, action, effect_name]
	add_message(message)

func _update_display():
	"""Update the visual log display"""
	if not log_display:
		return
	
	var log_text = "\n".join(log_entries)
	log_display.text = log_text
	
	# Scroll to bottom
	log_display.scroll_to_line(log_entries.size())
