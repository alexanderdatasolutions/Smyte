# GodSelectionGrid - Mobile-friendly god selection for territory node management
class_name GodSelectionGrid
extends Control

signal god_selected(god: God)
signal selection_cancelled

enum FilterMode { ALL, AVAILABLE, ASSIGNED, GARRISON_READY, WORKER_READY }

const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1), God.ElementType.WATER: Color(0.2, 0.5, 0.9),
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2), God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0),
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3), God.ElementType.DARK: Color(0.5, 0.2, 0.6)
}
const ELEMENT_ICONS = {
	God.ElementType.FIRE: "🔥", God.ElementType.WATER: "💧", God.ElementType.EARTH: "🪨",
	God.ElementType.LIGHTNING: "⚡", God.ElementType.LIGHT: "☀️", God.ElementType.DARK: "🌙"
}
const CARD_WIDTH = 80
const CARD_HEIGHT = 100
const CARD_SPACING = 8
const GRID_COLUMNS = 5
const FADE_DURATION := 0.15

var collection_manager
var event_bus
var _title_bar: HBoxContainer
var _title_label: Label
var _close_button: Button
var _filter_container: HBoxContainer
var _scroll_container: ScrollContainer
var _god_grid: GridContainer
var _current_filter: FilterMode = FilterMode.ALL
var _excluded_god_ids: Array[String] = []
var _is_loading: bool = false

func _ready() -> void:
	_init_systems()
	_setup_ui()

func _init_systems() -> void:
	var registry = SystemRegistry.get_instance()
	if registry:
		collection_manager = registry.get_system("CollectionManager")
		event_bus = registry.get_system("EventBus")

func _setup_ui() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12

	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Main container with margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Title bar with close button
	_setup_title_bar(main_vbox)

	# Filter buttons
	_setup_filter_buttons(main_vbox)

	# Scrollable god grid
	_setup_god_grid(main_vbox)

func _setup_title_bar(parent: Control) -> void:
	"""Setup title bar with label and close button"""
	_title_bar = HBoxContainer.new()
	_title_bar.custom_minimum_size = Vector2(0, 40)
	parent.add_child(_title_bar)

	_title_label = Label.new()
	_title_label.text = "Select God"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_bar.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(60, 60)  # Meets 60px minimum tap target
	_close_button.pressed.connect(_on_close_pressed)
	_style_close_button(_close_button)
	_title_bar.add_child(_close_button)

func _setup_filter_buttons(parent: Control) -> void:
	"""Setup filter toggle buttons"""
	_filter_container = HBoxContainer.new()
	_filter_container.add_theme_constant_override("separation", 8)
	parent.add_child(_filter_container)

	var filters = [
		{"text": "All", "mode": FilterMode.ALL},
		{"text": "Available", "mode": FilterMode.AVAILABLE},
		{"text": "Assigned", "mode": FilterMode.ASSIGNED}
	]

	for filter_data in filters:
		var btn = Button.new()
		btn.text = filter_data.text
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(80, 36)
		btn.button_pressed = (filter_data.mode == _current_filter)
		btn.toggled.connect(_create_filter_handler(filter_data.mode))
		_filter_container.add_child(btn)

func _create_filter_handler(mode: FilterMode) -> Callable:
	"""Create a callable for filter button toggle"""
	return func(pressed: bool):
		if pressed:
			_set_filter(mode)

func _setup_god_grid(parent: Control) -> void:
	"""Setup scrollable grid container for god cards"""
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_scroll_container)

	_god_grid = GridContainer.new()
	_god_grid.columns = GRID_COLUMNS
	_god_grid.add_theme_constant_override("h_separation", CARD_SPACING)
	_god_grid.add_theme_constant_override("v_separation", CARD_SPACING)
	_scroll_container.add_child(_god_grid)

# =============================================================================
# PUBLIC API
# =============================================================================

func show_selection(title: String = "Select God", filter: FilterMode = FilterMode.ALL, excluded_ids: Array[String] = []) -> void:
	"""Show the god selection grid with specified filter and title, with smooth fade-in"""
	_title_label.text = title
	_current_filter = filter
	_excluded_god_ids = excluded_ids
	_update_filter_buttons()

	# Show loading state first
	_show_loading_state()

	# Smooth fade-in
	modulate.a = 0.0
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT)

	# Refresh display after a brief moment (allows fade to start)
	await get_tree().create_timer(0.05).timeout
	refresh_display()

func hide_selection() -> void:
	"""Hide the god selection grid with smooth fade-out"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		modulate.a = 1.0  # Reset for next show
	)

func set_filter(filter: FilterMode) -> void:
	"""Set the current filter mode and refresh"""
	_set_filter(filter)

func set_excluded_gods(god_ids: Array[String]) -> void:
	"""Set gods to exclude from the selection (e.g., already selected)"""
	_excluded_god_ids = god_ids
	refresh_display()

func refresh_display() -> void:
	"""Refresh the god grid with current filter - RULE 4: Read-only"""
	_is_loading = false

	# Error handling: CollectionManager not available
	if not collection_manager:
		_show_error_state("Collection not available")
		push_error("GodSelectionGrid: CollectionManager not available for refresh")
		return

	# Clear existing cards
	for child in _god_grid.get_children():
		child.queue_free()

	# Get all gods with error handling
	var all_gods = collection_manager.get_all_gods()
	if all_gods == null:
		_show_error_state("Failed to load gods")
		push_error("GodSelectionGrid: get_all_gods() returned null")
		return

	# Apply filter and exclusions
	var filtered_gods = _apply_filter(all_gods)

	# Show empty state if no gods match filter
	if filtered_gods.is_empty():
		_show_empty_state()
		print("GodSelectionGrid: No gods match current filter")
		return

	# Sort by element for nice visual grouping
	filtered_gods.sort_custom(_compare_gods_by_element)

	# Create cards for each god
	for god in filtered_gods:
		if god == null:
			push_warning("GodSelectionGrid: Skipping null god in filtered list")
			continue
		var card = _create_god_card(god)
		_god_grid.add_child(card)

	print("GodSelectionGrid: Displayed %d gods (filter: %s)" % [filtered_gods.size(), FilterMode.keys()[_current_filter]])

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _set_filter(mode: FilterMode) -> void:
	"""Internal filter setter"""
	_current_filter = mode
	_update_filter_buttons()
	refresh_display()

func _update_filter_buttons() -> void:
	"""Update filter button pressed states"""
	var filter_modes = [FilterMode.ALL, FilterMode.AVAILABLE, FilterMode.ASSIGNED]
	var buttons = _filter_container.get_children()
	for i in range(min(buttons.size(), filter_modes.size())):
		if buttons[i] is Button:
			buttons[i].set_pressed_no_signal(filter_modes[i] == _current_filter)

func _apply_filter(gods: Array) -> Array:
	"""Apply current filter to god list"""
	var result = []

	for god in gods:
		if not god is God:
			continue

		# Check exclusion list
		if god.id in _excluded_god_ids:
			continue

		# Apply filter
		var include = false
		match _current_filter:
			FilterMode.ALL:
				include = true
			FilterMode.AVAILABLE:
				include = not _is_god_assigned(god)
			FilterMode.ASSIGNED:
				include = _is_god_assigned(god)
			FilterMode.GARRISON_READY:
				include = not _is_god_assigned(god) and _is_combat_capable(god)
			FilterMode.WORKER_READY:
				include = not _is_god_assigned(god)

		if include:
			result.append(god)

	return result

func _is_god_assigned(god: God) -> bool:
	"""Check if god is assigned to territory or task"""
	return god.stationed_territory != "" or god.is_working_on_task()

func _is_combat_capable(god: God) -> bool:
	"""Check if god is suitable for garrison (has decent combat stats)"""
	# Simple check: level 5+ or has some combat stats
	return god.level >= 5 or god.base_attack > 50

func _compare_gods_by_element(a: God, b: God) -> bool:
	"""Compare gods by element for sorting"""
	if a.element != b.element:
		return a.element < b.element
	# Secondary sort by level descending
	return a.level > b.level

func _create_god_card(god: God) -> Control:
	"""Create a compact god card with affinity color border (80x100px)"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.name = "GodCard_" + god.id

	# Style with element/affinity color border - enhanced width for visibility
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = element_color
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	# Main layout
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

	# Portrait (40x40) with element badge overlay
	var portrait_container = CenterContainer.new()
	var portrait = _create_portrait(god)
	portrait_container.add_child(portrait)
	vbox.add_child(portrait_container)

	# Name label (compact, truncated if needed)
	var name_label = Label.new()
	name_label.text = _truncate_name(god.name, 10)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Element indicator row - icon with colored background
	var element_row = _create_element_indicator(god)
	vbox.add_child(element_row)

	# Level label
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Make tappable with invisible button (60x60 min tap target)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_card_pressed.bind(god))
	card.add_child(button)

	return card

func _create_element_indicator(god: God) -> Control:
	"""Create element indicator with icon and colored background badge"""
	var container = CenterContainer.new()

	# Badge panel with element color
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(24, 16)

	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = element_color.darkened(0.2)
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	badge.add_theme_stylebox_override("panel", badge_style)

	# Element icon label
	var icon_label = Label.new()
	icon_label.text = ELEMENT_ICONS.get(god.element, "?")
	icon_label.add_theme_font_size_override("font_size", 10)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(icon_label)

	container.add_child(badge)
	return container

func _create_portrait(god: God) -> Control:
	"""Create god portrait with element-colored placeholder if no image"""
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Try to load portrait
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		# Create element-colored placeholder
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var placeholder = _create_color_placeholder(element_color, 40, 40)
		portrait.texture = placeholder

	return portrait

func _create_color_placeholder(color: Color, width: int, height: int) -> ImageTexture:
	"""Create a colored placeholder texture"""
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	return texture

func _truncate_name(text: String, max_length: int) -> String:
	"""Truncate name if too long"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 2) + ".."

func _on_god_card_pressed(god: God) -> void:
	"""Handle god card tap - emit signal"""
	print("GodSelectionGrid: God selected - %s (Lv.%d)" % [god.name, god.level])
	god_selected.emit(god)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	selection_cancelled.emit()
	hide_selection()

func _style_close_button(button: Button) -> void:
	"""Apply consistent close button styling"""
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
	button.add_theme_font_size_override("font_size", 20)

func _show_loading_state() -> void:
	"""Show loading indicator while gods are being loaded"""
	_is_loading = true
	# Clear existing cards
	for child in _god_grid.get_children():
		child.queue_free()

	# Add loading label
	var loading_label = Label.new()
	loading_label.name = "LoadingLabel"
	loading_label.text = "Loading gods..."
	loading_label.add_theme_font_size_override("font_size", 14)
	loading_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_god_grid.add_child(loading_label)

func _show_empty_state() -> void:
	"""Show empty state when no gods match filter"""
	# Clear existing cards
	for child in _god_grid.get_children():
		child.queue_free()

	# Add empty state message
	var empty_label = Label.new()
	empty_label.name = "EmptyStateLabel"
	empty_label.text = "No gods available"
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_god_grid.add_child(empty_label)

func _show_error_state(error_message: String) -> void:
	"""Show error state when gods cannot be loaded"""
	# Clear existing cards
	for child in _god_grid.get_children():
		child.queue_free()

	# Add error message
	var error_label = Label.new()
	error_label.name = "ErrorLabel"
	error_label.text = error_message
	error_label.add_theme_font_size_override("font_size", 12)
	error_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_god_grid.add_child(error_label)
