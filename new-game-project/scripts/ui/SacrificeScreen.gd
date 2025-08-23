# scripts/ui/SacrificeScreen.gd - Tabbed god management interface
extends Control

signal back_pressed

@onready var back_button = $BackButton
@onready var tab_container = $ContentContainer/TabContainer

# Tab references
var sacrifice_tab: Control = null
var awakening_tab: Control = null

# Sacrifice tab UI
var god_list: Control = null
var sacrifice_panel: Control = null
var selected_god: God = null
var god_display: Control = null
var sacrifice_button: Button = null

# Awakening tab UI
var awakening_god_grid: GridContainer = null
var awakening_selected_god: God = null
var awakening_god_display: Control = null
var awakening_button: Button = null
var awakening_materials_display: Control = null

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)

# Scroll position preservation
var sacrifice_scroll_position: float = 0.0
var awakening_scroll_position: float = 0.0

# Sacrifice selection screen reference
var sacrifice_selection_screen_scene = preload("res://scenes/SacrificeSelectionScreen.tscn")

func _ready():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	await get_tree().process_frame
	setup_tab_interface()

func setup_tab_interface():
	"""Setup the tabbed interface with Power Up and Awakening tabs"""
	if not tab_container:
		return
		
	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create Sacrifice tab
	setup_sacrifice_tab()
	
	# Create Awakening tab
	setup_awakening_tab()

func setup_sacrifice_tab():
	"""Setup the Sacrifice tab with god grid and selection"""
	sacrifice_tab = Control.new()
	sacrifice_tab.name = "Sacrifice"
	tab_container.add_child(sacrifice_tab)
	
	# Main horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	sacrifice_tab.add_child(main_hbox)
	
	# Left panel - God grid
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 10)
	main_hbox.add_child(left_panel)
	
	var left_title = Label.new()
	left_title.text = "YOUR GODS"
	left_title.add_theme_font_size_override("font_size", 18)
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(left_title)
	
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(400, 400)
	left_panel.add_child(grid_scroll)
	
	god_list = GridContainer.new()
	god_list.columns = 5
	god_list.add_theme_constant_override("h_separation", 10)
	god_list.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(god_list)
	
	# Right panel - Selection and power up
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 20)
	main_hbox.add_child(right_panel)
	
	sacrifice_panel = right_panel
	setup_sacrifice_selection_panel()
	refresh_sacrifice_god_list()
	
	# Add sorting UI after everything is set up
	await get_tree().process_frame
	add_sorting_to_sacrifice_tab()

func setup_sacrifice_selection_panel():
	"""Setup the sacrifice selection panel"""
	if not sacrifice_panel:
		return
		
	# Clear existing UI
	for child in sacrifice_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	sacrifice_panel.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "SELECT GOD TO SACRIFICE"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# Selected god display
	var selection_section = VBoxContainer.new()
	selection_section.add_theme_constant_override("separation", 15)
	main_vbox.add_child(selection_section)
	
	var select_label = Label.new()
	select_label.text = "Selected God:"
	select_label.add_theme_font_size_override("font_size", 16)
	select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_section.add_child(select_label)
	
	# God display area
	god_display = Panel.new()
	god_display.custom_minimum_size = Vector2(350, 120)
	god_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.8, 0.2, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	god_display.add_theme_stylebox_override("panel", style)
	selection_section.add_child(god_display)
	
	# Power up button
	sacrifice_button = Button.new()
	sacrifice_button.text = "OPEN SACRIFICE SELECTION"
	sacrifice_button.custom_minimum_size = Vector2(250, 60)
	sacrifice_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_selection_screen_pressed)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.6, 0.2, 1.0)
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	sacrifice_button.add_theme_stylebox_override("normal", button_style)
	sacrifice_button.add_theme_font_size_override("font_size", 16)
	
	main_vbox.add_child(sacrifice_button)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Click a god from your collection on the left to select them for sacrifice."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.modulate = Color.LIGHT_GRAY
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(instructions)
	
	update_sacrifice_god_display()
func setup_awakening_tab():
	"""Setup the Awakening tab with god grid for Epic/Legendary gods"""
	awakening_tab = Control.new()
	awakening_tab.name = "Awakening"
	tab_container.add_child(awakening_tab)
	
	# Main horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	awakening_tab.add_child(main_hbox)
	
	# Left panel - God grid
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 10)
	main_hbox.add_child(left_panel)
	
	var left_title = Label.new()
	left_title.text = "AWAKENABLE GODS"
	left_title.add_theme_font_size_override("font_size", 18)
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(left_title)
	
	var grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.custom_minimum_size = Vector2(400, 400)
	left_panel.add_child(grid_scroll)
	
	awakening_god_grid = GridContainer.new()
	awakening_god_grid.columns = 5
	awakening_god_grid.add_theme_constant_override("h_separation", 10)
	awakening_god_grid.add_theme_constant_override("v_separation", 10)
	grid_scroll.add_child(awakening_god_grid)
	
	# Right panel - Awakening details
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 20)
	main_hbox.add_child(right_panel)
	
	setup_awakening_panel(right_panel)
	refresh_awakening_god_grid()
	
	# Add sorting UI after everything is set up
	await get_tree().process_frame
	add_sorting_to_awakening_tab()

func setup_awakening_panel(parent: Control):
	"""Setup the awakening details panel"""
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	parent.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "AWAKEN GOD"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# Selected god display
	var selection_section = VBoxContainer.new()
	selection_section.add_theme_constant_override("separation", 15)
	main_vbox.add_child(selection_section)
	
	var select_label = Label.new()
	select_label.text = "Selected God:"
	select_label.add_theme_font_size_override("font_size", 16)
	select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_section.add_child(select_label)
	
	# God display area
	awakening_god_display = Panel.new()
	awakening_god_display.custom_minimum_size = Vector2(350, 120)
	awakening_god_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.2, 0.4, 0.8)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.6, 0.2, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	awakening_god_display.add_theme_stylebox_override("panel", style)
	selection_section.add_child(awakening_god_display)
	
	# Materials display
	awakening_materials_display = Panel.new()
	awakening_materials_display.custom_minimum_size = Vector2(350, 240)
	awakening_materials_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var materials_style = StyleBoxFlat.new()
	materials_style.bg_color = Color(0.2, 0.3, 0.2, 0.8)
	materials_style.border_width_left = 2
	materials_style.border_width_right = 2
	materials_style.border_width_top = 2
	materials_style.border_width_bottom = 2
	materials_style.border_color = Color(0.4, 0.8, 0.4, 1.0)
	materials_style.corner_radius_top_left = 8
	materials_style.corner_radius_top_right = 8
	materials_style.corner_radius_bottom_left = 8
	materials_style.corner_radius_bottom_right = 8
	awakening_materials_display.add_theme_stylebox_override("panel", materials_style)
	main_vbox.add_child(awakening_materials_display)
	
	# Awakening button
	awakening_button = Button.new()
	awakening_button.text = "AWAKEN GOD"
	awakening_button.custom_minimum_size = Vector2(250, 60)
	awakening_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	awakening_button.disabled = true
	awakening_button.pressed.connect(_on_awaken_god_pressed)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.8, 0.4, 0.0, 1.0)
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	awakening_button.add_theme_stylebox_override("normal", button_style)
	awakening_button.add_theme_font_size_override("font_size", 16)
	
	main_vbox.add_child(awakening_button)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Select an Epic or Legendary god at level 40 to awaken them."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.modulate = Color.LIGHT_GRAY
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(instructions)
	
	update_awakening_god_display()
	update_awakening_materials_display()

func add_sorting_to_sacrifice_tab():
	"""Add sorting controls to the sacrifice tab"""
	var left_panel = sacrifice_tab.get_child(0).get_child(0)  # main_hbox -> left_panel
	if not left_panel:
		return
	
	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 5)
	
	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_container.add_child(sort_label)
	
	# Create compact sort buttons
	var sort_buttons = [
		{"text": "Pwr", "type": SortType.POWER},
		{"text": "Lvl", "type": SortType.LEVEL}, 
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Elem", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for button_data in sort_buttons:
		var sort_button = Button.new()
		sort_button.text = button_data.text
		sort_button.custom_minimum_size = Vector2(35, 25)
		sort_button.add_theme_font_size_override("font_size", 10)
		sort_button.pressed.connect(_on_sort_changed.bind(button_data.type))
		
		# Highlight current sort
		if button_data.type == current_sort:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			sort_button.add_theme_stylebox_override("normal", style)
		
		sort_container.add_child(sort_button)
	
	# Add sort direction button
	var direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(25, 25)
	direction_button.add_theme_font_size_override("font_size", 12)
	direction_button.pressed.connect(_on_sort_direction_changed)
	sort_container.add_child(direction_button)
	
	# Insert after the title
	left_panel.add_child(sort_container)
	left_panel.move_child(sort_container, 1)  # After title, before scroll

func add_sorting_to_awakening_tab():
	"""Add sorting controls to the awakening tab"""
	var left_panel = awakening_tab.get_child(0).get_child(0)  # main_hbox -> left_panel
	if not left_panel:
		return
	
	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 5)
	
	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_container.add_child(sort_label)
	
	# Create compact sort buttons
	var sort_buttons = [
		{"text": "Pwr", "type": SortType.POWER},
		{"text": "Lvl", "type": SortType.LEVEL}, 
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for button_data in sort_buttons:
		var sort_button = Button.new()
		sort_button.text = button_data.text
		sort_button.custom_minimum_size = Vector2(35, 25)
		sort_button.add_theme_font_size_override("font_size", 10)
		sort_button.pressed.connect(_on_awakening_sort_changed.bind(button_data.type))
		
		# Highlight current sort
		if button_data.type == current_sort:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			sort_button.add_theme_stylebox_override("normal", style)
		
		sort_container.add_child(sort_button)
	
	# Add sort direction button
	var direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(25, 25)
	direction_button.add_theme_font_size_override("font_size", 12)
	direction_button.pressed.connect(_on_awakening_sort_direction_changed)
	sort_container.add_child(direction_button)
	
	# Insert after the title
	left_panel.add_child(sort_container)
	left_panel.move_child(sort_container, 1)  # After title, before scroll

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change for sacrifice tab"""
	current_sort = sort_type
	refresh_sacrifice_god_list()

func _on_sort_direction_changed():
	"""Toggle sort direction for sacrifice tab"""
	sort_ascending = !sort_ascending
	refresh_sacrifice_god_list()

func _on_awakening_sort_changed(sort_type: SortType):
	"""Handle sort type change for awakening tab"""
	current_sort = sort_type
	refresh_awakening_god_grid()

func _on_awakening_sort_direction_changed():
	"""Toggle sort direction for awakening tab"""
	sort_ascending = !sort_ascending
	refresh_awakening_god_grid()

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

func refresh_sacrifice_god_list():
	"""Refresh the god list on the left in Sacrifice tab"""
	if not god_list:
		return
	
	# Save scroll position
	var scroll_container = god_list.get_parent()
	if scroll_container is ScrollContainer:
		sacrifice_scroll_position = scroll_container.get_v_scroll()
		
	# Clear existing gods
	for child in god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if not GameManager or not GameManager.player_data:
		return
	
	# Get and sort gods
	var gods = GameManager.player_data.gods.duplicate()
	sort_gods(gods)
	
	# Add sorted gods
	for god in gods:
		var god_item = create_sacrifice_god_grid_item(god)
		god_list.add_child(god_item)
	
	# Restore scroll position
	await get_tree().process_frame
	if scroll_container is ScrollContainer:
		scroll_container.set_v_scroll(int(sacrifice_scroll_position))

func create_sacrifice_god_grid_item(god: God) -> Control:
	"""Create a compact grid item for god selection in Sacrifice tab"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(120, 140)
	
	# Style based on selection with subtle colors
	var style = StyleBoxFlat.new()
	if god == selected_god:
		style.bg_color = Color(0.2, 0.4, 0.8, 0.7)  # Blue for selected
		style.border_color = Color(0.4, 0.6, 1.0, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	else:
		style.bg_color = get_subtle_tier_color(god.tier)
		style.border_color = get_tier_border_color(god.tier)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	item.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	item.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
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
	
	# Level and tier (SW style)
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Power rating (important for sacrifice decisions)
	var power_label = Label.new()
	power_label.text = "P:%d" % god.get_power_rating()
	power_label.add_theme_font_size_override("font_size", 9)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(power_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_sacrifice_god_clicked.bind(god))
	item.add_child(button)
	
	return item

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

func _on_sacrifice_god_clicked(god: God):
	"""Handle god selection in Sacrifice tab"""
	if selected_god == god:
		# Deselect if clicking the same god
		selected_god = null
	else:
		# Select new god
		selected_god = god
	
	refresh_sacrifice_god_list()
	update_sacrifice_god_display()
	update_sacrifice_button()

func update_sacrifice_god_display():
	"""Update the selected god display in Sacrifice tab"""
	if not god_display:
		return
	
	# Clear existing content
	for child in god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if selected_god == null:
		# Show empty state
		var empty_label = Label.new()
		empty_label.text = "No god selected\n\nClick a god from the collection to select"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_label.modulate = Color.GRAY
		empty_label.add_theme_font_size_override("font_size", 16)
		god_display.add_child(empty_label)
	else:
		# Show selected god info
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 15)
		god_display.add_child(hbox)
		
		# Left margin
		var left_margin = Control.new()
		left_margin.custom_minimum_size = Vector2(15, 0)
		hbox.add_child(left_margin)
		
		# God info
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = "%s" % selected_god.name
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		info_vbox.add_child(name_label)
		
		var level_label = Label.new()
		level_label.text = "Level %d" % selected_god.level
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.modulate = Color.CYAN
		info_vbox.add_child(level_label)
		
		var details_label = Label.new()
		details_label.text = "%s %s" % [selected_god.get_tier_name(), selected_god.get_element_name()]
		details_label.add_theme_font_size_override("font_size", 14)
		details_label.modulate = Color.LIGHT_GRAY
		info_vbox.add_child(details_label)
		
		var power_label = Label.new()
		power_label.text = "Power Rating: %d" % selected_god.get_power_rating()
		power_label.add_theme_font_size_override("font_size", 14)
		power_label.modulate = Color.YELLOW
		info_vbox.add_child(power_label)
		
		hbox.add_child(info_vbox)

func update_sacrifice_button():
	"""Update the sacrifice button state"""
	if not sacrifice_button:
		return
	
	sacrifice_button.disabled = selected_god == null

func refresh_awakening_god_grid():
	"""Refresh the awakening god grid with Epic/Legendary gods"""
	if not awakening_god_grid:
		return
	
	# Save scroll position
	var scroll_container = awakening_god_grid.get_parent()
	if scroll_container is ScrollContainer:
		awakening_scroll_position = scroll_container.get_v_scroll()
		
	# Clear existing gods
	for child in awakening_god_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if not GameManager or not GameManager.player_data:
		return
	
	# Get only Epic and Legendary gods, then sort them
	var gods = []
	for god in GameManager.player_data.gods:
		if god.tier >= God.TierType.EPIC:  # Epic or Legendary
			gods.append(god)
	
	sort_gods(gods)
	
	# Add sorted gods
	for god in gods:
		var god_item = create_awakening_god_item(god)
		awakening_god_grid.add_child(god_item)
	
	# Restore scroll position
	await get_tree().process_frame
	if scroll_container is ScrollContainer:
		scroll_container.set_v_scroll(int(awakening_scroll_position))

func create_awakening_god_item(god: God) -> Control:
	"""Create a compact grid item for awakening god selection"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(120, 140)
	
	# Style based on selection and awakening status
	var style = StyleBoxFlat.new()
	if god == awakening_selected_god:
		style.bg_color = Color(0.4, 0.2, 0.6, 0.8)  # Purple for selected
		style.border_color = Color(0.8, 0.4, 1.0, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	elif god.can_awaken():
		style.bg_color = get_subtle_tier_color(god.tier)
		style.border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold border for awakenable
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)  # Dark gray for not ready
		style.border_color = Color(0.4, 0.4, 0.4, 0.8)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	item.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	item.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
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
	
	# Level and tier (SW style)
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Status (important for awakening)
	var status_label = Label.new()
	if god.can_awaken():
		status_label.text = "✓ Ready"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Lv.40 Req"
		status_label.modulate = Color.RED
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_awakening_god_clicked.bind(god))
	item.add_child(button)
	
	return item

func _on_awakening_god_clicked(god: God):
	"""Handle god selection in Awakening tab"""
	if awakening_selected_god == god:
		# Deselect if clicking the same god
		awakening_selected_god = null
	else:
		# Select new god
		awakening_selected_god = god
	
	refresh_awakening_god_grid()
	update_awakening_god_display()
	update_awakening_materials_display()
	update_awakening_button()

func update_awakening_god_display():
	"""Update the selected god display in Awakening tab"""
	if not awakening_god_display:
		return
	
	# Clear existing content
	for child in awakening_god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if awakening_selected_god == null:
		# Show empty state
		var empty_label = Label.new()
		empty_label.text = "No god selected\n\nSelect an Epic or Legendary god to awaken"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_label.modulate = Color.GRAY
		empty_label.add_theme_font_size_override("font_size", 16)
		awakening_god_display.add_child(empty_label)
	else:
		# Show selected god info
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 15)
		awakening_god_display.add_child(hbox)
		
		# Left margin
		var left_margin = Control.new()
		left_margin.custom_minimum_size = Vector2(15, 0)
		hbox.add_child(left_margin)
		
		# God info
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = "%s" % awakening_selected_god.name
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color.ORANGE)
		info_vbox.add_child(name_label)
		
		var level_label = Label.new()
		level_label.text = "Level %d" % awakening_selected_god.level
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.modulate = Color.CYAN
		info_vbox.add_child(level_label)
		
		var tier_label = Label.new()
		tier_label.text = "%s %s" % [awakening_selected_god.get_tier_name(), awakening_selected_god.get_element_name()]
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.modulate = Color.LIGHT_GRAY
		info_vbox.add_child(tier_label)
		
		var status_label = Label.new()
		if awakening_selected_god.can_awaken():
			status_label.text = "Ready for Awakening!"
			status_label.modulate = Color.GREEN
		else:
			var levels_needed = 40 - awakening_selected_god.level
			status_label.text = "%d more levels needed" % levels_needed
			status_label.modulate = Color.RED
		status_label.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(status_label)
		
		hbox.add_child(info_vbox)
		
		# God image on the right
		var image_container = VBoxContainer.new()
		image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image_container.custom_minimum_size = Vector2(80, 0)
		
		var god_image = TextureRect.new()
		god_image.custom_minimum_size = Vector2(64, 64)
		god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		god_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Load god image using the new sprite function
		var god_texture = awakening_selected_god.get_sprite()
		if god_texture:
			god_image.texture = god_texture
		
		image_container.add_child(god_image)
		hbox.add_child(image_container)

func update_awakening_materials_display():
	"""Update the awakening materials display"""
	if not awakening_materials_display:
		return
	
	# Clear existing content
	for child in awakening_materials_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if awakening_selected_god == null:
		# Show empty state
		var empty_label = Label.new()
		empty_label.text = "Select a god to see awakening requirements"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_label.modulate = Color.GRAY
		empty_label.add_theme_font_size_override("font_size", 12)
		awakening_materials_display.add_child(empty_label)
	else:
		# Show materials required
		var scroll_container = ScrollContainer.new()
		scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll_container.custom_minimum_size = Vector2(0, 220)
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		scroll_container.clip_contents = true
		awakening_materials_display.add_child(scroll_container)
		
		var margin_container = MarginContainer.new()
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.add_theme_constant_override("margin_left", 10)
		margin_container.add_theme_constant_override("margin_right", 10)
		margin_container.add_theme_constant_override("margin_top", 5)
		margin_container.add_theme_constant_override("margin_bottom", 5)
		scroll_container.add_child(margin_container)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_theme_constant_override("separation", 3)
		margin_container.add_child(vbox)
		
		var title_label = Label.new()
		title_label.text = "Materials Required:"
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.modulate = Color.WHITE
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.clip_contents = true
		vbox.add_child(title_label)
		
		# Get materials from AwakeningSystem
		if GameManager and GameManager.awakening_system:
			var materials = GameManager.awakening_system.get_awakening_materials_cost(awakening_selected_god)
			var requirements_check = GameManager.awakening_system.can_awaken_god(awakening_selected_god)
			
			# Show basic requirements if not met
			if not requirements_check.can_awaken and requirements_check.missing_requirements.size() > 0:
				var req_label = Label.new()
				req_label.text = "Requirements not met:"
				req_label.add_theme_font_size_override("font_size", 12)
				req_label.add_theme_color_override("font_color", Color.RED)
				req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(req_label)
				
				for req in requirements_check.missing_requirements:
					var req_item = Label.new()
					req_item.text = "• " + str(req)
					req_item.add_theme_font_size_override("font_size", 10)
					req_item.add_theme_color_override("font_color", Color.LIGHT_CORAL)
					req_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					vbox.add_child(req_item)
				return
			
			if materials.is_empty():
				var no_data_label = Label.new()
				no_data_label.text = "No awakening data available"
				no_data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				no_data_label.add_theme_font_size_override("font_size", 12)
				no_data_label.modulate = Color.GRAY
				no_data_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				no_data_label.clip_contents = true
				vbox.add_child(no_data_label)
			else:
				# Check materials availability
				var materials_check = GameManager.awakening_system.check_awakening_materials(materials, GameManager.player_data)
				
				# Display each material requirement with current/needed amounts
				for material_type in materials:
					var needed_amount = materials[material_type]
					var current_amount = GameManager.awakening_system.get_player_material_amount(material_type, GameManager.player_data)
					
					# Create material row
					var material_container = HBoxContainer.new()
					material_container.add_theme_constant_override("separation", 10)
					vbox.add_child(material_container)
					
					# Material name
					var name_label = Label.new()
					name_label.text = format_material_name(material_type)
					name_label.add_theme_font_size_override("font_size", 11)
					name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					material_container.add_child(name_label)
					
					# Amount display
					var amount_label = Label.new()
					amount_label.text = "%d / %d" % [current_amount, needed_amount]
					amount_label.add_theme_font_size_override("font_size", 11)
					amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					
					# Color based on availability
					if current_amount >= needed_amount:
						amount_label.add_theme_color_override("font_color", Color.GREEN)
					else:
						amount_label.add_theme_color_override("font_color", Color.RED)
					
					material_container.add_child(amount_label)
				
				# Add separator
				var separator = HSeparator.new()
				vbox.add_child(separator)
				
				# Overall status
				var status_label = Label.new()
				if materials_check.can_afford:
					status_label.text = "✓ All materials available!"
					status_label.add_theme_color_override("font_color", Color.GREEN)
				else:
					status_label.text = "✗ Missing materials"
					status_label.add_theme_color_override("font_color", Color.RED)
				
				status_label.add_theme_font_size_override("font_size", 12)
				status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(status_label)

func format_material_name(material_type: String) -> String:
	"""Format material type string for display"""
	match material_type:
		"awakening_stones":
			return "Awakening Stones"
		"divine_crystals":
			return "Divine Crystals"
		_:
			# Handle elemental powders and pantheon relics
			if material_type.ends_with("_powder_low"):
				var element = material_type.replace("_powder_low", "").capitalize()
				return "%s Powder (Low)" % element
			elif material_type.ends_with("_powder_mid"):
				var element = material_type.replace("_powder_mid", "").capitalize()
				return "%s Powder (Mid)" % element
			elif material_type.ends_with("_powder_high"):
				var element = material_type.replace("_powder_high", "").capitalize()
				return "%s Powder (High)" % element
			elif material_type.ends_with("_relics"):
				var pantheon = material_type.replace("_relics", "").capitalize()
				return "%s Relics" % pantheon
			else:
				# Fallback - just capitalize and replace underscores
				return material_type.replace("_", " ").capitalize()

func update_awakening_button():
	"""Update the awakening button state"""
	if not awakening_button:
		return
	
	var can_awaken = false
	if awakening_selected_god and GameManager and GameManager.awakening_system:
		var awakening_check = GameManager.awakening_system.can_awaken_god(awakening_selected_god)
		if awakening_check.can_awaken:
			# Also check materials
			var materials_needed = GameManager.awakening_system.get_awakening_materials_cost(awakening_selected_god)
			var materials_check = GameManager.awakening_system.check_awakening_materials(materials_needed, GameManager.player_data)
			can_awaken = materials_check.can_afford
	
	awakening_button.disabled = not can_awaken

func _on_awaken_god_pressed():
	"""Handle awakening a god"""
	if not awakening_selected_god or not GameManager or not GameManager.awakening_system:
		return
	
	if not awakening_selected_god.can_awaken():
		print("God must be level 40 to awaken!")
		return
	
	var awakening_check = GameManager.awakening_system.can_awaken_god(awakening_selected_god)
	if not awakening_check.can_awaken:
		print("Not enough materials for awakening!")
		return
	
	# Perform awakening
	var success = GameManager.awakening_system.attempt_awakening(awakening_selected_god, GameManager.player_data)
	if success:
		print("Successfully awakened %s!" % awakening_selected_god.name)
		
		# Refresh displays
		refresh_awakening_god_grid()
		update_awakening_god_display()
		update_awakening_materials_display()
		update_awakening_button()
	else:
		print("Failed to awaken god!")

func _on_sacrifice_selection_screen_pressed():
	"""Open the dedicated sacrifice selection screen"""
	if not selected_god:
		return
	
	# Create and show sacrifice selection screen
	var sacrifice_selection_screen = sacrifice_selection_screen_scene.instantiate()
	get_parent().add_child(sacrifice_selection_screen)
	
	# Initialize with selected god
	sacrifice_selection_screen.initialize_with_god(selected_god)
	
	# Connect back signal
	sacrifice_selection_screen.back_pressed.connect(_on_sacrifice_selection_back_pressed.bind(sacrifice_selection_screen))
	
	# Hide this screen
	visible = false

func _on_sacrifice_selection_back_pressed(sacrifice_selection_screen: Control):
	"""Handle return from sacrifice selection screen"""
	# Show this screen again
	visible = true
	
	# Clean up sacrifice selection screen
	sacrifice_selection_screen.queue_free()
	
	# Refresh in case gods changed
	refresh_sacrifice_god_list()
	update_sacrifice_god_display()

func _on_back_pressed():
	"""Handle back button"""
	back_pressed.emit()
