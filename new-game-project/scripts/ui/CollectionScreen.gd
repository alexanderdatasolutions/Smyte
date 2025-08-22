# scripts/ui/CollectionScreen.gd
extends Control

signal back_pressed

@onready var grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
@onready var back_button = $BackButton
@onready var details_content = $MainContainer/RightPanel/DetailsContainer/DetailsContent
@onready var no_selection_label = $MainContainer/RightPanel/DetailsContainer/DetailsContent/NoSelectionLabel

func _ready():
	print("DEBUG: CollectionScreen._ready() starting...")
	# Connect to GameManager signals for modular communication
	if GameManager:
		GameManager.god_summoned.connect(_on_god_summoned)
		GameManager.resources_updated.connect(_on_resources_updated)  # Refresh when XP is awarded
		print("DEBUG: GameManager signals connected")
		# Also connect to collection changes if you add that signal
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("DEBUG: Back button connected")
	else:
		print("DEBUG: Back button NOT found")
		
	print("DEBUG: Calling refresh_collection()...")
	refresh_collection()
	print("DEBUG: Calling show_no_selection()...")
	show_no_selection()
	print("DEBUG: CollectionScreen._ready() completed")

func _on_back_pressed():
	back_pressed.emit()

func _on_god_summoned(_god):
	# When a new god is summoned, refresh the collection display
	refresh_collection()

func _on_resources_updated():
	# When resources are updated (including XP), refresh the collection
	refresh_collection()

func show_no_selection():
	# Show the default "no selection" message
	if not details_content:
		return
		
	for child in details_content.get_children():
		child.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	var no_selection = Label.new()
	no_selection.text = "Click on a god to view details"
	no_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_selection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_selection.add_theme_font_size_override("font_size", 16)
	details_content.add_child(no_selection)

func refresh_collection():
	print("DEBUG: refresh_collection() starting...")
	# Make sure the grid_container exists
	if not grid_container:
		grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
		if not grid_container:
			print("Error: Could not find GridContainer")
			return
	
	print("DEBUG: GridContainer found, clearing existing cards...")
	# Clear existing god cards
	for child in grid_container.get_children():
		child.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Add god cards - using GameManager autoload for modular access
	if GameManager and GameManager.player_data:
		print("DEBUG: Found GameManager and player_data, gods count: ", GameManager.player_data.gods.size())
		for god in GameManager.player_data.gods:
			print("DEBUG: Creating card for god: ", god.name)
			create_god_card(god)
	else:
		print("DEBUG: GameManager or player_data not available")
	print("DEBUG: refresh_collection() completed")

func create_god_card(god):
	print("DEBUG: create_god_card() starting for: ", god.name)
	var card = VBoxContainer.new()
	card.custom_minimum_size = Vector2(150, 260)  # Increased height for XP bar
	print("DEBUG: Created VBoxContainer with size: ", card.custom_minimum_size)
	
	# Create a button that will serve as the clickable panel background
	var panel = Button.new()
	panel.flat = false  # Keep button styling to show rarity colors properly
	panel.pressed.connect(_on_god_card_clicked.bind(god))
	print("DEBUG: Created panel button, flat=", panel.flat)
	
	# Style the button to show rarity colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_tier_color(god.tier)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color.WHITE
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	print("DEBUG: Created style with bg_color: ", style.bg_color)
	
	# Apply the style to all button states to ensure consistent coloring
	panel.add_theme_stylebox_override("normal", style)
	panel.add_theme_stylebox_override("hover", style)
	panel.add_theme_stylebox_override("pressed", style)
	panel.add_theme_stylebox_override("focus", style)
	panel.custom_minimum_size = Vector2(150, 260)  # Increased height for XP bar
	
	print("DEBUG: Adding panel to card...")
	card.add_child(panel)
	
	print("DEBUG: Adding card to grid_container...")
	grid_container.add_child(card)
	print("DEBUG: create_god_card() completed for: ", god.name, ", grid children now: ", grid_container.get_child_count())
	
	# Create a margin container for padding
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	
	# Create inner VBox for content
	var content = VBoxContainer.new()
	
	# God Image
	var image_container = TextureRect.new()
	image_container.custom_minimum_size = Vector2(120, 120)
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Load god image - use god name in lowercase for filename matching
	var image_path = "res://assets/gods/" + god.name.to_lower() + ".png"
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		image_container.texture = texture
	else:
		# Fallback - create a colored rectangle if image not found
		var placeholder = ColorRect.new()
		placeholder.color = get_tier_color(god.tier)
		placeholder.custom_minimum_size = Vector2(120, 120)
		content.add_child(placeholder)
		image_container = null
	
	if image_container:
		content.add_child(image_container)
	
	# Name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 14)
	content.add_child(name_label)
	
	# Tier and Element
	var info_label = Label.new()
	info_label.text = god.get_tier_name() + " " + god.get_element_name()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_font_size_override("font_size", 10)
	content.add_child(info_label)
	
	# Level and Power
	var level_label = Label.new()
	level_label.text = "Lv." + str(god.level) + " Power: " + str(god.get_power_rating())
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_font_size_override("font_size", 9)
	content.add_child(level_label)
	
	# XP Progress Bar
	var xp_container = VBoxContainer.new()
	
	# XP Label
	var xp_label = Label.new()
	var xp_needed = god.get_experience_to_next_level()
	var xp_progress = god.experience
	xp_label.text = "XP: %d / %d" % [xp_progress, xp_needed]
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_color_override("font_color", Color.YELLOW)
	xp_label.add_theme_font_size_override("font_size", 8)
	xp_container.add_child(xp_label)
	
	# XP Progress Bar
	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(120, 8)
	xp_bar.min_value = 0
	xp_bar.max_value = xp_needed
	xp_bar.value = xp_progress
	xp_bar.show_percentage = false
	
	# Style the XP bar
	var xp_bar_style = StyleBoxFlat.new()
	xp_bar_style.bg_color = Color(0.2, 0.2, 0.8, 0.8)  # Blue background
	xp_bar_style.corner_radius_top_left = 4
	xp_bar_style.corner_radius_top_right = 4
	xp_bar_style.corner_radius_bottom_left = 4
	xp_bar_style.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", xp_bar_style)
	
	var xp_bg_style = StyleBoxFlat.new()
	xp_bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark background
	xp_bg_style.corner_radius_top_left = 4
	xp_bg_style.corner_radius_top_right = 4
	xp_bg_style.corner_radius_bottom_left = 4
	xp_bg_style.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("background", xp_bg_style)
	
	xp_container.add_child(xp_bar)
	content.add_child(xp_container)
	
	# Assemble the card
	margin_container.add_child(content)
	panel.add_child(margin_container)
	card.add_child(panel)
	
	grid_container.add_child(card)

func _on_god_card_clicked(god: God):
	# Show detailed god information in side panel
	show_god_details_in_panel(god)

func show_god_details_in_panel(god: God):
	# Clear existing details
	if not details_content:
		return
		
	for child in details_content.get_children():
		child.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Create content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	
	# God Image
	var image_container = TextureRect.new()
	image_container.custom_minimum_size = Vector2(200, 200)
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Load god image
	var image_path = "res://assets/gods/" + god.name.to_lower() + ".png"
	if ResourceLoader.exists(image_path):
		var texture = load(image_path)
		image_container.texture = texture
	else:
		# Fallback - create a colored rectangle
		var placeholder = ColorRect.new()
		placeholder.color = get_tier_color(god.tier)
		placeholder.custom_minimum_size = Vector2(200, 200)
		content.add_child(placeholder)
		image_container = null
	
	if image_container:
		content.add_child(image_container)
	
	# Basic Info Section
	var info_section = VBoxContainer.new()
	var info_title = Label.new()
	info_title.text = "═══ " + god.name.to_upper() + " ═══"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", get_tier_color(god.tier))
	info_section.add_child(info_title)
	
	var basic_info = Label.new()
	basic_info.text = """Pantheon: %s
Element: %s
Tier: %s
Level: %d
Power: %d""" % [
		god.pantheon, god.get_element_name(), 
		god.get_tier_name(), god.level, god.get_power_rating()
	]
	basic_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_section.add_child(basic_info)
	content.add_child(info_section)
	
	# XP Section
	var xp_section = VBoxContainer.new()
	var xp_title = Label.new()
	xp_title.text = "═══ EXPERIENCE ═══"
	xp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_section.add_child(xp_title)
	
	var xp_needed = god.get_experience_to_next_level()
	var xp_progress = god.experience
	var xp_info = Label.new()
	xp_info.text = """Current XP: %d
Next Level: %d
Progress: %.1f%%""" % [
		xp_progress, xp_needed, 
		(float(xp_progress) / float(xp_needed)) * 100.0
	]
	xp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_section.add_child(xp_info)
	
	# XP Progress Bar
	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 20)
	xp_bar.min_value = 0
	xp_bar.max_value = xp_needed
	xp_bar.value = xp_progress
	xp_bar.show_percentage = true
	
	# Style the XP bar
	var xp_bar_style = StyleBoxFlat.new()
	xp_bar_style.bg_color = Color(0.2, 0.2, 0.8, 0.8)
	xp_bar_style.corner_radius_top_left = 4
	xp_bar_style.corner_radius_top_right = 4
	xp_bar_style.corner_radius_bottom_left = 4
	xp_bar_style.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", xp_bar_style)
	
	xp_section.add_child(xp_bar)
	content.add_child(xp_section)
	
	# Combat Stats Section  
	var stats_section = VBoxContainer.new()
	var stats_title = Label.new()
	stats_title.text = "═══ COMBAT STATS ═══"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_section.add_child(stats_title)
	
	var stats_info = Label.new()
	stats_info.text = """HP: %d
Attack: %d
Defense: %d
Speed: %d
Territory: %s""" % [
		god.get_max_hp(), god.get_current_attack(), 
		god.get_current_defense(), god.get_current_speed(),
		god.stationed_territory if god.stationed_territory != "" else "Unassigned"
	]
	stats_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_section.add_child(stats_info)
	content.add_child(stats_section)
	
	# Abilities Section
	if god.has_valid_abilities():
		var abilities_section = VBoxContainer.new()
		var abilities_title = Label.new()
		abilities_title.text = "═══ ABILITIES ═══"
		abilities_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		abilities_title.add_theme_font_size_override("font_size", 14)
		abilities_section.add_child(abilities_title)
		
		for ability in god.active_abilities:
			var ability_container = VBoxContainer.new()
			ability_container.add_theme_constant_override("separation", 2)
			
			var ability_name = Label.new()
			ability_name.text = "• " + ability.get("name", "Unknown")
			ability_name.add_theme_font_size_override("font_size", 12)
			ability_name.add_theme_color_override("font_color", Color.YELLOW)
			ability_container.add_child(ability_name)
			
			var ability_desc = Label.new()
			ability_desc.text = "  " + ability.get("description", "No description")
			ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ability_desc.custom_minimum_size.x = 300
			ability_desc.add_theme_font_size_override("font_size", 10)
			ability_container.add_child(ability_desc)
			
			abilities_section.add_child(ability_container)
		
		content.add_child(abilities_section)
	
	# Add content to details panel
	details_content.add_child(content)

func get_tier_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color.GRAY
		1:  # RARE
			return Color.BLUE
		2:  # EPIC
			return Color.PURPLE
		3:  # LEGENDARY
			return Color.GOLD
		_:
			return Color.WHITE
