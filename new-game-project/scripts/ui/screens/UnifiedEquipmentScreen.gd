# scripts/ui/screens/UnifiedEquipmentScreen.gd
# Unified Equipment Screen with consistent styling matching battle setup
extends Control
class_name UnifiedEquipmentScreen

signal back_pressed

const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# Color palette (matching UI_DESIGN_PATTERNS.md)
const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.6, 0.4, 0.4)
const COLOR_EQUIPPED = Color(0.2, 0.4, 0.25)

const RARITY_COLORS = {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.4, 0.8, 0.4),
	"rare": Color(0.4, 0.6, 1.0),
	"epic": Color(0.7, 0.4, 0.9),
	"legendary": Color(1.0, 0.8, 0.2)
}

# Systems
var equipment_manager: EquipmentManager
var collection_manager: CollectionManager

# State
var selected_god: God = null
var selected_slot: int = -1
var all_gods: Array = []
var _cached_equipment_config: Dictionary = {}  # Cache for equipment config loading

# Sorting
enum GodSortType { POWER, LEVEL, TIER, ELEMENT, NAME }
enum EquipSortType { RARITY, TYPE, LEVEL, NAME }
var god_sort_type: GodSortType = GodSortType.POWER
var god_sort_ascending: bool = false
var equip_sort_type: EquipSortType = EquipSortType.RARITY
var equip_sort_ascending: bool = false

# UI References
var left_panel: PanelContainer
var right_panel: PanelContainer
var god_portrait: TextureRect
var god_name_label: Label
var god_info_label: Label
var stats_grid: GridContainer
var equipment_slots_grid: GridContainer
var set_bonus_container: VBoxContainer
var god_selector_grid: HBoxContainer  # HBox of VBox columns for 2-row layout
var god_selector_scroll: ScrollContainer
var inventory_grid: GridContainer
var inventory_scroll: ScrollContainer
var god_sort_btn: OptionButton
var equip_sort_btn: OptionButton
var filter_hint_label: Label

func _ready():
	_setup_fullscreen()
	_initialize_systems()
	_build_ui()
	_load_gods()
	_setup_unified_header()

func _setup_fullscreen():
	"""Make this control fill the entire viewport (needed when parent is Node2D)"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _initialize_systems():
	var registry = SystemRegistry.get_instance()
	if registry:
		equipment_manager = registry.get_system("EquipmentManager")
		collection_manager = registry.get_system("CollectionManager")

func _setup_unified_header():
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header()

func _on_visibility_changed():
	if visible:
		_update_header()
		_refresh_all()

func _update_header():
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("EQUIPMENT")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func _on_back_pressed():
	back_pressed.emit()

# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui():
	# Background is now in the .tscn file - no need to create programmatically

	# Main horizontal layout - fills screen below header using anchors
	var main_hbox = HBoxContainer.new()
	main_hbox.name = "MainHBox"
	# Use anchors like other working screens
	main_hbox.anchor_left = 0.0
	main_hbox.anchor_top = 0.0
	main_hbox.anchor_right = 1.0
	main_hbox.anchor_bottom = 1.0
	main_hbox.offset_left = 8
	main_hbox.offset_top = 58  # Below unified header
	main_hbox.offset_right = -8
	main_hbox.offset_bottom = -8
	main_hbox.add_theme_constant_override("separation", 8)
	add_child(main_hbox)

	# Left panel (320px fixed) - Selected god info
	left_panel = _create_left_panel()
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_panel)

	# Right panel (fills remaining space)
	right_panel = _create_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

func _create_left_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 0)  # Slightly narrower
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)  # Tighter spacing
	margin.add_child(vbox)

	# God portrait and info row (compact - no header needed)
	var portrait_row = HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 10)
	vbox.add_child(portrait_row)

	# Portrait container - smaller
	var portrait_panel = PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(65, 65)
	var portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.1, 0.08, 0.14)
	portrait_style.border_color = COLOR_PANEL_BORDER
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(6)
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	portrait_row.add_child(portrait_panel)

	god_portrait = TextureRect.new()
	god_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	god_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_panel.add_child(god_portrait)

	# God name/info + stats combined
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(info_vbox)

	god_name_label = Label.new()
	god_name_label.text = "Select a God"
	god_name_label.add_theme_font_size_override("font_size", 14)
	god_name_label.add_theme_color_override("font_color", COLOR_HEADER)
	info_vbox.add_child(god_name_label)

	god_info_label = Label.new()
	god_info_label.text = "from the right panel"
	god_info_label.add_theme_font_size_override("font_size", 10)
	god_info_label.add_theme_color_override("font_color", COLOR_MUTED)
	info_vbox.add_child(god_info_label)

	# Compact stats row next to portrait
	stats_grid = _create_stats_grid()
	info_vbox.add_child(stats_grid)

	# Thin separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	vbox.add_child(sep1)

	# Equipment slots section - compact header
	var equip_header = Label.new()
	equip_header.text = "EQUIPMENT"
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_header.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(equip_header)

	equipment_slots_grid = _create_equipment_slots()
	vbox.add_child(equipment_slots_grid)

	# Thin separator
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	vbox.add_child(sep2)

	# Set bonuses section
	var set_header = Label.new()
	set_header.text = "SET BONUSES"
	set_header.add_theme_font_size_override("font_size", 11)
	set_header.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(set_header)

	# Set bonus in a scroll container to handle overflow
	var set_scroll = ScrollContainer.new()
	set_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(set_scroll)

	set_bonus_container = VBoxContainer.new()
	set_bonus_container.add_theme_constant_override("separation", 4)
	set_bonus_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_scroll.add_child(set_bonus_container)

	return panel

func _create_stats_grid() -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 6  # 3 stat pairs per row (HP ATK DEF / SPD CR CD)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)

	var stats = ["HP", "ATK", "DEF", "SPD", "CR", "CD"]
	for stat in stats:
		var label = Label.new()
		label.text = stat + ":"
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", COLOR_MUTED)
		grid.add_child(label)

		var value = Label.new()
		value.name = stat + "Value"
		value.text = "-"
		value.add_theme_font_size_override("font_size", 10)
		value.add_theme_color_override("font_color", COLOR_TEXT)
		value.custom_minimum_size = Vector2(32, 0)
		grid.add_child(value)

	return grid

func _create_equipment_slots() -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)

	var slot_names = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]

	for i in range(6):
		var slot = _create_equipment_slot(i, slot_names[i])
		grid.add_child(slot)

	return grid

func _create_equipment_slot(slot_index: int, slot_name: String) -> Control:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(85, 80)  # Taller for icon
	container.name = "Slot" + str(slot_index)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "SlotVBox"
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)

	# Slot name at top
	var name_label = Label.new()
	name_label.text = slot_name
	name_label.name = "SlotName"
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Equipment icon in center
	var icon_container = CenterContainer.new()
	icon_container.name = "IconContainer"  # Name it so we can find it later
	icon_container.custom_minimum_size = Vector2(32, 32)
	vbox.add_child(icon_container)

	var icon = TextureRect.new()
	icon.name = "EquipIcon"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(icon)

	# Status/name label at bottom
	var status_label = Label.new()
	status_label.text = "Empty"
	status_label.name = "Status"
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.add_theme_color_override("font_color", COLOR_WARNING)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	# Click button overlay
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(_on_equipment_slot_clicked.bind(slot_index))
	container.add_child(btn)

	return container

func _create_right_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# God selector section
	var god_section = _create_god_selector_section()
	vbox.add_child(god_section)

	# Separator
	vbox.add_child(_create_separator())

	# Inventory section
	var inv_section = _create_inventory_section()
	inv_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(inv_section)

	return panel

func _create_god_selector_section() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)

	# Header with sorting
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	section.add_child(header_row)

	var title = Label.new()
	title.text = "SELECT GOD"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	# Sort dropdown
	god_sort_btn = OptionButton.new()
	god_sort_btn.add_item("Power", GodSortType.POWER)
	god_sort_btn.add_item("Level", GodSortType.LEVEL)
	god_sort_btn.add_item("Tier", GodSortType.TIER)
	god_sort_btn.add_item("Element", GodSortType.ELEMENT)
	god_sort_btn.add_item("Name", GodSortType.NAME)
	god_sort_btn.selected = 0
	god_sort_btn.item_selected.connect(_on_god_sort_changed)
	god_sort_btn.custom_minimum_size = Vector2(100, 0)
	_style_option_button(god_sort_btn)
	header_row.add_child(god_sort_btn)

	# Sort direction
	var sort_dir_btn = Button.new()
	sort_dir_btn.text = "▼"
	sort_dir_btn.name = "GodSortDir"
	sort_dir_btn.custom_minimum_size = Vector2(32, 0)
	sort_dir_btn.pressed.connect(_on_god_sort_direction_toggled.bind(sort_dir_btn))
	_style_small_button(sort_dir_btn)
	header_row.add_child(sort_dir_btn)

	# God cards scroll - 2 rows with horizontal scrolling
	god_selector_scroll = ScrollContainer.new()
	god_selector_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	god_selector_scroll.custom_minimum_size = Vector2(0, 258)  # Two row height (120px per row + spacing)
	god_selector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	god_selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	section.add_child(god_selector_scroll)

	# HBox of VBox columns for exactly 2 rows with horizontal scroll
	god_selector_grid = HBoxContainer.new()
	god_selector_grid.add_theme_constant_override("separation", 8)
	god_selector_scroll.add_child(god_selector_grid)

	return section

func _create_inventory_section() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header with sorting
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	section.add_child(header_row)

	var title = Label.new()
	title.text = "EQUIPMENT INVENTORY"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	filter_hint_label = Label.new()
	filter_hint_label.text = "Click a slot to filter"
	filter_hint_label.add_theme_font_size_override("font_size", 12)
	filter_hint_label.add_theme_color_override("font_color", COLOR_MUTED)
	header_row.add_child(filter_hint_label)

	# Sort dropdown
	equip_sort_btn = OptionButton.new()
	equip_sort_btn.add_item("Rarity", EquipSortType.RARITY)
	equip_sort_btn.add_item("Type", EquipSortType.TYPE)
	equip_sort_btn.add_item("Level", EquipSortType.LEVEL)
	equip_sort_btn.add_item("Name", EquipSortType.NAME)
	equip_sort_btn.selected = 0
	equip_sort_btn.item_selected.connect(_on_equip_sort_changed)
	equip_sort_btn.custom_minimum_size = Vector2(100, 0)
	_style_option_button(equip_sort_btn)
	header_row.add_child(equip_sort_btn)

	# Inventory scroll - fills remaining vertical space
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	section.add_child(inventory_scroll)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 6
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	inventory_scroll.add_child(inventory_grid)

	return section

# ==============================================================================
# STYLING HELPERS
# ==============================================================================

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

func _style_option_button(btn: OptionButton):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 12)

func _style_small_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.2, 0.17, 0.28, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 12)

func _create_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	return sep

# ==============================================================================
# DATA LOADING & DISPLAY
# ==============================================================================

func _load_gods():
	if collection_manager:
		all_gods = collection_manager.get_all_gods()
	_sort_gods()
	_populate_god_selector()

func _sort_gods():
	match god_sort_type:
		GodSortType.POWER:
			all_gods.sort_custom(func(a, b):
				var pa = _calculate_power(a)
				var pb = _calculate_power(b)
				return pa > pb if not god_sort_ascending else pa < pb)
		GodSortType.LEVEL:
			all_gods.sort_custom(func(a, b):
				return a.level > b.level if not god_sort_ascending else a.level < b.level)
		GodSortType.TIER:
			all_gods.sort_custom(func(a, b):
				return a.tier > b.tier if not god_sort_ascending else a.tier < b.tier)
		GodSortType.ELEMENT:
			all_gods.sort_custom(func(a, b):
				return a.element < b.element if not god_sort_ascending else a.element > b.element)
		GodSortType.NAME:
			all_gods.sort_custom(func(a, b):
				return a.name < b.name if not god_sort_ascending else a.name > b.name)

func _calculate_power(god: God) -> int:
	return god.base_hp + god.base_attack * 5 + god.base_defense * 3 + god.base_speed * 2

func _populate_god_selector():
	for child in god_selector_grid.get_children():
		child.queue_free()

	# 2-row layout: Create VBox columns with 2 cards each
	# Pair gods: [0,1], [2,3], [4,5]... for 2 rows per column
	var i = 0
	while i < all_gods.size():
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		god_selector_grid.add_child(column)

		# Top row card
		var card_top = _create_god_card(all_gods[i])
		column.add_child(card_top)

		# Bottom row card (if exists)
		if i + 1 < all_gods.size():
			var card_bottom = _create_god_card(all_gods[i + 1])
			column.add_child(card_bottom)

		i += 2

func _create_god_card(god: God) -> Control:
	# Use GodCard component for proper portraits
	var card = GodCardScript.new()
	card.card_size = GodCardScript.CardSize.SMALL
	card.show_experience_bar = false
	card.show_power_rating = false
	card.show_territory_assignment = false
	card.show_awakening_status = false
	card.clickable = false  # We'll handle clicks ourselves

	var is_selected = selected_god and selected_god.id == god.id
	var style_type = GodCardScript.CardStyle.SELECTED if is_selected else GodCardScript.CardStyle.NORMAL
	card.setup_god_card(god, style_type)

	# Override size for our layout
	card.custom_minimum_size = Vector2(100, 120)

	# Add selection styling
	if is_selected:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.35, 0.25, 0.95)
		style.border_color = COLOR_SUCCESS
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", style)

	# Click handler
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(_on_god_selected.bind(god))
	card.add_child(btn)

	return card

func _get_element_color(element: God.ElementType) -> Color:
	match element:
		God.ElementType.FIRE: return Color(1, 0.4, 0.2)
		God.ElementType.WATER: return Color(0.3, 0.6, 1)
		God.ElementType.EARTH: return Color(0.6, 0.5, 0.3)
		God.ElementType.LIGHTNING: return Color(1, 0.9, 0.3)
		God.ElementType.LIGHT: return Color(1, 1, 0.8)
		God.ElementType.DARK: return Color(0.5, 0.3, 0.6)
		_: return COLOR_PANEL_BORDER

func _refresh_inventory():
	if not inventory_grid or not equipment_manager:
		return

	for child in inventory_grid.get_children():
		child.queue_free()

	var equipment_list = equipment_manager.get_unequipped_equipment()

	# Filter by slot if selected
	if selected_slot >= 0:
		equipment_list = equipment_list.filter(func(e): return _get_slot_for_type(e.type) == selected_slot)

	# Sort
	_sort_equipment(equipment_list)

	for equipment in equipment_list:
		var card = _create_equipment_card(equipment)
		inventory_grid.add_child(card)

	# Update filter hint
	if filter_hint_label:
		if selected_slot >= 0:
			var slot_names = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]
			filter_hint_label.text = "Showing: " + slot_names[selected_slot]
			filter_hint_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			filter_hint_label.text = "Click a slot to filter"
			filter_hint_label.add_theme_color_override("font_color", COLOR_MUTED)

func _sort_equipment(list: Array):
	match equip_sort_type:
		EquipSortType.RARITY:
			list.sort_custom(func(a, b):
				return a.rarity > b.rarity if not equip_sort_ascending else a.rarity < b.rarity)
		EquipSortType.TYPE:
			list.sort_custom(func(a, b):
				return a.type < b.type if not equip_sort_ascending else a.type > b.type)
		EquipSortType.LEVEL:
			list.sort_custom(func(a, b):
				return a.level > b.level if not equip_sort_ascending else a.level < b.level)
		EquipSortType.NAME:
			list.sort_custom(func(a, b):
				return a.name < b.name if not equip_sort_ascending else a.name > b.name)

func _get_slot_for_type(type) -> int:
	match type:
		Equipment.EquipmentType.WEAPON: return 0
		Equipment.EquipmentType.ARMOR: return 1
		Equipment.EquipmentType.HELM: return 2
		Equipment.EquipmentType.BOOTS: return 3
		Equipment.EquipmentType.AMULET: return 4
		Equipment.EquipmentType.RING: return 5
		_: return -1

func _create_equipment_card(equipment: Equipment) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 140)  # Taller for icon

	var rarity_color = _get_rarity_color(equipment.rarity)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(rarity_color.r * 0.2, rarity_color.g * 0.2, rarity_color.b * 0.2, 0.9)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Equipment icon
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(50, 50)
	vbox.add_child(icon_container)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_equipment_texture(equipment)
	icon_container.add_child(icon)

	# Equipment name
	var name_label = Label.new()
	var display_name = equipment.name if equipment.name.length() <= 14 else equipment.name.substr(0, 12) + ".."
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Main stat
	if equipment.main_stat_type != "":
		var stat_label = Label.new()
		stat_label.text = "%s +%d" % [_get_stat_abbrev(equipment.main_stat_type), equipment.main_stat_value]
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_label.add_theme_color_override("font_color", Color.GOLD)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stat_label)

	# Level if enhanced
	if equipment.enhancement_level > 0:
		var lvl_label = Label.new()
		lvl_label.text = "+%d" % equipment.enhancement_level
		lvl_label.add_theme_font_size_override("font_size", 10)
		lvl_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lvl_label)

	# Click to equip
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(_on_equipment_clicked.bind(equipment))
	card.add_child(btn)

	return card

func _get_type_name(type) -> String:
	match type:
		Equipment.EquipmentType.WEAPON: return "Weapon"
		Equipment.EquipmentType.ARMOR: return "Armor"
		Equipment.EquipmentType.HELM: return "Helm"
		Equipment.EquipmentType.BOOTS: return "Boots"
		Equipment.EquipmentType.AMULET: return "Amulet"
		Equipment.EquipmentType.RING: return "Ring"
		_: return "Unknown"

func _get_rarity_color(rarity) -> Color:
	match rarity:
		Equipment.Rarity.COMMON: return RARITY_COLORS["common"]
		Equipment.Rarity.RARE: return RARITY_COLORS["rare"]
		Equipment.Rarity.EPIC: return RARITY_COLORS["epic"]
		Equipment.Rarity.LEGENDARY: return RARITY_COLORS["legendary"]
		_: return RARITY_COLORS["common"]

func _get_stat_abbrev(stat: String) -> String:
	match stat.to_lower():
		"hp": return "HP"
		"attack": return "ATK"
		"defense": return "DEF"
		"speed": return "SPD"
		"crit_rate": return "CR"
		"crit_damage": return "CD"
		_: return stat.substr(0, 3).to_upper()

func _load_equipment_texture(equipment: Equipment) -> Texture2D:
	"""Load equipment icon texture - tries multiple path patterns"""
	var base_path = "res://assets/equipment/"
	var type_str = Equipment.type_to_string(equipment.type)

	# Try patterns in order of specificity:
	# 1. Set + type: weapon_divine_weapon.png
	# 2. Generic type-based: iron_sword.png, swift_boots.png
	# 3. Type only: weapon.png

	var paths_to_try = []

	# Pattern 1: set_type + type (e.g., weapon_guardian_weapon.png)
	if equipment.equipment_set_type != "":
		paths_to_try.append(base_path + type_str + "_" + equipment.equipment_set_type + "_" + type_str + ".png")

	# Pattern 2: try name-based (convert name to snake_case)
	var name_snake = equipment.name.to_lower().replace(" ", "_")
	paths_to_try.append(base_path + name_snake + ".png")

	# Pattern 3: type-based generic (e.g., iron_sword.png, steel_armor.png)
	match equipment.type:
		Equipment.EquipmentType.WEAPON:
			paths_to_try.append(base_path + "iron_sword.png")
		Equipment.EquipmentType.ARMOR:
			paths_to_try.append(base_path + "steel_armor.png")
		Equipment.EquipmentType.HELM:
			paths_to_try.append(base_path + "mystic_helm.png")
		Equipment.EquipmentType.BOOTS:
			paths_to_try.append(base_path + "swift_boots.png")
		Equipment.EquipmentType.AMULET:
			paths_to_try.append(base_path + "power_amulet.png")
		Equipment.EquipmentType.RING:
			paths_to_try.append(base_path + "focus_ring.png")

	# Try each path
	for path in paths_to_try:
		if ResourceLoader.exists(path):
			return load(path)

	return null

func _refresh_god_display():
	if not selected_god:
		god_name_label.text = "Select a God"
		god_info_label.text = "from the right panel"
		god_portrait.texture = null
		_clear_stats()
		return

	god_name_label.text = selected_god.name
	god_info_label.text = "Lv.%d | %s | %s" % [selected_god.level, God.element_to_string(selected_god.element).capitalize(), "★".repeat(selected_god.tier + 1)]

	# Load portrait - use template_id like GodCard does
	var god_template = selected_god.template_id if selected_god.template_id else selected_god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		god_portrait.texture = load(sprite_path)
	else:
		# Try lowercase
		sprite_path = "res://assets/gods/" + god_template.to_lower() + ".png"
		if ResourceLoader.exists(sprite_path):
			god_portrait.texture = load(sprite_path)
		else:
			god_portrait.texture = null

	# Update stats
	_update_stats_display()
	_refresh_equipment_slots()
	_refresh_set_bonuses()

func _clear_stats():
	var stat_names = ["HP", "ATK", "DEF", "SPD", "CR", "CD"]
	for stat in stat_names:
		var val = stats_grid.get_node_or_null(stat + "Value")
		if val:
			val.text = "-"

func _update_stats_display():
	if not selected_god or not stats_grid:
		return

	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator")
	var stats = {}

	if stat_calc:
		stats = stat_calc.calculate_god_total_stats(selected_god)
	else:
		stats = {
			"hp": selected_god.base_hp,
			"attack": selected_god.base_attack,
			"defense": selected_god.base_defense,
			"speed": selected_god.base_speed,
			"crit_rate": selected_god.base_crit_rate,
			"crit_damage": selected_god.base_crit_damage
		}

	var hp_val = stats_grid.get_node_or_null("HPValue")
	var atk_val = stats_grid.get_node_or_null("ATKValue")
	var def_val = stats_grid.get_node_or_null("DEFValue")
	var spd_val = stats_grid.get_node_or_null("SPDValue")
	var cr_val = stats_grid.get_node_or_null("CRValue")
	var cd_val = stats_grid.get_node_or_null("CDValue")

	if hp_val: hp_val.text = _format_number(stats.get("hp", 0))
	if atk_val: atk_val.text = str(stats.get("attack", 0))
	if def_val: def_val.text = str(stats.get("defense", 0))
	if spd_val: spd_val.text = str(stats.get("speed", 0))
	if cr_val: cr_val.text = str(stats.get("crit_rate", 0)) + "%"
	if cd_val: cd_val.text = str(stats.get("crit_damage", 0)) + "%"

func _format_number(num: int) -> String:
	if num >= 10000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _refresh_equipment_slots():
	if not selected_god or not equipment_slots_grid:
		return

	for i in range(6):
		var slot_panel = equipment_slots_grid.get_node_or_null("Slot" + str(i))
		if not slot_panel:
			continue

		var equipped = _get_equipped_in_slot(i)
		var status = slot_panel.get_node_or_null("SlotVBox/Status")
		var icon = slot_panel.get_node_or_null("SlotVBox/IconContainer/EquipIcon")

		# Update slot styling based on equipped state
		var style = StyleBoxFlat.new()

		if equipped:
			style.bg_color = COLOR_EQUIPPED
			style.border_color = _get_rarity_color(equipped.rarity)
			if status:
				var name_short = equipped.name if equipped.name.length() <= 8 else equipped.name.substr(0, 6) + ".."
				status.text = name_short
				status.add_theme_color_override("font_color", _get_rarity_color(equipped.rarity))
			if icon:
				icon.texture = _load_equipment_texture(equipped)
		else:
			style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
			style.border_color = COLOR_PANEL_BORDER
			if status:
				status.text = "Empty"
				status.add_theme_color_override("font_color", COLOR_WARNING)
			if icon:
				icon.texture = null

		# Highlight selected slot
		if selected_slot == i:
			style.border_color = Color(0.4, 0.8, 0.9)
			style.set_border_width_all(3)
		else:
			style.set_border_width_all(2)

		style.set_corner_radius_all(6)
		slot_panel.add_theme_stylebox_override("panel", style)

func _get_equipped_in_slot(slot_index: int) -> Equipment:
	if not selected_god or slot_index < 0 or slot_index >= selected_god.equipment.size():
		return null

	var equip_ref = selected_god.equipment[slot_index]
	if equip_ref == null:
		return null

	if equip_ref is Equipment:
		return equip_ref

	if equip_ref is String and equip_ref != "" and equipment_manager:
		return equipment_manager.get_equipment_by_id(equip_ref)

	return null

func _refresh_set_bonuses():
	if not set_bonus_container:
		return

	for child in set_bonus_container.get_children():
		child.queue_free()

	if not selected_god:
		var no_bonus = Label.new()
		no_bonus.text = "No god selected"
		no_bonus.add_theme_font_size_override("font_size", 12)
		no_bonus.add_theme_color_override("font_color", COLOR_MUTED)
		set_bonus_container.add_child(no_bonus)
		return

	# Load config for set names
	var config = _get_equipment_config()
	var config_sets = config.get("equipment_sets", {})

	# Count set pieces and track set types
	var set_counts = {}
	var set_types = {}
	for i in range(6):
		var equipped = _get_equipped_in_slot(i)
		if equipped and equipped.equipment_set_type != "":
			var set_type = equipped.equipment_set_type
			# Get display name from equipment_config if not on item
			var set_name = equipped.equipment_set_name
			if set_name == "":
				set_name = config_sets.get(set_type, {}).get("name", set_type.capitalize())
			set_counts[set_type] = set_counts.get(set_type, 0) + 1
			set_types[set_type] = set_name

	if set_counts.is_empty():
		var no_bonus = Label.new()
		no_bonus.text = "No set bonuses active"
		no_bonus.add_theme_font_size_override("font_size", 12)
		no_bonus.add_theme_color_override("font_color", COLOR_MUTED)
		set_bonus_container.add_child(no_bonus)
		return

	# Load set bonus data
	var set_bonus_data = _load_set_bonus_data()

	for set_type in set_counts:
		var count = set_counts[set_type]
		var set_name = set_types.get(set_type, set_type.capitalize())

		# Set header with count
		var set_panel = PanelContainer.new()
		var set_style = StyleBoxFlat.new()
		set_style.bg_color = Color(0.1, 0.08, 0.14, 0.8)
		set_style.border_color = Color.GOLD if count >= 2 else COLOR_PANEL_BORDER
		set_style.set_border_width_all(1)
		set_style.set_corner_radius_all(4)
		set_panel.add_theme_stylebox_override("panel", set_style)
		set_bonus_container.add_child(set_panel)

		var set_vbox = VBoxContainer.new()
		set_vbox.add_theme_constant_override("separation", 4)
		set_panel.add_child(set_vbox)

		var header = Label.new()
		header.text = "%s (%d/6)" % [set_name, count]
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color.GOLD if count >= 2 else COLOR_HEADER)
		set_vbox.add_child(header)

		# Show tier bonuses
		var tiers = [2, 4, 6]
		# Use lowercase for lookup (JSON keys are lowercase)
		var set_type_lower = set_type.to_lower()
		var set_info = set_bonus_data.get(set_type_lower, {})

		for tier in tiers:
			var tier_active = count >= tier
			var tier_str = str(tier)
			var bonus_info = set_info.get(tier_str, {})
			var description = bonus_info.get("description", _get_default_bonus_description(set_type_lower, tier))

			var tier_row = HBoxContainer.new()
			tier_row.add_theme_constant_override("separation", 6)
			set_vbox.add_child(tier_row)

			# Tier indicator
			var tier_label = Label.new()
			tier_label.text = "(%d)" % tier
			tier_label.add_theme_font_size_override("font_size", 10)
			tier_label.add_theme_color_override("font_color", COLOR_SUCCESS if tier_active else COLOR_MUTED)
			tier_label.custom_minimum_size = Vector2(25, 0)
			tier_row.add_child(tier_label)

			# Bonus description
			var desc_label = Label.new()
			desc_label.text = description
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.add_theme_color_override("font_color", COLOR_TEXT if tier_active else Color(0.4, 0.4, 0.45))
			desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tier_row.add_child(desc_label)

			# Show special effect for 6-piece if active
			if tier == 6 and tier_active and bonus_info.has("special_effect"):
				var effect_label = Label.new()
				effect_label.text = "★ " + bonus_info.get("special_effect", "")
				effect_label.add_theme_font_size_override("font_size", 10)
				effect_label.add_theme_color_override("font_color", Color.GOLD)
				effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				set_vbox.add_child(effect_label)

func _load_set_bonus_data() -> Dictionary:
	"""Load set bonus descriptions from JSON"""
	var bonus_data = {}
	var file = FileAccess.open("res://data/equipment_set_bonuses.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		file.close()
		if result == OK:
			var data = json.get_data()
			if data.has("sets"):
				for set_id in data.sets:
					bonus_data[set_id] = data.sets[set_id].get("bonuses", {})
	return bonus_data

func _get_default_bonus_description(set_type: String, tier: int) -> String:
	"""Get default bonus description from equipment_config"""
	# Load config directly to ensure we have it
	var config = _get_equipment_config()

	var sets = config.get("equipment_sets", {})
	var set_info = sets.get(set_type, {})
	var tier_bonuses = set_info.get("bonuses", {}).get(str(tier), {})

	if tier_bonuses.is_empty():
		# Fallback: show generic based on tier
		match tier:
			2: return "+Minor stat bonus"
			4: return "+Medium stat bonus"
			6: return "+Major stat bonus"
		return "Bonus"

	var parts = []
	for stat in tier_bonuses:
		var value = tier_bonuses[stat]
		var stat_name = stat.replace("_", " ").capitalize()
		if stat in ["crit_rate", "crit_damage", "accuracy", "resistance"]:
			parts.append("+%d%% %s" % [value, stat_name])
		else:
			parts.append("+%d %s" % [value, stat_name])
	return ", ".join(parts)

func _get_equipment_config() -> Dictionary:
	"""Load equipment config directly - more reliable than depending on Equipment class"""
	if not _cached_equipment_config.is_empty():
		return _cached_equipment_config

	var file = FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		file.close()
		if result == OK:
			_cached_equipment_config = json.get_data()

	return _cached_equipment_config

func _refresh_all():
	_populate_god_selector()
	_refresh_god_display()
	_refresh_inventory()

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_god_selected(god: God):
	selected_god = god
	selected_slot = -1
	_populate_god_selector()  # Refresh to show selection
	_refresh_god_display()
	_refresh_inventory()

func _on_equipment_slot_clicked(slot_index: int):
	if selected_slot == slot_index:
		selected_slot = -1  # Toggle off
	else:
		selected_slot = slot_index
	_refresh_equipment_slots()
	_refresh_inventory()

func _on_equipment_clicked(equipment: Equipment):
	if not selected_god or not equipment_manager:
		return

	var slot = _get_slot_for_type(equipment.type)
	var success = equipment_manager.equip_equipment_to_god(selected_god, equipment, slot)

	if success:
		selected_slot = -1
		_refresh_all()

func _on_god_sort_changed(index: int):
	god_sort_type = index as GodSortType
	_sort_gods()
	_populate_god_selector()

func _on_god_sort_direction_toggled(btn: Button):
	god_sort_ascending = not god_sort_ascending
	btn.text = "▲" if god_sort_ascending else "▼"
	_sort_gods()
	_populate_god_selector()

func _on_equip_sort_changed(index: int):
	equip_sort_type = index as EquipSortType
	_refresh_inventory()
