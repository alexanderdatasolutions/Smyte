# scripts/ui/TerritoryScreen.gd - Enhanced with polished UI
extends Control

signal back_pressed

const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

@onready var territory_list = $ScrollContainer/TerritoryList
@onready var back_button = $BackButton
@onready var scroll_container = $ScrollContainer

# UI Enhancement nodes
@onready var header_panel = $HeaderPanel
@onready var filter_buttons = $HeaderPanel/FilterButtons
@onready var collection_button = $HeaderPanel/CollectAllButton
@onready var territory_count_label = $HeaderPanel/TerritoryCount

# Currently selected territory for god assignment
var current_territory: Territory
var selected_gods: Array = []
var god_assignment_popup: PopupPanel
var popup_territory_info: Label
var popup_god_list: VBoxContainer

# Filter states
var current_filter: String = "all"  # all, controlled, available, locked

func _ready():
	if GameManager:
		GameManager.territory_captured.connect(_on_territory_captured)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Configure scroll container for proper scrolling (Godot 4.x API)
	if scroll_container:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	create_header_ui()
	create_god_assignment_popup()
	refresh_territories()

func create_god_assignment_popup():
	"""Create the god assignment popup for legacy UI support"""
	god_assignment_popup = PopupPanel.new()
	god_assignment_popup.size = Vector2(600, 400)
	god_assignment_popup.position = Vector2(200, 100)
	
	# Create content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 20)
	content.add_theme_constant_override("margin_right", 20)
	content.add_theme_constant_override("margin_top", 20)
	content.add_theme_constant_override("margin_bottom", 20)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Assign Gods to Territory"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	
	# Instructions
	var instruction_label = Label.new()
	instruction_label.text = "Select gods to assign to this territory:"
	instruction_label.add_theme_font_size_override("font_size", 12)
	content.add_child(instruction_label)
	
	# Scrollable god list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	popup_god_list = VBoxContainer.new()
	popup_god_list.add_theme_constant_override("separation", 5)
	scroll.add_child(popup_god_list)
	content.add_child(scroll)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 10)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_assignment)
	button_container.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(_on_confirm_assignment)
	button_container.add_child(confirm_btn)
	
	content.add_child(button_container)
	
	# Add content to popup
	god_assignment_popup.add_child(content)
	
	# Add popup to scene
	add_child(god_assignment_popup)

func create_header_ui():
	"""Create enhanced header with filters and quick actions"""
	# Create header if not exists
	if not header_panel:
		header_panel = Panel.new()
		header_panel.name = "HeaderPanel"
		header_panel.custom_minimum_size = Vector2(0, 80)
		header_panel.position = Vector2(180, 60)
		header_panel.size = Vector2(1000, 80)
		add_child(header_panel)
		move_child(header_panel, 0)
	
	# Style the header
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	header_style.border_width_bottom = 2
	header_style.border_color = Color(0.8, 0.6, 0.2, 1)
	header_panel.add_theme_stylebox_override("panel", header_style)
	
	# Main header container
	var header_content = VBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("separation", 5)
	header_content.add_theme_constant_override("margin_left", 10)
	header_content.add_theme_constant_override("margin_right", 10)
	header_content.add_theme_constant_override("margin_top", 5)
	header_content.add_theme_constant_override("margin_bottom", 5)
	header_panel.add_child(header_content)
	
	# Top row - Title and summary
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	header_content.add_child(top_row)
	
	# Territory summary
	var summary_container = HBoxContainer.new()
	summary_container.add_theme_constant_override("separation", 30)
	top_row.add_child(summary_container)
	
	# Controlled territories count
	var controlled_label = create_summary_stat("🏰 Controlled", "0/0", Color.GREEN)
	summary_container.add_child(controlled_label)
	
	# Total resource rate
	var resource_label = create_summary_stat("⚡ Total Rate", "0/hr", Color.YELLOW)
	summary_container.add_child(resource_label)
	
	# Pending resources
	var pending_label = create_summary_stat("💰 Pending", "0", Color.CYAN)
	summary_container.add_child(pending_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	
	# Collect All button
	var collect_all_btn = Button.new()
	collect_all_btn.text = "🎁 COLLECT ALL"
	collect_all_btn.custom_minimum_size = Vector2(150, 35)
	collect_all_btn.modulate = Color.GREEN
	collect_all_btn.add_theme_font_size_override("font_size", 12)
	collect_all_btn.pressed.connect(_on_collect_all_pressed)
	top_row.add_child(collect_all_btn)
	
	# Bottom row - Filter buttons
	var filter_container = HBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 10)
	header_content.add_child(filter_container)
	
	# Filter label
	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.modulate = Color.GRAY
	filter_container.add_child(filter_label)
	
	# Filter buttons - Updated descriptions for level-based hiding (MYTHOS ARCHITECTURE)
	var filters = [
		{"id": "all", "text": "All", "color": Color.WHITE},
		{"id": "controlled", "text": "Controlled", "color": Color.GREEN},
		{"id": "available", "text": "Available", "color": Color.YELLOW},
		{"id": "locked", "text": "Completed", "color": Color.BLUE}  # Changed from "Locked" to "Completed"
	]
	
	for filter_data in filters:
		var filter_btn = Button.new()
		filter_btn.text = filter_data.text
		filter_btn.toggle_mode = true
		filter_btn.button_pressed = (filter_data.id == current_filter)
		filter_btn.custom_minimum_size = Vector2(100, 28)
		filter_btn.add_theme_font_size_override("font_size", 11)
		if filter_data.id == current_filter:
			filter_btn.modulate = filter_data.color
		filter_btn.pressed.connect(_on_filter_changed.bind(filter_data.id, filter_btn))
		filter_container.add_child(filter_btn)
	
	# Update summary stats
	update_header_summary()

func create_summary_stat(label_text: String, value_text: String, color: Color) -> Control:
	"""Create a summary stat display"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color.GRAY
	container.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.modulate = color
	value.name = "Value"  # For easy updating
	container.add_child(value)
	
	return container

func update_header_summary():
	"""Update header summary statistics"""
	if not header_panel:
		return
	
	var controlled_count = 0
	var total_count = 0
	var total_rate = 0
	var total_pending = 0
	
	if GameManager and GameManager.territories:
		total_count = GameManager.territories.size()
		for territory in GameManager.territories:
			if territory.is_controlled_by_player():
				controlled_count += 1
				total_rate += territory.get_resource_rate()
				
				var pending = territory.get_pending_resources()
				for amount in pending.values():
					total_pending += amount
	
	# Update labels
	var summary_container = header_panel.get_node_or_null("VBoxContainer/HBoxContainer/HBoxContainer")
	if summary_container:
		# Update controlled count
		var controlled_stat = summary_container.get_child(0)
		if controlled_stat:
			var value_label = controlled_stat.get_node_or_null("Value")
			if value_label:
				value_label.text = "%d/%d" % [controlled_count, total_count]
		
		# Update resource rate
		var rate_stat = summary_container.get_child(1)
		if rate_stat:
			var value_label = rate_stat.get_node_or_null("Value")
			if value_label:
				value_label.text = "%d/hr" % total_rate
		
		# Update pending resources
		var pending_stat = summary_container.get_child(2)
		if pending_stat:
			var value_label = pending_stat.get_node_or_null("Value")
			if value_label:
				value_label.text = format_large_number(total_pending)

func format_large_number(num: int) -> String:
	"""Format large numbers for display"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func format_compact_number(num: int) -> String:
	"""Format numbers compactly for resource displays"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 10000:
		return "%.0fK" % (num / 1000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _on_filter_changed(filter_id: String, button: Button):
	"""Handle filter button changes"""
	current_filter = filter_id
	
	# Update button states
	var filter_container = header_panel.get_node_or_null("VBoxContainer/HBoxContainer2")
	if filter_container:
		for child in filter_container.get_children():
			if child is Button:
				child.button_pressed = false
				child.modulate = Color.WHITE
	
	button.button_pressed = true
	match filter_id:
		"all": button.modulate = Color.WHITE
		"controlled": button.modulate = Color.GREEN
		"available": button.modulate = Color.YELLOW
		"locked": button.modulate = Color.BLUE  # Changed from RED to BLUE for "Completed"
	
	refresh_territories()

func _on_collect_all_pressed():
	"""Collect resources from all controlled territories"""
	if not GameManager:
		return
	
	var total_collected = {}
	var territories_collected = 0
	
	for territory in GameManager.territories:
		if territory.is_controlled_by_player() and territory.is_unlocked:
			var resources = territory.collect_resources()
			if resources.size() > 0:
				territories_collected += 1
				for resource_type in resources:
					total_collected[resource_type] = total_collected.get(resource_type, 0) + resources[resource_type]
					GameManager.player_data.add_resource(resource_type, resources[resource_type])
	
	if territories_collected > 0:
		show_collection_popup(total_collected, territories_collected)
	
	refresh_territories()
	update_header_summary()

func _on_territory_captured(_territory):
	"""Handle when a territory is captured - refresh display"""
	refresh_territories()
	update_header_summary()

func _on_back_pressed():
	"""Handle back button press"""
	print("=== TerritoryScreen: Back button pressed ===")
	back_pressed.emit()

func _on_collect_resources(territory: Territory):
	"""Manually collect pending resources from a territory"""
	var resources = territory.collect_resources()
	
	if resources.size() > 0:
		# Add resources to player
		for resource_type in resources.keys():
			var amount = resources[resource_type]
			GameManager.player_data.add_resource(resource_type, amount)
		
		# Show collection notification
		var total_collected = 0
		for amount in resources.values():
			total_collected += amount
		
		print("Collected %d resources from %s" % [total_collected, territory.name])
		
		# Refresh the territory display
		refresh_territories()
		update_header_summary()
	else:
		print("No resources to collect from %s" % territory.name)

func _on_manage_territory(territory):
	"""Open legacy territory management popup"""
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
	if role_screen.has_signal("role_assignments_changed"):
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

func _on_claim_territory(territory):
	"""Auto-assign strongest god and mark territory as unlocked"""
	var strongest_god = _find_strongest_available_god()
	if strongest_god:
		territory.station_god(strongest_god.id)
		strongest_god.stationed_territory = territory.id
	
	territory.is_unlocked = true
	GameManager.territory_captured.emit(territory)
	refresh_territories()

func _on_stage_navigation(territory, direction: int):
	"""Handle stage navigation (previous/next stage selection)"""
	var current_selected = territory.get_meta("selected_stage", 1)
	var max_available_stage
	
	# For controlled territories, allow farming any cleared stage
	if territory.is_controlled_by_player() and territory.is_unlocked:
		max_available_stage = territory.max_stages
	else:
		max_available_stage = min(territory.current_stage + 1, territory.max_stages)
	
	var new_stage = current_selected + direction
	new_stage = clamp(new_stage, 1, max_available_stage)
	
	if new_stage != current_selected:
		territory.set_meta("selected_stage", new_stage)
		refresh_territories()

func _on_attack_stage(territory, stage_number: int):
	"""Handle stage attack button press"""
	print("Attacking territory: %s, Stage: %d" % [territory.name, stage_number])
	
	# Open BattleSetupScreen directly
	open_battle_setup_screen(territory, stage_number)

func show_collection_popup(resources: Dictionary, territory_count: int):
	"""Show popup with collection results"""
	var popup = AcceptDialog.new()
	popup.title = "Resources Collected!"
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	
	var header = Label.new()
	header.text = "Collected from %d territories:" % territory_count
	header.add_theme_font_size_override("font_size", 14)
	content.add_child(header)
	
	for resource_type in resources:
		var line = Label.new()
		line.text = "• %s: +%d" % [resource_type.capitalize(), resources[resource_type]]
		line.modulate = Color.YELLOW
		content.add_child(line)
	
	popup.add_child(content)
	get_tree().root.add_child(popup)
	popup.popup_centered()
	popup.popup_hide.connect(popup.queue_free)

func refresh_territories():
	print("TerritoryScreen: Starting refresh_territories() with filter: ", current_filter)
	
	var saved_scroll_position = 0
	if scroll_container:
		saved_scroll_position = scroll_container.scroll_vertical
	
	if not territory_list:
		territory_list = $ScrollContainer/TerritoryList
		if not territory_list:
			print("Error: Could not find TerritoryList")
			return
	
	for child in territory_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	territory_list.add_theme_constant_override("separation", 12)
	
	if not GameManager or not GameManager.territories:
		return
	
	# Apply filter - Updated for level-based progression (MYTHOS ARCHITECTURE)
	# Hide locked territories completely - user should only see available/accessible content
	var filtered_territories = []
	for territory in GameManager.territories:
		var player_level = _get_player_level()
		var required_level = _get_territory_unlock_level(territory)
		var is_level_unlocked = player_level >= required_level
		
		# Skip territories that aren't unlocked by level (clean UI - MYTHOS ARCHITECTURE)
		if not is_level_unlocked:
			continue
		
		match current_filter:
			"all":
				filtered_territories.append(territory)
			"controlled":
				if territory.is_controlled_by_player() and territory.is_unlocked:
					filtered_territories.append(territory)
			"available":
				if territory.can_be_attacked() and not territory.is_controlled_by_player():
					filtered_territories.append(territory)
			"locked":
				# For "locked" filter, show stage-completed territories (renamed to "Completed")
				if not territory.can_be_attacked() and not territory.is_controlled_by_player():
					filtered_territories.append(territory)
	
	# Sort territories by tier and status
	filtered_territories.sort_custom(func(a, b):
		# First by tier
		if a.tier != b.tier:
			return a.tier < b.tier
		# Then by control status (controlled first)
		if a.is_controlled_by_player() != b.is_controlled_by_player():
			return a.is_controlled_by_player()
		# Then by progress
		return a.current_stage > b.current_stage
	)
	
	# Create enhanced territory cards
	for territory in filtered_territories:
		create_enhanced_territory_card(territory)
	
	if filtered_territories.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No territories match current filter"
		empty_label.modulate = Color.GRAY
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		territory_list.add_child(empty_label)
	
	call_deferred("_restore_scroll_position", saved_scroll_position)
	update_header_summary()

func create_enhanced_territory_card(territory):
	"""Create a polished territory card with proper minimum sizing"""
	# Main card container with tier-based coloring
	var card_panel = create_styled_territory_panel(territory)
	card_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand unnecessarily
	card_panel.custom_minimum_size = Vector2(0, 280)  # Minimum height for proper content display
	territory_list.add_child(card_panel)
	
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(margin)
	margin.add_child(main_vbox)
	
	# Header row with title and status
	var header_row = create_territory_header(territory)
	main_vbox.add_child(header_row)
	
	# Progress bar for stages
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		var progress_bar = create_stage_progress_bar(territory)
		main_vbox.add_child(progress_bar)
	
	# Main content area with auto-scaling boxed sections
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 12)
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)
	
	# Create styled boxes for each section with adjusted sizes
	# Left section - Resource Production Box (wider for overflow prevention)
	var left_section_content = create_resource_production_section(territory)
	var left_box = create_section_box("📊 Resources", left_section_content, Color(0.2, 0.7, 0.9, 1), 240)
	content_hbox.add_child(left_box)
	
	# Middle-left section - God Assignments Box  
	var middle_section_content = create_role_assignment_section(territory)
	var middle_box = create_section_box("⚔️ Gods", middle_section_content, Color(0.8, 0.4, 0.9, 1), 220)
	content_hbox.add_child(middle_box)
	
	# Middle-right section - Combat & Farming Box
	var combat_section_content = create_combat_farming_section(territory)
	var combat_box = create_section_box("⚔️ Combat", combat_section_content, Color(0.9, 0.6, 0.2, 1), 200)
	content_hbox.add_child(combat_box)
	
	# Right section - Upgrades Box
	var upgrade_section_content = create_upgrade_section(territory)
	var upgrade_box = create_section_box("⬆️ Upgrades", upgrade_section_content, Color(0.2, 0.9, 0.4, 1), 200)
	content_hbox.add_child(upgrade_box)

func create_styled_territory_panel(territory) -> Panel:
	"""Create a panel styled based on territory tier and status"""
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	
	# Base color based on tier
	match territory.tier:
		1: style.bg_color = Color(0.2, 0.25, 0.3, 0.9)  # Blue-ish
		2: style.bg_color = Color(0.25, 0.2, 0.35, 0.9)  # Purple-ish
		3: style.bg_color = Color(0.35, 0.2, 0.2, 0.9)   # Red-ish
		_: style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	
	# Border based on control status
	style.border_width_left = 3
	style.border_width_top = 2
	style.border_width_right = 3
	style.border_width_bottom = 2
	
	if territory.is_controlled_by_player() and territory.is_unlocked:
		style.border_color = Color(0.2, 0.8, 0.2, 1)  # Green for controlled
	elif territory.current_stage >= territory.max_stages:
		style.border_color = Color(0.8, 0.8, 0.2, 1)  # Yellow for cleared
	elif territory.can_be_attacked():
		style.border_color = Color(0.8, 0.4, 0.2, 1)  # Orange for available
	else:
		style.border_color = Color(0.5, 0.5, 0.5, 1)  # Gray for locked
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	
	# Glow effect for controlled territories
	if territory.is_controlled_by_player():
		style.shadow_color = Color(0.2, 0.8, 0.2, 0.3)
		style.shadow_size = 5
	
	panel.add_theme_stylebox_override("panel", style)
	return panel

func create_section_box(title: String, content: Control, accent_color: Color, min_width: int = 200) -> Panel:
	"""Create a styled box container with custom minimum sizing"""
	var box_panel = Panel.new()
	box_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand unnecessarily
	box_panel.custom_minimum_size = Vector2(min_width, 180)  # Custom width and minimum height
	
	# Style the box
	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	box_style.border_width_left = 2
	box_style.border_width_top = 3
	box_style.border_width_right = 2  
	box_style.border_width_bottom = 2
	box_style.border_color = accent_color
	box_style.corner_radius_top_left = 6
	box_style.corner_radius_top_right = 6
	box_style.corner_radius_bottom_right = 6
	box_style.corner_radius_bottom_left = 6
	box_panel.add_theme_stylebox_override("panel", box_style)
	
	# Main container with margins
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	box_panel.add_child(margin_container)
	
	# Content container with auto-scaling
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(content_vbox)
	
	# Title header
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.modulate = accent_color
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(title_label)
	
	# Separator line
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 2)
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = accent_color
	separator.add_theme_stylebox_override("separator", sep_style)
	content_vbox.add_child(separator)
	
	# Add the actual content (remove its title since we have our own)
	if content is VBoxContainer and content.get_child_count() > 0:
		var first_child = content.get_child(0)
		if first_child is Label and (first_child.text.begins_with("📊") or first_child.text.begins_with("⚔️")):
			first_child.queue_free()
	
	content_vbox.add_child(content)
	
	return box_panel

func create_territory_header(territory) -> Control:
	"""Create the header section with name and status badges"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	
	# Territory icon based on element
	var icon_label = Label.new()
	icon_label.text = get_element_icon(territory.element)
	icon_label.add_theme_font_size_override("font_size", 24)
	header.add_child(icon_label)
	
	# Name and tier
	var name_container = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = territory.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = Color.WHITE
	name_container.add_child(name_label)
	
	var tier_label = Label.new()
	tier_label.text = "Tier %d • %s" % [territory.tier, territory.get_element_name()]
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.modulate = Color.GRAY
	name_container.add_child(tier_label)
	
	header.add_child(name_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Status badges
	var badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	
	if territory.is_controlled_by_player() and territory.is_unlocked:
		badges.add_child(create_badge("CONTROLLED", Color.GREEN))
		
		# Auto-collection badge
		if territory.auto_collection_mode != "manual":
			var auto_text = territory.auto_collection_mode.replace("_", " ").capitalize()
			badges.add_child(create_badge("AUTO: " + auto_text, Color.CYAN))
	elif territory.current_stage >= territory.max_stages:
		badges.add_child(create_badge("READY TO CLAIM", Color.YELLOW))
	elif territory.current_stage > 0:
		badges.add_child(create_badge("IN PROGRESS", Color.ORANGE))
	else:
		# Check if territory is unlocked by player level (MYTHOS ARCHITECTURE)
		var player_level = _get_player_level()
		var required_level = _get_territory_unlock_level(territory)
		
		if player_level < required_level:
			badges.add_child(create_badge("LOCKED (Lv.%d)" % required_level, Color.RED))
		else:
			badges.add_child(create_badge("AVAILABLE", Color.GREEN))
	
	header.add_child(badges)
	
	return header

func create_badge(text: String, color: Color) -> Panel:
	"""Create a styled badge"""
	var badge_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	badge_panel.add_theme_stylebox_override("panel", style)
	badge_panel.custom_minimum_size = Vector2(80, 24)
	
	var badge_label = Label.new()
	badge_label.text = text
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.modulate = color
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	badge_panel.add_child(badge_label)
	
	return badge_panel

func create_stage_progress_bar(territory) -> Control:
	"""Create a visual progress bar for stage completion"""
	var progress_container = VBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 4)
	
	# Progress label
	var progress_label = Label.new()
	progress_label.text = "Stage Progress: %d/%d" % [territory.current_stage, territory.max_stages]
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_container.add_child(progress_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.max_value = territory.max_stages
	progress_bar.value = territory.current_stage
	progress_bar.show_percentage = false
	
	# Style the progress bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.1, 0.1, 1)
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_right = 3
	bar_style.corner_radius_bottom_left = 3
	progress_bar.add_theme_stylebox_override("background", bar_style)
	
	var fill_style = StyleBoxFlat.new()
	if territory.current_stage >= territory.max_stages:
		fill_style.bg_color = Color(0.2, 0.8, 0.2, 1)  # Green when complete
	else:
		fill_style.bg_color = Color(0.8, 0.4, 0.2, 1)  # Orange in progress
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_right = 3
	fill_style.corner_radius_bottom_left = 3
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	progress_container.add_child(progress_bar)
	
	# Stage indicators
	var stage_indicators = HBoxContainer.new()
	stage_indicators.add_theme_constant_override("separation", 2)
	
	for i in range(territory.max_stages):
		var indicator = Panel.new()
		indicator.custom_minimum_size = Vector2(20, 6)
		
		var ind_style = StyleBoxFlat.new()
		if i < territory.current_stage:
			ind_style.bg_color = Color(0.2, 0.8, 0.2, 1)  # Completed
		elif i == territory.current_stage:
			ind_style.bg_color = Color(0.8, 0.8, 0.2, 1)  # Current
		else:
			ind_style.bg_color = Color(0.3, 0.3, 0.3, 1)  # Locked
		indicator.add_theme_stylebox_override("panel", ind_style)
		
		stage_indicators.add_child(indicator)
	
	progress_container.add_child(stage_indicators)
	
	return progress_container

func create_resource_production_section(territory) -> Control:
	"""Create compact resource production display"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 3)  # Reduced spacing
	
	if territory.is_controlled_by_player() and territory.is_unlocked:
		# Total production rate
		var rate_container = HBoxContainer.new()
		var rate_label = Label.new()
		rate_label.text = "Rate:"
		rate_label.add_theme_font_size_override("font_size", 9)  # Smaller font
		rate_container.add_child(rate_label)
		
		var rate_value = Label.new()
		rate_value.text = " %s/hr" % format_compact_number(territory.get_resource_rate())
		rate_value.modulate = Color.GREEN
		rate_value.add_theme_font_size_override("font_size", 9)  # Smaller font
		rate_container.add_child(rate_value)
		section.add_child(rate_container)
		
		# Resource breakdown using TerritoryManager
		if GameManager.territory_manager:
			var generation = GameManager.territory_manager.calculate_territory_passive_generation(territory)
			
			if generation.size() > 0:
				var breakdown_container = VBoxContainer.new()
				breakdown_container.add_theme_constant_override("separation", 1)
				
				# Limit to 3 most important resources to prevent overflow
				var sorted_resources = []
				for resource_type in generation:
					if generation[resource_type] > 0:
						sorted_resources.append([resource_type, generation[resource_type]])
				
				sorted_resources.sort_custom(func(a, b): return a[1] > b[1])
				
				var display_count = 0
				for res_data in sorted_resources:
					if display_count >= 3:  # Limit display
						break
					var res_line = create_resource_line(res_data[0], res_data[1])
					breakdown_container.add_child(res_line)
					display_count += 1
				
				if sorted_resources.size() > 3:
					var more_label = Label.new()
					more_label.text = "... and %d more" % (sorted_resources.size() - 3)
					more_label.add_theme_font_size_override("font_size", 9)
					more_label.modulate = Color.GRAY
					breakdown_container.add_child(more_label)
				
				section.add_child(breakdown_container)
		
		# Pending resources with collect button
		var pending = territory.get_pending_resources()
		if pending.size() > 0:
			var separator = HSeparator.new()
			separator.custom_minimum_size = Vector2(0, 1)  # Thinner separator
			section.add_child(separator)
			
			var pending_label = Label.new()
			pending_label.text = "💰 Pending:"
			pending_label.add_theme_font_size_override("font_size", 9)  # Smaller font
			pending_label.modulate = Color.CYAN
			section.add_child(pending_label)
			
			# Show first 2 pending resources with compact spacing
			var count = 0
			for resource_type in pending:
				if pending[resource_type] > 0 and count < 2:  # Reduced from 3 to 2
					var pending_line = create_resource_line(resource_type, pending[resource_type], Color.CYAN)
					section.add_child(pending_line)
					count += 1
			
			# Show "+X more" if there are additional resources
			if pending.size() > 2:
				var more_label = Label.new()
				more_label.text = "+%d more" % (pending.size() - 2)
				more_label.add_theme_font_size_override("font_size", 8)
				more_label.modulate = Color.GRAY
				section.add_child(more_label)
			
			var collect_btn = Button.new()
			collect_btn.text = "Collect"
			collect_btn.custom_minimum_size = Vector2(120, 24)  # Smaller button
			collect_btn.add_theme_font_size_override("font_size", 9)
			collect_btn.pressed.connect(_on_collect_resources.bind(territory))
			section.add_child(collect_btn)
	else:
		# Show potential resources when captured
		var potential_label = Label.new()
		potential_label.text = "Potential when captured:"
		potential_label.add_theme_font_size_override("font_size", 10)
		potential_label.modulate = Color.GRAY
		section.add_child(potential_label)
		
		# Show base generation for this territory
		var base_rate = territory.base_resource_rate * territory.tier
		var potential_value = Label.new()
		potential_value.text = "• Base: %d/hour" % base_rate
		potential_value.add_theme_font_size_override("font_size", 10)
		potential_value.modulate = Color.GRAY
		section.add_child(potential_value)
	
	return section

func create_resource_line(resource_type: String, amount: int, color: Color = Color.WHITE) -> HBoxContainer:
	"""Create a compact resource display line"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	
	var icon = Label.new()
	icon.text = get_resource_icon(resource_type)
	icon.add_theme_font_size_override("font_size", 9)
	line.add_child(icon)
	
	var name_label = Label.new()
	name_label.text = resource_type.replace("_", " ").capitalize()
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.custom_minimum_size = Vector2(60, 0)  # Reduced width
	line.add_child(name_label)
	
	var amount_label = Label.new()
	amount_label.text = "+%s" % format_compact_number(amount)  # Use compact number format
	amount_label.add_theme_font_size_override("font_size", 8)
	amount_label.modulate = color
	line.add_child(amount_label)
	
	return line

func create_role_assignment_section(territory) -> Control:
	"""Create enhanced role assignment display with auto-scaling"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	
	# Management button in top right of content
	var title_container = HBoxContainer.new()
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(spacer)
	
	if territory.is_controlled_by_player() and territory.is_unlocked:
		var manage_btn = Button.new()
		manage_btn.text = "Manage Roles"
		manage_btn.custom_minimum_size = Vector2(100, 24)
		manage_btn.add_theme_font_size_override("font_size", 11)
		if GameManager.territory_manager:
			manage_btn.pressed.connect(_on_open_role_management.bind(territory))
		else:
			manage_btn.pressed.connect(_on_manage_territory.bind(territory))
		title_container.add_child(manage_btn)
	
	section.add_child(title_container)
	
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		var locked_label = Label.new()
		locked_label.text = "Capture territory to assign gods"
		locked_label.add_theme_font_size_override("font_size", 10)
		locked_label.modulate = Color.GRAY
		section.add_child(locked_label)
		return section
	
	# Role slots display
	if GameManager.territory_manager:
		var slot_config = GameManager.territory_manager.get_territory_slot_configuration(territory)
		var assignments = GameManager.territory_manager.get_territory_role_assignments(territory)
		
		# Create role displays
		for role in ["defender", "gatherer", "crafter"]:
			if slot_config[role + "_slots"] > 0:
				var role_display = create_role_display(role, assignments[role], slot_config[role + "_slots"], territory)
				section.add_child(role_display)
		
		# Efficiency summary
		var separator = HSeparator.new()
		section.add_child(separator)
		
		var efficiency_summary = GameManager.territory_manager.get_territory_efficiency_summary(territory)
		
		var efficiency_label = Label.new()
		efficiency_label.text = "Efficiency: %d/%d slots used" % [
			efficiency_summary.total_slots_used,
			efficiency_summary.total_slots_available
		]
		efficiency_label.add_theme_font_size_override("font_size", 10)
		
		if efficiency_summary.total_slots_used < efficiency_summary.total_slots_available:
			efficiency_label.modulate = Color.YELLOW
		else:
			efficiency_label.modulate = Color.GREEN
		
		section.add_child(efficiency_label)
	else:
		# Legacy display
		var slots_label = Label.new()
		slots_label.text = "Slots: %d/%d" % [territory.stationed_gods.size(), territory.max_god_slots]
		slots_label.add_theme_font_size_override("font_size", 11)
		section.add_child(slots_label)
	
	return section

func create_role_display(role: String, gods: Array, max_slots: int, territory: Territory) -> Control:
	"""Create a role assignment display"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	
	# Role header
	var header = HBoxContainer.new()
	
	var icon_label = Label.new()
	icon_label.text = get_role_icon(role)
	icon_label.add_theme_font_size_override("font_size", 14)
	header.add_child(icon_label)
	
	var role_label = Label.new()
	role_label.text = " %s" % role.capitalize()
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.modulate = get_role_color(role)
	header.add_child(role_label)
	
	var count_label = Label.new()
	count_label.text = " (%d/%d)" % [gods.size(), max_slots]
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.modulate = Color.WHITE if gods.size() < max_slots else Color.GREEN
	header.add_child(count_label)
	
	container.add_child(header)
	
	# God list or empty slots
	if gods.size() > 0:
		for god in gods:
			var god_line = create_god_assignment_line(god, role, territory)
			container.add_child(god_line)
	else:
		var empty_label = Label.new()
		empty_label.text = "  • Empty slots"
		empty_label.add_theme_font_size_override("font_size", 9)
		empty_label.modulate = Color.GRAY
		container.add_child(empty_label)
	
	return container

func create_god_assignment_line(god: God, role: String, territory: Territory) -> HBoxContainer:
	"""Create a god assignment display line"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	
	# Indent
	var indent = Control.new()
	indent.custom_minimum_size = Vector2(15, 0)
	line.add_child(indent)
	
	# Element match indicator
	var match_label = Label.new()
	if god.element == territory.element:
		match_label.text = "★"
		match_label.modulate = Color.YELLOW
	else:
		match_label.text = "•"
		match_label.modulate = Color.GRAY
	match_label.add_theme_font_size_override("font_size", 10)
	line.add_child(match_label)
	
	# God name
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [god.name, god.level]
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.custom_minimum_size = Vector2(120, 0)
	line.add_child(name_label)
	
	# Contribution hint
	if GameManager.territory_manager:
		var contribution = GameManager.territory_manager.calculate_god_contribution(god, role, territory)
		if contribution.size() > 0:
			var contrib_label = Label.new()
			var total = 0
			for amount in contribution.values():
				total += amount
			contrib_label.text = "+%d/hr" % total
			contrib_label.add_theme_font_size_override("font_size", 8)
			contrib_label.modulate = Color.GREEN
			line.add_child(contrib_label)
	
	return line

func create_action_section(territory) -> Control:
	"""Create the action buttons section with better organization"""
	var section = VBoxContainer.new()
	section.custom_minimum_size = Vector2(140, 0)
	section.size_flags_horizontal = Control.SIZE_SHRINK_END
	section.add_theme_constant_override("separation", 6)
	
	# Battle/Stage section
	if territory.is_controlled_by_player() and territory.is_unlocked:
		# Farm stages button
		var farm_container = create_enhanced_stage_selector(territory)
		section.add_child(farm_container)
		
		# Upgrade buttons
		if territory.can_upgrade_territory() or territory.can_upgrade_resource_generation():
			var upgrade_container = VBoxContainer.new()
			upgrade_container.add_theme_constant_override("separation", 4)
			
			var upgrade_label = Label.new()
			upgrade_label.text = "⬆️ Upgrades"
			upgrade_label.add_theme_font_size_override("font_size", 11)
			upgrade_label.modulate = Color.CYAN
			upgrade_container.add_child(upgrade_label)
			
			if territory.can_upgrade_territory():
				var terr_btn = Button.new()
				terr_btn.text = "Territory Lv.%d→%d" % [territory.territory_level, territory.territory_level + 1]
				terr_btn.custom_minimum_size = Vector2(140, 26)
				terr_btn.add_theme_font_size_override("font_size", 9)
				terr_btn.pressed.connect(func(): territory.upgrade_territory(); refresh_territories())
				upgrade_container.add_child(terr_btn)
			
			if territory.can_upgrade_resource_generation():
				var res_btn = Button.new()
				res_btn.text = "Resources +8%%"
				res_btn.custom_minimum_size = Vector2(140, 26)
				res_btn.add_theme_font_size_override("font_size", 9)
				res_btn.pressed.connect(func(): territory.upgrade_resource_generation(); refresh_territories())
				upgrade_container.add_child(res_btn)
			
			section.add_child(upgrade_container)
	
	elif territory.current_stage >= territory.max_stages and not territory.is_unlocked:
		# Claim button
		var claim_btn = Button.new()
		claim_btn.text = "🏆 CLAIM\nTERRITORY"
		claim_btn.custom_minimum_size = Vector2(140, 60)
		claim_btn.modulate = Color.GREEN
		claim_btn.add_theme_font_size_override("font_size", 12)
		claim_btn.pressed.connect(_on_claim_territory.bind(territory))
		section.add_child(claim_btn)
	
	elif territory.can_be_attacked() or territory.current_stage > 0:
		# Stage selector for progression
		var stage_container = create_enhanced_stage_selector(territory)
		section.add_child(stage_container)
	
	else:
		# Locked display - Use level-based unlocking (MYTHOS ARCHITECTURE)
		var locked_btn = Button.new()
		var _player_level = _get_player_level()  # Not currently used in display
		var required_level = _get_territory_unlock_level(territory)
		locked_btn.text = "🔒 LOCKED\nLevel %d Required" % required_level
		locked_btn.custom_minimum_size = Vector2(140, 60)
		locked_btn.modulate = Color.GRAY
		locked_btn.add_theme_font_size_override("font_size", 10)
		locked_btn.disabled = true
		section.add_child(locked_btn)
	
	return section

func create_combat_farming_section(territory) -> Control:
	"""Create the combat and farming section with auto-scaling"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	
	# Battle/Stage section
	if territory.is_controlled_by_player() and territory.is_unlocked:
		# Farm stages button
		var farm_container = create_enhanced_stage_selector(territory)
		section.add_child(farm_container)
		
	elif territory.current_stage >= territory.max_stages and not territory.is_unlocked:
		# Claim button
		var claim_btn = Button.new()
		claim_btn.text = "🏆 CLAIM TERRITORY"
		claim_btn.custom_minimum_size = Vector2(160, 40)
		claim_btn.modulate = Color.GREEN
		claim_btn.add_theme_font_size_override("font_size", 13)
		claim_btn.pressed.connect(_on_claim_territory.bind(territory))
		section.add_child(claim_btn)
	
	elif territory.can_be_attacked() or territory.current_stage > 0:
		# Stage selector for progression
		var stage_container = create_enhanced_stage_selector(territory)
		section.add_child(stage_container)
	
	else:
		# Locked display - Use level-based unlocking (MYTHOS ARCHITECTURE)
		var locked_btn = Button.new()
		var required_level = _get_territory_unlock_level(territory)
		locked_btn.text = "🔒 LOCKED\nLevel %d Required" % required_level
		locked_btn.custom_minimum_size = Vector2(120, 50)
		locked_btn.modulate = Color.GRAY
		locked_btn.add_theme_font_size_override("font_size", 10)
		locked_btn.disabled = true
		section.add_child(locked_btn)
	
	return section

func create_upgrade_section(territory) -> Control:
	"""Create the upgrades section with auto-scaling"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	
	# Only show upgrades if controlled
	if territory.is_controlled_by_player() and territory.is_unlocked:
		# Upgrade buttons
		if territory.can_upgrade_territory() or territory.can_upgrade_resource_generation():
			if territory.can_upgrade_territory():
				var terr_btn = Button.new()
				terr_btn.text = "Territory Lv.%d→%d" % [territory.territory_level, territory.territory_level + 1]
				terr_btn.custom_minimum_size = Vector2(160, 30)
				terr_btn.add_theme_font_size_override("font_size", 11)
				terr_btn.pressed.connect(func(): territory.upgrade_territory(); refresh_territories())
				section.add_child(terr_btn)
			
			if territory.can_upgrade_resource_generation():
				var res_btn = Button.new()
				res_btn.text = "Resources +8% Generation"
				res_btn.custom_minimum_size = Vector2(160, 30)
				res_btn.add_theme_font_size_override("font_size", 11)
				res_btn.pressed.connect(func(): territory.upgrade_resource_generation(); refresh_territories())
				section.add_child(res_btn)
		else:
			# No upgrades available
			var no_upgrades = Label.new()
			no_upgrades.text = "No upgrades\navailable"
			no_upgrades.add_theme_font_size_override("font_size", 10)
			no_upgrades.modulate = Color.GRAY
			no_upgrades.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			section.add_child(no_upgrades)
	else:
		# Not controlled
		var not_controlled = Label.new()
		not_controlled.text = "Capture territory\nto unlock upgrades"
		not_controlled.add_theme_font_size_override("font_size", 10)
		not_controlled.modulate = Color.GRAY
		not_controlled.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(not_controlled)
	
	return section

# ==============================================================================
# UTILITY METHODS
# ==============================================================================

func _calculate_player_power() -> int:
	"""Calculate total player power from all gods"""
	var total_power = 0
	if GameManager and GameManager.player_data:
		if GameManager.player_data.has_method("get_total_power"):
			total_power = GameManager.player_data.get_total_power()
		else:
			for god in GameManager.player_data.gods:
				if god.has_method("get_power_rating"):
					total_power += god.get_power_rating()
				elif god.has_method("get_total_power"):
					total_power += god.get_total_power()
				else:
					# Fallback calculation
					total_power += god.base_hp + god.base_attack + god.base_defense + god.base_speed
	return total_power

func _find_strongest_available_god():
	"""Find the strongest god not assigned to any territory"""
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
				# Fallback calculation
				power = god.base_hp + god.base_attack + god.base_defense + god.base_speed
			
			if power > highest_power:
				highest_power = power
				strongest_god = god
	
	return strongest_god

func _find_god_by_id(god_id: String):
	"""Find a god by their ID"""
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			if god.id == god_id:
				return god
	return null

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
		print("Invalid battle setup context")
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
	"""Handle return from battle screen"""
	# Return to territory screen and refresh
	visible = true
	
	# Disconnect signal to prevent any issues during cleanup
	if battle_screen.back_pressed.is_connected(_on_battle_screen_back):
		battle_screen.back_pressed.disconnect(_on_battle_screen_back)
	
	battle_screen.queue_free()
	refresh_territories()

func populate_god_assignment_list(territory):
	"""Populate the legacy god assignment popup"""
	# Use direct reference to god list
	if not popup_god_list:
		print("Error: popup_god_list not found")
		return
	
	for child in popup_god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Add spacing between god items
	popup_god_list.add_theme_constant_override("separation", 5)
	
	# Get all player gods
	if not GameManager or not GameManager.player_data:
		print("Error: GameManager or player_data not found")
		return
	
	# Add gods that aren't already stationed elsewhere
	var available_gods = 0
	for god in GameManager.player_data.gods:
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
	"""Create a god assignment item for the legacy popup"""
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
	"""Handle god checkbox toggle in legacy popup"""
	if checked:
		if not selected_gods.has(god_id):
			selected_gods.append(god_id)
	else:
		selected_gods.erase(god_id)
	
	print("Selected gods: ", selected_gods)

func _on_confirm_assignment():
	"""Confirm god assignments in legacy popup"""
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
				god.stationed_territory = ""
	
	print("Assigned gods to %s: %s" % [current_territory.name, selected_gods])
	
	# Close popup and refresh display
	god_assignment_popup.hide()
	refresh_territories()

func _on_cancel_assignment():
	"""Cancel god assignments in legacy popup"""
	selected_gods.clear()
	god_assignment_popup.hide()

func create_enhanced_stage_selector(territory) -> Control:
	"""Create an enhanced stage selector with better visuals"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	
	# Title
	var title = Label.new()
	if territory.is_controlled_by_player() and territory.is_unlocked:
		title.text = "🔄 Farm Stages"
	else:
		title.text = "⚔️ Battle Stages"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color.ORANGE
	container.add_child(title)
	
	# Stage selector
	var stage_container = HBoxContainer.new()
	stage_container.add_theme_constant_override("separation", 4)
	
	# Get current selected stage
	if not territory.has_meta("selected_stage"):
		territory.set_meta("selected_stage", max(1, territory.current_stage))
	var selected_stage = territory.get_meta("selected_stage")
	
	# Previous button
	var prev_btn = Button.new()
	prev_btn.text = "◄"
	prev_btn.custom_minimum_size = Vector2(30, 30)
	prev_btn.add_theme_font_size_override("font_size", 12)
	prev_btn.pressed.connect(_on_stage_navigation.bind(territory, -1))
	prev_btn.disabled = (selected_stage <= 1)
	stage_container.add_child(prev_btn)
	
	# Stage display
	var stage_display = Button.new()
	stage_display.custom_minimum_size = Vector2(80, 30)
	stage_display.add_theme_font_size_override("font_size", 11)
	
	# Update stage display based on status
	if selected_stage <= territory.current_stage:
		stage_display.text = "Stage %d" % selected_stage
		stage_display.modulate = Color.ORANGE
		stage_display.pressed.connect(_on_attack_stage.bind(territory, selected_stage))
	elif selected_stage == territory.current_stage + 1:
		stage_display.text = "Stage %d" % selected_stage
		stage_display.modulate = Color.RED
		stage_display.pressed.connect(_on_attack_stage.bind(territory, selected_stage))
	else:
		stage_display.text = "Locked"
		stage_display.modulate = Color.GRAY
		stage_display.disabled = true
	
	stage_container.add_child(stage_display)
	
	# Next button
	var next_btn = Button.new()
	next_btn.text = "►"
	next_btn.custom_minimum_size = Vector2(30, 30)
	next_btn.add_theme_font_size_override("font_size", 12)
	next_btn.pressed.connect(_on_stage_navigation.bind(territory, 1))
	
	var max_available = territory.max_stages if (territory.is_controlled_by_player() and territory.is_unlocked) else min(territory.current_stage + 1, territory.max_stages)
	next_btn.disabled = (selected_stage >= max_available)
	stage_container.add_child(next_btn)
	
	container.add_child(stage_container)
	
	# Stage info
	var info_label = Label.new()
	if selected_stage <= territory.current_stage:
		info_label.text = "Farming mode"
		info_label.modulate = Color.ORANGE
	else:
		info_label.text = "New challenge!"
		info_label.modulate = Color.CYAN
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(info_label)
	
	return container

func get_element_icon(element: Territory.ElementType) -> String:
	"""Get icon for element type"""
	match element:
		Territory.ElementType.FIRE: return "🔥"
		Territory.ElementType.WATER: return "💧"
		Territory.ElementType.EARTH: return "🌿"
		Territory.ElementType.LIGHTNING: return "⚡"
		Territory.ElementType.LIGHT: return "✨"
		Territory.ElementType.DARK: return "🌙"
		_: return "◆"

func get_resource_icon(resource_type: String) -> String:
	"""Get icon for resource type"""
	if "powder" in resource_type: return "✨"
	elif "soul" in resource_type: return "👻"
	elif "ore" in resource_type: return "⛏️"
	elif "mana" in resource_type: return "💎"
	elif "crystal" in resource_type: return "💠"
	elif "energy" in resource_type: return "⚡"
	else: return "•"

func get_role_icon(role: String) -> String:
	"""Get icon for role type"""
	match role:
		"defender": return "🛡️"
		"gatherer": return "⛏️"
		"crafter": return "🔨"
		_: return "•"

func get_role_color(role: String) -> Color:
	"""Get color for role type"""
	match role:
		"defender": return Color.RED
		"gatherer": return Color.GREEN
		"crafter": return Color.BLUE
		_: return Color.WHITE

# ==============================================================================
# PROGRESSION SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _get_player_level() -> int:
	"""Get current player level from ProgressionManager"""
	if GameManager and GameManager.progression_manager:
		return GameManager.progression_manager.get_current_level()
	elif GameManager and GameManager.player_data:
		# Fallback: calculate from experience if ProgressionManager not available
		var xp = GameManager.player_data.get_resource("player_experience")
		return max(1, int(xp / 100))  # Simple formula: 100 XP per level
	return 1  # Default to level 1

func _get_territory_unlock_level(territory: Territory) -> int:
	"""Get the required player level to unlock this territory - delegates to ProgressionManager"""
	# Use ProgressionManager for territory progression logic (MYTHOS ARCHITECTURE)
	if GameManager and GameManager.progression_manager:
		return GameManager.progression_manager.get_territory_unlock_level(territory.id)
	
	# Fallback: use tier-based levels
	return max(1, territory.tier)
