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
const BattleUnitCardScene = preload("res://scenes/ui/battle/BattleUnitCard.tscn")

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

# Unit card tracking for turn highlighting
var player_unit_cards: Dictionary = {}  # BattleUnit -> BattleUnitCard
var enemy_unit_cards: Dictionary = {}   # BattleUnit -> BattleUnitCard
var current_active_unit: BattleUnit = null

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
		if not battle_coordinator.turn_changed.is_connected(_on_turn_changed):
			battle_coordinator.turn_changed.connect(_on_turn_changed)

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
	# Clear active unit highlighting
	_clear_active_highlight()
	current_active_unit = null

	# Update UI based on result
	if battle_status_label:
		if result.victory:
			battle_status_label.text = "VICTORY!"
		else:
			battle_status_label.text = "DEFEAT!"

func _on_turn_changed(unit: BattleUnit):
	"""Handle turn change - highlight active unit's card"""
	print("BattleScreen: Turn changed to ", unit.display_name if unit else "null")

	# Clear previous highlight
	_clear_active_highlight()

	# Set new active unit
	current_active_unit = unit

	# Find and highlight the active unit's card
	if unit:
		var card = _get_unit_card(unit)
		if card:
			card.set_active(true)

		# Update turn indicator
		if turn_indicator:
			turn_indicator.text = "%s's Turn" % unit.display_name

		# Update all unit cards (for HP/status changes)
		_update_all_unit_cards()

func _clear_active_highlight():
	"""Remove active highlight from all unit cards"""
	for unit_card in player_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.set_active(false)
	for unit_card in enemy_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.set_active(false)

func _get_unit_card(unit: BattleUnit) -> BattleUnitCard:
	"""Get the BattleUnitCard for a given unit"""
	if player_unit_cards.has(unit):
		return player_unit_cards[unit]
	if enemy_unit_cards.has(unit):
		return enemy_unit_cards[unit]
	return null

func _update_all_unit_cards():
	"""Update all unit cards with current battle state"""
	for unit_card in player_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.update_unit()
	for unit_card in enemy_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.update_unit()

func _populate_battle_ui():
	"""Populate the battle UI with units from battle state using BattleUnitCard"""
	if not battle_coordinator or not battle_coordinator.battle_state:
		print("BattleScreen: No battle state available")
		return

	var battle_state = battle_coordinator.battle_state

	# Clear existing units and card tracking
	_clear_container(player_team_container)
	_clear_container(enemy_team_container)
	player_unit_cards.clear()
	enemy_unit_cards.clear()
	current_active_unit = null

	# Populate player team with BattleUnitCard
	var player_units = battle_state.get_player_units()
	print("BattleScreen: Creating ", player_units.size(), " player unit cards")
	for unit in player_units:
		var unit_card = _create_battle_unit_card(unit)
		player_team_container.add_child(unit_card)
		player_unit_cards[unit] = unit_card
		# Connect click signal for targeting
		unit_card.unit_clicked.connect(_on_unit_card_clicked)

	# Populate enemy team with BattleUnitCard
	var enemy_units = battle_state.get_enemy_units()
	print("BattleScreen: Creating ", enemy_units.size(), " enemy unit cards")
	for unit in enemy_units:
		var unit_card = _create_battle_unit_card(unit)
		enemy_team_container.add_child(unit_card)
		enemy_unit_cards[unit] = unit_card
		# Connect click signal for targeting
		unit_card.unit_clicked.connect(_on_unit_card_clicked)

	# Update status
	if battle_status_label:
		battle_status_label.text = "Battle in progress..."
	if action_label:
		action_label.text = "Fight!"

func _create_battle_unit_card(unit: BattleUnit) -> BattleUnitCard:
	"""Create a BattleUnitCard for a battle unit"""
	var unit_card = BattleUnitCardScene.instantiate() as BattleUnitCard
	unit_card.setup_unit(unit, BattleUnitCard.CardStyle.NORMAL)
	return unit_card

func _on_unit_card_clicked(unit: BattleUnit):
	"""Handle unit card click for targeting - RULE 4: UI signals"""
	print("BattleScreen: Unit clicked - ", unit.display_name)
	# TODO: In Task 6, this will be used for ability targeting

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
