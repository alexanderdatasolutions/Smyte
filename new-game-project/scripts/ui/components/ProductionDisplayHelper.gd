# scripts/ui/components/ProductionDisplayHelper.gd
# Handles production rate display in a compact tier-based grid
# Config-driven: loads resource icons from resources.json
extends RefCounted

const COLOR_TEXT := Color(0.75, 0.75, 0.8)
const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_GOLD := Color(0.95, 0.85, 0.5)
const COLOR_TIER_LABEL := Color(0.6, 0.55, 0.7)
const COLOR_CELL_BG := Color(0.12, 0.1, 0.16, 0.6)
const COLOR_CELL_BORDER := Color(0.25, 0.2, 0.35, 0.5)
const COLOR_ROW_CURRENCY := Color(0.2, 0.18, 0.12, 0.4)
const COLOR_ROW_ODD := Color(0.1, 0.08, 0.14, 0.3)
const COLOR_ROW_EVEN := Color(0.08, 0.06, 0.12, 0.3)

# Static config cache (shared across instances)
static var _resource_config: Dictionary = {}
static var _resource_config_loaded: bool = false

var _production_grid: Control = null
var _icon_lookup: Dictionary = {}

# Material types in display order
const MATERIAL_TYPES: Array = ["currency", "raw", "processed", "defense_drop", "flame", "divine"]
const TYPE_HEADERS: Dictionary = {
	"currency": "💰",
	"raw": "RAW",
	"processed": "PROC",
	"defense_drop": "DEF",
	"flame": "🔥",
	"divine": "✨"
}

func initialize(production_grid: Control) -> void:
	_production_grid = production_grid
	_build_icon_lookup()

static func _load_resource_config() -> void:
	if _resource_config_loaded:
		return
	_resource_config_loaded = true

	var file: FileAccess = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if not file:
		return
	var json_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		_resource_config = parsed as Dictionary

func _build_icon_lookup() -> void:
	_load_resource_config()

	var emoji_fallbacks: Dictionary = {
		"mana": "✦", "gold": "💰", "divine_crystals": "◆",
		"ore": "🪨", "wood": "🪵", "herbs": "🌿",
		"fine_ore": "⛏️", "hardwood": "🌳", "exotic_herbs": "🌺",
		"arcane_ore": "💜", "ancient_wood": "🌲", "mystic_herbs": "🔮",
		"celestial_ore": "⭐",
		"refined_metal": "⚙️", "quality_timber": "📐", "rare_herbs": "💊",
		"steel_ingot": "🔩", "treated_lumber": "🪓", "alchemical_extract": "⚗️",
		"prometheum": "🌋", "enchanted_wood": "✨", "mystic_bloom": "🌸",
		"astral_shard": "⭐", "divine_metal": "✨",
		"monster_parts": "🦴", "beast_scales": "🐉", "elemental_cores": "🔮", "dragon_parts": "🐲",
		"basic_flame": "🔥", "forging_flame": "🔥", "divine_flame": "🕯️", "eternal_flame": "🔥",
		"magic_crystals": "💎", "socket_crystal": "💠", "socket_crystals": "💎",
		"divine_essence": "🌟", "mana_crystals": "💠", "blessed_oil": "🛢️",
	}

	_icon_lookup = emoji_fallbacks.duplicate()

	for section_key: String in _resource_config:
		if section_key.begins_with("_"):
			continue
		var section: Variant = _resource_config[section_key]
		if section is Dictionary:
			for resource_id: String in section:
				if not resource_id.begins_with("_") and not _icon_lookup.has(resource_id):
					_icon_lookup[resource_id] = "📦"

func get_resource_icon(resource_id: String) -> String:
	return _icon_lookup.get(resource_id, "📦")

func format_number(value: float) -> String:
	var int_value: int = int(value)
	if int_value >= 1000000:
		return "%dM" % (int_value / 1000000)
	elif int_value >= 1000:
		return "%dK" % (int_value / 1000)
	return "%d" % int_value

func _get_resource_tier_and_type(resource_id: String) -> Dictionary:
	_load_resource_config()

	var currencies: Variant = _resource_config.get("currencies", {})
	if currencies is Dictionary and currencies.has(resource_id):
		return {"tier": 0, "type": "currency"}

	var crafting: Variant = _resource_config.get("crafting_materials", {})
	if crafting is Dictionary and crafting.has(resource_id):
		var def: Variant = crafting[resource_id]
		if def is Dictionary:
			return {
				"tier": int(def.get("tier", 1)),
				"type": str(def.get("material_type", "raw"))
			}

	var divine: Variant = _resource_config.get("divine_materials", {})
	if divine is Dictionary and divine.has(resource_id):
		return {"tier": 0, "type": "divine"}

	return {"tier": 0, "type": "other"}

# ==============================================================================
# MAIN UPDATE FUNCTION
# ==============================================================================

func update_production_display(cached_rates: Dictionary) -> void:
	if not _production_grid:
		return

	for child: Node in _production_grid.get_children():
		child.queue_free()

	if cached_rates.is_empty():
		var empty: Label = Label.new()
		empty.text = "No production - capture territory nodes!"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_production_grid.add_child(empty)
		return

	# Group resources by tier and type: {tier: {type: [{id, rate}]}}
	var tier_data: Dictionary = {}
	for resource_id: String in cached_rates:
		var rate: float = cached_rates[resource_id]
		if rate <= 0:
			continue
		var info: Dictionary = _get_resource_tier_and_type(resource_id)
		var tier: int = info.tier
		var mat_type: String = info.type
		if not tier_data.has(tier):
			tier_data[tier] = {}
		if not tier_data[tier].has(mat_type):
			tier_data[tier][mat_type] = []
		tier_data[tier][mat_type].append({"id": resource_id, "rate": rate})

	# Currency row (tier 0) - separate from grid since it spans all columns
	if tier_data.has(0):
		var curr_types: Dictionary = tier_data[0]
		var currency_resources: Array = curr_types.get("currency", []) + curr_types.get("divine", [])
		_add_currency_row(currency_resources)

	# Build the grid - 5 columns: TIER | RAW | PROC | DEF | FLAME
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_production_grid.add_child(grid)

	# Header row
	_add_header_cell(grid, "")
	_add_header_cell(grid, "Raw")
	_add_header_cell(grid, "Processed")
	_add_header_cell(grid, "Defense")
	_add_header_cell(grid, "Flame")

	# Tier rows (1-4) with alternating colors
	var row_idx: int = 0
	for tier: int in [1, 2, 3, 4]:
		if not tier_data.has(tier):
			continue
		var types: Dictionary = tier_data[tier]
		if types.is_empty():
			continue

		var row_color: Color = COLOR_ROW_ODD if row_idx % 2 == 0 else COLOR_ROW_EVEN
		row_idx += 1

		_add_tier_label(grid, "Tier %d" % tier, row_color)
		_add_resource_cell(grid, types.get("raw", []), 1, row_color)
		_add_resource_cell(grid, types.get("processed", []), 1, row_color)
		_add_resource_cell(grid, types.get("defense_drop", []), 1, row_color)
		_add_resource_cell(grid, types.get("flame", []), 1, row_color)

func _add_currency_row(resources: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_production_grid.add_child(row)

	# Label panel
	var label_panel: PanelContainer = PanelContainer.new()
	var label_style: StyleBoxFlat = StyleBoxFlat.new()
	label_style.bg_color = COLOR_ROW_CURRENCY
	label_style.border_color = COLOR_CELL_BORDER
	label_style.set_border_width_all(1)
	label_style.set_corner_radius_all(4)
	label_style.content_margin_left = 8
	label_style.content_margin_right = 8
	label_style.content_margin_top = 4
	label_style.content_margin_bottom = 4
	label_panel.add_theme_stylebox_override("panel", label_style)
	label_panel.custom_minimum_size.x = 80

	var label: Label = Label.new()
	label.text = "Currency"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TIER_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_panel.add_child(label)
	row.add_child(label_panel)

	# Resources panel - spans the rest
	var res_panel: PanelContainer = PanelContainer.new()
	res_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var res_style: StyleBoxFlat = StyleBoxFlat.new()
	res_style.bg_color = COLOR_ROW_CURRENCY
	res_style.border_color = COLOR_CELL_BORDER
	res_style.set_border_width_all(1)
	res_style.set_corner_radius_all(4)
	res_style.content_margin_left = 6
	res_style.content_margin_right = 6
	res_style.content_margin_top = 4
	res_style.content_margin_bottom = 4
	res_panel.add_theme_stylebox_override("panel", res_style)

	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override("separation", 16)
	res_panel.add_child(cell)

	if resources.is_empty():
		var dash: Label = Label.new()
		dash.text = "-"
		dash.add_theme_font_size_override("font_size", 16)
		dash.add_theme_color_override("font_color", COLOR_MUTED)
		cell.add_child(dash)
	else:
		resources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("rate", 0)) > float(b.get("rate", 0))
		)
		for res: Dictionary in resources:
			var res_id: String = str(res.get("id", ""))
			var rate: float = float(res.get("rate", 0))
			var pair: HBoxContainer = _create_compact_item(res_id, rate)
			cell.add_child(pair)

	row.add_child(res_panel)

func _add_header_cell(grid: GridContainer, text: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	style.border_color = Color(0.3, 0.25, 0.4, 0.6)
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TIER_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	grid.add_child(panel)

func _add_tier_label(grid: GridContainer, text: String, bg_color: Color = COLOR_CELL_BG) -> void:
	var panel: PanelContainer = PanelContainer.new()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = COLOR_CELL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 80

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TIER_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	grid.add_child(panel)

func _add_resource_cell(grid: GridContainer, resources: Array, span: int = 1, bg_color: Color = COLOR_CELL_BG) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = COLOR_CELL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override("separation", 12)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(cell)

	if resources.is_empty():
		var dash: Label = Label.new()
		dash.text = "-"
		dash.add_theme_font_size_override("font_size", 16)
		dash.add_theme_color_override("font_color", COLOR_MUTED)
		cell.add_child(dash)
	else:
		# Sort by rate descending
		resources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("rate", 0)) > float(b.get("rate", 0))
		)
		for res: Dictionary in resources:
			var res_id: String = str(res.get("id", ""))
			var rate: float = float(res.get("rate", 0))
			var pair: HBoxContainer = _create_compact_item(res_id, rate)
			cell.add_child(pair)

	grid.add_child(panel)

	# Add empty cells for span (GridContainer doesn't support colspan)
	for i: int in range(span - 1):
		var spacer: Control = Control.new()
		grid.add_child(spacer)

func _create_compact_item(resource_id: String, rate: float) -> HBoxContainer:
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 3)

	var tooltip: String = "%s: +%d/hr" % [resource_id.replace("_", " ").capitalize(), int(rate)]

	var icon: Label = Label.new()
	icon.text = get_resource_icon(resource_id)
	icon.add_theme_font_size_override("font_size", 16)
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	pair.add_child(icon)

	var rate_label: Label = Label.new()
	rate_label.text = "+%s" % format_number(rate)
	rate_label.add_theme_font_size_override("font_size", 14)
	rate_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	rate_label.tooltip_text = tooltip
	rate_label.mouse_filter = Control.MOUSE_FILTER_PASS
	pair.add_child(rate_label)

	return pair
