# scripts/ui/screens/SacrificeSelectionScreen.gd
# RULE 1 COMPLIANCE: 500-line limit enforced
# RULE 2 COMPLIANCE: Single responsibility - sacrifice selection screen UI
# RULE 4 COMPLIANCE: UI layer - display coordination only, no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control

signal back_pressed

# ==============================================================================
# COLOR PALETTE (from UI_DESIGN_PATTERNS.md)
# ==============================================================================
const COLOR_BG_DARK = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT_NORMAL = Color(0.7, 0.7, 0.8)
const COLOR_TEXT_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.6, 0.4, 0.4)
const COLOR_SELECTED = Color(0.4, 0.6, 0.8, 0.9)
const COLOR_SELECTED_BORDER = Color(0.5, 0.7, 1.0, 1.0)

# Node references
@onready var back_button = $MainContainer/TopBar/BackButton
@onready var target_god_display = $MainContainer/SacrificeContent/TargetGodSection/TargetGodDisplay
@onready var xp_bar_container = $MainContainer/SacrificeContent/XPBarSection/XPBarContainer
@onready var material_grid = $MainContainer/SacrificeContent/MaterialSection/ScrollContainer/MaterialGrid
@onready var lock_in_button = $MainContainer/SacrificeContent/ButtonSection/LockInButton
@onready var sacrifice_button = $MainContainer/SacrificeContent/ButtonSection/SacrificeButton

# Scene labels to style
@onready var target_label = $MainContainer/SacrificeContent/TargetGodSection/TargetLabel
@onready var xp_section_label = $MainContainer/SacrificeContent/XPBarSection/XPLabel
@onready var material_label = $MainContainer/SacrificeContent/MaterialSection/MaterialLabel
@onready var scroll_container = $MainContainer/SacrificeContent/MaterialSection/ScrollContainer

# State
var target_god: God = null
var selected_materials: Array[God] = []
var locked_in: bool = false

# Sorting
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false
var sort_dropdown: OptionButton = null
var sort_direction_btn: Button = null
var select_dupes_btn: Button = null

# UI elements
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_preview_label: Label = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)

	setup_ui()
	_setup_unified_header()

	# Hide old back button (using unified header)
	if back_button:
		back_button.visible = false

	# Auto-initialize with target god from SacrificeManager if available
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			var temp_target_god = sacrifice_manager.get_temporary_target_god()
			if temp_target_god:
				initialize_with_god(temp_target_god)

# ==============================================================================
# STYLING HELPERS
# ==============================================================================
func _style_panel(panel: Control, highlight: bool = false) -> void:
	"""Apply consistent panel styling"""
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	if highlight:
		style.border_color = Color.GOLD
	else:
		style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false) -> void:
	"""Apply consistent button styling"""
	var style_normal = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.1, 0.08, 0.12, 0.7)
	style_disabled.border_color = Color(0.2, 0.18, 0.25, 0.5)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_color_override("font_color", COLOR_HEADER)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)

func _style_header_label(label: Label) -> void:
	"""Style a label as a header"""
	label.add_theme_color_override("font_color", COLOR_HEADER)
	label.add_theme_font_size_override("font_size", 14)

func _style_progress_bar(bar: ProgressBar) -> void:
	"""Style a progress bar"""
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.08, 0.12, 0.9)
	bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.6, 0.8, 0.9)
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)

func _style_section_label(label: Label) -> void:
	"""Style section header labels"""
	if not label:
		return
	label.add_theme_color_override("font_color", COLOR_HEADER)
	label.add_theme_font_size_override("font_size", 14)

func _style_scroll_area() -> void:
	"""Wrap scroll container in a styled panel"""
	if not scroll_container:
		return

	var parent = scroll_container.get_parent()
	if not parent:
		return

	# Check if already wrapped
	if scroll_container.get_parent().name == "ScrollWrapper":
		return

	# Create wrapper panel
	var wrapper = PanelContainer.new()
	wrapper.name = "ScrollWrapper"
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.08, 0.9)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = COLOR_PANEL_BORDER
	wrapper.add_theme_stylebox_override("panel", style)

	# Reparent scroll container into wrapper
	var idx = scroll_container.get_index()
	parent.remove_child(scroll_container)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	wrapper.add_child(scroll_container)

func _style_separators() -> void:
	"""Style all HSeparators in the scene"""
	var separators = [
		get_node_or_null("MainContainer/HSeparator"),
		get_node_or_null("MainContainer/SacrificeContent/HSeparator2"),
		get_node_or_null("MainContainer/SacrificeContent/HSeparator3"),
		get_node_or_null("MainContainer/SacrificeContent/HSeparator4")
	]
	for sep in separators:
		if sep:
			var style = StyleBoxFlat.new()
			style.bg_color = COLOR_PANEL_BORDER
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			sep.add_theme_stylebox_override("separator", style)

# ==============================================================================
# SORTING & SELECTION CONTROLS
# ==============================================================================
func _create_controls_row() -> HBoxContainer:
	"""Create sorting controls and select duplicates button"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	container.add_child(sort_label)

	# Sort dropdown
	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(100, 28)
	sort_dropdown.add_item("Power", SortType.POWER)
	sort_dropdown.add_item("Level", SortType.LEVEL)
	sort_dropdown.add_item("Tier", SortType.TIER)
	sort_dropdown.add_item("Element", SortType.ELEMENT)
	sort_dropdown.add_item("Name", SortType.NAME)
	sort_dropdown.selected = 0
	sort_dropdown.item_selected.connect(_on_sort_changed)
	container.add_child(sort_dropdown)

	# Sort direction button
	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▼"
	sort_direction_btn.custom_minimum_size = Vector2(30, 28)
	sort_direction_btn.tooltip_text = "Toggle sort direction"
	sort_direction_btn.pressed.connect(_toggle_sort_direction)
	_style_button(sort_direction_btn)
	container.add_child(sort_direction_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)

	# Select Duplicates button
	select_dupes_btn = Button.new()
	select_dupes_btn.text = "Select Duplicates"
	select_dupes_btn.custom_minimum_size = Vector2(140, 28)
	select_dupes_btn.tooltip_text = "Select all gods you have more than one of"
	select_dupes_btn.pressed.connect(_on_select_duplicates)
	_style_button(select_dupes_btn)
	container.add_child(select_dupes_btn)

	# Clear Selection button
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(60, 28)
	clear_btn.tooltip_text = "Clear all selections"
	clear_btn.pressed.connect(_on_clear_selection)
	_style_button(clear_btn)
	container.add_child(clear_btn)

	return container

func _on_sort_changed(index: int):
	current_sort = index as SortType
	populate_material_grid()

func _toggle_sort_direction():
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	populate_material_grid()

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

func _on_select_duplicates():
	"""Select all duplicate gods (keep one of each template, select the rest)"""
	if locked_in:
		return

	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return

	var gods = collection_manager.get_all_gods()

	# Count gods by template_id
	var template_counts: Dictionary = {}
	var gods_by_template: Dictionary = {}

	for god in gods:
		if god == target_god:
			continue
		# CRITICAL: Skip gods that are assigned to garrisons or as workers
		var location = _get_god_location(god)
		if location != "":
			continue  # God is in a garrison or assigned as a worker - don't select
		var template = god.template_id if god.template_id else god.id
		if not template_counts.has(template):
			template_counts[template] = 0
			gods_by_template[template] = []
		template_counts[template] += 1
		gods_by_template[template].append(god)

	# Select duplicates (all but the highest level one)
	selected_materials.clear()
	for template in gods_by_template:
		if template_counts[template] > 1:
			var template_gods = gods_by_template[template]
			# Sort by level descending, keep the best, select the rest
			template_gods.sort_custom(func(a, b): return a.level > b.level)
			for i in range(1, template_gods.size()):
				selected_materials.append(template_gods[i])

	update_all_displays()

func _on_clear_selection():
	"""Clear all selected gods"""
	if locked_in:
		return
	selected_materials.clear()
	update_all_displays()

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _setup_unified_header():
	"""Configure the unified header for this screen"""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed():
	"""Update header when this screen becomes visible"""
	if visible:
		_update_header_for_screen()

func _update_header_for_screen():
	"""Apply this screen's header settings"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("SACRIFICE SELECTION")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func initialize_with_god(god: God):
	"""Initialize the screen with a target god"""
	target_god = god
	selected_materials.clear()
	locked_in = false
	update_all_displays()

func setup_ui():
	# Style section headers
	_style_section_label(target_label)
	_style_section_label(xp_section_label)

	# Replace material_label with controls row
	_setup_material_section_header()

	# Style scroll area with panel wrapper
	_style_scroll_area()

	# Style separators
	_style_separators()

	setup_xp_bar()
	setup_target_display()
	_style_button(lock_in_button, false)
	_style_button(sacrifice_button, true)
	sacrifice_button.disabled = true
	update_button_states()

func _setup_material_section_header():
	"""Replace the material label with a header row containing label + controls"""
	if not material_label:
		return

	var parent = material_label.get_parent()
	var idx = material_label.get_index()

	# Create header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 15)

	# Label
	var label = Label.new()
	label.text = "SELECT GODS TO SACRIFICE:"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	header_row.add_child(label)

	# Sorting and selection controls
	var controls = _create_controls_row()
	header_row.add_child(controls)

	# Replace old label
	material_label.queue_free()
	parent.add_child(header_row)
	parent.move_child(header_row, idx)

func setup_xp_bar():
	"""Create the XP bar display"""
	for child in xp_bar_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	xp_bar_container.add_child(vbox)

	# Level preview label
	level_preview_label = Label.new()
	level_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_preview_label.add_theme_font_size_override("font_size", 16)
	level_preview_label.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(level_preview_label)

	# XP bar
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 25)
	xp_bar.show_percentage = false
	_style_progress_bar(xp_bar)
	hbox.add_child(xp_bar)

	# XP text label
	xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(150, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	hbox.add_child(xp_label)

func setup_target_display():
	"""Setup target god display"""
	for child in target_god_display.get_children():
		child.queue_free()

	await get_tree().process_frame
	_style_panel(target_god_display, true)

# ==============================================================================
# GRID POPULATION
# ==============================================================================
func populate_material_grid():
	"""Populate the material selection grid"""
	for child in material_grid.get_children():
		child.queue_free()

	# Set grid spacing and columns (fit more cards)
	material_grid.add_theme_constant_override("h_separation", 6)
	material_grid.add_theme_constant_override("v_separation", 6)
	material_grid.columns = 11  # More columns to fill width

	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return

	var gods = collection_manager.get_all_gods()

	# Filter out target god and sort
	var available_gods: Array = []
	for god in gods:
		if god != target_god:
			available_gods.append(god)

	var sorted_gods = _sort_gods(available_gods)

	# Create god cards
	for god in sorted_gods:
		var card = create_god_card(god)
		material_grid.add_child(card)

func create_god_card(god: God) -> Control:
	"""Create a god card for material selection"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(95, 125)  # Smaller to fit more

	# Style based on selection
	var style = StyleBoxFlat.new()
	if selected_materials.has(god):
		style.bg_color = COLOR_SELECTED
		style.border_color = COLOR_SELECTED_BORDER
		style.set_border_width_all(3)
	else:
		style.bg_color = COLOR_PANEL_BG
		style.border_color = COLOR_PANEL_BORDER
		style.set_border_width_all(1)

	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	# MarginContainer for padding
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	# Content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(60, 60)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		var god_texture = load(sprite_path)
		god_image.texture = god_texture

	vbox.add_child(god_image)

	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", COLOR_HEADER)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Level info
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(level_label)

	# Location info (garrison/worker)
	var location = _get_god_location(god)
	if location != "":
		var location_label = Label.new()
		location_label.text = location
		location_label.add_theme_font_size_override("font_size", 8)
		location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		location_label.add_theme_color_override("font_color", COLOR_WARNING)
		location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(location_label)

	# Make clickable if not locked
	if not locked_in:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_god_clicked.bind(god))
		card.add_child(button)

	return card

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_god_clicked(god: God):
	"""Handle god selection"""
	if locked_in:
		return

	if selected_materials.has(god):
		selected_materials.erase(god)
	else:
		selected_materials.append(god)

	update_all_displays()

# ==============================================================================
# UI UPDATES
# ==============================================================================
func update_all_displays():
	"""Update all UI displays"""
	update_target_display()
	update_xp_bar()
	populate_material_grid()
	update_button_states()

func update_target_display():
	"""Update target god display"""
	if not target_god:
		return

	for child in target_god_display.get_children():
		child.queue_free()

	await get_tree().process_frame

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	target_god_display.add_child(hbox)

	# Left margin
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(left_margin)

	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(80, 80)
	god_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = target_god.template_id if target_god.template_id else target_god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		var god_texture = load(sprite_path)
		god_image.texture = god_texture

	hbox.add_child(god_image)

	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var name_label = Label.new()
	name_label.text = target_god.name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_HEADER)
	info_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Level %d" % target_god.level
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color.GOLD)
	info_vbox.add_child(level_label)

	var details_label = Label.new()
	details_label.text = "%s %s - Power: %d" % [God.tier_to_string(target_god.tier), God.element_to_string(target_god.element), GodCalculator.get_power_rating(target_god)]
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	info_vbox.add_child(details_label)

	hbox.add_child(info_vbox)

func update_xp_bar():
	"""Update XP bar display with level gain preview"""
	if not target_god or not xp_bar or not xp_label or not level_preview_label:
		return

	var current_level = target_god.level
	var current_xp = target_god.experience
	var max_level = 40

	# Calculate preview XP
	var preview_xp = 0
	if selected_materials.size() > 0:
		var system_registry = SystemRegistry.get_instance()
		if system_registry:
			var sacrifice_system = system_registry.get_system("SacrificeSystem")
			if sacrifice_system:
				var result = sacrifice_system.calculate_sacrifice_experience(selected_materials, target_god)
				preview_xp = result.total_xp

	if current_level >= max_level:
		xp_bar.value = 100
		xp_bar.modulate = Color.GOLD
		xp_label.text = "MAX LEVEL"
		level_preview_label.text = "Level %d (MAX)" % current_level
		return

	# Calculate progress
	var xp_needed_for_next = GodCalculator.get_experience_to_next_level(target_god)
	var xp_progress_in_level = current_xp
	var current_level_progress = float(xp_progress_in_level) / float(xp_needed_for_next) if xp_needed_for_next > 0 else 0.0

	# Update progress bar and labels
	if preview_xp > 0:
		# Calculate new level after XP gain
		var new_total_xp = current_xp + preview_xp
		var new_level = GodExperienceCalculator.calculate_level_from_experience(new_total_xp)
		new_level = min(new_level, max_level)
		var levels_gained = new_level - current_level

		# Calculate progress bar for the NEW level
		var new_level_xp_needed = GodExperienceCalculator.get_experience_to_next_level(new_level)
		var new_level_start_xp = GodExperienceCalculator.get_total_experience_for_level(new_level)
		var xp_into_new_level = new_total_xp - new_level_start_xp
		var new_level_progress = float(xp_into_new_level) / float(new_level_xp_needed) * 100.0 if new_level_xp_needed > 0 else 100.0

		xp_bar.value = min(100, new_level_progress)
		xp_bar.modulate = COLOR_SUCCESS

		# Show XP gain
		xp_label.text = "%d XP (+%d)" % [current_xp, preview_xp]
		xp_label.add_theme_color_override("font_color", COLOR_SUCCESS)

		# Show level change preview
		if levels_gained > 0:
			if new_level >= max_level:
				level_preview_label.text = "Lv.%d -> Lv.%d (MAX!) +%d levels" % [current_level, new_level, levels_gained]
				level_preview_label.add_theme_color_override("font_color", Color.GOLD)
			else:
				level_preview_label.text = "Lv.%d -> Lv.%d (+%d levels!)" % [current_level, new_level, levels_gained]
				level_preview_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			level_preview_label.text = "Lv.%d (+%d XP)" % [current_level, preview_xp]
			level_preview_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	else:
		xp_bar.value = current_level_progress * 100
		xp_bar.modulate = Color.WHITE
		var xp_to_next = xp_needed_for_next
		xp_label.text = "%d / %d XP" % [xp_progress_in_level, xp_to_next]
		xp_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
		level_preview_label.text = "Level %d (%d XP to next)" % [current_level, xp_to_next]
		level_preview_label.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)

func update_button_states():
	"""Update button states"""
	if selected_materials.size() > 0 and not locked_in:
		lock_in_button.disabled = false
		lock_in_button.text = "Lock In Selection (%d gods)" % selected_materials.size()
	else:
		lock_in_button.disabled = true
		lock_in_button.text = "Lock In Selection"

	sacrifice_button.disabled = not locked_in or selected_materials.size() == 0

func _on_lock_in_pressed():
	"""Lock in selection"""
	if selected_materials.size() == 0:
		return

	locked_in = true
	lock_in_button.text = "Selection Locked (%d gods)" % selected_materials.size()
	lock_in_button.disabled = true

	update_all_displays()

func _on_sacrifice_pressed():
	"""Perform sacrifice"""
	if not locked_in or selected_materials.size() == 0 or not target_god:
		return

	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var sacrifice_manager = system_registry.get_system("SacrificeManager")
	var result = sacrifice_manager.perform_sacrifice(target_god, selected_materials)

	if result.success:
		_show_success_popup(result.xp_gained)
	else:
		_show_error_popup(result.error)

# ==============================================================================
# POPUPS
# ==============================================================================
func _show_success_popup(xp_gained: int):
	"""Show success popup with UI pattern styling"""
	var popup_overlay = ColorRect.new()
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100
	add_child(popup_overlay)

	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(400, 200)
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(popup_panel)
	popup_overlay.add_child(popup_panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	popup_panel.add_child(content)

	var title = Label.new()
	title.text = "Sacrifice Complete!"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var message = Label.new()
	message.text = "Your god gained %d experience!" % xp_gained
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", COLOR_SUCCESS)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)

	var ok_button = Button.new()
	ok_button.text = "Continue"
	ok_button.custom_minimum_size = Vector2(150, 40)
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(ok_button, true)
	ok_button.pressed.connect(func():
		popup_overlay.queue_free()
		_navigate_back_to_main()
	)
	content.add_child(ok_button)

func _show_error_popup(error_message: String):
	"""Show error popup"""
	var popup_overlay = ColorRect.new()
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100
	add_child(popup_overlay)

	popup_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			popup_overlay.queue_free()
	)

	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(400, 150)
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(popup_panel)
	popup_overlay.add_child(popup_panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	popup_panel.add_child(content)

	var title = Label.new()
	title.text = "Sacrifice Failed"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_WARNING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var message = Label.new()
	message.text = error_message
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)

# ==============================================================================
# NAVIGATION
# ==============================================================================
func _navigate_back_to_main():
	"""Navigate back to the main world view"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("worldview")

func _get_god_location(god: God) -> String:
	"""Get the location of a god (garrison or worker assignment)"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return ""

	var territory_manager = system_registry.get_system("TerritoryManager")
	if not territory_manager:
		return ""

	var controlled = territory_manager.get_controlled_nodes()
	for node in controlled:
		if node.garrison.find(god.id) != -1:
			return "Garrison: " + node.name
		if node.assigned_workers.find(god.id) != -1:
			return "Worker: " + node.name

	return ""

func _on_back_pressed():
	"""Handle back button - use ScreenManager for proper navigation"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("sacrifice")

	back_pressed.emit()
