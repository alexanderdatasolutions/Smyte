# scripts/ui/components/ProductionDisplayHelper.gd
# Handles production rate, refiner, and accumulated resource grid displays
extends RefCounted

const COLOR_TEXT := Color(0.75, 0.75, 0.8)
const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_GOLD := Color(0.95, 0.85, 0.5)
const COLOR_REFINER := Color(0.8, 0.65, 0.4)

var _production_grid: GridContainer = null
var _refiner_grid: GridContainer = null
var _accumulated_grid: GridContainer = null
var _icon_lookup: Dictionary = {}

func initialize(production_grid: GridContainer, refiner_grid: GridContainer, accumulated_grid: GridContainer) -> void:
	_production_grid = production_grid
	_refiner_grid = refiner_grid
	_accumulated_grid = accumulated_grid
	_build_icon_lookup()

func _build_icon_lookup() -> void:
	_icon_lookup = {
		"mana": "✦", "gold": "💰", "ore": "🪨", "wood": "🪵",
		"herbs": "🌿", "monster_parts": "🦴", "enhancement_powder": "✨",
		"refined_metal": "⚙️", "socket_crystals": "💎", "divine_essence": "🌟",
		"mana_crystals": "💠", "divine_crystals": "✝️", "crystals": "◆",
		"fire_crystals": "🔥", "water_crystals": "💧", "earth_crystals": "🌍",
		"lightning_crystals": "⚡", "light_crystals": "☀️", "dark_crystals": "🌑",
		"fine_ore": "⛏️", "hardwood": "🌳", "exotic_herbs": "🌺",
		"beast_scales": "🐉", "quality_timber": "📐", "rare_herbs": "💊",
		"steel_ingot": "🔩", "treated_lumber": "🪓", "alchemical_extract": "⚗️",
		"arcane_ore": "💜", "ancient_wood": "🌲", "mystic_herbs": "🔮",
		"magic_crystals": "💎", "prometheum": "🌋", "enchanted_wood": "✨",
		"mystic_bloom": "🌸", "astral_shard": "⭐", "forging_flame": "🔥",
		"divine_flame": "🕯️", "socket_crystal": "💠", "common_soul": "👻",
		"blessed_oil": "🛢️"
	}

func get_resource_icon(resource_id: String) -> String:
	return _icon_lookup.get(resource_id, "📦")

func format_number(value: float) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	elif value >= 100:
		return "%d" % int(value)
	elif value >= 10:
		return "%.1f" % value
	else:
		return "%.2f" % value

# ==============================================================================
# PRODUCTION GRID
# ==============================================================================

func update_production_grid(cached_rates: Dictionary) -> void:
	if not _production_grid:
		return

	for child: Node in _production_grid.get_children():
		child.queue_free()

	if cached_rates.is_empty():
		var empty: Label = Label.new()
		empty.text = "No production"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_production_grid.columns = 1
		_production_grid.add_child(empty)
		return

	_production_grid.columns = 6  # 3 pairs per row

	var sorted_resources: Array = cached_rates.keys()
	sorted_resources.sort_custom(func(a: String, b: String) -> bool: return cached_rates[a] > cached_rates[b])

	for resource_id: String in sorted_resources:
		var rate: float = cached_rates[resource_id]
		if rate <= 0:
			continue

		var items: Array = _create_rate_item(resource_id, rate)
		for item: Node in items:
			_production_grid.add_child(item)

# ==============================================================================
# REFINER GRID
# ==============================================================================

func update_refiner_grid(cached_conversions: Array) -> void:
	if not _refiner_grid:
		return

	for child: Node in _refiner_grid.get_children():
		child.queue_free()

	if cached_conversions.is_empty():
		var empty: Label = Label.new()
		empty.text = "No refiners"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_refiner_grid.columns = 1
		_refiner_grid.add_child(empty)
		return

	_refiner_grid.columns = 6  # 3 pairs per row

	for conversion: Dictionary in cached_conversions:
		var items: Array = _create_conversion_item(conversion)
		for item: Node in items:
			_refiner_grid.add_child(item)

# ==============================================================================
# ACCUMULATED GRID
# ==============================================================================

func update_accumulated_grid(cached_accumulated: Dictionary) -> void:
	if not _accumulated_grid:
		return

	for child: Node in _accumulated_grid.get_children():
		child.queue_free()

	if cached_accumulated.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nothing ready"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_accumulated_grid.columns = 1
		_accumulated_grid.add_child(empty)
		return

	_accumulated_grid.columns = 6  # 3 pairs per row

	var sorted_resources: Array = cached_accumulated.keys()
	sorted_resources.sort_custom(func(a: String, b: String) -> bool: return cached_accumulated[a] > cached_accumulated[b])

	for resource_id: String in sorted_resources:
		var amount: float = cached_accumulated[resource_id]
		if amount < 0.1:
			continue

		var items: Array = _create_accumulated_item(resource_id, amount)
		for item: Node in items:
			_accumulated_grid.add_child(item)

# ==============================================================================
# ITEM CREATORS
# ==============================================================================

func _create_rate_item(resource_id: String, rate: float) -> Array:
	var tooltip: String = "%s: +%.1f per hour" % [resource_id.replace("_", " ").capitalize(), rate]

	var icon: Label = Label.new()
	icon.text = get_resource_icon(resource_id)
	icon.add_theme_font_size_override("font_size", 11)
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS

	var rate_label: Label = Label.new()
	rate_label.text = "+%s" % format_number(rate)
	rate_label.add_theme_font_size_override("font_size", 10)
	rate_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	rate_label.tooltip_text = tooltip
	rate_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icon, rate_label]

func _create_conversion_item(conversion: Dictionary) -> Array:
	var input_str: String = ""
	var consumes: Dictionary = conversion.get("consumes", {})
	for res_id: String in consumes:
		input_str += "%d %s, " % [consumes[res_id], res_id.replace("_", " ")]
	input_str = input_str.trim_suffix(", ")

	var output_str: String = ""
	var produces: Dictionary = conversion.get("produces", {})
	for res_id: String in produces:
		output_str += "%d %s, " % [produces[res_id], res_id.replace("_", " ")]
	output_str = output_str.trim_suffix(", ")

	var tooltip: String = "%s\nConverts: %s/hr\nProduces: %s/hr" % [conversion.get("name", ""), input_str, output_str]

	var first_input: String = consumes.keys()[0] if not consumes.is_empty() else ""
	var first_output: String = produces.keys()[0] if not produces.is_empty() else ""
	var output_rate: float = produces.get(first_output, 0)

	var icons_label: Label = Label.new()
	icons_label.text = "%s→%s" % [get_resource_icon(first_input), get_resource_icon(first_output)]
	icons_label.add_theme_font_size_override("font_size", 10)
	icons_label.tooltip_text = tooltip
	icons_label.mouse_filter = Control.MOUSE_FILTER_PASS

	var rate_label: Label = Label.new()
	rate_label.text = "+%s" % format_number(output_rate)
	rate_label.add_theme_font_size_override("font_size", 10)
	rate_label.add_theme_color_override("font_color", COLOR_REFINER)
	rate_label.tooltip_text = tooltip
	rate_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icons_label, rate_label]

func _create_accumulated_item(resource_id: String, amount: float) -> Array:
	var tooltip: String = "%s: %.1f ready to collect" % [resource_id.replace("_", " ").capitalize(), amount]

	var icon: Label = Label.new()
	icon.text = get_resource_icon(resource_id)
	icon.add_theme_font_size_override("font_size", 11)
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS

	var amount_label: Label = Label.new()
	amount_label.text = format_number(amount)
	amount_label.add_theme_font_size_override("font_size", 10)
	amount_label.add_theme_color_override("font_color", COLOR_GOLD)
	amount_label.tooltip_text = tooltip
	amount_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icon, amount_label]
