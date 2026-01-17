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

## Get predicted turn order for the next N turns (for UI display)
func get_turn_order_preview(num_turns: int = 8) -> Array:
	"""Simulate turn progression to predict upcoming turn order"""
	var preview: Array = []  # Array[BattleUnit]

	# Get living units
	var living_units = battle_units.filter(func(unit): return unit.is_alive)
	if living_units.is_empty():
		return preview

	# Create a copy of turn bar values to simulate without modifying actual state
	var simulated_bars: Dictionary = {}
	for unit in living_units:
		simulated_bars[unit] = unit.current_turn_bar

	# Add units already in queue first
	for unit in turn_queue:
		if unit.is_alive:
			preview.append(unit)
			if preview.size() >= num_turns:
				return preview

	# Simulate future turns
	var safety_counter = 0
	var max_iterations = 1000

	while preview.size() < num_turns and safety_counter < max_iterations:
		# Advance all simulated turn bars
		var ready_units: Array = []

		for unit in living_units:
			simulated_bars[unit] += unit.speed * 0.07
			if simulated_bars[unit] >= 100.0:
				ready_units.append(unit)

		# Sort ready units by speed (faster goes first) then by turn bar (higher goes first)
		ready_units.sort_custom(func(a, b):
			if simulated_bars[a] != simulated_bars[b]:
				return simulated_bars[a] > simulated_bars[b]
			return a.speed > b.speed
		)

		# Add ready units to preview
		for unit in ready_units:
			if not preview.has(unit) or _count_in_array(preview, unit) < _count_future_turns(simulated_bars[unit]):
				preview.append(unit)
				simulated_bars[unit] = 0.0  # Reset after taking turn
				if preview.size() >= num_turns:
					return preview

		safety_counter += 1

	return preview

func _count_in_array(arr: Array, item) -> int:
	"""Count occurrences of item in array"""
	var count = 0
	for element in arr:
		if element == item:
			count += 1
	return count

func _count_future_turns(turn_bar_value: float) -> int:
	"""Helper to allow same unit appearing multiple times if very fast"""
	return int(turn_bar_value / 100.0) + 1

## End the battle
func end_battle():
	battle_units.clear()
	turn_queue.clear()
	current_unit_index = 0

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

func _end_current_turn():
	"""End the current unit's turn"""
	var current_unit = get_current_unit()
	if current_unit:
		turn_ended.emit(current_unit)
