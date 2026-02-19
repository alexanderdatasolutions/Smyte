class_name BattleResultOverlay
extends Control

"""
BattleResultOverlay.gd - Clean, compact battle result display
Shows victory/defeat, rating, and rewards in a polished format
"""

signal return_to_map_pressed
signal continue_pressed

# UI references
var _content_panel: Panel
var _result_label: Label
var _rating_label: Label
var _perfect_label: Label
var _rewards_grid: GridContainer
var _first_clear_container: VBoxContainer
var _loot_container: VBoxContainer
var _button_container: HBoxContainer
var _return_button: Button
var _continue_button: Button

# Battle result data (needed by BattleScreen for navigation)
var battle_result: BattleResult

# Animation
var _reveal_tween: Tween
var _animated_elements: Array = []

# Color palette (from UI_DESIGN_PATTERNS.md)
const COLOR_BG_DARK = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.98)
const COLOR_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_BORDER_VICTORY = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_BORDER_DEFEAT = Color(0.8, 0.3, 0.3, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.4, 0.9, 0.4)
const COLOR_DEFEAT = Color(1.0, 0.4, 0.4)
const COLOR_GOLD = Color(1.0, 0.85, 0.3)
const COLOR_REWARD_VALUE = Color(0.6, 0.9, 0.6)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_create_ui()

func _create_ui():
	# Dark overlay background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel - compact size
	_content_panel = Panel.new()
	_content_panel.custom_minimum_size = Vector2(420, 320)
	_style_panel(_content_panel, COLOR_BORDER)
	center.add_child(_content_panel)

	# Margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_content_panel.add_child(margin)

	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# === HEADER: Victory/Defeat + Rating ===
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 32)
	header.add_child(_result_label)

	_rating_label = Label.new()
	_rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_rating_label)

	_perfect_label = Label.new()
	_perfect_label.text = "PERFECT!"
	_perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect_label.add_theme_font_size_override("font_size", 14)
	_perfect_label.add_theme_color_override("font_color", COLOR_GOLD)
	_perfect_label.visible = false
	header.add_child(_perfect_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	vbox.add_child(sep)

	# === REWARDS SECTION (scrollable) ===
	var rewards_scroll = ScrollContainer.new()
	rewards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rewards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rewards_scroll.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(rewards_scroll)

	var rewards_vbox = VBoxContainer.new()
	rewards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_vbox.add_theme_constant_override("separation", 8)
	rewards_scroll.add_child(rewards_vbox)

	# Rewards header
	var rewards_header = Label.new()
	rewards_header.text = "REWARDS"
	rewards_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_header.add_theme_font_size_override("font_size", 16)
	rewards_header.add_theme_color_override("font_color", COLOR_GOLD)
	rewards_vbox.add_child(rewards_header)

	# 3-column rewards grid
	_rewards_grid = GridContainer.new()
	_rewards_grid.columns = 3
	_rewards_grid.add_theme_constant_override("h_separation", 16)
	_rewards_grid.add_theme_constant_override("v_separation", 6)
	_rewards_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rewards_vbox.add_child(_rewards_grid)

	# First clear bonus (hidden by default)
	_first_clear_container = VBoxContainer.new()
	_first_clear_container.add_theme_constant_override("separation", 4)
	_first_clear_container.visible = false
	rewards_vbox.add_child(_first_clear_container)

	# Loot container (hidden by default)
	_loot_container = VBoxContainer.new()
	_loot_container.add_theme_constant_override("separation", 4)
	rewards_vbox.add_child(_loot_container)

	# === BUTTONS ===
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_button_container)

	_return_button = Button.new()
	_return_button.text = "Close"
	_return_button.custom_minimum_size = Vector2(120, 36)
	_return_button.pressed.connect(_on_return_pressed)
	_style_button(_return_button, true)
	_button_container.add_child(_return_button)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(120, 36)
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.visible = false
	_style_button(_continue_button, false)
	_button_container.add_child(_continue_button)

func _style_panel(panel: Panel, border_color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool):
	var style = StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.2, 0.45, 0.3, 0.9)
		style.border_color = Color(0.3, 0.6, 0.4, 0.8)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = style.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed)

func show_result(result: BattleResult):
	battle_result = result  # Store for external access
	_animated_elements.clear()
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()

	# Update header
	if result.victory:
		_result_label.text = "VICTORY"
		_result_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_style_panel(_content_panel, COLOR_BORDER_VICTORY)
	else:
		_result_label.text = "DEFEAT"
		_result_label.add_theme_color_override("font_color", COLOR_DEFEAT)
		_style_panel(_content_panel, COLOR_BORDER_DEFEAT)

	# Rating
	var rating = result.get_efficiency_rating()
	_rating_label.text = "Rank: %s" % rating
	_rating_label.add_theme_color_override("font_color", _get_rating_color(rating))

	# Perfect victory
	_perfect_label.visible = result.is_perfect_victory()

	# Populate rewards
	_populate_rewards(result)
	_populate_first_clear(result)
	_populate_loot(result)

	visible = true
	_animate_reveal()

func _populate_rewards(result: BattleResult):
	# Clear grid
	for child in _rewards_grid.get_children():
		child.queue_free()

	# Collect all rewards (resources + experience)
	var all_rewards: Array = []

	# Add resource rewards (skip first_clear tagged ones)
	for resource_id in result.rewards:
		var is_first_clear = false
		for loot in result.loot_obtained:
			if loot.get("resource_id") == resource_id and loot.get("source") == "first_clear":
				is_first_clear = true
				break
		if not is_first_clear:
			all_rewards.append({
				"name": _format_resource_name(resource_id),
				"amount": result.rewards[resource_id],
				"color": _get_resource_color(resource_id)
			})

	# Add experience
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	for god_id in result.experience_gained:
		var exp_amount = result.experience_gained[god_id]
		var god_name = "God"
		if collection_manager:
			var god = collection_manager.get_god_by_id(god_id)
			if god:
				god_name = god.name
		all_rewards.append({
			"name": god_name + " XP",
			"amount": exp_amount,
			"color": Color(0.5, 0.9, 0.5)
		})

	# Create compact reward cells
	for reward in all_rewards:
		var cell = _create_reward_cell(str(reward.name), int(reward.amount), reward.color)
		cell.modulate.a = 0.0
		_rewards_grid.add_child(cell)
		_animated_elements.append(cell)

func _create_reward_cell(reward_name: String, amount: int, icon_color: Color) -> HBoxContainer:
	var cell = HBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)

	# Small color indicator
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(8, 8)
	icon.color = icon_color
	cell.add_child(icon)

	# Name + amount combined
	var label = Label.new()
	label.text = "%s +%s" % [reward_name, _format_number(amount)]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	cell.add_child(label)

	return cell

func _populate_first_clear(result: BattleResult):
	for child in _first_clear_container.get_children():
		child.queue_free()

	var first_clear_items: Array = []
	for item in result.loot_obtained:
		if item.get("source") == "first_clear":
			first_clear_items.append(item)

	if first_clear_items.is_empty():
		_first_clear_container.visible = false
		return

	_first_clear_container.visible = true
	_first_clear_container.modulate.a = 0.0
	_animated_elements.append(_first_clear_container)

	# Header
	var header = Label.new()
	header.text = "FIRST CLEAR BONUS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", COLOR_GOLD)
	_first_clear_container.add_child(header)

	# Grid for first clear rewards
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_first_clear_container.add_child(grid)

	for item in first_clear_items:
		var resource_id = item.get("resource_id", "unknown")
		var amount = item.get("amount", 0)
		var cell = _create_reward_cell(_format_resource_name(resource_id), amount, COLOR_GOLD)
		grid.add_child(cell)

func _populate_loot(result: BattleResult):
	for child in _loot_container.get_children():
		child.queue_free()

	var equipment_loot: Array = []
	for item in result.loot_obtained:
		if item.get("source") != "first_clear" and item.has("name"):
			equipment_loot.append(item)

	if equipment_loot.is_empty():
		return

	# Loot header
	var header = Label.new()
	header.text = "LOOT"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.6, 0.4, 0.9))
	header.modulate.a = 0.0
	_loot_container.add_child(header)
	_animated_elements.append(header)

	for item in equipment_loot:
		var loot_label = Label.new()
		loot_label.text = item.get("name", "Unknown")
		loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_label.add_theme_font_size_override("font_size", 13)
		loot_label.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
		loot_label.modulate.a = 0.0
		_loot_container.add_child(loot_label)
		_animated_elements.append(loot_label)

func _animate_reveal():
	modulate.a = 0.0
	_reveal_tween = create_tween()

	# Fade in overlay
	_reveal_tween.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_interval(0.15)

	# Reveal each element
	for element in _animated_elements:
		_reveal_tween.tween_property(element, "modulate:a", 1.0, 0.12).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_interval(0.05)

func hide_result():
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
	visible = false
	modulate.a = 1.0

func _on_return_pressed():
	return_to_map_pressed.emit()

func _on_continue_pressed():
	continue_pressed.emit()

func show_continue_button(should_show: bool = true):
	if _continue_button:
		_continue_button.visible = should_show

func _get_rating_color(rating: String) -> Color:
	match rating:
		"S": return Color(1.0, 0.85, 0.0)  # Gold
		"A": return Color(0.7, 0.4, 0.9)   # Purple
		"B": return Color(0.4, 0.6, 1.0)   # Blue
		"C": return Color(0.4, 0.9, 0.4)   # Green
		_: return COLOR_MUTED

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.4, 0.8, 0.4)
		"rare": return Color(0.4, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 0.9)
		"legendary": return Color(1.0, 0.8, 0.2)
		_: return COLOR_TEXT

func _get_resource_color(resource_id: String) -> Color:
	var id = resource_id.to_lower()
	if "mana" in id: return Color(0.3, 0.5, 1.0)
	if "crystal" in id: return Color(0.7, 0.4, 0.9)
	if "gold" in id: return Color(1.0, 0.85, 0.3)
	if "fire" in id: return Color(1.0, 0.4, 0.2)
	if "water" in id: return Color(0.3, 0.6, 1.0)
	if "earth" in id: return Color(0.6, 0.5, 0.3)
	if "lightning" in id: return Color(1.0, 0.9, 0.3)
	if "light" in id: return Color(1.0, 1.0, 0.7)
	if "dark" in id: return Color(0.5, 0.3, 0.6)
	return Color(0.6, 0.6, 0.6)

func _format_resource_name(resource_id: String) -> String:
	# Try to get proper display name from resources config
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		var resources_config = config_manager.get_resources_config()
		# Check all resource categories
		for category in resources_config:
			if category.begins_with("_"):
				continue
			var category_data = resources_config.get(category, {})
			if category_data is Dictionary and category_data.has(resource_id):
				var resource_data = category_data[resource_id]
				if resource_data is Dictionary:
					return resource_data.get("name", resource_id.replace("_", " ").capitalize())

	# Fallback to formatted ID
	return resource_id.replace("_", " ").capitalize()

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)
