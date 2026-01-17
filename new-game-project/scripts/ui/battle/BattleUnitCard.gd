# scripts/ui/battle/BattleUnitCard.gd
# Battle-specific unit card for displaying units during combat
# RULE 2: Single responsibility - ONLY displays BattleUnit data
# RULE 4: No logic in UI - just display state from BattleUnit
class_name BattleUnitCard extends Panel

const StatusEffectIconScript = preload("res://scripts/ui/battle/StatusEffectIcon.gd")

signal unit_clicked(unit: BattleUnit)

# Card configuration
enum CardStyle { NORMAL, ACTIVE, TARGETED, DEAD }

# Internal state
var battle_unit: BattleUnit = null
var current_style: CardStyle = CardStyle.NORMAL

# UI Elements (created dynamically in _ready)
var portrait_rect: TextureRect
var name_label: Label
var level_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var turn_bar: ProgressBar
var turn_label: Label
var status_container: HBoxContainer

func _ready():
	# Only setup structure if it doesn't already exist
	# (setup_unit() might have been called before _ready())
	if not portrait_rect:
		_setup_card_structure()
		_apply_card_style()

func setup_unit(unit: BattleUnit, style: CardStyle = CardStyle.NORMAL):
	"""Setup card with BattleUnit data"""
	print("BattleUnitCard.setup_unit: Starting setup for ", unit.display_name if unit else "NULL")
	battle_unit = unit
	current_style = style

	# Ensure structure exists
	if not portrait_rect:
		print("BattleUnitCard.setup_unit: Setting up card structure...")
		_setup_card_structure()
		print("BattleUnitCard.setup_unit: Card structure complete")

	print("BattleUnitCard.setup_unit: Populating unit data...")
	_populate_unit_data()
	print("BattleUnitCard.setup_unit: Applying card style...")
	_apply_card_style()
	print("BattleUnitCard.setup_unit: Setup complete for ", unit.display_name)

func update_unit():
	"""Update card with current BattleUnit state (call after HP/status changes)"""
	if battle_unit:
		_update_hp_display()
		_update_turn_bar()
		_update_alive_state()
		update_status_effects()

func set_active(is_active: bool):
	"""Set whether this unit is the active turn unit"""
	if is_active:
		current_style = CardStyle.ACTIVE
	elif battle_unit and not battle_unit.is_alive:
		current_style = CardStyle.DEAD
	else:
		current_style = CardStyle.NORMAL
	_apply_card_style()

func set_targeted(is_targeted: bool):
	"""Set whether this unit is being targeted"""
	if is_targeted and current_style != CardStyle.ACTIVE:
		current_style = CardStyle.TARGETED
	elif battle_unit and not battle_unit.is_alive:
		current_style = CardStyle.DEAD
	elif current_style == CardStyle.TARGETED:
		current_style = CardStyle.NORMAL
	_apply_card_style()

func _setup_card_structure():
	"""Create the card UI structure"""
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Set card size - compact horizontal layout
	custom_minimum_size = Vector2(200, 115)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	# Main HORIZONTAL layout (portrait left, stats right)
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)

	# Portrait on the left
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(portrait_rect)

	# Stats VBox on the right
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	# Name label
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Level label
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(level_label)

	# HP bar container
	var hp_container = VBoxContainer.new()
	hp_container.add_theme_constant_override("separation", 1)
	vbox.add_child(hp_container)

	# HP label
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 9)
	hp_label.modulate = Color.LIGHT_GREEN
	hp_container.add_child(hp_label)

	# HP bar
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 8)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.show_percentage = false
	hp_container.add_child(hp_bar)
	_style_hp_bar()

	# Turn bar container
	var turn_container = VBoxContainer.new()
	turn_container.add_theme_constant_override("separation", 1)
	vbox.add_child(turn_container)

	# Turn label
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 8)
	turn_label.modulate = Color.CYAN
	turn_label.text = "ATB"
	turn_container.add_child(turn_label)

	# Turn bar (ATB-style)
	turn_bar = ProgressBar.new()
	turn_bar.custom_minimum_size = Vector2(0, 6)
	turn_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_bar.min_value = 0.0
	turn_bar.max_value = 100.0
	turn_bar.show_percentage = false
	turn_container.add_child(turn_bar)
	_style_turn_bar()

	# Status effects container (horizontal icons)
	status_container = HBoxContainer.new()
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	status_container.add_theme_constant_override("separation", 2)
	status_container.custom_minimum_size = Vector2(0, 20)  # Reserve space for status icons
	vbox.add_child(status_container)

	# Make card clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_card_clicked)
	margin.add_child(button)

func _style_hp_bar():
	"""Style the HP bar"""
	if not hp_bar:
		return

	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("background", bg_style)

	# Fill style
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", fill_style)

func _style_turn_bar():
	"""Style the turn/ATB bar"""
	if not turn_bar:
		return

	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	bg_style.corner_radius_top_left = 1
	bg_style.corner_radius_top_right = 1
	bg_style.corner_radius_bottom_left = 1
	bg_style.corner_radius_bottom_right = 1
	turn_bar.add_theme_stylebox_override("background", bg_style)

	# Fill style
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.6, 1.0, 1.0)  # Blue/cyan
	fill_style.corner_radius_top_left = 1
	fill_style.corner_radius_top_right = 1
	fill_style.corner_radius_bottom_left = 1
	fill_style.corner_radius_bottom_right = 1
	turn_bar.add_theme_stylebox_override("fill", fill_style)

func _populate_unit_data():
	"""Fill card with battle unit data"""
	if not battle_unit:
		print("BattleUnitCard._populate_unit_data: No battle_unit!")
		return

	print("BattleUnitCard._populate_unit_data: Loading portrait...")
	# Load portrait
	_load_portrait()

	print("BattleUnitCard._populate_unit_data: Setting name...")
	# Set name
	if name_label:
		name_label.text = battle_unit.display_name

	print("BattleUnitCard._populate_unit_data: Setting level...")
	# Set level (from source_god if available)
	if level_label:
		var level = 1
		if battle_unit.source_god:
			level = battle_unit.source_god.level
		level_label.text = "Lv.%d" % level

	print("BattleUnitCard._populate_unit_data: Updating HP display...")
	# Update HP display
	_update_hp_display()

	print("BattleUnitCard._populate_unit_data: Updating turn bar...")
	# Update turn bar
	_update_turn_bar()

	print("BattleUnitCard._populate_unit_data: Updating status effects...")
	# Update status effects
	update_status_effects()
	print("BattleUnitCard._populate_unit_data: Complete")

func _load_portrait():
	"""Load the unit portrait from source_god or fallback"""
	if not portrait_rect:
		print("BattleUnitCard._load_portrait: No portrait_rect!")
		return

	var texture_loaded = false

	# Try to load from source_god
	if battle_unit.source_god:
		var sprite_path = "res://assets/gods/" + battle_unit.source_god.id + ".png"
		print("BattleUnitCard._load_portrait: Trying to load god sprite: ", sprite_path)
		if ResourceLoader.exists(sprite_path):
			portrait_rect.texture = load(sprite_path)
			texture_loaded = true
			print("BattleUnitCard._load_portrait: God sprite loaded successfully")
		else:
			print("BattleUnitCard._load_portrait: God sprite not found at path")

	# Try to load from source_enemy
	if not texture_loaded and not battle_unit.source_enemy.is_empty():
		var enemy_sprite = battle_unit.source_enemy.get("sprite", "")
		print("BattleUnitCard._load_portrait: Trying to load enemy sprite: ", enemy_sprite)
		if enemy_sprite != "" and ResourceLoader.exists(enemy_sprite):
			portrait_rect.texture = load(enemy_sprite)
			texture_loaded = true
			print("BattleUnitCard._load_portrait: Enemy sprite loaded successfully")
		else:
			print("BattleUnitCard._load_portrait: Enemy sprite not found or empty")

	# Create placeholder if no texture loaded
	if not texture_loaded:
		print("BattleUnitCard._load_portrait: Creating placeholder texture...")
		var placeholder = _create_placeholder_texture()
		portrait_rect.texture = placeholder
		print("BattleUnitCard._load_portrait: Placeholder created")

func _create_placeholder_texture() -> ImageTexture:
	"""Create a colorful placeholder texture based on unit type"""
	var placeholder = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)

	# Color based on player/enemy status
	var color: Color
	if battle_unit.is_player_unit:
		color = Color(0.2, 0.4, 0.8, 1.0)  # Blue for player
	else:
		color = Color(0.8, 0.2, 0.2, 1.0)  # Red for enemy

	# Try to get element color if source_god exists
	if battle_unit.source_god:
		color = _get_element_color(battle_unit.source_god.element)

	image.fill(color)
	placeholder.set_image(image)
	return placeholder

func _get_element_color(element: God.ElementType) -> Color:
	"""Get color for element type"""
	match element:
		God.ElementType.FIRE: return Color(1.0, 0.4, 0.2, 1.0)
		God.ElementType.WATER: return Color(0.2, 0.6, 1.0, 1.0)
		God.ElementType.EARTH: return Color(0.6, 0.8, 0.2, 1.0)
		God.ElementType.LIGHTNING: return Color(1.0, 1.0, 0.2, 1.0)
		God.ElementType.LIGHT: return Color(1.0, 1.0, 0.8, 1.0)
		God.ElementType.DARK: return Color(0.4, 0.2, 0.6, 1.0)
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _update_hp_display():
	"""Update HP bar and label"""
	if not battle_unit:
		return

	var hp_percent = battle_unit.get_hp_percentage()

	if hp_bar:
		hp_bar.value = hp_percent
		# Change color based on HP level
		var fill_style = StyleBoxFlat.new()
		if hp_percent > 50:
			fill_style.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
		elif hp_percent > 25:
			fill_style.bg_color = Color(0.9, 0.7, 0.1, 1.0)  # Yellow
		else:
			fill_style.bg_color = Color(0.8, 0.2, 0.2, 1.0)  # Red
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_bottom_right = 2
		hp_bar.add_theme_stylebox_override("fill", fill_style)

	if hp_label:
		hp_label.text = "%d / %d" % [battle_unit.current_hp, battle_unit.max_hp]

func _update_turn_bar():
	"""Update the turn/ATB bar"""
	if not battle_unit or not turn_bar:
		return

	var turn_progress = battle_unit.get_turn_progress() * 100.0
	turn_bar.value = turn_progress

	# Glow effect when ready
	if turn_progress >= 100.0:
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 1.0, 0.2, 1.0)  # Yellow/green when ready
		fill_style.corner_radius_top_left = 1
		fill_style.corner_radius_top_right = 1
		fill_style.corner_radius_bottom_left = 1
		fill_style.corner_radius_bottom_right = 1
		turn_bar.add_theme_stylebox_override("fill", fill_style)
	else:
		_style_turn_bar()  # Reset to default style

func _update_alive_state():
	"""Update visual state based on alive status"""
	if not battle_unit:
		return

	if not battle_unit.is_alive:
		current_style = CardStyle.DEAD
		_apply_card_style()

func _apply_card_style():
	"""Apply visual style based on current_style"""
	var style = StyleBoxFlat.new()

	match current_style:
		CardStyle.NORMAL:
			style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
			style.border_color = Color(0.3, 0.3, 0.4, 1.0)

		CardStyle.ACTIVE:
			style.bg_color = Color(0.2, 0.25, 0.15, 0.95)
			style.border_color = Color(1.0, 0.9, 0.2, 1.0)  # Gold border for active

		CardStyle.TARGETED:
			style.bg_color = Color(0.25, 0.15, 0.15, 0.95)
			style.border_color = Color(1.0, 0.3, 0.3, 1.0)  # Red border for targeted

		CardStyle.DEAD:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
			style.border_color = Color(0.3, 0.3, 0.3, 0.5)
			# Gray out the card
			modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Reset modulate if not dead
	if current_style != CardStyle.DEAD:
		modulate = Color.WHITE

	# Apply border
	var border_width = 3 if current_style == CardStyle.ACTIVE else 2
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	add_theme_stylebox_override("panel", style)

func _on_card_clicked():
	"""Handle card click"""
	if battle_unit:
		unit_clicked.emit(battle_unit)

# =============================================================================
# PUBLIC API for status effects
# =============================================================================

const MAX_VISIBLE_STATUS_ICONS := 5  # Limit to avoid overflow

func update_status_effects():
	"""Update status effect icons display using StatusEffectIcon component"""
	if not status_container or not battle_unit:
		print("BattleUnitCard.update_status_effects: Missing container or unit")
		return

	print("BattleUnitCard.update_status_effects: Updating %s with %d effects" % [battle_unit.display_name, battle_unit.status_effects.size()])

	# Clear existing icons
	for child in status_container.get_children():
		child.queue_free()

	# Add icons for each status effect (up to max visible)
	var effect_count = 0
	for effect in battle_unit.status_effects:
		print("BattleUnitCard.update_status_effects: Adding icon for effect: %s" % effect.name)
		if effect_count >= MAX_VISIBLE_STATUS_ICONS:
			# Add overflow indicator
			var overflow_label = Label.new()
			overflow_label.text = "+%d" % (battle_unit.status_effects.size() - MAX_VISIBLE_STATUS_ICONS)
			overflow_label.add_theme_font_size_override("font_size", 8)
			overflow_label.modulate = Color.LIGHT_GRAY
			status_container.add_child(overflow_label)
			break

		# Use StatusEffectIcon component
		var icon = StatusEffectIconScript.new()
		icon.setup(effect)
		status_container.add_child(icon)
		effect_count += 1

	print("BattleUnitCard.update_status_effects: Added %d status effect icons to %s" % [effect_count, battle_unit.display_name])
