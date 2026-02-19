# GodSelectionPanel - Left-sliding overlay for god selection
# Uses standardized GodCard component for consistent appearance
class_name GodSelectionPanel
extends Control

"""
GodSelectionPanel - Mobile-friendly sliding panel for god selection

Slides in from the LEFT side of the screen (opposite of TerritoryOverviewScreen which slides from RIGHT).
Uses standardized GodCard components for consistent UI across all god selection screens.

Usage:
  panel.show_for_garrison(excluded_ids)  # Filter for combat-ready gods
  panel.show_for_worker(excluded_ids)    # Filter for available workers
  panel.show_all(excluded_ids)           # Show all available gods
"""

signal god_selected(god: God)
signal selection_cancelled
signal panel_closed

enum SelectionContext { ALL, WORKER, GARRISON }
enum SortType { RECOMMENDED, POWER, LEVEL, TIER, ELEMENT, NAME }

const PANEL_WIDTH := 400  # Width of the sliding panel
const SLIDE_DURATION := 0.25  # Animation duration in seconds

# UI Components
var _overlay_bg: ColorRect
var _panel_container: Panel
var _header_container: HBoxContainer
var _close_button: Button
var _title_label: Label
var _filter_bar: HBoxContainer
var _context_filters: HBoxContainer
var _affinity_filters: HBoxContainer
var _sort_bar: HBoxContainer
var _sort_dropdown: OptionButton
var _sort_direction_btn: Button
var _god_selection_grid: GodSelectionGrid
var _content_container: VBoxContainer

# State
var _current_context: SelectionContext = SelectionContext.ALL
var _active_affinity_filter: God.ElementType = -1  # -1 means no filter
var _current_sort: SortType = SortType.RECOMMENDED
var _sort_ascending: bool = false  # false = descending (highest first)
var _excluded_god_ids: Array[String] = []
var _is_visible: bool = false
var _slide_tween: Tween = null
var _current_node: HexNode = null  # Node context for element matching

# Systems
var collection_manager = null

func _ready() -> void:
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _setup_fullscreen() -> void:
	"""Setup fullscreen sizing (required when Control is child of Node2D)"""
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
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
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.3, 0.35, 0.4)
	panel_style.border_width_right = 2
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	_panel_container.add_theme_stylebox_override("panel", panel_style)

	# Inner margin container - fills the panel using anchors
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel_container.add_child(margin)
	margin.anchor_left = 0
	margin.anchor_right = 1
	margin.anchor_top = 0
	margin.anchor_bottom = 1
	margin.offset_left = 0
	margin.offset_right = 0
	margin.offset_top = 0
	margin.offset_bottom = 0

	# Main vertical layout - MarginContainer auto-sizes its single child
	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var header_panel: Panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 70)  # Increased for 60x60 close button

	var header_style: StyleBoxFlat = StyleBoxFlat.new()
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
	var spacer: Control = Control.new()
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
		var btn: Button = Button.new()
		btn.text = option.text
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(70, 36)
		btn.button_pressed = (option.context == _current_context)
		btn.toggled.connect(_create_context_handler(option.context))
		_style_filter_button(btn, option.context == _current_context)
		_context_filters.add_child(btn)

	# Separator
	var sep: VSeparator = VSeparator.new()
	sep.custom_minimum_size = Vector2(8, 0)
	_filter_bar.add_child(sep)

	# Affinity filter label
	var affinity_label: Label = Label.new()
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
	var all_btn: Button = Button.new()
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
		var elem_btn: Button = Button.new()
		elem_btn.text = element_icons.get(elem, "?")
		elem_btn.toggle_mode = true
		elem_btn.custom_minimum_size = Vector2(48, 32)
		elem_btn.button_pressed = false
		elem_btn.toggled.connect(func(pressed): _on_affinity_filter_changed(elem, pressed))
		_style_element_button(elem_btn, elem, false)
		_affinity_filters.add_child(elem_btn)

	# Build sort controls row
	_build_sort_bar()

func _build_sort_bar() -> void:
	"""Build sort dropdown and direction toggle"""
	_sort_bar = HBoxContainer.new()
	_sort_bar.add_theme_constant_override("separation", 8)
	_content_container.add_child(_sort_bar)

	# Sort label
	var sort_label: Label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sort_bar.add_child(sort_label)

	# Sort dropdown
	_sort_dropdown = OptionButton.new()
	_sort_dropdown.custom_minimum_size = Vector2(120, 32)
	_sort_dropdown.add_item("Recommended", SortType.RECOMMENDED)
	_sort_dropdown.add_item("Power", SortType.POWER)
	_sort_dropdown.add_item("Level", SortType.LEVEL)
	_sort_dropdown.add_item("Tier", SortType.TIER)
	_sort_dropdown.add_item("Element", SortType.ELEMENT)
	_sort_dropdown.add_item("Name", SortType.NAME)
	_sort_dropdown.selected = 0
	_sort_dropdown.item_selected.connect(_on_sort_changed)
	_sort_bar.add_child(_sort_dropdown)

	# Sort direction button
	_sort_direction_btn = Button.new()
	_sort_direction_btn.text = "▼"
	_sort_direction_btn.custom_minimum_size = Vector2(32, 32)
	_sort_direction_btn.tooltip_text = "Toggle sort direction"
	_sort_direction_btn.pressed.connect(_on_sort_direction_pressed)
	_sort_bar.add_child(_sort_direction_btn)

func _build_god_grid() -> void:
	"""Build the embedded god selection grid"""
	# Create scroll container that expands to fill remaining space
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "GodScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 200)  # Minimum height fallback
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.follow_focus = false  # Prevent scroll jumping
	_content_container.add_child(scroll)

	# Grid container - must NOT expand vertically so it can grow beyond scroll viewport
	var grid: GridContainer = GridContainer.new()
	grid.name = "GodGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # Critical: don't expand, let it grow
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

func _style_close_button(button: Button) -> void:
	"""Apply close button styling"""
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.15, 0.15, 0.9)
	style_normal.border_color = Color(0.5, 0.3, 0.3)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = StyleBoxFlat.new()
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
	var bg_color: Color = Color(0.2, 0.3, 0.4, 0.9) if active else Color(0.15, 0.15, 0.2, 0.8)
	var border_color: Color = Color(0.4, 0.5, 0.6) if active else Color(0.3, 0.3, 0.4)

	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	var elem_color: Color = GodUIHelpers.get_element_color(element)
	var bg_color: Color = elem_color.darkened(0.4) if active else Color(0.15, 0.15, 0.2, 0.8)

	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	var contexts: Array = [SelectionContext.ALL, SelectionContext.WORKER, SelectionContext.GARRISON]
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

func show_for_garrison(excluded_ids: Array[String] = [], node: HexNode = null) -> void:
	"""Show panel filtered for garrison selection (combat-ready gods)"""
	_title_label.text = "Select Garrison Defender"
	_current_context = SelectionContext.GARRISON
	_excluded_god_ids = excluded_ids
	_current_node = node
	_active_affinity_filter = -1
	_current_sort = SortType.RECOMMENDED
	_sort_ascending = false
	if _sort_dropdown:
		_sort_dropdown.selected = 0
	if _sort_direction_btn:
		_sort_direction_btn.text = "▼"
	_update_context_buttons()
	_update_affinity_buttons()
	_show_panel()

func show_for_worker(excluded_ids: Array[String] = [], node: HexNode = null) -> void:
	"""Show panel filtered for worker selection"""
	_title_label.text = "Select Worker"
	_current_context = SelectionContext.WORKER
	_excluded_god_ids = excluded_ids
	_current_node = node
	_active_affinity_filter = -1
	_current_sort = SortType.RECOMMENDED
	_sort_ascending = false
	if _sort_dropdown:
		_sort_dropdown.selected = 0
	if _sort_direction_btn:
		_sort_direction_btn.text = "▼"
	_update_context_buttons()
	_update_affinity_buttons()
	_show_panel()

func show_all(excluded_ids: Array[String] = [], title: String = "Select God", node: HexNode = null) -> void:
	"""Show panel with all gods"""
	_title_label.text = title
	_current_context = SelectionContext.ALL
	_excluded_god_ids = excluded_ids
	_current_node = node
	_active_affinity_filter = -1
	_current_sort = SortType.RECOMMENDED
	_sort_ascending = false
	if _sort_dropdown:
		_sort_dropdown.selected = 0
	if _sort_direction_btn:
		_sort_direction_btn.text = "▼"
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

	# Debug: print first few god details
	for i in range(mini(all_gods.size(), 5)):
		var g = all_gods[i]

	# Filter gods
	var filtered_gods = _filter_gods(all_gods)

	if filtered_gods.is_empty():
		_add_empty_label(grid, "No gods match filters")
		return

	# Sort gods using current sort settings
	var sorted_gods = _sort_gods(filtered_gods)

	# Create cards
	for god in sorted_gods:
		var card = _create_god_card(god)
		grid.add_child(card)


func _sort_gods(gods: Array) -> Array:
	"""Sort gods based on current sort settings"""
	var sorted = gods.duplicate()

	match _current_sort:
		SortType.RECOMMENDED:
			# Recommended: unassigned first, then synergy score, then matching element, then power
			# Get current garrison gods for synergy calculation
			var garrison_gods = _get_garrison_gods()
			sorted.sort_custom(func(a, b):
				# First priority: unassigned gods first
				var a_assigned = a.id in _excluded_god_ids
				var b_assigned = b.id in _excluded_god_ids
				if a_assigned != b_assigned:
					return not a_assigned  # unassigned comes first
				# Second priority: team synergy score (how much this god improves team bonuses)
				var a_synergy = _calculate_synergy_score(a, garrison_gods)
				var b_synergy = _calculate_synergy_score(b, garrison_gods)
				if a_synergy != b_synergy:
					return a_synergy > b_synergy  # higher synergy first
				# Third priority: matching node element
				var a_matches = _god_matches_node_element(a)
				var b_matches = _god_matches_node_element(b)
				if a_matches != b_matches:
					return a_matches  # matching element first
				# Fourth priority: power (descending)
				var pa = _calculate_god_power(a)
				var pb = _calculate_god_power(b)
				return pa > pb)
		SortType.POWER:
			sorted.sort_custom(func(a, b):
				var pa = _calculate_god_power(a)
				var pb = _calculate_god_power(b)
				return pa < pb if _sort_ascending else pa > pb)
		SortType.LEVEL:
			sorted.sort_custom(func(a, b):
				return a.level < b.level if _sort_ascending else a.level > b.level)
		SortType.TIER:
			sorted.sort_custom(func(a, b):
				return a.tier < b.tier if _sort_ascending else a.tier > b.tier)
		SortType.ELEMENT:
			sorted.sort_custom(func(a, b):
				return a.element < b.element if _sort_ascending else a.element > b.element)
		SortType.NAME:
			sorted.sort_custom(func(a, b):
				return a.name < b.name if _sort_ascending else a.name > b.name)

	return sorted

func _god_matches_node_element(god: God) -> bool:
	"""Check if god's element matches the current node's element"""
	if not _current_node or not god:
		return false
	if "element" in _current_node:
		return god.element == _current_node.element
	return false

func _calculate_god_power(god: God) -> float:
	"""Calculate combat power using unified GodCalculator system"""
	if not god:
		return 0.0
	# Use get_combat_power for full individual combat potential
	# (includes crit effectiveness, equipment set bonuses, etc.)
	return float(GodCalculator.get_combat_power(god))

func _get_garrison_gods() -> Array:
	"""Get the gods currently in the node's garrison"""
	if not _current_node or not collection_manager:
		return []

	var gods: Array = []
	for god_id in _current_node.garrison:
		var god = collection_manager.get_god_by_id(god_id)
		if god:
			gods.append(god)
	return gods

func _calculate_synergy_score(god: God, garrison_gods: Array) -> float:
	"""Calculate synergy score using unified GodCalculator system.
	Considers: team bonuses, special synergies, element matching, role diversity, leader skills"""
	if not god:
		return 0.0

	# Get node element for matching bonus
	var node_element: int = -1
	if _current_node and "element" in _current_node:
		node_element = _current_node.element

	# Use the unified synergy calculation from GodCalculator
	return GodCalculator.calculate_synergy_score(god, garrison_gods, node_element)

func _on_sort_changed(index: int) -> void:
	"""Handle sort dropdown selection change"""
	_current_sort = _sort_dropdown.get_item_id(index) as SortType
	_refresh_god_grid()

func _on_sort_direction_pressed() -> void:
	"""Handle sort direction toggle"""
	_sort_ascending = not _sort_ascending
	_sort_direction_btn.text = "▲" if _sort_ascending else "▼"
	_refresh_god_grid()

func _filter_gods(gods: Array) -> Array:
	"""Apply current filters to god list (assigned gods are shown but grayed out)"""
	var result: Array = []

	for god in gods:
		if not god is God:
			continue

		# SHOW ALL GODS - assigned gods will be grayed out in _create_god_card()
		# Don't filter based on assignment status - let the UI handle that

		# Only apply element/affinity filter if active
		if _active_affinity_filter >= 0:
			if god.element != _active_affinity_filter:
				continue

		result.append(god)

	return result

func _create_god_card(god: God) -> Control:
	"""Create a compact god card (80x100px), grayed out if already assigned"""
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(80, 100)
	card.name = "GodCard_" + god.id

	# Check if god is already assigned - either to this node (in exclusion list) or stationed elsewhere
	var is_assigned = god.id in _excluded_god_ids
	var current_node_id = _current_node.id if _current_node else ""
	var is_stationed_elsewhere = god.stationed_territory != "" and god.stationed_territory != current_node_id
	var is_working = god.is_working_on_task() if god.has_method("is_working_on_task") else false
	var is_unavailable = is_assigned or is_stationed_elsewhere or is_working

	# Style with element border (dimmed if unavailable)
	var element_color = GodUIHelpers.get_element_color(god.element)
	if is_unavailable:
		element_color = element_color * 0.4  # Dim the border color

	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_unavailable:
		style.bg_color = Color(0.1, 0.1, 0.12, 0.7)  # Darker background for unavailable
	else:
		style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = element_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	# Content layout
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Portrait (40x40)
	var portrait_container: CenterContainer = CenterContainer.new()
	var portrait = _create_portrait(god)
	if is_unavailable:
		portrait.modulate = Color(0.5, 0.5, 0.5, 0.8)  # Dim the portrait
	portrait_container.add_child(portrait)
	vbox.add_child(portrait_container)

	# Status indicator badge for unavailable gods
	if is_unavailable:
		var status_badge: Label = Label.new()
		if is_stationed_elsewhere:
			status_badge.text = "STATIONED"
		elif is_working:
			status_badge.text = "WORKING"
		else:
			status_badge.text = "ASSIGNED"
		status_badge.add_theme_font_size_override("font_size", 8)
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3, 0.9))  # Orange warning color
		status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(status_badge)

	# Name (truncated)
	var name_label: Label = Label.new()
	name_label.text = _truncate_name(god.name, 10)
	name_label.add_theme_font_size_override("font_size", 10)
	if is_unavailable:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Dimmed white
	else:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level + Element (compact row)
	var level_elem_row: HBoxContainer = HBoxContainer.new()
	level_elem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_elem_row.add_theme_constant_override("separation", 2)
	vbox.add_child(level_elem_row)

	var level_label: Label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	if is_unavailable:
		level_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))  # More dimmed
	else:
		level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_elem_row.add_child(level_label)

	# Element icon
	var elem_label: Label = Label.new()
	elem_label.text = _get_element_icon(god.element)
	elem_label.add_theme_font_size_override("font_size", 9)
	var elem_color = GodUIHelpers.get_element_color(god.element)
	if is_unavailable:
		elem_color = elem_color * 0.5
	elem_label.add_theme_color_override("font_color", elem_color)
	level_elem_row.add_child(elem_label)

	# Power display
	var power_label: Label = Label.new()
	var power = _calculate_god_power(god)
	power_label.text = "⚔%.0f" % power
	power_label.add_theme_font_size_override("font_size", 9)
	if is_unavailable:
		power_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	else:
		power_label.add_theme_color_override("font_color", Color.GOLD)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(power_label)

	# Invisible tap button
	var button: Button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_card_pressed.bind(god))
	card.add_child(button)

	return card

func _create_portrait(god: God) -> Control:
	"""Create god portrait with element-colored placeholder"""
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = god.template_id if god.template_id else god.id
	var sprite_path: String = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		var element_color = GodUIHelpers.get_element_color(god.element)
		var image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
		image.fill(element_color)
		portrait.texture = ImageTexture.create_from_image(image)

	return portrait

func _truncate_name(text: String, max_length: int) -> String:
	"""Truncate name if too long"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 2) + ".."

func _get_element_icon(element: God.ElementType) -> String:
	"""Get element icon for display"""
	match element:
		God.ElementType.FIRE: return "🔥"
		God.ElementType.WATER: return "💧"
		God.ElementType.EARTH: return "🌍"
		God.ElementType.LIGHTNING: return "⚡"
		God.ElementType.LIGHT: return "✨"
		God.ElementType.DARK: return "🌑"
		_: return "?"

func _add_empty_label(parent: Control, message: String) -> void:
	"""Add empty state label"""
	var label: Label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _add_error_label(parent: Control, message: String) -> void:
	"""Add error state label"""
	var label: Label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _on_god_card_pressed(god: God) -> void:
	"""Handle god card tap"""
	# Don't allow selecting already-assigned gods
	if god.id in _excluded_god_ids:
		return
	god_selected.emit(god)
	hide_panel()

func _on_close_pressed() -> void:
	"""Handle close button press"""
	selection_cancelled.emit()
	hide_panel()

func _on_overlay_input(event: InputEvent) -> void:
	"""Handle input on overlay background (tap to close, pass through scroll)"""
	if event is InputEventMouseButton:
		# Only handle left click for closing, let scroll events pass through
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
