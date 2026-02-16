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

# UI references
var overlay: ColorRect = null
var main_panel: PanelContainer = null
var content_container: VBoxContainer = null
var buildings_grid: GridContainer = null

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
	"""Build the popup UI following UI_DESIGN_PATTERNS.md popup pattern"""
	# Clean up existing UI
	for child in get_children():
		child.queue_free()

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

	var panel_width = mini(viewport_size.x * 0.9, 720)
	var panel_height = mini(viewport_size.y * 0.85, 600)
	main_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	main_panel.size = Vector2(panel_width, panel_height)
	main_panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)

	_style_panel(main_panel)
	add_child(main_panel)

	# === Content Container ===
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 12)
	main_panel.add_child(content_container)

	# === Header with title and close button ===
	_build_header()

	# === Tile info ===
	_build_tile_info()

	# === Separator ===
	var sep = HSeparator.new()
	content_container.add_child(sep)

	# === Buildings grid in scroll container ===
	_build_buildings_section()

func _build_header() -> void:
	"""Build header with title and close button"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content_container.add_child(header)

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

func _build_tile_info() -> void:
	"""Show info about the captured tile"""
	if not current_node:
		return

	var info_box = HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 20)
	content_container.add_child(info_box)

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

func _build_buildings_section() -> void:
	"""Build the buildings selection grid"""
	# Category filter tabs (optional - for now show all)
	var filter_label = Label.new()
	filter_label.text = "Available Buildings"
	filter_label.add_theme_font_size_override("font_size", 16)
	filter_label.add_theme_color_override("font_color", COLOR_HEADER)
	content_container.add_child(filter_label)

	# Scroll container for building grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_container.add_child(scroll)

	# Grid for building cards (3 columns)
	buildings_grid = GridContainer.new()
	buildings_grid.columns = 3
	buildings_grid.add_theme_constant_override("h_separation", 10)
	buildings_grid.add_theme_constant_override("v_separation", 10)
	buildings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buildings_grid)

	# Get available buildings for this tile
	var available_buildings = _get_available_buildings()

	if available_buildings.is_empty():
		var no_buildings = Label.new()
		no_buildings.text = "No buildings available for this tile tier."
		no_buildings.add_theme_font_size_override("font_size", 14)
		no_buildings.add_theme_color_override("font_color", COLOR_MUTED)
		buildings_grid.add_child(no_buildings)
		return

	# Sort by category then tier
	available_buildings.sort_custom(func(a, b):
		if a.get("category", "") != b.get("category", ""):
			return a.get("category", "") < b.get("category", "")
		return a.get("tier", 1) < b.get("tier", 1)
	)

	# Create building cards
	for building in available_buildings:
		var card = _create_building_card(building)
		buildings_grid.add_child(card)

func _get_available_buildings() -> Array:
	"""Get buildings available for the current tile"""
	if not building_manager or not current_node:
		return []

	return building_manager.get_available_buildings_for_tile(current_node)

func _create_building_card(building: Dictionary) -> PanelContainer:
	"""Create a building card for selection"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 160)

	var building_id = building.get("id", "")
	var category = building.get("category", "")
	var tier = building.get("tier", 1)

	# Buildings are FREE - always show as affordable
	_style_building_card(card, category, true)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)

	# Header row with icon and name
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	content.add_child(header)

	var icon_label = Label.new()
	icon_label.text = BUILDING_ICONS.get(building_id, CATEGORY_ICONS.get(category, "🏠"))
	icon_label.add_theme_font_size_override("font_size", 20)
	header.add_child(icon_label)

	var name_label = Label.new()
	name_label.text = building.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	header.add_child(name_label)

	# Tier indicator
	var tier_label = Label.new()
	tier_label.text = "T%d" % tier
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, COLOR_MUTED))
	header.add_child(tier_label)

	# Category
	var cat_label = Label.new()
	cat_label.text = category.capitalize()
	cat_label.add_theme_font_size_override("font_size", 10)
	cat_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, COLOR_MUTED))
	content.add_child(cat_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = building.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 30)
	content.add_child(desc_label)

	# Production preview - handle both production and conversion
	var production = building.get("production", {})
	var consumes = building.get("consumes", {})

	if not production.is_empty():
		var prod_label = Label.new()

		if not consumes.is_empty():
			# This is a processing/conversion building
			var input_parts = []
			var output_parts = []
			for res_id in consumes:
				input_parts.append("%d %s" % [consumes[res_id], res_id.replace("_", " ")])
			for res_id in production:
				output_parts.append("%d %s" % [production[res_id], res_id.replace("_", " ")])
			prod_label.text = "Converts: %s → %s/h" % [", ".join(input_parts), ", ".join(output_parts)]
			prod_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))  # Orange for conversion
		else:
			# Pure production building
			var prod_parts = []
			for res_id in production:
				prod_parts.append("%d %s/h" % [production[res_id], res_id.replace("_", " ")])
			prod_label.text = "Produces: " + ", ".join(prod_parts)
			prod_label.add_theme_color_override("font_color", COLOR_SUCCESS)

		prod_label.add_theme_font_size_override("font_size", 10)
		content.add_child(prod_label)

	# Building selection is FREE
	var free_label = Label.new()
	free_label.text = "Cost: FREE"
	free_label.add_theme_font_size_override("font_size", 10)
	free_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	content.add_child(free_label)

	# Build button - always enabled since building is free
	var build_btn = Button.new()
	build_btn.text = "BUILD"
	build_btn.custom_minimum_size = Vector2(0, 28)
	build_btn.pressed.connect(_on_building_selected.bind(building_id))
	_style_build_button(build_btn, true)
	content.add_child(build_btn)

	return card

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

func _style_building_card(card: PanelContainer, category: String, can_afford: bool) -> void:
	"""Style a building card"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95) if can_afford else Color(0.08, 0.08, 0.1, 0.8)

	var cat_color = CATEGORY_COLORS.get(category, COLOR_BORDER)
	style.border_color = cat_color if can_afford else cat_color * 0.5
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

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
	else:
		push_error("BuildingSelectionPopup: Failed to place building")
		# Could show error feedback here

	hide_popup()
