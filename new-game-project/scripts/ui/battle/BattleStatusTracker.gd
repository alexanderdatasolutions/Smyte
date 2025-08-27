# BattleStatusTracker.gd - Tracks HP and status updates
# Single responsibility: Monitor and display unit status changes
class_name BattleStatusTracker extends Node

signal status_changed(unit_id: String)

var tracked_units: Dictionary = {}  # unit_id -> status_data

func initialize_tracking(player_team: Array, enemy_team: Array):
	"""Initialize tracking for all battle units"""
	tracked_units.clear()
	
	# Track player gods
	for god in player_team:
		if god is God:
			_add_unit_tracking(god.id, god)
	
	# Track enemies
	for i in range(enemy_team.size()):
		var enemy = enemy_team[i]
		var enemy_id = "enemy_" + str(i)
		_add_unit_tracking(enemy_id, enemy)

func _add_unit_tracking(unit_id: String, unit):
	"""Add a unit to tracking"""
	tracked_units[unit_id] = {
		"unit": unit,
		"last_hp": _get_unit_hp(unit),
		"max_hp": _get_unit_max_hp(unit),
		"status_effects": []
	}

func update_unit_hp(unit):
	"""Update HP for a tracked unit"""
	var unit_id = _get_unit_id(unit)
	if not tracked_units.has(unit_id):
		return
		
	var current_hp = _get_unit_hp(unit)
	var tracked_data = tracked_units[unit_id]
	
	if tracked_data.last_hp != current_hp:
		tracked_data.last_hp = current_hp
		status_changed.emit(unit_id)
		
		# Log HP change
		var unit_name = unit.name if unit is God else unit.get("name", "Unknown")
		print("HP Update: %s - %d/%d" % [unit_name, current_hp, tracked_data.max_hp])

func _get_unit_hp(unit) -> int:
	"""Get current HP of a unit"""
	if unit is God:
		return unit.current_hp
	else:
		return unit.get("current_hp", unit.get("hp", 0))

func _get_unit_max_hp(unit) -> int:
	"""Get max HP of a unit"""
	if unit is God:
		return unit.get_max_hp()
	else:
		return unit.get("max_hp", unit.get("hp", 100))

func _get_unit_id(unit) -> String:
	"""Get ID for a unit"""
	if unit is God:
		return unit.id
	else:
		# Find enemy by reference
		for unit_id in tracked_units:
			if tracked_units[unit_id].unit == unit:
				return unit_id
		return "unknown"

func get_unit_status(unit_id: String) -> Dictionary:
	"""Get current status of a tracked unit"""
	return tracked_units.get(unit_id, {})
