# scripts/ui/screens/SacrificeScreen.gd
# Main sacrifice screen with tabbed interface using standardized GodCard component
extends Control

signal back_pressed

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")
const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

@onready var back_button = $BackButton
@onready var tab_container = $ContentContainer/TabContainer

# Tab references
var sacrifice_tab: Control = null
var awakening_tab: Control = null

# Sacrifice tab UI
var god_list: GridContainer = null
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
var sort_ascending: bool = false

# System references
var collection_manager: CollectionManager
var awakening_system: AwakeningSystem
var resource_manager: ResourceManager
var sacrifice_selection_screen_scene = preload("res://scenes/SacrificeSelectionScreen.tscn")

func _ready():
	"""Initialize the sacrifice screen"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return
	
	collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return
	
	awakening_system = system_registry.get_system("AwakeningSystem")
	if not awakening_system:
		return
		
	resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return
	
	setup_tabbed_interface()
	
func setup_tabbed_interface():
	"""Create the tabbed interface"""
	if not tab_container:
		return
	
	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create "Sacrifice" tab
	create_sacrifice_tab()
	
	# Create "Awakening" tab
	create_awakening_tab()

func create_sacrifice_tab():
	"""Create the main sacrifice tab with god selection"""
	sacrifice_tab = Control.new()
	sacrifice_tab.name = "Sacrifice"
	tab_container.add_child(sacrifice_tab)
	
	# Create horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	sacrifice_tab.add_child(main_hbox)
	
	# Left panel - God grid
	create_god_grid_panel(main_hbox)
	
	# Right panel - God selection and sacrifice button
	create_selection_panel(main_hbox)
	
	# Load gods after UI is created
	refresh_god_list()

func create_god_grid_panel(parent: Control):
	"""Create the left panel with god grid"""
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 10)
	parent.add_child(left_panel)
	
	# Title
	var title = Label.new()
	title.text = "YOUR GODS"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(title)
	
	# Scrollable god grid
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(400, 400)
	left_panel.add_child(scroll_container)
	
	god_list = GridContainer.new()
	god_list.columns = 5
	god_list.add_theme_constant_override("h_separation", 10)
	god_list.add_theme_constant_override("v_separation", 10)
	scroll_container.add_child(god_list)

func create_selection_panel(parent: Control):
	"""Create the right panel for god selection"""
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 20)
	parent.add_child(right_panel)
	
	# Title
	var title = Label.new()
	title.text = "SELECT GOD TO SACRIFICE"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(title)
	
	# Selected god display area
	create_god_display(right_panel)
	
	# Sacrifice button
	create_sacrifice_button(right_panel)

func create_god_display(parent: Control):
	"""Create the god display area"""
	var selection_container = VBoxContainer.new()
	selection_container.add_theme_constant_override("separation", 15)
	parent.add_child(selection_container)
	
	var label = Label.new()
	label.text = "Selected God:"
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_container.add_child(label)
	
	# God display panel
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
	
	selection_container.add_child(god_display)
	update_god_display()

func create_sacrifice_button(parent: Control):
	"""Create the sacrifice button"""
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
	
	parent.add_child(sacrifice_button)

func refresh_god_list():
	"""Refresh the god list display using standardized GodCard component"""
	if not god_list or not collection_manager:
		return
		
	# Clear existing
	for child in god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get gods and create cards using factory
	var gods = collection_manager.get_all_gods()
	for god in gods:
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.SACRIFICE_SELECTION)
		god_list.add_child(god_card)
		god_card.setup_god_card(god)
		god_card.god_selected.connect(_on_god_clicked)

func create_god_card(god: God) -> Control:
	"""Create a god card for the grid"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(70, 90)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)
	
	# God image placeholder
	var image_button = Button.new()
	image_button.custom_minimum_size = Vector2(60, 60)
	image_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image_button.pressed.connect(_on_god_clicked.bind(god))
	
	# Try to load god sprite
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		image_button.icon = texture
		image_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		image_button.expand_icon = true  # Allow scaling
		image_button.text = ""
		# Constrain the icon size to fit within the button
		image_button.custom_minimum_size = Vector2(60, 60)
		image_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		image_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		image_button.text = god.name.substr(0, 3).to_upper()
	
	vbox.add_child(image_button)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	vbox.add_child(info_vbox)
	
	# Name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(name_label)
	
	# Level and tier info
	var level_label = Label.new()
	level_label.text = "Lv%d %s" % [god.level, God.tier_to_string(god.tier)]
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = get_tier_color(god.tier)
	info_vbox.add_child(level_label)
	
	# Experience bar (only if not max level)
	var max_level = 40  # Level 40 like Summoners War
	if god.level < max_level:
		var xp_bar = ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(60, 8)
		xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# Simple XP calculation - just use current experience vs estimated needed
		var progress = float(god.experience) / float(god.level * 100)  # Basic formula
		if progress > 1.0:
			progress = 1.0
		
		xp_bar.value = progress * 100.0
		xp_bar.modulate = Color.GREEN
		info_vbox.add_child(xp_bar)
	
	return card

func get_tier_color(tier: God.TierType) -> Color:
	"""Get color for tier display"""
	match tier:
		God.TierType.COMMON: return Color.LIGHT_GRAY
		God.TierType.RARE: return Color.CYAN
		God.TierType.EPIC: return Color.MAGENTA
		God.TierType.LEGENDARY: return Color.GOLD
		_: return Color.WHITE

func _on_god_clicked(god: God):
	"""Handle god selection"""
	selected_god = god
	update_god_display()
	update_sacrifice_button()

func update_god_display():
	"""Update the selected god display"""
	if not god_display:
		return
		
	# Clear existing content
	for child in god_display.get_children():
		child.queue_free()
	
	if not selected_god:
		var label = Label.new()
		label.text = "No god selected"
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		god_display.add_child(label)
		return
	
	# Create god display content
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	god_display.add_child(hbox)
	
	# God image
	var image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(80, 80)
	image_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	var sprite_path = "res://assets/gods/" + selected_god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		image_rect.texture = load(sprite_path)
	
	hbox.add_child(image_rect)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = selected_god.name
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)
	
	var stats_label = Label.new()
	stats_label.text = "Level: %d | %s | %s" % [selected_god.level, 
		God.tier_to_string(selected_god.tier), 
		God.element_to_string(selected_god.element)]
	stats_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(stats_label)
	
	var power_label = Label.new()
	power_label.text = "Power: %d" % selected_god.get_power_rating()
	power_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(power_label)

func update_sacrifice_button():
	"""Update sacrifice button state"""
	if sacrifice_button:
		sacrifice_button.disabled = (selected_god == null)

# =============================================================================
# AWAKENING TAB FUNCTIONS
# =============================================================================

func create_awakening_tab():
	"""Create the awakening tab for awakening gods"""
	awakening_tab = Control.new()
	awakening_tab.name = "Awakening"
	tab_container.add_child(awakening_tab)
	
	# Create horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	awakening_tab.add_child(main_hbox)
	
	# Left panel - Awakenable god grid  
	create_awakening_god_grid_panel(main_hbox)
	
	# Right panel - Awakening details
	create_awakening_panel(main_hbox)
	
	# Load awakening gods after UI is created
	refresh_awakening_god_list()

func create_awakening_god_grid_panel(parent: Control):
	"""Create the left panel with awakening god grid"""
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 10)
	parent.add_child(left_panel)
	
	# Title
	var title = Label.new()
	title.text = "AWAKENABLE GODS"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(title)
	
	# Scrollable god grid
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(400, 400)
	left_panel.add_child(scroll_container)
	
	awakening_god_grid = GridContainer.new()
	awakening_god_grid.columns = 5
	awakening_god_grid.add_theme_constant_override("h_separation", 10)
	awakening_god_grid.add_theme_constant_override("v_separation", 10)
	scroll_container.add_child(awakening_god_grid)

func create_awakening_panel(parent: Control):
	"""Create the right panel for awakening details"""
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 20)
	parent.add_child(right_panel)
	
	# Title
	var title = Label.new()
	title.text = "AWAKEN GOD"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(title)
	
	# Selected god display area
	create_awakening_god_display(right_panel)
	
	# Materials display
	create_awakening_materials_display(right_panel)
	
	# Awakening button
	create_awakening_button(right_panel)

func create_awakening_god_display(parent: Control):
	"""Create the awakening god display area"""
	var selection_container = VBoxContainer.new()
	selection_container.add_theme_constant_override("separation", 15)
	parent.add_child(selection_container)
	
	var label = Label.new()
	label.text = "Selected God:"
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_container.add_child(label)
	
	# God display panel
	awakening_god_display = Panel.new()
	awakening_god_display.custom_minimum_size = Vector2(350, 120)
	awakening_god_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.8, 0.2, 1.0)  # Green for awakening
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	awakening_god_display.add_theme_stylebox_override("panel", style)
	selection_container.add_child(awakening_god_display)

func create_awakening_materials_display(parent: Control):
	"""Create materials requirements display"""
	var materials_container = VBoxContainer.new()
	materials_container.add_theme_constant_override("separation", 10)
	parent.add_child(materials_container)
	
	var materials_title = Label.new()
	materials_title.text = "Required Materials:"
	materials_title.add_theme_font_size_override("font_size", 16)
	materials_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	materials_container.add_child(materials_title)
	
	awakening_materials_display = VBoxContainer.new()
	awakening_materials_display.add_theme_constant_override("separation", 5)
	materials_container.add_child(awakening_materials_display)

func create_awakening_button(parent: Control):
	"""Create the awakening button"""
	awakening_button = Button.new()
	awakening_button.text = "AWAKEN GOD"
	awakening_button.custom_minimum_size = Vector2(250, 60)
	awakening_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	awakening_button.disabled = true
	awakening_button.pressed.connect(_on_awaken_god_pressed)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green for awakening
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	awakening_button.add_theme_stylebox_override("normal", button_style)
	awakening_button.add_theme_font_size_override("font_size", 16)
	
	parent.add_child(awakening_button)

func refresh_awakening_god_list():
	"""Refresh the awakening god grid using standardized GodCard component"""
	if not awakening_god_grid:
		return
		
	# Clear existing gods
	for child in awakening_god_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get gods that can be awakened using factory filter
	var gods = collection_manager.get_all_gods()
	var awakenable_gods = gods.filter(GodCardFactory.get_awakening_filter())
	
	# Sort by tier then level
	awakenable_gods.sort_custom(func(a, b): 
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.level > b.level
	)
	
	# Create god cards using factory
	for god in awakenable_gods:
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.AWAKENING_SELECTION)
		var card_style = GodCardScript.CardStyle.AWAKENING_READY if awakening_system.can_awaken_god(god) else GodCardScript.CardStyle.NORMAL
		awakening_god_grid.add_child(god_card)
		god_card.setup_god_card(god, card_style)
		god_card.god_selected.connect(_on_awakening_god_clicked)

func create_awakening_god_card(god: God) -> Control:
	"""Create a god card for awakening selection"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(100, 120)
	
	# Style based on tier and awakening eligibility
	var style = StyleBoxFlat.new()
	var can_awaken_result = awakening_system.can_awaken_god(god)
	
	if awakening_selected_god and awakening_selected_god.id == god.id:
		style.bg_color = Color(0.4, 0.2, 0.6, 0.8)  # Purple for selected
		style.border_color = Color(0.8, 0.4, 1.0, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	elif can_awaken_result.can_awaken:
		style.bg_color = Color(0.2, 0.4, 0.2, 0.8)  # Green for awakenable
		style.border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold border
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Gray for not ready
		style.border_color = Color(0.5, 0.5, 0.5, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)
	
	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Level and tier
	var info_label = Label.new()
	info_label.text = "Lv.%d\n%s" % [god.level, God.tier_to_string(god.tier)]
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(func(): _on_awakening_god_clicked(god))
	card.add_child(button)
	
	return card

func _on_awakening_god_clicked(god: God):
	"""Handle awakening god selection"""
	if awakening_selected_god == god:
		awakening_selected_god = null
	else:
		awakening_selected_god = god
	
	update_awakening_god_display()
	update_awakening_materials_display()
	update_awakening_button()
	refresh_awakening_god_list()  # Refresh to update selection styling

func update_awakening_god_display():
	"""Update the selected awakening god display"""
	if not awakening_god_display:
		return
	
	# Clear existing content
	for child in awakening_god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if not awakening_selected_god:
		var no_selection = Label.new()
		no_selection.text = "Select a god to awaken"
		no_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_selection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		awakening_god_display.add_child(no_selection)
		return
	
	var info_vbox = VBoxContainer.new()
	info_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_vbox.add_theme_constant_override("separation", 5)
	awakening_god_display.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = awakening_selected_god.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(name_label)
	
	var stats_label = Label.new()
	stats_label.text = "Level: %d | %s | %s" % [awakening_selected_god.level,
		God.tier_to_string(awakening_selected_god.tier),
		God.element_to_string(awakening_selected_god.element)]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(stats_label)
	
	# Show awakening requirements status
	var can_awaken_result = awakening_system.can_awaken_god(awakening_selected_god)
	var status_label = Label.new()
	if can_awaken_result.can_awaken:
		status_label.text = "✓ Ready to awaken!"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Requirements not met"
		status_label.modulate = Color.RED
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(status_label)

func update_awakening_materials_display():
	"""Update the awakening materials display"""
	if not awakening_materials_display or not awakening_selected_god:
		return
		
	# Clear existing materials
	for child in awakening_materials_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var materials_needed = awakening_system.get_awakening_materials_cost(awakening_selected_god)
	
	if materials_needed.is_empty():
		var no_materials = Label.new()
		no_materials.text = "No materials needed"
		no_materials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_materials_display.add_child(no_materials)
		return
	
	for material_type in materials_needed:
		var needed_count = materials_needed[material_type]
		var player_has = resource_manager.get_resource(material_type)
		
		var material_label = Label.new()
		var material_name = format_material_name(material_type)
		
		if player_has >= needed_count:
			material_label.text = "✓ %s: %d/%d" % [material_name, player_has, needed_count]
			material_label.modulate = Color.GREEN
		else:
			material_label.text = "✗ %s: %d/%d" % [material_name, player_has, needed_count]
			material_label.modulate = Color.RED
		
		material_label.add_theme_font_size_override("font_size", 12)
		material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_materials_display.add_child(material_label)

func update_awakening_button():
	"""Update awakening button state"""
	if not awakening_button:
		return
		
	if not awakening_selected_god:
		awakening_button.disabled = true
		return
	
	var can_awaken_result = awakening_system.can_awaken_god(awakening_selected_god)
	awakening_button.disabled = not can_awaken_result.can_awaken

func format_material_name(material_type: String) -> String:
	"""Format material names for display"""
	return material_type.replace("_", " ").capitalize()

func _on_awaken_god_pressed():
	"""Handle awakening button press"""
	if not awakening_selected_god:
		return

	if awakening_system.attempt_awakening(awakening_selected_god):
		print("SacrificeScreen: God awakened successfully!")
		
		# Refresh displays
		awakening_selected_god = null
		refresh_awakening_god_list()
		update_awakening_god_display() 
		update_awakening_materials_display()
		update_awakening_button()
		
		# Also refresh sacrifice tab in case awakened god affects sacrifice options
		refresh_god_list()
	else:
		print("SacrificeScreen: Awakening failed!")

func _on_sacrifice_selection_screen_pressed():
	"""Open the sacrifice selection screen using ScreenManager"""
	if not selected_god:
		return
	
	# Store the selected god in SacrificeManager for the selection screen to access
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			# Store target god temporarily
			sacrifice_manager.set_temporary_target_god(selected_god)
		
		# Use ScreenManager for proper full-screen navigation
		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("sacrifice_selection")

func _on_back_pressed():
	"""Handle back button"""
	back_pressed.emit()
