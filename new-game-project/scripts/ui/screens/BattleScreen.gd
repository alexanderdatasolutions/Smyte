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
@onready var back_button = $BottomContainer/ButtonContainer/BackButton
@onready var auto_button = $BottomContainer/ButtonContainer/AutoButton
@onready var battle_title_label = $MainContainer/HeaderContainer/BattleTitleLabel
@onready var action_label = $MainContainer/BattleArenaContainer/BattleCenter/ActionDisplay/ActionLabel
@onready var player_team_container = $MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer
@onready var enemy_team_container = $MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer
@onready var wave_indicator = $MainContainer/BattleArenaContainer/BattleCenter/WaveIndicator
@onready var turn_indicator = $MainContainer/BattleArenaContainer/BattleCenter/TurnIndicator
@onready var ability_bar = $BottomContainer/AbilityBarContainer/AbilityBar
@onready var turn_order_bar = $BottomContainer/TurnOrderContainer/TurnOrderBar
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

# Auto battle state
var auto_battle_enabled: bool = false

# Battle result overlay
var battle_result_overlay = null  # BattleResultOverlay instance

# Wave reward particle effect
var wave_reward_effect = null  # WaveRewardEffect instance

# Battle log for combat event tracking
var battle_log: BattleLog = null

func _ready():
	# Connect back button (RULE 4: UI signals) - keep as fallback
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.visible = false  # Hide old back button, use unified header

	# Connect auto battle button
	if auto_button:
		auto_button.pressed.connect(_on_auto_button_pressed)
		_update_auto_button_text()

	# Connect ability bar signal (RULE 4: UI signals)
	if ability_bar:
		ability_bar.ability_selected.connect(_on_ability_selected)
		ability_bar.hide()  # Hidden by default until player's turn

	# Create battle result overlay (hidden by default)
	_create_battle_result_overlay()

	# Create wave reward effect (hidden by default)
	_create_wave_reward_effect()

	# Create battle log (collapsible combat event log)
	_create_battle_log()

	# CRITICAL: Connect to battle coordinator signals IMMEDIATELY (not deferred)
	# This ensures we don't miss the battle_started signal
	_initialize_battle_connections()

	# Force fullscreen layout (must be deferred for proper sizing)
	call_deferred("_force_fullscreen_layout")

	# Setup unified header
	_setup_unified_header()

	# Connect visibility changed to clean up when screen is hidden
	visibility_changed.connect(_on_visibility_changed)

func _initialize_battle_connections():
	"""Connect to battle coordinator signals - runs immediately in _ready()"""
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

		# Connect battle log to battle signals
		_connect_battle_log_signals()
	else:
		_show_no_battle_state()

	print("BattleScreen: Battle coordinator connections initialized")

func _force_fullscreen_layout():
	"""Force all layout elements to fill the viewport - runs deferred for proper sizing"""
	var viewport_size = get_viewport().get_visible_rect().size
	print("BattleScreen: Forcing fullscreen layout to ", viewport_size)

	# Force this control to fill viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = viewport_size

	# Force Background to fill viewport
	var background = get_node_or_null("Background")
	if background:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.size = viewport_size

	# Force MainContainer to fill viewport
	var main_container = get_node_or_null("MainContainer")
	if main_container:
		main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		main_container.size = viewport_size

func _setup_unified_header():
	"""Configure the unified header for this screen"""
	if not visibility_changed.is_connected(_on_header_visibility_changed):
		visibility_changed.connect(_on_header_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_header_visibility_changed():
	"""Update header when this screen becomes visible"""
	if visible:
		_update_header_for_screen()

func _update_header_for_screen():
	"""Apply this screen's header settings"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("BATTLE")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

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

	# Clear and reconnect battle log for new battle
	if battle_log:
		battle_log.clear_log()
	_connect_battle_log_signals()

	# Re-sync auto battle state if it was enabled (e.g., for tower multi-floor)
	if auto_battle_enabled and battle_coordinator:
		print("BattleScreen: Re-enabling auto battle for new battle")
		battle_coordinator.set_auto_battle(true)

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

	# Reset auto battle on victory
	if result.victory:
		auto_battle_enabled = false
		_update_auto_button_text()
		if battle_coordinator:
			battle_coordinator.set_auto_battle(false)
		print("BattleScreen: Auto battle reset after victory")

	# Skip showing result overlay for Tower battles - TowerScreen handles the flow
	if result.battle_type.to_lower() == "tower":
		print("BattleScreen: Tower battle - skipping result overlay (TowerScreen handles flow)")
		return

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

	# Create target array based on skill (must be typed for BattleAction)
	var targets: Array[BattleUnit] = []
	if skill.target_count >= 99:
		# AoE skill - get all valid targets
		var battle_state = battle_coordinator.battle_state
		if skill.targets_enemies:
			for unit: BattleUnit in battle_state.get_living_enemy_units():
				targets.append(unit)
		else:
			for unit: BattleUnit in battle_state.get_living_player_units():
				targets.append(unit)
	else:
		# Single or multi-target - for now just use the clicked target
		targets.append(target)

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

	# Log action to battle log
	_log_action_to_battle_log(action, result)

func _show_damage_number(target: BattleUnit, damage_result):
	"""Display a floating damage number above the target unit with hover tooltip"""
	# Find the card for this target
	var card = _get_unit_card(target)
	if not card:
		return

	# Create a container for the damage number that handles mouse events
	var damage_container = Control.new()
	damage_container.mouse_filter = Control.MOUSE_FILTER_STOP
	damage_container.custom_minimum_size = Vector2(100, 40)

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
	damage_container.add_child(damage_label)

	# Position above the card
	damage_container.position = Vector2(
		card.global_position.x + card.size.x / 2 - 50,
		card.global_position.y - 20
	)

	# Create tooltip panel (hidden by default)
	var tooltip = _create_damage_tooltip(damage_result)
	tooltip.visible = false
	damage_container.add_child(tooltip)

	# Connect mouse events for tooltip
	damage_container.mouse_entered.connect(func(): tooltip.visible = true)
	damage_container.mouse_exited.connect(func(): tooltip.visible = false)

	# Add to scene tree (at root level for proper positioning)
	get_tree().current_scene.add_child(damage_container)

	# Animate: float up and fade out (longer duration for hover viewing)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_container, "position:y", damage_container.position.y - 60, 2.0)
	tween.tween_property(damage_container, "modulate:a", 0.0, 1.5).set_delay(1.0)
	tween.chain().tween_callback(damage_container.queue_free)

func _create_damage_tooltip(damage_result) -> PanelContainer:
	"""Create a tooltip panel showing damage calculation breakdown"""
	var panel = PanelContainer.new()
	panel.z_index = 200

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)

	# Get the calculation breakdown
	var breakdown_text = damage_result.get_calculation_breakdown()
	var lines = breakdown_text.split("\n")

	for line in lines:
		var label = Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 10)

		# Style header lines differently
		if line.contains("→") or line.contains("Final:"):
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
			label.add_theme_font_size_override("font_size", 11)
		elif line.contains("ATK") or line.contains("DEF") or line.contains("Mult"):
			label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		else:
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

		content.add_child(label)

	# Position tooltip to the right of the damage number
	panel.position = Vector2(60, -20)

	return panel

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
	"""Handle return to map button - navigate based on battle type"""
	# Get the battle type from the result overlay
	var return_screen = "WorldView"  # Default

	if battle_result_overlay and battle_result_overlay.battle_result:
		var battle_type = battle_result_overlay.battle_result.battle_type
		print("BattleScreen: Return to map pressed - battle_type: ", battle_type)

		# Navigate to appropriate screen based on battle origin
		match battle_type.to_upper():
			"TERRITORY":
				return_screen = "hex_territory"
			"DUNGEON":
				return_screen = "dungeon"
			_:
				return_screen = "WorldView"

	print("BattleScreen: Navigating to ", return_screen)

	# Hide the overlay
	_hide_battle_result_overlay()

	# Navigate to the appropriate screen
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen(return_screen)
		print("BattleScreen: Navigated to ", return_screen)
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

	# Check for tower battles - show floor number
	if config.battle_type == BattleConfig.BattleType.TOWER:
		var floor_num = config.get_meta("tower_floor", 1) if config.has_meta("tower_floor") else 1
		var is_boss = config.get_meta("is_boss_floor", false) if config.has_meta("is_boss_floor") else false
		if is_boss:
			wave_indicator.text = "BOSS Floor %d" % floor_num
		else:
			wave_indicator.text = "Floor %d" % floor_num
		wave_indicator.visible = true
		print("BattleScreen: Floor indicator initialized - Floor %d (boss: %s)" % [floor_num, is_boss])
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

# =============================================================================
# BATTLE LOG MANAGEMENT
# =============================================================================

func _create_battle_log():
	"""Create the battle log component at the bottom of the battle area"""
	battle_log = BattleLog.new()
	battle_log.name = "BattleLog"

	# Add to BottomContainer, before the TurnOrderContainer
	var bottom_container = get_node_or_null("BottomContainer")
	if bottom_container:
		bottom_container.add_child(battle_log)
		# Move it to be first (above turn order bar)
		bottom_container.move_child(battle_log, 0)
		# Set size flags for proper layout in VBoxContainer
		battle_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# Fallback: add to self with explicit positioning
		add_child(battle_log)
		battle_log.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		battle_log.offset_top = -150
		battle_log.offset_bottom = -30

	print("BattleScreen: Battle log created")

func _connect_battle_log_signals():
	"""Connect battle log to battle system signals"""
	if not battle_log or not battle_coordinator:
		return

	# Connect to turn manager for turn events
	if battle_coordinator.turn_manager:
		if not battle_coordinator.turn_manager.turn_started.is_connected(_on_battle_log_turn_started):
			battle_coordinator.turn_manager.turn_started.connect(_on_battle_log_turn_started)

	# Connect to wave manager for wave events
	if battle_coordinator.wave_manager:
		if not battle_coordinator.wave_manager.wave_started.is_connected(_on_battle_log_wave_started):
			battle_coordinator.wave_manager.wave_started.connect(_on_battle_log_wave_started)

	# Connect to battle coordinator for general log messages
	if not battle_coordinator.battle_log_message.is_connected(_on_battle_log_message):
		battle_coordinator.battle_log_message.connect(_on_battle_log_message)

	# Connect to battle ended for victory/defeat
	if not battle_coordinator.battle_ended.is_connected(_on_battle_log_ended):
		battle_coordinator.battle_ended.connect(_on_battle_log_ended)

	print("BattleScreen: Battle log signals connected")

func _on_battle_log_turn_started(unit: BattleUnit):
	"""Log turn start event"""
	if battle_log and unit:
		battle_log.add_turn_start(unit.display_name, not unit.is_enemy())

		# Check if unit cannot act (stunned, frozen, etc.)
		if not unit.can_act():
			var reason = unit.get_action_prevention_reason()
			battle_log.add_action_skipped(unit.display_name, reason)

func _on_battle_log_wave_started(wave_number: int):
	"""Log wave start event"""
	if battle_log and battle_coordinator and battle_coordinator.wave_manager:
		var total_waves = battle_coordinator.wave_manager.get_wave_count()
		battle_log.add_wave_start(wave_number, total_waves)

func _on_battle_log_message(message: String):
	"""Log general battle message"""
	if battle_log:
		# Parse message to determine color/type
		battle_log._add_entry(message, Color(0.8, 0.8, 0.8))

func _on_battle_log_ended(result: BattleResult):
	"""Log battle end"""
	if battle_log:
		battle_log.add_battle_end(result.victory)

func _log_action_to_battle_log(action: BattleAction, result):
	"""Log action execution details to battle log"""
	if not battle_log:
		return

	var caster = action.caster

	# Log the skill/attack use
	if action.action_type == BattleAction.ActionType.SKILL:
		battle_log.add_skill_use(caster.display_name, action.skill.name)

	# Log damage to each target
	for i in range(result.damage_results.size()):
		var damage_result = result.damage_results[i]
		var target = action.targets[i] if i < action.targets.size() else null
		if target:
			if action.action_type == BattleAction.ActionType.ATTACK:
				battle_log.add_attack(
					caster.display_name,
					target.display_name,
					damage_result.total,
					damage_result.is_critical,
					damage_result.is_glancing,
					damage_result  # Pass full damage result for hover tooltip
				)
			else:
				battle_log.add_skill_damage(
					target.display_name,
					damage_result.total,
					damage_result.is_critical,
					damage_result.is_glancing,
					damage_result  # Pass full damage result for hover tooltip
				)

			# Check if target was defeated
			if not target.is_alive:
				battle_log.add_unit_defeated(target.display_name)

	# Log status effects applied
	for status_effect in result.status_effects_applied:
		var target_name = status_effect.target_name if status_effect.target_name else "target"
		battle_log.add_status_applied(target_name, status_effect.name, status_effect.duration)

# =============================================================================
# AUTO BATTLE CONTROLS
# =============================================================================

func _on_auto_button_pressed():
	"""Handle auto battle button press - toggle auto battle mode"""
	auto_battle_enabled = not auto_battle_enabled
	_update_auto_button_text()

	# Send to battle coordinator
	if battle_coordinator:
		battle_coordinator.set_auto_battle(auto_battle_enabled)
		print("BattleScreen: Auto battle toggled to ", auto_battle_enabled)

func _update_auto_button_text():
	"""Update auto button text based on state"""
	if auto_button:
		auto_button.text = "AUTO: ON" if auto_battle_enabled else "AUTO: OFF"
