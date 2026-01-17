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

func _ready():
	# Set up full screen overlay
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
	add_child(center_container)

	# Content panel with border
	var content_panel = Panel.new()
	content_panel.custom_minimum_size = Vector2(500, 450)

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

	# Update rewards
	_populate_rewards(result)

	# Update loot
	_populate_loot(result)

	# Show the overlay
	visible = true

	# Play animation
	_animate_show()

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

func _populate_rewards(result: BattleResult):
	"""Populate rewards earned"""
	# Clear existing
	for child in rewards_container.get_children():
		child.queue_free()

	if result.rewards.is_empty():
		rewards_title.visible = false
		return

	rewards_title.visible = true

	for resource_id in result.rewards:
		var amount = result.rewards[resource_id]
		_add_reward_row(resource_id, amount)

	# Add experience gained
	for god_id in result.experience_gained:
		var exp_amount = result.experience_gained[god_id]
		_add_reward_row("EXP (%s)" % god_id, exp_amount)

func _add_reward_row(reward_name: String, amount: int):
	"""Add a reward row"""
	var row = HBoxContainer.new()

	# Reward icon could go here

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

	rewards_container.add_child(row)

func _format_resource_name(resource_id: String) -> String:
	"""Format resource ID to display name"""
	return resource_id.replace("_", " ").capitalize()

func _populate_loot(result: BattleResult):
	"""Populate loot items obtained"""
	# Clear existing
	for child in loot_container.get_children():
		child.queue_free()

	if result.loot_obtained.is_empty():
		return

	# Loot title
	var loot_title = Label.new()
	loot_title.text = "LOOT"
	loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_title.add_theme_font_size_override("font_size", 18)
	loot_title.add_theme_color_override("font_color", Color(0.6, 0.3, 1.0, 1.0))
	loot_container.add_child(loot_title)

	for item in result.loot_obtained:
		var item_name = item.get("name", "Unknown Item")
		var item_rarity = item.get("rarity", "common")

		var item_label = Label.new()
		item_label.text = item_name
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.add_theme_color_override("font_color", _get_rarity_color(item_rarity))
		loot_container.add_child(item_label)

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

func _animate_show():
	"""Animate the overlay appearing"""
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func hide_result():
	"""Hide the overlay with animation"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)

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
