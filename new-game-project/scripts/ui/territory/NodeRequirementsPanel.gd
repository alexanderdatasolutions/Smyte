# scripts/ui/territory/NodeRequirementsPanel.gd
# Display panel showing node unlock requirements with met/unmet status
extends Control
class_name NodeRequirementsPanel

"""
NodeRequirementsPanel.gd - Display unlock requirements for locked hex nodes
RULE 2: Single responsibility - ONLY displays requirements and their status
RULE 1: Under 500 lines

Shows:
- Level requirement (green check if met, red X if not)
- Specialization tier requirement (green check if met, red X if not)
- Specialization role requirement (green check if met, red X if not)
- Power requirement (green check if met, red X if not)
- "What you need" text explanation for unmet requirements
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal close_requested()

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: HexNode = null

# System references
var node_requirement_checker = null

# UI components
var _main_container: VBoxContainer = null
var _title_label: Label = null
var _requirements_list: VBoxContainer = null
var _explanation_container: VBoxContainer = null
var _explanation_label: Label = null
var _close_button: Button = null

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 400
const PANEL_HEIGHT = 350
const REQUIREMENT_ROW_HEIGHT = 40
const BUTTON_HEIGHT = 40

# Colors
const COLOR_MET = Color(0.3, 0.8, 0.3, 1)  # Green
const COLOR_UNMET = Color(0.8, 0.3, 0.3, 1)  # Red
const COLOR_BACKGROUND = Color(0.1, 0.1, 0.12, 0.95)
const COLOR_BORDER = Color(0.4, 0.35, 0.3, 1)
const COLOR_TEXT = Color(0.9, 0.9, 0.85, 1)

# Icons
const ICON_MET = "✓"
const ICON_UNMET = "✗"

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("NodeRequirementsPanel: SystemRegistry not available")
		return

	node_requirement_checker = registry.get_system("NodeRequirementChecker")

	if not node_requirement_checker:
		push_error("NodeRequirementsPanel: NodeRequirementChecker not found")

# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui() -> void:
	"""Build the UI hierarchy"""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Background panel
	var background = Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BACKGROUND
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background.add_theme_stylebox_override("panel", style)
	add_child(background)

	# Main container
	_main_container = VBoxContainer.new()
	_main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_container.add_theme_constant_override("separation", 10)
	add_child(_main_container)

	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	_main_container.add_child(margin)

	var content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 15)
	margin.add_child(content_container)

	# Title
	_title_label = Label.new()
	_title_label.text = "UNLOCK REQUIREMENTS"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(_title_label)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	content_container.add_child(separator1)

	# Requirements list
	_requirements_list = VBoxContainer.new()
	_requirements_list.add_theme_constant_override("separation", 8)
	content_container.add_child(_requirements_list)

	# Separator
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 2)
	content_container.add_child(separator2)

	# Explanation container
	_explanation_container = VBoxContainer.new()
	_explanation_container.add_theme_constant_override("separation", 5)
	content_container.add_child(_explanation_container)

	var explanation_title = Label.new()
	explanation_title.text = "What You Need:"
	explanation_title.add_theme_font_size_override("font_size", 14)
	explanation_title.add_theme_color_override("font_color", COLOR_TEXT)
	_explanation_container.add_child(explanation_title)

	_explanation_label = Label.new()
	_explanation_label.add_theme_font_size_override("font_size", 12)
	_explanation_label.add_theme_color_override("font_color", COLOR_TEXT)
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation_container.add_child(_explanation_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(spacer)

	# Close button
	_close_button = Button.new()
	_close_button.text = "CLOSE"
	_close_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_close_button.pressed.connect(_on_close_pressed)
	_apply_button_style(_close_button)
	content_container.add_child(_close_button)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================

func show_requirements(hex_node: HexNode) -> void:
	"""Show requirements for the given node"""
	if not hex_node:
		push_warning("NodeRequirementsPanel: Cannot show requirements for null node")
		return

	current_node = hex_node
	_update_requirements_display()
	visible = true

func hide_panel() -> void:
	"""Hide the panel"""
	visible = false
	current_node = null

func refresh() -> void:
	"""Refresh the display with current data"""
	if current_node:
		_update_requirements_display()

# ==============================================================================
# PRIVATE METHODS
# ==============================================================================

func _update_requirements_display() -> void:
	"""Update the requirements list display"""
	# Clear existing requirements
	for child in _requirements_list.get_children():
		child.queue_free()

	if not current_node:
		return

	if not node_requirement_checker:
		push_error("NodeRequirementsPanel: NodeRequirementChecker not available")
		return

	# Get requirement status
	var status = node_requirement_checker.get_requirement_status(current_node)
	if status.is_empty():
		return

	# Build requirement rows
	_add_level_requirement_row(status.get("level", {}))

	var spec_status = status.get("specialization", {})
	if spec_status.get("tier_required", 0) > 0:
		_add_specialization_requirement_row(spec_status)

	_add_power_requirement_row(status.get("power", {}))

	# Update explanation
	_update_explanation(status)

func _add_level_requirement_row(level_status: Dictionary) -> void:
	"""Add level requirement row"""
	if level_status.is_empty():
		return

	var required = level_status.get("required", 1)
	var current = level_status.get("current", 1)
	var met = level_status.get("met", false)

	var row_text = "Player Level %d (Currently: %d)" % [required, current]
	_add_requirement_row(row_text, met)

func _add_specialization_requirement_row(spec_status: Dictionary) -> void:
	"""Add specialization requirement row"""
	if spec_status.is_empty():
		return

	var tier_required = spec_status.get("tier_required", 0)
	var role_required = spec_status.get("role_required", "")
	var met = spec_status.get("met", false)

	var row_text = ""
	if role_required != "":
		row_text = "%s Specialization Tier %d" % [role_required.capitalize(), tier_required]
	else:
		row_text = "Any Specialization Tier %d" % tier_required

	_add_requirement_row(row_text, met)

func _add_power_requirement_row(power_status: Dictionary) -> void:
	"""Add power requirement row"""
	if power_status.is_empty():
		return

	var required = power_status.get("required", 1000)
	var current = power_status.get("current", 0)
	var met = power_status.get("met", false)

	var row_text = "Combat Power %d (Currently: %d)" % [required, current]
	_add_requirement_row(row_text, met)

func _add_requirement_row(text: String, met: bool) -> void:
	"""Add a requirement row with status indicator"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, REQUIREMENT_ROW_HEIGHT)
	_requirements_list.add_child(row)

	# Status icon
	var icon_label = Label.new()
	icon_label.text = ICON_MET if met else ICON_UNMET
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", COLOR_MET if met else COLOR_UNMET)
	icon_label.custom_minimum_size = Vector2(30, 0)
	row.add_child(icon_label)

	# Requirement text
	var text_label = Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.add_theme_color_override("font_color", COLOR_TEXT)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text_label)

func _update_explanation(status: Dictionary) -> void:
	"""Update the 'What You Need' explanation text"""
	if not node_requirement_checker:
		return

	var missing = node_requirement_checker.get_missing_requirements(current_node)

	if missing.is_empty():
		_explanation_label.text = "All requirements met! You can capture this node."
		_explanation_label.add_theme_color_override("font_color", COLOR_MET)
		_explanation_container.visible = true
	elif missing.size() > 0:
		var explanation_parts: Array = []
		for req in missing:
			explanation_parts.append("• " + str(req))

		_explanation_label.text = "\n".join(explanation_parts)
		_explanation_label.add_theme_color_override("font_color", COLOR_UNMET)
		_explanation_container.visible = true
	else:
		_explanation_container.visible = false

func _apply_button_style(button: Button) -> void:
	"""Apply dark fantasy button style"""
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.22, 0.2, 1)
	normal_style.border_width_left = 1
	normal_style.border_width_right = 1
	normal_style.border_width_top = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.5, 0.45, 0.4, 1)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.35, 0.32, 0.3, 1)
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed state
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.18, 0.16, 1)
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Text color
	button.add_theme_color_override("font_color", COLOR_TEXT)

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_requested.emit()
	hide_panel()
