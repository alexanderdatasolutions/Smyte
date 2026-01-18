class_name BattleResultOverlay
extends Control

"""
BattleResultOverlay.gd - Displays battle result with rewards and navigation
RULE 2: Single responsibility - ONLY displays battle result UI
RULE 4: No logic in UI - just displays BattleResult data
RULE 5: Uses SystemRegistry for navigation

Shows:
- Victory/Defeat banner with rating
- Rewards earned (resources, experience, loot)
- Battle statistics summary
- Return to Map button for navigation
"""

# Signals for navigation
signal return_to_map_pressed
signal continue_pressed

# References to child nodes (will be created in _create_ui)
var background_panel: Panel
var result_container: VBoxContainer
var result_label: Label
var rating_label: Label
var stats_container: VBoxContainer
var rewards_container: VBoxContainer
var rewards_title: Label
var loot_container: VBoxContainer
var button_container: HBoxContainer
var return_button: Button
var continue_button: Button

# Battle result data
var battle_result: BattleResult

# Animation tracking
var _reward_rows: Array = []
var _loot_rows: Array = []
var _first_clear_container: VBoxContainer
var _reveal_tween: Tween
var _is_animating: bool = false

func _ready():
	# Set up as fullscreen container for centering
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Start hidden
	visible = false

	# Create UI structure
	_create_ui()

func _create_ui():
	"""Create the overlay UI structure"""
	# Semi-transparent dark background
	background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Create dark semi-transparent style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
	background_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(background_panel)

	# Main content container - centered
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block background clicks
	add_child(center_container)

	# Content panel with border - this will be centered by CenterContainer
	var content_panel = Panel.new()
	content_panel.custom_minimum_size = Vector2(500, 450)
	content_panel.size = Vector2(500, 450)  # Force the size

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	content_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(content_panel)

	# Result container inside content panel
	result_container = VBoxContainer.new()
	result_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_container.add_theme_constant_override("separation", 15)

	# Add margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	content_panel.add_child(margin)
	margin.add_child(result_container)

	# Victory/Defeat label
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 36)
	result_container.add_child(result_label)

	# Rating label (S, A, B, C, D)
	rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 48)
	result_container.add_child(rating_label)

	# Separator
	var sep1 = HSeparator.new()
	result_container.add_child(sep1)

	# Stats container
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 5)
	result_container.add_child(stats_container)

	# Separator
	var sep2 = HSeparator.new()
	result_container.add_child(sep2)

	# Rewards title
	rewards_title = Label.new()
	rewards_title.text = "REWARDS"
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_title.add_theme_font_size_override("font_size", 20)
	rewards_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	result_container.add_child(rewards_title)

	# Rewards container
	rewards_container = VBoxContainer.new()
	rewards_container.add_theme_constant_override("separation", 5)
	result_container.add_child(rewards_container)

	# First clear bonus container (special section)
	_first_clear_container = VBoxContainer.new()
	_first_clear_container.add_theme_constant_override("separation", 5)
	_first_clear_container.visible = false  # Hidden until first clear
	result_container.add_child(_first_clear_container)

	# Loot container (for equipment/items)
	loot_container = VBoxContainer.new()
	loot_container.add_theme_constant_override("separation", 5)
	result_container.add_child(loot_container)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_container.add_child(spacer)

	# Button container
	button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	result_container.add_child(button_container)

	# Return to Map button
	return_button = Button.new()
	return_button.text = "Return to Map"
	return_button.custom_minimum_size = Vector2(150, 40)
	return_button.pressed.connect(_on_return_pressed)
	button_container.add_child(return_button)

	# Continue button (for multi-stage battles or replaying)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 40)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false  # Hidden by default
	button_container.add_child(continue_button)

func show_result(result: BattleResult):
	"""Display the battle result overlay"""
	battle_result = result

	# Reset animation state
	_reward_rows.clear()
	_loot_rows.clear()
	_is_animating = false
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()

	# Update victory/defeat display
	if result.victory:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))

		# Change panel border to gold for victory
		var panel = background_panel.get_parent().get_child(1).get_child(0)  # Get content panel
		if panel is Panel:
			var style = panel.get_theme_stylebox("panel").duplicate()
			if style is StyleBoxFlat:
				style.border_color = Color(1.0, 0.85, 0.3, 1.0)
				panel.add_theme_stylebox_override("panel", style)
	else:
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))

	# Update rating display
	var rating = result.get_efficiency_rating()
	rating_label.text = "Rank: %s" % rating

	# Color rating based on grade
	var rating_color = _get_rating_color(rating)
	rating_label.add_theme_color_override("font_color", rating_color)

	# Update stats
	_populate_stats(result)

	# Prepare rewards (hidden initially for animation)
	_prepare_rewards(result)

	# Prepare first-clear bonus section
	_prepare_first_clear_bonus(result)

	# Prepare loot
	_prepare_loot(result)

	# Show the overlay
	visible = true

	# Play animation - fade in overlay then reveal rewards sequentially
	_animate_show_with_rewards()

func _get_rating_color(rating: String) -> Color:
	"""Get color for efficiency rating"""
	match rating:
		"S":
			return Color(1.0, 0.85, 0.0, 1.0)  # Gold
		"A":
			return Color(0.6, 0.3, 1.0, 1.0)  # Purple
		"B":
			return Color(0.3, 0.6, 1.0, 1.0)  # Blue
		"C":
			return Color(0.3, 1.0, 0.3, 1.0)  # Green
		_:
			return Color(0.6, 0.6, 0.6, 1.0)  # Gray

func _populate_stats(result: BattleResult):
	"""Populate battle statistics"""
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()

	# Add stat rows
	_add_stat_row("Duration", result.get_duration_string())
	_add_stat_row("Turns", str(result.turns_taken))
	_add_stat_row("Damage Dealt", str(result.damage_dealt))
	_add_stat_row("Damage Received", str(result.damage_received))

	if result.is_perfect_victory():
		var perfect_label = Label.new()
		perfect_label.text = "PERFECT VICTORY!"
		perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perfect_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		perfect_label.add_theme_font_size_override("font_size", 16)
		stats_container.add_child(perfect_label)

func _add_stat_row(stat_name: String, stat_value: String):
	"""Add a stat row to the stats container"""
	var row = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	row.add_child(name_label)

	var value_label = Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	row.add_child(value_label)

	stats_container.add_child(row)

func _prepare_rewards(result: BattleResult):
	"""Prepare rewards for animated reveal (hidden initially)"""
	# Clear existing
	for child in rewards_container.get_children():
		child.queue_free()
	_reward_rows.clear()

	# Filter out first_clear rewards - they go in the special section
	var normal_rewards: Dictionary = {}
	for resource_id in result.rewards:
		# Check if this is a first-clear reward by checking loot_obtained
		var is_first_clear = false
		for loot_item in result.loot_obtained:
			if loot_item.get("resource_id") == resource_id and loot_item.get("source") == "first_clear":
				is_first_clear = true
				break
		if not is_first_clear:
			normal_rewards[resource_id] = result.rewards[resource_id]

	if normal_rewards.is_empty() and result.experience_gained.is_empty():
		rewards_title.visible = false
		return

	rewards_title.visible = true
	rewards_title.modulate.a = 0.0  # Start hidden for animation

	for resource_id in normal_rewards:
		var amount = normal_rewards[resource_id]
		var row = _create_reward_row(resource_id, amount)
		row.modulate.a = 0.0  # Start hidden
		rewards_container.add_child(row)
		_reward_rows.append(row)

	# Add experience gained
	for god_id in result.experience_gained:
		var exp_amount = result.experience_gained[god_id]
		var row = _create_reward_row("EXP (%s)" % god_id, exp_amount)
		row.modulate.a = 0.0  # Start hidden
		rewards_container.add_child(row)
		_reward_rows.append(row)

func _create_reward_row(reward_name: String, amount: int, rarity: String = "common") -> HBoxContainer:
	"""Create a reward row with optional rarity for glow effect"""
	var row = HBoxContainer.new()

	# Resource icon placeholder (small colored square based on type)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.color = _get_resource_icon_color(reward_name)
	row.add_child(icon)

	# Small spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	row.add_child(spacer)

	var name_label = Label.new()
	name_label.text = _format_resource_name(reward_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	row.add_child(name_label)

	var amount_label = Label.new()
	amount_label.text = "+%d" % amount
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	row.add_child(amount_label)

	# Apply glow effect for rare+ items
	if rarity in ["rare", "epic", "legendary", "mythic"]:
		_apply_glow_effect(row, rarity)

	return row

func _get_resource_icon_color(resource_name: String) -> Color:
	"""Get icon color based on resource type"""
	var name_lower = resource_name.to_lower()
	if "mana" in name_lower:
		return Color(0.3, 0.5, 1.0, 1.0)  # Blue
	elif "crystal" in name_lower:
		return Color(0.8, 0.3, 0.9, 1.0)  # Purple
	elif "fire" in name_lower:
		return Color(1.0, 0.4, 0.2, 1.0)  # Orange
	elif "water" in name_lower:
		return Color(0.2, 0.6, 1.0, 1.0)  # Light blue
	elif "earth" in name_lower:
		return Color(0.6, 0.4, 0.2, 1.0)  # Brown
	elif "lightning" in name_lower:
		return Color(1.0, 1.0, 0.3, 1.0)  # Yellow
	elif "light" in name_lower:
		return Color(1.0, 1.0, 0.8, 1.0)  # Light yellow
	elif "dark" in name_lower:
		return Color(0.4, 0.2, 0.5, 1.0)  # Dark purple
	elif "exp" in name_lower:
		return Color(0.3, 1.0, 0.3, 1.0)  # Green
	elif "magic" in name_lower:
		return Color(0.5, 0.3, 1.0, 1.0)  # Violet
	else:
		return Color(0.7, 0.7, 0.7, 1.0)  # Gray

func _apply_glow_effect(row: Control, rarity: String):
	"""Apply a subtle glow effect to rare+ items"""
	var glow_color: Color
	match rarity:
		"rare":
			glow_color = Color(0.3, 0.6, 1.0, 0.3)  # Blue glow
		"epic":
			glow_color = Color(0.6, 0.3, 1.0, 0.3)  # Purple glow
		"legendary":
			glow_color = Color(1.0, 0.6, 0.0, 0.3)  # Orange glow
		"mythic":
			glow_color = Color(1.0, 0.3, 0.3, 0.3)  # Red glow
		_:
			return

	# Add glow background
	var glow_bg = Panel.new()
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = glow_color
	glow_style.corner_radius_top_left = 4
	glow_style.corner_radius_top_right = 4
	glow_style.corner_radius_bottom_left = 4
	glow_style.corner_radius_bottom_right = 4
	glow_bg.add_theme_stylebox_override("panel", glow_style)
	glow_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_bg.z_index = -1
	row.add_child(glow_bg)
	row.move_child(glow_bg, 0)  # Move to back

func _format_resource_name(resource_id: String) -> String:
	"""Format resource ID to display name"""
	return resource_id.replace("_", " ").capitalize()

func _prepare_first_clear_bonus(result: BattleResult):
	"""Prepare first-clear bonus section with special header"""
	# Clear existing
	for child in _first_clear_container.get_children():
		child.queue_free()

	# Find first-clear rewards from loot_obtained
	var first_clear_items: Array = []
	for item in result.loot_obtained:
		if item.get("source") == "first_clear":
			first_clear_items.append(item)

	if first_clear_items.is_empty():
		_first_clear_container.visible = false
		return

	_first_clear_container.visible = true
	_first_clear_container.modulate.a = 0.0  # Start hidden for animation

	# Create special "FIRST CLEAR BONUS!" header
	var bonus_header = Label.new()
	bonus_header.text = "🏆 FIRST CLEAR BONUS! 🏆"
	bonus_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_header.add_theme_font_size_override("font_size", 20)
	bonus_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))  # Gold
	_first_clear_container.add_child(bonus_header)

	# Add first-clear reward rows
	for item in first_clear_items:
		var resource_id = item.get("resource_id", "unknown")
		var amount = item.get("amount", 0)
		var row = _create_reward_row(resource_id, amount, "legendary")  # Gold glow for first clear
		_first_clear_container.add_child(row)

func _prepare_loot(result: BattleResult):
	"""Prepare loot items for animated reveal"""
	# Clear existing
	for child in loot_container.get_children():
		child.queue_free()
	_loot_rows.clear()

	# Filter to only equipment/item loot (not resources which go in rewards)
	var equipment_loot: Array = []
	for item in result.loot_obtained:
		# Only show items that are actual equipment, not resource materials
		if item.get("source") != "first_clear" and item.has("name"):
			equipment_loot.append(item)

	if equipment_loot.is_empty():
		return

	# Loot title
	var loot_title = Label.new()
	loot_title.text = "LOOT"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 18)
	loot_title.add_theme_color_override("font_color", Color(0.6, 0.3, 1.0, 1.0))
	loot_title.modulate.a = 0.0  # Start hidden
	loot_container.add_child(loot_title)
	_loot_rows.append(loot_title)

	for item in equipment_loot:
		var item_name = item.get("name", "Unknown Item")
		var item_rarity = item.get("rarity", "common")

		var item_label = Label.new()
		item_label.text = item_name
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_color_override("font_color", _get_rarity_color(item_rarity))
		item_label.modulate.a = 0.0  # Start hidden
		loot_container.add_child(item_label)
		_loot_rows.append(item_label)

		# Apply glow effect for rare+ loot
		if item_rarity in ["rare", "epic", "legendary", "mythic"]:
			_apply_glow_effect(item_label, item_rarity)

func _get_rarity_color(rarity: String) -> Color:
	"""Get color for item rarity"""
	match rarity.to_lower():
		"common":
			return Color(0.8, 0.8, 0.8, 1.0)
		"uncommon":
			return Color(0.3, 1.0, 0.3, 1.0)
		"rare":
			return Color(0.3, 0.6, 1.0, 1.0)
		"epic":
			return Color(0.6, 0.3, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.6, 0.0, 1.0)
		"mythic":
			return Color(1.0, 0.3, 0.3, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

func _animate_show_with_rewards():
	"""Animate the overlay appearing, then reveal rewards sequentially"""
	_is_animating = true
	modulate.a = 0.0

	# Kill any existing tween
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()

	_reveal_tween = create_tween()

	# Step 1: Fade in overlay (0.3s)
	_reveal_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Step 2: Brief pause before rewards
	_reveal_tween.tween_interval(0.2)

	# Step 3: Fade in rewards title
	if rewards_title.visible:
		_reveal_tween.tween_property(rewards_title, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)

	# Step 4: Reveal each reward row sequentially (100ms delay each)
	for row in _reward_rows:
		_reveal_tween.tween_property(row, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_interval(0.1)  # 100ms delay between each

	# Step 5: Reveal first-clear bonus section (with slight pause before)
	if _first_clear_container.visible:
		_reveal_tween.tween_interval(0.2)  # Extra pause before first clear bonus
		_reveal_tween.tween_property(_first_clear_container, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		# Add a scale bounce for emphasis
		_reveal_tween.parallel().tween_property(_first_clear_container, "scale", Vector2(1.0, 1.0), 0.3) \
			.from(Vector2(0.8, 0.8)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Step 6: Reveal loot items
	if not _loot_rows.is_empty():
		_reveal_tween.tween_interval(0.15)
		for loot_row in _loot_rows:
			_reveal_tween.tween_property(loot_row, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
			_reveal_tween.tween_interval(0.1)  # 100ms delay

	# Mark animation complete
	_reveal_tween.tween_callback(_on_reveal_complete)

func _on_reveal_complete():
	"""Called when reward reveal animation is complete"""
	_is_animating = false
	print("BattleResultOverlay: Loot reveal animation complete")

func hide_result():
	"""Hide the overlay with animation"""
	# Kill any running animation
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
	_is_animating = false

	# Set visible to false immediately to prevent showing stale overlays
	visible = false
	# Reset modulate for next time
	modulate.a = 1.0

func _on_return_pressed():
	"""Handle return to map button press"""
	return_to_map_pressed.emit()

func _on_continue_pressed():
	"""Handle continue button press"""
	continue_pressed.emit()

func show_continue_button(visible_state: bool = true):
	"""Show or hide the continue button for multi-stage battles"""
	if continue_button:
		continue_button.visible = visible_state
