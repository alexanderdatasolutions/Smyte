# scripts/ui/territory/GarrisonDisplay.gd
# Mobile-friendly garrison display component for node defense
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - displays garrison gods and combat power
# RULE 4: Read-only display - no data modification (emits signals for parent to handle)
# RULE 5: SystemRegistry for all system access
class_name GarrisonDisplay
extends Control

signal set_garrison_requested  # Parent should open GodSelectionGrid
signal garrison_god_tapped(god: God)  # When user taps an assigned god
signal remove_god_requested(god: God)  # When user wants to unassign a god

# Affinity/Element color mapping (matches GodSelectionGrid)
const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1, 1.0),       # Red
	God.ElementType.WATER: Color(0.2, 0.5, 0.9, 1.0),      # Blue
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2, 1.0),      # Brown
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0, 1.0),  # Light Blue (Air)
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3, 1.0),     # Gold
	God.ElementType.DARK: Color(0.5, 0.2, 0.6, 1.0)        # Purple
}

# Element icons for visual indicator (matches GodSelectionGrid)
const ELEMENT_ICONS = {
	God.ElementType.FIRE: "🔥",
	God.ElementType.WATER: "💧",
	God.ElementType.EARTH: "🪨",
	God.ElementType.LIGHTNING: "⚡",
	God.ElementType.LIGHT: "☀️",
	God.ElementType.DARK: "🌙"
}

# Card sizing for garrison display (compact, horizontal layout)
const CARD_WIDTH = 70
const CARD_HEIGHT = 90
const CARD_SPACING = 8

# Core systems
var collection_manager

# UI elements
var _title_label: Label
var _combat_power_label: Label
var _garrison_container: HBoxContainer
var _set_garrison_button: Button
var _empty_state_label: Label

# State
var _garrison_god_ids: Array[String] = []
var _garrison_gods: Array[God] = []

func _ready() -> void:
	_init_systems()
	_setup_ui()

func _init_systems() -> void:
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GarrisonDisplay: SystemRegistry not available!")
		return

	collection_manager = registry.get_system("CollectionManager")

	if not collection_manager:
		push_error("GarrisonDisplay: CollectionManager not found!")

func _setup_ui() -> void:
	"""Setup the UI structure"""
	# Main section container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header row: Title + Combat Power
	var header = _create_header()
	main_vbox.add_child(header)

	# Garrison cards container (horizontal scroll)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CARD_HEIGHT + 20)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_garrison_container = HBoxContainer.new()
	_garrison_container.add_theme_constant_override("separation", CARD_SPACING)
	scroll.add_child(_garrison_container)

	# Empty state label (shown when no garrison)
	_empty_state_label = Label.new()
	_empty_state_label.text = "No defenders assigned"
	_empty_state_label.add_theme_font_size_override("font_size", 14)
	_empty_state_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garrison_container.add_child(_empty_state_label)

	# Set Garrison button
	_set_garrison_button = Button.new()
	_set_garrison_button.text = "+ Set Garrison"
	_set_garrison_button.custom_minimum_size = Vector2(140, 44)  # 60x60 min tap target
	_set_garrison_button.pressed.connect(_on_set_garrison_pressed)
	main_vbox.add_child(_set_garrison_button)

func _create_header() -> Control:
	"""Create header with title and combat power display"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	# Title
	_title_label = Label.new()
	_title_label.text = "Garrison"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(_title_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Combat power icon + label
	var power_container = HBoxContainer.new()
	power_container.add_theme_constant_override("separation", 4)

	var power_icon = Label.new()
	power_icon.text = "Combat Power:"
	power_icon.add_theme_font_size_override("font_size", 14)
	power_icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	power_container.add_child(power_icon)

	_combat_power_label = Label.new()
	_combat_power_label.text = "0"
	_combat_power_label.add_theme_font_size_override("font_size", 16)
	_combat_power_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold
	power_container.add_child(_combat_power_label)

	header.add_child(power_container)

	return header

# =============================================================================
# PUBLIC API
# =============================================================================

func set_garrison_gods(god_ids: Array[String]) -> void:
	"""Set the garrison gods by their IDs and refresh display"""
	_garrison_god_ids = god_ids.duplicate()
	_resolve_gods()
	refresh_display()

func get_garrison_god_ids() -> Array[String]:
	"""Get current garrison god IDs"""
	return _garrison_god_ids.duplicate()

func get_total_combat_power() -> int:
	"""Calculate total combat power of garrison"""
	var total = 0
	for god in _garrison_gods:
		total += _get_god_combat_power(god)
	return total

func add_god_to_garrison(god: God) -> void:
	"""Add a god to the garrison (does not persist - parent should handle data)"""
	if god.id in _garrison_god_ids:
		return  # Already in garrison

	_garrison_god_ids.append(god.id)
	_garrison_gods.append(god)
	refresh_display()

func remove_god_from_garrison(god_id: String) -> void:
	"""Remove a god from garrison by ID"""
	var idx = _garrison_god_ids.find(god_id)
	if idx >= 0:
		_garrison_god_ids.remove_at(idx)
		# Find and remove from gods array
		for i in range(_garrison_gods.size()):
			if _garrison_gods[i].id == god_id:
				_garrison_gods.remove_at(i)
				break
		refresh_display()

func refresh_display() -> void:
	"""Refresh the garrison display - RULE 4: Read-only display"""
	_clear_garrison_cards()

	if _garrison_gods.is_empty():
		_show_empty_state()
	else:
		_show_garrison_cards()

	_update_combat_power()
	print("GarrisonDisplay: Showing %d garrison gods, total power: %d" % [_garrison_gods.size(), get_total_combat_power()])

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _resolve_gods() -> void:
	"""Resolve god IDs to God objects using CollectionManager"""
	_garrison_gods.clear()

	if not collection_manager:
		return

	for god_id in _garrison_god_ids:
		var god = collection_manager.get_god_by_id(god_id)
		if god:
			_garrison_gods.append(god)
		else:
			push_warning("GarrisonDisplay: Could not find god with ID: " + god_id)

func _clear_garrison_cards() -> void:
	"""Clear existing garrison cards"""
	for child in _garrison_container.get_children():
		if child != _empty_state_label:
			child.queue_free()

func _show_empty_state() -> void:
	"""Show empty garrison state"""
	_empty_state_label.visible = true
	_set_garrison_button.text = "+ Set Garrison"

func _show_garrison_cards() -> void:
	"""Create cards for garrison gods"""
	_empty_state_label.visible = false
	_set_garrison_button.text = "+ Add Defender"

	for god in _garrison_gods:
		var card = _create_garrison_card(god)
		_garrison_container.add_child(card)

func _create_garrison_card(god: God) -> Control:
	"""Create a compact garrison card showing portrait, level, and combat power"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.name = "GarrisonCard_" + god.id

	# Style with element color border - enhanced visibility
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = element_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)

	# Portrait (40x40)
	var portrait_container = CenterContainer.new()
	var portrait = _create_portrait(god)
	portrait_container.add_child(portrait)
	vbox.add_child(portrait_container)

	# Element indicator badge
	var element_indicator = _create_element_indicator(god)
	vbox.add_child(element_indicator)

	# Combat power
	var power_label = Label.new()
	power_label.text = "%d" % _get_god_combat_power(god)
	power_label.add_theme_font_size_override("font_size", 10)
	power_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(power_label)

	# Make tappable (for removing)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_garrison_god_tapped.bind(god))
	card.add_child(button)

	return card

func _create_element_indicator(god: God) -> Control:
	"""Create element indicator with icon and colored background badge"""
	var container = CenterContainer.new()

	# Badge panel with element color
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(20, 14)

	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = element_color.darkened(0.2)
	badge_style.corner_radius_top_left = 3
	badge_style.corner_radius_top_right = 3
	badge_style.corner_radius_bottom_left = 3
	badge_style.corner_radius_bottom_right = 3
	badge.add_theme_stylebox_override("panel", badge_style)

	# Element icon label
	var icon_label = Label.new()
	icon_label.text = ELEMENT_ICONS.get(god.element, "?")
	icon_label.add_theme_font_size_override("font_size", 9)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(icon_label)

	container.add_child(badge)
	return container

func _create_portrait(god: God) -> Control:
	"""Create god portrait with element-colored placeholder if no image"""
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Try to load portrait
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		# Create element-colored placeholder
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var placeholder = _create_color_placeholder(element_color, 40, 40)
		portrait.texture = placeholder

	return portrait

func _create_color_placeholder(color: Color, width: int, height: int) -> ImageTexture:
	"""Create a colored placeholder texture"""
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	return texture

func _get_god_combat_power(god: God) -> int:
	"""Get combat power for a god - uses GodCalculator"""
	# Combat power = sum of combat stats (HP + Attack + Defense + Speed)
	return GodCalculator.get_power_rating(god)

func _update_combat_power() -> void:
	"""Update combat power display"""
	var total = get_total_combat_power()
	_combat_power_label.text = str(total)

	# Color code based on power level
	if total == 0:
		_combat_power_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	elif total < 500:
		_combat_power_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	elif total < 1000:
		_combat_power_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green
	elif total < 2000:
		_combat_power_label.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))  # Blue
	else:
		_combat_power_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold

func _on_set_garrison_pressed() -> void:
	"""Handle Set Garrison button press"""
	print("GarrisonDisplay: Set Garrison button pressed")
	set_garrison_requested.emit()

func _on_garrison_god_tapped(god: God) -> void:
	"""Handle tap on garrison god card"""
	print("GarrisonDisplay: Garrison god tapped - %s" % god.name)
	garrison_god_tapped.emit(god)
