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

	# Get the UI nodes from the parent BattleSetupScreen
	var screen = get_parent()
	if not screen:
		push_error("BattleSetupCoordinator: No parent screen found")
		return

	# Find the UI nodes
	var team_slots = screen.get_node_or_null("MainContainer/ContentContainer/TeamSelectionContainer/TeamSlotsContainer")
	var gods_grid = screen.get_node_or_null("MainContainer/ContentContainer/TeamSelectionContainer/AvailableGodsContainer/ScrollContainer/GodsGrid")
	var start_btn = screen.get_node_or_null("MainContainer/BottomContainer/StartBattleButton")
	var cancel_btn = screen.get_node_or_null("MainContainer/BottomContainer/CancelButton")

	if not team_slots or not gods_grid or not start_btn or not cancel_btn:
		push_error("BattleSetupCoordinator: Required UI nodes not found")
		return

	# Create and initialize team manager
	team_manager = TeamSelectionManagerScript.new()
	add_child(team_manager)
	team_manager.initialize(team_slots, gods_grid, start_btn, cancel_btn)

	# Get battle info panel nodes
	var enemy_container = screen.get_node_or_null("MainContainer/ContentContainer/BattleInfoPanel/EnemyPreviewContainer")
	var rewards_container = screen.get_node_or_null("MainContainer/ContentContainer/BattleInfoPanel/RewardsContainer")
	var title_label = screen.get_node_or_null("MainContainer/HeaderContainer/TitleLabel")
	var desc_label = screen.get_node_or_null("MainContainer/HeaderContainer/DescriptionLabel")

	# Create and initialize battle info manager
	battle_info_manager = BattleInfoManagerScript.new()
	add_child(battle_info_manager)
	if enemy_container and rewards_container:
		battle_info_manager.initialize(enemy_container, rewards_container, title_label, desc_label)

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

	# Emit signal for any listeners
	battle_setup_complete.emit(battle_context)

	# If no specific context was set (direct navigation), start a test battle
	if not battle_context.has("type") or battle_context.get("type", "") == "":
		_start_battle_directly(team)

func _on_setup_cancelled():
	setup_cancelled.emit()

func _start_battle_directly(team: Array):
	"""Start a test battle directly when no context is set (for testing)"""
	# Filter out null entries
	var valid_team = []
	for god in team:
		if god != null:
			valid_team.append(god)

	if valid_team.is_empty():
		push_error("BattleSetupCoordinator: No valid gods in team")
		return

	# Get systems
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")

	if not screen_manager or not battle_coordinator:
		push_error("BattleSetupCoordinator: Required systems not available")
		return

	# Build test battle config using BattleConfig
	var battle_config = BattleConfig.new()
	battle_config.battle_type = BattleConfig.BattleType.DUNGEON
	battle_config.attacker_team = valid_team
	battle_config.dungeon_name = "Test Battle"
	# Create a test enemy wave with a basic enemy
	battle_config.enemy_waves = [
		[
			{"name": "Test Goblin", "level": 5, "hp": 500, "attack": 100, "defense": 50, "speed": 80},
			{"name": "Test Orc", "level": 6, "hp": 700, "attack": 120, "defense": 60, "speed": 70}
		]
	]

	# Navigate to battle screen and start battle
	if screen_manager.change_screen("battle"):
		var battle_screen = screen_manager.get_current_screen()
		if battle_screen and battle_screen.has_method("start_battle"):
			battle_screen.start_battle(battle_config)
		else:
			battle_coordinator.start_battle(battle_config)
