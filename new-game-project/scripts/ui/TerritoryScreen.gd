# scripts/ui/TerritoryScreen.gd - Detailed territory management with stage system
extends Control

signal back_pressed

# Preload DataLoader for JSON data access
const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

@onready var territory_list = $ScrollContainer/TerritoryList
@onready var back_button = $BackButton

# Currently selected territory for god assignment
var current_territory: Territory
var selected_gods: Array = []
var god_assignment_popup: PopupPanel
var popup_territory_info: Label
var popup_god_list: VBoxContainer

# Team selection for battles
var battle_team_popup: PopupPanel
var battle_territory_info: Label
var battle_god_list: VBoxContainer
var selected_battle_gods: Array = []
var current_battle_territory: Territory
var current_battle_stage: int = 1

func _ready():
	# Connect to GameManager signals for modular communication
	if GameManager:
		GameManager.territory_captured.connect(_on_territory_captured)
		# Connect to resources updated for real-time updates
		GameManager.resources_updated.connect(refresh_territories)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Create the popup dynamically
	create_god_assignment_popup()
	create_battle_team_popup()
		
	refresh_territories()

func create_god_assignment_popup():
	# Create popup panel
	god_assignment_popup = PopupPanel.new()
	god_assignment_popup.position = Vector2(660, 290)  # Center-ish position
	god_assignment_popup.size = Vector2(600, 500)
	add_child(god_assignment_popup)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	god_assignment_popup.add_child(margin)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Assign Gods to Territory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title)
	
	# Territory info
	popup_territory_info = Label.new()
	popup_territory_info.name = "TerritoryInfo"
	popup_territory_info.text = "Territory: None"
	main_vbox.add_child(popup_territory_info)
	
	# God list scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	popup_god_list = VBoxContainer.new()
	popup_god_list.name = "GodList"
	popup_god_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(popup_god_list)
	
	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(button_hbox)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.pressed.connect(_on_confirm_assignment)
	button_hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_on_cancel_assignment)
	button_hbox.add_child(cancel_btn)

func create_battle_team_popup():
	# Create battle team selection popup
	battle_team_popup = PopupPanel.new()
	
	# Make it responsive to screen size instead of fixed size
	var screen_size = get_viewport().get_visible_rect().size
	var popup_width = min(600, screen_size.x * 0.8)  # 80% of screen width, max 600
	var popup_height = min(500, screen_size.y * 0.8)  # 80% of screen height, max 500
	
	battle_team_popup.size = Vector2(popup_width, popup_height)
	
	# Center the popup instead of fixed position
	battle_team_popup.position = Vector2(
		(screen_size.x - popup_width) / 2,
		(screen_size.y - popup_height) / 2
	)
	
	add_child(battle_team_popup)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	battle_team_popup.add_child(margin)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Select Battle Team"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)  # Slightly smaller
	main_vbox.add_child(title)
	
	# Territory and stage info
	battle_territory_info = Label.new()
	battle_territory_info.name = "BattleTerritoryInfo"
	battle_territory_info.text = "Territory: None - Stage: 0"
	battle_territory_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_territory_info.add_theme_font_size_override("font_size", 14)  # Smaller
	battle_territory_info.modulate = Color.YELLOW
	main_vbox.add_child(battle_territory_info)
	
	# Selected team display - make it smaller
	var selected_team_label = Label.new()
	selected_team_label.text = "Selected Team (0/5):"
	selected_team_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(selected_team_label)
	
	var selected_team_container = VBoxContainer.new()
	selected_team_container.name = "SelectedTeamContainer"
	selected_team_container.custom_minimum_size = Vector2(0, 80)  # Smaller height
	main_vbox.add_child(selected_team_container)
	
	# Available gods scroll
	var scroll_label = Label.new()
	scroll_label.text = "Available Gods:"
	scroll_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(scroll_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)  # Set minimum height for scroll area
	main_vbox.add_child(scroll)
	
	battle_god_list = VBoxContainer.new()
	battle_god_list.name = "BattleGodList"
	battle_god_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(battle_god_list)
	
	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(button_hbox)
	
	var start_battle_btn = Button.new()
	start_battle_btn.text = "Start Battle"
	start_battle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_battle_btn.pressed.connect(_on_start_stage_battle)
	button_hbox.add_child(start_battle_btn)
	
	var cancel_battle_btn = Button.new()
	cancel_battle_btn.text = "Cancel"
	cancel_battle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_battle_btn.pressed.connect(_on_cancel_battle_team_selection)
	button_hbox.add_child(cancel_battle_btn)
func _on_back_pressed():
	back_pressed.emit()

func _on_territory_captured(_territory):
	# When a territory is captured, refresh the display
	refresh_territories()

func refresh_territories():
	print("TerritoryScreen: Starting refresh_territories()")
	
	# Make sure the territory_list exists
	if not territory_list:
		territory_list = $ScrollContainer/TerritoryList
		if not territory_list:
			print("Error: Could not find TerritoryList")
			return
		else:
			print("Found TerritoryList node")
	
	# Clear existing territory cards
	for child in territory_list.get_children():
		child.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Add spacing between cards
	territory_list.add_theme_constant_override("separation", 10)
	
	# Check GameManager
	if not GameManager:
		print("Error: GameManager not found!")
		var error_label = Label.new()
		error_label.text = "ERROR: GameManager not found!"
		error_label.modulate = Color.RED
		territory_list.add_child(error_label)
		return
	
	# Check territories
	if not GameManager.territories:
		print("Error: GameManager.territories is null!")
		var error_label = Label.new()
		error_label.text = "ERROR: GameManager.territories is null!"
		error_label.modulate = Color.RED
		territory_list.add_child(error_label)
		return
	
	print("GameManager.territories size: ", GameManager.territories.size())
	
	# Add territory cards - using GameManager autoload for modular access
	if GameManager.territories.size() > 0:
		for i in range(GameManager.territories.size()):
			var territory = GameManager.territories[i]
			create_detailed_territory_card(territory)
	else:
		# Add a debug label if no territories found
		var debug_label = Label.new()
		debug_label.text = "No territories found. Check GameManager initialization."
		debug_label.modulate = Color.RED
		territory_list.add_child(debug_label)

func create_detailed_territory_card(territory):
	# Create main card panel
	var card_panel = create_nine_patch_panel()
	card_panel.custom_minimum_size = Vector2(0, 120)
	territory_list.add_child(card_panel)
	
	# Main horizontal container
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 80)
	# Add some padding from the panel edges
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	card_panel.add_child(margin)
	margin.add_child(hbox)
	
	# Territory info section (left)
	var info_section = create_territory_info_section(territory)
	hbox.add_child(info_section)
	
	# Production section (center)
	var production_section = create_production_section(territory)
	hbox.add_child(production_section)
	
	# Assignment section (right)
	var assignment_section = create_assignment_section(territory)
	hbox.add_child(assignment_section)
	
	# Action button (far right)
	var action_button = create_territory_action_button(territory)
	hbox.add_child(action_button)

func create_territory_info_section(territory):
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	
	# Territory name and tier
	var name_label = Label.new()
	name_label.text = "%s (Tier %d)" % [territory.name, territory.tier]
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Element
	var element_label = Label.new()
	element_label.text = "Element: %s" % _get_element_name(territory.element)
	vbox.add_child(element_label)
	
	# Power requirement vs player power
	var player_power = _calculate_player_power()
	var power_label = Label.new()
	power_label.text = "Required: %d | Your Power: %d" % [territory.get_required_power(), player_power]
	
	# Color code based on if player can attack
	if player_power >= territory.get_required_power():
		power_label.modulate = Color.GREEN
	else:
		power_label.modulate = Color.RED
	
	vbox.add_child(power_label)
	
	# NEW: Show territory level and upgrades
	var upgrade_info = Label.new()
	upgrade_info.text = "Level: %d | Upgrades: R%d/D%d/Z%d" % [
		territory.territory_level,
		territory.resource_upgrades, 
		territory.defense_upgrades,
		territory.zone_upgrades
	]
	upgrade_info.add_theme_font_size_override("font_size", 10)
	upgrade_info.modulate = Color.CYAN
	vbox.add_child(upgrade_info)
	
	# NEW: Show auto collection status
	if territory.is_controlled_by_player() and territory.is_unlocked:
		var collection_info = Label.new()
		collection_info.text = "Collection: %s" % territory.auto_collection_mode.capitalize()
		collection_info.add_theme_font_size_override("font_size", 10)
		collection_info.modulate = Color.YELLOW
		vbox.add_child(collection_info)
	
	return vbox

func create_production_section(territory):
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(150, 0)
	
	var production_label = Label.new()
	production_label.text = "Production"
	production_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(production_label)
	
	# Show current production rate
	var total_rate = territory.get_resource_rate()
	var rate_label = Label.new()
	rate_label.text = "%d/hour" % total_rate
	rate_label.modulate = Color.YELLOW
	rate_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(rate_label)
	
	# NEW: Show pending resources if any
	if territory.is_controlled_by_player() and territory.is_unlocked:
		var pending_resources = territory.get_pending_resources()
		var total_pending = 0
		for amount in pending_resources.values():
			total_pending += amount
		
		if total_pending > 0:
			var pending_label = Label.new()
			pending_label.text = "Pending: %d" % total_pending
			pending_label.modulate = Color.CYAN
			pending_label.add_theme_font_size_override("font_size", 11)
			vbox.add_child(pending_label)
			
			# Add collection button if manual mode or large amount
			if territory.auto_collection_mode == "manual" or total_pending > 50:
				var collect_btn = Button.new()
				collect_btn.text = "Collect"
				collect_btn.custom_minimum_size = Vector2(80, 25)
				collect_btn.add_theme_font_size_override("font_size", 10)
				collect_btn.pressed.connect(_on_collect_resources.bind(territory))
				vbox.add_child(collect_btn)
	
	# NEW: Show resource breakdown for higher tiers
	if territory.tier >= 2 and territory.is_controlled_by_player():
		var breakdown_label = Label.new()
		var breakdown_text = ""
		if territory.tier == 2:
			breakdown_text = "Gold, Essence, Books"
		elif territory.tier == 3:
			breakdown_text = "Gold, Essence, Books, Stones"
		
		breakdown_label.text = breakdown_text
		breakdown_label.add_theme_font_size_override("font_size", 9)
		breakdown_label.modulate = Color.LIGHT_GRAY
		vbox.add_child(breakdown_label)
	
	# Status with stage information
	var status_label = Label.new()
	if territory.is_controlled_by_player() and territory.is_unlocked:
		status_label.text = "🟢 CONTROLLED"
		status_label.modulate = Color.GREEN
	elif territory.current_stage > 0 and territory.current_stage < territory.max_stages:
		# Show stage progress
		status_label.text = "🟡 STAGE %d/%d" % [territory.current_stage, territory.max_stages]
		status_label.modulate = Color.YELLOW
	elif territory.current_stage >= territory.max_stages:
		status_label.text = "🟢 CLEARED"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "🔴 LOCKED"
		status_label.modulate = Color.RED
	
	vbox.add_child(status_label)
	
	# Add selected stage info for territories with progress
	if territory.current_stage > 0:
		var selected_stage = territory.get_meta("selected_stage", territory.current_stage)
		var selected_label = Label.new()
		if selected_stage <= territory.current_stage:
			selected_label.text = "🔄 Selected: Stage %d (Grind)" % selected_stage
			selected_label.modulate = Color.ORANGE
		else:
			selected_label.text = "⚔️ Selected: Stage %d (New)" % selected_stage
			selected_label.modulate = Color.CYAN
		selected_label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(selected_label)
	
	return vbox

func create_assignment_section(territory):
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200, 0)
	
	var assignment_label = Label.new()
	assignment_label.text = "Assigned Gods"
	assignment_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(assignment_label)
	
	# NEW: Show slot usage
	var slot_info = Label.new()
	slot_info.text = "Slots: %d/%d" % [territory.stationed_gods.size(), territory.max_god_slots]
	slot_info.add_theme_font_size_override("font_size", 11)
	slot_info.modulate = Color.CYAN
	vbox.add_child(slot_info)
	
	if territory.stationed_gods.size() > 0:
		for god_id in territory.stationed_gods:
			var god = _find_god_by_id(god_id)
			if god:
				var god_label = Label.new()
				var element_match = (god.element == territory.element)
				var match_icon = "★" if element_match else ""
				god_label.text = "• %s%s (Lv.%d)" % [match_icon, god.name, god.level]
				god_label.modulate = Color.YELLOW if element_match else Color.WHITE
				god_label.add_theme_font_size_override("font_size", 10)
				vbox.add_child(god_label)
		
		# NEW: Show total resource bonus
		var bonus = territory.get_god_resource_bonus()
		if bonus > 0:
			var bonus_label = Label.new()
			bonus_label.text = "God Bonus: +%d/hr" % bonus
			bonus_label.modulate = Color.GREEN
			bonus_label.add_theme_font_size_override("font_size", 10)
			vbox.add_child(bonus_label)
	else:
		var empty_label = Label.new()
		empty_label.text = "No gods assigned"
		empty_label.modulate = Color.GRAY
		vbox.add_child(empty_label)
		
		# NEW: Show potential benefit hint
		if territory.is_controlled_by_player() and territory.is_unlocked:
			var hint_label = Label.new()
			hint_label.text = "Assign gods for bonus resources!"
			hint_label.add_theme_font_size_override("font_size", 9)
			hint_label.modulate = Color.YELLOW
			vbox.add_child(hint_label)
	
	return vbox

func create_territory_action_button(territory):
	# Check if territory is fully unlocked and controlled
	if territory.is_controlled_by_player() and territory.is_unlocked:
		# Create a vertical container for multiple buttons
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(120, 80)
		vbox.add_theme_constant_override("separation", 3)
		
		# Main manage button
		var manage_button = Button.new()
		manage_button.custom_minimum_size = Vector2(120, 35)
		manage_button.text = "MANAGE"
		manage_button.modulate = Color.GREEN
		manage_button.add_theme_font_size_override("font_size", 11)
		manage_button.pressed.connect(_on_manage_territory.bind(territory))
		vbox.add_child(manage_button)
		
		# NEW: Quick upgrade button if upgrades available
		if territory.can_upgrade_territory() or territory.can_upgrade_resource_generation():
			var upgrade_button = Button.new()
			upgrade_button.custom_minimum_size = Vector2(120, 25)
			upgrade_button.text = "UPGRADE"
			upgrade_button.modulate = Color.CYAN
			upgrade_button.add_theme_font_size_override("font_size", 9)
			upgrade_button.pressed.connect(_on_quick_upgrade_territory.bind(territory))
			vbox.add_child(upgrade_button)
		else:
			# Show max level indicator
			var max_label = Label.new()
			max_label.text = "Max Level"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.add_theme_font_size_override("font_size", 8)
			max_label.modulate = Color.GRAY
			vbox.add_child(max_label)
		
		return vbox
	
	# Check if territory has been cleared but not yet managed
	elif territory.current_stage >= territory.max_stages and not territory.is_unlocked:
		var button = Button.new()
		button.custom_minimum_size = Vector2(120, 80)
		button.text = "CLAIM\nTERRITORY"
		button.modulate = Color.GREEN
		button.pressed.connect(_on_claim_territory.bind(territory))
		return button
	
	# Check if territory can be attacked or has cleared stages (stage cycling)
	elif territory.can_be_attacked() or territory.current_stage > 0:
		return create_stage_navigation_buttons(territory)
	
	else:
		var button = Button.new()
		button.custom_minimum_size = Vector2(120, 80)
		button.text = "UNAVAILABLE"
		button.modulate = Color.GRAY
		button.disabled = true
		return button

func create_stage_navigation_buttons(territory):
	var player_power = _calculate_player_power()
	var max_available_stage = min(territory.current_stage + 1, territory.max_stages)
	
	# If no stages cleared and can't attack, show locked button
	if territory.current_stage == 0 and player_power < territory.get_required_power():
		var button = Button.new()
		button.custom_minimum_size = Vector2(120, 80)
		button.text = "LOCKED\n(Need %d\nmore power)" % [territory.get_required_power() - player_power]
		button.modulate = Color.GRAY
		button.disabled = true
		return button
	
	# Create container for stage navigation
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(120, 80)
	container.add_theme_constant_override("separation", 2)
	
	# Create stage selector with navigation buttons
	var stage_row = HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 2)
	
	# Previous stage button
	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(25, 25)
	prev_btn.add_theme_font_size_override("font_size", 12)
	prev_btn.pressed.connect(_on_stage_navigation.bind(territory, -1))
	
	# Current stage button (main battle button)
	var stage_btn = Button.new()
	stage_btn.custom_minimum_size = Vector2(60, 25)
	stage_btn.add_theme_font_size_override("font_size", 11)
	
	# Next stage button
	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(25, 25)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.pressed.connect(_on_stage_navigation.bind(territory, 1))
	
	# Initialize with default stage (highest available for grinding or next to clear)
	var default_stage = territory.current_stage if territory.current_stage > 0 else 1
	if not territory.has_meta("selected_stage"):
		territory.set_meta("selected_stage", default_stage)
	
	var selected_stage = territory.get_meta("selected_stage", default_stage)
	
	# Update button states based on selected stage
	update_stage_navigation_buttons(territory, prev_btn, stage_btn, next_btn, selected_stage, max_available_stage, player_power)
	
	# Add to stage row
	stage_row.add_child(prev_btn)
	stage_row.add_child(stage_btn)
	stage_row.add_child(next_btn)
	
	# Progress indicator
	var progress_label = Label.new()
	progress_label.text = "Progress: %d/%d" % [territory.current_stage, territory.max_stages]
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 10)
	progress_label.modulate = Color.YELLOW
	
	container.add_child(stage_row)
	container.add_child(progress_label)
	
	return container

func update_stage_navigation_buttons(territory, prev_btn, stage_btn, next_btn, selected_stage, max_available_stage, player_power):
	# Update previous button
	prev_btn.disabled = (selected_stage <= 1)
	prev_btn.modulate = Color.WHITE if not prev_btn.disabled else Color.GRAY
	
	# Update next button
	next_btn.disabled = (selected_stage >= max_available_stage)
	next_btn.modulate = Color.WHITE if not next_btn.disabled else Color.GRAY
	
	# Update main stage button
	stage_btn.text = "STAGE %d" % selected_stage
	
	# Determine if this stage can be attacked
	var can_attack_stage = false
	if selected_stage <= territory.current_stage:
		# Can always re-fight cleared stages for grinding
		can_attack_stage = true
		stage_btn.modulate = Color.ORANGE  # Grinding color
		stage_btn.add_theme_font_size_override("font_size", 10)
	elif selected_stage == territory.current_stage + 1 and selected_stage <= territory.max_stages:
		# Next stage progression
		if player_power >= territory.get_required_power():
			can_attack_stage = true
			stage_btn.modulate = Color.RED  # New challenge color
			stage_btn.add_theme_font_size_override("font_size", 10)
		else:
			stage_btn.text = "LOCKED"
			stage_btn.modulate = Color.GRAY
			stage_btn.add_theme_font_size_override("font_size", 9)
	else:
		stage_btn.text = "LOCKED"
		stage_btn.modulate = Color.GRAY
		stage_btn.add_theme_font_size_override("font_size", 9)
	
	# Connect the stage button
	if can_attack_stage:
		# Disconnect any existing connections
		if stage_btn.pressed.is_connected(_on_attack_stage):
			stage_btn.pressed.disconnect(_on_attack_stage)
		stage_btn.pressed.connect(_on_attack_stage.bind(territory, selected_stage))
		stage_btn.disabled = false
	else:
		stage_btn.disabled = true

func _on_stage_navigation(territory, direction: int):
	var current_selected = territory.get_meta("selected_stage", 1)
	var max_available_stage = min(territory.current_stage + 1, territory.max_stages)
	
	var new_stage = current_selected + direction
	new_stage = clamp(new_stage, 1, max_available_stage)
	
	if new_stage != current_selected:
		territory.set_meta("selected_stage", new_stage)
		# Refresh the territory display to update buttons
		refresh_territories()

func _on_attack_stage(territory, stage_number: int):
	print("Attacking territory: %s, Stage: %d" % [territory.name, stage_number])
	current_battle_territory = territory
	current_battle_stage = stage_number
	selected_battle_gods.clear()
	
	# Open BattleSetupScreen instead of old team selection popup
	open_battle_setup_screen(territory, stage_number)

func open_battle_setup_screen(territory: Territory, stage: int):
	"""Open the universal battle setup screen for territory battles"""
	# Load battle setup scene
	var setup_scene = load("res://scenes/BattleSetupScreen.tscn")
	var setup_screen = setup_scene.instantiate()
	
	# Setup for territory battle
	setup_screen.setup_for_territory_battle(territory, stage)
	
	# Connect signals
	setup_screen.battle_setup_complete.connect(_on_territory_battle_setup_complete)
	setup_screen.setup_cancelled.connect(_on_territory_battle_setup_cancelled)
	
	# Add to scene tree
	get_tree().root.add_child(setup_screen)

func _on_territory_battle_setup_complete(context: Dictionary):
	"""Handle territory battle setup completion"""
	var team = context.get("team", [])
	var territory = context.get("territory")
	var stage = context.get("stage", 1)
	
	if not territory or team.size() == 0:
		print("Invalid battle setup - missing territory or team")
		return
	
	# Remove setup screen
	var setup_screen = get_tree().get_nodes_in_group("battle_setup")[0] if get_tree().get_nodes_in_group("battle_setup").size() > 0 else null
	if setup_screen:
		setup_screen.queue_free()
	
	# Store battle context
	current_battle_territory = territory
	current_battle_stage = stage
	selected_battle_gods = team
	
	# Open battle screen with proper setup
	_start_territory_battle_with_team(team)

func _on_territory_battle_setup_cancelled():
	"""Handle territory battle setup cancellation"""
	# Remove setup screen
	var setup_screen = get_tree().get_nodes_in_group("battle_setup")[0] if get_tree().get_nodes_in_group("battle_setup").size() > 0 else null
	if setup_screen:
		setup_screen.queue_free()
	
	# Clear battle context
	current_battle_territory = null
	current_battle_stage = 1
	selected_battle_gods.clear()

func _start_territory_battle_with_team(team: Array):
	"""Start the actual territory battle with selected team"""
	# Load and open the battle screen
	var battle_screen_scene = preload("res://scenes/BattleScreen.tscn")
	var battle_screen = battle_screen_scene.instantiate()
	
	# Add to scene tree root instead of current_scene (fixes gray screen issue)
	get_tree().root.add_child(battle_screen)
	
	# Hide territory screen
	visible = false
	
	# Connect back button
	if battle_screen.has_signal("back_pressed"):
		battle_screen.back_pressed.connect(_on_battle_screen_back.bind(battle_screen))
	
	# Set up the battle screen for territory stage battle
	battle_screen.setup_territory_stage_battle(current_battle_territory, current_battle_stage, team)

func create_nine_patch_panel() -> Panel:
	var panel = Panel.new()
	
	# Create a StyleBoxFlat for the Panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2 
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _on_attack_territory(territory):
	# Legacy function - redirect to new stage attack with next stage
	var next_stage = territory.current_stage + 1
	_on_attack_stage(territory, next_stage)

func populate_battle_team_list():
	# Clear existing god items
	if not battle_god_list:
		return
		
	for child in battle_god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Add spacing
	battle_god_list.add_theme_constant_override("separation", 5)
	
	# Get all player gods
	if not GameManager or not GameManager.player_data:
		return
	
	# Add team info
	var info_label = Label.new()
	info_label.text = "Select up to 5 gods for battle"
	info_label.modulate = Color.CYAN
	battle_god_list.add_child(info_label)
	
	# Add enemy preview for this stage
	var enemy_preview = create_enemy_preview_info()
	battle_god_list.add_child(enemy_preview)
	
	# Add each available god
	for god in GameManager.player_data.gods:
		var god_item = create_battle_god_item(god)
		battle_god_list.add_child(god_item)
	
	# Update selected team display
	update_selected_team_display()

func create_battle_god_item(god) -> Control:
	# Create a panel for the god item
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.4, 0.7)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 50)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	
	# Add margin inside the panel
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	margin.add_child(hbox)
	
	# Checkbox for selection
	var checkbox = CheckBox.new()
	checkbox.toggled.connect(_on_battle_god_toggled.bind(god))
	hbox.add_child(checkbox)
	
	# God info
	var god_label = Label.new()
	god_label.text = "%s (Lv.%d) - %s %s" % [
		god.name, 
		god.level,
		god.get_tier_name(),
		god.get_element_name()
	]
	god_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(god_label)
	
	# Power display
	var power_label = Label.new()
	var total_power = 0
	if god.has_method("get_power_rating"):
		total_power = god.get_power_rating()
	elif god.has_method("get_total_power"):
		total_power = god.get_total_power()
	else:
		total_power = god.base_attack + god.base_defense + god.base_hp + god.base_speed
	
	power_label.text = "Power: %d" % total_power
	power_label.custom_minimum_size = Vector2(100, 0)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(power_label)
	
	# HP/Status display
	var status_label = Label.new()
	if god.has_method("get_current_hp"):
		var current_hp = god.get_current_hp()
		var max_hp = god.get_max_hp()
		if current_hp <= 0:
			status_label.text = "DEFEATED"
			status_label.modulate = Color.RED
			checkbox.disabled = true
		elif current_hp < max_hp:
			status_label.text = "HP: %d/%d" % [current_hp, max_hp]
			status_label.modulate = Color.YELLOW
		else:
			status_label.text = "READY"
			status_label.modulate = Color.GREEN
	else:
		status_label.text = "READY"
		status_label.modulate = Color.GREEN
	
	status_label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(status_label)
	
	return panel

func _on_battle_god_toggled(checked: bool, god):
	if checked:
		if selected_battle_gods.size() < 5:
			selected_battle_gods.append(god)
		else:
			# Uncheck the checkbox if team is full
			var checkboxes = battle_god_list.get_children()
			for child in checkboxes:
				if child.has_method("get_children"):
					for subchild in child.get_children():
						if subchild is MarginContainer:
							var hbox = subchild.get_child(0)
							if hbox is HBoxContainer:
								var checkbox = hbox.get_child(0)
								if checkbox is CheckBox:
									# Find the god this checkbox represents
									for c in checkboxes:
										if c == child:
											checkbox.set_pressed_no_signal(false)
											return
	else:
		selected_battle_gods.erase(god)
	
	update_selected_team_display()

func update_selected_team_display():
	var container = battle_team_popup.find_child("SelectedTeamContainer")
	if not container:
		return
		
	# Clear existing display
	for child in container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Update header
	var header_label = Label.new()
	header_label.text = "Selected Team (%d/5):" % selected_battle_gods.size()
	header_label.add_theme_font_size_override("font_size", 14)
	container.add_child(header_label)
	
	if selected_battle_gods.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No gods selected"
		empty_label.modulate = Color.GRAY
		container.add_child(empty_label)
	else:
		var total_power = 0
		for god in selected_battle_gods:
			var god_label = Label.new()
			var power = 0
			if god.has_method("get_power_rating"):
				power = god.get_power_rating()
			elif god.has_method("get_total_power"):
				power = god.get_total_power()
			else:
				power = god.base_attack + god.base_defense + god.base_hp + god.base_speed
			
			total_power += power
			god_label.text = "• %s (Lv.%d) - Power: %d" % [god.name, god.level, power]
			container.add_child(god_label)
		
		# Show total power
		var total_label = Label.new()
		total_label.text = "Total Team Power: %d" % total_power
		total_label.modulate = Color.GOLD
		total_label.add_theme_font_size_override("font_size", 14)
		container.add_child(total_label)

func _on_start_stage_battle():
	if selected_battle_gods.size() == 0:
		print("No gods selected for battle!")
		return
	
	if not current_battle_territory:
		print("No territory selected!")
		return
	
	print("Opening Battle Screen for territory stage battle with %d gods" % selected_battle_gods.size())
	
	# Hide the popup
	battle_team_popup.hide()
	
	# Load and open the battle screen
	var battle_screen_scene = preload("res://scenes/BattleScreen.tscn")
	var battle_screen = battle_screen_scene.instantiate()
	
	# Add to scene tree root instead of current_scene (fixes gray screen issue)
	get_tree().root.add_child(battle_screen)
	
	# Hide territory screen
	visible = false
	
	# Connect back button
	if battle_screen.has_signal("back_pressed"):
		battle_screen.back_pressed.connect(_on_battle_screen_back.bind(battle_screen))
	
	# Set up the battle screen for territory stage battle
	battle_screen.setup_territory_stage_battle(current_battle_territory, current_battle_stage, selected_battle_gods)

func _on_battle_screen_back(battle_screen: Node):
	# Return to territory screen and refresh
	visible = true
	battle_screen.queue_free()
	
	# Reset battle selections
	selected_battle_gods.clear()
	current_battle_territory = null
	
	# Refresh territories to show updated progress
	refresh_territories()

func _on_cancel_battle_team_selection():
	selected_battle_gods.clear()
	battle_team_popup.hide()

func _on_claim_territory(territory):
	# Auto-assign strongest god and mark as unlocked
	var strongest_god = _find_strongest_available_god()
	if strongest_god:
		strongest_god.stationed_territory = territory.id
		territory.station_god(strongest_god.id)
		print("Territory %s claimed! Auto-assigned %s" % [territory.name, strongest_god.name])
	
	territory.is_unlocked = true
	GameManager.territory_captured.emit(territory)
	refresh_territories()

func _on_manage_territory(territory):
	print("Managing territory: ", territory.name)
	current_territory = territory
	selected_gods.clear()
	
	# Update popup info using direct reference
	if popup_territory_info:
		popup_territory_info.text = "Territory: %s (Tier %d)" % [territory.name, territory.tier]
	
	# Populate available gods
	populate_god_assignment_list(territory)
	
	# Show the popup
	if god_assignment_popup:
		god_assignment_popup.popup_centered()

func populate_god_assignment_list(territory):
	# Use direct reference to god list
	if not popup_god_list:
		print("popup_god_list is null!")
		return
		
	for child in popup_god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Add spacing between god items
	popup_god_list.add_theme_constant_override("separation", 5)
	
	# Get all player gods
	if not GameManager or not GameManager.player_data:
		var no_gods_label = Label.new()
		no_gods_label.text = "No gods available"
		no_gods_label.modulate = Color.GRAY
		popup_god_list.add_child(no_gods_label)
		return
	
	# Add gods that aren't already stationed elsewhere
	var available_gods = 0
	for god in GameManager.player_data.gods:
		# Check if god is already stationed at another territory
		var is_stationed_elsewhere = false
		if god.stationed_territory != "" and god.stationed_territory != territory.id:
			is_stationed_elsewhere = true
		
		var god_item = create_god_assignment_item(god, territory, is_stationed_elsewhere)
		popup_god_list.add_child(god_item)
		
		if not is_stationed_elsewhere:
			available_gods += 1
	
	# Add info about god limits
	var info_label = Label.new()
	info_label.text = "Available gods: %d | Currently assigned: %d" % [available_gods, territory.stationed_gods.size()]
	info_label.modulate = Color.YELLOW
	popup_god_list.add_child(info_label)
	popup_god_list.move_child(info_label, 0)  # Move to top

func create_god_assignment_item(god, territory, is_stationed_elsewhere: bool):
	# Create a panel for the god item
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	if is_stationed_elsewhere:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	else:
		style.bg_color = Color(0.2, 0.2, 0.4, 0.7)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 40)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	
	# Add margin inside the panel
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	margin.add_child(hbox)
	
	# Checkbox for selection
	var checkbox = CheckBox.new()
	checkbox.disabled = is_stationed_elsewhere
	
	# Pre-check if god is already stationed at this territory
	if territory.stationed_gods.has(god.id):
		checkbox.button_pressed = true
		if not selected_gods.has(god.id):
			selected_gods.append(god.id)
	
	checkbox.toggled.connect(_on_god_checkbox_toggled.bind(god.id))
	hbox.add_child(checkbox)
	
	# God info
	var god_label = Label.new()
	var status_text = ""
	if is_stationed_elsewhere:
		status_text = " (Stationed elsewhere)"
	elif territory.stationed_gods.has(god.id):
		status_text = " (Currently here)"
	
	god_label.text = "%s (Lv.%d) - %s %s%s" % [
		god.name, 
		god.level, 
		god.get_tier_name(), 
		god.get_element_name(),
		status_text
	]
	
	if is_stationed_elsewhere:
		god_label.modulate = Color.GRAY
	
	god_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(god_label)
	
	# Power display - handle both function names
	var power_label = Label.new()
	var total_power = 0
	if god.has_method("get_power_rating"):
		total_power = god.get_power_rating()
	elif god.has_method("get_total_power"):
		total_power = god.get_total_power()
	else:
		# Fallback calculation
		total_power = god.base_hp + god.base_attack + god.base_defense + god.base_speed
	
	power_label.text = "Power: %d" % total_power
	power_label.custom_minimum_size = Vector2(80, 0)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(power_label)
	
	return panel

func _on_god_checkbox_toggled(checked: bool, god_id: String):
	if checked:
		if not selected_gods.has(god_id):
			selected_gods.append(god_id)
	else:
		selected_gods.erase(god_id)
	
	print("Selected gods: ", selected_gods)

func _on_confirm_assignment():
	if not current_territory:
		return
	
	# Update territory's stationed gods
	current_territory.stationed_gods.clear()
	current_territory.stationed_gods.append_array(selected_gods)
	
	# Update each god's stationed_territory field
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			if selected_gods.has(god.id):
				god.stationed_territory = current_territory.id
			elif god.stationed_territory == current_territory.id:
				# Remove gods that were unselected
				god.stationed_territory = ""
	
	print("Assigned gods to %s: %s" % [current_territory.name, selected_gods])
	
	# Close popup and refresh display
	god_assignment_popup.hide()
	refresh_territories()

func _on_cancel_assignment():
	selected_gods.clear()
	god_assignment_popup.hide()

func _calculate_player_power() -> int:
	var total_power = 0
	if GameManager and GameManager.player_data:
		if GameManager.player_data.has_method("get_total_power"):
			total_power = GameManager.player_data.get_total_power()
		else:
			# Fallback calculation
			for god in GameManager.player_data.gods:
				if god.has_method("get_power_rating"):
					total_power += god.get_power_rating()
				elif god.has_method("get_total_power"):
					total_power += god.get_total_power()
				else:
					total_power += god.base_hp + god.base_attack + god.base_defense + god.base_speed
	return total_power

func _find_god_by_id(god_id: String):
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			if god.id == god_id:
				return god
	return null

func _find_strongest_available_god():
	if not GameManager or not GameManager.player_data:
		return null
	
	var strongest_god = null
	var highest_power = 0
	
	for god in GameManager.player_data.gods:
		if god.stationed_territory.is_empty():  # God is available
			var power = 0
			if god.has_method("get_power_rating"):
				power = god.get_power_rating()
			elif god.has_method("get_total_power"):
				power = god.get_total_power()
			else:
				power = god.base_hp + god.base_attack + god.base_defense + god.base_speed
			
			if power > highest_power:
				highest_power = power
				strongest_god = god
	
	return strongest_god

func _get_strongest_gods_for_battle(max_count: int) -> Array:
	if not GameManager or not GameManager.player_data:
		return []
	
	var available_gods = []
	for god in GameManager.player_data.gods:
		if god.stationed_territory.is_empty():  # God is available
			available_gods.append(god)
	
	# Sort by power (highest first) - handle different method names
	available_gods.sort_custom(func(a, b): 
		var power_a = 0
		var power_b = 0
		
		if a.has_method("get_power_rating"):
			power_a = a.get_power_rating()
		elif a.has_method("get_total_power"):
			power_a = a.get_total_power()
		else:
			power_a = a.base_hp + a.base_attack + a.base_defense + a.base_speed
			
		if b.has_method("get_power_rating"):
			power_b = b.get_power_rating()
		elif b.has_method("get_total_power"):
			power_b = b.get_total_power()
		else:
			power_b = b.base_hp + b.base_attack + b.base_defense + b.base_speed
			
		return power_a > power_b
	)
	
	# Return up to max_count gods
	return available_gods.slice(0, max_count)

func create_enemy_preview_info() -> Control:
	"""Create a preview of enemies that will be faced in the current stage"""
	if not current_battle_territory:
		return Label.new()
	
	var preview_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.2, 0.8)  # Reddish tint for enemies
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.RED
	preview_panel.add_theme_stylebox_override("panel", style)
	preview_panel.custom_minimum_size = Vector2(0, 120)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "⚔️ Stage %d Enemies:" % current_battle_stage
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.modulate = Color.YELLOW
	vbox.add_child(title_label)
	
	# Get enemy preview from battle system
	var enemy_preview = get_stage_enemy_preview(current_battle_territory, current_battle_stage)
	
	for enemy_info in enemy_preview:
		var enemy_label = Label.new()
		
		# Enhanced enemy display with type and element info
		var type_icon = get_enemy_type_icon(enemy_info.get("type", "basic"))
		var element_color = get_element_color(enemy_info.get("element", ""))
		
		enemy_label.text = "%s %s (Lv.%d)\n  HP: %d | ATK: %d | DEF: %d" % [
			type_icon,
			enemy_info.name, 
			enemy_info.level, 
			enemy_info.hp, 
			enemy_info.attack,
			enemy_info.get("defense", 0)
		]
		enemy_label.add_theme_font_size_override("font_size", 11)
		enemy_label.modulate = element_color
		vbox.add_child(enemy_label)
	
	return preview_panel

func get_stage_enemy_preview(territory: Territory, stage: int) -> Array:
	"""Get a preview of enemies for a specific stage - Summoners War style"""
	var previews = []
	
	# Base calculations for Summoners War style scaling
	var base_level = get_preview_base_level(territory.tier)
	var stage_level = base_level + (stage - 1) * 2  # Level scaling per stage
	var enemy_count = get_stage_enemy_count(territory, stage)
	
	# Determine enemy composition based on stage progression
	var enemy_composition = get_stage_enemy_composition(territory, stage)
	
	# Create enemy previews based on composition
	for i in range(enemy_count):
		var preview = {}
		preview.level = stage_level
		
		# Determine enemy type for this position
		var enemy_type = "basic"
		if i < enemy_composition.size():
			enemy_type = enemy_composition[i]
		
		# Set enemy name and element based on territory and type
		var element_name = get_element_display_name(str(territory.element))
		match enemy_type:
			"boss":
				preview.name = "%s Overlord" % element_name
			"elite":
				preview.name = "%s Elite" % element_name
			"leader":
				preview.name = "%s Commander" % element_name
			_:
				preview.name = "%s Guardian" % element_name
		
		# Calculate stats using enemies.json base stats
		var stats = calculate_preview_stats_from_enemies_json(str(territory.element), enemy_type, stage_level)
		preview.hp = stats.hp
		preview.attack = stats.attack
		preview.defense = stats.defense
		preview.element = str(territory.element)  # Convert enum to string
		preview.type = enemy_type
		
		previews.append(preview)
	
	return previews

func get_stage_enemy_count(_territory: Territory, stage: int) -> int:
	"""Get number of enemies for a stage - Summoners War style progression"""
	match stage:
		1, 2:
			return 3  # Early stages: 3 basic enemies
		3, 4, 5:
			return 4  # Mid stages: 4 enemies
		6, 7, 8, 9:
			return 5  # Late stages: 5 enemies
		10:
			return 3  # Boss stage: fewer but stronger enemies
		_:
			return 4  # Default

func get_stage_enemy_composition(_territory: Territory, stage: int) -> Array:
	"""Get enemy type composition for a stage - Summoners War style"""
	var composition = []
	
	match stage:
		1, 2:
			# Early stages: all basic
			composition = ["basic", "basic", "basic"]
		3, 4:
			# Add a leader
			composition = ["basic", "basic", "leader", "basic"]
		5, 6, 7:
			# Mixed composition with elite
			composition = ["basic", "leader", "elite", "basic", "basic"]
		8, 9:
			# Harder composition
			composition = ["leader", "elite", "elite", "basic", "leader"]
		10:
			# Boss stage
			composition = ["elite", "boss", "elite"]
		_:
			# Default composition
			composition = ["basic", "basic", "leader", "basic"]
	
	return composition

func get_element_display_name(element: String) -> String:
	"""Get display name for element"""
	match element.to_lower():
		"fire":
			return "Flame"
		"water":
			return "Frost"
		"earth":
			return "Stone"
		"lightning":
			return "Storm"
		"light":
			return "Divine"
		"dark":
			return "Shadow"
		_:
			return "Mystic"

func calculate_preview_stats_from_enemies_json(_element: String, enemy_type: String, level: int) -> Dictionary:
	"""Calculate enemy stats using enemies.json data structure"""
	# Base stats from enemies.json structure
	var base_hp = 200
	var base_attack = 50
	var base_defense = 25
	
	# Per-level growth
	var hp_per_level = 25
	var attack_per_level = 6
	var defense_per_level = 3
	
	# Role multipliers based on enemy type
	var role_multipliers = get_preview_multipliers(enemy_type)
	
	# Territory tier scaling (higher tiers = stronger base stats)
	var tier_multiplier = 1.0
	if current_battle_territory:
		tier_multiplier = 1.0 + (current_battle_territory.tier - 1) * 0.2
	
	# Calculate final stats
	var stats = {}
	stats.hp = int((base_hp + level * hp_per_level) * role_multipliers.hp * tier_multiplier)
	stats.attack = int((base_attack + level * attack_per_level) * role_multipliers.attack * tier_multiplier)
	stats.defense = int((base_defense + level * defense_per_level) * role_multipliers.defense * tier_multiplier)
	
	return stats

func get_enemy_type_icon(enemy_type: String) -> String:
	"""Get icon/symbol for enemy type"""
	match enemy_type:
		"boss":
			return "👑"  # Crown for boss
		"elite":
			return "⚡"  # Lightning for elite
		"leader":
			return "🛡️"  # Shield for leader
		_:
			return "⚔️"  # Sword for basic

func get_element_color(element: String) -> Color:
	"""Get color for element display"""
	match element.to_lower():
		"fire":
			return Color.ORANGE_RED
		"water":
			return Color.CYAN
		"earth":
			return Color.YELLOW_GREEN
		"lightning":
			return Color.LIGHT_YELLOW
		"light":
			return Color.WHITE
		"dark":
			return Color.PURPLE
		_:
			return Color.LIGHT_CORAL

func get_fallback_enemy_preview(territory: Territory, stage: int) -> Array:
	"""Fallback enemy preview when JSON data isn't available"""
	var previews = []
	var base_level = get_preview_base_level(territory.tier)
	var enemy_count = get_preview_base_enemy_count(territory.tier)
	var stage_level = base_level + (stage - 1) * 2
	
	for i in range(enemy_count):
		var preview = {}
		preview.level = stage_level
		preview.name = "Territory Guardian %d" % (i + 1)
		
		var stats = calculate_preview_stats(stage_level, {"hp": 1.0, "attack": 1.0, "defense": 1.0})
		preview.hp = stats.hp
		preview.attack = stats.attack
		preview.defense = stats.defense
		
		previews.append(preview)
	
	return previews

func get_preview_multipliers(enemy_type: String) -> Dictionary:
	"""Get stat multipliers for different enemy types"""
	match enemy_type:
		"boss":
			return {"hp": 3.0, "attack": 1.8, "defense": 1.5}
		"elite":
			return {"hp": 1.8, "attack": 1.4, "defense": 1.2}
		"leader":
			return {"hp": 1.4, "attack": 1.2, "defense": 1.1}
		_:
			return {"hp": 1.0, "attack": 1.0, "defense": 1.0}

func get_preview_base_level(tier: int) -> int:
	var tier_settings = GameDataLoader.get_tier_settings(tier)
	return tier_settings.get("base_level", 5)

func get_preview_base_enemy_count(tier: int) -> int:
	var tier_settings = GameDataLoader.get_tier_settings(tier)
	return tier_settings.get("base_enemy_count", 3)

func get_preview_element_enemy_types(element: int) -> Dictionary:
	var element_string = GameDataLoader.element_int_to_string(element)
	return GameDataLoader.get_enemy_types_for_element(element_string)

func get_preview_stage_title(stage: int) -> String:
	return GameDataLoader.get_stage_title(stage)

func calculate_preview_stats(level: int, multiplier: Dictionary) -> Dictionary:
	var base_stats = GameDataLoader.get_base_stats_config()
	return {
		"hp": int(level * base_stats.get("hp_per_level", 80) * multiplier.get("hp", 1.0)),
		"attack": int(level * base_stats.get("attack_per_level", 15) * multiplier.get("attack", 1.0)),
		"defense": int(level * base_stats.get("defense_per_level", 12) * multiplier.get("defense", 1.0)),
		"speed": int(level * base_stats.get("speed_per_level", 8) * multiplier.get("speed", 1.0))
	}

func _get_element_name(element_type: int) -> String:
	match element_type:
		0: return "Fire"
		1: return "Water"  
		2: return "Earth"
		3: return "Lightning"
		4: return "Light"
		5: return "Dark"
		_: return "Unknown"

func get_tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color(0.3, 0.5, 0.3)  # Green
		2:
			return Color(0.5, 0.3, 0.5)  # Purple
		3:
			return Color(0.5, 0.5, 0.3)  # Gold
		_:
			return Color.GRAY

# NEW: Resource collection function
func _on_collect_resources(territory: Territory):
	"""Manually collect pending resources from a territory"""
	var resources = territory.collect_resources()
	
	if resources.size() > 0:
		# Add resources to player
		for resource_type in resources.keys():
			var amount = resources[resource_type]
			if amount > 0:
				GameManager.player_data.add_resource(resource_type, amount)
		
		# Show collection notification
		var total_collected = 0
		for amount in resources.values():
			total_collected += amount
		
		print("Collected %d resources from %s" % [total_collected, territory.name])
		
		# Refresh the territory display
		refresh_territories()
	else:
		print("No resources to collect from %s" % territory.name)

# NEW: Quick upgrade function
func _on_quick_upgrade_territory(territory: Territory):
	"""Quick upgrade for the most beneficial territory improvement"""
	var upgraded = false
	
	# Try resource generation first (usually most beneficial)
	if territory.can_upgrade_resource_generation():
		if territory.upgrade_resource_generation():
			print("Upgraded resource generation for %s" % territory.name)
			upgraded = true
	# Then try territory level
	elif territory.can_upgrade_territory():
		if territory.upgrade_territory():
			print("Upgraded territory level for %s" % territory.name)
			upgraded = true
	
	if upgraded:
		refresh_territories()
		# Auto-save after territory upgrades (spending resources)
		if GameManager:
			GameManager.save_game()
	else:
		print("Cannot upgrade %s - insufficient resources" % territory.name)
