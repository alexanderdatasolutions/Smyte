# scripts/ui/pvp_territory/PvPNodeInfoPanel.gd
# Info display panel for selected PvP hex node - matches NodeInfoPanel patterns exactly
extends Control
class_name PvPNodeInfoPanel

"""
PvPNodeInfoPanel - Display details for selected PvP hex node
Matches NodeInfoPanel structure exactly with PvP-specific features:
- Neutral nodes: Show PvE enemies to defeat (like regular territory)
- Owned nodes: Show garrison slots for defense team
- Enemy nodes: Show enemy defense team preview

Shows:
- Node name, type, tier
- Territory owner info
- Garrison with slot boxes (for owned nodes)
- Enemy defense preview (for enemy nodes)
- PvE defenders (for neutral nodes)
- Combat Power
- Action buttons: Attack/Set Defense/Close
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal capture_requested(hex_node: PvPHexNode)
signal attack_requested(hex_node: PvPHexNode)
signal set_defense_requested(hex_node: PvPHexNode)
signal close_requested()
signal slot_tapped(node: PvPHexNode, slot_type: String, slot_index: int)
signal filled_slot_tapped(node: PvPHexNode, slot_type: String, slot_index: int, god_data: Dictionary)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH := 380
const PANEL_HEIGHT := 600
const BUTTON_HEIGHT := 40
const SLOT_SIZE := 54
const SLOT_SPACING := 4
const MAX_GARRISON_SLOTS := 4

# Colors (matching NodeInfoPanel)
const COLOR_LOCKED := Color(0.15, 0.15, 0.15, 0.9)
const COLOR_NEUTRAL := Color(0.3, 0.3, 0.35, 0.9)
const COLOR_CONTROLLED := Color(0.2, 0.5, 0.3, 0.9)

const TIER_COLORS := {
	1: Color(0.6, 0.6, 0.6, 1),
	2: Color(0.3, 0.8, 0.3, 1),
	3: Color(0.3, 0.5, 1.0, 1),
	4: Color(0.8, 0.3, 1.0, 1),
	5: Color(1.0, 0.6, 0.0, 1)
}

const ELEMENT_COLORS := {
	"fire": Color(0.9, 0.2, 0.1),
	"water": Color(0.2, 0.5, 0.9),
	"earth": Color(0.6, 0.4, 0.2),
	"lightning": Color(0.6, 0.8, 1.0),
	"light": Color(1.0, 0.85, 0.3),
	"dark": Color(0.5, 0.2, 0.6)
}

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: PvPHexNode = null
var _territory_manager: PvPTerritoryManager = null
var _current_user_uid: String = ""

# UI components
var _main_container: VBoxContainer = null
var _header_label: Label = null
var _type_tier_label: Label = null
var _owner_container: VBoxContainer = null
var _garrison_container: VBoxContainer = null
var _defense_preview_container: VBoxContainer = null
var _defense_label: Label = null
var _action_buttons: HBoxContainer = null

# Cooldown timer
var _cooldown_label: Label = null
var _cooldown_timer: Timer = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_build_ui()
	visible = true  # Panel visibility controlled by parent container


func initialize(territory_manager: PvPTerritoryManager, current_user_uid: String) -> void:
	"""Initialize with manager reference"""
	_territory_manager = territory_manager
	_current_user_uid = current_user_uid


func _build_ui() -> void:
	"""Build the UI components - matching NodeInfoPanel structure"""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Background panel
	var bg_panel := Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.3, 0.35, 1)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Main scroll container
	var scroll := ScrollContainer.new()
	scroll.name = "MainScrollContainer"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	# Main container
	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_main_container)

	# Header section
	_build_header()

	# Separator
	_add_separator()

	# Owner section
	_build_owner_section()

	# Garrison section (for owned nodes)
	_build_garrison_section()

	# Defense preview section (for enemy/neutral nodes)
	_build_defense_preview_section()

	# Combat Power section
	_build_defense_section()

	# Separator
	_add_separator()

	# Action buttons
	_build_action_buttons()

	# Cooldown timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.timeout.connect(_update_cooldown_display)
	add_child(_cooldown_timer)


func _build_header() -> void:
	"""Build header with name, type, tier and close button"""
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	_main_container.add_child(header_row)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_vbox)

	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(_header_label)

	_type_tier_label = Label.new()
	_type_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_type_tier_label.add_theme_font_size_override("font_size", 14)
	_type_tier_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	title_vbox.add_child(_type_tier_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(_on_close_pressed)
	_style_button(close_btn, Color(0.3, 0.25, 0.35, 0.8))
	header_row.add_child(close_btn)


func _build_owner_section() -> void:
	"""Build owner info section"""
	var section_label := _create_section_label("Territory Owner")
	_main_container.add_child(section_label)

	_owner_container = VBoxContainer.new()
	_owner_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_owner_container)


func _build_garrison_section() -> void:
	"""Build garrison info section with slot boxes (for owned nodes)"""
	var section_label := _create_section_label("Garrison (Defense)")
	section_label.name = "GarrisonSectionLabel"
	_main_container.add_child(section_label)

	_garrison_container = VBoxContainer.new()
	_garrison_container.name = "GarrisonContainer"
	_garrison_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_garrison_container)


func _build_defense_preview_section() -> void:
	"""Build defense preview section (for enemy/neutral nodes)"""
	var section_label := _create_section_label("Defenders")
	section_label.name = "DefensePreviewSectionLabel"
	_main_container.add_child(section_label)

	_defense_preview_container = VBoxContainer.new()
	_defense_preview_container.name = "DefensePreviewContainer"
	_defense_preview_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_defense_preview_container)


func _build_defense_section() -> void:
	"""Build combat power info section"""
	var section_label := _create_section_label("Combat Power")
	_main_container.add_child(section_label)

	_defense_label = Label.new()
	_defense_label.add_theme_font_size_override("font_size", 12)
	_defense_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	_main_container.add_child(_defense_label)


func _build_action_buttons() -> void:
	"""Build action buttons"""
	_action_buttons = HBoxContainer.new()
	_action_buttons.add_theme_constant_override("separation", 10)
	_action_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_container.add_child(_action_buttons)


func _create_section_label(text: String) -> Label:
	"""Create a section header label"""
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
	return label


func _add_separator() -> void:
	"""Add a horizontal separator"""
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_main_container.add_child(separator)


# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func show_hex(hex_node: PvPHexNode) -> void:
	"""Show panel with node data"""
	current_node = hex_node

	if not current_node:
		hide_panel()
		return

	_update_all_displays()


func hide_panel() -> void:
	"""Hide the panel"""
	current_node = null
	_cooldown_timer.stop()


func refresh() -> void:
	"""Refresh the display with current node data"""
	if current_node:
		_update_all_displays()


# ==============================================================================
# PRIVATE METHODS - Display Updates
# ==============================================================================
func _update_all_displays() -> void:
	"""Update all display sections"""
	_update_header()
	_update_owner()
	_update_garrison()
	_update_defense_preview()
	_update_defense()
	_update_action_buttons()


func _update_header() -> void:
	"""Update header labels"""
	if not current_node:
		return

	_header_label.text = current_node.name

	var tier_stars := ""
	for i in range(current_node.tier):
		tier_stars += "★"

	var type_display := current_node.get_node_type_display()
	_type_tier_label.text = "%s - %s" % [type_display, tier_stars]

	var tier_color: Color = TIER_COLORS.get(current_node.tier, Color.WHITE)
	_type_tier_label.add_theme_color_override("font_color", tier_color)


func _update_owner() -> void:
	"""Update owner display"""
	_clear_container(_owner_container)

	if not current_node:
		return

	var owner_label := Label.new()
	owner_label.add_theme_font_size_override("font_size", 14)

	if current_node.is_neutral():
		owner_label.text = "⚪ Neutral Territory"
		owner_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	elif current_node.controller_uid == _current_user_uid:
		owner_label.text = "🟢 Your Territory"
		owner_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		owner_label.text = "🔴 Owned by: %s" % current_node.controller_display_name
		owner_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))

	_owner_container.add_child(owner_label)

	# Objective value info
	if current_node.is_objective:
		var value_label := Label.new()
		value_label.text = "⭐ Objective: +%d points/min" % current_node.objective_value
		value_label.add_theme_font_size_override("font_size", 12)
		value_label.add_theme_color_override("font_color", Color.GOLD)
		_owner_container.add_child(value_label)


func _update_garrison() -> void:
	"""Update garrison display with slot boxes (only for owned nodes)"""
	_clear_container(_garrison_container)

	# Find and hide/show garrison section label
	var garrison_label: Label = _main_container.get_node_or_null("GarrisonSectionLabel")

	if not current_node:
		if garrison_label:
			garrison_label.visible = false
		_garrison_container.visible = false
		return

	# Only show garrison for player-owned nodes
	var is_mine := current_node.controller_uid == _current_user_uid
	if not is_mine:
		if garrison_label:
			garrison_label.visible = false
		_garrison_container.visible = false
		return

	if garrison_label:
		garrison_label.visible = true
	_garrison_container.visible = true

	# Create slot boxes
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	_garrison_container.add_child(slots_row)

	for i in range(MAX_GARRISON_SLOTS):
		var slot: Control
		if i < current_node.defense_team_serialized.size():
			var god_data: Dictionary = current_node.defense_team_serialized[i]
			slot = _create_filled_slot(i, god_data)
		else:
			slot = _create_empty_slot(i)
		slots_row.add_child(slot)

	# Show defense power
	if current_node.defense_power > 0:
		var power_label := Label.new()
		power_label.text = "🛡️ Defense Power: %d" % current_node.defense_power
		power_label.add_theme_font_size_override("font_size", 12)
		power_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		_garrison_container.add_child(power_label)
	else:
		var warning_label := Label.new()
		warning_label.text = "⚠️ No defense team set!"
		warning_label.add_theme_font_size_override("font_size", 12)
		warning_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4))
		_garrison_container.add_child(warning_label)


func _update_defense_preview() -> void:
	"""Update defense preview for enemy/neutral nodes - DETAILED VIEW"""
	_clear_container(_defense_preview_container)

	# Find and hide/show preview section label
	var preview_label: Label = _main_container.get_node_or_null("DefensePreviewSectionLabel")

	if not current_node:
		if preview_label:
			preview_label.visible = false
		_defense_preview_container.visible = false
		return

	# Don't show for owned nodes (they have garrison section instead)
	var is_mine := current_node.controller_uid == _current_user_uid
	if is_mine:
		if preview_label:
			preview_label.visible = false
		_defense_preview_container.visible = false
		return

	if preview_label:
		preview_label.visible = true
	_defense_preview_container.visible = true

	if current_node.is_neutral():
		# Show PvE defenders for neutral nodes
		var pve_label := Label.new()
		pve_label.text = "🐉 Territory Defenders"
		pve_label.add_theme_font_size_override("font_size", 13)
		pve_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
		_defense_preview_container.add_child(pve_label)

		# Show actual enemy names from enemies.json
		var enemy_names := _get_tier_enemy_names(current_node.tier)
		var num_enemies := mini(current_node.tier + 1, 4)  # Tier 1: 2, Tier 2: 3, etc

		var enemies_row := HBoxContainer.new()
		enemies_row.add_theme_constant_override("separation", 6)
		_defense_preview_container.add_child(enemies_row)

		for i in range(num_enemies):
			var enemy_name: String = enemy_names[i % enemy_names.size()]
			var enemy_card := _create_pve_enemy_card(enemy_name, current_node.tier)
			enemies_row.add_child(enemy_card)

		var power_required := current_node.capture_power_required
		var power_label := Label.new()
		power_label.text = "⚔️ Power Required: ~%d" % power_required
		power_label.add_theme_font_size_override("font_size", 12)
		power_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
		_defense_preview_container.add_child(power_label)

	else:
		# Show enemy player's defense team - DETAILED VIEW
		var enemy_label := Label.new()
		enemy_label.text = "🛡️ %s's Garrison" % current_node.controller_display_name
		enemy_label.add_theme_font_size_override("font_size", 14)
		enemy_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		_defense_preview_container.add_child(enemy_label)

		if current_node.has_defense_team():
			# Show detailed defense team cards
			_defense_preview_container.add_child(_create_detailed_team_display(current_node.defense_team_serialized))

			# Show team bonuses
			var bonuses_section := _create_team_bonuses_display(current_node.defense_team_serialized)
			if bonuses_section:
				_defense_preview_container.add_child(bonuses_section)

			# Show total combat power with breakdown
			var power_section := _create_power_breakdown(current_node.defense_team_serialized, current_node.defense_power)
			_defense_preview_container.add_child(power_section)
		else:
			var undefended := Label.new()
			undefended.text = "⚠️ Undefended territory!"
			undefended.add_theme_font_size_override("font_size", 12)
			undefended.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
			_defense_preview_container.add_child(undefended)


func _update_defense() -> void:
	"""Update combat power display"""
	if not current_node:
		_defense_label.text = "Combat Power: N/A"
		return

	if current_node.controller_uid == _current_user_uid:
		_defense_label.text = "🛡️ Your Defense Power: %d" % current_node.defense_power
	elif current_node.is_neutral():
		_defense_label.text = "⚔️ Required Power: %d" % current_node.capture_power_required
	else:
		_defense_label.text = "⚔️ Enemy Power: %d" % current_node.defense_power


func _update_action_buttons() -> void:
	"""Update action buttons based on ownership"""
	_clear_container(_action_buttons)

	if not current_node:
		return

	if current_node.is_neutral():
		# Capture neutral territory
		var capture_btn := _create_action_button("⚔️  Capture", Color(0.3, 0.7, 0.4, 1))
		capture_btn.pressed.connect(func(): attack_requested.emit(current_node))
		_action_buttons.add_child(capture_btn)

	elif current_node.controller_uid == _current_user_uid:
		# Own territory - set defense
		var defense_btn := _create_action_button("🛡️  Set Defense", Color(0.3, 0.5, 0.8, 1))
		defense_btn.pressed.connect(func(): set_defense_requested.emit(current_node))
		_action_buttons.add_child(defense_btn)

	else:
		# Enemy territory - check if can attack
		if _territory_manager:
			var validation := _territory_manager.can_attack_hex(current_node)
			if validation["can_attack"]:
				var attack_btn := _create_action_button("⚔️  Attack", Color(0.8, 0.3, 0.3, 1))
				attack_btn.pressed.connect(func(): attack_requested.emit(current_node))
				_action_buttons.add_child(attack_btn)
			else:
				# Show reason and cooldown
				var reason_label := Label.new()
				reason_label.text = validation.get("reason", "Cannot attack")
				reason_label.add_theme_font_size_override("font_size", 12)
				reason_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
				reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_action_buttons.add_child(reason_label)

				if validation.has("cooldown_remaining"):
					_cooldown_label = Label.new()
					_cooldown_label.add_theme_font_size_override("font_size", 13)
					_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					_action_buttons.add_child(_cooldown_label)
					_cooldown_timer.start()
					_update_cooldown_display()
		else:
			var attack_btn := _create_action_button("⚔️  Attack", Color(0.8, 0.3, 0.3, 1))
			attack_btn.pressed.connect(func(): attack_requested.emit(current_node))
			_action_buttons.add_child(attack_btn)


# ==============================================================================
# SLOT CREATION (matching NodeInfoPanel pattern)
# ==============================================================================
func _create_empty_slot(slot_index: int) -> Control:
	"""Create an empty garrison slot with '+' icon"""
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var border_color := Color(0.4, 0.4, 0.45, 0.7)
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 2))

	# Plus icon
	var plus_label := Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 24)
	plus_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	plus_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	slot.add_child(plus_label)

	# Tappable button
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_slot_tapped.bind(slot_index))
	slot.add_child(button)

	return slot


func _create_filled_slot(slot_index: int, god_data: Dictionary) -> Control:
	"""Create a filled garrison slot showing god info"""
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var element: String = god_data.get("element", "fire")
	var border_color: Color = ELEMENT_COLORS.get(element, Color.GRAY)
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 3))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# Element icon
	var element_icons := {"fire": "🔥", "water": "💧", "earth": "🌍", "lightning": "⚡", "light": "✨", "dark": "🌑"}
	var icon_label := Label.new()
	icon_label.text = element_icons.get(element, "❓")
	icon_label.add_theme_font_size_override("font_size", 18)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Name (truncated)
	var god_name: String = god_data.get("name", "?")
	var name_label := Label.new()
	name_label.text = god_name.substr(0, 6) if god_name.length() > 6 else god_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label := Label.new()
	level_label.text = "Lv%d" % god_data.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Tappable button
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_filled_slot_tapped.bind(slot_index, god_data))
	slot.add_child(button)

	return slot


func _create_god_preview_card(god_data: Dictionary) -> Control:
	"""Create a god card for enemy defense preview (read-only)"""
	var card := Panel.new()
	card.custom_minimum_size = Vector2(60, 70)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.22)
	var element: Variant = god_data.get("element", "fire")
	var element_str: String = _element_to_string(element)
	style.border_color = ELEMENT_COLORS.get(element_str, Color(0.4, 0.35, 0.5))
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Element icon
	var element_icons := {"fire": "🔥", "water": "💧", "earth": "🌍", "lightning": "⚡", "light": "✨", "dark": "🌑"}
	var icon_label := Label.new()
	icon_label.text = element_icons.get(element_str, "❓")
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Name
	var god_name: String = god_data.get("name", "?")
	var name_label := Label.new()
	name_label.text = god_name.substr(0, 5) if god_name.length() > 5 else god_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label := Label.new()
	level_label.text = "Lv%d" % god_data.get("level", 1)
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	return card


# ==============================================================================
# DETAILED ENEMY GARRISON DISPLAY
# ==============================================================================

func _create_detailed_team_display(defense_team: Array) -> Control:
	"""Create detailed god cards showing full stats for enemy garrison"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	for i in range(defense_team.size()):
		var god_data: Dictionary = defense_team[i]
		var card := _create_detailed_god_card(god_data, i == 0)
		container.add_child(card)

	return container


func _create_detailed_god_card(god_data: Dictionary, is_leader: bool) -> Control:
	"""Create a detailed god card with stats, element, pantheon, equipment"""
	var card := Panel.new()
	card.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 90)

	var element: Variant = god_data.get("element", 0)
	var element_str: String = _element_to_string(element)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.18, 0.95)
	style.border_color = ELEMENT_COLORS.get(element_str, Color(0.4, 0.35, 0.5))
	style.set_border_width_all(2)
	if is_leader:
		style.border_color = Color.GOLD
		style.border_width_top = 3
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Left side: Element icon and basic info
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(70, 0)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(left_vbox)

	# Element icon (large)
	var element_icons := {"fire": "🔥", "water": "💧", "earth": "🌍", "lightning": "⚡", "light": "✨", "dark": "🌑"}
	var icon_label := Label.new()
	icon_label.text = element_icons.get(element_str, "❓")
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(icon_label)

	# Tier stars
	var tier_val: Variant = god_data.get("tier", 1)
	var tier: int = tier_val if tier_val is int else 1
	var tier_label := Label.new()
	var stars := ""
	for _s in range(mini(tier + 1, 4)):
		stars += "★"
	tier_label.text = stars
	tier_label.add_theme_font_size_override("font_size", 10)
	tier_label.add_theme_color_override("font_color", TIER_COLORS.get(tier + 1, Color.WHITE))
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(tier_label)

	# Middle: Name, level, pantheon
	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(mid_vbox)

	# Name with leader badge
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	mid_vbox.add_child(name_row)

	if is_leader:
		var leader_badge := Label.new()
		leader_badge.text = "👑"
		leader_badge.add_theme_font_size_override("font_size", 12)
		name_row.add_child(leader_badge)

	var name_label := Label.new()
	name_label.text = god_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	# Level and Pantheon
	var info_label := Label.new()
	var pantheon: String = god_data.get("pantheon", "unknown")
	info_label.text = "Lv%d • %s" % [god_data.get("level", 1), pantheon.capitalize()]
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	mid_vbox.add_child(info_label)

	# Stats row
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	mid_vbox.add_child(stats_row)

	var hp: int = god_data.get("base_hp", god_data.get("hp", 100))
	var atk: int = god_data.get("base_attack", god_data.get("attack", 50))
	var def: int = god_data.get("base_defense", god_data.get("defense", 40))
	var spd: int = god_data.get("base_speed", god_data.get("speed", 50))

	_add_stat_display(stats_row, "❤️", hp, Color(0.9, 0.5, 0.5))
	_add_stat_display(stats_row, "⚔️", atk, Color(0.9, 0.7, 0.4))
	_add_stat_display(stats_row, "🛡️", def, Color(0.5, 0.7, 0.9))
	_add_stat_display(stats_row, "💨", spd, Color(0.5, 0.9, 0.7))

	# Equipment indicator
	var equipment: Variant = god_data.get("equipment", [])
	var equip_count: int = 0
	if equipment is Array:
		for eq in equipment:
			if eq != null:
				equip_count += 1
	elif equipment is Dictionary:
		equip_count = equipment.size()

	if equip_count > 0:
		var equip_label := Label.new()
		equip_label.text = "🎒 %d equipped" % equip_count
		equip_label.add_theme_font_size_override("font_size", 10)
		equip_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		mid_vbox.add_child(equip_label)

	return card


func _add_stat_display(container: Control, icon: String, value: int, color: Color) -> void:
	"""Add a stat icon + value display"""
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	container.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(icon_lbl)

	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(val_lbl)


func _create_team_bonuses_display(defense_team: Array) -> Control:
	"""Create display showing team bonuses (element synergy, pantheon, etc.)"""
	# Convert serialized team to God objects for TeamStatsCalculator
	var god_objects: Array = []
	for god_data: Dictionary in defense_team:
		var god: God = _deserialize_god_for_bonuses(god_data)
		if god:
			god_objects.append(god)

	if god_objects.is_empty():
		return null

	# Get team bonuses using the real system
	var bonuses: Array = TeamStatsCalculator.get_team_bonuses(god_objects)

	if bonuses.is_empty():
		return null

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Section header
	var header := Label.new()
	header.text = "⚡ Team Bonuses"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.8, 0.9, 0.5))
	container.add_child(header)

	# List each bonus
	for bonus: Dictionary in bonuses:
		var bonus_row := HBoxContainer.new()
		bonus_row.add_theme_constant_override("separation", 6)
		container.add_child(bonus_row)

		var name_lbl := Label.new()
		name_lbl.text = "• %s" % bonus.get("name", "Bonus")
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
		bonus_row.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = bonus.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.4))
		bonus_row.add_child(desc_lbl)

	# Leader skill
	var leader_info: Dictionary = TeamStatsCalculator.get_leader_skill_info(god_objects)
	if not leader_info.is_empty():
		var leader_row := HBoxContainer.new()
		leader_row.add_theme_constant_override("separation", 6)
		container.add_child(leader_row)

		var leader_lbl := Label.new()
		leader_lbl.text = "👑 %s" % leader_info.get("skill_name", "Leader Skill")
		leader_lbl.add_theme_font_size_override("font_size", 11)
		leader_lbl.add_theme_color_override("font_color", Color.GOLD)
		leader_row.add_child(leader_lbl)

		var leader_desc := Label.new()
		leader_desc.text = leader_info.get("description", "")
		leader_desc.add_theme_font_size_override("font_size", 10)
		leader_desc.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
		leader_row.add_child(leader_desc)

	return container


func _create_power_breakdown(defense_team: Array, total_power: int) -> Control:
	"""Create power breakdown display"""
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Total power header
	var power_row := HBoxContainer.new()
	power_row.add_theme_constant_override("separation", 8)
	container.add_child(power_row)

	var power_icon := Label.new()
	power_icon.text = "⚔️"
	power_icon.add_theme_font_size_override("font_size", 18)
	power_row.add_child(power_icon)

	var power_label := Label.new()
	power_label.text = "Total Power:"
	power_label.add_theme_font_size_override("font_size", 14)
	power_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	power_row.add_child(power_label)

	var power_value := Label.new()
	power_value.text = "%d" % total_power
	power_value.add_theme_font_size_override("font_size", 18)
	power_value.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	power_row.add_child(power_value)

	# Tip about bonuses
	var tip := Label.new()
	tip.text = "(Includes team synergies & equipment)"
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	container.add_child(tip)

	return container


func _deserialize_god_for_bonuses(data: Dictionary) -> God:
	"""Convert serialized god data back to God object for bonus calculation"""
	var god := God.new()
	god.id = data.get("id", "deserialized_%d" % randi())
	god.template_id = data.get("template_id", data.get("id", ""))
	god.name = data.get("name", "Unknown")
	god.level = data.get("level", 1)

	# Handle tier as int or enum
	var tier_val: Variant = data.get("tier", 0)
	if tier_val is int:
		god.tier = tier_val as God.TierType
	elif tier_val is String:
		god.tier = God.string_to_tier(tier_val)
	else:
		god.tier = God.TierType.COMMON

	god.pantheon = data.get("pantheon", "unknown")

	# Handle element as int or enum or string
	var element_val: Variant = data.get("element", 0)
	if element_val is int:
		god.element = element_val as God.ElementType
	elif element_val is String:
		god.element = God.string_to_element(element_val)
	else:
		god.element = God.ElementType.FIRE

	god.base_hp = data.get("base_hp", data.get("hp", 100))
	god.base_attack = data.get("base_attack", data.get("attack", 50))
	god.base_defense = data.get("base_defense", data.get("defense", 40))
	god.base_speed = data.get("base_speed", data.get("speed", 50))
	god.base_crit_rate = data.get("base_crit_rate", God.DEFAULT_CRIT_RATE)
	god.base_crit_damage = data.get("base_crit_damage", God.DEFAULT_CRIT_DAMAGE)
	god.is_awakened = data.get("is_awakened", false)
	god.awakened_name = data.get("awakened_name", "")
	god.ascension_level = data.get("ascension_level", 0)
	god.leader_skill = data.get("leader_skill", {})

	return god


func _element_to_string(element: Variant) -> String:
	"""Convert element (int, enum, or string) to string"""
	if element is String:
		return element.to_lower()
	if element is int:
		match element:
			0: return "fire"
			1: return "water"
			2: return "earth"
			3: return "lightning"
			4: return "light"
			5: return "dark"
			_: return "fire"
	return "fire"


func _create_slot_style(border_color: Color, border_width: int) -> StyleBoxFlat:
	"""Create slot panel style"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style


# ==============================================================================
# UI HELPERS
# ==============================================================================
func _create_action_button(text: String, color: Color) -> Button:
	"""Create styled action button"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE)

	return btn


func _style_button(btn: Button, color: Color) -> void:
	"""Style a button with given color"""
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	btn.add_theme_font_size_override("font_size", 16)


func _clear_container(container: Control) -> void:
	"""Remove all children from a container"""
	if not container:
		return
	for child in container.get_children():
		child.queue_free()


func _update_cooldown_display() -> void:
	"""Update cooldown timer display"""
	if not current_node or not _cooldown_label:
		_cooldown_timer.stop()
		return

	var remaining := current_node.get_cooldown_remaining_for(_current_user_uid)
	if remaining <= 0:
		_cooldown_label.text = "✅ Attack available!"
		_cooldown_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_cooldown_timer.stop()
		_update_action_buttons()
	else:
		var minutes := int(remaining) / 60
		var seconds := int(remaining) % 60
		_cooldown_label.text = "⏱️ Cooldown: %d:%02d" % [minutes, seconds]
		_cooldown_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_close_pressed() -> void:
	"""Handle close button press"""
	hide_panel()
	close_requested.emit()


func _on_slot_tapped(slot_index: int) -> void:
	"""Handle empty slot tap"""
	if current_node:
		slot_tapped.emit(current_node, "garrison", slot_index)


func _on_filled_slot_tapped(slot_index: int, god_data: Dictionary) -> void:
	"""Handle filled slot tap"""
	if current_node:
		filled_slot_tapped.emit(current_node, "garrison", slot_index, god_data)


# ==============================================================================
# PVE ENEMY HELPERS
# ==============================================================================
func _get_tier_enemy_names(tier: int) -> Array:
	"""Get available enemy names for a tier from enemies.json"""
	var registry := SystemRegistry.get_instance()
	if not registry:
		return _get_fallback_enemy_names(tier)

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return _get_fallback_enemy_names(tier)

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return _get_fallback_enemy_names(tier)

	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if not territory_defenders.has(tier_key):
		return _get_fallback_enemy_names(tier)

	var tier_data: Dictionary = territory_defenders[tier_key]
	var names: Array = []

	# Collect enemy names from all node types in this tier
	for node_type: String in tier_data:
		if node_type.begins_with("_"):  # Skip metadata keys
			continue
		var node_enemies = tier_data[node_type]
		if node_enemies is Dictionary:
			for enemy_name: String in node_enemies.keys():
				if enemy_name not in names:
					names.append(enemy_name)

	if names.is_empty():
		return _get_fallback_enemy_names(tier)

	return names


func _get_fallback_enemy_names(tier: int) -> Array:
	"""Fallback enemy names if enemies.json fails to load"""
	var names := {
		1: ["Kobold Miner", "Nisse", "Domovoi"],
		2: ["Jorogumo", "Kelpie", "Rusalka"],
		3: ["Oni Brute", "Baba Yaga's Guard", "Berserker"],
		4: ["Typhon Spawn", "Set's Champion", "Jormungandr Scion"],
		5: ["Apep", "Typhon", "Angra Mainyu"]
	}
	return names.get(tier, names[1])


func _get_enemy_element(enemy_name: String, tier: int) -> String:
	"""Get element for an enemy from enemies.json"""
	var registry := SystemRegistry.get_instance()
	if not registry:
		return "neutral"

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return "neutral"

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return "neutral"

	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if territory_defenders.has(tier_key):
		var tier_data: Dictionary = territory_defenders[tier_key]
		for node_type: String in tier_data:
			if node_type.begins_with("_"):
				continue
			var node_enemies = tier_data[node_type]
			if node_enemies is Dictionary and node_enemies.has(enemy_name):
				return node_enemies[enemy_name].get("element", "neutral")

	return "neutral"


func _create_pve_enemy_card(enemy_name: String, tier: int) -> Control:
	"""Create a card showing PvE enemy info"""
	var card := Panel.new()
	card.custom_minimum_size = Vector2(60, 70)

	var element := _get_enemy_element(enemy_name, tier)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.22)
	style.border_color = ELEMENT_COLORS.get(element, Color(0.4, 0.35, 0.5))
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Element icon
	var element_icons := {"fire": "🔥", "water": "💧", "earth": "🌍", "lightning": "⚡", "light": "✨", "dark": "🌑", "neutral": "⚪"}
	var icon_label := Label.new()
	icon_label.text = element_icons.get(element, "❓")
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Name (truncated)
	var name_label := Label.new()
	name_label.text = enemy_name.substr(0, 5) if enemy_name.length() > 5 else enemy_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level based on tier
	var level_label := Label.new()
	level_label.text = "Lv%d" % (tier * 10)
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	return card
