# scripts/ui/sacrifice/AwakeningTabBuilder.gd
# Helper component for building and managing the awakening tab UI
class_name AwakeningTabBuilder
extends RefCounted

const CardFactory = preload("res://scripts/utilities/GodCardFactory.gd")
const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# Signals
signal god_awakened(god: God)

# UI references
var awakening_god_grid: GridContainer
var awakening_god_display: Control
var awakening_materials_display: Control
var awakening_button: Button
var awakening_selected_god: God = null

# System references
var collection_manager: CollectionManager
var awakening_system: AwakeningSystem
var resource_manager: ResourceManager

static func create_awakening_tab(parent: TabContainer, collection_mgr: CollectionManager,
								awakening_sys: AwakeningSystem, resource_mgr: ResourceManager):
	"""Create and setup the awakening tab"""
	var script = load("res://scripts/ui/sacrifice/AwakeningTabBuilder.gd")
	var builder = script.new()
	builder.collection_manager = collection_mgr
	builder.awakening_system = awakening_sys
	builder.resource_manager = resource_mgr

	# Create tab
	var awakening_tab = Control.new()
	awakening_tab.name = "Awakening"
	parent.add_child(awakening_tab)

	# Create horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	awakening_tab.add_child(main_hbox)

	# Left panel - Awakenable god grid
	builder._create_awakening_god_grid_panel(main_hbox)

	# Right panel - Awakening details
	builder._create_awakening_panel(main_hbox)

	# Load gods
	builder.refresh_awakening_god_list()

	return builder

func _create_awakening_god_grid_panel(parent: Control):
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

func _create_awakening_panel(parent: Control):
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

	# Selected god display
	_create_awakening_god_display(right_panel)

	# Materials display
	_create_awakening_materials_display(right_panel)

	# Awakening button
	_create_awakening_button(right_panel)

func _create_awakening_god_display(parent: Control):
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

func _create_awakening_materials_display(parent: Control):
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

func _create_awakening_button(parent: Control):
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

	# Get gods that can be awakened using factory filter
	var gods = collection_manager.get_all_gods()
	var awakenable_gods = gods.filter(CardFactory.get_awakening_filter())

	# Sort by tier then level
	awakenable_gods.sort_custom(func(a, b):
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.level > b.level
	)

	# Create god cards using factory
	for god in awakenable_gods:
		var god_card = CardFactory.create_god_card(CardFactory.CardPreset.AWAKENING_SELECTION)
		var card_style = GodCardScript.CardStyle.AWAKENING_READY if awakening_system.can_awaken_god(god) else GodCardScript.CardStyle.NORMAL
		awakening_god_grid.add_child(god_card)
		god_card.setup_god_card(god, card_style)
		god_card.god_selected.connect(_on_awakening_god_clicked)

func _on_awakening_god_clicked(god: God):
	"""Handle awakening god selection"""
	if awakening_selected_god == god:
		awakening_selected_god = null
	else:
		awakening_selected_god = god

	_update_awakening_god_display()
	_update_awakening_materials_display()
	_update_awakening_button()
	refresh_awakening_god_list()  # Refresh to update selection styling

func _update_awakening_god_display():
	"""Update the selected awakening god display"""
	if not awakening_god_display:
		return

	# Clear existing content
	for child in awakening_god_display.get_children():
		child.queue_free()

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

func _update_awakening_materials_display():
	"""Update the awakening materials display"""
	if not awakening_materials_display or not awakening_selected_god:
		return

	# Clear existing materials
	for child in awakening_materials_display.get_children():
		child.queue_free()

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
		var material_name = _format_material_name(material_type)

		if player_has >= needed_count:
			material_label.text = "✓ %s: %d/%d" % [material_name, player_has, needed_count]
			material_label.modulate = Color.GREEN
		else:
			material_label.text = "✗ %s: %d/%d" % [material_name, player_has, needed_count]
			material_label.modulate = Color.RED

		material_label.add_theme_font_size_override("font_size", 12)
		material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_materials_display.add_child(material_label)

func _update_awakening_button():
	"""Update awakening button state"""
	if not awakening_button:
		return

	if not awakening_selected_god:
		awakening_button.disabled = true
		return

	var can_awaken_result = awakening_system.can_awaken_god(awakening_selected_god)
	awakening_button.disabled = not can_awaken_result.can_awaken

func _format_material_name(material_type: String) -> String:
	"""Format material names for display"""
	return material_type.replace("_", " ").capitalize()

func _on_awaken_god_pressed():
	"""Handle awakening button press"""
	if not awakening_selected_god:
		return

	if awakening_system.attempt_awakening(awakening_selected_god):
		var awakened_god = awakening_selected_god
		awakening_selected_god = null
		refresh_awakening_god_list()
		_update_awakening_god_display()
		_update_awakening_materials_display()
		_update_awakening_button()
		god_awakened.emit(awakened_god)

func get_selected_god() -> God:
	"""Get the currently selected awakening god"""
	return awakening_selected_god
