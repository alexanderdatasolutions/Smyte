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

const BattleUnitCardScene = preload("res://scenes/ui/battle/BattleUnitCard.tscn")
const BattleResultOverlayScene = preload("res://scenes/ui/battle/BattleResultOverlay.tscn")

# UI Components (following RULE 2: Single responsibility)
@onready var back_button = $MainContainer/BottomContainer/ButtonContainer/BackButton
@onready var battle_title_label = $MainContainer/HeaderContainer/BattleTitleLabel
@onready var action_label = $MainContainer/BattleArenaContainer/BattleCenter/ActionDisplay/ActionLabel
@onready var battle_status_label = $MainContainer/BottomContainer/BattleStatusLabel
@onready var player_team_container = $MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer
@onready var enemy_team_container = $MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer
@onready var turn_indicator = $MainContainer/BattleArenaContainer/BattleCenter/TurnIndicator
@onready var ability_bar = $MainContainer/BottomContainer/AbilityBarContainer/AbilityBar
@onready var turn_order_bar = $MainContainer/HeaderContainer/TurnOrderContainer/TurnOrderBar

# Signal for screen navigation (RULE 4: UI signals)
signal back_pressed

# Battle state tracking
var battle_coordinator = null

# Unit card tracking for turn highlighting
var player_unit_cards: Dictionary = {}  # BattleUnit -> BattleUnitCard
var enemy_unit_cards: Dictionary = {}   # BattleUnit -> BattleUnitCard
var current_active_unit: BattleUnit = null

# Battle result overlay
var battle_result_overlay = null  # BattleResultOverlay instance

func _ready():
	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Connect ability bar signal (RULE 4: UI signals)
	if ability_bar:
		ability_bar.ability_selected.connect(_on_ability_selected)
		ability_bar.hide()  # Hidden by default until player's turn

	# Create battle result overlay (hidden by default)
	_create_battle_result_overlay()

	# Get battle coordinator and connect to signals
	battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")
	if battle_coordinator:
		if not battle_coordinator.battle_started.is_connected(_on_battle_started):
			battle_coordinator.battle_started.connect(_on_battle_started)
		if not battle_coordinator.battle_ended.is_connected(_on_battle_ended):
			battle_coordinator.battle_ended.connect(_on_battle_ended)
		if not battle_coordinator.turn_changed.is_connected(_on_turn_changed):
			battle_coordinator.turn_changed.connect(_on_turn_changed)

		# Connect to action_executed signal to show damage numbers and update UI
		if battle_coordinator.action_processor:
			if not battle_coordinator.action_processor.action_executed.is_connected(_on_action_executed):
				battle_coordinator.action_processor.action_executed.connect(_on_action_executed)

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

func _on_battle_ended(result: BattleResult):
	"""Handle battle end - RULE 4: UI listens to events"""
	print("BattleScreen: Battle ended - Victory: ", result.victory)
	# Clear active unit highlighting
	_clear_active_highlight()
	current_active_unit = null

	# Hide ability bar when battle ends
	_hide_ability_bar()

	# Clear turn order bar when battle ends
	_clear_turn_order_bar()

	# Update UI based on result
	if battle_status_label:
		if result.victory:
			battle_status_label.text = "VICTORY!"
		else:
			battle_status_label.text = "DEFEAT!"

	# Show the battle result overlay with rewards
	_show_battle_result_overlay(result)

func _on_turn_changed(unit: BattleUnit):
	"""Handle turn change - highlight active unit's card and show/hide ability bar"""
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

		# Show ability bar for player units, hide for enemies
		_update_ability_bar_for_turn(unit)

		# Update turn order bar
		_update_turn_order_bar(unit)

func _clear_active_highlight():
	"""Remove active highlight from all unit cards"""
	for unit_card in player_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.set_active(false)
	for unit_card in enemy_unit_cards.values():
		if unit_card and is_instance_valid(unit_card):
			unit_card.set_active(false)

func _get_unit_card(unit: BattleUnit):
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

func _create_battle_unit_card(unit: BattleUnit):
	"""Create a BattleUnitCard for a battle unit"""
	var unit_card = BattleUnitCardScene.instantiate()
	unit_card.setup_unit(unit, unit_card.CardStyle.NORMAL)
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
	# Hide ability bar when no battle
	_hide_ability_bar()
	# Clear turn order bar when no battle
	_clear_turn_order_bar()

# =============================================================================
# ABILITY BAR MANAGEMENT
# =============================================================================

func _update_ability_bar_for_turn(unit: BattleUnit):
	"""Show ability bar for player units, hide for enemy units"""
	if not ability_bar:
		return

	# Check if this is a player unit (not an enemy)
	if unit and not unit.is_enemy():
		# Player unit's turn - show and populate ability bar
		ability_bar.setup_unit(unit)
		print("BattleScreen: Showing ability bar for player unit: ", unit.display_name)
	else:
		# Enemy unit's turn - hide ability bar
		_hide_ability_bar()
		print("BattleScreen: Hiding ability bar (enemy turn)")

func _hide_ability_bar():
	"""Hide and clear the ability bar"""
	if ability_bar:
		ability_bar.clear()

func _on_ability_selected(skill_index: int):
	"""Handle ability selection from AbilityBar - RULE 4: UI signals"""
	if not current_active_unit:
		print("BattleScreen: No active unit for ability selection")
		return

	if not battle_coordinator or not battle_coordinator.is_in_battle():
		print("BattleScreen: No active battle for ability execution")
		return

	print("BattleScreen: Ability selected - index: ", skill_index, " by ", current_active_unit.display_name)

	# Get the skill from the active unit
	if skill_index >= current_active_unit.skills.size():
		print("BattleScreen: Invalid skill index: ", skill_index)
		return

	var skill = current_active_unit.skills[skill_index]
	print("BattleScreen: Selected skill: ", skill.name)

	# Update action label to show selected skill
	if action_label:
		action_label.text = "%s uses %s!" % [current_active_unit.display_name, skill.name]

	# Find targets for the skill
	var targets = _find_skill_targets(skill)
	if targets.is_empty():
		print("BattleScreen: No valid targets for skill")
		if action_label:
			action_label.text = "No valid targets!"
		return

	# Create the battle action
	var action = BattleAction.create_skill_action(current_active_unit, skill, targets)

	# Execute the action through BattleCoordinator
	var success = battle_coordinator.execute_action(action)
	if success:
		print("BattleScreen: Action executed successfully")
		# Hide ability bar after action (will show again on next player turn)
		_hide_ability_bar()
	else:
		print("BattleScreen: Action execution failed")
		if action_label:
			action_label.text = "Action failed!"

func _find_skill_targets(skill: Skill) -> Array:
	"""Find appropriate targets for a skill based on its targeting type"""
	if not battle_coordinator or not battle_coordinator.battle_state:
		return []

	var battle_state = battle_coordinator.battle_state
	var potential_targets: Array = []

	# Determine target pool based on skill target type
	if skill.targets_enemies:
		potential_targets = battle_state.get_living_enemy_units()
	else:
		potential_targets = battle_state.get_living_player_units()

	if potential_targets.is_empty():
		return []

	# Get target count (99 usually means "all")
	var target_count = skill.target_count if skill.target_count < 99 else potential_targets.size()

	# For single target skills, pick lowest HP target (simple AI)
	if target_count == 1:
		potential_targets.sort_custom(func(a, b): return a.current_hp < b.current_hp)
		return [potential_targets[0]]

	# For multi-target skills, return up to target_count
	return potential_targets.slice(0, min(target_count, potential_targets.size()))

func _on_action_executed(action: BattleAction, result):
	"""Handle action execution - update UI with results"""
	print("BattleScreen: Action executed - ", action.get_description())

	# Update all unit cards to reflect HP/status changes
	_update_all_unit_cards()

	# Show damage numbers for each damage result
	if result.damage_results:
		for i in range(result.damage_results.size()):
			var damage_result = result.damage_results[i]
			var target = action.targets[i] if i < action.targets.size() else null
			if target:
				_show_damage_number(target, damage_result)

	# Update ability bar cooldowns
	if ability_bar and current_active_unit:
		ability_bar.update_cooldowns()

func _show_damage_number(target: BattleUnit, damage_result):
	"""Display a floating damage number above the target unit"""
	# Find the card for this target
	var card = _get_unit_card(target)
	if not card:
		return

	# Create damage number label
	var damage_label = Label.new()
	damage_label.text = str(damage_result.total)

	# Style based on damage type
	if damage_result.is_critical:
		damage_label.add_theme_font_size_override("font_size", 24)
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))  # Gold for crit
		damage_label.text += "!"
	elif damage_result.is_glancing:
		damage_label.add_theme_font_size_override("font_size", 14)
		damage_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))  # Gray for glancing
	else:
		damage_label.add_theme_font_size_override("font_size", 18)
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))  # Red for normal

	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Position above the card
	damage_label.position = Vector2(
		card.global_position.x + card.size.x / 2 - 20,
		card.global_position.y - 10
	)

	# Add to scene tree (at root level for proper positioning)
	get_tree().current_scene.add_child(damage_label)

	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 50, 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.chain().tween_callback(damage_label.queue_free)

# =============================================================================
# TURN ORDER BAR MANAGEMENT
# =============================================================================

func _update_turn_order_bar(active_unit: BattleUnit):
	"""Update the turn order bar with predicted turn order"""
	if not turn_order_bar or not battle_coordinator:
		return

	if not battle_coordinator.turn_manager:
		return

	# Get turn order preview from TurnManager
	var turn_order = battle_coordinator.turn_manager.get_turn_order_preview(10)

	# Update the turn order bar
	turn_order_bar.update_turn_order(turn_order, active_unit)
	print("BattleScreen: Updated turn order bar with ", turn_order.size(), " upcoming turns")

func _clear_turn_order_bar():
	"""Clear the turn order bar"""
	if turn_order_bar:
		turn_order_bar.clear()

# =============================================================================
# BATTLE RESULT OVERLAY MANAGEMENT
# =============================================================================

func _create_battle_result_overlay():
	"""Create the battle result overlay (hidden by default)"""
	battle_result_overlay = BattleResultOverlayScene.instantiate()
	add_child(battle_result_overlay)

	# Connect signals for navigation
	battle_result_overlay.return_to_map_pressed.connect(_on_return_to_map_pressed)
	battle_result_overlay.continue_pressed.connect(_on_continue_pressed)

	print("BattleScreen: Battle result overlay created")

func _show_battle_result_overlay(result: BattleResult):
	"""Show the battle result overlay with rewards"""
	if not battle_result_overlay:
		_create_battle_result_overlay()

	# Show the overlay with the result
	battle_result_overlay.show_result(result)
	print("BattleScreen: Showing battle result overlay")

func _hide_battle_result_overlay():
	"""Hide the battle result overlay"""
	if battle_result_overlay:
		battle_result_overlay.hide_result()

func _on_return_to_map_pressed():
	"""Handle return to map button - navigate back to hex territory"""
	print("BattleScreen: Return to map pressed")

	# Hide the overlay
	_hide_battle_result_overlay()

	# Navigate back using ScreenManager
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# Navigate to hex_territory screen (the map)
		screen_manager.change_screen("hex_territory")
		print("BattleScreen: Navigated to hex_territory")
	else:
		# Fallback to emitting back_pressed signal
		print("BattleScreen: No ScreenManager, emitting back_pressed")
		back_pressed.emit()

func _on_continue_pressed():
	"""Handle continue button - for multi-stage battles or replaying"""
	print("BattleScreen: Continue pressed")
	_hide_battle_result_overlay()
