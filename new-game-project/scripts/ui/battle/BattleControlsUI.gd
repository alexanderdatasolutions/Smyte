# BattleControlsUI.gd - Manages battle controls (speed, auto, back)
# Single responsibility: Handle battle control inputs
class_name BattleControlsUI extends Node

signal back_pressed
signal auto_battle_toggled(enabled: bool)
signal speed_changed(multiplier: float)

# Control references
var back_button: Button = null
var auto_button: Button = null
var speed_buttons: Array[Button] = []

var auto_battle_enabled: bool = false
var speed_multiplier: float = 1.0

func initialize_controls(container: Control):
	"""Initialize control button references"""
	if not container:
		return
		
	# Find control buttons
	back_button = container.get_node_or_null("BackButton")
	auto_button = container.get_node_or_null("AutoButton")
	
	# Connect signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if auto_button:
		auto_button.pressed.connect(_on_auto_pressed)
	
	# Find speed buttons
	var speed_container = container.get_node_or_null("SpeedControlContainer")
	if speed_container:
		_setup_speed_buttons(speed_container)

func _setup_speed_buttons(container: Control):
	"""Setup speed control buttons"""
	var speed_1x = container.get_node_or_null("Speed1xButton")
	var speed_2x = container.get_node_or_null("Speed2xButton")
	var speed_3x = container.get_node_or_null("Speed3xButton")
	
	if speed_1x:
		speed_buttons.append(speed_1x)
		speed_1x.pressed.connect(_on_speed_pressed.bind(1.0))
	if speed_2x:
		speed_buttons.append(speed_2x)
		speed_2x.pressed.connect(_on_speed_pressed.bind(2.0))
	if speed_3x:
		speed_buttons.append(speed_3x)
		speed_3x.pressed.connect(_on_speed_pressed.bind(3.0))

func enable_battle_controls():
	"""Enable all battle controls"""
	_set_controls_enabled(true)
	_update_auto_button_text()

func disable_battle_controls():
	"""Disable all battle controls"""
	_set_controls_enabled(false)
	auto_battle_enabled = false
	_update_auto_button_text()

func _set_controls_enabled(enabled: bool):
	"""Set enabled state for all controls"""
	if auto_button:
		auto_button.disabled = not enabled
	
	for button in speed_buttons:
		button.disabled = not enabled

func _update_auto_button_text():
	"""Update auto battle button text"""
	if auto_button:
		auto_button.text = "Auto: ON" if auto_battle_enabled else "Auto: OFF"

func _on_back_pressed():
	"""Handle back button pressed"""
	back_pressed.emit()

func _on_auto_pressed():
	"""Handle auto battle button pressed"""
	auto_battle_enabled = not auto_battle_enabled
	_update_auto_button_text()
	auto_battle_toggled.emit(auto_battle_enabled)

func _on_speed_pressed(multiplier: float):
	"""Handle speed button pressed"""
	speed_multiplier = multiplier
	_update_speed_button_states()
	speed_changed.emit(multiplier)

func _update_speed_button_states():
	"""Update speed button visual states"""
	# This would update button styles to show which speed is active
	for i in range(speed_buttons.size()):
		var button = speed_buttons[i]
		var expected_speed = [1.0, 2.0, 3.0][i]
		# Update button appearance based on current speed
		if button:
			button.modulate = Color.YELLOW if expected_speed == speed_multiplier else Color.WHITE
