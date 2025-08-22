# BattleAI.gd - Intelligent AI for both gods and enemies
class_name BattleAI
extends RefCounted

# Main AI decision methods

static func choose_god_auto_action(god: God, enemies: Array, allies: Array) -> Dictionary:
	"""Choose best action for god using Summoners War AI priorities"""
	
	var alive_enemies = enemies.filter(func(e): return e.get("current_hp", 0) > 0)
	var alive_allies = allies.filter(func(g): return g.current_hp > 0)
	
	# Priority 1: Emergency heal if ally is critically low (< 30% HP)
	for ally in alive_allies:
		if ally != god and ally.current_hp > 0:
			var hp_percent = float(ally.current_hp) / float(ally.get_max_hp())
			if hp_percent < 0.3:
				var heal_ability = _find_healing_ability(god)
				if heal_ability.size() > 0:
					print("Auto-AI: Emergency heal for %s at %.1f%% HP" % [ally.name, hp_percent * 100])
					return {"action": "ability", "ability": heal_ability, "target": ally}
	
	# Priority 2: Cleanse debuffed ally
	for ally in alive_allies:
		if ally != god and ally.current_hp > 0 and ally.get_debuffs().size() > 0:
			var cleanse_ability = _find_cleanse_ability(god)
			if cleanse_ability.size() > 0:
				print("Auto-AI: Cleansing %s (has %d debuffs)" % [ally.name, ally.get_debuffs().size()])
				return {"action": "ability", "ability": cleanse_ability, "target": ally}
	
	# Priority 3: Use buff ability if no buffs active on team
	var team_has_buffs = false
	for ally in alive_allies:
		if ally.current_hp > 0 and ally.get_buffs().size() > 0:
			team_has_buffs = true
			break
	
	if not team_has_buffs:
		var buff_ability = _find_buff_ability(god)
		if buff_ability.size() > 0:
			var target = _choose_buff_target(god, alive_allies, buff_ability)
			print("Auto-AI: Using buff ability %s on %s" % [buff_ability.name, target.name])
			return {"action": "ability", "ability": buff_ability, "target": target}
	
	# Priority 4: AOE ability if 3+ enemies alive
	if alive_enemies.size() >= 3:
		var aoe_ability = _find_aoe_ability(god)
		if aoe_ability.size() > 0:
			var target = _choose_damage_target(alive_enemies)
			print("Auto-AI: Using AOE ability %s (3+ enemies)" % aoe_ability.name)
			return {"action": "ability", "ability": aoe_ability, "target": target}
	
	# Priority 5: Nuke low HP enemy (< 40%)
	for enemy in alive_enemies:
		var hp_percent = float(enemy.get("current_hp", 0)) / float(enemy.get("hp", 100))
		if hp_percent < 0.4:
			var nuke_ability = _find_nuke_ability(god)
			if nuke_ability.size() > 0:
				print("Auto-AI: Nuking %s at %.1f%% HP" % [enemy.get("name", "Enemy"), hp_percent * 100])
				return {"action": "ability", "ability": nuke_ability, "target": enemy}
	
	# Priority 6: Use any available ability with intelligent targeting
	var best_ability = _find_best_available_ability(god)
	if best_ability.size() > 0:
		var target = _choose_ability_target(god, best_ability, alive_enemies, alive_allies)
		print("Auto-AI: Using ability %s on %s" % [best_ability.name, _get_unit_name(target)])
		return {"action": "ability", "ability": best_ability, "target": target}
	
	# Priority 7: Basic attack with intelligent targeting
	var target = _choose_damage_target(alive_enemies)
	print("Auto-AI: Basic attack on %s" % _get_unit_name(target))
	return {"action": "attack", "target": target}

static func choose_enemy_action(enemy: Dictionary, enemy_allies: Array, god_enemies: Array) -> Dictionary:
	"""Choose action for enemy using their AI behavior"""
	
	var alive_gods = god_enemies.filter(func(g): return g.current_hp > 0)
	var targetable_gods = alive_gods.filter(_is_god_targetable)
	
	if targetable_gods.size() == 0:
		return {"action": "skip"}
	
	# Check for provoke/taunt - if so, must target them
	var provoked_gods = targetable_gods.filter(func(g): return g.has_status_effect("provoked"))
	var target_pool = provoked_gods if provoked_gods.size() > 0 else targetable_gods
	
	# Get enemy AI behavior
	var ai_behavior = enemy.get("ai_behavior", {})
	var target_priority = ai_behavior.get("target_priority", "random")
	var ability_usage = ai_behavior.get("ability_usage", "basic_attacks_mostly")
	var aggression = ai_behavior.get("aggression", 0.5)
	
	# Choose target based on AI behavior
	var target = _choose_enemy_target(target_pool, target_priority, enemy)
	
	# Decide between ability and basic attack
	if _should_use_ability(enemy, ability_usage, aggression):
		var ability = _choose_enemy_ability(enemy, target)
		if ability.size() > 0:
			return {"action": "ability", "ability": ability, "target": target}
	
	# Default to basic attack
	return {"action": "attack", "target": target}

# God AI helper methods

static func _find_healing_ability(god: God) -> Dictionary:
	"""Find best healing ability for god"""
	for ability in god.active_abilities:
		if ability.get("damage_type", "") == "healing":
			return ability
	return {}

static func _find_cleanse_ability(god: God) -> Dictionary:
	"""Find cleanse/dispel ability"""
	for ability in god.active_abilities:
		var special_effects = ability.get("special_effects", [])
		if special_effects.has("cleanse") or special_effects.has("dispel"):
			return ability
	return {}

static func _find_buff_ability(god: God) -> Dictionary:
	"""Find buff ability"""
	for ability in god.active_abilities:
		if ability.get("damage_type", "") == "none":
			# Check for buff status effects
			var status_effects = ability.get("status_effects", [])
			for effect in status_effects:
				if effect in ["attack_boost", "defense_boost", "speed_boost", "crit_boost"]:
					return ability
	return {}

static func _find_aoe_ability(god: God) -> Dictionary:
	"""Find AOE ability"""
	for ability in god.active_abilities:
		var targets = ability.get("targets", "single")
		if targets == "all_enemies":
			return ability
	return {}

static func _find_nuke_ability(god: God) -> Dictionary:
	"""Find high damage single-target ability"""
	var best_ability = {}
	var best_damage = 0.0
	
	for ability in god.active_abilities:
		var targets = ability.get("targets", "single")
		if targets == "single":
			var damage_mult = ability.get("damage_multiplier", 1.0)
			if damage_mult > best_damage:
				best_damage = damage_mult
				best_ability = ability
	
	return best_ability

static func _find_best_available_ability(god: God) -> Dictionary:
	"""Find best available ability to use"""
	if god.active_abilities.size() > 0:
		# For now, return a random ability - could be more sophisticated
		var random_index = randi() % god.active_abilities.size()
		return god.active_abilities[random_index]
	return {}

static func _choose_buff_target(god: God, allies: Array, ability: Dictionary) -> God:
	"""Choose best target for buff ability"""
	var targets = ability.get("targets", "self")
	
	match targets:
		"self":
			return god
		"single", "lowest_hp_ally":
			# Buff the lowest HP ally (most in danger)
			var lowest_hp_ally = god
			var lowest_hp_percent = 1.0
			for ally in allies:
				if ally.current_hp > 0:
					var hp_percent = float(ally.current_hp) / float(ally.get_max_hp())
					if hp_percent < lowest_hp_percent:
						lowest_hp_percent = hp_percent
						lowest_hp_ally = ally
			return lowest_hp_ally
		"all_allies":
			return allies[0] if allies.size() > 0 else god  # Return any ally as representative
		_:
			return god

static func _choose_damage_target(enemies: Array):
	"""Choose best enemy to attack based on Summoners War AI priorities"""
	if enemies.size() == 0:
		return null
	
	var targetable_enemies = enemies.filter(func(e): return e.get("current_hp", 0) > 0)
	if targetable_enemies.size() == 0:
		return null
	
	# Priority 1: Lowest HP enemy (finish off weak targets)
	var lowest_hp_enemy = targetable_enemies[0]
	var lowest_hp_percent = float(lowest_hp_enemy.get("current_hp", 0)) / float(lowest_hp_enemy.get("hp", 100))
	
	for enemy in targetable_enemies:
		var hp_percent = float(enemy.get("current_hp", 0)) / float(enemy.get("hp", 100))
		if hp_percent < lowest_hp_percent:
			lowest_hp_percent = hp_percent
			lowest_hp_enemy = enemy
	
	# If an enemy is below 30% HP, prioritize finishing them
	if lowest_hp_percent < 0.3:
		return lowest_hp_enemy
	
	# Priority 2: Highest attack enemy (eliminate threats)
	var highest_attack_enemy = targetable_enemies[0]
	var highest_attack = highest_attack_enemy.get("attack", 0)
	
	for enemy in targetable_enemies:
		var attack = enemy.get("attack", 0)
		if attack > highest_attack:
			highest_attack = attack
			highest_attack_enemy = enemy
	
	return highest_attack_enemy

static func _choose_ability_target(god: God, ability: Dictionary, enemies: Array, allies: Array):
	"""Choose target based on ability type and targeting"""
	var damage_type = ability.get("damage_type", "damage")
	var targets = ability.get("targets", "single")
	
	match damage_type:
		"healing", "none":  # none often means buff/utility
			match targets:
				"self":
					return god
				"lowest_hp_ally":
					var lowest_hp_ally = god
					var lowest_hp_percent = float(god.current_hp) / float(god.get_max_hp())
					for ally in allies:
						if ally.current_hp > 0:
							var hp_percent = float(ally.current_hp) / float(ally.get_max_hp())
							if hp_percent < lowest_hp_percent:
								lowest_hp_percent = hp_percent
								lowest_hp_ally = ally
					return lowest_hp_ally
				"all_allies":
					return allies[0] if allies.size() > 0 else god
				_:
					return _choose_damage_target(enemies)
		_:  # Damage abilities
			return _choose_damage_target(enemies)

# Enemy AI helper methods

static func _choose_enemy_target(target_pool: Array, target_priority: String, enemy: Dictionary):
	"""Choose target for enemy based on their AI behavior"""
	if target_pool.size() == 0:
		return null
	
	match target_priority:
		"lowest_hp":
			var lowest_hp_god = target_pool[0]
			var lowest_hp_percent = float(lowest_hp_god.current_hp) / float(lowest_hp_god.get_max_hp())
			for god in target_pool:
				var hp_percent = float(god.current_hp) / float(god.get_max_hp())
				if hp_percent < lowest_hp_percent:
					lowest_hp_percent = hp_percent
					lowest_hp_god = god
			return lowest_hp_god
		
		"highest_attack":
			var highest_attack_god = target_pool[0]
			var highest_attack = highest_attack_god.get_current_attack()
			for god in target_pool:
				var attack = god.get_current_attack()
				if attack > highest_attack:
					highest_attack = attack
					highest_attack_god = god
			return highest_attack_god
		
		"random":
			return target_pool[randi() % target_pool.size()]
		
		"balanced":
			# Consider both HP and threat level
			var best_target = target_pool[0]
			var best_score = _calculate_target_score(best_target)
			for god in target_pool:
				var score = _calculate_target_score(god)
				if score > best_score:
					best_score = score
					best_target = god
			return best_target
		
		_:
			return target_pool[randi() % target_pool.size()]

static func _should_use_ability(enemy: Dictionary, ability_usage: String, aggression: float) -> bool:
	"""Decide if enemy should use ability or basic attack"""
	match ability_usage:
		"always_use_best":
			return true
		"smart_cooldown_management":
			return randf() < 0.7  # 70% chance to use ability
		"support_allies":
			return randf() < 0.5  # 50% chance to use ability
		"basic_attacks_mostly":
			return randf() < 0.3  # 30% chance to use ability
		_:
			return randf() < aggression  # Use aggression as ability chance

static func _choose_enemy_ability(enemy: Dictionary, target) -> Dictionary:
	"""Choose which ability enemy should use (simplified for now)"""
	# For now, enemies don't have complex abilities
	# This could be expanded to give enemies actual abilities
	var enemy_type = enemy.get("type", "basic")
	
	match enemy_type:
		"boss":
			# Bosses might have special abilities
			if randf() < 0.3:
				return {
					"name": "Boss Strike",
					"damage_multiplier": 2.0,
					"type": "physical",
					"targets": "single"
				}
		"elite":
			# Elites might have moderate abilities
			if randf() < 0.2:
				return {
					"name": "Power Attack", 
					"damage_multiplier": 1.5,
					"type": "physical",
					"targets": "single"
				}
		_:
			# Basic enemies rarely use abilities
			pass
	
	return {}  # No ability, will default to basic attack

static func _calculate_target_score(god: God) -> float:
	"""Calculate targeting score for balanced enemy AI"""
	var hp_percent = float(god.current_hp) / float(god.get_max_hp())
	var attack_power = god.get_current_attack()
	
	# Lower HP = higher score (easier to finish off)
	var hp_score = 1.0 - hp_percent
	
	# Higher attack = higher score (bigger threat)
	var attack_score = attack_power / 200.0  # Normalize attack value
	
	# Combine scores (weighted toward finishing low HP targets)
	return hp_score * 0.7 + attack_score * 0.3

# Helper utility methods

static func _is_god_targetable(god: God) -> bool:
	"""Check if god can be targeted (not untargetable)"""
	return not god.has_status_effect("untargetable")

static func _get_unit_name(unit) -> String:
	"""Get name from either God or dictionary"""
	if unit is God:
		return unit.name
	else:
		return unit.get("name", "Unknown")

# Advanced AI behaviors for future expansion

static func evaluate_battlefield_state(gods: Array, enemies: Array) -> Dictionary:
	"""Analyze current battlefield state for advanced AI decisions"""
	var state = {
		"god_advantage": 0.0,
		"enemy_advantage": 0.0,
		"total_god_hp": 0.0,
		"total_enemy_hp": 0.0,
		"god_threat_level": 0.0,
		"enemy_threat_level": 0.0
	}
	
	# Calculate total HP and threat levels
	for god in gods:
		if god.current_hp > 0:
			state.total_god_hp += god.current_hp
			state.god_threat_level += god.get_current_attack()
	
	for enemy in enemies:
		if enemy.get("current_hp", 0) > 0:
			state.total_enemy_hp += enemy.get("current_hp", 0)
			state.enemy_threat_level += enemy.get("attack", 0)
	
	# Calculate advantage ratios
	if state.total_enemy_hp > 0:
		state.god_advantage = state.total_god_hp / state.total_enemy_hp
	if state.total_god_hp > 0:
		state.enemy_advantage = state.total_enemy_hp / state.total_god_hp
	
	return state

static func predict_turn_outcome(attacker, target, action: Dictionary) -> Dictionary:
	"""Predict the outcome of a potential action (for advanced AI planning)"""
	var prediction = {
		"estimated_damage": 0,
		"target_survives": true,
		"attacker_risk": 0.0
	}
	
	# Simplified prediction - could be expanded
	if action.get("action") == "attack":
		var attacker_attack = 0
		if attacker is God:
			attacker_attack = attacker.get_current_attack()
		else:
			attacker_attack = attacker.get("attack", 50)
		
		# Simple damage estimation
		prediction.estimated_damage = int(attacker_attack * 0.8)  # Rough estimate
		
		var target_hp = 0
		if target is God:
			target_hp = target.current_hp
		else:
			target_hp = target.get("current_hp", 100)
		
		prediction.target_survives = target_hp > prediction.estimated_damage
	
	return prediction
