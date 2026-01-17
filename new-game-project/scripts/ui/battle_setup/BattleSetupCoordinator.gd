# scripts/ui/battle_setup/BattleSetupCoordinator.gd
# Single responsibility: Coordinate battle setup screen functionality
class_name BattleSetupCoordinator
extends Control

signal battle_setup_complete(context: Dictionary)
signal setup_cancelled

# Load component scripts
const TeamSelectionManagerScript = preload("res://scripts/ui/battle_setup/TeamSelectionManager.gd")
const BattleInfoManagerScript = preload("res://scripts/ui/battle_setup/BattleInfoManager.gd")

var team_manager
var battle_info_manager
var battle_context: Dictionary = {}

func _ready():
	# Defer setup to ensure we're in the tree
	call_deferred("_setup_managers")

func _setup_managers():
	if not is_inside_tree():
		push_warning("BattleSetupCoordinator: Not in tree, deferring setup")
		call_deferred("_setup_managers")
		return

	team_manager = TeamSelectionManagerScript.new()
	add_child(team_manager)

	battle_info_manager = BattleInfoManagerScript.new()
	add_child(battle_info_manager)

	_connect_signals()

func _connect_signals():
	team_manager.team_changed.connect(_on_team_changed)
	team_manager.battle_start_requested.connect(_on_battle_start_requested)
	team_manager.setup_cancelled.connect(_on_setup_cancelled)

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
	# Ensure managers are set up before updating context
	if not team_manager:
		call_deferred("_update_for_context")
	else:
		_update_for_context()

func _update_for_context():
	# Double check managers exist
	if not team_manager or not battle_info_manager:
		push_warning("BattleSetupCoordinator: Managers not ready, deferring context update")
		call_deferred("_update_for_context")
		return

	team_manager.setup_for_context(battle_context)
	battle_info_manager.update_for_context(battle_context)

func _on_team_changed(team: Array):
	battle_info_manager.update_team_preview(team)

func _on_battle_start_requested(team: Array):
	battle_context["selected_team"] = team
	battle_setup_complete.emit(battle_context)

func _on_setup_cancelled():
	setup_cancelled.emit()
