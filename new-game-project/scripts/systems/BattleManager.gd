# BattleManager.gd - Core battle orchestration 
extends Node

class_name BattleManager


# Helper function to safely get stats from both God objects and dictionary enemies
static func _get_stat(unit, stat_name: String, default_value: Variant = 0):
	"""Safely get a stat from either God object or dictionary - UNIFIED APPROACH"""
	if unit is God:
		match stat_name:
			"name": return unit.name
			"hp", "current_hp": return unit.current_hp
			"max_hp": return unit.get_max_hp()
			_: return default_value
	elif stat_name == "current_hp":
		# UNIFIED: Always use current_hp for enemies
		return unit.get("current_hp", unit.get("hp", default_value))
	elif unit.has(stat_name):
		return unit[stat_name]
	elif unit.has("get") and unit.has_method("get"):
		return unit.get(stat_name, default_value)
	else:
		return default_value

# Helper function to safely set HP for both God objects and dictionary enemies
static func _set_hp(unit, new_hp: int):
	"""Safely set HP for either God object or dictionary - UNIFIED APPROACH"""
	if unit is God:
		unit.current_hp = new_hp
	else:
		# UNIFIED: Always set current_hp for enemies
		unit.current_hp = new_hp

# Signals for UI communication
signal battle_completed(result)
signal battle_log_updated(message)
signal status_effect_applied(target, effect)
signal status_effect_removed(target, effect_id)

enum BattleResult { VICTORY, DEFEAT }

# Core battle state
var battle_active: bool = false
var auto_battle_enabled: bool = false
var current_battle_gods: Array = []
var current_battle_enemies: Array = []

# Getter for the wave system
var selected_gods: Array:
	get:
		return current_battle_gods

# Auto-battle timing system
var auto_battle_timer: Timer = null
var auto_battle_speed: float = 1.0  # Seconds between auto actions (1.0 = normal speed)
var pending_auto_action: Dictionary = {}
var pending_auto_unit = null

# Auto-battle timing system
var pending_god_action: Dictionary = {}
var waiting_for_auto_action: bool = false

# Battle context
var current_battle_territory: Territory = null
var current_battle_stage: int = 1
var current_battle_context: Dictionary = {}  # Store additional battle context for loot system

# Loot tracking
var last_awarded_loot: Dictionary = {}  # Store the actual loot awarded by the loot system

# Sub-systems
var turn_system: TurnSystem
var status_effect_manager: StatusEffectManager

# UI reference
var battle_screen = null

func _ready():
	"""Initialize battle manager and sub-systems"""
	turn_system = TurnSystem.new()
	status_effect_manager = StatusEffectManager.new()
	
	# Create auto-battle timer
	auto_battle_timer = Timer.new()
	auto_battle_timer.wait_time = 1.0  # 1 second default
	auto_battle_timer.one_shot = true
	auto_battle_timer.timeout.connect(_on_auto_battle_timer_timeout)
	add_child(auto_battle_timer)
	
	# Connect sub-system signals
	turn_system.turn_started.connect(_on_turn_started)
	turn_system.turn_ended.connect(_on_turn_ended)
	status_effect_manager.status_effect_applied.connect(_on_status_effect_applied)
	status_effect_manager.status_effect_removed.connect(_on_status_effect_removed)

func start_battle(config: BattleFactory) -> bool:
	"""Universal battle starter - handles any battle type with modular configuration"""
	print("=== BATTLE MANAGER: Starting %s Battle ===" % config.battle_type.capitalize())
	
	# Validate configuration
	if not config.validate():
		print("ERROR: Invalid battle configuration")
		return false
	
	# Set core battle state
	battle_active = true
	current_battle_gods = config.player_team.duplicate()
	
	# MODULAR: Use EnemyFactory to create enemies based on configuration
	current_battle_enemies = EnemyFactory.create_enemies_for_battle(config)
	
	# Set context-specific data and loot table context
	match config.battle_type:
		"territory":
			current_battle_territory = config.battle_territory
			current_battle_stage = config.battle_stage
			# Clear any previous dungeon context
			current_battle_context = {}
		"dungeon":
			current_battle_territory = null
			current_battle_stage = 1
			# Set dungeon context for loot system
			current_battle_context = {
				"loot_table_id": config.loot_table_id if "loot_table_id" in config else "",
				"context": {
					"element": config.element if "element" in config else "",
					"pantheon": config.pantheon if "pantheon" in config else "",
					"equipment_type": config.equipment_type if "equipment_type" in config else "",
					"difficulty": config.difficulty if "difficulty" in config else "",
					"tier": config.tier if "tier" in config else ""
				}
			}
		_:
			current_battle_territory = null
			current_battle_stage = 1
			current_battle_context = {}
	
	# Reset all gods to full HP at start of battle
	_reset_gods_hp()
	
	# Reset auto-battle state for new battle
	auto_battle_enabled = false
	
	# Emit battle log
	battle_log_updated.emit(config.get_battle_description())
	
	# Setup turn order
	turn_system.setup_turn_order(current_battle_gods, current_battle_enemies)
	
	# Record battle start in statistics
	if GameManager and GameManager.statistics_manager:
		GameManager.statistics_manager.record_battle_start(config.battle_type, current_battle_enemies.size())
	
	# Start first turn
	_start_next_turn()
	
	return true

func start_dungeon_battle_with_loot_context(gods: Array, loot_table_id: String, context: Dictionary = {}, enemies: Array = []) -> bool:
	"""Start dungeon battle with proper loot table context for template system"""
	print("=== BattleManager: Starting dungeon battle with loot table: %s ===" % loot_table_id)
	
	# Set up battle state
	battle_active = true
	current_battle_gods = gods.duplicate()
	current_battle_enemies = enemies.duplicate()
	current_battle_territory = null
	current_battle_stage = 1
	
	# Set the loot context for the template system
	current_battle_context = {
		"loot_table_id": loot_table_id,
		"context": context
	}
	
	# Reset gods and setup
	_reset_gods_hp()
	auto_battle_enabled = false
	
	# Setup turn order
	turn_system.setup_turn_order(current_battle_gods, current_battle_enemies)
	
	# Start battle
	battle_log_updated.emit("Dungeon Battle: %s" % loot_table_id.replace("_", " ").capitalize())
	_start_next_turn()
	
	return true

# Legacy methods for backward compatibility - redirect to modular system
func start_territory_assault(gods: Array, territory: Territory, stage: int):
	"""Legacy method - redirects to modular start_battle"""
	var config = BattleFactory.create_territory_battle(gods, territory, stage)
	start_battle(config)

func start_dungeon_battle(gods: Array, dungeon_id: String, difficulty: String, enemies: Array) -> bool:
	"""Legacy method - redirects to modular start_battle"""
	var config = BattleFactory.create_dungeon_battle(gods, dungeon_id, difficulty, enemies)
	return start_battle(config)

func reset_battle():
	"""Reset battle state for new wave or battle"""
	print("=== BATTLE MANAGER: Resetting battle state ===")
	
	# Clear current battle state
	battle_active = false
	current_battle_enemies.clear()
	
	# Keep gods and their current state
	# Note: We don't reset god HP between waves - that's Summoners War style
	
	# Clear turn system
	if turn_system:
		turn_system.clear_turn_order()

func start_wave_battle(enemies: Array) -> bool:
	"""Start battle with specific wave enemies (used by wave system)"""
	print("=== BATTLE MANAGER: Starting Wave Battle - %d enemies ===" % enemies.size())
	print("=== BattleManager: Received enemies: %d enemies ===" % enemies.size())
	
	if current_battle_gods.is_empty():
		print("ERROR: No gods selected for wave battle")
		return false
	
	# Set wave enemies
	current_battle_enemies = enemies.duplicate()
	battle_active = true
	
	print("=== BattleManager: current_battle_enemies set to %d enemies ===" % current_battle_enemies.size())
	
	battle_log_updated.emit("Wave Battle: %d enemies approaching!" % enemies.size())
	
	# Setup turn order for this wave
	turn_system.setup_turn_order(current_battle_gods, current_battle_enemies)
	
	# Simple approach: just start the turn after a brief moment to let displays update
	call_deferred("_start_next_turn")
	
	return true

func _start_wave_battle_delayed():
	"""Deprecated - now using enemy_displays_ready signal for proper coordination"""
	# This method is no longer needed as we use signal-based coordination
	_start_next_turn()

func toggle_auto_battle():
	"""Toggle auto-battle mode"""
	auto_battle_enabled = !auto_battle_enabled
	print("Auto-battle: %s" % ("ON" if auto_battle_enabled else "OFF"))
	battle_log_updated.emit("Auto-battle %s" % ("enabled" if auto_battle_enabled else "disabled"))
	
	# Stop any pending auto actions when disabling
	if not auto_battle_enabled:
		auto_battle_timer.stop()
		waiting_for_auto_action = false
		pending_god_action = {}

func set_auto_battle_speed(speed: float):
	"""Set auto-battle speed (1.0 = normal, 2.0 = 2x speed, etc.)"""
	auto_battle_speed = max(0.1, min(10.0, speed))  # Clamp between 0.1x and 10x
	auto_battle_timer.wait_time = 1.0 / auto_battle_speed
	print("Auto-battle speed set to %.1fx" % auto_battle_speed)

func get_auto_battle_speed() -> float:
	"""Get current auto-battle speed multiplier"""
	return auto_battle_speed

func process_god_action(god: God, action: Dictionary):
	"""Process a god's action (from player input or AI)"""
	if not battle_active or not god:
		return
	
	print("Processing action for %s: %s" % [god.name, action])
	
	# Process the action based on type
	match action.get("action", ""):
		"attack":
			_process_attack_action(god, action.get("target"))
		"ability":
			_process_ability_action(god, action.get("ability"), action.get("target"))
		"skip":
			battle_log_updated.emit("%s skips their turn" % god.name)
		_:
			print("Unknown action: %s" % action)
			return
	
	# CRITICAL: Check if battle ended after action processing
	# This prevents showing victory before HP updates complete
	await get_tree().create_timer(0.1).timeout  # Brief pause for UI updates
	if _check_battle_end():
		return  # Battle ended, don't continue
	
	# End turn and advance
	_end_unit_turn(god)

func process_enemy_action(enemy: Dictionary):
	"""Process an enemy's action (AI controlled)"""
	if not battle_active or not enemy:
		return
	
	# Get AI decision
	var action = BattleAI.choose_enemy_action(enemy, current_battle_enemies, current_battle_gods)
	print("Enemy %s chooses: %s" % [_get_stat(enemy, "name", "Unknown"), action])
	
	# Process the action
	match action.get("action", ""):
		"attack":
			_process_attack_action(enemy, action.get("target"))
		"ability":
			_process_ability_action(enemy, action.get("ability"), action.get("target"))
		"skip":
			battle_log_updated.emit("%s skips their turn" % _get_stat(enemy, "name", "Unknown"))
		_:
			print("Enemy unknown action: %s" % action)
	
	# CRITICAL: Check if battle ended after enemy action processing
	await get_tree().create_timer(0.1).timeout  # Brief pause for UI updates
	if _check_battle_end():
		return  # Battle ended, don't continue
	
	# End turn and advance
	_end_unit_turn(enemy)

# Private battle flow methods

func _start_next_turn():
	"""Start the next unit's turn"""
	print("=== BattleManager: _start_next_turn called ===")
	if not battle_active:
		print("=== BattleManager: Battle not active, returning ===")
		return
	
	# Remove dead units from turn order
	turn_system.remove_dead_units()
	
	# Check victory/defeat conditions
	if _check_battle_end():
		return
	
	var current_unit = turn_system.get_current_unit()
	if not current_unit:
		print("No units left in turn order!")
		return
	
	print("=== Turn: %s ===" % _get_stat(current_unit, "name", "Unknown"))
	
	# Process turn start status effects using StatusEffectManager
	var effect_messages = StatusEffectManager.process_turn_start_effects(current_unit, status_effect_manager)
	for message in effect_messages:
		battle_log_updated.emit(message)
	
	# Update UI after status effect processing
	if battle_screen:
		if current_unit is God:
			battle_screen.update_god_hp_instantly(current_unit)
			battle_screen.update_god_status_effects(current_unit)
		else:
			battle_screen.update_enemy_hp_instantly(current_unit)
			battle_screen.update_enemy_status_effects(current_unit)
	
	# Check if unit can act after status effects
	if not turn_system.can_unit_act(current_unit):
		battle_log_updated.emit("%s cannot act this turn" % _get_stat(current_unit, "name", "Unknown"))
		_end_unit_turn(current_unit)
		return
	
	# Determine if this is a god or enemy
	var is_god = current_unit in current_battle_gods
	
	if is_god:
		_handle_god_turn(current_unit)
	else:
		_handle_enemy_turn(current_unit)

func _handle_god_turn(god: God):
	"""Handle a god's turn"""
	print("=== BattleManager: Handling god turn for %s ===" % god.name)
	print("Auto-battle enabled: %s" % auto_battle_enabled)
	print("Battle screen reference: %s" % battle_screen)
	
	if auto_battle_enabled:
		# Stop any existing timer to prevent conflicts
		auto_battle_timer.stop()
		
		# Clear any pending actions from previous turns
		pending_god_action = {}
		waiting_for_auto_action = false
		
		# Show UI first so player can see what's happening
		if battle_screen:
			battle_screen.show_god_turn_ui(god)
		
		# Get AI decision but don't execute immediately
		var action = BattleAI.choose_god_auto_action(god, current_battle_enemies, current_battle_gods)
		pending_god_action = action
		waiting_for_auto_action = true
		
		# Start timer for auto execution
		auto_battle_timer.wait_time = 1.0 / auto_battle_speed
		auto_battle_timer.start()
		
		print("Auto-battle: Scheduled action %s for %s in %.1f seconds" % [action.get("action", "unknown"), god.name, auto_battle_timer.wait_time])
	else:
		# Player input needed - show UI
		if battle_screen:
			print("=== BattleManager: Calling show_god_turn_ui for %s ===" % god.name)
			battle_screen.show_god_turn_ui(god)
		else:
			print("ERROR: BattleManager has no battle_screen reference!")

func _handle_enemy_turn(enemy: Dictionary):
	"""Handle an enemy's turn"""
	# Enemies always use AI
	process_enemy_action(enemy)

func _end_unit_turn(unit):
	"""End a unit's turn and advance to next"""
	print("=== BattleManager: Ending turn for %s ===" % _get_stat(unit, "name", "Unknown"))
	
	# If this was a god's turn, clear the UI
	if unit is God and battle_screen:
		battle_screen.end_god_turn_ui()
	
	# Process turn end status effects
	var effect_messages = StatusEffectManager.process_turn_end_effects(unit, status_effect_manager)
	for message in effect_messages:
		battle_log_updated.emit(message)
	
	# Advance turn
	print("=== BattleManager: Advancing turn ===" )
	turn_system.advance_turn()
	
	# Start next turn after short delay
	print("=== BattleManager: Starting next turn ===" )
	_start_next_turn()

func _process_attack_action(attacker, target):
	"""Process a basic attack action"""
	if not target or _get_stat(target, "hp", 0) <= 0:
		battle_log_updated.emit("%s attacks, but target is invalid!" % _get_stat(attacker, "name", "Unknown"))
		return
	
	# Use CombatCalculator for proper damage calculation
	var damage_result = CombatCalculator.execute_basic_attack(attacker, target)
	
	if not damage_result.hit_success:
		battle_log_updated.emit("%s attacks %s but misses!" % [_get_stat(attacker, "name", "Unknown"), _get_stat(target, "name", "Unknown")])
		return
	
	# Apply damage - UNIFIED APPROACH
	var final_damage = damage_result.damage
	var current_hp = _get_stat(target, "current_hp", 100)
	var new_hp = max(0, current_hp - final_damage)
	_set_hp(target, new_hp)
	
	var crit_text = " (Critical!)" if damage_result.is_critical else ""
	
	battle_log_updated.emit("%s attacks %s for %d damage%s" % [
		_get_stat(attacker, "name", "Unknown"), 
		_get_stat(target, "name", "Unknown"), 
		final_damage,
		crit_text
	])
	
	# Update UI IMMEDIATELY after damage application
	if battle_screen:
		if target is God:
			battle_screen.update_god_hp_instantly(target)
		else:
			battle_screen.update_enemy_hp_instantly(target)
	
	# CRITICAL: Wait a moment for UI to update before checking death
	if new_hp <= 0:
		battle_log_updated.emit("%s is defeated!" % _get_stat(target, "name", "Unknown"))
		
		# Give UI a moment to show the HP change before death effects
		await get_tree().create_timer(0.3).timeout
		
		# Now check if battle should end
		if _check_battle_end():
			return  # Battle ended, don't continue processing
	
	# Check for counters or other death-related effects here

func _determine_ability_type(ability: Dictionary) -> String:
	"""Automatically determine ability type based on effects"""
	# First check if type is explicitly set
	if ability.has("type"):
		return ability.get("type")
	
	# Check effects to determine type
	var effects = ability.get("effects", [])
	if effects.size() == 0:
		return "physical"  # Default for abilities with no effects
	
	# Analyze effects to determine type
	var has_damage = false
	var has_utility = false
	
	for effect in effects:
		var effect_type = effect.get("type", "")
		match effect_type:
			"damage":
				has_damage = true
			# Core SW utility effects
			"heal", "shield", "cleanse", "cleanse_all", "buff", "debuff", "self_buff", \
			"strip", "strip_all", "atb_increase", "atb_decrease", "atb_steal", \
			"additional_turn", "life_drain", "stun", "sleep", "freeze", \
			"immunity", "invincibility", "revive", "endure":
				has_utility = true
			_:
				# For unknown effect types, check if damage_multiplier suggests damage
				if ability.get("damage_multiplier", 0) > 0:
					has_damage = true
	
	# Determine final type
	if has_utility and not has_damage:
		return "utility"
	elif has_damage:
		return "physical"  # or "magical" - could be enhanced to detect this
	else:
		return "physical"  # Default

func _process_ability_action(caster, ability: Dictionary, target):
	"""Process an ability action"""
	if not ability:
		return
	
	var ability_name = ability.get("name", "Unknown Ability")
	var ability_type = _determine_ability_type(ability)
	var targets_type = ability.get("targets", "single")  # single, all_enemies, all_allies, etc.
	
	battle_log_updated.emit("%s uses %s!" % [_get_stat(caster, "name", "Unknown"), ability_name])
	
	# Handle AOE abilities (target is null)
	if target == null:
		match targets_type:
			"all_enemies":
				# Apply to all living enemies
				for enemy in current_battle_enemies:
					if _get_stat(enemy, "current_hp", 0) > 0:
						_process_single_target_ability(caster, ability, enemy, ability_type)
			"all_allies":
				# Apply to all living gods
				for god in current_battle_gods:
					if _get_stat(god, "current_hp", 0) > 0:
						_process_single_target_ability(caster, ability, god, ability_type)
			_:
				print("Unknown AOE target type: %s" % targets_type)
	else:
		# Single target ability
		_process_single_target_ability(caster, ability, target, ability_type)

func _process_single_target_ability(caster, ability: Dictionary, target, ability_type: String):
	"""Process ability on a single target"""
	
	# Handle different ability types
	match ability_type:
		"physical", "magical":
			_process_damage_ability(caster, ability, target)
		"healing":
			_process_healing_ability(caster, ability, target)
		"utility", "buff":
			_process_utility_ability(caster, ability, target)
		_:
			print("WARNING: Unknown ability type: %s for %s" % [ability_type, ability.get("name", "Unknown")])
			battle_log_updated.emit("Unknown ability type: %s" % ability_type)

func _process_damage_ability(caster, ability: Dictionary, target):
	"""Process damage-dealing ability with multi-hit support"""
	if not target:
		print("BattleManager: Null target passed to _process_damage_ability")
		return
	
	# Check for multi-hit ability
	var hits = ability.get("hits", 1)
	var total_damage = 0
	var any_hit = false
	var any_crit = false
	
	print("Processing %s - %d hits on %s" % [ability.get("name", "Unknown"), hits, _get_stat(target, "name", "Unknown")])
	
	# Execute each hit separately (like Summoners War)
	for hit_num in range(hits):
		var damage_result = CombatCalculator.execute_ability_damage(caster, ability, target)
		
		if damage_result.hit_success:
			any_hit = true
			var hit_damage = damage_result.damage
			total_damage += hit_damage
			
			# Apply this hit's damage immediately
			var current_hp = _get_stat(target, "current_hp", 100)
			var new_hp = max(0, current_hp - hit_damage)
			_set_hp(target, new_hp)
			
			var hit_crit_text = " (Crit!)" if damage_result.is_critical else ""
			if damage_result.is_critical:
				any_crit = true
			
			battle_log_updated.emit("Hit %d: %s takes %d damage%s" % [hit_num + 1, _get_stat(target, "name", "Unknown"), hit_damage, hit_crit_text])
			
			# Update UI after each hit for visual feedback
			if battle_screen:
				if target is God:
					battle_screen.update_god_hp_instantly(target)
				else:
					battle_screen.update_enemy_hp_instantly(target)
			
			# Small delay between hits for visual effect (only in multi-hit)
			if hits > 1 and hit_num < hits - 1:
				await get_tree().create_timer(0.15).timeout
			
			# Stop hitting if target dies
			if _get_stat(target, "current_hp", 100) <= 0:
				if hit_num < hits - 1:
					battle_log_updated.emit("Target defeated after %d hits" % (hit_num + 1))
				break
		else:
			battle_log_updated.emit("Hit %d misses %s!" % [hit_num + 1, _get_stat(target, "name", "Unknown")])
	
	# If no hits landed, return early
	if not any_hit:
		return
	
	# Summary message for multi-hit abilities
	if hits > 1:
		var crit_text = " (Critical hits!)" if any_crit else ""
		battle_log_updated.emit("Total: %s takes %d damage from %d hits%s" % [_get_stat(target, "name", "Unknown"), total_damage, hits, crit_text])
	
	# Apply status effects AFTER all hits (SW behavior)
	if ability.has("effects"):
		for effect_data in ability.effects:
			# Use the new modular SW effect system for ALL effects
			var effect_type = effect_data.get("type", "")
			if effect_type != "damage":  # Skip damage effects (already processed above)
				var battle_context = _get_battle_effect_context()
				BattleEffectProcessor.process_single_effect(effect_type, effect_data, caster, target, ability, battle_context)
	
	# Update status effect UI after applying effects
	if battle_screen:
		if target is God:
			battle_screen.update_god_status_effects(target)
		else:
			battle_screen.update_enemy_status_effects(target)
	
	# CRITICAL: Give time for UI to update if target died during multi-hit
	if _get_stat(target, "current_hp", 100) <= 0:
		battle_log_updated.emit("%s is defeated!" % _get_stat(target, "name", "Unknown"))
		# Extra time for death animation/UI updates
		await get_tree().create_timer(0.4).timeout

func _process_healing_ability(caster, ability: Dictionary, target):
	"""Process healing ability"""
	if not target:
		print("BattleManager: Null target passed to _process_healing_ability")
		return
		
	var heal_result = CombatCalculator.execute_healing(caster, ability, target)
	
	# Apply actual healing
	var actual_heal = heal_result.actual_heal
	var crit_text = " (Critical!)" if heal_result.get("is_critical", false) else ""
	battle_log_updated.emit("%s heals for %d HP%s" % [_get_stat(target, "name", "Unknown"), actual_heal, crit_text])
	
	# Update UI
	if battle_screen:
		if target is God:
			battle_screen.update_god_hp_instantly(target)
		else:
			battle_screen.update_enemy_hp_instantly(target)

func _process_utility_ability(caster, ability: Dictionary, target):
	"""Process utility/buff ability"""
	if not target:
		print("BattleManager: Null target passed to _process_utility_ability")
		return
	
	battle_log_updated.emit("%s receives the effect of %s" % [_get_stat(target, "name", "Unknown"), ability.get("name", "Unknown")])
	
	# Handle new effects format (used by most abilities) - MODULAR SW EFFECT SYSTEM
	if ability.has("effects"):
		for effect_data in ability.effects:
			var effect_type = effect_data.get("type", "")
			# Use the new BattleEffectProcessor instead of internal methods
			var battle_context = _get_battle_effect_context()
			BattleEffectProcessor.process_single_effect(effect_type, effect_data, caster, target, ability, battle_context)
	
	# Handle old status_effects format (fallback for compatibility)
	elif ability.has("status_effects"):
		for effect_id in ability.status_effects:
			var effect = StatusEffectManager.create_status_effect_from_id(effect_id, caster)
			if effect:
				StatusEffectManager.apply_status_effect_to_target(target, effect, status_effect_manager)
	
	# Update status effect UI after applying effects
	if battle_screen:
		if target is God:
			battle_screen.update_god_status_effects(target)
		else:
			battle_screen.update_enemy_status_effects(target)


# === HELPER FUNCTIONS ===

func _update_unit_ui(unit):
	"""Update unit UI after effect processing"""
	if battle_screen:
		if unit is God:
			battle_screen.update_god_hp_instantly(unit)
			battle_screen.update_god_status_effects(unit)
		else:
			battle_screen.update_enemy_hp_instantly(unit)
			battle_screen.update_enemy_status_effects(unit)

func _get_battle_effect_context() -> Dictionary:
	"""Get battle context for BattleEffectProcessor"""
	return {
		"current_battle_gods": current_battle_gods,
		"current_battle_enemies": current_battle_enemies,
		"battle_screen": battle_screen,
		"battle_manager": self,
		"status_effect_manager": status_effect_manager
	}

func _create_status_effect_from_data(effect_data, caster) -> StatusEffect:
	"""Create a StatusEffect from ability data"""
	# If effect_data is a string ID, use StatusEffectManager
	if effect_data is String:
		return StatusEffectManager.create_status_effect_from_id(effect_data, caster)
	elif effect_data is Dictionary:
		# Handle complex effect data
		var effect_id = effect_data.get("id", "")
		if effect_id != "":
			return StatusEffectManager.create_status_effect_from_id(effect_id, caster)
	
	return null

func _check_battle_end() -> bool:
	"""Check if battle should end (victory/defeat conditions)"""
	var alive_counts = turn_system.get_units_alive_count(current_battle_gods, current_battle_enemies)
	
	if alive_counts.gods <= 0:
		_end_battle(BattleResult.DEFEAT)
		return true
	elif alive_counts.enemies <= 0:
		_end_battle(BattleResult.VICTORY)
		return true
	
	return false

func _end_battle(result: BattleResult):
	"""End battle with result"""
	battle_active = false
	auto_battle_enabled = false  # Reset auto-battle
	
	# Reset all god HP to full after battle
	_reset_gods_hp()
	
	match result:
		BattleResult.VICTORY:
			battle_log_updated.emit("VICTORY!")
			
			# Record victory statistics
			if GameManager and GameManager.statistics_manager:
				GameManager.statistics_manager.record_battle_end(true, current_battle_gods)
			
			_award_victory_rewards()
		BattleResult.DEFEAT:
			battle_log_updated.emit("DEFEAT!")
			
			# Record defeat statistics  
			if GameManager and GameManager.statistics_manager:
				GameManager.statistics_manager.record_battle_end(false, current_battle_gods)
			
			_award_consolation_rewards()
	
	battle_completed.emit(result)

func _get_current_battle_context() -> Dictionary:
	"""Get current battle context for loot system"""
	return current_battle_context

func set_battle_context(context: Dictionary):
	"""Set battle context for loot system (called by dungeon system, etc.)"""
	current_battle_context = context
	print("BattleManager: Battle context set to %s" % context)

func _reset_gods_hp():
	"""Reset all gods to full HP"""
	print("Resetting all gods to full HP")
	for god in current_battle_gods:
		if god and god is God:
			var max_hp = god.get_max_hp()
			god.current_hp = max_hp
			print("Reset %s HP to %d/%d" % [god.name, god.current_hp, max_hp])
			
			# Also clear any status effects
			if god.has_method("clear_status_effects"):
				god.clear_status_effects()
			elif "status_effects" in god:
				god.status_effects.clear()
	
	# Update UI if battle screen exists
	if battle_screen:
		for god in current_battle_gods:
			if god and god is God:
				battle_screen.update_god_hp_instantly(god)
				battle_screen.update_god_status_effects(god)

func _award_victory_rewards():
	"""Award rewards for victory using the new template-based loot system"""
	var reward_parts = []
	var awarded_loot = {}
	
	# Clear previous loot
	last_awarded_loot.clear()
	
	# Use the new loot system for all reward types
	if GameManager and GameManager.loot_system:
		# Handle territory battles
		if current_battle_territory:
			var is_final_stage = (current_battle_stage >= current_battle_territory.max_stages)
			var territory_element = ""
			
			# Use Territory's built-in element name method and convert to lowercase for loot system
			if current_battle_territory.has_method("get_element_name"):
				territory_element = current_battle_territory.get_element_name().to_lower()
			else:
				territory_element = ""
			
			# Use loot system for stage rewards
			if is_final_stage:
				awarded_loot = GameManager.loot_system.award_loot(
					"boss_stage", 
					current_battle_stage, 
					territory_element
				)
			else:
				awarded_loot = GameManager.loot_system.award_loot(
					"stage_victory", 
					current_battle_stage, 
					territory_element
				)
		
		# Handle dungeon battles - this is where the template system really shines!
		elif _get_current_battle_context():
			var battle_context = _get_current_battle_context()
			var loot_table_id = battle_context.get("loot_table_id", "")
			var context = battle_context.get("context", {})
			
			if loot_table_id != "":
				print("=== BattleManager: Using template loot system for %s ===" % loot_table_id)
				awarded_loot = GameManager.loot_system.award_loot(loot_table_id, 1, "", context)
			else:
				# Fallback to generic battle victory
				awarded_loot = GameManager.loot_system.award_loot("stage_victory", 1, "")
		
		# Fallback for other battle types
		else:
			awarded_loot = GameManager.loot_system.award_loot("stage_victory", 1, "")
		
	# Store the actual awarded loot for WaveSystem to use
	last_awarded_loot = awarded_loot.duplicate()
	
	# Add loot items to inventory system
	if GameManager and GameManager.inventory_manager:
		GameManager.inventory_manager.add_loot_items(awarded_loot)
	
	# Convert awarded loot to display format using ResourceManager
	var resource_manager = GameManager.get_resource_manager() if GameManager.has_method("get_resource_manager") else null
	
	for resource_id in awarded_loot:
			var amount = awarded_loot[resource_id]
			var resource_info = resource_manager.get_resource_info(resource_id) if resource_manager else {}
			var display_name = resource_info.get("name", resource_id.capitalize().replace("_", " "))
			
			reward_parts.append("%d %s" % [amount, display_name])
	
	# Award experience to participating gods
	var base_xp = 100 + (current_battle_stage * 25) if current_battle_territory else 150
	if base_xp > 0:
		reward_parts.append("%d XP" % base_xp)
		GameManager.award_experience_to_gods(base_xp)
		
		# Add XP gain message to battle log for better feedback
		var xp_per_god = int(float(base_xp) / float(current_battle_gods.size()))
		battle_log_updated.emit("[color=cyan]All gods gained %d experience![/color]" % xp_per_god)
	
	# Display rewards
	if reward_parts.size() > 0:
		battle_log_updated.emit("Victory! Rewards:")
		# Split rewards into multiple lines for better readability
		var current_line = ""
		for i in range(reward_parts.size()):
			if current_line.length() > 50 or i == 0:  # Start new line
				if current_line != "":
					battle_log_updated.emit("  " + current_line)
				current_line = reward_parts[i]
			else:
				current_line += ", " + reward_parts[i]
		
		# Add the last line
		if current_line != "":
			battle_log_updated.emit("  " + current_line)
	else:
		battle_log_updated.emit("Victory!")

func _award_consolation_rewards():
	"""Award small consolation rewards for defeat using the new loot system"""
	var awarded_loot = {}
	
	# Clear previous loot
	last_awarded_loot.clear()
	
	if GameManager and GameManager.loot_system:
		# Use the new template-based loot system for defeat rewards
		awarded_loot = GameManager.loot_system.award_loot("battle_defeat", 1, "")
		
		# Store the actual awarded loot for WaveSystem to use
		last_awarded_loot = awarded_loot.duplicate()
		
		# Display defeat rewards
		var resource_manager = GameManager.get_resource_manager() if GameManager.has_method("get_resource_manager") else null
		var reward_parts = []
		
		for resource_id in awarded_loot:
			var amount = awarded_loot[resource_id]
			var resource_info = resource_manager.get_resource_info(resource_id) if resource_manager else {}
			var display_name = resource_info.get("name", resource_id.capitalize().replace("_", " "))
			reward_parts.append("%d %s" % [amount, display_name])
		
		# Award small consolation XP
		var consolation_xp = 25
		GameManager.award_experience_to_gods(consolation_xp)
		reward_parts.append("%d XP" % consolation_xp)
		
		if reward_parts.size() > 0:
			battle_log_updated.emit("Consolation rewards: " + ", ".join(reward_parts))
	else:
		# Fallback - award basic XP
		for god in current_battle_gods:
			if god:
				god.add_experience(25)
		battle_log_updated.emit("Consolation: 25 XP awarded to all gods")

# Signal handlers

func _on_turn_started(unit):
	"""Handle turn start signal"""
	print("Turn started: %s" % _get_stat(unit, "name", "Unknown"))

func _on_turn_ended(unit):
	"""Handle turn end signal"""
	print("Turn ended: %s" % _get_stat(unit, "name", "Unknown"))

func _on_status_effect_applied(target, effect):
	"""Handle status effect applied signal"""
	status_effect_applied.emit(target, effect)

func _on_status_effect_removed(target, effect_id):
	"""Handle status effect removed signal"""
	status_effect_removed.emit(target, effect_id)

func _on_auto_battle_timer_timeout():
	"""Execute pending auto-battle action"""
	print("=== BattleManager: Timer timeout - checking conditions ===")
	print("waiting_for_auto_action: %s" % waiting_for_auto_action)
	print("pending_god_action.size(): %s" % pending_god_action.size())
	print("auto_battle_enabled: %s" % auto_battle_enabled)
	
	# Always stop the timer first to prevent multiple firings
	auto_battle_timer.stop()
	
	if waiting_for_auto_action and pending_god_action.size() > 0:
		# Find the current god whose turn it is
		var current_unit = turn_system.get_current_unit()
		print("Current unit: %s" % (current_unit.name if current_unit else "null"))
		
		if current_unit and current_unit is God:
			print("Auto-battle: Executing scheduled action for %s" % current_unit.name)
			
			# Clear flags BEFORE processing action to prevent race conditions
			var action_to_process = pending_god_action
			pending_god_action = {}
			waiting_for_auto_action = false
			
			# Process the action
			process_god_action(current_unit, action_to_process)
		else:
			print("ERROR: Current unit is not a God!")
			# Clear flags even if error
			pending_god_action = {}
			waiting_for_auto_action = false
	else:
		print("Timer fired but conditions not met - auto-battle may have been disabled")

# === Loot System Integration ===

func get_last_awarded_loot() -> Dictionary:
	"""Get the loot that was actually awarded by the loot system - for WaveSystem integration"""
	return last_awarded_loot.duplicate()

func execute_pending_auto_action():
	"""Immediately execute pending auto action (for speed-up button)"""
	if waiting_for_auto_action and pending_god_action.size() > 0:
		auto_battle_timer.stop()  # Stop the timer
		_on_auto_battle_timer_timeout()  # Execute immediately
		return true
	return false
