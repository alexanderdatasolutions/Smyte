class_name BattleScreen
extends Control

"""
BattleScreen.gd - Main battle screen coordinator
RULE 2: Single responsibility - ONLY coordinates battle UI components
RULE 4: No logic in UI - delegates to systems through SystemRegistry
RULE 5: Uses SystemRegistry for all system access

Following prompt.prompt.md architecture:
- UI LAYER: Only display, no data modification
- Coordinates battle UI components (BattleUICoordinator, etc.)
"""

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

# UI Components (following RULE 2: Single responsibility)
@onready var back_button = $MainContainer/BottomContainer/ButtonContainer/BackButton
@onready var battle_title_label = $MainContainer/HeaderContainer/BattleTitleLabel
@onready var action_label = $MainContainer/BattleArenaContainer/BattleCenter/ActionDisplay/ActionLabel
@onready var battle_status_label = $MainContainer/BottomContainer/BattleStatusLabel
@onready var player_team_container = $MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer
@onready var enemy_team_container = $MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer
@onready var turn_indicator = $MainContainer/BattleArenaContainer/BattleCenter/TurnIndicator

# Signal for screen navigation (RULE 4: UI signals)
signal back_pressed

# Battle state tracking
var battle_coordinator = null

func _ready():
	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Get battle coordinator and connect to signals
	battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")
	if battle_coordinator:
		if not battle_coordinator.battle_started.is_connected(_on_battle_started):
			battle_coordinator.battle_started.connect(_on_battle_started)
		if not battle_coordinator.battle_ended.is_connected(_on_battle_ended):
			battle_coordinator.battle_ended.connect(_on_battle_ended)

		# Check if there's already an active battle
		if battle_coordinator.has_method("is_in_battle") and battle_coordinator.is_in_battle():
			# Battle already active, populate UI
			_populate_battle_ui()
		else:
			_show_no_battle_state()
	else:
		_show_no_battle_state()

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	back_pressed.emit()

func start_battle(battle_config: Dictionary):
	"""Start a battle with given configuration - RULE 5: SystemRegistry"""
	# Battle coordinator already stored in _ready
	if battle_coordinator:
		battle_coordinator.start_battle(battle_config)

func _on_battle_started(_config):
	"""Handle battle start event - populate UI with units"""
	print("BattleScreen: Battle started, populating UI")
	_populate_battle_ui()

func _on_battle_ended(result):
	"""Handle battle end - RULE 4: UI listens to events"""
	print("BattleScreen: Battle ended")
	# Update UI based on result
	if battle_status_label:
		if result.victory:
			battle_status_label.text = "VICTORY!"
		else:
			battle_status_label.text = "DEFEAT!"

func _populate_battle_ui():
	"""Populate the battle UI with units from battle state"""
	if not battle_coordinator or not battle_coordinator.battle_state:
		print("BattleScreen: No battle state available")
		return

	var battle_state = battle_coordinator.battle_state

	# Clear existing units
	_clear_container(player_team_container)
	_clear_container(enemy_team_container)

	# Populate player team
	var player_units = battle_state.get_player_units()
	print("BattleScreen: Creating ", player_units.size(), " player unit cards")
	for unit in player_units:
		if unit.source_god:
			var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
			god_card.setup_god_card(unit.source_god)
			player_team_container.add_child(god_card)

	# Populate enemy team
	var enemy_units = battle_state.get_enemy_units()
	print("BattleScreen: Creating ", enemy_units.size(), " enemy unit cards")
	for unit in enemy_units:
		var enemy_card = _create_enemy_card(unit)
		enemy_team_container.add_child(enemy_card)

	# Update status
	if battle_status_label:
		battle_status_label.text = "Battle in progress..."
	if action_label:
		action_label.text = "Fight!"

func _create_enemy_card(unit: BattleUnit) -> Control:
	"""Create a card for an enemy unit"""
	# If it's a God (captured enemy), use GodCardFactory
	if unit.source_god:
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.setup_god_card(unit.source_god)
		return god_card

	# Otherwise create a simple enemy display
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 120)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = unit.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [unit.current_hp, unit.max_hp]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hp_label)

	return card

func _clear_container(container: Control):
	"""Clear all children from a container"""
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _show_no_battle_state():
	"""Show friendly message when no battle is active"""
	if battle_status_label:
		battle_status_label.text = "No active battle. Start a battle from Dungeons or Territories."
	if action_label:
		action_label.text = "Ready to fight!"
	if battle_title_label:
		battle_title_label.text = "BATTLE ARENA"
