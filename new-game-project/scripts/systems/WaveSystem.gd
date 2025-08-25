# scripts/systems/WaveSystem.gd
extends Node
class_name WaveSystem

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int, total_waves: int)
signal all_waves_completed()  # No rewards data - BattleManager handles loot
signal wave_failed(wave_number: int, total_waves: int)

# Wave configuration
var current_wave: int = 0
var total_waves: int = 1
var wave_config: Dictionary = {}
var battle_context: Dictionary = {}

# Enemy management
var current_wave_enemies: Array = []
var all_enemies_defeated: bool = false

# References
var battle_manager: BattleManager = null

# Modular battle setup methods
enum BattleType {
	DUNGEON,
	TERRITORY,
	RAID,
	GUILD_BATTLE,
	ARENA,
	SPECIAL_EVENT
}

var current_battle_type: BattleType = BattleType.DUNGEON

func _ready():
	# Get references to other systems
	if GameManager and GameManager.get_battle_system():
		battle_manager = GameManager.get_battle_system()
		print("WaveSystem connected to BattleManager")
	
	# Connect to battle system signals
	if battle_manager:
		battle_manager.battle_completed.connect(_on_battle_completed)

# UNIFIED WAVE SETUP - Works for all battle types
func setup_wave_battle(battle_type: BattleType, config: Dictionary) -> bool:
	"""
	Unified wave setup for all battle types
	Config should contain:
	- battle_id: String (dungeon_id, territory_id, etc.)
	- difficulty: String 
	- stage: int (for territory battles)
	- Any other battle-specific data
	"""
	print("=== WaveSystem: Setting up %s wave battle ===" % _get_battle_type_name(battle_type))
	
	# Reset state
	current_wave = 0
	current_wave_enemies.clear()
	
	# Determine wave count based on battle type
	total_waves = _determine_wave_count(battle_type, config)
	
	# Store battle context
	battle_context = {
		"type": _get_battle_type_name(battle_type).to_lower(),
		"battle_type_enum": battle_type,
		"config": config.duplicate()
	}
	
	print("=== WaveSystem setup complete: %d waves for %s ===" % [total_waves, config.get("battle_id", "unknown")])
	return true

func _get_battle_type_name(battle_type: BattleType) -> String:
	"""Convert battle type enum to string"""
	match battle_type:
		BattleType.DUNGEON: return "DUNGEON"
		BattleType.TERRITORY: return "TERRITORY"
		BattleType.RAID: return "RAID"
		BattleType.GUILD_BATTLE: return "GUILD_BATTLE"
		BattleType.ARENA: return "ARENA"
		_: return "UNKNOWN"

func _determine_wave_count(battle_type: BattleType, config: Dictionary) -> int:
	"""Determine wave count based on battle type and difficulty"""
	match battle_type:
		BattleType.DUNGEON:
			return _get_dungeon_wave_count(config)
		BattleType.TERRITORY:
			return _get_territory_wave_count(config)
		BattleType.RAID:
			return _get_raid_wave_count(config)
		BattleType.GUILD_BATTLE:
			return _get_guild_battle_wave_count(config)
		BattleType.ARENA:
			return 1  # Arena battles are typically single wave
		_:
			return 3  # Default fallback

func _get_dungeon_wave_count(config: Dictionary) -> int:
	"""Get wave count for dungeon battles"""
	var difficulty = config.get("difficulty", "beginner")
	var dungeon_id = config.get("battle_id", "")
	
	# Get dungeon info from dungeon system
	var dungeon_system = GameManager.get_dungeon_system()
	if dungeon_system:
		var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
		var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		return int(difficulty_info.get("waves", 3))
	
	return 3  # Default for dungeons

func _get_territory_wave_count(config: Dictionary) -> int:
	"""Get wave count for territory battles"""
	var stage = config.get("stage", 1)
	
	# Territory wave progression
	if stage <= 3:
		return 1  # Early stages = 1 wave
	elif stage <= 7:
		return 2  # Mid stages = 2 waves
	else:
		return 3  # Boss stages = 3 waves

func _get_raid_wave_count(config: Dictionary) -> int:
	"""Get wave count for raid battles"""
	var difficulty = config.get("difficulty", "normal")
	
	match difficulty:
		"easy":
			return 3
		"normal":
			return 4
		"hard":
			return 5
		"nightmare":
			return 6
		_:
			return 5  # Default

func _get_guild_battle_wave_count(config: Dictionary) -> int:
	"""Get wave count for guild battles"""
	var battle_tier = config.get("tier", 1)
	
	# Higher tier guild battles have more waves
	return min(3 + battle_tier, 7)  # 3-7 waves based on tier

func setup_waves_for_dungeon(dungeon_id: String, difficulty: String) -> bool:
	"""Setup wave system for dungeon battles - SIMPLIFIED: Use dungeons.json as single source of truth"""
	print("=== WaveSystem: Setting up waves for dungeon %s (%s) ===" % [dungeon_id, difficulty])
	
	var dungeon_system = GameManager.get_dungeon_system()
	if not dungeon_system:
		print("ERROR: No dungeon system found")
		return false
	
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	
	# Use dungeons.json as the ONLY source of truth
	var configured_waves = difficulty_info.get("waves", 3)
	print("=== Using dungeons.json wave count: %d waves for %s %s ===" % [configured_waves, dungeon_id, difficulty])
	
	total_waves = configured_waves
	current_wave = 1  # Start at 1 for proper display
	
	# Clear any old wave config data - we don't use overrides anymore
	wave_config = {}
	
	battle_context = {
		"type": "dungeon",
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"dungeon_info": dungeon_info,
		"difficulty_info": difficulty_info
	}
	
	print("=== WaveSystem setup complete: %d waves for %s ====" % [total_waves, dungeon_id])
	print("=== Battle context type: %s ===" % battle_context.get("type"))
	return true

func setup_waves_for_territory(territory: Territory, stage: int) -> bool:
	"""Setup wave system for territory battles"""
	print("=== WaveSystem: Setting up waves for territory %s stage %d ===" % [territory.name, stage])
	
	# Territory battles typically have 1-3 waves based on stage (like Summoners War)
	if stage <= 3:
		total_waves = 1  # Early stages = 1 wave
	elif stage <= 7:
		total_waves = 2  # Mid stages = 2 waves
	else:
		total_waves = 3  # Boss stages = 3 waves
	
	current_wave = 1  # Start at 1 for proper display
	
	battle_context = {
		"type": "territory",
		"territory": territory,
		"territory_name": territory.name,
		"stage": stage
	}
	
	print("Setup complete: %d waves for %s stage %d" % [total_waves, territory.name, stage])
	return true

func setup_waves_for_raid(raid_id: String, difficulty: String) -> bool:
	"""Setup wave system for raid battles"""
	total_waves = 5  # Raids typically have more waves
	current_wave = 1  # Start at 1 for proper display
	
	battle_context = {
		"type": "raid", 
		"raid_id": raid_id,
		"difficulty": difficulty
	}
	
	print("Setup complete: %d waves for raid %s" % [total_waves, raid_id])
	return true

func start_wave_battle_sequence() -> bool:
	"""Start the wave battle sequence (call this to begin wave 1)"""
	if total_waves <= 0:
		print("ERROR: No waves configured")
		return false
	
	if not battle_manager:
		print("ERROR: No battle manager available")
		return false
	
	# Reset wave system - start at 1 for proper display
	current_wave = 1
	
	# Start first wave
	return start_current_wave()

func start_next_wave() -> bool:
	"""Start the next wave in the sequence"""
	if current_wave >= total_waves:
		print("All waves completed!")
		_complete_all_waves()
		return false
	
	current_wave += 1
	print("=== Starting Wave %d/%d ===" % [current_wave, total_waves])
	
	return start_current_wave()

func start_current_wave() -> bool:
	"""Start the current wave"""
	# Create enemies for this wave
	current_wave_enemies = _create_wave_enemies(current_wave)
	
	if current_wave_enemies.is_empty():
		print("ERROR: No enemies created for wave %d" % current_wave)
		return false
	
	# Emit wave started signal
	wave_started.emit(current_wave, total_waves)
	
	# Start battle with wave enemies
	if battle_manager:
		var battle_started = _start_wave_battle()
		if not battle_started:
			print("ERROR: Failed to start wave %d battle" % current_wave)
			return false
	else:
		print("ERROR: No battle manager available for wave %d" % current_wave)
		return false
	
	return true

func _create_wave_enemies(wave_number: int) -> Array:
	"""Create enemies for a specific wave based on battle context"""
	var enemies = []
	
	match battle_context.get("type", ""):
		"dungeon":
			enemies = _create_dungeon_wave_enemies(wave_number)
		"territory":
			enemies = _create_territory_wave_enemies(wave_number)
		"raid":
			enemies = _create_raid_wave_enemies(wave_number)
		_:
			print("Unknown battle type: %s" % battle_context.get("type", ""))
	
	print("Created %d enemies for wave %d" % [enemies.size(), wave_number])
	return enemies

func _create_dungeon_wave_enemies(wave_number: int) -> Array:
	"""Create enemies for dungeon wave"""
	var dungeon_id = battle_context.get("dungeon_id", "")
	var difficulty = battle_context.get("difficulty", "")
	
	# Use EnemyFactory to create enemies
	if EnemyFactory:
		return EnemyFactory.create_enemies_for_dungeon_wave(dungeon_id, difficulty, wave_number)
	
	return []

func _create_territory_wave_enemies(wave_number: int) -> Array:
	"""Create enemies for territory wave"""
	var territory = battle_context.get("territory")
	var stage = battle_context.get("stage", 1)
	
	if EnemyFactory and territory:
		return EnemyFactory.create_enemies_for_territory_wave(territory, stage, wave_number)
	
	return []

func _create_raid_wave_enemies(wave_number: int) -> Array:
	"""Create enemies for raid wave"""
	var raid_id = battle_context.get("raid_id", "")
	var difficulty = battle_context.get("difficulty", "")
	
	# For raids, each wave gets progressively harder
	var enemy_count = wave_number + 2  # Wave 1 = 3 enemies, Wave 2 = 4, etc.
	
	if EnemyFactory:
		return EnemyFactory.create_enemies_for_raid_wave(raid_id, difficulty, wave_number, enemy_count)
	
	return []

func _start_wave_battle():
	"""Start battle with current wave enemies"""
	if not battle_manager:
		print("ERROR: No battle manager available")
		return false
	
	print("=== Starting battle for wave %d with %d enemies ===" % [current_wave, current_wave_enemies.size()])
	
	# Reset battle state for new wave (but keep player gods)
	battle_manager.reset_battle()
	
	# Start wave battle with new enemies
	return battle_manager.start_wave_battle(current_wave_enemies)

func _on_battle_completed(result):
	"""Handle battle completion for current wave - NO LOOT HANDLING (BattleManager does that)"""
	if result == BattleManager.BattleResult.VICTORY:
		print("Wave %d of %d completed successfully!" % [current_wave, total_waves])
		
		# Emit wave completion (no loot data - BattleManager handles that)
		wave_completed.emit(current_wave, total_waves)
		
		# Check if this was the final wave
		if current_wave >= total_waves:
			print("=== All %d waves completed! ===" % total_waves)
			# Just emit completion - BattleManager already awarded loot
			all_waves_completed.emit()
			_complete_all_waves()
		else:
			print("=== Wave %d complete, starting wave %d/%d ===" % [current_wave, current_wave + 1, total_waves])
			
			# Short delay before next wave
			await get_tree().create_timer(2.0).timeout
			
			# Start next wave
			if not start_next_wave():
				print("ERROR: Failed to start next wave")
				wave_failed.emit(current_wave + 1, total_waves)
	else:
		print("Wave %d failed!" % current_wave)
		wave_failed.emit(current_wave, total_waves)

func _complete_all_waves():
	"""Complete the entire wave sequence - NO LOOT DISTRIBUTION (BattleManager handles all loot)"""
	print("=== All %d waves completed! ===" % total_waves)
	
	# Handle final dungeon completion if this was a dungeon battle
	if battle_context.get("type") == "dungeon":
		var dungeon_id = battle_context.get("dungeon_id", "")
		var difficulty = battle_context.get("difficulty", "")
		
		if dungeon_id != "" and difficulty != "":
			var dungeon_system = GameManager.get_dungeon_system()
			if dungeon_system:
				print("=== WaveSystem: Processing final dungeon completion: %s (%s) ===" % [dungeon_id, difficulty])
				# Update dungeon progress (but don't award rewards - BattleManager handles that)
				dungeon_system.update_dungeon_progress(dungeon_id, difficulty)
				
				# Store completed dungeon for UI refresh
				if GameManager:
					GameManager.set_meta("last_dungeon_completed", dungeon_id)
					GameManager.save_game()
	
	# Reset for next battle (delayed to allow signal handling)
	await get_tree().create_timer(0.5).timeout
	reset()

func get_current_wave_info() -> Dictionary:
	"""Get current wave information for UI"""
	return {
		"current_wave": current_wave,
		"total_waves": total_waves,
		"enemies_remaining": current_wave_enemies.size()
	}

func is_final_wave() -> bool:
	"""Check if this is the final wave"""
	return current_wave >= total_waves

func reset():
	"""Reset wave system for next battle"""
	current_wave = 0
	total_waves = 1
	current_wave_enemies.clear()
	battle_context.clear()
	all_enemies_defeated = false
