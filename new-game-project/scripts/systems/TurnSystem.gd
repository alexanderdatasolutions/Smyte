# TurnSystem.gd - Handle turn order and advancement
class_name TurnSystem
extends RefCounted

signal turn_started(unit)
signal turn_ended(unit)

# Turn tracking
var turn_order: Array = []
var current_turn_index: int = 0
var current_acting_unit = null

func setup_turn_order(gods: Array, enemies: Array):
	"""Create turn order based on speed - matches your existing system"""
	var all_units = []
	
	# Add gods
	for god in gods:
		if god and _get_current_hp(god) > 0:
			all_units.append({
				"unit": god, 
				"speed": god.get_current_speed(), 
				"is_god": true
			})
	
	# Add enemies
	for enemy in enemies:
		if enemy and _get_current_hp(enemy) > 0:
			all_units.append({
				"unit": enemy, 
				"speed": enemy.get("speed", 70), 
				"is_god": false
			})
	
	# Sort by speed (highest first)
	all_units.sort_custom(func(a, b): return a.speed > b.speed)
	
	turn_order = all_units
	current_turn_index = 0
	
	print("Turn order created:")
	for i in range(turn_order.size()):
		var entry = turn_order[i]
		var unit_name = _get_unit_name(entry.unit)
		print("  %d. %s (Speed: %d)" % [i+1, unit_name, entry.speed])

func get_current_unit():
	"""Get the currently acting unit"""
	if current_turn_index >= turn_order.size():
		_start_new_turn_cycle()
	
	if current_turn_index < turn_order.size():
		var turn_entry = turn_order[current_turn_index]
		current_acting_unit = turn_entry.unit
		return current_acting_unit
	
	return null

func advance_turn():
	"""Advance to next unit in turn order"""
	if current_acting_unit:
		turn_ended.emit(current_acting_unit)
	
	current_turn_index += 1
	current_acting_unit = null
	
	# If we've gone through all units, start new cycle
	if current_turn_index >= turn_order.size():
		_start_new_turn_cycle()

func can_unit_act(unit) -> bool:
	"""Check if unit can act (not stunned, frozen, etc.)"""
	if unit is God:
		return unit.can_act()
	else:
		# Check enemy status effects for disable conditions
		var status_effects = unit.get("status_effects", [])
		for effect in status_effects:
			# StatusEffect is now a Resource object, access properties directly
			if effect is StatusEffect and effect.prevents_action:
				return false
		return true

func remove_dead_units():
	"""Remove dead units from turn order"""
	var alive_units = []
	
	for turn_entry in turn_order:
		var unit = turn_entry.unit
		if _get_current_hp(unit) > 0:
			alive_units.append(turn_entry)
	
	# Adjust current index if units were removed before current position
	var old_size = turn_order.size()
	turn_order = alive_units
	var new_size = turn_order.size()
	
	if new_size < old_size and current_turn_index > 0:
		current_turn_index = min(current_turn_index, new_size - 1)

func get_units_alive_count(gods: Array, enemies: Array) -> Dictionary:
	"""Get count of alive gods and enemies"""
	var god_count = 0
	var enemy_count = 0
	
	for god in gods:
		if god and _get_current_hp(god) > 0:
			god_count += 1
	
	for enemy in enemies:
		if enemy and _get_current_hp(enemy) > 0:
			enemy_count += 1
	
	return {"gods": god_count, "enemies": enemy_count}

func _start_new_turn_cycle():
	"""Start a new turn cycle - rebuild turn order"""
	print("=== NEW TURN CYCLE ===")
	current_turn_index = 0
	
	# Remove dead units and refresh speeds
	var alive_units = []
	for turn_entry in turn_order:
		var unit = turn_entry.unit
		if _get_current_hp(unit) > 0:
			# Update speed in case it changed
			var updated_speed
			if unit is God:
				updated_speed = unit.get_current_speed()
			else:
				updated_speed = unit.get("speed", 70)
			
			alive_units.append({
				"unit": unit,
				"speed": updated_speed,
				"is_god": turn_entry.is_god
			})
	
	# Re-sort by current speeds
	alive_units.sort_custom(func(a, b): return a.speed > b.speed)
	turn_order = alive_units

# Helper methods

func _get_current_hp(unit) -> int:
	"""Get current HP from either God or dictionary"""
	if unit is God:
		return unit.current_hp
	else:
		return unit.get("current_hp", 0)

func _get_unit_name(unit) -> String:
	"""Get name from either God or dictionary"""
	if unit is God:
		return unit.name
	else:
		return unit.get("name", "Unknown")

func _get_current_speed(unit) -> int:
	"""Get current speed from either God or dictionary"""
	if unit is God:
		return unit.current_speed
	else:
		return unit.get("current_speed", 0)
