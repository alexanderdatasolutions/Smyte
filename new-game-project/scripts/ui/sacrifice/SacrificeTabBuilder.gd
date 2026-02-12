# scripts/ui/sacrifice/SacrificeTabBuilder.gd
# Helper component for building and managing the sacrifice tab UI
class_name SacrificeTabBuilder
extends RefCounted

const CardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

# UI Design Pattern Colors
const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.9, 0.6, 0.4)
const COLOR_SELECTED = Color(0.3, 0.5, 0.3, 0.9)
const COLOR_SELECTED_BORDER = Color(0.5, 0.8, 0.5)

# Signals
signal god_selected(god: God)
signal sacrifice_requested(god: God)

# UI references
var god_list: GridContainer
var god_display: Control
var sacrifice_button: Button
var selected_god: God = null
var scroll_container: ScrollContainer

# Sorting
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false
var sort_dropdown: OptionButton = null
var sort_direction_btn: Button = null

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

	# Create horizontal layout matching UI patterns
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 15)
	sacrifice_tab.add_child(main_hbox)

	# Left panel - Selected god info (fixed width like battle setup)
	builder._create_selection_panel(main_hbox)

	# Right panel - God grid (flexible width)
	builder._create_god_grid_panel(main_hbox)

	# Load gods
	builder.refresh_god_list()

	return builder

func _create_selection_panel(parent: Control):
	"""Create the left panel for selected god - fixed width like battle setup"""
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(left_panel)
	parent.add_child(left_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	left_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "TARGET GOD"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(title)

	# Selected god display area
	_create_god_display(vbox)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Select a god to receive XP from sacrificed gods"
	instructions.add_theme_font_size_override("font_size", 11)
	instructions.add_theme_color_override("font_color", COLOR_MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

	# Sacrifice button
	_create_sacrifice_button(vbox)

func _create_god_grid_panel(parent: Control):
	"""Create the right panel with god grid - flexible width"""
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(right_panel)
	parent.add_child(right_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(vbox)

	# Header row with title and sorting
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 15)
	vbox.add_child(header_row)

	# Title
	var title = Label.new()
	title.text = "SELECT GOD"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	header_row.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	# Sorting controls
	_create_sorting_controls(header_row)

	# Scrollable god grid
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)

	god_list = GridContainer.new()
	god_list.columns = 6
	god_list.add_theme_constant_override("h_separation", 8)
	god_list.add_theme_constant_override("v_separation", 8)
	god_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(god_list)

func _create_sorting_controls(parent: HBoxContainer):
	"""Create sorting dropdown and direction button"""
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", COLOR_TEXT)
	parent.add_child(sort_label)

	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(100, 28)
	sort_dropdown.add_item("Power", SortType.POWER)
	sort_dropdown.add_item("Level", SortType.LEVEL)
	sort_dropdown.add_item("Tier", SortType.TIER)
	sort_dropdown.add_item("Element", SortType.ELEMENT)
	sort_dropdown.add_item("Name", SortType.NAME)
	sort_dropdown.selected = 0
	sort_dropdown.item_selected.connect(_on_sort_changed)
	parent.add_child(sort_dropdown)

	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▼"
	sort_direction_btn.custom_minimum_size = Vector2(30, 28)
	sort_direction_btn.tooltip_text = "Toggle sort direction"
	sort_direction_btn.pressed.connect(_toggle_sort_direction)
	_style_button(sort_direction_btn, false)
	parent.add_child(sort_direction_btn)

func _on_sort_changed(index: int):
	current_sort = index as SortType
	refresh_god_list()

func _toggle_sort_direction():
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	refresh_god_list()

func _sort_gods(gods: Array) -> Array:
	"""Sort gods based on current sort settings"""
	var sorted = gods.duplicate()

	match current_sort:
		SortType.POWER:
			sorted.sort_custom(func(a, b):
				var pa = GodCalculator.get_power_rating(a)
				var pb = GodCalculator.get_power_rating(b)
				return pa < pb if sort_ascending else pa > pb)
		SortType.LEVEL:
			sorted.sort_custom(func(a, b):
				return a.level < b.level if sort_ascending else a.level > b.level)
		SortType.TIER:
			sorted.sort_custom(func(a, b):
				return a.tier < b.tier if sort_ascending else a.tier > b.tier)
		SortType.ELEMENT:
			sorted.sort_custom(func(a, b):
				return a.element < b.element if sort_ascending else a.element > b.element)
		SortType.NAME:
			sorted.sort_custom(func(a, b):
				return a.name < b.name if sort_ascending else a.name > b.name)

	return sorted

func _create_god_display(parent: Control):
	"""Create the god display area"""
	god_display = PanelContainer.new()
	god_display.custom_minimum_size = Vector2(0, 140)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	god_display.add_theme_stylebox_override("panel", style)

	parent.add_child(god_display)
	_update_god_display()

func _create_sacrifice_button(parent: Control):
	"""Create the sacrifice button"""
	sacrifice_button = Button.new()
	sacrifice_button.text = "CHOOSE SACRIFICES"
	sacrifice_button.custom_minimum_size = Vector2(0, 50)
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_button_pressed)
	_style_button(sacrifice_button, true)
	parent.add_child(sacrifice_button)

func refresh_god_list():
	"""Refresh the god list display using standardized GodCard component"""
	if not god_list or not collection_manager:
		return

	# Clear existing
	for child in god_list.get_children():
		child.queue_free()

	# Get gods, sort, and create cards
	var gods = collection_manager.get_all_gods()
	var sorted_gods = _sort_gods(gods)

	for god in sorted_gods:
		var card = _create_god_card(god)
		god_list.add_child(card)

func _create_god_card(god: God) -> Control:
	"""Create a styled god card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(100, 130)

	var is_selected = (god == selected_god)

	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = COLOR_SELECTED
		style.border_color = COLOR_SELECTED_BORDER
		style.set_border_width_all(3)
	else:
		style.bg_color = COLOR_PANEL_BG
		style.border_color = COLOR_PANEL_BORDER
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# God image
	var image_container = CenterContainer.new()
	image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(image_container)

	var image = TextureRect.new()
	image.custom_minimum_size = Vector2(60, 60)
	image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		image.texture = load(sprite_path)
	image_container.add_child(image)

	# Name
	var name_label = Label.new()
	name_label.text = god.name if god.name.length() <= 10 else god.name.substr(0, 9) + ".."
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level + Tier
	var info_label = Label.new()
	info_label.text = "Lv.%d %s" % [god.level, God.tier_to_string(god.tier).substr(0, 1)]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.add_theme_color_override("font_color", COLOR_MUTED)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Power
	var power_label = Label.new()
	power_label.text = str(GodCalculator.get_power_rating(god))
	power_label.add_theme_font_size_override("font_size", 9)
	power_label.add_theme_color_override("font_color", Color.GOLD)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(power_label)

	# Click handling
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_god_clicked(god)
	)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	return card

func _on_god_clicked(god: God):
	"""Handle god selection"""
	selected_god = god
	_update_god_display()
	_update_sacrifice_button()
	refresh_god_list()  # Refresh to update selection visuals
	god_selected.emit(god)

func _update_god_display():
	"""Update the selected god display"""
	if not god_display:
		return

	# Clear existing content
	for child in god_display.get_children():
		child.queue_free()

	if not selected_god:
		var center = CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		god_display.add_child(center)

		var label = Label.new()
		label.text = "Select a god from the right panel"
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", COLOR_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(label)
		return

	# Create god display content
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	god_display.add_child(hbox)

	# God image
	var image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(80, 80)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = selected_god.template_id if selected_god.template_id else selected_god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		image_rect.texture = load(sprite_path)
	hbox.add_child(image_rect)

	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = selected_god.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_HEADER)
	info_vbox.add_child(name_label)

	var tier_label = Label.new()
	tier_label.text = "%s | %s" % [God.tier_to_string(selected_god.tier), God.element_to_string(selected_god.element)]
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(tier_label)

	var level_label = Label.new()
	level_label.text = "Level: %d" % selected_god.level
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(level_label)

	var power_label = Label.new()
	power_label.text = "Power: %d" % GodCalculator.get_power_rating(selected_god)
	power_label.add_theme_font_size_override("font_size", 11)
	power_label.add_theme_color_override("font_color", Color.GOLD)
	info_vbox.add_child(power_label)

func _update_sacrifice_button():
	"""Update sacrifice button state"""
	if sacrifice_button:
		sacrifice_button.disabled = (selected_god == null)
		if selected_god:
			sacrifice_button.text = "CHOOSE SACRIFICES"
		else:
			sacrifice_button.text = "SELECT A GOD FIRST"

func _on_sacrifice_button_pressed():
	"""Handle sacrifice button press"""
	if selected_god:
		sacrifice_requested.emit(selected_god)

func get_selected_god() -> God:
	"""Get the currently selected god"""
	return selected_god

# ==============================================================================
# STYLING HELPERS
# ==============================================================================
func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false):
	var style_normal = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = COLOR_PANEL_BORDER
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.1, 0.1, 0.12, 0.7)
	style_disabled.border_color = Color(0.2, 0.2, 0.25, 0.5)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
