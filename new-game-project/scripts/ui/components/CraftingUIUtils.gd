# scripts/ui/components/CraftingUIUtils.gd
# Shared utilities for crafting UI - used by TerritoryOverviewScreen and NodeInfoPanel
class_name CraftingUIUtils
extends RefCounted

# ==============================================================================
# RARITY COLORS
# ==============================================================================
const RARITY_COLORS = {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.4, 0.8, 0.4),
	"rare": Color(0.4, 0.6, 0.9),
	"epic": Color(0.7, 0.4, 0.9),
	"legendary": Color(1.0, 0.7, 0.2)
}

# ==============================================================================
# RESOURCE NAME MAPPINGS
# ==============================================================================

## Full resource name lookup - maps resource IDs to their proper display names
const RESOURCE_FULL_NAMES = {
	# Currencies
	"mana": "Mana",
	"gold": "Gold",
	"divine_crystals": "Divine Crystals",
	"energy": "Energy",
	# T1 Raw
	"ore": "Ore",
	"wood": "Wood",
	"herbs": "Herbs",
	# T1 Processed
	"refined_metal": "Refined Metal",
	"quality_timber": "Quality Timber",
	"rare_herbs": "Rare Herbs",
	"monster_parts": "Monster Parts",
	"basic_flame": "Basic Flame",
	# T2 Raw
	"fine_ore": "Fine Ore",
	"hardwood": "Hardwood",
	"exotic_herbs": "Exotic Herbs",
	# T2 Processed
	"steel_ingot": "Steel Ingot",
	"treated_lumber": "Treated Lumber",
	"alchemical_extract": "Alchemical Extract",
	"beast_scales": "Beast Scales",
	"forging_flame": "Forging Flame",
	# T3 Raw
	"arcane_ore": "Arcane Ore",
	"ancient_wood": "Ancient Wood",
	"mystic_herbs": "Mystic Herbs",
	"magic_crystals": "Magic Crystals",
	# T3 Processed
	"prometheum": "Prometheum",
	"enchanted_wood": "Enchanted Wood",
	"mystic_bloom": "Mystic Bloom",
	"astral_shard": "Astral Shard",
	"elemental_cores": "Elemental Cores",
	"divine_flame": "Divine Flame",
	"mana_crystals": "Mana Crystals",
	# T4
	"celestial_ore": "Celestial Ore",
	"divine_metal": "Divine Metal",
	"divine_essence": "Divine Essence",
	"dragon_parts": "Dragon Parts",
	"eternal_flame": "Eternal Flame"
}

static func get_full_resource_name(resource_id: String) -> String:
	"""Get full resource name for display (matches resources.json names)"""
	if RESOURCE_FULL_NAMES.has(resource_id):
		return RESOURCE_FULL_NAMES[resource_id]
	# Fallback: capitalize and replace underscores
	return resource_id.replace("_", " ").capitalize()

static func get_short_resource_name(resource_id: String) -> String:
	"""Get shortened resource name for very compact display (use get_full_resource_name for normal display)"""
	match resource_id:
		# T1 Raw
		"ore": return "Ore"
		"wood": return "Wood"
		"herbs": return "Herbs"
		# T1 Processed
		"refined_metal": return "R.Metal"
		"quality_timber": return "Q.Timber"
		"rare_herbs": return "R.Herbs"
		"monster_parts": return "M.Parts"
		"basic_flame": return "B.Flame"
		# T2 Raw
		"fine_ore": return "F.Ore"
		"hardwood": return "Hardwood"
		"exotic_herbs": return "Ex.Herbs"
		# T2 Processed
		"steel_ingot": return "Steel"
		"treated_lumber": return "T.Lumber"
		"alchemical_extract": return "Extract"
		"beast_scales": return "Scales"
		"forging_flame": return "F.Flame"
		# T3 Raw
		"arcane_ore": return "Arc.Ore"
		"ancient_wood": return "Anc.Wood"
		"mystic_herbs": return "Mys.Herbs"
		"magic_crystals": return "M.Crystal"
		# T3 Processed
		"prometheum": return "Prome."
		"enchanted_wood": return "Enc.Wood"
		"mystic_bloom": return "M.Bloom"
		"astral_shard": return "A.Shard"
		"elemental_cores": return "E.Cores"
		"divine_flame": return "D.Flame"
		# T4
		"celestial_ore": return "Cel.Ore"
		"divine_metal": return "D.Metal"
		"divine_essence": return "D.Essence"
		# Other
		"mana": return "Mana"
		"gold": return "Gold"
		_: return resource_id.replace("_", " ").substr(0, 8)

# ==============================================================================
# FORMATTING FUNCTIONS
# ==============================================================================
static func format_conversion_display(costs: Dictionary, output: Dictionary) -> String:
	"""Format conversion as 'Input x50 → Output x10'"""
	var input_parts: Array = []
	var output_parts: Array = []

	for resource_id in costs.keys():
		var amount = costs[resource_id]
		var name = get_full_resource_name(resource_id)
		input_parts.append("%s x%d" % [name, amount])

	for resource_id in output.keys():
		var amount = output[resource_id]
		var name = get_full_resource_name(resource_id)
		output_parts.append("%s x%d" % [name, amount])

	var input_str = ", ".join(input_parts) if not input_parts.is_empty() else "?"
	var output_str = ", ".join(output_parts) if not output_parts.is_empty() else "?"

	return "%s → %s" % [input_str, output_str]

static func format_costs_compact(costs: Dictionary, can_afford: bool) -> String:
	"""Format costs in compact form with check marks - uses full resource names"""
	if costs.is_empty():
		return "Free"

	var parts: Array = []
	for resource_id in costs.keys():
		var amount = costs[resource_id]
		var name = get_full_resource_name(resource_id)
		parts.append("%s: %d" % [name, amount])

	var prefix = "✓ " if can_afford else "✗ "
	return prefix + ", ".join(parts)

static func format_costs_with_check(costs: Dictionary, resource_manager) -> String:
	"""Format costs with per-resource ✓/✗ indicators - uses full resource names"""
	if costs.is_empty():
		return "Free"

	var parts: Array = []
	for resource_id in costs.keys():
		var required = costs[resource_id]
		var has_enough = true
		if resource_manager:
			var current = resource_manager.get_resource(resource_id)
			has_enough = current >= required
		var name = get_full_resource_name(resource_id)
		var indicator = "✓" if has_enough else "✗"
		parts.append("%s %s: %d" % [indicator, name, required])

	return ", ".join(parts)

static func format_duration(seconds: int) -> String:
	"""Format duration in human-readable form"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		var mins = seconds / 60
		var secs = seconds % 60
		if secs > 0:
			return "%dm %ds" % [mins, secs]
		return "%dm" % mins
	else:
		var hours = seconds / 3600
		var mins = (seconds % 3600) / 60
		if mins > 0:
			return "%dh %dm" % [hours, mins]
		return "%dh" % hours

# ==============================================================================
# RARITY HELPERS
# ==============================================================================
static func get_rarity_color(rarity: String) -> Color:
	"""Get color for rarity tier"""
	return RARITY_COLORS.get(rarity, Color(0.6, 0.6, 0.6))

static func get_rarity_short(rarity: String) -> String:
	"""Get short display name for rarity"""
	match rarity:
		"common": return "C"
		"uncommon": return "U"
		"rare": return "R"
		"epic": return "E"
		"legendary": return "L"
		_: return "?"

# ==============================================================================
# RECIPE TYPE HELPERS
# ==============================================================================
static func is_conversion_recipe(task: Dictionary) -> bool:
	"""Check if recipe is a conversion type"""
	return task.get("recipe_type", "equipment") == "conversion"

static func get_recipe_icon(task: Dictionary) -> String:
	"""Get appropriate icon for recipe type"""
	if is_conversion_recipe(task):
		return "🔄"

	var equip_type = task.get("equipment_type", "weapon")
	match equip_type:
		"weapon": return "⚔️"
		"armor": return "🛡️"
		"accessory": return "💍"
		"boots": return "👢"
		"helmet": return "⛑️"
		_: return "📦"

static func get_recipe_costs(task: Dictionary) -> Dictionary:
	"""Get costs from recipe - handles both 'materials' and 'resource_costs' keys"""
	return task.get("materials", task.get("resource_costs", {}))

static func truncate_name(name: String, max_length: int = 20) -> String:
	"""Truncate name if too long"""
	if name.length() > max_length:
		return name.substr(0, max_length - 2) + ".."
	return name

# ==============================================================================
# UNIFIED RECIPE CARD BUILDER
# ==============================================================================

## Creates a unified recipe card for use in grids (3-4 columns)
## Layout:
##   ┌─────────────────────────┐
##   │ 🔄 Refine Ore      [T1] │
##   │ Ore x50 → Metal x10     │
##   │        [Craft]          │
##   └─────────────────────────┘
static func create_recipe_card(
	task: Dictionary,
	can_afford: bool,
	on_craft_pressed: Callable = Callable(),
	show_auto_repeat: bool = false,
	resource_manager = null  # Optional: pass to show have/need amounts
) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Get recipe info
	var is_conversion = is_conversion_recipe(task)
	var task_rarity = task.get("rarity", "common")
	var border_color = get_rarity_color(task_rarity) if not is_conversion else Color(0.4, 0.6, 0.5)
	var costs = get_recipe_costs(task)
	var tier = task.get("tier", task.get("territory_tier_requirement", 1))

	# Card style
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.1, 0.16, 0.95) if can_afford else Color(0.15, 0.1, 0.1, 0.95)
	card_style.border_color = border_color if can_afford else border_color.darkened(0.4)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(6)
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Row 1: Icon + Name + Tier badge
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	# Icon
	var icon_label = Label.new()
	icon_label.text = get_recipe_icon(task)
	icon_label.add_theme_font_size_override("font_size", 16)
	header_row.add_child(icon_label)

	# Name
	var name_label = Label.new()
	name_label.text = truncate_name(task.get("name", "Unknown"), 14)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95) if can_afford else Color(0.5, 0.5, 0.55))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_label)

	# Tier badge
	var tier_label = Label.new()
	if is_conversion:
		tier_label.text = "T%d" % tier
		tier_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6))
	else:
		tier_label.text = get_rarity_short(task_rarity)
		tier_label.add_theme_color_override("font_color", border_color)
	tier_label.add_theme_font_size_override("font_size", 11)
	header_row.add_child(tier_label)

	# Row 2: Conversion display OR cost summary
	var info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_conversion:
		var output = task.get("output", {})
		info_label.text = format_conversion_display(costs, output)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6) if can_afford else Color(0.4, 0.5, 0.4))
	else:
		# Show detailed have/need when can't afford and resource_manager available
		if not can_afford and resource_manager:
			info_label.text = format_costs_with_check(costs, resource_manager)
		else:
			info_label.text = format_costs_compact(costs, can_afford)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9) if can_afford else Color(0.5, 0.5, 0.55))
	vbox.add_child(info_label)

	# Row 3: Auto-repeat (optional) + Craft button
	var bottom_row = HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_row)

	var auto_repeat_check: CheckButton = null
	if show_auto_repeat and is_conversion and can_afford:
		auto_repeat_check = CheckButton.new()
		auto_repeat_check.text = "x∞"
		auto_repeat_check.add_theme_font_size_override("font_size", 10)
		auto_repeat_check.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		bottom_row.add_child(auto_repeat_check)

	# Craft button
	var craft_btn = Button.new()
	craft_btn.text = "Craft" if can_afford else "✗"
	craft_btn.custom_minimum_size = Vector2(70, 26)
	craft_btn.disabled = not can_afford
	craft_btn.add_theme_font_size_override("font_size", 11)

	var btn_style = StyleBoxFlat.new()
	if can_afford:
		btn_style.bg_color = Color(0.25, 0.45, 0.3, 0.95)
		btn_style.border_color = Color(0.35, 0.6, 0.4, 0.9)
		craft_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	else:
		btn_style.bg_color = Color(0.2, 0.15, 0.15, 0.8)
		btn_style.border_color = Color(0.35, 0.25, 0.25, 0.7)
		craft_btn.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	craft_btn.add_theme_stylebox_override("normal", btn_style)
	craft_btn.add_theme_stylebox_override("disabled", btn_style)

	if can_afford:
		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0.3, 0.55, 0.35, 1)
		craft_btn.add_theme_stylebox_override("hover", btn_hover)

	if on_craft_pressed.is_valid() and can_afford:
		craft_btn.pressed.connect(func(): on_craft_pressed.call(task, auto_repeat_check))

	bottom_row.add_child(craft_btn)

	# Store task data on card for reference
	card.set_meta("task", task)
	card.set_meta("can_afford", can_afford)

	return card

## Creates a grid container for recipe cards (3-4 columns based on width)
static func create_recipe_grid(columns: int = 3) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid
