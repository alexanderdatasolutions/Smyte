class_name CollectionScreen
extends Control

"""
CollectionScreen.gd - God collection screen following TeamSelectionManager pattern
Two-panel layout: Left = God details, Right = God grid with sorting
"""

signal back_pressed

# UI References
var left_panel: PanelContainer = null
var right_panel: PanelContainer = null
var gods_grid: GridContainer = null
var details_container: VBoxContainer = null
var no_selection_label: Label = null
var count_label: Label = null

# Sorting UI
var sort_dropdown: OptionButton = null
var sort_direction_btn: Button = null

# Data
var all_gods: Array = []
var selected_god: God = null
var collection_manager = null

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false

func _ready():
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	_setup_unified_header()
	_load_gods()

func _setup_fullscreen():
	"""Ensure this control fills the entire viewport"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport_size = get_viewport().get_visible_rect().size
	set_size(viewport_size)
	position = Vector2.ZERO

func _init_systems():
	var registry = SystemRegistry.get_instance()
	if registry:
		collection_manager = registry.get_system("CollectionManager")

func _setup_unified_header():
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed():
	if visible:
		_update_header_for_screen()
		_load_gods()

func _update_header_for_screen():
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("GOD COLLECTION")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

# ============================================================================
# UI BUILDING
# ============================================================================

func _build_ui():
	# Background - fills entire screen
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.06, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main VBox that fills the screen
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20
	main_vbox.offset_right = -20
	main_vbox.offset_top = 60  # Space for header
	main_vbox.offset_bottom = -20
	add_child(main_vbox)

	# Content HBox for two panels
	var content_hbox = HBoxContainer.new()
	content_hbox.name = "ContentHBox"
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	# Left Panel - God Details (320px fixed width)
	left_panel = _create_left_panel()
	content_hbox.add_child(left_panel)

	# Right Panel - Gods Grid (flexible)
	right_panel = _create_right_panel()
	content_hbox.add_child(right_panel)

func _create_left_panel() -> PanelContainer:
	"""Create left panel for god details"""
	var panel = PanelContainer.new()
	panel.name = "LeftPanel"
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "LeftVBox"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "GOD DETAILS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(header)

	# Scroll container for details
	var scroll = ScrollContainer.new()
	scroll.name = "DetailsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Details content container
	details_container = VBoxContainer.new()
	details_container.name = "DetailsContent"
	details_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details_container)

	# No selection label
	no_selection_label = Label.new()
	no_selection_label.text = "Select a god to view details"
	no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_selection_label.add_theme_font_size_override("font_size", 12)
	no_selection_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	details_container.add_child(no_selection_label)

	return panel

func _create_right_panel() -> PanelContainer:
	"""Create right panel for gods grid with sorting"""
	var panel = PanelContainer.new()
	panel.name = "RightPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "RightVBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header row with sorting controls
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 15)
	vbox.add_child(header_row)

	var header = Label.new()
	header.text = "YOUR GODS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	# Sorting controls
	var sort_controls = _create_sorting_controls()
	header_row.add_child(sort_controls)

	# Gods count label
	count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(count_label)

	# Scrollable gods grid
	var scroll = ScrollContainer.new()
	scroll.name = "GodsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	gods_grid = GridContainer.new()
	gods_grid.name = "GodsGrid"
	gods_grid.columns = 5
	gods_grid.add_theme_constant_override("h_separation", 12)
	gods_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(gods_grid)

	return panel

func _create_sorting_controls() -> HBoxContainer:
	"""Create sorting dropdown and direction button"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Skins button (only if feature unlocked)
	var skins_btn = Button.new()
	skins_btn.name = "SkinsButton"
	skins_btn.text = "🎨 Skins"
	skins_btn.custom_minimum_size = Vector2(80, 28)
	skins_btn.pressed.connect(_on_skins_button_pressed)
	_style_button(skins_btn)
	container.add_child(skins_btn)
	_update_skins_button_visibility(skins_btn)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	container.add_child(spacer)

	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	container.add_child(sort_label)

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

	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▼"
	sort_direction_btn.custom_minimum_size = Vector2(30, 28)
	sort_direction_btn.tooltip_text = "Toggle sort direction"
	sort_direction_btn.pressed.connect(_toggle_sort_direction)
	_style_button(sort_direction_btn)
	container.add_child(sort_direction_btn)

	return container

# ============================================================================
# DATA & DISPLAY
# ============================================================================

func _load_gods():
	"""Load all gods from collection"""
	if not collection_manager:
		return

	all_gods = collection_manager.get_all_gods()
	_refresh_gods_grid()

func _refresh_gods_grid():
	"""Refresh the gods grid with current sorting"""
	if not gods_grid:
		return

	# Clear existing
	for child in gods_grid.get_children():
		child.queue_free()

	# Update count
	if count_label:
		count_label.text = "%d gods in collection" % all_gods.size()

	if all_gods.is_empty():
		var no_gods = Label.new()
		no_gods.text = "No gods in your collection yet!\nSummon some gods to get started."
		no_gods.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_gods.add_theme_font_size_override("font_size", 14)
		no_gods.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		gods_grid.add_child(no_gods)
		return

	# Sort gods
	var sorted_gods = _sort_gods(all_gods)

	# Create god cards
	for god in sorted_gods:
		var card_container = _create_god_card(god)
		gods_grid.add_child(card_container)

func _create_god_card(god: God) -> Control:
	"""Create a selectable god card for the grid"""
	var container = Panel.new()
	container.custom_minimum_size = Vector2(160, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", style)

	# God card using global class
	var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.LARGE)

	# Apply selected style if this is the selected god
	var card_style = GodCard.CardStyle.SELECTED if (selected_god and selected_god.id == god.id) else GodCard.CardStyle.NORMAL
	god_card.setup_god_card(god, card_style)
	god_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_mouse_on_children(god_card)
	container.add_child(god_card)

	# Selection overlay
	var selection_overlay = ColorRect.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_overlay.color = Color(0.3, 0.6, 0.9, 0.25)
	selection_overlay.visible = (selected_god != null and selected_god.id == god.id)
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(selection_overlay)

	# Make clickable
	container.gui_input.connect(_on_god_card_clicked.bind(god))

	return container

func _on_god_card_clicked(event: InputEvent, god: God):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_god(god)

func _select_god(god: God):
	"""Select a god and show their details"""
	selected_god = god
	_refresh_gods_grid()
	_show_god_details(god)

func _show_god_details(god: God):
	"""Show detailed god info in left panel"""
	CollectionDetailsPanel.show_god_details(god, details_container, no_selection_label)

# ============================================================================
# SORTING
# ============================================================================

func _on_sort_changed(index: int):
	current_sort = index as SortType
	_refresh_gods_grid()

func _toggle_sort_direction():
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	_refresh_gods_grid()

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

# ============================================================================
# HELPERS
# ============================================================================

func _disable_mouse_on_children(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

func _on_back_pressed():
	back_pressed.emit()

# ============================================================================
# SKINS
# ============================================================================

func _update_skins_button_visibility(skins_btn: Button) -> void:
	var registry = SystemRegistry.get_instance()
	var feature_manager = registry.get_system("FeatureUnlockManager") if registry else null
	if feature_manager and feature_manager.is_feature_unlocked("skin_selection"):
		skins_btn.visible = true
	else:
		skins_btn.visible = false

func _on_skins_button_pressed() -> void:
	var popup: SkinManagementPopup = SkinManagementPopup.new()
	add_child(popup)
	popup.show_popup()
