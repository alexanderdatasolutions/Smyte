# scripts/ui/territory/GodSelectionGrid.gd
# Mobile-friendly god selection grid for territory node management
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - displays gods in a tappable grid
# RULE 4: Read-only display - no data modification
# RULE 5: SystemRegistry for all system access
class_name GodSelectionGrid
extends Control

signal god_selected(god: God)
signal selection_cancelled

# Filter modes for showing gods
enum FilterMode {
	ALL,              # Show all gods
	AVAILABLE,        # Show only unassigned gods
	ASSIGNED,         # Show only assigned gods
	GARRISON_READY,   # Show gods suitable for garrison (combat-focused)
	WORKER_READY      # Show gods suitable for work tasks
}

# Affinity/Element color mapping (matches plan: Fire=Red, Water=Blue, etc.)
const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1, 1.0),       # Red
	God.ElementType.WATER: Color(0.2, 0.5, 0.9, 1.0),      # Blue
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2, 1.0),      # Brown
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0, 1.0),  # Light Blue (Air)
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3, 1.0),     # Gold
	God.ElementType.DARK: Color(0.5, 0.2, 0.6, 1.0)        # Purple
}

# Element icons for visual indicator (emoji-based for easy display)
const ELEMENT_ICONS = {
	God.ElementType.FIRE: "🔥",
	God.ElementType.WATER: "💧",
	God.ElementType.EARTH: "🪨",
	God.ElementType.LIGHTNING: "⚡",
	God.ElementType.LIGHT: "☀️",
	God.ElementType.DARK: "🌙"
}

# Card sizing (80x100px as specified)
const CARD_WIDTH = 80
const CARD_HEIGHT = 100
const CARD_SPACING = 8
const GRID_COLUMNS = 5  # 5-6 gods per row (5 default, adjusts to screen)

# Core systems
var collection_manager
var event_bus

# UI elements
var _title_bar: HBoxContainer
var _title_label: Label
var _close_button: Button
var _filter_container: HBoxContainer
var _scroll_container: ScrollContainer
var _god_grid: GridContainer

# State
var _current_filter: FilterMode = FilterMode.ALL
var _excluded_god_ids: Array[String] = []  # Gods to exclude from selection

func _ready() -> void:
	_init_systems()
	_setup_ui()

func _init_systems() -> void:
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GodSelectionGrid: SystemRegistry not available!")
		return

	collection_manager = registry.get_system("CollectionManager")
	event_bus = registry.get_system("EventBus")

	if not collection_manager:
		push_error("GodSelectionGrid: CollectionManager not found!")

func _setup_ui() -> void:
	"""Setup the UI structure"""
	# Main dark background panel
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
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(40, 40)
	_close_button.pressed.connect(_on_close_pressed)
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
	"""Show the god selection grid with specified filter and title"""
	_title_label.text = title
	_current_filter = filter
	_excluded_god_ids = excluded_ids
	_update_filter_buttons()
	refresh_display()
	visible = true

func hide_selection() -> void:
	"""Hide the god selection grid"""
	visible = false

func set_filter(filter: FilterMode) -> void:
	"""Set the current filter mode and refresh"""
	_set_filter(filter)

func set_excluded_gods(god_ids: Array[String]) -> void:
	"""Set gods to exclude from the selection (e.g., already selected)"""
	_excluded_god_ids = god_ids
	refresh_display()

func refresh_display() -> void:
	"""Refresh the god grid with current filter - RULE 4: Read-only"""
	if not collection_manager:
		return

	# Clear existing cards
	for child in _god_grid.get_children():
		child.queue_free()

	# Get all gods
	var all_gods = collection_manager.get_all_gods()

	# Apply filter and exclusions
	var filtered_gods = _apply_filter(all_gods)

	# Sort by element for nice visual grouping
	filtered_gods.sort_custom(_compare_gods_by_element)

	# Create cards for each god
	for god in filtered_gods:
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
