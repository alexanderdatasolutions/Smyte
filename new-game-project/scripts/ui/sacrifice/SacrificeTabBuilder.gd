# scripts/ui/sacrifice/SacrificeTabBuilder.gd
# Helper component for building and managing the sacrifice tab UI
class_name SacrificeTabBuilder
extends RefCounted

const CardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

# Signals
signal god_selected(god: God)
signal sacrifice_requested(god: God)

# UI references
var god_list: GridContainer
var god_display: Control
var sacrifice_button: Button
var selected_god: God = null

# System references
var collection_manager: CollectionManager

static func create_sacrifice_tab(parent: TabContainer, collection_mgr: CollectionManager):
	"""Create and setup the sacrifice tab"""
	var script = load("res://scripts/ui/sacrifice/SacrificeTabBuilder.gd")
	var builder = script.new()
	builder.collection_manager = collection_mgr

	# Create tab
	var sacrifice_tab = Control.new()
	sacrifice_tab.name = "Sacrifice"
	parent.add_child(sacrifice_tab)

	# Create horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	sacrifice_tab.add_child(main_hbox)

	# Left panel - God grid
	builder._create_god_grid_panel(main_hbox)

	# Right panel - Selection and button
	builder._create_selection_panel(main_hbox)

	# Load gods
	builder.refresh_god_list()

	return builder

func _create_god_grid_panel(parent: Control):
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

func _create_selection_panel(parent: Control):
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
	_create_god_display(right_panel)

	# Sacrifice button
	_create_sacrifice_button(right_panel)

func _create_god_display(parent: Control):
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
	_update_god_display()

func _create_sacrifice_button(parent: Control):
	"""Create the sacrifice button"""
	sacrifice_button = Button.new()
	sacrifice_button.text = "OPEN SACRIFICE SELECTION"
	sacrifice_button.custom_minimum_size = Vector2(250, 60)
	sacrifice_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_button_pressed)

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

	# Get gods and create cards using factory
	var gods = collection_manager.get_all_gods()
	for god in gods:
		var god_card = CardFactory.create_god_card(CardFactory.CardPreset.SACRIFICE_SELECTION)
		god_list.add_child(god_card)
		god_card.setup_god_card(god)
		god_card.god_selected.connect(_on_god_clicked)

func _on_god_clicked(god: God):
	"""Handle god selection"""
	selected_god = god
	_update_god_display()
	_update_sacrifice_button()
	god_selected.emit(god)

func _update_god_display():
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
	power_label.text = "Power: %d" % GodCalculator.get_power_rating(selected_god)
	power_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(power_label)

func _update_sacrifice_button():
	"""Update sacrifice button state"""
	if sacrifice_button:
		sacrifice_button.disabled = (selected_god == null)

func _on_sacrifice_button_pressed():
	"""Handle sacrifice button press"""
	if selected_god:
		sacrifice_requested.emit(selected_god)

func get_selected_god() -> God:
	"""Get the currently selected god"""
	return selected_god
