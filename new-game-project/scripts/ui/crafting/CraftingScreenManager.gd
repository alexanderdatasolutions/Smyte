# scripts/ui/crafting/CraftingScreenManager.gd
# Unified crafting screen following TeamSelectionManager pattern
# Left panel: Active crafts, forge info, set bonuses
# Right panel: Type filter tabs, sort controls, recipe grid
class_name CraftingScreenManager
extends RefCounted

# ==============================================================================
# CONSTANTS
# ==============================================================================
const EQUIPMENT_TYPES: Array[String] = ["all", "weapon", "armor", "helm", "boots", "amulet", "ring"]
const TYPE_ICONS: Dictionary = {
	"all": "📦",
	"weapon": "⚔️",
	"armor": "🛡️",
	"helm": "⛑️",
	"boots": "👢",
	"amulet": "💍",
	"ring": "💎"
}

const PROGRESS_COLORS: Dictionary = {
	"common": Color(0.5, 0.5, 0.5),
	"rare": Color(0.4, 0.6, 0.9),
	"epic": Color(0.7, 0.4, 0.9),
	"legendary": Color(1.0, 0.7, 0.2)
}

# Panel colors (from MEMORY.md palette)
const BG_MAIN := Color(0.08, 0.06, 0.12)
const BG_PANEL := Color(0.12, 0.1, 0.16, 0.95)
const BORDER_PANEL := Color(0.3, 0.25, 0.4, 0.8)
const TEXT_HEADER := Color(0.8, 0.8, 0.9)
const TEXT_MUTED := Color(0.5, 0.5, 0.55)

# Static config cache
static var _equipment_config: Dictionary = {}
static var _buildings_config: Dictionary = {}
static var _crafting_recipes: Dictionary = {}
static var _config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	# Load equipment config
	var eq_file := FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if eq_file:
		var parsed: Variant = JSON.parse_string(eq_file.get_as_text())
		eq_file.close()
		if parsed is Dictionary:
			_equipment_config = parsed
	# Load buildings config
	var bld_file := FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if bld_file:
		var parsed: Variant = JSON.parse_string(bld_file.get_as_text())
		bld_file.close()
		if parsed is Dictionary:
			_buildings_config = parsed.get("buildings", {})
	# Load crafting recipes (flat structure - recipes at top level)
	var recipes_file := FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if recipes_file:
		var parsed: Variant = JSON.parse_string(recipes_file.get_as_text())
		recipes_file.close()
		if parsed is Dictionary:
			_crafting_recipes = {}
			for key: String in parsed.keys():
				# Skip metadata and comment keys
				if key.begins_with("_"):
					continue
				var recipe: Variant = parsed[key]
				if recipe is Dictionary:
					_crafting_recipes[key] = recipe
	_config_loaded = true

# ==============================================================================
# STATE
# ==============================================================================
var _popup: Control = null
var _recipe_grid: GridContainer = null
var _active_crafts_container: VBoxContainer = null
var _filter_tabs: HBoxContainer = null
var _recipe_count_label: Label = null
var _forge_selector_container: VBoxContainer = null
var _forge_info_container: VBoxContainer = null

var _current_node = null  # HexNode - currently selected forge
var _all_forges: Array = []  # All player forges
var _all_recipes: Array = []
var _filtered_recipes: Array = []
var _current_filter: String = "all"
var _current_sort: String = "tier"
var _craftable_only: bool = false
var _craftable_toggle: Button = null

var _hex_grid_manager = null
var _resource_manager = null
var _territory_manager = null

# Signals
signal craft_started(node, task_id)
signal craft_cancelled(node, task_id)
signal popup_closed

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Show the crafting screen with all player forges (multi-forge mode)
func show_all_forges(
	hex_grid_manager,
	resource_manager,
	territory_manager,
	parent_node: Node = null,
	initial_node = null  # Optional: pre-select this forge
) -> void:
	_hex_grid_manager = hex_grid_manager
	_resource_manager = resource_manager
	_territory_manager = territory_manager
	_current_filter = "all"

	# Load all player forges
	_all_forges = _get_all_player_forges()

	# Select initial forge (first one with workers, or the specified one)
	if initial_node:
		_current_node = initial_node
	elif not _all_forges.is_empty():
		# Prefer forge with workers assigned
		for forge in _all_forges:
			if forge.assigned_workers and not forge.assigned_workers.is_empty():
				_current_node = forge
				break
		if not _current_node:
			_current_node = _all_forges[0]

	# Load recipes for current forge
	_load_recipes_for_current_forge()

	_create_popup(parent_node)

## Show the crafting screen for a given forge node (single-forge mode, legacy)
func show_crafting_screen(
	node,
	recipes: Array,
	hex_grid_manager,
	resource_manager,
	parent_node: Node = null
) -> void:
	_current_node = node
	_all_forges = [node] if node else []
	_all_recipes = recipes
	_hex_grid_manager = hex_grid_manager
	_resource_manager = resource_manager
	_current_filter = "all"
	_filtered_recipes = recipes.duplicate()

	_create_popup(parent_node)

## Close the crafting screen
func close() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null
	popup_closed.emit()

# ==============================================================================
# FORGE MANAGEMENT
# ==============================================================================

func _get_all_player_forges() -> Array:
	"""Get all player-owned forge nodes with crafting buildings"""
	var forges: Array = []
	if not _territory_manager:
		return forges

	var crafting_buildings: Array = ["blacksmith", "weapon_forge", "armor_forge", "divine_forge", "jeweler"]
	var controlled_nodes: Array = _territory_manager.get_controlled_nodes()

	for node in controlled_nodes:
		var placed_building: String = ""
		if "placed_building" in node:
			placed_building = str(node.placed_building)

		# Check if it's a crafting building OR a forge node type
		if placed_building in crafting_buildings or node.node_type == "forge":
			forges.append(node)

	# Sort by tier descending, then by name
	forges.sort_custom(func(a, b):
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.name < b.name
	)

	return forges

func _load_recipes_for_current_forge() -> void:
	"""Load available recipes for the currently selected forge"""
	_all_recipes = []
	if not _current_node:
		return

	# Load crafting recipes from cached data
	_load_config()

	for recipe_id: String in _crafting_recipes:
		var recipe: Dictionary = _crafting_recipes[recipe_id].duplicate()
		recipe["id"] = recipe_id

		# Check tier requirement
		var required_tier: int = recipe.get("tier", 1)
		if _current_node.tier >= required_tier:
			_all_recipes.append(recipe)

	_filtered_recipes = _all_recipes.duplicate()

func _select_forge(node) -> void:
	"""Select a forge and update the UI"""
	_current_node = node
	_load_recipes_for_current_forge()
	_apply_filter_and_sort()
	_update_active_crafts()
	_update_forge_info()
	_update_forge_selector_styles()

func _update_forge_info() -> void:
	"""Update the forge info section for the selected forge"""
	if not _forge_info_container:
		return

	# Clear existing
	for child in _forge_info_container.get_children():
		child.queue_free()

	if not _current_node:
		var no_forge := Label.new()
		no_forge.text = "No forge selected"
		no_forge.add_theme_font_size_override("font_size", 11)
		no_forge.add_theme_color_override("font_color", TEXT_MUTED)
		_forge_info_container.add_child(no_forge)
		return

	# Tier with stars
	var tier_row := _create_info_row("Tier:", _get_tier_stars(_current_node.tier))
	_forge_info_container.add_child(tier_row)

	# Workers
	var workers_assigned: int = _current_node.assigned_workers.size() if _current_node.assigned_workers else 0
	_load_config()
	var forge_cfg: Dictionary = _equipment_config.get("forge_config", {})
	var default_max: int = int(forge_cfg.get("default_max_workers", 3))
	var building_cfg: Dictionary = _buildings_config.get(_current_node.placed_building, {})
	var max_workers: int = int(building_cfg.get("max_workers", default_max))
	var workers_row := _create_info_row("Workers:", "%d/%d" % [workers_assigned, max_workers])
	_forge_info_container.add_child(workers_row)

	# Warning if no workers
	if workers_assigned == 0:
		var warning_label := Label.new()
		warning_label.text = "⚠️ Assign a worker to craft!"
		warning_label.add_theme_font_size_override("font_size", 10)
		warning_label.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		_forge_info_container.add_child(warning_label)

	# Craft slots
	var max_crafts := _get_max_crafts_for_tier(_current_node.tier)
	var active_crafts: int = 0
	if _hex_grid_manager and _hex_grid_manager.has_method("get_active_crafts_for_node"):
		active_crafts = _hex_grid_manager.get_active_crafts_for_node(_current_node.id).size()
	var craft_slots_row := _create_info_row("Craft Slots:", "%d/%d" % [active_crafts, max_crafts])
	_forge_info_container.add_child(craft_slots_row)

func _update_forge_selector_styles() -> void:
	"""Update the visual state of forge selector buttons"""
	if not _forge_selector_container:
		return

	for child in _forge_selector_container.get_children():
		if child is Button:
			var forge_node = child.get_meta("forge_node", null)
			var is_selected: bool = forge_node == _current_node
			_style_forge_button(child, is_selected, forge_node)

# ==============================================================================
# POPUP CREATION
# ==============================================================================

func _create_popup(parent_node: Node) -> void:
	# Remove existing popup
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()

	var viewport_size := Vector2(1280, 720)  # Default fallback
	if parent_node:
		viewport_size = parent_node.get_viewport().get_visible_rect().size

	# Main popup container
	_popup = Control.new()
	_popup.name = "CraftingScreen"
	_popup.z_index = 100
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark overlay - click to close
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.gui_input.connect(_on_overlay_clicked)
	_popup.add_child(overlay)

	# Main panel
	var panel_width := mini(viewport_size.x * 0.95, 900)
	var panel_height := viewport_size.y * 0.9
	var main_panel := PanelContainer.new()
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	main_panel.size = Vector2(panel_width, panel_height)
	main_panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)
	_style_main_panel(main_panel)
	_popup.add_child(main_panel)

	# Content layout
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	main_panel.add_child(content)

	# Header
	content.add_child(_build_header())

	# Separator
	content.add_child(HSeparator.new())

	# Main body: left + right panels
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	# Left panel (280px fixed)
	body.add_child(_build_left_panel())

	# Vertical separator
	body.add_child(VSeparator.new())

	# Right panel (flexible)
	body.add_child(_build_right_panel())

	# Bottom bar
	content.add_child(HSeparator.new())
	content.add_child(_build_bottom_bar())

	# Add to scene tree
	if parent_node:
		var main_node = parent_node.get_tree().root.get_node_or_null("Main")
		if main_node:
			main_node.add_child(_popup)
		else:
			parent_node.add_child(_popup)

	# IMPORTANT: Store reference to self in popup to prevent garbage collection
	# CraftingScreenManager extends RefCounted, so without this reference the manager
	# can be garbage collected while the popup is still visible, breaking button callbacks
	_popup.set_meta("_manager_ref", self)

	# Initial population
	_apply_filter_and_sort()
	_update_active_crafts()

func _style_main_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_color = BORDER_PANEL
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

# ==============================================================================
# HEADER
# ==============================================================================

func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "⚒️ CRAFTING"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Forge tier info
	if _current_node:
		var tier_label := Label.new()
		tier_label.text = "Tier %d Forge" % _current_node.tier
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", TEXT_MUTED)
		header.add_child(tier_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(close)
	_style_close_button(close_btn)
	header.add_child(close_btn)

	return header

func _style_close_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.2, 0.9)
	style.border_color = Color(0.6, 0.3, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 16)

	var hover := style.duplicate()
	hover.bg_color = Color(0.5, 0.25, 0.25, 1)
	btn.add_theme_stylebox_override("hover", hover)

# ==============================================================================
# LEFT PANEL
# ==============================================================================

func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_section_panel(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Forge Selector section (if multiple forges)
	if _all_forges.size() > 1:
		content.add_child(_build_forge_selector_section())
		content.add_child(HSeparator.new())

	# Active Crafts section
	content.add_child(_build_active_crafts_section())

	# Separator
	content.add_child(HSeparator.new())

	# Forge Info section
	content.add_child(_build_forge_info_section())

	# Separator
	content.add_child(HSeparator.new())

	# Set Bonuses section
	content.add_child(_build_set_bonuses_section())

	return panel

func _build_forge_selector_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "YOUR FORGES"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", TEXT_HEADER)
	section.add_child(header)

	_forge_selector_container = VBoxContainer.new()
	_forge_selector_container.add_theme_constant_override("separation", 4)
	section.add_child(_forge_selector_container)

	# Add a button for each forge
	for forge in _all_forges:
		var btn := Button.new()
		var workers_count: int = forge.assigned_workers.size() if forge.assigned_workers else 0
		var active_crafts: int = 0
		if _hex_grid_manager and _hex_grid_manager.has_method("get_active_crafts_for_node"):
			active_crafts = _hex_grid_manager.get_active_crafts_for_node(forge.id).size()

		# Format: "★★ Forge Name (2 workers, 1 craft)"
		var stars: String = "★".repeat(forge.tier)
		var status_parts: Array = []
		if workers_count > 0:
			status_parts.append("%d worker%s" % [workers_count, "s" if workers_count > 1 else ""])
		if active_crafts > 0:
			status_parts.append("%d active" % active_crafts)

		var status_text: String = " - " + ", ".join(status_parts) if not status_parts.is_empty() else ""
		btn.text = "%s %s%s" % [stars, forge.name, status_text]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.set_meta("forge_node", forge)
		btn.pressed.connect(_on_forge_button_pressed.bind(forge))

		var is_selected: bool = forge == _current_node
		_style_forge_button(btn, is_selected, forge)
		_forge_selector_container.add_child(btn)

	return section

func _on_forge_button_pressed(forge) -> void:
	_select_forge(forge)

func _style_forge_button(btn: Button, is_selected: bool, forge) -> void:
	var has_workers: bool = forge.assigned_workers and not forge.assigned_workers.is_empty()

	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.25, 0.35, 0.45, 0.95)
		style.border_color = Color(0.4, 0.6, 0.8, 1)
		style.set_border_width_all(2)
	elif not has_workers:
		style.bg_color = Color(0.15, 0.12, 0.18, 0.7)
		style.border_color = Color(0.4, 0.3, 0.3, 0.5)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.15, 0.18, 0.22, 0.9)
		style.border_color = Color(0.3, 0.4, 0.5, 0.7)
		style.set_border_width_all(1)

	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 11)

	if not has_workers:
		btn.add_theme_color_override("font_color", Color(0.5, 0.45, 0.45))
	elif is_selected:
		btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	else:
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

func _style_section_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.8)
	style.border_color = Color(0.25, 0.2, 0.35, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _build_active_crafts_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "ACTIVE CRAFTS"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", TEXT_HEADER)
	section.add_child(header)

	_active_crafts_container = VBoxContainer.new()
	_active_crafts_container.add_theme_constant_override("separation", 8)
	section.add_child(_active_crafts_container)

	return section

func _build_forge_info_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "FORGE INFO"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	section.add_child(header)

	# Dynamic content container - stored for updates when switching forges
	_forge_info_container = VBoxContainer.new()
	_forge_info_container.add_theme_constant_override("separation", 4)
	section.add_child(_forge_info_container)

	# Populate initial content
	_update_forge_info()

	return section

func _create_info_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	row.add_child(value)

	return row

func _get_tier_stars(tier: int) -> String:
	var stars := ""
	for i in range(tier):
		stars += "★"
	return stars + " (T%d)" % tier

func _get_max_crafts_for_tier(tier: int) -> int:
	_load_config()
	var forge_cfg: Dictionary = _equipment_config.get("forge_config", {})
	var max_crafts_cfg: Dictionary = forge_cfg.get("max_crafts_per_tier", {})
	return int(max_crafts_cfg.get(str(tier), 1))

func _build_set_bonuses_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "SET BONUSES"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	section.add_child(header)

	# Show a few example set bonuses from metadata
	var set_bonuses := {
		"wrath": {"2pc": "+15% ATK", "4pc": "+30% ATK"},
		"aegis": {"2pc": "+15% DEF", "4pc": "+30% DEF, +15% HP"},
		"zephyr": {"2pc": "+25 SPD", "4pc": "+50 SPD"},
		"titan": {"2pc": "+15% HP", "4pc": "+30% HP"},
		"fury": {"2pc": "+20% Crit Dmg", "4pc": "+40% Crit Dmg"}
	}

	for set_name in set_bonuses:
		var bonus_data: Dictionary = set_bonuses[set_name]

		var set_label := Label.new()
		set_label.text = "─ %s ─" % set_name.capitalize()
		set_label.add_theme_font_size_override("font_size", 10)
		set_label.add_theme_color_override("font_color", CraftingUIUtils.get_rarity_color("rare"))
		section.add_child(set_label)

		var two_pc := Label.new()
		two_pc.text = "  2pc: %s" % bonus_data.get("2pc", "")
		two_pc.add_theme_font_size_override("font_size", 9)
		two_pc.add_theme_color_override("font_color", TEXT_MUTED)
		section.add_child(two_pc)

		var four_pc := Label.new()
		four_pc.text = "  4pc: %s" % bonus_data.get("4pc", "")
		four_pc.add_theme_font_size_override("font_size", 9)
		four_pc.add_theme_color_override("font_color", TEXT_MUTED)
		section.add_child(four_pc)

	return section

# ==============================================================================
# RIGHT PANEL
# ==============================================================================

func _build_right_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Filter tabs
	panel.add_child(_build_filter_tabs())

	# Sort controls row
	panel.add_child(_build_sort_row())

	# Recipe scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_recipe_grid = CraftingUIUtils.create_recipe_grid(3)
	scroll.add_child(_recipe_grid)

	return panel

func _build_filter_tabs() -> HBoxContainer:
	_filter_tabs = HBoxContainer.new()
	_filter_tabs.add_theme_constant_override("separation", 4)

	for eq_type in EQUIPMENT_TYPES:
		var tab := Button.new()
		var icon: String = TYPE_ICONS.get(eq_type, "")
		tab.text = icon if eq_type != "all" else "All"
		tab.custom_minimum_size = Vector2(50, 32)
		tab.set_meta("filter_type", eq_type)
		tab.pressed.connect(_on_filter_tab_pressed.bind(eq_type))
		_style_filter_tab(tab, eq_type == _current_filter)
		_filter_tabs.add_child(tab)

	return _filter_tabs

func _style_filter_tab(tab: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.25, 0.2, 0.35, 0.95)
		style.border_color = Color(0.5, 0.4, 0.7, 0.9)
	else:
		style.bg_color = Color(0.12, 0.1, 0.16, 0.8)
		style.border_color = Color(0.3, 0.25, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	tab.add_theme_stylebox_override("normal", style)
	tab.add_theme_font_size_override("font_size", 12)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	tab.add_theme_stylebox_override("hover", hover)

func _build_sort_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var sort_label := Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 11)
	sort_label.add_theme_color_override("font_color", TEXT_MUTED)
	row.add_child(sort_label)

	# Sort dropdown
	var sort_dropdown := OptionButton.new()
	sort_dropdown.add_item("Tier", 0)
	sort_dropdown.add_item("Rarity", 1)
	sort_dropdown.add_item("Set", 2)
	sort_dropdown.add_item("Craftable", 3)
	sort_dropdown.custom_minimum_size = Vector2(90, 28)
	sort_dropdown.item_selected.connect(_on_sort_changed)
	row.add_child(sort_dropdown)

	# Craftable toggle
	_craftable_toggle = Button.new()
	_craftable_toggle.text = "✓ Craftable"
	_craftable_toggle.toggle_mode = true
	_craftable_toggle.button_pressed = _craftable_only
	_craftable_toggle.custom_minimum_size = Vector2(90, 28)
	_craftable_toggle.toggled.connect(_on_craftable_toggled)
	_style_craftable_toggle(_craftable_toggle, _craftable_only)
	row.add_child(_craftable_toggle)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Recipe count
	_recipe_count_label = Label.new()
	_recipe_count_label.text = "%d recipes" % _filtered_recipes.size()
	_recipe_count_label.add_theme_font_size_override("font_size", 11)
	_recipe_count_label.add_theme_color_override("font_color", TEXT_MUTED)
	row.add_child(_recipe_count_label)

	return row

func _style_craftable_toggle(btn: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.2, 0.4, 0.25, 0.95)
		style.border_color = Color(0.4, 0.7, 0.45, 0.9)
	else:
		style.bg_color = Color(0.12, 0.1, 0.16, 0.8)
		style.border_color = Color(0.3, 0.25, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_font_size_override("font_size", 11)

func _on_craftable_toggled(toggled_on: bool) -> void:
	_craftable_only = toggled_on
	_style_craftable_toggle(_craftable_toggle, toggled_on)
	_apply_filter_and_sort()

# ==============================================================================
# BOTTOM BAR
# ==============================================================================

func _build_bottom_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(close)
	_style_action_button(close_btn, false)
	bar.add_child(close_btn)

	return bar

func _style_action_button(btn: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 14)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

# ==============================================================================
# FILTERING & SORTING
# ==============================================================================

func _on_filter_tab_pressed(eq_type: String) -> void:
	_current_filter = eq_type
	_update_filter_tab_styles()
	_apply_filter_and_sort()

func _update_filter_tab_styles() -> void:
	for i in range(_filter_tabs.get_child_count()):
		var tab := _filter_tabs.get_child(i) as Button
		if tab:
			var tab_type := tab.get_meta("filter_type", "all") as String
			_style_filter_tab(tab, tab_type == _current_filter)

func _on_sort_changed(index: int) -> void:
	match index:
		0: _current_sort = "tier"
		1: _current_sort = "rarity"
		2: _current_sort = "set"
		3: _current_sort = "craftable"
	_apply_filter_and_sort()

func _apply_filter_and_sort() -> void:
	# Filter by equipment type
	if _current_filter == "all":
		_filtered_recipes = _all_recipes.duplicate()
	else:
		_filtered_recipes = []
		for recipe in _all_recipes:
			if recipe.get("equipment_type", "") == _current_filter:
				_filtered_recipes.append(recipe)

	# Filter by craftable
	if _craftable_only:
		var craftable_recipes: Array = []
		for recipe in _filtered_recipes:
			if _can_afford(recipe):
				craftable_recipes.append(recipe)
		_filtered_recipes = craftable_recipes

	# Sort
	match _current_sort:
		"tier":
			_filtered_recipes.sort_custom(func(a, b): return a.get("tier", 1) < b.get("tier", 1))
		"rarity":
			_filtered_recipes.sort_custom(_sort_by_rarity)
		"set":
			_filtered_recipes.sort_custom(func(a, b): return a.get("equipment_set", "") < b.get("equipment_set", ""))
		"craftable":
			_filtered_recipes.sort_custom(_sort_craftable_first)

	_populate_recipe_grid()
	if _recipe_count_label:
		_recipe_count_label.text = "%d recipes" % _filtered_recipes.size()

func _sort_by_rarity(a: Dictionary, b: Dictionary) -> bool:
	var rarity_order: Dictionary = {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}
	var a_val: int = rarity_order.get(a.get("rarity", "common"), 0)
	var b_val: int = rarity_order.get(b.get("rarity", "common"), 0)
	return a_val < b_val

func _sort_craftable_first(a: Dictionary, b: Dictionary) -> bool:
	var a_afford := _can_afford(a)
	var b_afford := _can_afford(b)
	if a_afford and not b_afford:
		return true
	if b_afford and not a_afford:
		return false
	return a.get("tier", 1) < b.get("tier", 1)

func _can_afford(recipe: Dictionary) -> bool:
	if not _resource_manager:
		return true
	var costs := CraftingUIUtils.get_recipe_costs(recipe)
	return _resource_manager.can_afford(costs)

func _populate_recipe_grid() -> void:
	if not _recipe_grid:
		return

	# Clear existing
	for child in _recipe_grid.get_children():
		child.queue_free()

	# Add cards
	for recipe in _filtered_recipes:
		var can_afford := _can_afford(recipe)
		var card := CraftingUIUtils.create_enhanced_recipe_card(
			recipe,
			can_afford,
			_on_craft_pressed,
			_resource_manager
		)
		_recipe_grid.add_child(card)

# ==============================================================================
# ACTIVE CRAFTS
# ==============================================================================

func _update_active_crafts() -> void:
	if not _active_crafts_container or not _current_node:
		return

	# Clear existing
	for child in _active_crafts_container.get_children():
		child.queue_free()

	# Get active crafts for this node
	var active_crafts: Array = []
	if _hex_grid_manager and _hex_grid_manager.has_method("get_active_crafts_for_node"):
		active_crafts = _hex_grid_manager.get_active_crafts_for_node(_current_node.id)

	if active_crafts.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active crafts"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", TEXT_MUTED)
		_active_crafts_container.add_child(empty_label)
		return

	for craft_data in active_crafts:
		_active_crafts_container.add_child(_create_active_craft_card(craft_data))

func _create_active_craft_card(craft_data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = Color(0.3, 0.25, 0.4, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Header row: name + cancel button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var task_data: Dictionary = craft_data.get("task_data", {})
	var task_name := task_data.get("name", "Unknown") as String
	var task_rarity := task_data.get("rarity", "common") as String

	var icon := CraftingUIUtils.get_recipe_icon(task_data)
	var name_label := Label.new()
	name_label.text = "%s %s" % [icon, CraftingUIUtils.truncate_name(task_name, 14)]
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", CraftingUIUtils.get_rarity_color(task_rarity))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var cancel_btn := Button.new()
	cancel_btn.text = "✗"
	cancel_btn.custom_minimum_size = Vector2(24, 24)
	cancel_btn.pressed.connect(_on_cancel_craft.bind(craft_data))
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.4, 0.2, 0.2, 0.8)
	cancel_style.set_corner_radius_all(3)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_font_size_override("font_size", 10)
	header.add_child(cancel_btn)

	# Progress bar
	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.max_value = 100
	progress_bar.show_percentage = false

	var now := int(Time.get_unix_time_from_system())
	var start_time := craft_data.get("start_time", now) as int
	var end_time := craft_data.get("end_time", now + 60) as int
	var total_duration := end_time - start_time
	var elapsed := now - start_time
	var progress := 100.0 if total_duration <= 0 else clampf((float(elapsed) / float(total_duration)) * 100.0, 0.0, 100.0)
	progress_bar.value = progress

	# Style progress bar with rarity color
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = PROGRESS_COLORS.get(task_rarity, PROGRESS_COLORS["common"])
	fill_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	bg_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(progress_bar)

	# Time remaining
	var time_remaining := maxi(0, end_time - now)
	var time_label := Label.new()
	if time_remaining <= 0:
		time_label.text = "Complete! Tap to collect"
		time_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		time_label.text = "⏱ %s remaining" % CraftingUIUtils.format_duration(time_remaining)
		time_label.add_theme_color_override("font_color", TEXT_MUTED)
	time_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(time_label)

	return card

# ==============================================================================
# CRAFT ACTIONS
# ==============================================================================

func _on_craft_pressed(task: Dictionary, _auto_repeat = null) -> void:
	if not _current_node or not _hex_grid_manager:
		return

	var task_id := task.get("id", "") as String
	if task_id.is_empty():
		return

	# Check if node has workers assigned (required for crafting)
	if _current_node.assigned_workers.is_empty():
		_show_error_message("Assign a worker to this forge first!")
		return

	# Check if node is at craft limit (from config)
	if _hex_grid_manager.has_method("get_active_crafts_for_node"):
		var active: Array = _hex_grid_manager.get_active_crafts_for_node(_current_node.id)
		var max_crafts: int = _get_max_crafts_for_tier(_current_node.tier)
		if active.size() >= max_crafts:
			_show_error_message("This forge already has max active crafts")
			return

	# Check and spend resources
	var costs := CraftingUIUtils.get_recipe_costs(task)
	if not costs.is_empty() and _resource_manager:
		if not _resource_manager.can_afford(costs):
			_show_error_message("Not enough resources!")
			return
		if not _resource_manager.spend_resources(costs):
			return

	# Start craft
	var success: bool = _hex_grid_manager.start_craft(_current_node.id, task_id, task, false)
	if success:
		craft_started.emit(_current_node, task_id)
		_update_active_crafts()
		_populate_recipe_grid()  # Refresh affordability
	else:
		_show_error_message("Could not start craft")

func _on_cancel_craft(craft_data: Dictionary) -> void:
	if not _current_node or not _hex_grid_manager:
		return

	var task_id := craft_data.get("task_id", "") as String
	if task_id.is_empty():
		return

	# Cancel and refund
	if _hex_grid_manager.has_method("cancel_craft"):
		_hex_grid_manager.cancel_craft(_current_node.id, task_id)
		craft_cancelled.emit(_current_node, task_id)
		_update_active_crafts()
		_populate_recipe_grid()

func _show_error_message(message: String) -> void:
	"""Show a temporary error message in the UI"""
	if not _popup or not is_instance_valid(_popup):
		return

	# Find or create error label
	var error_label: Label = _popup.get_node_or_null("ErrorLabel") as Label
	if not error_label:
		error_label = Label.new()
		error_label.name = "ErrorLabel"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.add_theme_font_size_override("font_size", 14)
		error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		error_label.z_index = 101
		error_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		error_label.position.y = 80
		_popup.add_child(error_label)

	error_label.text = message
	error_label.visible = true

	# Fade out after 2 seconds
	var tween: Tween = _popup.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(error_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): error_label.visible = false; error_label.modulate.a = 1.0)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_overlay_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
