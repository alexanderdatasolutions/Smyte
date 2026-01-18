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
const WaveRewardEffectScene = preload("res://scenes/ui/battle/WaveRewardEffect.tscn")

# UI Components (following RULE 2: Single responsibility)
@onready var back_button = $MainContainer/BottomContainer/ButtonContainer/BackButton
@onready var battle_title_label = $MainContainer/HeaderContainer/BattleTitleLabel
@onready var action_label = $MainContainer/BattleArenaContainer/BattleCenter/ActionDisplay/ActionLabel
@onready var battle_status_label = $MainContainer/BottomContainer/BattleStatusLabel
@onready var player_team_container = $MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer
@onready var enemy_team_container = $MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer
@onready var wave_indicator = $MainContainer/BattleArenaContainer/BattleCenter/WaveIndicator
@onready var turn_indicator = $MainContainer/BattleArenaContainer/BattleCenter/TurnIndicator
@onready var ability_bar = $MainContainer/BottomContainer/AbilityBarContainer/AbilityBar
@onready var turn_order_bar = $MainContainer/HeaderContainer/TurnOrderContainer/TurnOrderBar
@onready var skill_details_panel = $SkillDetailsOverlay
@onready var skill_name_label = $SkillDetailsOverlay/MarginContainer/VBoxContainer/SkillNameLabel
@onready var skill_desc_label = $SkillDetailsOverlay/MarginContainer/VBoxContainer/SkillDescLabel
@onready var wave_transition_overlay = $WaveTransitionOverlay
@onready var wave_transition_label = $WaveTransitionOverlay/WaveTransitionLabel

# Signal for screen navigation (RULE 4: UI signals)
signal back_pressed

# Battle state tracking
var battle_coordinator = null

# Unit card tracking for turn highlighting
var player_unit_cards: Dictionary = {}  # BattleUnit -> BattleUnitCard
var enemy_unit_cards: Dictionary = {}   # BattleUnit -> BattleUnitCard
var current_active_unit: BattleUnit = null

# Skill selection state (mobile two-tap flow)
var selected_skill: Skill = null
var selected_skill_index: int = -1

# Battle result overlay
var battle_result_overlay = null  # BattleResultOverlay instance

# Wave reward particle effect
var wave_reward_effect = null  # WaveRewardEffect instance

func _ready():
	# Connect visibility changed to clean up when screen is hidden
	visibility_changed.connect(_on_visibility_changed)

	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Connect ability bar signal (RULE 4: UI signals)
	if ability_bar:
		ability_bar.ability_selected.connect(_on_ability_selected)
		ability_bar.hide()  # Hidden by default until player's turn

	# Create battle result overlay (hidden by default)
	_create_battle_result_overlay()

	# Create wave reward effect (hidden by default)
	_create_wave_reward_effect()

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

		# Connect to wave signals for wave indicator and transitions
		if battle_coordinator.wave_manager:
			if not battle_coordinator.wave_manager.wave_started.is_connected(_on_wave_started):
				battle_coordinator.wave_manager.wave_started.connect(_on_wave_started)
			if not battle_coordinator.wave_manager.wave_completed.is_connected(_on_wave_completed):
				battle_coordinator.wave_manager.wave_completed.connect(_on_wave_completed)

		# Check if there's already an active battle
		if battle_coordinator.has_method("is_in_battle") and battle_coordinator.is_in_battle():
			# Battle already active, populate UI
			_populate_battle_ui()
		else:
			_show_no_battle_state()
	else:
		_show_no_battle_state()

func _notification(what: int) -> void:
	"""Handle notifications including visibility changes"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# Clean up stale battle result overlay when screen becomes visible
		if visible and battle_result_overlay and battle_result_overlay.visible:
			_hide_battle_result_overlay()
			print("BattleScreen: Became visible with stale overlay, cleaned up")
		elif not visible and battle_result_overlay:
			_hide_battle_result_overlay()
			print("BattleScreen: Became hidden, cleaned up overlay")

func _on_visibility_changed():
	"""Handle visibility change - clean up battle result overlay when screen is hidden OR shown"""
	if not visible and battle_result_overlay:
		# Screen is being hidden, hide the battle result overlay
		_hide_battle_result_overlay()
		print("BattleScreen: Screen hidden, cleaned up battle result overlay")
	elif visible and battle_result_overlay and battle_result_overlay.visible:
		# Screen is being shown but battle result overlay is still visible from previous battle
		# This happens when user navigates back to battle screen after returning to map
		# Hide it to prevent showing stale results
		_hide_battle_result_overlay()
		print("BattleScreen: Screen shown with stale overlay, cleaned up")

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	# Hide battle result overlay if it's showing (prevents it from reappearing when returning to this screen)
	if battle_result_overlay and battle_result_overlay.visible:
		_hide_battle_result_overlay()
		print("BattleScreen: Back pressed, cleaned up battle result overlay")

	back_pressed.emit()

func start_battle(battle_config):
	"""Start a battle with given configuration - RULE 5: SystemRegistry"""
	# Battle coordinator already stored in _ready
	if battle_coordinator:
		battle_coordinator.start_battle(battle_config)

func _on_battle_started(config):
	"""Handle battle start event - populate UI with units"""
	print("BattleScreen: Battle started, populating UI")
	_populate_battle_ui()

	# Initialize wave indicator for wave-based battles
	_initialize_wave_indicator(config)

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

	# Hide wave indicator when battle ends
	_hide_wave_indicator()

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
	print("BattleScreen: Creating unit card for: ", unit.display_name)
	var unit_card = BattleUnitCardScene.instantiate()
	print("BattleScreen: Unit card instantiated, calling setup_unit...")
	# CardStyle is an enum in the class, not instance - use BattleUnitCard.CardStyle
	unit_card.setup_unit(unit, BattleUnitCard.CardStyle.NORMAL)
	print("BattleScreen: Unit card setup complete")
	return unit_card

func _on_unit_card_clicked(unit: BattleUnit):
	"""Handle unit card click for targeting - RULE 4: UI signals"""
	_on_unit_clicked(unit)

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
	# Hide wave indicator when no battle
	_hide_wave_indicator()

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
	"""Handle ability selection from AbilityBar - Mobile two-tap flow: select skill, then tap target"""
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
	print("BattleScreen: Skill selected for targeting: ", skill.name)

	# Store selected skill
	selected_skill = skill
	selected_skill_index = skill_index

	# Update action label to instruct user to tap target
	if action_label:
		var target_type = "enemy" if skill.targets_enemies else "ally"
		action_label.text = "Tap %s to use %s" % [target_type, skill.name]

	# Highlight ability button to show it's selected
	if ability_bar:
		ability_bar.highlight_skill(skill_index, true)

	# Show skill details panel
	_show_skill_details(skill)

	# Highlight valid targets
	_highlight_valid_targets(skill)

func _highlight_valid_targets(skill: Skill):
	"""Highlight units that can be targeted by the selected skill"""
	if not battle_coordinator or not battle_coordinator.battle_state:
		return

	var battle_state = battle_coordinator.battle_state

	# Get valid target pool
	var valid_targets: Array = []
	if skill.targets_enemies:
		valid_targets = battle_state.get_living_enemy_units()
	else:
		valid_targets = battle_state.get_living_player_units()

	# Highlight valid targets with TARGETED style
	for unit in valid_targets:
		var card = _get_unit_card(unit)
		if card:
			card.set_targeted(true)

func _on_unit_clicked(unit: BattleUnit):
	"""Handle unit card click - execute selected skill on this target"""
	print("BattleScreen: Unit clicked - ", unit.display_name)

	# If no skill selected, ignore click
	if not selected_skill:
		return

	# Check if this is a valid target
	if not _is_valid_target(unit, selected_skill):
		print("BattleScreen: Invalid target for skill")
		if action_label:
			action_label.text = "Invalid target!"
		return

	# Execute the skill on this target
	_execute_skill_on_target(selected_skill, unit)

	# Clear selection
	selected_skill = null
	selected_skill_index = -1

	# Hide skill details panel
	_hide_skill_details()

	# Clear target highlighting
	_clear_target_highlighting()

func _is_valid_target(unit: BattleUnit, skill: Skill) -> bool:
	"""Check if unit is a valid target for the skill"""
	if not unit.is_alive:
		return false

	# Check if targeting enemies and this is an enemy
	if skill.targets_enemies and unit.is_enemy():
		return true

	# Check if targeting allies and this is a player unit
	if not skill.targets_enemies and not unit.is_enemy():
		return true

	return false

func _execute_skill_on_target(skill: Skill, target: BattleUnit):
	"""Execute the selected skill on the target"""
	if not current_active_unit or not battle_coordinator:
		return

	print("BattleScreen: Executing %s on %s" % [skill.name, target.display_name])

	# Update action label
	if action_label:
		action_label.text = "%s uses %s on %s!" % [current_active_unit.display_name, skill.name, target.display_name]

	# Create target array based on skill
	var targets: Array = []
	if skill.target_count >= 99:
		# AoE skill - get all valid targets
		var battle_state = battle_coordinator.battle_state
		if skill.targets_enemies:
			targets = battle_state.get_living_enemy_units()
		else:
			targets = battle_state.get_living_player_units()
	else:
		# Single or multi-target - for now just use the clicked target
		targets = [target]

	# Create and execute action
	var action = BattleAction.create_skill_action(current_active_unit, skill, targets)
	var success = battle_coordinator.execute_action(action)

	if success:
		print("BattleScreen: Action executed successfully")
	else:
		print("BattleScreen: Action execution failed")
		if action_label:
			action_label.text = "Action failed!"

func _show_skill_details(skill: Skill):
	"""Show the skill details panel with skill information"""
	if not skill_details_panel or not skill_name_label or not skill_desc_label:
		return

	# Set skill name
	skill_name_label.text = skill.name

	# Build skill description with damage/effects info
	var description = skill.description if skill.description else "No description available"

	# Add damage multiplier info
	if skill.damage_multiplier > 0:
		description += "\n• Damage: %d%% ATK" % int(skill.damage_multiplier * 100)

	# Add target info
	if skill.target_count >= 99:
		description += "\n• Target: All %s" % ("enemies" if skill.targets_enemies else "allies")
	elif skill.target_count > 1:
		description += "\n• Target: %d %s" % [skill.target_count, "enemies" if skill.targets_enemies else "allies"]
	else:
		description += "\n• Target: Single %s" % ("enemy" if skill.targets_enemies else "ally")

	# Add cooldown
	if skill.cooldown > 0:
		description += "\n• Cooldown: %d turns" % skill.cooldown

	skill_desc_label.text = description

	# Show the panel
	skill_details_panel.visible = true
	skill_details_panel.z_index = 100  # Force to top

func _hide_skill_details():
	"""Hide the skill details panel"""
	if skill_details_panel:
		skill_details_panel.visible = false

func _clear_target_highlighting():
	"""Remove TARGETED styling from all units"""
	for card in player_unit_cards.values():
		if card and is_instance_valid(card):
			card.set_targeted(false)
	for card in enemy_unit_cards.values():
		if card and is_instance_valid(card):
			card.set_targeted(false)

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
	"""Handle return to map button - always navigate to WorldView (home)"""
	print("BattleScreen: Return to map pressed - navigating to WorldView")

	# Hide the overlay
	_hide_battle_result_overlay()

	# Navigate to WorldView (home) instead of going back
	# This ensures players always return to home after battle, not DungeonScreen
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("WorldView")
		print("BattleScreen: Navigated to WorldView")
	else:
		# Fallback to back_pressed if ScreenManager not available
		back_pressed.emit()
		print("BattleScreen: ScreenManager not found, falling back to back_pressed")

func _on_continue_pressed():
	"""Handle continue button - for multi-stage battles or replaying"""
	print("BattleScreen: Continue pressed")
	_hide_battle_result_overlay()

# =============================================================================
# WAVE INDICATOR MANAGEMENT
# =============================================================================

func _initialize_wave_indicator(config):
	"""Initialize wave indicator based on battle configuration"""
	if not wave_indicator:
		return

	# Check if this is a wave-based battle (dungeon) or non-wave battle (arena)
	var has_waves = config.enemy_waves.size() > 1

	if has_waves:
		# Show wave indicator for wave-based battles
		var total_waves = config.enemy_waves.size()
		_update_wave_indicator(1, total_waves)
		wave_indicator.visible = true
		print("BattleScreen: Wave indicator initialized - 1/%d waves" % total_waves)
	else:
		# Hide for non-wave battles (arena, single wave)
		wave_indicator.visible = false
		print("BattleScreen: Wave indicator hidden (non-wave battle)")

func _update_wave_indicator(current_wave: int, total_waves: int):
	"""Update wave indicator display"""
	if wave_indicator:
		wave_indicator.text = "Wave %d/%d" % [current_wave, total_waves]

func _on_wave_started(wave_number: int):
	"""Handle wave started signal - update wave indicator and refresh enemy cards"""
	print("BattleScreen: Wave %d started" % wave_number)

	# Update wave indicator
	if wave_indicator and wave_indicator.visible:
		if battle_coordinator and battle_coordinator.wave_manager:
			var total_waves = battle_coordinator.wave_manager.get_wave_count()
			_update_wave_indicator(wave_number, total_waves)
			print("BattleScreen: Wave indicator updated to %d/%d" % [wave_number, total_waves])

	# Refresh enemy unit cards for new wave (wave 2+)
	if wave_number > 1:
		_refresh_enemy_cards_with_animation()

func _hide_wave_indicator():
	"""Hide the wave indicator"""
	if wave_indicator:
		wave_indicator.visible = false

# =============================================================================
# WAVE TRANSITION ANIMATION
# =============================================================================

func _on_wave_completed(wave_number: int):
	"""Handle wave completed signal - show celebratory transition and particle effects"""
	if not wave_transition_overlay or not wave_transition_label:
		return

	# Get total waves from wave manager
	var total_waves = 0
	if battle_coordinator and battle_coordinator.wave_manager:
		total_waves = battle_coordinator.wave_manager.get_wave_count()

	# Don't show transition after final wave (victory screen will show instead)
	if wave_number >= total_waves:
		print("BattleScreen: Final wave completed, skipping transition (victory will show)")
		return

	print("BattleScreen: Wave %d completed, showing transition animation" % wave_number)
	_show_wave_transition(wave_number, total_waves)

	# Trigger wave reward particle effect
	_trigger_wave_reward_particles()

func _show_wave_transition(completed_wave: int, _total_waves: int):
	"""Display wave transition overlay with animation"""
	if not wave_transition_overlay or not wave_transition_label:
		return

	# Set transition text
	wave_transition_label.text = "Wave %d Complete!" % completed_wave

	# Reset overlay state for animation
	wave_transition_overlay.modulate = Color(1, 1, 1, 0)
	wave_transition_label.modulate = Color(1, 1, 1, 0)
	wave_transition_label.scale = Vector2(0.5, 0.5)
	wave_transition_label.pivot_offset = wave_transition_label.size / 2
	wave_transition_overlay.visible = true

	# Animate in: fade overlay, scale up text
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade in overlay
	tween.tween_property(wave_transition_overlay, "modulate:a", 1.0, 0.3)

	# Scale up and fade in text
	tween.tween_property(wave_transition_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(wave_transition_label, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hold for a moment, then fade out
	tween.chain()
	tween.tween_interval(0.8)

	# Fade out
	tween.set_parallel(true)
	tween.tween_property(wave_transition_overlay, "modulate:a", 0.0, 0.4)
	tween.tween_property(wave_transition_label, "modulate:a", 0.0, 0.3)

	# Hide overlay when done
	tween.chain()
	tween.tween_callback(_hide_wave_transition)

	print("BattleScreen: Wave transition animation started")

func _hide_wave_transition():
	"""Hide the wave transition overlay"""
	if wave_transition_overlay:
		wave_transition_overlay.visible = false
	print("BattleScreen: Wave transition animation completed")

func _refresh_enemy_cards_with_animation():
	"""Refresh enemy unit cards with fade-in animation for new wave"""
	if not battle_coordinator or not battle_coordinator.battle_state:
		return

	# Clear old enemy cards
	_clear_container(enemy_team_container)
	enemy_unit_cards.clear()

	# Get new enemy units from battle state
	var enemy_units = battle_coordinator.battle_state.get_enemy_units()
	print("BattleScreen: Refreshing enemy cards for new wave - %d enemies" % enemy_units.size())

	# Create new enemy cards with animation
	for i in range(enemy_units.size()):
		var unit = enemy_units[i]
		var unit_card = _create_battle_unit_card(unit)
		enemy_team_container.add_child(unit_card)
		enemy_unit_cards[unit] = unit_card

		# Connect click signal for targeting
		unit_card.unit_clicked.connect(_on_unit_card_clicked)

		# Start invisible for animation
		unit_card.modulate = Color(1, 1, 1, 0)
		unit_card.position.x += 50  # Start offset to the right

		# Animate in with staggered delay
		var tween = create_tween()
		tween.set_parallel(true)
		var delay = i * 0.1  # Stagger each card by 0.1s
		tween.tween_property(unit_card, "modulate:a", 1.0, 0.3).set_delay(delay)
		tween.tween_property(unit_card, "position:x", unit_card.position.x - 50, 0.3).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	print("BattleScreen: Enemy cards refreshed with fade-in animation")

# =============================================================================
# WAVE REWARD PARTICLE EFFECTS
# =============================================================================

func _create_wave_reward_effect():
	"""Create the wave reward particle effect (hidden by default)"""
	wave_reward_effect = WaveRewardEffectScene.instantiate()
	add_child(wave_reward_effect)
	print("BattleScreen: Wave reward effect created")

func _trigger_wave_reward_particles():
	"""Trigger wave reward particle effect - particles fly toward resource display"""
	if not wave_reward_effect:
		return

	# Calculate spawn position (center of battle area)
	var spawn_pos = size / 2.0

	# Calculate target position (top-right where resource display is)
	# ResourceDisplay is positioned at offset_left: 453, offset_top: 3 in MainUIOverlay
	# We target the mana and crystal icon positions
	var mana_target = Vector2(size.x - 350, 20)  # Approximate mana icon position

	# Play particles flying toward resource display
	wave_reward_effect.play_wave_reward(spawn_pos, mana_target, 5, 3)
	print("BattleScreen: Wave reward particles triggered from %s to %s" % [spawn_pos, mana_target])
