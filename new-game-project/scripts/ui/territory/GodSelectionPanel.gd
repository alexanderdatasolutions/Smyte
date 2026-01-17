# GodSelectionPanel - Left-sliding overlay for god selection
class_name GodSelectionPanel
extends Control

"""
GodSelectionPanel - Mobile-friendly sliding panel for god selection

Slides in from the LEFT side of the screen (opposite of TerritoryOverviewScreen which slides from RIGHT).
Contains a GodSelectionGrid and additional filter options for Worker/Garrison selection.

Usage:
  panel.show_for_garrison(excluded_ids)  # Filter for combat-ready gods
  panel.show_for_worker(excluded_ids)    # Filter for available workers
  panel.show_all(excluded_ids)           # Show all available gods
"""

signal god_selected(god: God)
signal selection_cancelled
signal panel_closed

enum SelectionContext { ALL, WORKER, GARRISON }

const PANEL_WIDTH := 400  # Width of the sliding panel
const SLIDE_DURATION := 0.25  # Animation duration in seconds
const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1), God.ElementType.WATER: Color(0.2, 0.5, 0.9),
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2), God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0),
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3), God.ElementType.DARK: Color(0.5, 0.2, 0.6)
}

# UI Components
var _overlay_bg: ColorRect
var _panel_container: Panel
var _header_container: HBoxContainer
var _close_button: Button
var _title_label: Label
var _filter_bar: HBoxContainer
var _context_filters: HBoxContainer
var _affinity_filters: HBoxContainer
var _god_selection_grid: GodSelectionGrid
var _content_container: VBoxContainer

# State
var _current_context: SelectionContext = SelectionContext.ALL
var _active_affinity_filter: God.ElementType = -1  # -1 means no filter
var _excluded_god_ids: Array[String] = []
var _is_visible: bool = false
var _slide_tween: Tween = null

# Systems
var collection_manager = null

func _ready() -> void:
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _setup_fullscreen() -> void:
	"""Setup fullscreen sizing (required when Control is child of Node2D)"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("set_size", viewport_size)
	position = Vector2.ZERO
	clip_contents = true

func _init_systems() -> void:
	"""Initialize system references via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		collection_manager = registry.get_system("CollectionManager")

func _build_ui() -> void:
	"""Build the complete UI structure"""
	# Semi-transparent overlay background (clicking closes panel)
	_overlay_bg = ColorRect.new()
	_overlay_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_bg.color = Color(0, 0, 0, 0.5)
	_overlay_bg.gui_input.connect(_on_overlay_input)
	add_child(_overlay_bg)

	# Panel container (slides from left)
	_panel_container = Panel.new()
	_panel_container.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel_container.anchor_left = 0
	_panel_container.anchor_top = 0
	_panel_container.anchor_right = 0
	_panel_container.anchor_bottom = 1
	_panel_container.offset_left = -PANEL_WIDTH  # Start off-screen to the left
	_panel_container.offset_right = 0
	_panel_container.offset_top = 0
	_panel_container.offset_bottom = 0
	add_child(_panel_container)

	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.3, 0.35, 0.4)
	panel_style.border_width_right = 2
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	_panel_container.add_theme_stylebox_override("panel", panel_style)

	# Inner margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel_container.add_child(margin)

	# Main vertical layout
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 12)
	margin.add_child(_content_container)

	# Build header
	_build_header()

	# Build filter bars
	_build_filter_bars()

	# Build god selection grid (embedded, not as overlay)
	_build_god_grid()

func _build_header() -> void:
	"""Build header with title and close button"""
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 70)  # Increased for 60x60 close button

	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_panel.add_theme_stylebox_override("panel", header_style)
	_content_container.add_child(header_panel)

	_header_container = HBoxContainer.new()
	_header_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header_container.offset_left = 12
	_header_container.offset_right = -12
	_header_container.offset_top = 8
	_header_container.offset_bottom = -8
	_header_container.add_theme_constant_override("separation", 12)
	header_panel.add_child(_header_container)

	# Close button (60x60px minimum tap target)
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(60, 60)
	_close_button.pressed.connect(_on_close_pressed)
	_style_close_button(_close_button)
	_header_container.add_child(_close_button)

	# Title label
	_title_label = Label.new()
	_title_label.text = "Select God"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_container.add_child(_title_label)

	# Spacer to balance the close button
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(60, 0)
	_header_container.add_child(spacer)

func _build_filter_bars() -> void:
	"""Build context and affinity filter bars"""
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 8)
	_content_container.add_child(_filter_bar)

	# Context filters (All / Worker / Garrison)
	_context_filters = HBoxContainer.new()
	_context_filters.add_theme_constant_override("separation", 4)
	_filter_bar.add_child(_context_filters)

	var context_options = [
		{"text": "All", "context": SelectionContext.ALL},
		{"text": "Worker", "context": SelectionContext.WORKER},
		{"text": "Garrison", "context": SelectionContext.GARRISON}
	]

	for option in context_options:
		var btn = Button.new()
		btn.text = option.text
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(70, 36)
		btn.button_pressed = (option.context == _current_context)
		btn.toggled.connect(_create_context_handler(option.context))
		_style_filter_button(btn, option.context == _current_context)
		_context_filters.add_child(btn)

	# Separator
	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(8, 0)
	_filter_bar.add_child(sep)

	# Affinity filter label
	var affinity_label = Label.new()
	affinity_label.text = "Element:"
	affinity_label.add_theme_font_size_override("font_size", 12)
	affinity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	affinity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_filter_bar.add_child(affinity_label)

	# Build affinity filter row in second line
	_affinity_filters = HBoxContainer.new()
	_affinity_filters.add_theme_constant_override("separation", 4)
	_content_container.add_child(_affinity_filters)

	# "All" element filter
	var all_btn = Button.new()
	all_btn.text = "All"
	all_btn.toggle_mode = true
	all_btn.custom_minimum_size = Vector2(40, 32)
	all_btn.button_pressed = true
	all_btn.toggled.connect(func(pressed): _on_affinity_filter_changed(-1, pressed))
	_style_filter_button(all_btn, true)
	_affinity_filters.add_child(all_btn)

	# Element-specific filters
	var elements = [
		God.ElementType.FIRE, God.ElementType.WATER, God.ElementType.EARTH,
		God.ElementType.LIGHTNING, God.ElementType.LIGHT, God.ElementType.DARK
	]
	var element_icons = {
		God.ElementType.FIRE: "Fire", God.ElementType.WATER: "Water",
		God.ElementType.EARTH: "Earth", God.ElementType.LIGHTNING: "Ltn",
		God.ElementType.LIGHT: "Light", God.ElementType.DARK: "Dark"
	}

	for elem in elements:
		var elem_btn = Button.new()
		elem_btn.text = element_icons.get(elem, "?")
		elem_btn.toggle_mode = true
		elem_btn.custom_minimum_size = Vector2(48, 32)
		elem_btn.button_pressed = false
		elem_btn.toggled.connect(func(pressed): _on_affinity_filter_changed(elem, pressed))
		_style_element_button(elem_btn, elem, false)
		_affinity_filters.add_child(elem_btn)

func _build_god_grid() -> void:
	"""Build the embedded god selection grid"""
	# Create a custom grid view (simpler than embedding GodSelectionGrid)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_container.add_child(scroll)

	var grid = GridContainer.new()
	grid.name = "GodGrid"
	grid.columns = 4  # Fit in narrower panel
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

func _style_close_button(button: Button) -> void:
	"""Apply close button styling"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.15, 0.15, 0.9)
	style_normal.border_color = Color(0.5, 0.3, 0.3)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.35, 0.2, 0.2, 0.95)
	style_hover.border_color = Color(0.6, 0.4, 0.4)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.7))
	button.add_theme_font_size_override("font_size", 16)

func _style_filter_button(button: Button, active: bool) -> void:
	"""Apply filter button styling"""
	var bg_color = Color(0.2, 0.3, 0.4, 0.9) if active else Color(0.15, 0.15, 0.2, 0.8)
	var border_color = Color(0.4, 0.5, 0.6) if active else Color(0.3, 0.3, 0.4)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)

	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE if active else Color(0.7, 0.7, 0.8))

func _style_element_button(button: Button, element: God.ElementType, active: bool) -> void:
	"""Apply element-specific button styling"""
	var elem_color = ELEMENT_COLORS.get(element, Color.GRAY)
	var bg_color = elem_color.darkened(0.4) if active else Color(0.15, 0.15, 0.2, 0.8)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = elem_color if active else Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)

	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color.WHITE)

func _create_context_handler(context: SelectionContext) -> Callable:
	"""Create callable for context filter toggle"""
	return func(pressed: bool):
		if pressed:
			_set_context_filter(context)

func _set_context_filter(context: SelectionContext) -> void:
	"""Set context filter and update UI"""
	_current_context = context
	_update_context_buttons()
	_refresh_god_grid()

func _update_context_buttons() -> void:
	"""Update context button pressed states"""
	var contexts = [SelectionContext.ALL, SelectionContext.WORKER, SelectionContext.GARRISON]
	var buttons = _context_filters.get_children()
	for i in range(min(buttons.size(), contexts.size())):
		if buttons[i] is Button:
			var is_active = (contexts[i] == _current_context)
			buttons[i].set_pressed_no_signal(is_active)
			_style_filter_button(buttons[i], is_active)

func _on_affinity_filter_changed(element: int, pressed: bool) -> void:
	"""Handle affinity filter change"""
	if pressed:
		_active_affinity_filter = element
		_update_affinity_buttons()
		_refresh_god_grid()

func _update_affinity_buttons() -> void:
	"""Update affinity button states"""
	var buttons = _affinity_filters.get_children()
	var elements = [-1, God.ElementType.FIRE, God.ElementType.WATER, God.ElementType.EARTH,
		God.ElementType.LIGHTNING, God.ElementType.LIGHT, God.ElementType.DARK]

	for i in range(min(buttons.size(), elements.size())):
		if buttons[i] is Button:
			var is_active = (elements[i] == _active_affinity_filter)
			buttons[i].set_pressed_no_signal(is_active)
			if i == 0:
				_style_filter_button(buttons[i], is_active)
			else:
				_style_element_button(buttons[i], elements[i], is_active)

# =============================================================================
# PUBLIC API
# =============================================================================

func show_for_garrison(excluded_ids: Array[String] = []) -> void:
	"""Show panel filtered for garrison selection (combat-ready gods)"""
	_title_label.text = "Select Garrison Defender"
	_current_context = SelectionContext.GARRISON
	_excluded_god_ids = excluded_ids
	_active_affinity_filter = -1
	_update_context_buttons()
	_update_affinity_buttons()
	_show_panel()

func show_for_worker(excluded_ids: Array[String] = []) -> void:
	"""Show panel filtered for worker selection"""
	_title_label.text = "Select Worker"
	_current_context = SelectionContext.WORKER
	_excluded_god_ids = excluded_ids
	_active_affinity_filter = -1
	_update_context_buttons()
	_update_affinity_buttons()
	_show_panel()

func show_all(excluded_ids: Array[String] = [], title: String = "Select God") -> void:
	"""Show panel with all gods"""
	_title_label.text = title
	_current_context = SelectionContext.ALL
	_excluded_god_ids = excluded_ids
	_active_affinity_filter = -1
	_update_context_buttons()
	_update_affinity_buttons()
	_show_panel()

func hide_panel() -> void:
	"""Hide the panel with slide-out animation"""
	if not _is_visible:
		return

	_is_visible = false

	# Cancel any existing tween
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)

	# Slide out to left and fade overlay
	_slide_tween.tween_property(_panel_container, "offset_left", -PANEL_WIDTH, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(_panel_container, "offset_right", 0, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(_overlay_bg, "color:a", 0.0, SLIDE_DURATION)

	_slide_tween.tween_callback(func():
		visible = false
		panel_closed.emit()
	)

func is_panel_visible() -> bool:
	return _is_visible

# =============================================================================
# INTERNAL METHODS
# =============================================================================

func _show_panel() -> void:
	"""Show the panel with slide-in animation"""
	visible = true
	_is_visible = true

	# Reset positions for animation
	_panel_container.offset_left = -PANEL_WIDTH
	_panel_container.offset_right = 0
	_overlay_bg.color.a = 0.0

	# Refresh grid first
	_refresh_god_grid()

	# Cancel any existing tween
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)

	# Slide in from left and fade in overlay
	_slide_tween.tween_property(_panel_container, "offset_left", 0, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(_panel_container, "offset_right", PANEL_WIDTH, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(_overlay_bg, "color:a", 0.5, SLIDE_DURATION)

	print("GodSelectionPanel: Showing panel (context: %s)" % SelectionContext.keys()[_current_context])

func _refresh_god_grid() -> void:
	"""Refresh the god grid with current filters"""
	var grid = _content_container.get_node_or_null("../MarginContainer/VBoxContainer/ScrollContainer/GodGrid")
	if not grid:
		# Try to find it differently
		for child in _content_container.get_children():
			if child is ScrollContainer:
				grid = child.get_child(0) if child.get_child_count() > 0 else null
				break

	if not grid:
		push_error("GodSelectionPanel: Could not find GodGrid")
		return

	# Clear existing cards
	for child in grid.get_children():
		child.queue_free()

	if not collection_manager:
		_add_error_label(grid, "Collection not available")
		return

	var all_gods = collection_manager.get_all_gods()
	if all_gods == null or all_gods.is_empty():
		_add_empty_label(grid, "No gods available")
		return

	# Filter gods
	var filtered_gods = _filter_gods(all_gods)

	if filtered_gods.is_empty():
		_add_empty_label(grid, "No gods match filters")
		return

	# Sort by element, then level
	filtered_gods.sort_custom(func(a, b):
		if a.element != b.element:
			return a.element < b.element
		return a.level > b.level
	)

	# Create cards
	for god in filtered_gods:
		var card = _create_god_card(god)
		grid.add_child(card)

	print("GodSelectionPanel: Displaying %d gods" % filtered_gods.size())

func _filter_gods(gods: Array) -> Array:
	"""Apply current filters to god list"""
	var result = []

	for god in gods:
		if not god is God:
			continue

		# Exclusion check
		if god.id in _excluded_god_ids:
			continue

		# Context filter
		match _current_context:
			SelectionContext.WORKER:
				if god.stationed_territory != "" or god.is_working_on_task():
					continue
			SelectionContext.GARRISON:
				if god.stationed_territory != "" or god.is_working_on_task():
					continue
				# Garrison prefers combat-capable gods
				if god.level < 5 and god.base_attack <= 50:
					continue

		# Affinity filter
		if _active_affinity_filter >= 0:
			if god.element != _active_affinity_filter:
				continue

		result.append(god)

	return result

func _create_god_card(god: God) -> Control:
	"""Create a compact god card (80x100px)"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(80, 100)
	card.name = "GodCard_" + god.id

	# Style with element border
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = element_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	# Content layout
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Portrait (40x40)
	var portrait_container = CenterContainer.new()
	var portrait = _create_portrait(god)
	portrait_container.add_child(portrait)
	vbox.add_child(portrait_container)

	# Name (truncated)
	var name_label = Label.new()
	name_label.text = _truncate_name(god.name, 10)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Invisible tap button
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_card_pressed.bind(god))
	card.add_child(button)

	return card

func _create_portrait(god: God) -> Control:
	"""Create god portrait with element-colored placeholder"""
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
		image.fill(element_color)
		portrait.texture = ImageTexture.create_from_image(image)

	return portrait

func _truncate_name(text: String, max_length: int) -> String:
	"""Truncate name if too long"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 2) + ".."

func _add_empty_label(parent: Control, message: String) -> void:
	"""Add empty state label"""
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _add_error_label(parent: Control, message: String) -> void:
	"""Add error state label"""
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _on_god_card_pressed(god: God) -> void:
	"""Handle god card tap"""
	print("GodSelectionPanel: Selected %s (Lv.%d)" % [god.name, god.level])
	god_selected.emit(god)
	hide_panel()

func _on_close_pressed() -> void:
	"""Handle close button press"""
	selection_cancelled.emit()
	hide_panel()

func _on_overlay_input(event: InputEvent) -> void:
	"""Handle input on overlay background (tap to close)"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if tap was outside panel
			var local_pos = _panel_container.get_local_mouse_position()
			var panel_rect = Rect2(Vector2.ZERO, _panel_container.size)
			if not panel_rect.has_point(local_pos):
				selection_cancelled.emit()
				hide_panel()

func _input(event: InputEvent) -> void:
	"""Handle global input for back gesture/escape"""
	if not _is_visible:
		return

	if event.is_action_pressed("ui_cancel"):
		selection_cancelled.emit()
		hide_panel()
		get_viewport().set_input_as_handled()
