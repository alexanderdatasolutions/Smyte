# scripts/systems/battle/WaveManager.gd
# Manages waves in PvE battles (dungeons, etc.)
extends Node
class_name WaveManager

var wave_data: Array = []  # Array[Array] - Array of wave enemy arrays
var current_wave: int = 0
var max_waves: int = 0

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

## Setup waves for the battle
func setup_waves(waves: Array):  # Array[Array]
	wave_data = waves.duplicate()
	max_waves = wave_data.size()
	current_wave = 0
	print("WaveManager: Setup ", max_waves, " waves")

## Start a specific wave
func start_wave(wave_number: int) -> bool:
	if wave_number <= 0 or wave_number > max_waves:
		push_error("WaveManager: Invalid wave number: " + str(wave_number))
		return false
	
	current_wave = wave_number
	wave_started.emit(wave_number)
	print("WaveManager: Started wave ", wave_number, "/", max_waves)
	return true

## Complete current wave and advance to next
func complete_current_wave():
	if current_wave <= 0:
		return
	
	wave_completed.emit(current_wave)
	print("WaveManager: Completed wave ", current_wave)
	
	# Check if there are more waves
	if current_wave >= max_waves:
		all_waves_completed.emit()
		print("WaveManager: All waves completed!")
	else:
		# Start next wave
		start_wave(current_wave + 1)

## Get current wave number
func get_current_wave() -> int:
	return current_wave

## Get total wave count
func get_wave_count() -> int:
	return max_waves

## Check if this is the last wave
func is_final_wave() -> bool:
	return current_wave >= max_waves

## Get current wave enemy data
func get_current_wave_enemies() -> Array:
	if current_wave <= 0 or current_wave > wave_data.size():
		return []
	return wave_data[current_wave - 1]

## Get next wave enemy data
func get_next_wave_enemies() -> Array:
	if current_wave >= wave_data.size():
		return []
	return wave_data[current_wave]

## Reset wave manager
func reset():
	wave_data.clear()
	current_wave = 0
	max_waves = 0
	print("WaveManager: Reset complete")
