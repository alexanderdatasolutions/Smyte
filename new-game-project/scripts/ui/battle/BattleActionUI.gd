# BattleActionUI.gd - Handles action buttons and targeting
# Single responsibility: Manage player action inputs
class_name BattleActionUI extends Node

signal action_selected(unit, action)

# Action buttons (will be connected to actual UI nodes)
var attack_button: Button = null
var skill_buttons: Array[Button] = []
var action_container: Control = null

var current_unit = null
var targeting_mode: bool = false
var current_action = null

func initialize_buttons(container: Control):
	"""Initialize action button references"""
	action_container = container
	# Find buttons in container
	_find_action_buttons()

func _find_action_buttons():
	"""Find action buttons in the UI"""
	if not action_container:
		return
		
	# Look for attack button
	attack_button = action_container.get_node_or_null("AttackButton")
	if attack_button:
		attack_button.pressed.connect(_on_attack_pressed)
	
	# Look for skill buttons
	for i in range(3):
		var skill_button = action_container.get_node_or_null("Skill" + str(i + 1) + "Button")
		if skill_button:
			skill_buttons.append(skill_button)
			skill_button.pressed.connect(_on_skill_pressed.bind(i))

func show_action_options(unit):
	"""Show available actions for a unit"""
	current_unit = unit
	targeting_mode = false
	
	if not action_container:
		return
		
	action_container.visible = true
	_update_action_buttons()

func hide_action_options():
	"""Hide action options"""
	current_unit = null
	targeting_mode = false
	
	if action_container:
		action_container.visible = false

func _update_action_buttons():
	"""Update button states based on current unit"""
	if not current_unit:
		return
	
	# Update attack button
	if attack_button:
		attack_button.disabled = false
		attack_button.text = "Attack"
	
	# Update skill buttons
	for i in range(skill_buttons.size()):
		var button = skill_buttons[i]
		if button and current_unit is God:
			var skill_available = _is_skill_available(current_unit, i)
			button.disabled = not skill_available
			button.text = "Skill " + str(i + 1)

func _is_skill_available(god: God, skill_index: int) -> bool:
	"""Check if a skill is available for use"""
	if skill_index >= god.skill_cooldowns.size():
		return false
		
	return god.skill_cooldowns[skill_index] <= 0

func _on_attack_pressed():
	"""Handle attack button pressed"""
	if not current_unit:
		return
		
	var action = {
		"type": "attack",
		"caster": current_unit,
		"targets": []
	}
	
	# For now, auto-select first enemy as target
	action_selected.emit(current_unit, action)

func _on_skill_pressed(skill_index: int):
	"""Handle skill button pressed"""
	if not current_unit or not current_unit is God:
		return
		
	var action = {
		"type": "skill",
		"skill_index": skill_index,
		"caster": current_unit,
		"targets": []
	}
	
	# For now, auto-select targets
	action_selected.emit(current_unit, action)
