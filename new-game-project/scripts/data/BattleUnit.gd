# scripts/data/BattleUnit.gd
# Represents a unit (god or enemy) in battle - contains only battle state
class_name BattleUnit extends RefCounted

# Core identification
var unit_id: String
var display_name: String
var is_player_unit: bool = true

# Battle stats (calculated from base stats + equipment + buffs)
var max_hp: int
var current_hp: int
var attack: int
var defense: int
var speed: int
var crit_rate: int
var crit_damage: int
var accuracy: int
var resistance: int

# Battle-specific state
var is_alive: bool = true
var current_turn_bar: float = 0.0  # Turn bar progress (0-100)
var skill_cooldowns: Array = [0, 0, 0, 0]  # Array[int] - Cooldowns for each skill
var status_effects: Array = []  # Array[StatusEffect]

# Equipment set special effects (loaded from god's equipment)
var set_effects: Array = []  # Array[Dictionary] - Active set effects
var first_attack_done: bool = false  # Track for Hermes ambush
var death_defiance_used: bool = false  # Track for Oracle death defiance
var vengeance_stacks: int = 0  # Track for Nemesis vengeance stacks
var marked_targets: Array = []  # Track for Artemis hunt marks
var shield_amount: int = 0  # Divine/Oracle shields
var immunity_turns: int = 0  # Track for Will set debuff immunity
var first_debuff_blocked: bool = false  # Track for Olympus first debuff immunity

# Skills (battle references)
var skills: Array = []  # Array[Skill]
var passive_skills: Array = []  # Array[Skill]

# Source reference (God or enemy data)
var source_god: God = null
var source_enemy: Dictionary = {}

## Create BattleUnit from a God
static func from_god(god: God) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_id = god.id
	unit.display_name = god.name
	unit.is_player_unit = true
	unit.source_god = god

	# Use GodCalculator for accurate stats (includes equipment, tier, ascension bonuses)
	# Note: CombatCalculator.get_detailed_* methods do NOT include equipment bonuses
	unit.max_hp = GodCalculator.get_current_hp(god)
	unit.current_hp = unit.max_hp
	unit.attack = GodCalculator.get_current_attack(god)
	unit.defense = GodCalculator.get_current_defense(god)
	unit.speed = GodCalculator.get_current_speed(god)
	unit.crit_rate = GodCalculator.get_current_crit_rate(god)
	unit.crit_damage = GodCalculator.get_current_crit_damage(god)
	unit.accuracy = GodCalculator.get_current_accuracy(god)
	unit.resistance = GodCalculator.get_current_resistance(god)

	# Load skills
	unit._load_god_skills(god)

	# Load equipment set special effects
	unit._load_set_effects(god)

	return unit

## Create BattleUnit from enemy data
static func from_enemy(enemy_data: Dictionary) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_id = enemy_data.get("id", "unknown")
	unit.display_name = enemy_data.get("name", "Enemy")
	unit.is_player_unit = false
	unit.source_enemy = enemy_data
	
	# Set stats from enemy data
	unit.max_hp = enemy_data.get("hp", 1000)
	unit.current_hp = unit.max_hp
	unit.attack = enemy_data.get("attack", 200)
	unit.defense = enemy_data.get("defense", 150)
	unit.speed = enemy_data.get("speed", 100)
	unit.crit_rate = enemy_data.get("crit_rate", 15)
	unit.crit_damage = enemy_data.get("crit_damage", 50)
	unit.accuracy = enemy_data.get("accuracy", 0)
	unit.resistance = enemy_data.get("resistance", 15)
	
	# Load enemy skills
	unit._load_enemy_skills(enemy_data)
	
	return unit

## Take damage and check if unit dies
func take_damage(damage: int):
	current_hp = max(0, current_hp - damage)
	if current_hp <= 0:
		is_alive = false

## Heal the unit (applies healing modifiers from status effects)
func heal(amount: int) -> int:
	var healing_modifier: float = get_healing_modifier()
	var actual_heal: int = int(float(amount) * healing_modifier)
	if actual_heal > 0:
		current_hp = min(max_hp, current_hp + actual_heal)
	return actual_heal

## Check if unit can use a specific skill
func can_use_skill(skill_index: int) -> bool:
	if skill_index < 0 or skill_index >= skills.size():
		return false
	
	return skill_cooldowns[skill_index] <= 0

## Use a skill and set its cooldown
func use_skill(skill_index: int):
	if can_use_skill(skill_index):
		var skill = skills[skill_index]
		skill_cooldowns[skill_index] = skill.cooldown

## Reduce cooldowns by 1 turn
func tick_cooldowns():
	for i in range(skill_cooldowns.size()):
		if skill_cooldowns[i] > 0:
			skill_cooldowns[i] -= 1

## Add a status effect
func add_status_effect(effect: StatusEffect):
	# Check if effect already exists and stack/replace as needed
	for existing_effect in status_effects:
		if existing_effect.id == effect.id:
			if effect.can_stack:
				existing_effect.stacks += 1
				return
			else:
				# Replace with new effect
				status_effects.erase(existing_effect)
				break

	status_effects.append(effect)

## Remove a status effect
func remove_status_effect(effect_id: String) -> bool:
	for effect in status_effects:
		if effect.id == effect_id:
			status_effects.erase(effect)
			return true
	return false

## Remove a random debuff (for cleanse effects)
func remove_random_debuff() -> bool:
	var debuffs: Array = []
	for effect: StatusEffect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT:
			debuffs.append(effect)

	if debuffs.is_empty():
		return false

	var to_remove: StatusEffect = debuffs[randi() % debuffs.size()]
	status_effects.erase(to_remove)
	return true

## Remove a random buff (for strip effects)
func remove_random_buff() -> bool:
	var buffs: Array = []
	for effect: StatusEffect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.BUFF or effect.effect_type == StatusEffect.EffectType.HOT:
			buffs.append(effect)

	if buffs.is_empty():
		return false

	var to_remove: StatusEffect = buffs[randi() % buffs.size()]
	status_effects.erase(to_remove)
	return true

## Remove all buffs (for strip all effects)
func remove_all_buffs() -> int:
	var count: int = 0
	var to_remove: Array = []

	for effect: StatusEffect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.BUFF or effect.effect_type == StatusEffect.EffectType.HOT:
			to_remove.append(effect)

	for effect in to_remove:
		status_effects.erase(effect)
		count += 1

	return count

## Steal a random buff (remove from self and return it)
func steal_random_buff() -> StatusEffect:
	var buffs: Array = []
	for effect: StatusEffect in status_effects:
		if effect.effect_type == StatusEffect.EffectType.BUFF or effect.effect_type == StatusEffect.EffectType.HOT:
			buffs.append(effect)

	if buffs.is_empty():
		return null

	var stolen: StatusEffect = buffs[randi() % buffs.size()]
	status_effects.erase(stolen)
	return stolen

## Process status effects (called at start of turn)
func process_status_effects() -> Dictionary:
	var effects_to_remove = []
	var total_results = {"damage": 0, "healing": 0, "messages": []}

	for effect in status_effects:
		# Apply effect (this also reduces duration)
		var results = effect.apply_turn_effects(self)
		total_results.damage += results.get("damage", 0)
		total_results.healing += results.get("healing", 0)
		total_results.messages.append_array(results.get("messages", []))

		# Check if expired (apply_turn_effects already reduced duration)
		if effect.is_expired():
			effects_to_remove.append(effect)

	# Apply damage/healing from effects
	if total_results.damage > 0:
		current_hp = max(0, current_hp - total_results.damage)
	if total_results.healing > 0:
		current_hp = min(max_hp, current_hp + total_results.healing)

	# Remove expired effects
	for effect in effects_to_remove:
		remove_status_effect(effect.id)

	return total_results

## Get current turn bar progress percentage
func get_turn_progress() -> float:
	return current_turn_bar / TurnManager.get_turn_bar_threshold()

## Increase turn bar based on speed
func advance_turn_bar() -> void:
	var bar_speed: float = TurnManager.get_turn_bar_speed()
	var min_increment: float = TurnManager.get_min_turn_bar_increment()
	var increment: float = maxf(speed * bar_speed, min_increment)
	current_turn_bar += increment

## Reset turn bar after taking a turn
func reset_turn_bar() -> void:
	current_turn_bar = 0.0

## Check if unit is ready to take turn
func is_ready_for_turn() -> bool:
	return current_turn_bar >= TurnManager.get_turn_bar_threshold() and is_alive

## Get unit's current HP percentage
func get_hp_percentage() -> float:
	return float(current_hp) / float(max_hp) * 100.0

## Check if unit is enemy
func is_enemy() -> bool:
	return not is_player_unit

## Check if unit can act (not stunned, frozen, sleeping, etc.)
func can_act() -> bool:
	if not is_alive:
		return false
	for effect in status_effects:
		if effect.prevents_action:
			return false
	return true

## Get the status effect that prevents action (for logging)
func get_action_prevention_reason() -> String:
	for effect in status_effects:
		if effect.prevents_action:
			return effect.name
	return ""

## Get skill at index
func get_skill(index: int) -> Skill:
	if index >= 0 and index < skills.size():
		return skills[index]
	return null

## Get unit display info for UI
func get_display_info() -> Dictionary:
	return {
		"name": display_name,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"hp_percentage": get_hp_percentage(),
		"is_alive": is_alive,
		"turn_progress": get_turn_progress(),
		"status_effects": status_effects.map(func(effect): return effect.effect_id)
	}

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _load_god_skills(god: God):
	"""Load skills from a God object"""
	skills.clear()

	# Load from god's skill IDs (assuming skill data exists)
	if god.abilities != null and god.abilities is Array and not god.abilities.is_empty():
		for ability_id in god.abilities:
			var skill = Skill.load_from_id(ability_id)
			if skill:
				skills.append(skill)

	# Ensure we have at least a basic attack
	if skills.is_empty():
		skills.append(Skill.create_basic_attack())

	# Initialize cooldowns array
	skill_cooldowns.resize(skills.size())
	for i in range(skill_cooldowns.size()):
		skill_cooldowns[i] = 0

func _load_enemy_skills(enemy_data: Dictionary):
	"""Load skills from enemy data"""
	skills.clear()

	var enemy_skills = enemy_data.get("skills", ["basic_attack"])
	for skill_id in enemy_skills:
		var skill = Skill.load_from_id(skill_id)
		if skill:
			skills.append(skill)

	# Ensure at least basic attack
	if skills.is_empty():
		skills.append(Skill.create_basic_attack())

	# Initialize cooldowns
	skill_cooldowns.resize(skills.size())
	for i in range(skill_cooldowns.size()):
		skill_cooldowns[i] = 0

func _load_set_effects(god: God) -> void:
	"""Load equipment set special effects from god's equipment"""
	set_effects.clear()

	# Get EquipmentManager through SystemRegistry
	var system_registry: Variant = SystemRegistry.get_instance()
	if not system_registry:
		return

	var equipment_manager: Variant = system_registry.get_system("EquipmentManager")
	if not equipment_manager or not equipment_manager.stat_calculator:
		return

	# Get special effects from the stat calculator
	set_effects = equipment_manager.stat_calculator.get_set_special_effects(god)

	# Apply battle-start effects
	for effect: Dictionary in set_effects:
		match effect.get("effect", ""):
			"divine_favor":
				# Olympus: Start with 20% HP shield + first debuff immunity
				shield_amount = int(max_hp * 0.20)
				first_debuff_blocked = false  # Will block first debuff
			"shield_on_start":
				# Generic shield at start
				shield_amount = int(max_hp * effect.get("effect_value", 0.20))
			"immunity":
				# Will set: Start with X turns of debuff immunity
				immunity_turns = int(effect.get("effect_value", 1))

## Check if unit has a specific set effect active
func has_set_effect(effect_name: String) -> bool:
	for effect: Dictionary in set_effects:
		if effect.get("effect", "") == effect_name:
			return true
	return false

## Get a specific set effect's value
func get_set_effect_value(effect_name: String) -> float:
	for effect: Dictionary in set_effects:
		if effect.get("effect", "") == effect_name:
			return effect.get("effect_value", 0.0)
	return 0.0

## Get a specific set effect's chance
func get_set_effect_chance(effect_name: String) -> float:
	for effect: Dictionary in set_effects:
		if effect.get("effect", "") == effect_name:
			return effect.get("effect_chance", 1.0)
	return 0.0

## Apply damage to unit (with shield, immunity, sleep break, and death defiance support)
func apply_damage(damage: int) -> Dictionary:
	var result: Dictionary = {"damage_dealt": 0, "shield_absorbed": 0, "death_defied": false, "thorns_damage": 0, "reflect_damage": 0, "sleep_broken": false, "damage_immune": false}

	# Check for damage immunity first
	if is_damage_immune():
		result.damage_immune = true
		return result

	var remaining_damage: int = damage

	# Check for shield absorption (from status effects)
	var shield_effect: StatusEffect = get_status_effect("shield")
	if shield_effect and shield_effect.shield_value > 0:
		var absorbed: int = mini(shield_effect.shield_value, remaining_damage)
		shield_effect.shield_value -= absorbed
		remaining_damage -= absorbed
		result.shield_absorbed += absorbed
		# Remove shield if depleted
		if shield_effect.shield_value <= 0:
			remove_status_effect("shield")

	# Check for equipment shield absorption
	if shield_amount > 0:
		var absorbed: int = mini(shield_amount, remaining_damage)
		shield_amount -= absorbed
		remaining_damage -= absorbed
		result.shield_absorbed += absorbed

	# Apply remaining damage to HP
	if remaining_damage > 0:
		current_hp = max(0, current_hp - remaining_damage)
		result.damage_dealt = remaining_damage

		# Sleep breaks on damage
		if has_status_effect("sleep"):
			remove_status_effect("sleep")
			result.sleep_broken = true

	# Check for death defiance (Oracle set)
	if current_hp <= 0 and not death_defiance_used and has_set_effect("death_defiance"):
		death_defiance_used = true
		current_hp = 1
		shield_amount = int(max_hp * 0.25)  # 25% HP shield
		result.death_defied = true
		is_alive = true
	elif current_hp <= 0:
		is_alive = false

	# Calculate thorns damage (Aegis set)
	if has_set_effect("thorns"):
		result.thorns_damage = int(damage * get_set_effect_value("thorns"))

	# Calculate reflect damage (from status effect)
	var reflect_mult: float = get_reflect_damage_percent()
	if reflect_mult > 0:
		result.reflect_damage = int(damage * reflect_mult)

	return result

## Check if unit is immune to damage
func is_damage_immune() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.damage_immunity:
			return true
	return false

## Get total reflect damage percentage from status effects
func get_reflect_damage_percent() -> float:
	var total: float = 0.0
	for effect: StatusEffect in status_effects:
		if effect.reflect_damage > 0:
			total += effect.reflect_damage
	return total

## Check if unit is silenced (cannot use abilities, only basic attack)
func is_silenced() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.silenced:
			return true
	return false

## Check if unit is provoked (must attack the provoker)
func is_provoked() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.provoked:
			return true
	return false

## Get the provoker (caster of provoke effect)
func get_provoker_name() -> String:
	for effect: StatusEffect in status_effects:
		if effect.provoked:
			return effect.caster_name
	return ""

## Check if unit is charmed (attacks allies instead of enemies)
func is_charmed() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.charmed:
			return true
	return false

## Check if unit is untargetable
func is_untargetable() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.untargetable:
			return true
	return false

## Check if unit has counter attack buff (from status effect, not equipment)
func has_counter_attack_buff() -> bool:
	for effect: StatusEffect in status_effects:
		if effect.counter_attack:
			return true
	return false

## Called when this unit takes damage - for vengeance stacking
func on_damage_received() -> void:
	if has_set_effect("retribution"):
		vengeance_stacks = mini(vengeance_stacks + 1, 5)  # Max 5 stacks = 40%

## Get current attack with all modifiers (fury, vengeance, status effects)
func get_modified_attack() -> int:
	var modified: float = float(attack)

	# Apply status effect modifiers
	modified *= (1.0 + get_status_effect_modifier("attack"))

	# Wrath of Ares: +1% ATK per 2% HP missing (up to +50%)
	if has_set_effect("fury_scaling"):
		var hp_missing_percent: float = (1.0 - (float(current_hp) / float(max_hp))) * 100.0
		var fury_bonus: float = minf(hp_missing_percent / 2.0, 50.0) / 100.0
		modified *= (1.0 + fury_bonus)

	# Nemesis Vengeance: +8% per stack (up to 40%)
	if has_set_effect("retribution") and vengeance_stacks > 0:
		var vengeance_bonus: float = vengeance_stacks * 0.08
		modified *= (1.0 + vengeance_bonus)

	return int(modified)

## Get current defense with status effect modifiers
func get_modified_defense() -> int:
	var modified: float = float(defense)
	modified *= (1.0 + get_status_effect_modifier("defense"))
	return int(modified)

## Get current speed with status effect modifiers
func get_modified_speed() -> int:
	var modified: float = float(speed)
	modified *= (1.0 + get_status_effect_modifier("speed"))
	return max(1, int(modified))  # Speed can't go below 1

## Get current crit rate with status effect modifiers
func get_modified_crit_rate() -> int:
	var modified: float = float(crit_rate)
	modified += get_status_effect_modifier("critical_chance") * 100.0  # Convert from decimal
	return int(clamp(modified, 0, 100))

## Get current crit damage with status effect modifiers
func get_modified_crit_damage() -> int:
	var modified: float = float(crit_damage)
	modified += get_status_effect_modifier("critical_damage") * 100.0  # Convert from decimal
	return int(modified)

## Get current accuracy with status effect modifiers
func get_modified_accuracy() -> int:
	var modified: float = float(accuracy)
	modified += get_status_effect_modifier("accuracy") * 100.0  # Convert from decimal
	return int(modified)

## Get total stat modifier from all active status effects
func get_status_effect_modifier(stat_name: String) -> float:
	var total_modifier: float = 0.0
	for effect: StatusEffect in status_effects:
		total_modifier += effect.get_stat_modifier(stat_name)
	return total_modifier

## Check if unit has a specific status effect
func has_status_effect(effect_id: String) -> bool:
	for effect: StatusEffect in status_effects:
		if effect.id == effect_id:
			return true
	return false

## Get a specific status effect by ID
func get_status_effect(effect_id: String) -> StatusEffect:
	for effect: StatusEffect in status_effects:
		if effect.id == effect_id:
			return effect
	return null

## Check if healing is blocked or reduced
func get_healing_modifier() -> float:
	var modifier: float = 1.0 + get_status_effect_modifier("healing_received")
	return maxf(0.0, modifier)  # Can't go negative

## Check if unit takes increased damage (marked_for_death, analyze_weakness)
func get_damage_taken_modifier() -> float:
	return 1.0 + get_status_effect_modifier("damage_taken")

## Tick vengeance stacks down at end of turn
func tick_vengeance() -> void:
	if vengeance_stacks > 0:
		vengeance_stacks -= 1

## Mark a target (Artemis Hunt)
func mark_target(target_id: String) -> void:
	if not marked_targets.has(target_id):
		marked_targets.append(target_id)

## Check if a target is marked
func is_target_marked(target_id: String) -> bool:
	return marked_targets.has(target_id)

## Clear a mark from target
func clear_mark(target_id: String) -> void:
	marked_targets.erase(target_id)

## Check if unit is immune to debuffs (Will set or Olympus first debuff)
func is_debuff_immune() -> bool:
	# Will set immunity turns
	if immunity_turns > 0:
		return true
	# Olympus first debuff immunity (only blocks one)
	if has_set_effect("divine_favor") and not first_debuff_blocked:
		return true
	return false

## Called when a debuff would be applied - returns true if blocked
func try_block_debuff() -> bool:
	# Will set immunity turns
	if immunity_turns > 0:
		return true
	# Olympus first debuff immunity
	if has_set_effect("divine_favor") and not first_debuff_blocked:
		first_debuff_blocked = true
		return true
	return false

## Tick immunity turns down at end of turn
func tick_immunity() -> void:
	if immunity_turns > 0:
		immunity_turns -= 1

## Check if unit should counter-attack (Revenge set)
func should_counter_attack() -> bool:
	if has_set_effect("counter_attack"):
		var counter_chance: float = get_set_effect_chance("counter_attack")
		return randf() < counter_chance
	return false

## Check if attack should apply petrify/stun (Despair set)
func should_petrify() -> bool:
	if has_set_effect("petrify_chance"):
		var petrify_chance: float = get_set_effect_chance("petrify_chance")
		return randf() < petrify_chance
	return false
