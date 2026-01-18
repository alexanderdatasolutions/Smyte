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
	
	# Use existing CombatCalculator for authentic SW stats
	var attack_breakdown = CombatCalculator.get_detailed_attack_breakdown(god)
	var defense_breakdown = CombatCalculator.get_detailed_defense_breakdown(god)
	var hp_breakdown = CombatCalculator.get_detailed_hp_breakdown(god)
	var speed_breakdown = CombatCalculator.get_detailed_speed_breakdown(god)
	
	unit.max_hp = hp_breakdown.final_value
	unit.current_hp = unit.max_hp
	unit.attack = attack_breakdown.final_value
	unit.defense = defense_breakdown.final_value
	unit.speed = speed_breakdown.final_value
	unit.crit_rate = god.get_current_crit_rate() if god.has_method("get_current_crit_rate") else 15
	unit.crit_damage = god.get_current_crit_damage() if god.has_method("get_current_crit_damage") else 50
	unit.accuracy = god.get_current_accuracy() if god.has_method("get_current_accuracy") else 0
	unit.resistance = god.get_current_resistance() if god.has_method("get_current_resistance") else 15
	
	# Load skills
	unit._load_god_skills(god)
	
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

## Heal the unit
func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)

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
				print("BattleUnit.add_status_effect: Stacked %s on %s (now %d stacks)" % [effect.name, display_name, existing_effect.stacks])
				return
			else:
				# Replace with new effect
				status_effects.erase(existing_effect)
				break

	status_effects.append(effect)
	print("BattleUnit.add_status_effect: Added %s to %s (total effects: %d)" % [effect.name, display_name, status_effects.size()])

## Remove a status effect
func remove_status_effect(effect_id: String) -> bool:
	for effect in status_effects:
		if effect.id == effect_id:
			status_effects.erase(effect)
			return true
	return false

## Process status effects (called at start of turn)
func process_status_effects():
	var effects_to_remove = []
	
	for effect in status_effects:
		# Apply effect
		effect.apply_effect(self)
		
		# Reduce duration
		effect.duration -= 1
		if effect.duration <= 0:
			effects_to_remove.append(effect)
	
	# Remove expired effects
	for effect in effects_to_remove:
		remove_status_effect(effect.effect_id)

## Get current turn bar progress percentage
func get_turn_progress() -> float:
	return current_turn_bar / 100.0

## Increase turn bar based on speed
func advance_turn_bar():
	# Ensure minimum increment to prevent infinite loops with low/zero speed
	var increment = max(speed * 0.07, 1.0)  # Minimum 1.0 per tick
	current_turn_bar += increment

## Reset turn bar after taking a turn
func reset_turn_bar():
	current_turn_bar = 0.0

## Check if unit is ready to take turn
func is_ready_for_turn() -> bool:
	return current_turn_bar >= 100.0 and is_alive

## Get unit's current HP percentage
func get_hp_percentage() -> float:
	return float(current_hp) / float(max_hp) * 100.0

## Check if unit is enemy
func is_enemy() -> bool:
	return not is_player_unit

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
