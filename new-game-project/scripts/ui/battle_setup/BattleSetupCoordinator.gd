# scripts/ui/battle_setup/BattleSetupCoordinator.gd
# Coordinates battle setup screen functionality with unified team stats and sorting
# ALL battle types use the same unified UI with combat power, bonuses, sorting, equipment
class_name BattleSetupCoordinator
extends Control

signal battle_setup_complete(context: Dictionary)
signal setup_cancelled

const TeamSelectionManagerScript = preload("res://scripts/ui/battle_setup/TeamSelectionManager.gd")

var team_manager: TeamSelectionManager
var battle_context: Dictionary = {}

func _ready():
	call_deferred("_setup_unified_ui")

func _setup_unified_ui():
	if not is_inside_tree():
		call_deferred("_setup_unified_ui")
		return

	var screen = get_parent()
	if not screen:
		push_error("BattleSetupCoordinator: No parent screen found")
		return

	# Always use unified code-based UI for consistent experience
	_create_unified_battle_setup(screen)

func _create_unified_battle_setup(screen: Control):
	"""Create unified battle setup UI with stats, bonuses, sorting, and equipment"""
	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)

	# Main container with margins
	var main_container = MarginContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 60)  # Leave room for header
	main_container.add_theme_constant_override("margin_bottom", 10)
	screen.add_child(main_container)

	# Create team manager with full unified UI
	team_manager = TeamSelectionManagerScript.new()
	add_child(team_manager)
	team_manager.initialize_full(main_container)

	_connect_signals()

func _connect_signals():
	if team_manager:
		team_manager.battle_start_requested.connect(_on_battle_start_requested)
		team_manager.setup_cancelled.connect(_on_setup_cancelled)

# ============================================================================
# CONTEXT SETUP
# ============================================================================

func setup_for_territory_battle(territory: Territory, stage: int):
	battle_context = {
		"type": "territory",
		"territory": territory,
		"stage": stage
	}
	_update_for_context()

func setup_for_dungeon_battle(dungeon_id: String, difficulty: String):
	battle_context = {
		"type": "dungeon",
		"dungeon_id": dungeon_id,
		"difficulty": difficulty
	}
	_update_for_context()

func setup_for_pvp_battle(opponent_data: Dictionary):
	battle_context = {
		"type": "pvp",
		"opponent": opponent_data
	}
	_update_for_context()

func setup_for_pvp_attack(hex_node) -> void:
	"""Setup for PvP territory attack"""
	battle_context = {
		"type": "pvp_territory_attack",
		"pvp_hex": hex_node,
		"defender_uid": hex_node.controller_uid if hex_node else "",
		"defender_name": hex_node.controller_display_name if hex_node else "Unknown"
	}
	_update_for_context()

func setup_for_pvp_defense(hex_node) -> void:
	"""Setup for PvP territory defense team selection"""
	battle_context = {
		"type": "pvp_territory_defense",
		"pvp_hex": hex_node,
		"is_defense_setup": true
	}
	_update_for_context()

func setup_for_defense_team():
	"""Setup for arena defense team selection"""
	battle_context = {
		"type": "defense_setup",
		"is_defense_setup": true
	}
	_update_for_context()

func setup_for_hex_node_capture(hex_node: HexNode):
	battle_context = {
		"type": "hex_capture",
		"hex_node": hex_node
	}
	if not team_manager:
		call_deferred("_update_for_context")
	else:
		_update_for_context()
	# Check for team selection tutorial after setup
	call_deferred("_check_team_selection_tutorial")

func setup_for_tower(floor_number: int = 1):
	battle_context = {
		"type": "tower",
		"floor": floor_number
	}
	_update_for_context()

func _update_for_context():
	if not team_manager:
		call_deferred("_update_for_context")
		return

	team_manager.setup_for_context(battle_context)
	_update_header_for_context()

func _update_header_for_context():
	"""Update the unified header based on battle type"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if not main_ui:
		return

	var title = "BATTLE SETUP"
	match battle_context.get("type", ""):
		"territory":
			var territory = battle_context.get("territory")
			if territory:
				title = "TERRITORY: " + territory.name
		"dungeon":
			var dungeon_id = battle_context.get("dungeon_id", "")
			title = "DUNGEON: " + dungeon_id.to_upper()
		"pvp":
			var opponent = battle_context.get("opponent", {})
			var opponent_name = opponent.get("display_name", "Opponent")
			title = "PVP vs " + opponent_name
		"defense_setup":
			title = "SET ARENA DEFENSE"
		"hex_capture":
			var node = battle_context.get("hex_node")
			if node:
				title = "CAPTURE: " + node.name
		"tower":
			var floor_num = battle_context.get("floor", 1)
			title = "TOWER - FLOOR " + str(floor_num)
		"pvp_territory_attack":
			var defender_name = battle_context.get("defender_name", "Territory")
			title = "ATTACK: " + defender_name
		"pvp_territory_defense":
			title = "SET HEX DEFENSE"

	main_ui.set_screen_title(title)
	main_ui.show_header_back_button(true)
	main_ui.connect_header_back_button(_on_back_pressed)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_battle_start_requested(team: Array):
	battle_context["selected_team"] = team
	battle_setup_complete.emit(battle_context)

	var context_type: String = battle_context.get("type", "")

	# Handle different battle types
	# Note: "hex_capture" and "pvp_territory_attack" are handled by their respective
	# screen's battle_setup_complete handler via NodeCaptureHandler (unified flow)
	match context_type:
		"":
			# If no specific context was set, start a test battle
			_start_battle_directly(team)

func _on_setup_cancelled():
	setup_cancelled.emit()

func _on_back_pressed():
	setup_cancelled.emit()
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.go_back()

func _start_pvp_territory_battle(team: Array) -> void:
	"""Start PvP territory battle with enemies from enemies.json"""
	var valid_team := []
	for god in team:
		if god != null:
			valid_team.append(god)

	if valid_team.is_empty():
		return

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")

	if not screen_manager or not battle_coordinator:
		return

	# Get hex info from context
	var pvp_hex = battle_context.get("pvp_hex")
	var tier: int = pvp_hex.tier if pvp_hex else 1

	# Create enemies from enemies.json using the same system as regular territory
	var defender_team := _create_pvp_defenders(tier)

	var battle_config = BattleConfig.new()
	battle_config.battle_type = BattleConfig.BattleType.TERRITORY
	battle_config.attacker_team = valid_team
	battle_config.defender_team = defender_team

	# Store PvP context for result handling and return navigation
	if pvp_hex:
		battle_config.territory_id = pvp_hex.id
		battle_config.set_meta("is_pvp_territory", true)
		battle_config.set_meta("pvp_hex_id", pvp_hex.id)

	# Set rewards based on tier (PvP territory battles)
	battle_config.base_rewards = _calculate_pvp_territory_rewards(tier)
	battle_config.loot_table_id = "territory_tier" + str(tier)

	if screen_manager.change_screen("battle"):
		var battle_screen = screen_manager.get_current_screen()
		if battle_screen and battle_screen.has_method("start_battle"):
			battle_screen.start_battle(battle_config)
		else:
			battle_coordinator.start_battle(battle_config)


func _create_pvp_defenders(tier: int) -> Array:
	"""Create PvE defenders using enemies.json - same system as NodeCaptureHandler"""
	var defenders := []
	var num_enemies := mini(tier + 1, 4)  # Tier 1: 2, Tier 2: 3, etc.

	var enemy_names := _get_tier_enemy_names(tier)

	for i in range(num_enemies):
		var enemy_name: String = enemy_names[i % enemy_names.size()]
		var enemy := _create_enemy_from_config(enemy_name, tier)
		if not enemy.is_empty():
			defenders.append(enemy)
		else:
			defenders.append(_create_default_defender(tier, i))

	return defenders


func _get_tier_enemy_names(tier: int) -> Array:
	"""Get enemy names for a tier from enemies.json"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return _get_fallback_enemy_names(tier)

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return _get_fallback_enemy_names(tier)

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return _get_fallback_enemy_names(tier)

	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if not territory_defenders.has(tier_key):
		return _get_fallback_enemy_names(tier)

	var tier_data: Dictionary = territory_defenders[tier_key]
	var names: Array = []

	for node_type: String in tier_data:
		if node_type.begins_with("_"):
			continue
		var node_enemies = tier_data[node_type]
		if node_enemies is Dictionary:
			for enemy_name: String in node_enemies.keys():
				if enemy_name not in names:
					names.append(enemy_name)

	if names.is_empty():
		return _get_fallback_enemy_names(tier)

	return names


func _get_fallback_enemy_names(tier: int) -> Array:
	"""Fallback names if enemies.json fails"""
	var names := {
		1: ["Kobold Miner", "Nisse", "Domovoi"],
		2: ["Jorogumo", "Kelpie", "Rusalka"],
		3: ["Oni Brute", "Baba Yaga's Guard", "Berserker"],
		4: ["Typhon Spawn", "Set's Champion", "Jormungandr Scion"],
		5: ["Apep", "Typhon", "Angra Mainyu"]
	}
	return names.get(tier, names[1])


func _create_enemy_from_config(enemy_name: String, tier: int) -> Dictionary:
	"""Create enemy using enemies.json scaling - matches NodeCaptureHandler exactly"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return {}

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return {}

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return {}

	var enemy_data: Dictionary = {}
	var enemy_element := "neutral"
	var enemy_role := "basic"

	# Search territory_defenders
	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if territory_defenders.has(tier_key):
		var tier_data: Dictionary = territory_defenders[tier_key]
		for node_type: String in tier_data:
			if node_type.begins_with("_"):
				continue
			var node_enemies = tier_data[node_type]
			if node_enemies is Dictionary and node_enemies.has(enemy_name):
				enemy_data = node_enemies[enemy_name]
				enemy_element = enemy_data.get("element", "neutral")
				enemy_role = enemy_data.get("role", "basic")
				break

	# Fallback to enemy_types
	if enemy_data.is_empty():
		var enemy_types: Dictionary = enemies_config.get("enemy_types", {})
		for element: String in enemy_types:
			var roles = enemy_types[element]
			for role: String in roles:
				if roles[role] is Dictionary and roles[role].has(enemy_name):
					enemy_data = roles[role][enemy_name]
					enemy_element = element
					enemy_role = role
					break
			if not enemy_data.is_empty():
				break

	if enemy_data.is_empty():
		return {}

	# Calculate stats using enemies.json scaling
	var role_config: Dictionary = enemies_config.get("enemy_roles", {}).get(enemy_role, {})
	var stat_multipliers: Dictionary = role_config.get("stat_multipliers", {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0})
	var base_stats: Dictionary = enemies_config.get("enemy_scaling", {}).get("base_stats", {})
	var per_level: Dictionary = enemies_config.get("enemy_scaling", {}).get("per_level_growth", {})
	var tier_bonus: Dictionary = enemies_config.get("enemy_scaling", {}).get("stat_calculation", {}).get("territory_tier_bonus", {})

	var level := tier * 10
	var tier_mult := float(tier_bonus.get(str(tier), 1.0))

	var hp := int((base_stats.get("hp", 100) + level * per_level.get("hp", 6)) * stat_multipliers.get("hp", 1.0) * tier_mult)
	var atk := int((base_stats.get("attack", 45) + level * per_level.get("attack", 2)) * stat_multipliers.get("attack", 1.0) * tier_mult)
	var def := int((base_stats.get("defense", 35) + level * per_level.get("defense", 1)) * stat_multipliers.get("defense", 1.0) * tier_mult)
	var spd := int((base_stats.get("speed", 50) + level * per_level.get("speed", 1)) * stat_multipliers.get("speed", 1.0) * tier_mult)

	return {
		"id": enemy_name.to_lower().replace(" ", "_") + "_" + str(tier),
		"name": enemy_name,
		"level": level,
		"pantheon": enemy_data.get("pantheon", "enemy"),
		"element": enemy_element,
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": enemy_data.get("abilities", [])
	}


func _create_default_defender(tier: int, index: int) -> Dictionary:
	"""Fallback defender if enemies.json lookup fails"""
	var level := tier * 10 + index * 2
	var hp := 100 + (tier * 50) + (index * 20)
	var atk := 40 + (tier * 15) + (index * 5)
	var def := 30 + (tier * 12) + (index * 4)
	var spd := 45 + (tier * 8) + (index * 3)

	return {
		"id": "pvp_defender_%d_%d" % [tier, index],
		"name": "Territory Guardian",
		"level": level,
		"pantheon": "enemy",
		"element": "neutral",
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": []
	}


func _calculate_pvp_territory_rewards(tier: int) -> Dictionary:
	"""Calculate rewards for PvP territory battles based on tier"""
	# Base rewards scale with tier
	var mana_base := 100 + (tier * 100)
	var gold_base := 50 + (tier * 50)
	var experience_base := 75 + (tier * 50)

	# Add tier-specific crafting materials
	var rewards := {
		"mana": mana_base,
		"gold": gold_base,
		"experience": experience_base
	}

	# Add tier-appropriate materials (matches NodeCaptureHandler._get_default_defense_drops)
	match tier:
		1:
			rewards["monster_parts"] = randi_range(5, 15)
		2:
			rewards["monster_parts"] = randi_range(10, 25)
			rewards["beast_scales"] = randi_range(3, 8)
		3:
			rewards["monster_parts"] = randi_range(20, 40)
			rewards["beast_scales"] = randi_range(8, 18)
			rewards["elemental_cores"] = randi_range(2, 6)
		4, 5:
			rewards["dragon_parts"] = randi_range(5, 15)
			rewards["beast_scales"] = randi_range(15, 35)
			rewards["elemental_cores"] = randi_range(5, 12)

	return rewards


# ============================================================================
# TUTORIAL INTEGRATION
# ============================================================================
var _tutorial_highlight_overlay: TutorialHighlightOverlay = null

func _check_team_selection_tutorial() -> void:
	"""Check if team selection tutorial should be shown."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return

	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if not tutorial_orch:
		return

	# Check if team_selection_tutorial should start
	if not tutorial_orch.is_tutorial_completed("team_selection_tutorial"):
		# Check prerequisite
		if tutorial_orch.is_tutorial_completed("hex_capture_tutorial"):
			tutorial_orch.start_tutorial("team_selection_tutorial")
			# Connect to highlight requests if not connected
			if not tutorial_orch.highlight_requested.is_connected(_on_tutorial_highlight_requested):
				tutorial_orch.highlight_requested.connect(_on_tutorial_highlight_requested)
			if not tutorial_orch.highlight_cleared.is_connected(_on_tutorial_highlight_cleared):
				tutorial_orch.highlight_cleared.connect(_on_tutorial_highlight_cleared)

func _on_tutorial_highlight_requested(target_id: String, message: String, title: String, _show_button: bool = true) -> void:
	"""Handle highlight requests from TutorialOrchestrator."""
	var tutorial_orch = SystemRegistry.get_instance().get_system("TutorialOrchestrator")
	if not tutorial_orch:
		return

	var step_data: Dictionary = tutorial_orch.get_current_step_data()
	if step_data.get("target_screen", "") != "team_selection":
		return

	if target_id == "team_bonuses":
		_highlight_team_bonuses(message, title)

func _highlight_team_bonuses(message: String, title: String) -> void:
	"""Highlight the team bonuses section."""
	if not team_manager:
		return

	var bonuses_container: Control = team_manager.get_team_bonuses_container()
	if not bonuses_container:
		# No container, auto-advance
		_emit_tutorial_action("team_bonuses_seen")
		return

	# Create highlight overlay if needed
	if not _tutorial_highlight_overlay:
		_tutorial_highlight_overlay = TutorialHighlightOverlay.new()
		var root: Node = get_tree().root
		if root:
			root.add_child(_tutorial_highlight_overlay)

	# Show highlight with continue button (not wait for click)
	_tutorial_highlight_overlay.highlight_target(bonuses_container, message, title, "Got it!", false, true)
	_tutorial_highlight_overlay.continue_pressed.connect(_on_team_bonuses_seen, CONNECT_ONE_SHOT)

func _on_team_bonuses_seen() -> void:
	"""Handle team bonuses highlight dismissed."""
	_emit_tutorial_action("team_bonuses_seen")

func _on_tutorial_highlight_cleared() -> void:
	"""Clear any active tutorial highlight."""
	if _tutorial_highlight_overlay:
		_tutorial_highlight_overlay.clear_highlight()

func _emit_tutorial_action(action_id: String) -> void:
	"""Emit a tutorial action via EventBus."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return
	var event_bus: Node = registry.get_system("EventBus")
	if event_bus and event_bus.has_signal("tutorial_action_completed"):
		event_bus.tutorial_action_completed.emit(action_id)

func _start_battle_directly(team: Array):
	"""Start a test battle directly when no context is set"""
	var valid_team = []
	for god in team:
		if god != null:
			valid_team.append(god)

	if valid_team.is_empty():
		return

	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")

	if not screen_manager or not battle_coordinator:
		return

	var battle_config = BattleConfig.new()
	battle_config.battle_type = BattleConfig.BattleType.DUNGEON
	battle_config.attacker_team = valid_team
	battle_config.dungeon_name = "Test Battle"
	battle_config.enemy_waves = [
		[
			{"name": "Test Goblin", "level": 5, "hp": 500, "attack": 100, "defense": 50, "speed": 80},
			{"name": "Test Orc", "level": 6, "hp": 700, "attack": 120, "defense": 60, "speed": 70}
		]
	]

	if screen_manager.change_screen("battle"):
		var battle_screen = screen_manager.get_current_screen()
		if battle_screen and battle_screen.has_method("start_battle"):
			battle_screen.start_battle(battle_config)
		else:
			battle_coordinator.start_battle(battle_config)
