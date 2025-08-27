# scripts/ui/CollectionScreen.gd
extends Control

signal back_pressed

@onready var grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
@onready var back_button = $BackButton
@onready var details_content = $MainContainer/RightPanel/DetailsContainer/DetailsContent
@onready var no_selection_label = $MainContainer/RightPanel/DetailsContainer/DetailsContent/NoSelectionLabel

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)
var sort_buttons = []  # Store references to sort buttons
var direction_button = null  # Store reference to direction button

# Scroll position preservation
var scroll_position: float = 0.0

func _ready():
	# Connect to EventBus signals for modular communication
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus and event_bus.has_signal("god_obtained"):
		event_bus.god_obtained.connect(_on_god_summoned)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Add sorting UI
	setup_sorting_ui()
	refresh_collection()
	show_no_selection()

func _on_back_pressed():
	back_pressed.emit()

func _on_god_summoned(_god):
	# When a new god is summoned, refresh the collection display
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

func setup_sorting_ui():
	"""Add sorting controls to the collection screen - only called once"""
	# Check if sorting UI already exists
	var left_panel_vbox = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer
	if not left_panel_vbox:
		return
	
	# Don't create if already exists
	if sort_buttons.size() > 0:
		return
	
	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 10)
	
	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort by:"
	sort_label.add_theme_font_size_override("font_size", 14)
	sort_container.add_child(sort_label)
	
	# Create sort buttons
	var button_configs = [
		{"text": "Power", "type": SortType.POWER},
		{"text": "Level", "type": SortType.LEVEL}, 
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Element", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for button_data in button_configs:
		var sort_button = Button.new()
		sort_button.text = button_data.text
		sort_button.custom_minimum_size = Vector2(60, 30)
		sort_button.pressed.connect(_on_sort_changed.bind(button_data.type))
		sort_buttons.append(sort_button)
		sort_container.add_child(sort_button)
	
	# Add sort direction button
	direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(30, 30)
	direction_button.pressed.connect(_on_sort_direction_changed)
	sort_container.add_child(direction_button)
	
	# Insert sorting controls at the top of the VBox (before GridContainer)
	left_panel_vbox.add_child(sort_container)
	left_panel_vbox.move_child(sort_container, 0)
	
	# Initial button highlighting
	update_sort_buttons()

func update_sort_buttons():
	"""Update the visual state of sort buttons"""
	for i in range(sort_buttons.size()):
		var button = sort_buttons[i]
		var button_type = [SortType.POWER, SortType.LEVEL, SortType.TIER, SortType.ELEMENT, SortType.NAME][i]
		
		if button_type == current_sort:
			# Highlight current sort
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			button.add_theme_stylebox_override("normal", style)
		else:
			# Remove highlight
			button.remove_theme_stylebox_override("normal")
	
	# Update direction button
	if direction_button:
		direction_button.text = "↓" if not sort_ascending else "↑"

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	refresh_collection()
	# Update button highlighting
	update_sort_buttons()

func _on_sort_direction_changed():
	"""Toggle sort direction"""
	sort_ascending = !sort_ascending
	refresh_collection()
	# Update direction arrow
	update_sort_buttons()

func refresh_collection():
	# Make sure the grid_container exists
	if not grid_container:
		grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
		if not grid_container:
			print("Error: Could not find GridContainer")
			return
	
	# Save scroll position
	var scroll_container = grid_container.get_parent().get_parent()  # VBoxContainer -> ScrollContainer
	if scroll_container is ScrollContainer:
		scroll_position = scroll_container.get_v_scroll()
	
	# Clear existing god cards instantly
	for child in grid_container.get_children():
		child.queue_free()
	
	# Start batched loading for instant response
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if collection_manager:
		load_collection_gods_batched()
	
	# Restore scroll position after a frame
	await get_tree().process_frame
	if scroll_container is ScrollContainer:
		scroll_container.set_v_scroll(int(scroll_position))

func load_collection_gods_batched():
	"""Load collection gods using cached cards for instant display"""
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if not collection_manager or not grid_container:
		print("CollectionScreen: CollectionManager not available")
		return
	
	var gods = collection_manager.get_all_gods().duplicate()
	sort_gods(gods)
	
	# For now, use fallback loading until we implement caching in the new architecture
	load_collection_gods_batched_fallback(gods)

func load_collection_gods_from_cache(gods: Array):
	"""Load gods instantly from pre-cached cards"""
	# For now, create god cards directly since GameManager caching is deprecated
	# TODO: Implement UICardFactory caching system per prompt.prompt.md
	for god in gods:
		create_god_card(god)

func load_collection_gods_batched_fallback(gods: Array):
	"""Fallback batched loading if cache isn't ready"""
	# Load gods in smaller batches for ultra-smooth loading
	var batch_size = 8  # Smaller batches for ultra-smooth loading
	var batch_state = {"current_batch": 0}  # Use dictionary for reference
	
	var batch_timer = Timer.new()
	batch_timer.wait_time = 0.008  # ~120 FPS (8ms per frame)
	batch_timer.timeout.connect(func():
		var start_idx = batch_state.current_batch * batch_size
		var end_idx = min(start_idx + batch_size, gods.size())
		
		# Load this batch
		for i in range(start_idx, end_idx):
			var god = gods[i]
			create_god_card(god)
		
		batch_state.current_batch += 1
		
		# Check if we're done
		if end_idx >= gods.size():
			batch_timer.queue_free()
	)
	
	add_child(batch_timer)
	batch_timer.start()

func add_click_handler_to_cached_card(card: Control, god: God, callback: Callable):
	"""Add a click handler to a cached card"""
	# Find the existing button in the cached card
	var button = find_button_in_card(card)
	if button:
		# Clear any existing connections first
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		# Connect the new callback
		button.pressed.connect(callback.bind(god))
	else:
		print("Warning: Could not find button in cached card for god: ", god.name)

func find_button_in_card(card: Control) -> Button:
	"""Recursively find the button in a cached card"""
	if card is Button:
		return card
	
	for child in card.get_children():
		var result = find_button_in_card(child)
		if result:
			return result
	
	return null

func sort_gods(gods: Array):
	"""Sort gods array based on current sort settings"""
	gods.sort_custom(func(a, b):
		var result = false
		match current_sort:
			SortType.POWER:
				result = a.get_power_rating() > b.get_power_rating()
			SortType.LEVEL:
				result = a.level > b.level
			SortType.TIER:
				result = a.tier > b.tier
			SortType.ELEMENT:
				result = a.element < b.element  # Sort by element enum value
			SortType.NAME:
				result = a.name < b.name
		
		# Apply sort direction
		return result if not sort_ascending else !result
	)

func create_god_card(god):
	# Create compact card similar to other screens
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style with subtle tier colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_subtle_tier_color(god.tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = get_tier_border_color(god.tier)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)
	
	# Add margin for better spacing
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)
	margin.add_child(vbox)
	
	# God image (compact)
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god image using the new sprite function
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	
	vbox.add_child(god_image)
	
	# God name (compact)
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier (compact, SW style)
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Element and power (compact)
	var info_label = Label.new()
	info_label.text = "%s P:%d" % [get_element_short_name(god.element), god.get_power_rating()]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_card_clicked.bind(god))
	card.add_child(button)
	
	grid_container.add_child(card)

func get_subtle_tier_color(tier: int) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		0:  # COMMON
			return Color(0.25, 0.25, 0.25, 0.7)  # Dark gray
		1:  # RARE
			return Color(0.2, 0.3, 0.2, 0.7)     # Dark green
		2:  # EPIC
			return Color(0.3, 0.2, 0.4, 0.7)     # Dark purple
		3:  # LEGENDARY
			return Color(0.4, 0.3, 0.1, 0.7)     # Dark gold
		_:
			return Color(0.2, 0.2, 0.3, 0.7)

func get_tier_border_color(tier: int) -> Color:
	"""Get border colors for tiers"""
	match tier:
		0:  # COMMON
			return Color(0.5, 0.5, 0.5, 0.8)     # Gray
		1:  # RARE
			return Color(0.4, 0.8, 0.4, 1.0)     # Green
		2:  # EPIC
			return Color(0.7, 0.4, 1.0, 1.0)     # Purple
		3:  # LEGENDARY
			return Color(1.0, 0.8, 0.2, 1.0)     # Gold
		_:
			return Color(0.6, 0.6, 0.6, 0.8)

func get_tier_short_name(tier: int) -> String:
	"""Get short tier names for compact display"""
	match tier:
		0: return "★"      # COMMON
		1: return "★★"     # RARE  
		2: return "★★★"    # EPIC
		3: return "★★★★"   # LEGENDARY
		_: return "?"

func get_element_short_name(element: int) -> String:
	"""Get short element names for compact display"""
	match element:
		0: return "🔥"  # FIRE
		1: return "💧"  # WATER
		2: return "🌍"  # EARTH
		3: return "⚡"  # LIGHTNING
		4: return "☀️"  # LIGHT
		5: return "🌙"  # DARK
		_: return "?"

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
	
	# Load god image using the new sprite function
	var god_texture = god.get_sprite()
	if god_texture:
		image_container.texture = god_texture
	else:
		# Fallback - create a colored rectangle
		var placeholder = ColorRect.new()
		placeholder.color = get_tier_border_color(god.tier)
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
	info_title.add_theme_color_override("font_color", get_tier_border_color(god.tier))
	info_section.add_child(info_title)
	
	var basic_info = Label.new()
	basic_info.text = """Pantheon: %s
Element: %s
Tier: %s
Level: %d
Power: %d""" % [
		god.pantheon, God.element_to_string(god.element), 
		God.tier_to_string(god.tier), god.level, god.get_power_rating()
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
