# BattleManager.gd - Core battle orchestration 
extends Node

class_name BattleManager

# Note: System classes are referenced directly as they have class_name declarations

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

func start_territory_assault(gods: Array, territory: Territory, stage: int):
	"""Start battle with territory and stage"""
	print("=== BATTLE MANAGER: Starting %s Stage %d ===" % [territory.name, stage])
	
	battle_active = true
	current_battle_gods = gods.duplicate()
	current_battle_territory = territory
	current_battle_stage = stage
	
	# Reset all gods to full HP at start of battle
	_reset_gods_hp()
	
	# Create enemies using EnemyFactory
	current_battle_enemies = EnemyFactory.create_enemies_for_stage(territory, stage)
	
	# Reset auto-battle state for new battle
	auto_battle_enabled = false
	
	battle_log_updated.emit("Battle: %s Stage %d" % [territory.name, stage])
	
	# Setup turn order
	turn_system.setup_turn_order(current_battle_gods, current_battle_enemies)
	
	# Start first turn
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
	
	# Update UI
	if battle_screen:
		if target is God:
			battle_screen.update_god_hp_instantly(target)
		else:
			battle_screen.update_enemy_hp_instantly(target)
	
	# Check if target died
	if new_hp <= 0:
		battle_log_updated.emit("%s is defeated!" % _get_stat(target, "name", "Unknown"))

func _process_ability_action(caster, ability: Dictionary, target):
	"""Process an ability action"""
	if not ability:
		return
	
	var ability_name = ability.get("name", "Unknown Ability")
	var ability_type = ability.get("type", "physical")
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
			battle_log_updated.emit("Unknown ability type: %s" % ability_type)

func _process_damage_ability(caster, ability: Dictionary, target):
	"""Process damage-dealing ability"""
	if not target:
		print("BattleManager: Null target passed to _process_damage_ability")
		return
		
	var damage_result = CombatCalculator.execute_ability_damage(caster, ability, target)
	
	if not damage_result.hit_success:
		battle_log_updated.emit("The ability misses %s!" % _get_stat(target, "name", "Unknown"))
		return
	
	# Apply damage - UNIFIED APPROACH
	var final_damage = damage_result.damage
	var current_hp = _get_stat(target, "current_hp", 100)
	var new_hp = max(0, current_hp - final_damage)
	_set_hp(target, new_hp)
	
	var crit_text = " (Critical!)" if damage_result.is_critical else ""
	battle_log_updated.emit("%s takes %d damage%s" % [_get_stat(target, "name", "Unknown"), final_damage, crit_text])
	
	# Update UI
	if battle_screen:
		if target is God:
			battle_screen.update_god_hp_instantly(target)
		else:
			battle_screen.update_enemy_hp_instantly(target)
	
	# Apply status effects using StatusEffectManager
	if ability.has("status_effects"):
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
		if target is God:
			battle_screen.update_god_status_effects(target)
		else:
			battle_screen.update_enemy_status_effects(target)

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
	
	# Apply status effects if ability has them
	if ability.has("status_effects"):
		for effect_id in ability.status_effects:
			var effect = StatusEffectManager.create_status_effect_from_id(effect_id, caster)
			if effect:
				StatusEffectManager.apply_status_effect_to_target(target, effect, status_effect_manager)
	
	# Update status effect UI after applying effects
	if battle_screen and ability.has("status_effects") and ability.status_effects.size() > 0:
		if target is God:
			battle_screen.update_god_status_effects(target)
		else:
			battle_screen.update_enemy_status_effects(target)

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
			_award_victory_rewards()
		BattleResult.DEFEAT:
			battle_log_updated.emit("DEFEAT!")
			_award_consolation_rewards()
	
	battle_completed.emit(result)

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
	"""Award rewards for victory"""
	if GameManager and current_battle_territory:
		var is_final_stage = (current_battle_stage >= current_battle_territory.max_stages)
		var rewards = GameManager.award_stage_rewards(current_battle_stage, current_battle_territory, is_final_stage)
		
		# Build detailed reward text for battle log
		var reward_parts = []
		
		# Core resources
		if rewards.divine_essence > 0:
			reward_parts.append("%d Divine Essence" % rewards.divine_essence)
		if rewards.divine_crystals > 0:
			reward_parts.append("%d Divine Crystals" % rewards.divine_crystals)
		if rewards.awakening_stones > 0:
			reward_parts.append("%d Awakening Stones" % rewards.awakening_stones)
		
		# Detailed powder breakdown (Summoners War style)
		if rewards.has("powder_details") and rewards.powder_details.size() > 0:
			var powder_parts = []
			
			for powder_type in rewards.powder_details.keys():
				var amount = rewards.powder_details[powder_type]
				if amount > 0:
					# Parse powder type (e.g., "fire_powder_low" -> "Fire Low")
					var parts = powder_type.split("_")
					if parts.size() >= 3:
						var element = parts[0].capitalize()
						var tier = parts[2].capitalize()
						var display_key = "%s %s" % [element, tier]
						powder_parts.append("%d %s" % [amount, display_key])
			
			# Add powder rewards to display
			for powder_part in powder_parts:
				reward_parts.append(powder_part)
		
		# Detailed relic breakdown
		if rewards.has("relic_details") and rewards.relic_details.size() > 0:
			for relic_type in rewards.relic_details.keys():
				var amount = rewards.relic_details[relic_type]
				if amount > 0:
					var display_name = relic_type.replace("_", " ").capitalize()
					reward_parts.append("%d %s" % [amount, display_name])
		
		# Equipment drops
		if rewards.has("equipment") and rewards.equipment > 0:
			reward_parts.append("%d Equipment" % rewards.equipment)
		
		# Handle experience separately (not part of loot system)
		var base_xp = 100 + (current_battle_stage * 25)  # Base XP calculation
		if base_xp > 0:
			reward_parts.append("%d XP" % base_xp)
			# Award XP to participating gods
			GameManager.award_experience_to_gods(base_xp)
		
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
			battle_log_updated.emit("Victory! (No rewards this time)")
	else:
		battle_log_updated.emit("Victory!")

func _award_consolation_rewards():
	"""Award small consolation rewards for defeat"""
	for god in current_battle_gods:
		if god:
			god.add_experience(25)

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

func execute_pending_auto_action():
	"""Immediately execute pending auto action (for speed-up button)"""
	if waiting_for_auto_action and pending_god_action.size() > 0:
		auto_battle_timer.stop()  # Stop the timer
		_on_auto_battle_timer_timeout()  # Execute immediately
		return true
	return false
