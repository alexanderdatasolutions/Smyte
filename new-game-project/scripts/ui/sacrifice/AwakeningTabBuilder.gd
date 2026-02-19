# scripts/ui/sacrifice/AwakeningTabBuilder.gd
# Helper component for building and managing the awakening tab UI
# Centered vertical layout: God display box at top, materials below, god grid at bottom
class_name AwakeningTabBuilder
extends RefCounted

const CardFactory = preload("res://scripts/utilities/GodCardFactory.gd")
const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# Color palette (matching unified theme)
const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.8, 0.6, 0.4)
const COLOR_GOLD = Color(1.0, 0.85, 0.3)
const COLOR_AWAKENED = Color(0.9, 0.6, 1.0)

# Signals
signal god_awakened(god: God)

# UI references
var awakening_god_grid: GridContainer
var god_display_panel: PanelContainer
var god_portrait: TextureRect
var god_name_label: Label
var god_info_label: Label
var awakened_badge: Label
var materials_container: VBoxContainer
var awakening_button: Button
var select_prompt: Label
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

	# Main vertical layout - centered
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	awakening_tab.add_child(main_vbox)

	# Top section: Centered god display with materials
	builder._create_awakening_center_panel(main_vbox)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Bottom section: God selection grid
	builder._create_god_selection_section(main_vbox)

	# Load gods
	builder.refresh_awakening_god_list()

	return builder

func _create_awakening_center_panel(parent: Control):
	"""Create the centered awakening panel with god display and materials"""
	# Center container for the panel
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 320)
	parent.add_child(center)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.custom_minimum_size = Vector2(400, 0)
	panel_vbox.add_theme_constant_override("separation", 15)
	center.add_child(panel_vbox)

	# Title
	var title = Label.new()
	title.text = "AWAKENING"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_AWAKENED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_vbox.add_child(title)

	# God display box
	_create_god_display_box(panel_vbox)

	# Materials section
	_create_materials_section(panel_vbox)

	# Awaken button
	_create_awaken_button(panel_vbox)

func _create_god_display_box(parent: Control):
	"""Create the centered god display box"""
	god_display_panel = PanelContainer.new()
	god_display_panel.custom_minimum_size = Vector2(350, 150)

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	god_display_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(god_display_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	god_display_panel.add_child(margin)

	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(content_hbox)

	# Left side: Portrait
	var portrait_vbox = VBoxContainer.new()
	portrait_vbox.add_theme_constant_override("separation", 5)
	content_hbox.add_child(portrait_vbox)

	god_portrait = TextureRect.new()
	god_portrait.custom_minimum_size = Vector2(96, 96)
	god_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	god_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	god_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_portrait.visible = false
	portrait_vbox.add_child(god_portrait)

	# Awakened badge below portrait
	awakened_badge = Label.new()
	awakened_badge.text = "✦ AWAKENED ✦"
	awakened_badge.add_theme_font_size_override("font_size", 10)
	awakened_badge.add_theme_color_override("font_color", COLOR_AWAKENED)
	awakened_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	awakened_badge.visible = false
	portrait_vbox.add_child(awakened_badge)

	# Right side: Info
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content_hbox.add_child(info_vbox)

	# Select prompt (shown when no god selected)
	select_prompt = Label.new()
	select_prompt.text = "Select a god from below\nto awaken them"
	select_prompt.add_theme_font_size_override("font_size", 14)
	select_prompt.add_theme_color_override("font_color", COLOR_MUTED)
	select_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_vbox.add_child(select_prompt)

	# God name
	god_name_label = Label.new()
	god_name_label.add_theme_font_size_override("font_size", 18)
	god_name_label.add_theme_color_override("font_color", COLOR_HEADER)
	god_name_label.visible = false
	info_vbox.add_child(god_name_label)

	# God info (level, tier, element)
	god_info_label = Label.new()
	god_info_label.add_theme_font_size_override("font_size", 12)
	god_info_label.add_theme_color_override("font_color", COLOR_TEXT)
	god_info_label.visible = false
	info_vbox.add_child(god_info_label)

func _create_materials_section(parent: Control):
	"""Create materials display section"""
	var section_label = Label.new()
	section_label.text = "Required Materials"
	section_label.add_theme_font_size_override("font_size", 14)
	section_label.add_theme_color_override("font_color", COLOR_HEADER)
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(section_label)

	materials_container = VBoxContainer.new()
	materials_container.add_theme_constant_override("separation", 5)
	parent.add_child(materials_container)

func _create_awaken_button(parent: Control):
	"""Create the awaken button"""
	var button_center = CenterContainer.new()
	parent.add_child(button_center)

	awakening_button = Button.new()
	awakening_button.text = "AWAKEN"
	awakening_button.custom_minimum_size = Vector2(200, 50)
	awakening_button.disabled = true
	awakening_button.pressed.connect(_on_awaken_god_pressed)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.6, 0.3, 0.8, 0.9)
	btn_style.border_color = COLOR_AWAKENED
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(8)
	awakening_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.7, 0.4, 0.9, 1.0)
	awakening_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.3, 0.25, 0.35, 0.5)
	btn_disabled.border_color = Color(0.4, 0.35, 0.5, 0.5)
	awakening_button.add_theme_stylebox_override("disabled", btn_disabled)

	awakening_button.add_theme_font_size_override("font_size", 16)
	button_center.add_child(awakening_button)

func _create_god_selection_section(parent: Control):
	"""Create the god selection grid section"""
	# Header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	parent.add_child(header)

	var title = Label.new()
	title.text = "Select God to Awaken"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint = Label.new()
	hint.text = "(Epic/Legendary at Lv.40+)"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(hint)

	# Scrollable god grid
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll_container)

	awakening_god_grid = GridContainer.new()
	awakening_god_grid.columns = 6
	awakening_god_grid.add_theme_constant_override("h_separation", 10)
	awakening_god_grid.add_theme_constant_override("v_separation", 10)
	awakening_god_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(awakening_god_grid)

func refresh_awakening_god_list():
	"""Refresh the awakening god grid"""
	if not awakening_god_grid:
		return

	# Clear existing gods
	for child in awakening_god_grid.get_children():
		child.queue_free()

	if not collection_manager or not awakening_system:
		return

	# Get all gods that could potentially be awakened
	var all_gods = collection_manager.get_all_gods()
	var awakening_candidates = []

	for god in all_gods:
		# Filter: Epic+ tier and level 40+ and not awakened
		if god.tier >= God.TierType.EPIC and god.level >= 40 and not god.is_awakened:
			awakening_candidates.append(god)

	if awakening_candidates.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No gods ready for awakening\n(Need Epic/Legendary gods at level 40+)"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", COLOR_MUTED)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_god_grid.add_child(empty_label)
		return

	# Sort by tier (highest first), then level
	awakening_candidates.sort_custom(func(a, b):
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.level > b.level)

	# Create cards
	for god in awakening_candidates:
		var card = _create_god_card(god)
		awakening_god_grid.add_child(card)

func _create_god_card(god: God) -> Control:
	"""Create a god card for the selection grid"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(85, 110)

	# Check awakening readiness
	var requirements = awakening_system.can_awaken_god(god)
	var is_ready = requirements.can_awaken
	var is_selected = god == awakening_selected_god

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	if is_selected:
		style.border_color = COLOR_GOLD
		style.set_border_width_all(3)
	elif is_ready:
		style.border_color = COLOR_AWAKENED
		style.set_border_width_all(2)
	else:
		style.border_color = COLOR_PANEL_BORDER
		style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	# Content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Portrait
	var portrait_center = CenterContainer.new()
	vbox.add_child(portrait_center)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(50, 50)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Use GodPortraitHelper for proper skin/awakened portrait support
	var sprite_path = GodPortraitHelper.get_portrait_path(god)
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	portrait_center.add_child(portrait)

	# Name
	var name_label = Label.new()
	var display_name = god.name if god.name.length() <= 10 else god.name.substr(0, 9) + "…"
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", COLOR_HEADER)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.add_theme_color_override("font_color", COLOR_MUTED)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Ready indicator
	if is_ready:
		var ready_label = Label.new()
		ready_label.text = "✦ READY"
		ready_label.add_theme_font_size_override("font_size", 8)
		ready_label.add_theme_color_override("font_color", COLOR_AWAKENED)
		ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ready_label)

	# Click button
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_awakening_god_clicked.bind(god))
	card.add_child(button)

	return card

func _on_awakening_god_clicked(god: God):
	"""Handle awakening god selection"""
	if awakening_selected_god == god:
		awakening_selected_god = null
	else:
		awakening_selected_god = god

	_update_god_display()
	_update_materials_display()
	_update_awakening_button()
	refresh_awakening_god_list()

func _update_god_display():
	"""Update the god display box"""
	var has_god = awakening_selected_god != null

	# Toggle visibility
	select_prompt.visible = not has_god
	god_portrait.visible = has_god
	god_name_label.visible = has_god
	god_info_label.visible = has_god
	awakened_badge.visible = has_god and awakening_selected_god.is_awakened

	if not has_god:
		return

	# Update portrait using GodPortraitHelper for skin/awakened support
	var portrait_path = GodPortraitHelper.get_portrait_path(awakening_selected_god)
	if ResourceLoader.exists(portrait_path):
		god_portrait.texture = load(portrait_path)
	else:
		god_portrait.texture = null

	# Apply awakened glow effect
	if awakening_selected_god.is_awakened:
		god_portrait.modulate = Color(1.1, 0.95, 1.2)
	else:
		god_portrait.modulate = Color.WHITE

	# Name
	god_name_label.text = awakening_selected_god.name
	if awakening_selected_god.is_awakened:
		god_name_label.add_theme_color_override("font_color", COLOR_AWAKENED)
	else:
		god_name_label.add_theme_color_override("font_color", COLOR_HEADER)

	# Info line
	var tier_name = God.tier_to_string(awakening_selected_god.tier)
	var element_name = God.element_to_string(awakening_selected_god.element)
	god_info_label.text = "Lv.%d | %s | %s" % [awakening_selected_god.level, tier_name, element_name]

	# Update panel border to show selected state
	var style = god_display_panel.get_theme_stylebox("panel").duplicate()
	style.border_color = COLOR_AWAKENED
	god_display_panel.add_theme_stylebox_override("panel", style)

func _update_materials_display():
	"""Update materials display"""
	# Clear existing
	for child in materials_container.get_children():
		child.queue_free()

	if not awakening_selected_god:
		var no_selection = Label.new()
		no_selection.text = "Select a god to see requirements"
		no_selection.add_theme_font_size_override("font_size", 12)
		no_selection.add_theme_color_override("font_color", COLOR_MUTED)
		no_selection.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_container.add_child(no_selection)
		return

	if not awakening_system:
		return

	# Already awakened
	if awakening_selected_god.is_awakened:
		var complete_label = Label.new()
		complete_label.text = "This god has already been awakened!"
		complete_label.add_theme_font_size_override("font_size", 12)
		complete_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_container.add_child(complete_label)
		return

	# Check requirements first
	var requirements = awakening_system.can_awaken_god(awakening_selected_god)
	if not requirements.can_awaken:
		for missing in requirements.missing_requirements:
			var req_label = Label.new()
			req_label.text = "✗ " + missing
			req_label.add_theme_font_size_override("font_size", 11)
			req_label.add_theme_color_override("font_color", COLOR_WARNING)
			req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			materials_container.add_child(req_label)
		return

	# Show material costs
	var materials = awakening_system.get_awakening_materials_cost(awakening_selected_god)
	if materials.is_empty():
		var no_mats = Label.new()
		no_mats.text = "No materials required"
		no_mats.add_theme_color_override("font_color", COLOR_SUCCESS)
		no_mats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_container.add_child(no_mats)
		return

	# Center container for materials
	var mats_center = CenterContainer.new()
	materials_container.add_child(mats_center)

	var mats_vbox = VBoxContainer.new()
	mats_vbox.add_theme_constant_override("separation", 5)
	mats_center.add_child(mats_vbox)

	for material_id in materials:
		var needed = int(materials[material_id])
		var current = resource_manager.get_resource(material_id) if resource_manager else 0
		var has_enough = current >= needed

		var mat_row = _create_material_row(material_id, needed, current, has_enough)
		mats_vbox.add_child(mat_row)

func _create_material_row(material_id: String, needed: int, current: int, has_enough: bool) -> Control:
	"""Create a material requirement row"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Status icon
	var status = Label.new()
	status.text = "✓" if has_enough else "✗"
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", COLOR_SUCCESS if has_enough else COLOR_WARNING)
	row.add_child(status)

	# Material name
	var name_label = Label.new()
	name_label.text = _format_material_name(material_id)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	# Amount
	var amount_label = Label.new()
	amount_label.text = "%d / %d" % [current, needed]
	amount_label.add_theme_font_size_override("font_size", 12)
	if has_enough:
		amount_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		amount_label.add_theme_color_override("font_color", COLOR_WARNING)
	row.add_child(amount_label)

	return row

func _format_material_name(material_id: String) -> String:
	"""Format material ID to display name"""
	return material_id.replace("_", " ").capitalize()

func _update_awakening_button():
	"""Update awaken button state"""
	if not awakening_button:
		return

	if not awakening_selected_god or not awakening_system:
		awakening_button.disabled = true
		awakening_button.text = "AWAKEN"
		return

	if awakening_selected_god.is_awakened:
		awakening_button.disabled = true
		awakening_button.text = "ALREADY AWAKENED"
		return

	# Check all requirements
	var requirements = awakening_system.can_awaken_god(awakening_selected_god)
	if not requirements.can_awaken:
		awakening_button.disabled = true
		awakening_button.text = "REQUIREMENTS NOT MET"
		return

	# Check materials
	var materials = awakening_system.get_awakening_materials_cost(awakening_selected_god)
	var materials_check = awakening_system.check_awakening_materials(materials)

	if not materials_check.can_afford:
		awakening_button.disabled = true
		awakening_button.text = "INSUFFICIENT MATERIALS"
		return

	awakening_button.disabled = false
	awakening_button.text = "AWAKEN %s" % awakening_selected_god.name

func _on_awaken_god_pressed():
	"""Handle awakening button press"""
	if not awakening_selected_god or not awakening_system:
		return

	# Store the index before awakening (the god object will be replaced)
	var old_god_index: int = -1
	for i in range(collection_manager.gods.size()):
		if collection_manager.gods[i] == awakening_selected_god:
			old_god_index = i
			break

	if awakening_system.attempt_awakening(awakening_selected_god):
		# Get the NEW awakened god from the collection (it replaced the old one)
		if old_god_index >= 0 and old_god_index < collection_manager.gods.size():
			awakening_selected_god = collection_manager.gods[old_god_index]

		# Update display with the new awakened god
		_update_god_display()
		_update_materials_display()
		_update_awakening_button()
		refresh_awakening_god_list()
		god_awakened.emit(awakening_selected_god)

func get_selected_god() -> God:
	"""Get the currently selected awakening god"""
	return awakening_selected_god
