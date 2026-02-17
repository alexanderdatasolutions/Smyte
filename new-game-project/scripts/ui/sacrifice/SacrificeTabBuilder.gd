# scripts/ui/sacrifice/SacrificeTabBuilder.gd
# Consolidated sacrifice tab - select target AND sacrifice materials on one screen
# Uses GodCard component for consistent UI across screens
class_name SacrificeTabBuilder
extends RefCounted

const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# UI Design Pattern Colors (matching TeamSelectionManager)
const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.9, 0.6, 0.4)

# Selection overlay colors
const COLOR_TARGET_BORDER = Color(1.0, 0.85, 0.2)  # Gold for target
const COLOR_SACRIFICE_BORDER = Color(0.8, 0.4, 0.4)  # Red for sacrifice

# Signals
signal god_selected(god: God)
signal sacrifice_requested(god: God)
signal sacrifice_completed(xp_gained: int)

# UI references
var god_list: GridContainer
var target_god_display: Control
var sacrifice_list_container: VBoxContainer
var sacrifice_button: Button
var lock_in_button: Button
var clear_sacrifices_btn: Button
var scroll_container: ScrollContainer
var xp_bar: ProgressBar
var xp_label: Label
var level_preview_label: Label
var parent_tab: Control

# State
var selected_target: God = null
var selected_sacrifices: Array[God] = []
var locked_in: bool = false

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
	builder.parent_tab = sacrifice_tab

	# Create horizontal layout matching UI patterns
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 15)
	sacrifice_tab.add_child(main_hbox)

	# Left panel - Target + Sacrifices + XP Preview (fixed width)
	builder._create_left_panel(main_hbox)

	# Right panel - God grid (flexible width)
	builder._create_god_grid_panel(main_hbox)

	# Load gods
	builder.refresh_god_list()

	return builder

func _create_left_panel(parent: Control):
	"""Create the left panel with target, sacrifices, and XP preview"""
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(380, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(left_panel)
	parent.add_child(left_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# ===== TARGET GOD SECTION =====
	var target_header = HBoxContainer.new()
	vbox.add_child(target_header)

	var target_title = Label.new()
	target_title.text = "TARGET GOD"
	target_title.add_theme_font_size_override("font_size", 14)
	target_title.add_theme_color_override("font_color", Color.GOLD)
	target_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_header.add_child(target_title)

	var clear_target_btn = Button.new()
	clear_target_btn.text = "Clear"
	clear_target_btn.custom_minimum_size = Vector2(60, 26)
	clear_target_btn.pressed.connect(_on_clear_target)
	_style_button(clear_target_btn, false)
	target_header.add_child(clear_target_btn)

	# Target god display area
	_create_target_display(vbox)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# ===== XP PREVIEW SECTION =====
	var xp_title = Label.new()
	xp_title.text = "XP PREVIEW"
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_title.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(xp_title)

	_create_xp_preview(vbox)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# ===== SACRIFICE SELECTION SECTION =====
	var sacrifice_header = HBoxContainer.new()
	sacrifice_header.add_theme_constant_override("separation", 10)
	vbox.add_child(sacrifice_header)

	var sacrifice_title = Label.new()
	sacrifice_title.text = "SACRIFICES"
	sacrifice_title.add_theme_font_size_override("font_size", 14)
	sacrifice_title.add_theme_color_override("font_color", Color(0.8, 0.6, 0.9))
	sacrifice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sacrifice_header.add_child(sacrifice_title)

	# Select Duplicates button
	var select_dupes_btn = Button.new()
	select_dupes_btn.text = "Dupes"
	select_dupes_btn.custom_minimum_size = Vector2(55, 26)
	select_dupes_btn.tooltip_text = "Select all duplicate gods"
	select_dupes_btn.pressed.connect(_on_select_duplicates)
	_style_button(select_dupes_btn, false)
	sacrifice_header.add_child(select_dupes_btn)

	clear_sacrifices_btn = Button.new()
	clear_sacrifices_btn.text = "Clear"
	clear_sacrifices_btn.custom_minimum_size = Vector2(55, 26)
	clear_sacrifices_btn.pressed.connect(_on_clear_sacrifices)
	_style_button(clear_sacrifices_btn, false)
	sacrifice_header.add_child(clear_sacrifices_btn)

	# Sacrifice list container
	sacrifice_list_container = VBoxContainer.new()
	sacrifice_list_container.add_theme_constant_override("separation", 4)
	vbox.add_child(sacrifice_list_container)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Click a god to set as TARGET (gold)\nClick more gods to add as SACRIFICES (purple)"
	instructions.add_theme_font_size_override("font_size", 10)
	instructions.add_theme_color_override("font_color", COLOR_MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Separator
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# ===== ACTION BUTTONS =====
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(button_container)

	lock_in_button = Button.new()
	lock_in_button.text = "LOCK IN SELECTION"
	lock_in_button.custom_minimum_size = Vector2(0, 40)
	lock_in_button.disabled = true
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	_style_button(lock_in_button, false)
	button_container.add_child(lock_in_button)

	sacrifice_button = Button.new()
	sacrifice_button.text = "SACRIFICE"
	sacrifice_button.custom_minimum_size = Vector2(0, 45)
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	_style_button(sacrifice_button, true)
	button_container.add_child(sacrifice_button)

func _create_target_display(parent: Control):
	"""Create the target god display area"""
	target_god_display = PanelContainer.new()
	target_god_display.custom_minimum_size = Vector2(0, 100)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	target_god_display.add_theme_stylebox_override("panel", style)

	parent.add_child(target_god_display)
	_update_target_display()

func _create_xp_preview(parent: Control):
	"""Create XP preview bar and labels"""
	var xp_container = VBoxContainer.new()
	xp_container.add_theme_constant_override("separation", 5)
	parent.add_child(xp_container)

	# Level preview label
	level_preview_label = Label.new()
	level_preview_label.text = "Select a target god"
	level_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_preview_label.add_theme_font_size_override("font_size", 14)
	level_preview_label.add_theme_color_override("font_color", COLOR_HEADER)
	xp_container.add_child(level_preview_label)

	# XP bar row
	var bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	xp_container.add_child(bar_row)

	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 20)
	xp_bar.show_percentage = false
	_style_progress_bar(xp_bar)
	bar_row.add_child(xp_bar)

	xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(100, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_font_size_override("font_size", 11)
	xp_label.add_theme_color_override("font_color", COLOR_TEXT)
	bar_row.add_child(xp_label)

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
	title.text = "SELECT GODS"
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
	god_list.columns = 6  # 6 columns fits well with GodCard MEDIUM size
	god_list.add_theme_constant_override("h_separation", 6)
	god_list.add_theme_constant_override("v_separation", 6)
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
	"""Sort gods based on current sort settings, with assigned gods always at bottom"""
	var sorted = gods.duplicate()

	# Sort with assigned gods always at the bottom
	sorted.sort_custom(func(a, b):
		var a_assigned: bool = _get_god_location(a) != ""
		var b_assigned: bool = _get_god_location(b) != ""

		# Assigned gods go to bottom
		if a_assigned != b_assigned:
			return not a_assigned  # Available gods come first

		# Within same group, sort by selected criteria
		match current_sort:
			SortType.POWER:
				var pa = GodCalculator.get_power_rating(a)
				var pb = GodCalculator.get_power_rating(b)
				return pa < pb if sort_ascending else pa > pb
			SortType.LEVEL:
				return a.level < b.level if sort_ascending else a.level > b.level
			SortType.TIER:
				return a.tier < b.tier if sort_ascending else a.tier > b.tier
			SortType.ELEMENT:
				return a.element < b.element if sort_ascending else a.element > b.element
			SortType.NAME:
				return a.name < b.name if sort_ascending else a.name > b.name
		return false
	)

	return sorted

# ==============================================================================
# GOD SELECTION LOGIC
# ==============================================================================

func _on_god_clicked(god: God):
	"""Handle god selection - first click = target, subsequent = sacrifice"""
	if locked_in:
		return

	# If no target selected, this becomes the target
	if selected_target == null:
		selected_target = god
		_update_all_displays()
		god_selected.emit(god)
		return

	# If clicking the target, clear it
	if god == selected_target:
		selected_target = null
		selected_sacrifices.clear()
		_update_all_displays()
		return

	# Otherwise toggle as sacrifice material
	if selected_sacrifices.has(god):
		selected_sacrifices.erase(god)
	else:
		selected_sacrifices.append(god)

	_update_all_displays()

func _on_clear_target():
	"""Clear target god selection"""
	if locked_in:
		return
	selected_target = null
	selected_sacrifices.clear()
	_update_all_displays()

func _on_clear_sacrifices():
	"""Clear sacrifice selections"""
	if locked_in:
		return
	selected_sacrifices.clear()
	_update_all_displays()

func _on_select_duplicates():
	"""Select all duplicate gods as sacrifices"""
	if locked_in or selected_target == null:
		return

	var gods = collection_manager.get_all_gods()

	# Count gods by template_id
	var template_counts: Dictionary = {}
	var gods_by_template: Dictionary = {}

	for god in gods:
		if god == selected_target:
			continue
		# Skip assigned gods
		var location = _get_god_location(god)
		if location != "":
			continue
		var template = god.template_id if god.template_id else god.id
		if not template_counts.has(template):
			template_counts[template] = 0
			gods_by_template[template] = []
		template_counts[template] += 1
		gods_by_template[template].append(god)

	# Select duplicates (keep best, sacrifice rest)
	selected_sacrifices.clear()
	for template in gods_by_template:
		if template_counts[template] > 1:
			var template_gods = gods_by_template[template]
			template_gods.sort_custom(func(a, b): return a.level > b.level)
			for i in range(1, template_gods.size()):
				selected_sacrifices.append(template_gods[i])

	_update_all_displays()

func _on_lock_in_pressed():
	"""Lock in selection"""
	if selected_target == null or selected_sacrifices.size() == 0:
		return

	locked_in = true
	lock_in_button.text = "LOCKED (%d gods)" % selected_sacrifices.size()
	lock_in_button.disabled = true
	_update_all_displays()

func _on_sacrifice_pressed():
	"""Perform the sacrifice"""
	if not locked_in or selected_target == null or selected_sacrifices.size() == 0:
		return

	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var sacrifice_manager = system_registry.get_system("SacrificeManager")
	if not sacrifice_manager:
		return

	var result = sacrifice_manager.perform_sacrifice(selected_target, selected_sacrifices)

	if result.success:
		_show_success_popup(result.xp_gained)
		sacrifice_completed.emit(result.xp_gained)
	else:
		_show_error_popup(result.error)

# ==============================================================================
# DISPLAY UPDATES
# ==============================================================================

func _update_all_displays():
	"""Update all UI displays"""
	_update_target_display()
	_update_xp_preview()
	_update_sacrifice_list()
	_update_button_states()
	refresh_god_list()

func _update_target_display():
	"""Update target god display"""
	if not target_god_display:
		return

	for child in target_god_display.get_children():
		child.queue_free()

	if not selected_target:
		var center = CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target_god_display.add_child(center)

		var label = Label.new()
		label.text = "Click a god to set as target"
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", COLOR_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.add_child(label)

		# Update border to normal
		var empty_style = target_god_display.get_theme_stylebox("panel").duplicate()
		empty_style.border_color = COLOR_PANEL_BORDER
		target_god_display.add_theme_stylebox_override("panel", empty_style)
		return

	# Update border to gold
	var selected_style = target_god_display.get_theme_stylebox("panel").duplicate()
	selected_style.border_color = Color.GOLD
	selected_style.set_border_width_all(2)
	target_god_display.add_theme_stylebox_override("panel", selected_style)

	# Create god display content
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	target_god_display.add_child(hbox)

	# God image
	var image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(70, 70)
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = selected_target.template_id if selected_target.template_id else selected_target.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		image_rect.texture = load(sprite_path)
	hbox.add_child(image_rect)

	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = selected_target.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_HEADER)
	info_vbox.add_child(name_label)

	var tier_label = Label.new()
	tier_label.text = "%s | %s" % [God.tier_to_string(selected_target.tier), God.element_to_string(selected_target.element)]
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(tier_label)

	var level_label = Label.new()
	level_label.text = "Level: %d" % selected_target.level
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color.GOLD)
	info_vbox.add_child(level_label)

	var power_label = Label.new()
	power_label.text = "Power: %d" % GodCalculator.get_power_rating(selected_target)
	power_label.add_theme_font_size_override("font_size", 10)
	power_label.add_theme_color_override("font_color", COLOR_MUTED)
	info_vbox.add_child(power_label)

func _update_xp_preview():
	"""Update XP bar display with level gain preview"""
	if not xp_bar or not xp_label or not level_preview_label:
		return

	if not selected_target:
		xp_bar.value = 0
		xp_label.text = ""
		level_preview_label.text = "Select a target god"
		level_preview_label.add_theme_color_override("font_color", COLOR_MUTED)
		return

	var current_level = selected_target.level
	var current_xp = selected_target.experience
	var max_level: int = God.get_max_level()  # Single source of truth from progression_config.json

	# Calculate preview XP
	var preview_xp: int = 0
	if selected_sacrifices.size() > 0:
		var system_registry = SystemRegistry.get_instance()
		if system_registry:
			var sacrifice_system = system_registry.get_system("SacrificeSystem")
			if sacrifice_system:
				var result = sacrifice_system.calculate_sacrifice_experience(selected_sacrifices, selected_target)
				preview_xp = result.total_xp

	if current_level >= max_level:
		xp_bar.value = 100
		xp_bar.modulate = Color.GOLD
		xp_label.text = "MAX"
		level_preview_label.text = "Level %d (MAX)" % current_level
		return

	# Calculate progress
	var xp_needed_for_next = GodCalculator.get_experience_to_next_level(selected_target)
	var xp_progress_in_level = current_xp
	var current_level_progress: float = float(xp_progress_in_level) / float(xp_needed_for_next) if xp_needed_for_next > 0 else 0.0

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
		var new_level_progress: float = float(xp_into_new_level) / float(new_level_xp_needed) * 100.0 if new_level_xp_needed > 0 else 100.0

		xp_bar.value = min(100, new_level_progress)
		xp_bar.modulate = COLOR_SUCCESS

		xp_label.text = "+%d XP" % preview_xp
		xp_label.add_theme_color_override("font_color", COLOR_SUCCESS)

		if levels_gained > 0:
			if new_level >= max_level:
				level_preview_label.text = "Lv.%d -> Lv.%d (MAX!)" % [current_level, new_level]
				level_preview_label.add_theme_color_override("font_color", Color.GOLD)
			else:
				level_preview_label.text = "Lv.%d -> Lv.%d (+%d)" % [current_level, new_level, levels_gained]
				level_preview_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			level_preview_label.text = "Lv.%d (+%d XP)" % [current_level, preview_xp]
			level_preview_label.add_theme_color_override("font_color", COLOR_TEXT)
	else:
		xp_bar.value = current_level_progress * 100
		xp_bar.modulate = Color.WHITE
		xp_label.text = "%d/%d" % [xp_progress_in_level, xp_needed_for_next]
		xp_label.add_theme_color_override("font_color", COLOR_TEXT)
		level_preview_label.text = "Level %d" % current_level
		level_preview_label.add_theme_color_override("font_color", COLOR_TEXT)

func _update_sacrifice_list():
	"""Update the sacrifice list display"""
	if not sacrifice_list_container:
		return

	for child in sacrifice_list_container.get_children():
		child.queue_free()

	if selected_sacrifices.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No sacrifices selected"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", COLOR_MUTED)
		sacrifice_list_container.add_child(empty_label)
		return

	# Show count header
	var count_label = Label.new()
	count_label.text = "%d gods selected:" % selected_sacrifices.size()
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.9))
	sacrifice_list_container.add_child(count_label)

	# Show first few sacrifices (compact list)
	var max_shown = 5
	for i in range(min(selected_sacrifices.size(), max_shown)):
		var god = selected_sacrifices[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var bullet = Label.new()
		bullet.text = "•"
		bullet.add_theme_font_size_override("font_size", 10)
		bullet.add_theme_color_override("font_color", COLOR_SACRIFICE_BORDER)
		row.add_child(bullet)

		var name_lbl = Label.new()
		name_lbl.text = "%s Lv.%d" % [god.name, god.level]
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		sacrifice_list_container.add_child(row)

	if selected_sacrifices.size() > max_shown:
		var more_label = Label.new()
		more_label.text = "  ... and %d more" % (selected_sacrifices.size() - max_shown)
		more_label.add_theme_font_size_override("font_size", 10)
		more_label.add_theme_color_override("font_color", COLOR_MUTED)
		sacrifice_list_container.add_child(more_label)

func _update_button_states():
	"""Update button states"""
	if lock_in_button:
		if locked_in:
			lock_in_button.disabled = true
			lock_in_button.text = "LOCKED (%d gods)" % selected_sacrifices.size()
		elif selected_target and selected_sacrifices.size() > 0:
			lock_in_button.disabled = false
			lock_in_button.text = "LOCK IN (%d gods)" % selected_sacrifices.size()
		else:
			lock_in_button.disabled = true
			lock_in_button.text = "LOCK IN SELECTION"

	if sacrifice_button:
		sacrifice_button.disabled = not locked_in

func refresh_god_list():
	"""Refresh the god list display"""
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
	"""Create a god card using the standard GodCard component with selection overlay"""
	var is_target = (god == selected_target)
	var is_sacrifice = selected_sacrifices.has(god)
	var location = _get_god_location(god)
	var is_assigned = location != ""

	# Determine if card should be clickable (BEFORE setup)
	var should_be_clickable = not locked_in and not is_assigned

	# Container for card + selection indicator overlay
	var container = Control.new()
	container.custom_minimum_size = Vector2(120, 165)

	# Create GodCard using the standard component
	var card = GodCardScript.new()
	card.card_size = GodCardScript.CardSize.MEDIUM
	card.show_power_rating = true
	card.show_territory_assignment = false  # We handle assignment by dimming
	card.show_equipment_status = false  # Hide equipment for sacrifice screen
	card.clickable = should_be_clickable  # Set BEFORE setup_god_card

	# Determine card style
	var card_style = GodCardScript.CardStyle.NORMAL
	if is_target:
		card_style = GodCardScript.CardStyle.SELECTED
	elif is_sacrifice:
		card_style = GodCardScript.CardStyle.BATTLE_READY  # Blue tint for sacrifice

	card.setup_god_card(god, card_style)
	container.add_child(card)

	# Apply selection border override for sacrifice
	if is_sacrifice:
		var style = card.get_theme_stylebox("panel").duplicate()
		style.border_color = COLOR_SACRIFICE_BORDER
		style.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", style)

	# Dim assigned gods
	if is_assigned:
		card.modulate = Color(0.5, 0.5, 0.5)

	# Connect card's signal to our handler (only if clickable)
	if should_be_clickable:
		card.god_selected.connect(func(g: God): _on_god_clicked(g))

	# Add selection indicator label at top
	if is_target or is_sacrifice:
		var indicator = Label.new()
		indicator.set_anchors_preset(Control.PRESET_TOP_WIDE)
		indicator.offset_top = 2
		indicator.offset_bottom = 16
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.add_theme_font_size_override("font_size", 10)
		indicator.z_index = 10

		if is_target:
			indicator.text = "TARGET"
			indicator.add_theme_color_override("font_color", Color.GOLD)
		else:
			indicator.text = "SACRIFICE"
			indicator.add_theme_color_override("font_color", COLOR_SACRIFICE_BORDER)

		container.add_child(indicator)

	# Add assignment indicator for assigned gods
	if is_assigned:
		var assign_label = Label.new()
		assign_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		assign_label.offset_top = -16
		assign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		assign_label.add_theme_font_size_override("font_size", 9)
		assign_label.add_theme_color_override("font_color", COLOR_WARNING)
		assign_label.text = location.split(":")[0]  # "Garrison" or "Worker"
		assign_label.z_index = 10
		container.add_child(assign_label)

	return container

# ==============================================================================
# HELPERS
# ==============================================================================

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

func get_selected_god() -> God:
	"""Get the currently selected target god"""
	return selected_target

# ==============================================================================
# POPUPS
# ==============================================================================

func _show_success_popup(xp_gained: int):
	"""Show success popup"""
	if not parent_tab:
		return

	var popup_overlay = ColorRect.new()
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100
	parent_tab.add_child(popup_overlay)

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
	message.text = "%s gained %d experience!" % [selected_target.name if selected_target else "Your god", xp_gained]
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
		# Reset state for next sacrifice
		_reset_state()
	)
	content.add_child(ok_button)

func _show_error_popup(error_message: String):
	"""Show error popup"""
	if not parent_tab:
		return

	var popup_overlay = ColorRect.new()
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100
	parent_tab.add_child(popup_overlay)

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
	message.add_theme_color_override("font_color", COLOR_TEXT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)

func _reset_state():
	"""Reset state after successful sacrifice"""
	selected_target = null
	selected_sacrifices.clear()
	locked_in = false
	_update_all_displays()

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

func _style_progress_bar(bar: ProgressBar):
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.08, 0.12, 0.9)
	bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.6, 0.8, 0.9)
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)
