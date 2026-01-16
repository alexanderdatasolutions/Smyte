class_name CollectionScreen
extends Control

"""
CollectionScreen.gd - God collection management screen using SystemRegistry
RULE 2: Single responsibility - ONLY orchestrates collection UI display
RULE 4: No data modification - delegates to systems through SystemRegistry  
RULE 5: Uses SystemRegistry for all system access
Uses standardized GodCard component for consistent god display
"""

signal back_pressed

@onready var grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
@onready var back_button = $BackButton
@onready var details_content = $MainContainer/RightPanel/DetailsContainer/DetailsContent
@onready var no_selection_label = $MainContainer/RightPanel/DetailsContainer/DetailsContent/NoSelectionLabel

# SystemRegistry references
var collection_manager
var resource_manager

# Sorting state (from old collection screen)
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)
var sort_buttons = []  # Store references to sort buttons
var direction_button = null  # Store reference to direction button

# Additional utility functions for god data
func get_element_name(element_id: int) -> String:
	match element_id:
		0: return "Fire"
		1: return "Water"
		2: return "Wind"  
		3: return "Lightning"
		4: return "Light"
		5: return "Dark"
		_: return "Unknown"

func get_tier_name(tier: int) -> String:
	match tier:
		0: return "⭐ Common"
		1: return "⭐⭐ Rare"
		2: return "⭐⭐⭐ Epic"
		3: return "⭐⭐⭐⭐ Legendary"
		_: return "Unknown"

func get_power_rating(god) -> int:
	# Use GodCalculator for consistent power rating calculation (RULE 3)
	return GodCalculator.get_power_rating(god)

func get_experience_to_next_level(god) -> int:
	# Use centralized experience calculator for consistency
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	return god_exp_calc.get_experience_to_next_level(god.level)

func get_experience_progress(god) -> float:
	# Use centralized experience calculator for consistency
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	return god_exp_calc.get_experience_progress(god)

func get_max_hp(god) -> int:
	return god.base_hp

func get_current_attack(god) -> int:
	return god.base_attack

func get_current_defense(god) -> int:
	return god.base_defense

func get_current_speed(god) -> int:
	return god.base_speed

func has_valid_abilities(god) -> bool:
	return "ability_ids" in god and god.ability_ids.size() > 0

# Scroll position preservation
var scroll_position: float = 0.0

func _ready():
	_init_systems()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Add sorting UI
	setup_sorting_ui()
	refresh_collection()
	show_no_selection()
	
	# Connect to EventBus to listen for collection changes
	_connect_to_events()

func _connect_to_events():
	"""Connect to events that should trigger collection refresh"""
	var registry = SystemRegistry.get_instance()
	if registry:
		var event_bus = registry.get_system("EventBus")
		if event_bus:
			# Refresh when gods gain experience or level up
			if not event_bus.experience_gained.is_connected(_on_god_updated):
				event_bus.experience_gained.connect(_on_god_updated)
			if not event_bus.god_level_up.is_connected(_on_god_level_up):
				event_bus.god_level_up.connect(_on_god_level_up)
			if not event_bus.god_obtained.is_connected(_on_collection_changed):
				event_bus.god_obtained.connect(_on_collection_changed)
			# IMPORTANT: Listen to collection_updated for god removals (sacrifice)
			if not event_bus.collection_updated.is_connected(_on_collection_changed):
				event_bus.collection_updated.connect(_on_collection_changed)

func _on_god_updated(_god_id: String, _experience: int):
	"""Called when a god gains experience - refresh display"""
	refresh_collection()

func _on_god_level_up(_god, _new_level: int, _old_level: int):
	"""Called when a god levels up - refresh display"""
	refresh_collection()

func _on_collection_changed(_god):
	"""Called when collection changes - refresh display"""
	refresh_collection()

# Also add visibility change detection
func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Screen became visible - refresh collection
		if collection_manager:
			refresh_collection()

func _init_systems():
	"""Initialize SystemRegistry systems - RULE 5"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("CollectionScreen: SystemRegistry not available!")
		return
		
	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")
	
	if not collection_manager:
		push_error("CollectionScreen: CollectionManager not found!")
	if not resource_manager:
		push_error("CollectionScreen: ResourceManager not found!")

func setup_sorting_ui():
	"""Setup sorting controls like the old version with full functionality"""
	
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
	direction_button.text = "↓"  # Down arrow for descending
	direction_button.custom_minimum_size = Vector2(30, 30)
	direction_button.pressed.connect(_on_direction_changed)
	sort_container.add_child(direction_button)
	
	# Insert at the top of the left panel (before the grid)
	left_panel_vbox.add_child(sort_container)
	left_panel_vbox.move_child(sort_container, 0)
	
	# Update button styles to show current selection
	_update_sort_button_styles()

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	_update_sort_button_styles()
	refresh_collection()

func _on_direction_changed():
	"""Handle sort direction change"""
	sort_ascending = not sort_ascending
	direction_button.text = "↑" if sort_ascending else "↓"
	refresh_collection()

func _update_sort_button_styles():
	"""Update sort button styles to show current selection"""
	var button_configs = [SortType.POWER, SortType.LEVEL, SortType.TIER, SortType.ELEMENT, SortType.NAME]
	
	for i in range(sort_buttons.size()):
		var button = sort_buttons[i]
		if button_configs[i] == current_sort:
			# Highlight selected button
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			button.add_theme_stylebox_override("normal", style)
		else:
			# Remove highlight from unselected buttons
			button.remove_theme_stylebox_override("normal")

func refresh_collection():
	"""Refresh the god collection display using standardized GodCard component"""
	
	if not collection_manager:
		return
		
	# Get gods from SystemRegistry
	var gods_data = collection_manager.get_all_gods()
	
	# Sort gods according to current settings
	gods_data = _sort_gods(gods_data)
	
	# Clear existing god cards
	for child in grid_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if gods_data.is_empty():
		var no_gods_label = Label.new()
		no_gods_label.text = "No gods in your collection yet!"
		no_gods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(no_gods_label)
		return
	
	# Create god cards using factory for consistency
	for god in gods_data:
		if god != null:
			var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COLLECTION_DETAILED)
			grid_container.add_child(god_card)
			god_card.setup_god_card(god)
			god_card.god_selected.connect(show_god_details)

func _sort_gods(gods: Array) -> Array:
	"""Sort gods according to current sort settings"""
	var sorted_gods = gods.duplicate()
	
	match current_sort:
		SortType.POWER:
			sorted_gods.sort_custom(func(a, b): 
				if sort_ascending:
					return get_power_rating(a) < get_power_rating(b)
				else:
					return get_power_rating(a) > get_power_rating(b)
			)
		SortType.LEVEL:
			sorted_gods.sort_custom(func(a, b): 
				if sort_ascending:
					return a.level < b.level
				else:
					return a.level > b.level
			)
		SortType.TIER:
			sorted_gods.sort_custom(func(a, b): 
				if sort_ascending:
					return a.tier < b.tier
				else:
					return a.tier > b.tier
			)
		SortType.ELEMENT:
			sorted_gods.sort_custom(func(a, b): 
				if sort_ascending:
					return a.element < b.element
				else:
					return a.element > b.element
			)
		SortType.NAME:
			sorted_gods.sort_custom(func(a, b): 
				if sort_ascending:
					return a.name < b.name
				else:
					return a.name > b.name
			)
	
	return sorted_gods

func create_god_card(god: God):
	"""Create an enhanced god card with experience bar and detailed info"""
	# Create larger card for better detail display
	var card = Panel.new()
	card.custom_minimum_size = Vector2(160, 200)  # Bigger than before
	
	# Style with subtle tier colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_subtle_tier_color(god.tier)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = get_tier_border_color(god.tier)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)
	
	# Main container with margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# God image (larger)
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(64, 64)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god image based on god ID
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		god_image.texture = load(sprite_path)
	
	vbox.add_child(god_image)
	
	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier info
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Experience bar with labels
	var exp_container = VBoxContainer.new()
	exp_container.add_theme_constant_override("separation", 2)
	
	# Experience info label
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	var current_xp = god.experience
	var remaining_xp = god_exp_calc.get_experience_remaining_to_next_level(god)
	var progress_percent = god_exp_calc.get_experience_progress(god)
	
	var exp_info = Label.new()
	if god.level >= 40:
		exp_info.text = "MAX LEVEL"
		exp_info.modulate = Color.GOLD
	else:
		exp_info.text = "XP: %d (-%d)" % [current_xp, remaining_xp]
	exp_info.add_theme_font_size_override("font_size", 9)
	exp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_info.modulate = Color.LIGHT_GRAY
	exp_container.add_child(exp_info)
	
	# Experience progress bar
	var exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(140, 12)
	exp_bar.min_value = 0.0
	exp_bar.max_value = 100.0
	exp_bar.value = progress_percent
	exp_bar.show_percentage = false
	
	# Style the experience bar
	var exp_fill_style = StyleBoxFlat.new()
	if god.level >= 40:
		exp_fill_style.bg_color = Color.GOLD
	else:
		exp_fill_style.bg_color = Color(0.2, 0.6, 1.0, 0.9)  # Nice blue
	exp_fill_style.corner_radius_top_left = 3
	exp_fill_style.corner_radius_top_right = 3
	exp_fill_style.corner_radius_bottom_left = 3
	exp_fill_style.corner_radius_bottom_right = 3
	exp_bar.add_theme_stylebox_override("fill", exp_fill_style)
	
	var exp_bg_style = StyleBoxFlat.new()
	exp_bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	exp_bg_style.corner_radius_top_left = 3
	exp_bg_style.corner_radius_top_right = 3
	exp_bg_style.corner_radius_bottom_left = 3
	exp_bg_style.corner_radius_bottom_right = 3
	exp_bar.add_theme_stylebox_override("background", exp_bg_style)
	
	exp_container.add_child(exp_bar)
	
	# Progress percentage label
	var progress_label = Label.new()
	if god.level >= 40:
		progress_label.text = "MAX"
	else:
		progress_label.text = "%.1f%%" % progress_percent
	progress_label.add_theme_font_size_override("font_size", 8)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.modulate = Color.WHITE
	exp_container.add_child(progress_label)
	
	vbox.add_child(exp_container)
	
	# Element and power info
	var info_label = Label.new()
	info_label.text = "%s | Power: %d" % [get_element_short_name(god.element), get_power_rating(god)]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Territory assignment indicator
	if god.stationed_territory != "":
		var territory_label = Label.new()
		territory_label.text = "⚔ Stationed"
		territory_label.add_theme_font_size_override("font_size", 8)
		territory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		territory_label.modulate = Color.GREEN
		vbox.add_child(territory_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(func(): show_god_details(god))
	card.add_child(button)
	
	grid_container.add_child(card)

func show_god_details(god: God):
	"""Show god details in right panel - EXACTLY like old version with full styling"""
	
	# Clear existing content
	for child in details_content.get_children():
		if child != no_selection_label:
			child.queue_free()
	
	# Hide no selection label
	if no_selection_label:
		no_selection_label.visible = false
	
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
	
	# Load god image based on god ID
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		image_container.texture = load(sprite_path)
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
		god.pantheon, get_element_name(god.element), 
		get_tier_name(god.tier), god.level, get_power_rating(god)
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
	
	# Use centralized experience calculator
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	var current_xp = god.experience
	var remaining_xp = god_exp_calc.get_experience_remaining_to_next_level(god)
	var progress_percent = god_exp_calc.get_experience_progress(god)
	var next_level_total = god_exp_calc.get_total_experience_for_level(god.level + 1)
	
	var xp_info = Label.new()
	if god.level >= 40:
		xp_info.text = """Current XP: %d
Level: MAX
Status: Maximum Level Reached""" % [current_xp]
	else:
		xp_info.text = """Current XP: %d
Next Level Total: %d
Remaining: %d
Progress: %.1f%%""" % [current_xp, next_level_total, remaining_xp, progress_percent]
	xp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_section.add_child(xp_info)
	
	# XP Progress Bar
	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 20)
	xp_bar.min_value = 0.0
	xp_bar.max_value = 100.0
	xp_bar.value = progress_percent
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
		get_max_hp(god), get_current_attack(god), 
		get_current_defense(god), get_current_speed(god),
		god.stationed_territory if "stationed_territory" in god and god.stationed_territory != "" else "Unassigned"
	]
	stats_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_section.add_child(stats_info)
	content.add_child(stats_section)
	
	# Abilities Section
	if has_valid_abilities(god):
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

func show_no_selection():
	"""Show the no selection message"""
	if no_selection_label:
		no_selection_label.visible = true

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

# =============================================================================
# VISUAL STYLING FUNCTIONS - From old working collection screen
# =============================================================================

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
