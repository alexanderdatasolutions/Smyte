# scripts/ui/TerritoryScreen.gd - Streamlined territory management
extends Control

signal back_pressed

# Preload DataLoader for JSON data access
const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

@onready var territory_list = $ScrollContainer/TerritoryList
@onready var back_button = $BackButton
@onready var scroll_container = $ScrollContainer

# Currently selected territory for god assignment
var current_territory: Territory
var selected_gods: Array = []
var god_assignment_popup: PopupPanel
var popup_territory_info: Label
var popup_god_list: VBoxContainer

func _ready():
	# Connect to GameManager signals for modular communication
	if GameManager:
		GameManager.territory_captured.connect(_on_territory_captured)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Create the god assignment popup for territory management
	create_god_assignment_popup()
		
	refresh_territories()

func create_god_assignment_popup():
	# Create popup panel for god assignment (territory management, not battle)
	god_assignment_popup = PopupPanel.new()
	god_assignment_popup.position = Vector2(660, 290)
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

func _on_back_pressed():
	print("=== TerritoryScreen: Back button pressed ===")
	back_pressed.emit()

	# Fallback: if no connections, navigate manually
	if get_signal_connection_list("back_pressed").size() == 0:
		print("=== TerritoryScreen: No back_pressed connections, navigating manually ===")
		var world_view = get_node_or_null("/root/Main/WorldView")
		if world_view:
			world_view.visible = true
			queue_free()
		else:
			# Try to go to main scene as fallback
			get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_territory_captured(_territory):
	# When a territory is captured, refresh the display
	refresh_territories()

func refresh_territories():
	print("TerritoryScreen: Starting refresh_territories()")
	
	# Save current scroll position
	var saved_scroll_position = 0
	if scroll_container:
		saved_scroll_position = scroll_container.scroll_vertical
	
	# Make sure the territory_list exists
	if not territory_list:
		territory_list = $ScrollContainer/TerritoryList
		if not territory_list:
			print("Error: Could not find TerritoryList")
			return
	
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
	
	# Add territory cards
	if GameManager.territories.size() > 0:
		for i in range(GameManager.territories.size()):
			var territory = GameManager.territories[i]
			create_detailed_territory_card(territory)
	else:
		var debug_label = Label.new()
		debug_label.text = "No territories found. Check GameManager initialization."
		debug_label.modulate = Color.RED
		territory_list.add_child(debug_label)
	
	# Restore scroll position after content is added
	if scroll_container:
		call_deferred("_restore_scroll_position", saved_scroll_position)

func _restore_scroll_position(scroll_pos: int):
	"""Helper function to restore scroll position"""
	if scroll_container:
		scroll_container.scroll_vertical = scroll_pos

func create_detailed_territory_card(territory):
	# Create main card panel - increased height for better layout
	var card_panel = create_nine_patch_panel()
	card_panel.custom_minimum_size = Vector2(0, 180)  # Increased from 120 to 180
	territory_list.add_child(card_panel)
	
	# Main horizontal container with better spacing
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)  # Reduced from 80 for better balance
	# Add some padding from the panel edges
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)  # Slightly reduced margins
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
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
	vbox.custom_minimum_size = Vector2(250, 0)  # Increased width from 200
	vbox.add_theme_constant_override("separation", 4)  # Better spacing
	
	# Territory name and tier
	var name_label = Label.new()
	name_label.text = "%s (Tier %d)" % [territory.name, territory.tier]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = Color.WHITE
	vbox.add_child(name_label)
	
	# Element with better visibility
	var element_label = Label.new()
	element_label.text = "Element: %s" % _get_element_name(territory.element)
	element_label.modulate = Color.CYAN
	element_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(element_label)
	
	# Power requirement vs player power
	var player_power = _calculate_player_power()
	var power_label = Label.new()
	power_label.text = "Power: %d / %d required" % [player_power, territory.get_required_power()]
	power_label.add_theme_font_size_override("font_size", 11)
	
	# Color code based on if player can attack
	if player_power >= territory.get_required_power():
		power_label.modulate = Color.GREEN
	else:
		power_label.modulate = Color.ORANGE
	
	vbox.add_child(power_label)
	
	# Show territory level and upgrades
	var upgrade_info = Label.new()
	upgrade_info.text = "Level: %d | Upgrades: R%d/D%d/Z%d" % [
		territory.territory_level,
		territory.resource_upgrades,
		territory.defense_upgrades,
		territory.zone_upgrades
	]
	upgrade_info.add_theme_font_size_override("font_size", 10)
	upgrade_info.modulate = Color.LIGHT_GRAY
	vbox.add_child(upgrade_info)
	
	# Show auto collection status with better formatting
	if territory.is_controlled_by_player() and territory.is_unlocked:
		var collection_info = Label.new()
		collection_info.text = "✅ Auto-Collecting"
		collection_info.modulate = Color.GREEN
		collection_info.add_theme_font_size_override("font_size", 10)
		vbox.add_child(collection_info)
	
	return vbox

func create_production_section(territory):
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 0)  # Increased width from 150
	vbox.add_theme_constant_override("separation", 4)
	
	var production_label = Label.new()
	production_label.text = "📊 Production"
	production_label.add_theme_font_size_override("font_size", 14)
	production_label.modulate = Color.YELLOW
	vbox.add_child(production_label)
	
	# Show current production rate with better formatting
	var total_rate = territory.get_resource_rate()
	var rate_label = Label.new()
	rate_label.text = "%d resources/hour" % total_rate
	rate_label.modulate = Color.WHITE
	rate_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(rate_label)
	
	# Show pending resources if any
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
	
	# Show resource breakdown for higher tiers with more detail
	if territory.tier >= 2 and territory.is_controlled_by_player():
		var breakdown_label = Label.new()
		
		# Use TerritoryManager for detailed breakdown if available
		if GameManager.territory_manager:
			var generation = GameManager.territory_manager.calculate_territory_passive_generation(territory)
			var breakdown_parts = []
			
			for resource_type in generation.keys():
				var amount = generation[resource_type]
				if amount > 0:
					breakdown_parts.append("%s: %d/hr" % [resource_type.replace("_", " ").capitalize(), amount])
			
			if breakdown_parts.size() > 0:
				breakdown_label.text = " | ".join(breakdown_parts)
			else:
				breakdown_label.text = "Base generation only"
		else:
			# Fallback display using ResourceManager for dynamic names
			var breakdown_text = ""
			var mana_name = "Mana"  # Default fallback
			
			# Get proper resource name from ResourceManager
			if GameManager and GameManager.has_method("get_resource_manager"):
				var resource_mgr = GameManager.get_resource_manager()
				if resource_mgr:
					var mana_info = resource_mgr.get_resource_info("mana")
					mana_name = mana_info.get("name", "Mana")
			
			if territory.tier == 2:
				breakdown_text = "%s, Ore, Souls" % mana_name
			elif territory.tier == 3:
				breakdown_text = "%s, Ore, Souls, Energy" % mana_name
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
	vbox.custom_minimum_size = Vector2(240, 0)  # Increased width for better layout
	vbox.add_theme_constant_override("separation", 3)
	
	var assignment_label = Label.new()
	assignment_label.text = "⚔️ Assignments"
	assignment_label.add_theme_font_size_override("font_size", 14)
	assignment_label.modulate = Color.CYAN
	vbox.add_child(assignment_label)
	
	# Show role-based slot usage if TerritoryManager is available
	if GameManager.territory_manager:
		var role_assignments = GameManager.get_territory_role_assignments(territory)
		var slot_config = GameManager.territory_manager.get_territory_slot_configuration(territory)
		
		var total_used = 0
		var total_available = 0
		
		# Show each role's status with streamlined formatting
		for role in ["defender", "gatherer", "crafter"]:
			var role_gods = role_assignments.get(role, [])
			var max_slots = slot_config.get(role + "_slots", 0)
			total_used += role_gods.size()
			total_available += max_slots
			
			if max_slots > 0:  # Only show roles that have slots
				var role_container = HBoxContainer.new()
				
				var role_label = Label.new()
				var role_icon = get_role_icon(role)
				role_label.text = "%s %s:" % [role_icon, role.capitalize()]
				role_label.add_theme_font_size_override("font_size", 11)
				role_label.modulate = get_role_color(role)
				role_label.custom_minimum_size = Vector2(85, 0)
				role_container.add_child(role_label)
				
				var count_label = Label.new()
				count_label.text = "%d/%d" % [role_gods.size(), max_slots]
				count_label.add_theme_font_size_override("font_size", 11)
				count_label.modulate = Color.WHITE if role_gods.size() < max_slots else Color.GREEN
				role_container.add_child(count_label)
				
				vbox.add_child(role_container)
				
				# Show gods in a more detailed format with their contributions
				if role_gods.size() > 0:
					for i in range(min(role_gods.size(), 2)):  # Show max 2 gods per role
						var god = role_gods[i]
						var god_container = VBoxContainer.new()
						god_container.add_theme_constant_override("separation", 1)
						
						# God name and level
						var god_label = Label.new()
						var element_match = (god.element == territory.element)
						var match_icon = "★" if element_match else "•"
						god_label.text = "   %s %s (Lv.%d)" % [match_icon, god.name, god.level]
						god_label.modulate = Color.YELLOW if element_match else Color.LIGHT_GRAY
						god_label.add_theme_font_size_override("font_size", 9)
						god_container.add_child(god_label)
						
						# Show what the god is producing/doing
						var action_label = Label.new()
						var god_action = get_god_territory_action(god, role, territory)
						action_label.text = "     → %s" % god_action
						action_label.modulate = Color.CYAN
						action_label.add_theme_font_size_override("font_size", 8)
						god_container.add_child(action_label)
						
						vbox.add_child(god_container)
					
					if role_gods.size() > 2:
						var more_label = Label.new()
						more_label.text = "   ... +%d more %ss" % [role_gods.size() - 2, role]
						more_label.modulate = Color.GRAY
						more_label.add_theme_font_size_override("font_size", 9)
						vbox.add_child(more_label)
		
		# Total efficiency summary with detailed breakdown
		var summary_label = Label.new()
		summary_label.text = "Total: %d/%d slots" % [total_used, total_available]
		summary_label.add_theme_font_size_override("font_size", 10)
		summary_label.modulate = Color.CYAN
		vbox.add_child(summary_label)
		
		# Show total god contribution if any gods are assigned
		if total_used > 0 and GameManager.territory_manager:
			var god_contribution = Label.new()
			var total_generation = GameManager.territory_manager.calculate_territory_passive_generation(territory)
			var base_generation = GameManager.territory_manager.get_base_territory_generation(territory)
			
			var total_bonus = 0
			var base_total = 0
			
			for resource in total_generation.keys():
				total_bonus += total_generation[resource]
			for resource in base_generation.keys():
				base_total += base_generation[resource]
			
			var god_bonus = total_bonus - base_total
			
			if god_bonus > 0:
				god_contribution.text = "God Bonus: +%d resources/hr" % god_bonus
				god_contribution.modulate = Color.GREEN
			else:
				god_contribution.text = "Gods providing base efficiency"
				god_contribution.modulate = Color.YELLOW
			
			god_contribution.add_theme_font_size_override("font_size", 9)
			vbox.add_child(god_contribution)
	else:
		# Legacy slot display
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
			
			# Show total resource bonus
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
			
			# Show potential benefit hint
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
		# Create a vertical container for multiple buttons with better spacing
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(130, 140)  # Increased size
		vbox.add_theme_constant_override("separation", 5)  # Better separation
		
		# Main manage button - now opens role management if available
		var manage_button = Button.new()
		manage_button.custom_minimum_size = Vector2(130, 35)  # Increased height
		if GameManager.territory_manager:
			manage_button.text = "⚙️ MANAGE ROLES"
			manage_button.modulate = Color.GREEN
			manage_button.pressed.connect(_on_open_role_management.bind(territory))
		else:
			manage_button.text = "⚙️ MANAGE"
			manage_button.modulate = Color.GREEN
			manage_button.pressed.connect(_on_manage_territory.bind(territory))
		manage_button.add_theme_font_size_override("font_size", 11)  # Slightly larger font
		vbox.add_child(manage_button)
		
		# Keep the regular stage navigation buttons for farming
		var stage_buttons = create_stage_navigation_buttons(territory)
		vbox.add_child(stage_buttons)
		
		# Quick upgrade button if upgrades available
		if territory.can_upgrade_territory() or territory.can_upgrade_resource_generation():
			var upgrade_button = Button.new()
			upgrade_button.custom_minimum_size = Vector2(130, 25)  # Better sizing
			upgrade_button.text = "⬆️ UPGRADE"
			upgrade_button.modulate = Color.CYAN
			upgrade_button.add_theme_font_size_override("font_size", 10)
			upgrade_button.pressed.connect(_on_quick_upgrade_territory.bind(territory))
			vbox.add_child(upgrade_button)
		
		return vbox
	
	# Check if territory has been cleared but not yet managed
	elif territory.current_stage >= territory.max_stages and not territory.is_unlocked:
		var button = Button.new()
		button.custom_minimum_size = Vector2(130, 90)  # Better size for bigger cards
		button.text = "🏆 CLAIM\nTERRITORY"
		button.modulate = Color.GREEN
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_claim_territory.bind(territory))
		return button
	
	# Check if territory can be attacked or has cleared stages (stage cycling)
	elif territory.can_be_attacked() or territory.current_stage > 0:
		return create_stage_navigation_buttons(territory)
	
	else:
		var button = Button.new()
		button.custom_minimum_size = Vector2(130, 90)  # Better size consistency
		button.text = "🔒 LOCKED"
		button.modulate = Color.GRAY
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = true
		return button

func create_stage_navigation_buttons(territory):
	var player_power = _calculate_player_power()
	
	# For controlled territories, allow farming all cleared stages
	var max_available_stage
	if territory.is_controlled_by_player() and territory.is_unlocked:
		max_available_stage = territory.max_stages  # Can farm any stage
	else:
		max_available_stage = min(territory.current_stage + 1, territory.max_stages)  # Normal progression
	
	# If no stages cleared and can't attack, show locked button
	if territory.current_stage == 0 and player_power < territory.get_required_power():
		var button = Button.new()
		button.custom_minimum_size = Vector2(130, 90)  # Consistent sizing
		button.text = "🔒 LOCKED\n(Need %d\nmore power)" % [territory.get_required_power() - player_power]
		button.modulate = Color.GRAY
		button.add_theme_font_size_override("font_size", 10)
		button.disabled = true
		return button
	
	# Create container for stage navigation with better sizing
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(120, 80)  # Increased height for better fit
	container.add_theme_constant_override("separation", 3)  # Slightly more separation
	
	# Create stage selector with navigation buttons
	var stage_row = HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 2)
	
	# Previous stage button
	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(28, 28)  # Slightly larger
	prev_btn.add_theme_font_size_override("font_size", 12)
	prev_btn.pressed.connect(_on_stage_navigation.bind(territory, -1))
	
	# Current stage button (main battle button)
	var stage_btn = Button.new()
	stage_btn.custom_minimum_size = Vector2(64, 28)  # Slightly larger
	stage_btn.add_theme_font_size_override("font_size", 11)
	
	# Next stage button
	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(28, 28)  # Slightly larger
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.pressed.connect(_on_stage_navigation.bind(territory, 1))
	
	# Initialize with default stage
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
	if territory.is_controlled_by_player() and territory.is_unlocked:
		progress_label.text = "Farming: %d/%d" % [selected_stage, territory.max_stages]
		progress_label.modulate = Color.ORANGE
	else:
		progress_label.text = "Progress: %d/%d" % [territory.current_stage, territory.max_stages]
		progress_label.modulate = Color.YELLOW
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 10)
	
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
	var max_available_stage
	
	# For controlled territories, allow farming any cleared stage
	if territory.is_controlled_by_player() and territory.is_unlocked:
		max_available_stage = territory.max_stages
	else:
		# For uncontrolled territories, normal progression rules
		max_available_stage = min(territory.current_stage + 1, territory.max_stages)
	
	var new_stage = current_selected + direction
	new_stage = clamp(new_stage, 1, max_available_stage)
	
	if new_stage != current_selected:
		territory.set_meta("selected_stage", new_stage)
		# Refresh just the buttons for this territory
		refresh_territories()  # For now, full refresh - could be optimized later

func _on_attack_stage(territory, stage_number: int):
	print("Attacking territory: %s, Stage: %d" % [territory.name, stage_number])
	
	# Open BattleSetupScreen directly
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
	
	# Open battle screen with proper setup
	var battle_screen_scene = preload("res://scenes/BattleScreen.tscn")
	var battle_screen = battle_screen_scene.instantiate()
	
	# Add to scene tree root
	get_tree().root.add_child(battle_screen)
	
	# Hide territory screen
	visible = false
	
	# Connect back button
	if battle_screen.has_signal("back_pressed"):
		battle_screen.back_pressed.connect(_on_battle_screen_back.bind(battle_screen))
	
	# Set up the battle screen for territory stage battle
	battle_screen.setup_territory_stage_battle(territory, stage, team)

func _on_territory_battle_setup_cancelled():
	"""Handle territory battle setup cancellation"""
	# Remove setup screen
	var setup_screen = get_tree().get_nodes_in_group("battle_setup")[0] if get_tree().get_nodes_in_group("battle_setup").size() > 0 else null
	if setup_screen:
		setup_screen.queue_free()

func _on_battle_screen_back(battle_screen: Node):
	# Return to territory screen and refresh
	visible = true
	
	# Disconnect signal to prevent any issues during cleanup
	if battle_screen.back_pressed.is_connected(_on_battle_screen_back):
		battle_screen.back_pressed.disconnect(_on_battle_screen_back)
	
	battle_screen.queue_free()

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
	
	# Power display
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

func _get_element_name(element_type: int) -> String:
	match element_type:
		0: return "Fire"
		1: return "Water"  
		2: return "Earth"
		3: return "Lightning"
		4: return "Light"
		5: return "Dark"
		_: return "Unknown"

func get_role_icon(role: String) -> String:
	"""Get icon for role type"""
	match role:
		"defender":
			return "🛡️"
		"gatherer":
			return "⛏️"
		"crafter":
			return "🔨"
		_:
			return "•"

func get_role_color(role: String) -> Color:
	"""Get color for role type"""
	match role:
		"defender":
			return Color.RED
		"gatherer":
			return Color.GREEN
		"crafter":
			return Color.BLUE
		_:
			return Color.WHITE

func get_god_territory_action(god: God, role: String, territory: Territory) -> String:
	"""Get a description of what this god is doing in this territory role"""
	var efficiency = 1.0
	var element_bonus = ""
	
	# Calculate efficiency if TerritoryManager is available
	if GameManager.territory_manager:
		efficiency = GameManager.territory_manager.get_god_role_efficiency(god, role)
	
	# Check for element matching bonus
	if god.element == territory.element:
		element_bonus = " (+25% match)"
	
	# Generate action description based on role
	match role:
		"defender":
			var defense_boost = int(territory.required_power * 0.15 * efficiency)
			return "Defending (+%d power)%s" % [defense_boost, element_bonus]
		
		"gatherer":
			# Show specific resources being gathered based on territory tier
			var resource_list = []
			if GameManager.territory_manager:
				var god_contribution = GameManager.territory_manager.calculate_god_contribution(god, role, territory)
				for resource_type in god_contribution.keys():
					var amount = god_contribution[resource_type]
					if amount > 0:
						var display_name = resource_type.replace("_", " ").capitalize()
						resource_list.append("%s: +%d/hr" % [display_name, amount])
			
			if resource_list.size() > 0:
				return "Gathering: %s%s" % [", ".join(resource_list), element_bonus]
			else:
				# Fallback if TerritoryManager not available - use ResourceManager for names
				var mana_name = "Mana"  # Default fallback
				
				# Get proper resource name from ResourceManager
				if GameManager and GameManager.has_method("get_resource_manager"):
					var resource_mgr = GameManager.get_resource_manager()
					if resource_mgr:
						var mana_info = resource_mgr.get_resource_info("mana")
						mana_name = mana_info.get("name", "Mana")
				
				match territory.tier:
					1:
						return "Gathering: %s +%d/hr%s" % [mana_name, int(12 * efficiency), element_bonus]
					2:
						return "Gathering: %s +%d, Ore +%d/hr%s" % [mana_name, int(18 * efficiency), int(8 * efficiency), element_bonus]
					3:
						return "Gathering: Essence +%d, Ore +%d, Souls +%d/hr%s" % [int(25 * efficiency), int(12 * efficiency), int(5 * efficiency), element_bonus]
					_:
						return "Gathering: Base resources +%d/hr%s" % [int(10 * efficiency), element_bonus]
		
		"crafter":
			var crafted_items = []
			if GameManager.territory_manager:
				var god_contribution = GameManager.territory_manager.calculate_god_contribution(god, role, territory)
				for resource_type in god_contribution.keys():
					var amount = god_contribution[resource_type]
					if amount > 0:
						var display_name = resource_type.replace("_", " ").capitalize()
						crafted_items.append("%s: +%d/hr" % [display_name, amount])
			
			if crafted_items.size() > 0:
				return "Crafting: %s%s" % [", ".join(crafted_items), element_bonus]
			else:
				# Fallback
				var element_name = territory.get_element_name().to_lower()
				var powder_amount = max(1, int(3 * efficiency))
				return "Crafting: %s Powder +%d/hr%s" % [element_name.capitalize(), powder_amount, element_bonus]
		
		_:
			return "Unknown role (%d%% efficiency)" % int(efficiency * 100)

func _on_open_role_management(territory: Territory):
	"""Open the role management screen for a territory"""
	print("Opening role management for territory: ", territory.name)
	
	# Load the role management screen
	var role_screen_scene = load("res://scenes/TerritoryRoleScreen.tscn")
	var role_screen = role_screen_scene.instantiate()
	
	# Add to scene tree
	get_tree().root.add_child(role_screen)
	
	# Setup for this territory
	role_screen.setup_for_territory(territory)
	
	# Connect back signal
	role_screen.back_pressed.connect(_on_role_management_back.bind(role_screen))
	role_screen.role_assignments_changed.connect(_on_role_assignments_changed)
	
	# Hide this screen
	visible = false

func _on_role_management_back(role_screen: Node):
	"""Handle return from role management screen"""
	# Show this screen again
	visible = true
	
	# Clean up role screen
	role_screen.queue_free()
	
	# Refresh territories to show updated assignments
	refresh_territories()

func _on_role_assignments_changed():
	"""Handle role assignment changes"""
	# Refresh display when assignments change
	refresh_territories()

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
		# Auto-save after territory upgrades
		if GameManager:
			GameManager.save_game()
	else:
		print("Cannot upgrade %s - insufficient resources" % territory.name)