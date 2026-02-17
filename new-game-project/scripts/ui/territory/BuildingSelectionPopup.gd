# scripts/ui/territory/BuildingSelectionPopup.gd
# Building selection popup shown after capturing a blank tile
extends Control
class_name BuildingSelectionPopup

"""
BuildingSelectionPopup.gd - Choose which building to place on a captured blank tile
RULE 2: Single responsibility - ONLY handles building selection UI
RULE 1: Under 500 lines
RULE 5: Uses SystemRegistry for all system access

Follows popup pattern from UI_DESIGN_PATTERNS.md:
	pass
- z_index = 100 overlay
- Click overlay to close
- Dark purple color palette
- Grid of building cards
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal building_selected(hex_node: HexNode, building_id: String)
signal selection_cancelled(hex_node: HexNode)
signal popup_closed()

# ==============================================================================
# CONSTANTS - Color palette from UI_DESIGN_PATTERNS.md
# ==============================================================================
const COLOR_BG = Color(0.08, 0.06, 0.12)           # Dark purple base
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.98)  # Panel background
const COLOR_BORDER = Color(0.3, 0.25, 0.4, 0.8)    # Panel borders
const COLOR_HEADER = Color(0.8, 0.8, 0.9)          # Header text
const COLOR_MUTED = Color(0.5, 0.5, 0.55)          # Muted text
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)         # Success/equipped
const COLOR_GOLD = Color(1.0, 0.84, 0.0)           # Values/amounts

# Category colors
const CATEGORY_COLORS = {
	"extraction": Color(0.6, 0.5, 0.3),    # Brown/orange
	"processing": Color(0.5, 0.6, 0.3),    # Green/olive
	"crafting": Color(0.6, 0.4, 0.2),      # Forge orange
	"divine": Color(0.5, 0.3, 0.7),        # Purple
	"infrastructure": Color(0.3, 0.5, 0.7) # Blue
}

const CATEGORY_ICONS = {
	"extraction": "⛏️",
	"processing": "🔄",
	"crafting": "⚒️",
	"divine": "✨",
	"infrastructure": "🏗️"
}

# Per-building icons (matches HexTile.gd BUILDING_ICONS)
const BUILDING_ICONS = {
	# Extraction
	"mine": "⛏️",
	"lumber_camp": "🪓",
	"herbalist_hut": "🌿",
	"hunting_lodge": "🏹",
	"deep_mine": "💎",
	"hardwood_mill": "🪵",
	"exotic_garden": "🌺",
	"beast_grounds": "🐉",
	"arcane_excavation": "🔮",
	"ancient_grove": "🌳",
	"mystic_conservatory": "🌸",
	"crystal_cavern": "💠",
	# Processing
	"smelter": "🔥",
	"sawmill": "🪚",
	"apothecary": "⚗️",
	"steel_foundry": "⚒️",
	"treatment_works": "🧪",
	"alchemy_lab": "🧫",
	"prometheum_forge": "🌋",
	"enchanting_mill": "✨",
	"bloom_distillery": "🌼",
	"astral_refinery": "🌟",
	# Crafting
	"blacksmith": "🔨",
	"weapon_forge": "⚔️",
	"armor_forge": "🛡️",
	"divine_forge": "⚡",
	"jeweler": "💍",
	# Divine
	"shrine": "🕯️",
	"mana_well": "💧",
	"temple": "⛪",
	"sanctum": "🏛️",
	"soul_nexus": "👻",
	"day_care": "🌱",
	# Infrastructure
	"watchtower": "🗼",
	"barracks": "🏰",
	"warehouse": "📦",
	"trade_post": "🏪",
	"oracle_tower": "🔭",
	"fortress": "🏯"
}

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: HexNode = null
var building_manager = null
var selected_category: String = "extraction"  # Default category
var all_buildings: Array = []

# Sorting/filtering state
var current_sort: String = "tier"  # "tier", "name", "production"
var sort_ascending: bool = true

# UI references
var overlay: ColorRect = null
var main_panel: PanelContainer = null
var content_container: HBoxContainer = null  # Horizontal layout: left + right
var left_panel: VBoxContainer = null
var right_panel: VBoxContainer = null
var category_buttons: Dictionary = {}  # category -> Button
var buildings_scroll: ScrollContainer = null
var buildings_list: VBoxContainer = null  # Changed from GridContainer to VBoxContainer for single-column list
var sort_button: Button = null
var sort_direction_btn: Button = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	visible = false

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if registry:
		building_manager = registry.get_system("BuildingManager")

# ==============================================================================
# PUBLIC API
# ==============================================================================
func show_for_node(hex_node: HexNode) -> void:
	"""Show building selection popup for a captured blank tile"""
	if not hex_node:
		push_error("BuildingSelectionPopup: No node provided")
		return

	# Only show for blank buildable tiles
	if not hex_node.can_place_building():
		push_warning("BuildingSelectionPopup: Node %s cannot have buildings placed" % hex_node.id)
		return

	current_node = hex_node
	_build_popup_ui()
	visible = true

func hide_popup() -> void:
	"""Hide the popup"""
	visible = false
	popup_closed.emit()

	# Clean up UI
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null

	current_node = null

# ==============================================================================
# UI BUILDING
# ==============================================================================
func _build_popup_ui() -> void:
	"""Build the popup UI with left categories, right building list"""
	# Clean up existing UI
	for child in get_children():
		child.queue_free()
	category_buttons.clear()

	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100

	# === Overlay (click to close) ===
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	# === Main Panel (centered, mouse_filter=STOP) ===
	main_panel = PanelContainer.new()
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_width = mini(viewport_size.x * 0.9, 800)
	var panel_height = mini(viewport_size.y * 0.85, 600)
	main_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	main_panel.size = Vector2(panel_width, panel_height)
	main_panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)

	_style_panel(main_panel)
	add_child(main_panel)

	# === Outer VBox for header + content ===
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(outer_vbox)

	# === Header with title and close button ===
	_build_header(outer_vbox)

	# === Tile info ===
	_build_tile_info(outer_vbox)

	# === Separator ===
	var sep = HSeparator.new()
	outer_vbox.add_child(sep)

	# === Two-column layout: Left categories, Right buildings ===
	content_container = HBoxContainer.new()
	content_container.add_theme_constant_override("separation", 16)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_container)

	# Load all available buildings
	all_buildings = _get_available_buildings()

	# === Left Panel: Categories ===
	_build_left_panel()

	# === Right Panel: Building list ===
	_build_right_panel()

	# Select default category
	_select_category(selected_category)

func _build_header(parent: Control) -> void:
	"""Build header with title and close button"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	parent.add_child(header)

	var title = Label.new()
	title.text = "🏗️ SELECT BUILDING"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_on_close_pressed)
	_style_close_button(close_btn)
	header.add_child(close_btn)

func _build_tile_info(parent: Control) -> void:
	"""Show info about the captured tile"""
	if not current_node:
		return

	var info_box = HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 20)
	parent.add_child(info_box)

	# Tile name and tier
	var tier_stars = ""
	for i in range(current_node.tier):
		tier_stars += "★"

	var tile_label = Label.new()
	tile_label.text = "Captured: %s  |  Tier %d %s" % [current_node.name, current_node.tier, tier_stars]
	tile_label.add_theme_font_size_override("font_size", 14)
	tile_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	info_box.add_child(tile_label)

	# Building tier limit
	var limit_label = Label.new()
	limit_label.text = "Max building tier: %d" % current_node.tier
	limit_label.add_theme_font_size_override("font_size", 12)
	limit_label.add_theme_color_override("font_color", COLOR_MUTED)
	info_box.add_child(limit_label)

func _build_left_panel() -> void:
	"""Build the left panel with category buttons"""
	left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(160, 0)
	left_panel.add_theme_constant_override("separation", 8)
	content_container.add_child(left_panel)

	# Categories header
	var cat_header = Label.new()
	cat_header.text = "CATEGORIES"
	cat_header.add_theme_font_size_override("font_size", 12)
	cat_header.add_theme_color_override("font_color", COLOR_MUTED)
	left_panel.add_child(cat_header)

	# Get unique categories from available buildings
	var categories: Array[String] = []
	for building in all_buildings:
		var cat: String = building.get("category", "")
		if not cat.is_empty() and not categories.has(cat):
			categories.append(cat)

	# Sort categories in a logical order
	var category_order = ["extraction", "processing", "crafting", "divine", "infrastructure"]
	categories.sort_custom(func(a, b):
		var idx_a = category_order.find(a) if category_order.has(a) else 999
		var idx_b = category_order.find(b) if category_order.has(b) else 999
		return idx_a < idx_b
	)

	# Create category buttons
	for category in categories:
		var btn = Button.new()
		btn.text = "%s %s" % [CATEGORY_ICONS.get(category, "📦"), category.capitalize()]
		btn.custom_minimum_size = Vector2(150, 40)
		btn.pressed.connect(_on_category_pressed.bind(category))
		_style_category_button(btn, category, false)
		left_panel.add_child(btn)
		category_buttons[category] = btn

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(spacer)

	# Building count
	var count_label = Label.new()
	count_label.text = "%d buildings available" % all_buildings.size()
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", COLOR_MUTED)
	left_panel.add_child(count_label)

func _build_right_panel() -> void:
	"""Build the right panel with single-column building list and sorting"""
	right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 8)
	content_container.add_child(right_panel)

	# Header row with title and sorting controls
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	right_panel.add_child(header_row)

	# Category title (will be updated when category changes)
	var title = Label.new()
	title.name = "CategoryTitle"
	title.text = "SELECT A CATEGORY"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	# Sort controls
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", COLOR_MUTED)
	header_row.add_child(sort_label)

	# Sort dropdown button
	sort_button = Button.new()
	sort_button.text = "Tier"
	sort_button.custom_minimum_size = Vector2(90, 28)
	sort_button.pressed.connect(_on_sort_button_pressed)
	_style_sort_button(sort_button)
	header_row.add_child(sort_button)

	# Sort direction button
	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	sort_direction_btn.custom_minimum_size = Vector2(28, 28)
	sort_direction_btn.pressed.connect(_on_sort_direction_pressed)
	_style_sort_button(sort_direction_btn)
	header_row.add_child(sort_direction_btn)

	# Column headers for the list
	var column_headers = HBoxContainer.new()
	column_headers.add_theme_constant_override("separation", 8)
	right_panel.add_child(column_headers)
	_build_column_headers(column_headers)

	# Scroll container for building list
	buildings_scroll = ScrollContainer.new()
	buildings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buildings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(buildings_scroll)

	# Single-column list for building rows
	buildings_list = VBoxContainer.new()
	buildings_list.add_theme_constant_override("separation", 4)
	buildings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildings_scroll.add_child(buildings_list)

func _build_column_headers(parent: Control) -> void:
	"""Build column header labels for the list"""
	# Icon column (fixed width)
	var icon_header = Label.new()
	icon_header.text = ""
	icon_header.custom_minimum_size = Vector2(32, 0)
	parent.add_child(icon_header)

	# Name column (expands)
	var name_header = Label.new()
	name_header.text = "BUILDING"
	name_header.add_theme_font_size_override("font_size", 10)
	name_header.add_theme_color_override("font_color", COLOR_MUTED)
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_header.custom_minimum_size = Vector2(140, 0)
	parent.add_child(name_header)

	# Tier column
	var tier_header = Label.new()
	tier_header.text = "TIER"
	tier_header.add_theme_font_size_override("font_size", 10)
	tier_header.add_theme_color_override("font_color", COLOR_MUTED)
	tier_header.custom_minimum_size = Vector2(40, 0)
	parent.add_child(tier_header)

	# Production column
	var prod_header = Label.new()
	prod_header.text = "PRODUCTION"
	prod_header.add_theme_font_size_override("font_size", 10)
	prod_header.add_theme_color_override("font_color", COLOR_MUTED)
	prod_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_header.custom_minimum_size = Vector2(180, 0)
	parent.add_child(prod_header)

	# Action column
	var action_header = Label.new()
	action_header.text = ""
	action_header.custom_minimum_size = Vector2(70, 0)
	parent.add_child(action_header)

func _select_category(category: String) -> void:
	"""Select a category and show its buildings"""
	selected_category = category

	# Update button styles
	for cat in category_buttons:
		var btn: Button = category_buttons[cat]
		_style_category_button(btn, cat, cat == category)

	# Update title
	var title_node = right_panel.get_node_or_null("CategoryTitle")
	if title_node:
		title_node.text = "%s %s" % [CATEGORY_ICONS.get(category, "📦"), category.capitalize().to_upper()]
		title_node.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, COLOR_HEADER))

	_refresh_building_list()

func _refresh_building_list() -> void:
	"""Refresh the building list with current category and sorting"""
	if not buildings_list:
		return

	# Clear existing buildings
	for child in buildings_list.get_children():
		child.queue_free()

	# Get buildings for this category
	var category_buildings: Array = all_buildings.filter(func(b): return b.get("category", "") == selected_category)

	# Apply sorting
	category_buildings = _sort_buildings(category_buildings)

	if category_buildings.is_empty():
		var no_buildings = Label.new()
		no_buildings.text = "No %s buildings available for tier %d tiles." % [selected_category, current_node.tier]
		no_buildings.add_theme_font_size_override("font_size", 14)
		no_buildings.add_theme_color_override("font_color", COLOR_MUTED)
		no_buildings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buildings_list.add_child(no_buildings)
		return

	# Create building rows
	for building in category_buildings:
		var row = _create_building_row(building)
		buildings_list.add_child(row)

func _sort_buildings(buildings: Array) -> Array:
	"""Sort buildings based on current sort settings"""
	var sorted = buildings.duplicate()

	match current_sort:
		"tier":
			sorted.sort_custom(func(a, b):
				var tier_a = a.get("tier", 1)
				var tier_b = b.get("tier", 1)
				return tier_a < tier_b if sort_ascending else tier_a > tier_b
			)
		"name":
			sorted.sort_custom(func(a, b):
				var name_a = a.get("name", "").to_lower()
				var name_b = b.get("name", "").to_lower()
				return name_a < name_b if sort_ascending else name_a > name_b
			)
		"production":
			sorted.sort_custom(func(a, b):
				var prod_a = _get_total_production(a)
				var prod_b = _get_total_production(b)
				return prod_a < prod_b if sort_ascending else prod_a > prod_b
			)

	return sorted

func _get_total_production(building: Dictionary) -> int:
	"""Get total production value for sorting"""
	var production = building.get("production", {})
	var total = 0
	for res_id in production:
		total += int(production[res_id])
	return total

func _on_sort_button_pressed() -> void:
	"""Cycle through sort options"""
	var sort_options = ["tier", "name", "production"]
	var current_idx = sort_options.find(current_sort)
	current_idx = (current_idx + 1) % sort_options.size()
	current_sort = sort_options[current_idx]

	# Update button text
	match current_sort:
		"tier": sort_button.text = "Tier"
		"name": sort_button.text = "Name"
		"production": sort_button.text = "Production"

	_refresh_building_list()

func _on_sort_direction_pressed() -> void:
	"""Toggle sort direction"""
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	_refresh_building_list()

func _on_category_pressed(category: String) -> void:
	"""Handle category button press"""
	_select_category(category)

func _style_category_button(btn: Button, category: String, is_selected: bool) -> void:
	"""Style a category button"""
	var cat_color = CATEGORY_COLORS.get(category, COLOR_BORDER)

	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = cat_color * 0.4
		style.border_color = cat_color
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 0.8)
		style.border_color = cat_color * 0.5
		style.set_border_width_all(1)

	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = cat_color * 0.3 if not is_selected else cat_color * 0.5
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", cat_color if is_selected else Color(0.8, 0.8, 0.85))
	btn.add_theme_font_size_override("font_size", 13)

func _get_available_buildings() -> Array:
	"""Get buildings available for the current tile"""
	if not building_manager or not current_node:
		return []

	return building_manager.get_available_buildings_for_tile(current_node)

func _create_building_row(building: Dictionary) -> PanelContainer:
	"""Create a single-row building entry for the list"""
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	var building_id = building.get("id", "")
	var category = building.get("category", "")
	var tier = building.get("tier", 1)

	# Style the row
	_style_building_row(row, category)

	# Horizontal layout for all columns
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)

	# Icon column (fixed width)
	var icon_label = Label.new()
	icon_label.text = BUILDING_ICONS.get(building_id, CATEGORY_ICONS.get(category, "🏠"))
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.custom_minimum_size = Vector2(32, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(icon_label)

	# Name + description column (expands)
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.custom_minimum_size = Vector2(140, 0)
	name_vbox.add_theme_constant_override("separation", 0)
	content.add_child(name_vbox)

	var name_label = Label.new()
	name_label.text = building.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.clip_text = true
	name_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = building.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", COLOR_MUTED)
	desc_label.clip_text = true
	name_vbox.add_child(desc_label)

	# Tier column (fixed width)
	var tier_label = Label.new()
	var tier_stars = ""
	for i in range(tier):
		tier_stars += "★"
	tier_label.text = tier_stars
	tier_label.add_theme_font_size_override("font_size", 12)
	tier_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, COLOR_GOLD))
	tier_label.custom_minimum_size = Vector2(40, 0)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tier_label)

	# Production column (expands)
	var prod_label = Label.new()
	prod_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_label.custom_minimum_size = Vector2(180, 0)
	prod_label.add_theme_font_size_override("font_size", 11)
	prod_label.clip_text = true

	var production = building.get("production", {})
	var consumes = building.get("consumes", {})

	if not production.is_empty():
		if not consumes.is_empty():
			# Processing/conversion building
			var input_parts = []
			var output_parts = []
			for res_id in consumes:
				input_parts.append("%d %s" % [consumes[res_id], _format_resource_name(res_id)])
			for res_id in production:
				output_parts.append("%d %s" % [production[res_id], _format_resource_name(res_id)])
			prod_label.text = "%s → %s/h" % [", ".join(input_parts), ", ".join(output_parts)]
			prod_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		else:
			# Pure production building
			var prod_parts = []
			for res_id in production:
				prod_parts.append("%d %s/h" % [production[res_id], _format_resource_name(res_id)])
			prod_label.text = ", ".join(prod_parts)
			prod_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		prod_label.text = "—"
		prod_label.add_theme_color_override("font_color", COLOR_MUTED)

	content.add_child(prod_label)

	# Build button column (fixed width)
	var build_btn = Button.new()
	build_btn.text = "BUILD"
	build_btn.custom_minimum_size = Vector2(70, 32)
	build_btn.pressed.connect(_on_building_selected.bind(building_id))
	_style_build_button(build_btn, true)
	content.add_child(build_btn)

	return row

func _format_resource_name(res_id: String) -> String:
	"""Format resource ID for display (shorten common names)"""
	var res_name = res_id.replace("_", " ")
	# Shorten common resource names
	res_name = res_name.replace("raw ", "")
	res_name = res_name.replace("refined ", "")
	if res_name.length() > 12:
		res_name = res_name.substr(0, 10) + ".."
	return res_name

func _style_building_row(row: PanelContainer, category: String) -> void:
	"""Style a building row"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)

	var cat_color = CATEGORY_COLORS.get(category, COLOR_BORDER)
	style.border_color = cat_color * 0.6
	style.set_border_width_all(1)
	style.border_width_left = 3  # Accent border on left
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)

func _style_sort_button(btn: Button) -> void:
	"""Style the sort control buttons"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.2, 0.17, 0.25, 0.95)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", COLOR_HEADER)

func _can_afford_building(building_id: String) -> bool:
	"""Check if player can afford the building"""
	if not building_manager:
		return true

	var cost = building_manager.get_build_cost(building_id)
	if cost.is_empty():
		return true

	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if not resource_manager:
		return true

	for res_id in cost:
		if resource_manager.get_resource(res_id) < cost[res_id]:
			return false

	return true

# ==============================================================================
# STYLING
# ==============================================================================
func _style_panel(panel: PanelContainer) -> void:
	"""Apply dark fantasy panel style"""
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

func _style_close_button(btn: Button) -> void:
	"""Style the close button"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.2, 0.9)
	style.border_color = Color(0.6, 0.3, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.5, 0.25, 0.25, 0.95)
	hover.border_color = Color(0.7, 0.4, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_font_size_override("font_size", 18)

func _style_build_button(btn: Button, can_afford: bool) -> void:
	"""Style the build button"""
	var style = StyleBoxFlat.new()
	if can_afford:
		style.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style.bg_color = Color(0.25, 0.2, 0.2, 0.7)
		style.border_color = Color(0.4, 0.3, 0.3, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.2, 0.18, 0.18, 0.6)
	disabled.border_color = Color(0.3, 0.25, 0.25, 0.5)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", disabled)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_overlay_input(event: InputEvent) -> void:
	"""Handle click on overlay - close popup (cancel selection)"""
	if event is InputEventMouseButton and event.pressed:
		selection_cancelled.emit(current_node)
		hide_popup()

func _on_close_pressed() -> void:
	"""Handle close button press"""
	selection_cancelled.emit(current_node)
	hide_popup()

func _on_building_selected(building_id: String) -> void:
	"""Handle building selection - place the building"""
	if not current_node or not building_manager:
		hide_popup()
		return


	# Attempt to place the building
	var success = building_manager.place_building(current_node, building_id)

	if success:
		building_selected.emit(current_node, building_id)
		# Trigger building placed tutorial
		_trigger_building_placed_tutorial()
	else:
		push_error("BuildingSelectionPopup: Failed to place building")
		# Could show error feedback here

	hide_popup()

func _trigger_building_placed_tutorial() -> void:
	"""Trigger the garrison tutorial after first building placement."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return

	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if tutorial_orch:
		tutorial_orch.trigger_building_placed()
