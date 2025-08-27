# scripts/systems/battle/TurnManager.gd
# Manages turn order and turn progression in battle
extends Node
class_name TurnManager

var battle_units: Array = []  # Array[BattleUnit]
var turn_queue: Array = []  # Array[BattleUnit]
var current_unit_index: int = 0

signal turn_started(unit: BattleUnit)
signal turn_ended(unit: BattleUnit)

## Setup turn order based on units' speed
func setup_turn_order(units: Array):  # Array[BattleUnit]
	battle_units = units.duplicate()
	_calculate_initial_turn_order()
	print("TurnManager: Turn order established with ", battle_units.size(), " units")

## Start the battle turn cycle
func start_battle():
	if battle_units.is_empty():
		push_error("TurnManager: No units available for battle")
		return
	
	_begin_next_turn()

## Advance to the next unit's turn
func advance_turn():
	_end_current_turn()
	_begin_next_turn()

## Get the unit whose turn it currently is
func get_current_unit() -> BattleUnit:
	if turn_queue.is_empty():
		return null
	return turn_queue[0]

## End the battle
func end_battle():
	battle_units.clear()
	turn_queue.clear()
	current_unit_index = 0
	print("TurnManager: Battle ended")

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _calculate_initial_turn_order():
	"""Calculate the initial turn order based on Summoners War-style turn bar system"""
	turn_queue.clear()
	
	# Sort units by speed (fastest first)
	var sorted_units = battle_units.duplicate()
	sorted_units.sort_custom(func(a, b): return a.speed > b.speed)
	
	# Initialize turn bars based on speed
	for unit in sorted_units:
		unit.current_turn_bar = 0.0
	
	# Fill initial turn queue
	_fill_turn_queue()

func _fill_turn_queue():
	"""Fill the turn queue by advancing turn bars until someone is ready"""
	var safety_counter = 0
	var max_iterations = 1000  # Prevent infinite loops
	
	while turn_queue.is_empty() and safety_counter < max_iterations:
		# Advance all living units' turn bars
		var living_units = battle_units.filter(func(unit): return unit.is_alive)
		
		for unit in living_units:
			unit.advance_turn_bar()
			
			# Check if unit is ready for turn
			if unit.is_ready_for_turn():
				turn_queue.append(unit)
		
		safety_counter += 1
	
	if safety_counter >= max_iterations:
		push_error("TurnManager: Turn calculation exceeded maximum iterations")
		# Fallback: give turn to first living unit
		var living_units = battle_units.filter(func(unit): return unit.is_alive)
		if not living_units.is_empty():
			living_units[0].current_turn_bar = 100.0
			turn_queue.append(living_units[0])
	
	# Sort turn queue by speed if multiple units are ready
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)

func _begin_next_turn():
	"""Begin the next unit's turn"""
	# Clean up turn queue (remove dead units)
	turn_queue = turn_queue.filter(func(unit): return unit.is_alive)
	
	# Fill turn queue if empty
	if turn_queue.is_empty():
		_fill_turn_queue()
	
	# Check if battle should end
	if turn_queue.is_empty():
		print("TurnManager: No more units can take turns")
		return
	
	# Get next unit
	var current_unit = turn_queue.pop_front()
	if not current_unit or not current_unit.is_alive:
		# Try again with next unit
		_begin_next_turn()
		return
	
	# Reset unit's turn bar
	current_unit.reset_turn_bar()
	
	# Process status effects at start of turn
	current_unit.process_status_effects()
	
	# Emit turn started signal
	turn_started.emit(current_unit)
	print("TurnManager: Turn started for ", current_unit.display_name)

func _end_current_turn():
	"""End the current unit's turn"""
	var current_unit = get_current_unit()
	if current_unit:
		turn_ended.emit(current_unit)
		print("TurnManager: Turn ended for ", current_unit.display_name)
