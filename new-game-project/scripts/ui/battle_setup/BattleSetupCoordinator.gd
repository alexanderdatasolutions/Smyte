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
		team_manager.team_changed.connect(_on_team_changed)
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

func setup_for_hex_node_capture(hex_node: HexNode):
	battle_context = {
		"type": "hex_capture",
		"hex_node": hex_node
	}
	if not team_manager:
		call_deferred("_update_for_context")
	else:
		_update_for_context()

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
			title = "PVP BATTLE"
		"hex_capture":
			var node = battle_context.get("hex_node")
			if node:
				title = "CAPTURE: " + node.name
		"tower":
			var floor_num = battle_context.get("floor", 1)
			title = "TOWER - FLOOR " + str(floor_num)

	main_ui.set_screen_title(title)
	main_ui.show_header_back_button(true)
	main_ui.connect_header_back_button(_on_back_pressed)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_team_changed(_team: Array):
	# Team changed - stats update automatically in TeamSelectionManager
	pass

func _on_battle_start_requested(team: Array):
	battle_context["selected_team"] = team
	battle_setup_complete.emit(battle_context)

	# If no specific context was set, start a test battle
	if not battle_context.has("type") or battle_context.get("type", "") == "":
		_start_battle_directly(team)

func _on_setup_cancelled():
	setup_cancelled.emit()

func _on_back_pressed():
	setup_cancelled.emit()
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.go_back()

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
