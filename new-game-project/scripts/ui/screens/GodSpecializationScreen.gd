# scripts/ui/screens/GodSpecializationScreen.gd
# God Specialization Screen - View and select specialization paths
# RULE 1: Under 500 lines - Single screen coordinator
# RULE 2: Single responsibility - Specialization UI coordination
# RULE 4: UI Only - Delegates logic to SpecializationManager and RoleManager
class_name GodSpecializationScreen extends Control

"""
GodSpecializationScreen
Full screen UI for viewing and selecting god specializations
- Shows god selection list (left panel)
- Displays specialization tree for selected god's role (center panel)
- Shows detailed info about selected specialization (right panel)
- Allows unlocking specializations if requirements met
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal back_pressed

# ==============================================================================
# SYSTEM REFERENCES
# ==============================================================================
var collection_manager: CollectionManager = null
var specialization_manager: SpecializationManager = null
var role_manager: RoleManager = null
var resource_manager: ResourceManager = null
var event_bus: EventBus = null

# ==============================================================================
# STATE
# ==============================================================================
var selected_god: God = null
var selected_spec_id: String = ""
var current_role: String = ""

# ==============================================================================
# UI COMPONENTS
# ==============================================================================
var spec_tree: SpecializationTree = null
var tooltip_panel: Panel = null
var tooltip_label: RichTextLabel = null

# ==============================================================================
# SCENE REFERENCES
# ==============================================================================
@onready var back_button = $BackButton
@onready var main_container = $MainContainer

# Left panel: God selection
@onready var god_list_container = $MainContainer/LeftPanel/ScrollContainer/GodList

# Center panel: Specialization tree
@onready var tree_panel = $MainContainer/CenterPanel/TreePanel
@onready var tree_header_label = $MainContainer/CenterPanel/TreePanel/HeaderVBox/TreeHeaderLabel
@onready var tree_container = $MainContainer/CenterPanel/TreePanel/HeaderVBox/TreeScrollContainer

# Right panel: Details and unlock
@onready var details_panel = $MainContainer/RightPanel/DetailsPanel
@onready var details_content = $MainContainer/RightPanel/DetailsPanel/DetailsVBox/DetailsContent
@onready var unlock_button = $MainContainer/RightPanel/DetailsPanel/DetailsVBox/UnlockButton
@onready var no_selection_label = $MainContainer/RightPanel/DetailsPanel/DetailsVBox/NoSelectionLabel

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready():
	_setup_fullscreen()
	_initialize_systems()
	_create_tree_component()
	_create_tooltip_panel()
	_connect_signals()
	_style_ui()

	_refresh_god_list()
	_show_no_selection()

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _initialize_systems():
	"""Initialize system references via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GodSpecializationScreen: SystemRegistry not available!")
		return

	collection_manager = registry.get_system("CollectionManager")
	specialization_manager = registry.get_system("SpecializationManager")
	role_manager = registry.get_system("RoleManager")
	resource_manager = registry.get_system("ResourceManager")
	event_bus = registry.get_system("EventBus")

	if not collection_manager:
		push_error("GodSpecializationScreen: CollectionManager not found!")
	if not specialization_manager:
		push_error("GodSpecializationScreen: SpecializationManager not found!")
	if not role_manager:
		push_error("GodSpecializationScreen: RoleManager not found!")

func _create_tree_component():
	"""Create the SpecializationTree component"""
	spec_tree = SpecializationTree.new()
	spec_tree.name = "SpecializationTree"

	if tree_container:
		tree_container.add_child(spec_tree)

func _create_tooltip_panel():
	"""Create floating tooltip panel for hover info"""
	tooltip_panel = Panel.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.98)
	style.border_color = Color(0.6, 0.5, 0.7, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 8
	tooltip_panel.add_theme_stylebox_override("panel", style)

	# Margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	tooltip_panel.add_child(margin)

	# Label
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_label.add_theme_color_override("default_color", Color(0.95, 0.9, 0.85))
	tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	margin.add_child(tooltip_label)

	add_child(tooltip_panel)

func _connect_signals():
	"""Connect UI signals"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if unlock_button:
		unlock_button.pressed.connect(_on_unlock_pressed)

	# Tree signals
	if spec_tree:
		spec_tree.node_selected.connect(_on_spec_node_selected)
		spec_tree.node_hovered.connect(_on_spec_node_hovered)
		spec_tree.node_unhovered.connect(_on_spec_node_unhovered)

	# Event bus - refresh on specialization unlocked
	if event_bus:
		if not event_bus.is_connected("specialization_unlocked", _on_specialization_unlocked):
			event_bus.connect("specialization_unlocked", _on_specialization_unlocked)

func _style_ui():
	"""Apply dark fantasy theme styling"""
	_style_back_button()
	_style_unlock_button()

func _style_back_button():
	"""Style back button"""
	if not back_button:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", hover)

	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

func _style_unlock_button():
	"""Style unlock button"""
	if not unlock_button:
		return

	unlock_button.text = "Unlock Specialization"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.2, 0.95)
	style.border_color = Color(0.4, 0.8, 0.4, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	unlock_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.6, 0.25, 0.98)
	hover.border_color = Color(0.5, 1.0, 0.5, 1.0)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	unlock_button.add_theme_stylebox_override("hover", hover)

	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	disabled.border_color = Color(0.3, 0.3, 0.3, 0.7)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(8)
	unlock_button.add_theme_stylebox_override("disabled", disabled)

	unlock_button.add_theme_color_override("font_color", Color.WHITE)
	unlock_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	unlock_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

# ==============================================================================
# GOD LIST
# ==============================================================================

func _refresh_god_list():
	"""Refresh the list of selectable gods"""
	if not god_list_container or not collection_manager:
		return

	# Clear existing
	for child in god_list_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	# Get all gods
	var all_gods = collection_manager.get_all_gods()
	if all_gods.is_empty():
		var label = Label.new()
		label.text = "No gods available"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		god_list_container.add_child(label)
		return

	# Create god cards
	for god in all_gods:
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_list_container.add_child(god_card)

		# Highlight selected god
		var card_style = GodCard.CardStyle.SELECTED if (selected_god and selected_god.id == god.id) else GodCard.CardStyle.NORMAL
		god_card.setup_god_card(god, card_style)
		god_card.god_selected.connect(_on_god_selected)

# ==============================================================================
# GOD SELECTION
# ==============================================================================

func _on_god_selected(god: God):
	"""Handle god selection"""
	selected_god = god
	selected_spec_id = ""

	# Get god's primary role
	if god.primary_role != "":
		current_role = god.primary_role
	else:
		current_role = ""

	# Refresh UI
	_refresh_god_list()
	_refresh_tree()
	_show_no_selection()

# ==============================================================================
# SPECIALIZATION TREE
# ==============================================================================

func _refresh_tree():
	"""Refresh the specialization tree for selected god"""
	if not spec_tree or not selected_god or current_role == "" or not specialization_manager:
		if tree_header_label:
			tree_header_label.text = "Select a god to view specializations"
		return

	# Update header
	if tree_header_label:
		var role_display = current_role.capitalize()
		tree_header_label.text = selected_god.name + " - " + role_display + " Specializations"

	# Setup tree
	spec_tree.setup(selected_god, current_role, specialization_manager)

# ==============================================================================
# SPECIALIZATION SELECTION
# ==============================================================================

func _on_spec_node_selected(spec_id: String):
	"""Handle specialization node selection"""
	selected_spec_id = spec_id
	_show_spec_details(spec_id)

func _show_spec_details(spec_id: String):
	"""Show detailed info about selected specialization"""
	if not specialization_manager or spec_id == "":
		_show_no_selection()
		return

	var spec = specialization_manager.get_specialization(spec_id)
	if not spec:
		_show_no_selection()
		return

	# Hide no selection label
	if no_selection_label:
		no_selection_label.visible = false

	# Clear details content
	if details_content:
		for child in details_content.get_children():
			child.queue_free()

	await get_tree().process_frame

	# Create details UI
	_create_spec_details_ui(spec)

	# Update unlock button state
	_update_unlock_button(spec)

func _show_no_selection():
	"""Show no selection message"""
	if no_selection_label:
		no_selection_label.visible = true
		no_selection_label.text = "Select a specialization to view details"

	if unlock_button:
		unlock_button.visible = false

	selected_spec_id = ""

func _create_spec_details_ui(spec: GodSpecialization):
	"""Create detailed UI for specialization"""
	if not details_content:
		return

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	details_content.add_child(vbox)

	# Title
	var title_label = Label.new()
	title_label.text = spec.name
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(title_label)

	# Tier
	var tier_label = Label.new()
	var tier_names = ["", "Tier I", "Tier II", "Tier III"]
	tier_label.text = tier_names[clampi(spec.tier, 1, 3)]
	tier_label.add_theme_font_size_override("font_size", 14)
	tier_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(tier_label)

	# Description
	if spec.description != "":
		var desc_label = Label.new()
		desc_label.text = spec.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
		vbox.add_child(desc_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# Requirements section
	_add_requirements_section(vbox, spec)

	# Bonuses section
	_add_bonuses_section(vbox, spec)

func _add_requirements_section(parent: VBoxContainer, spec: GodSpecialization):
	"""Add requirements section to details"""
	var req_header = Label.new()
	req_header.text = "Requirements:"
	req_header.add_theme_font_size_override("font_size", 14)
	req_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	parent.add_child(req_header)

	# Level
	if spec.level_required > 0:
		var level_label = Label.new()
		var god_level = selected_god.level if selected_god else 0
		var meets_level = god_level >= spec.level_required
		var level_color = Color(0.5, 1.0, 0.5) if meets_level else Color(1.0, 0.5, 0.5)
		level_label.text = "  Level " + str(spec.level_required) + " (Current: " + str(god_level) + ")"
		level_label.add_theme_color_override("font_color", level_color)
		parent.add_child(level_label)

	# Role
	if spec.role_required != "":
		var role_label = Label.new()
		var meets_role = selected_god and selected_god.primary_role == spec.role_required
		var role_color = Color(0.5, 1.0, 0.5) if meets_role else Color(1.0, 0.5, 0.5)
		role_label.text = "  " + spec.role_required.capitalize() + " Role"
		role_label.add_theme_color_override("font_color", role_color)
		parent.add_child(role_label)

	# Costs
	if not spec.costs.is_empty():
		var cost_header = Label.new()
		cost_header.text = "Costs:"
		cost_header.add_theme_font_size_override("font_size", 14)
		cost_header.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
		parent.add_child(cost_header)

		for cost_key in spec.costs:
			var cost_value = spec.costs[cost_key]
			var cost_label = Label.new()
			cost_label.text = "  " + str(cost_value) + " " + cost_key.replace("_", " ").capitalize()
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			parent.add_child(cost_label)

func _add_bonuses_section(parent: VBoxContainer, spec: GodSpecialization):
	"""Add bonuses section to details"""
	var bonus_header = Label.new()
	bonus_header.text = "Bonuses:"
	bonus_header.add_theme_font_size_override("font_size", 14)
	bonus_header.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	parent.add_child(bonus_header)

	var has_bonuses = false

	# Stat bonuses
	var stat_bonuses = spec.get_all_stat_bonuses()
	for bonus_key in stat_bonuses:
		var bonus_label = Label.new()
		var value = stat_bonuses[bonus_key]
		var formatted = _format_bonus_value(value)
		bonus_label.text = "  +" + formatted + " " + bonus_key.replace("_", " ").capitalize()
		bonus_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		parent.add_child(bonus_label)
		has_bonuses = true

	# Task bonuses
	var task_bonuses = spec.get_all_task_bonuses()
	for bonus_key in task_bonuses:
		var bonus_label = Label.new()
		var value = task_bonuses[bonus_key]
		var formatted = _format_bonus_value(value)
		bonus_label.text = "  +" + formatted + " " + bonus_key.replace("_", " ").capitalize()
		bonus_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		parent.add_child(bonus_label)
		has_bonuses = true

	if not has_bonuses:
		var no_bonus_label = Label.new()
		no_bonus_label.text = "  No bonuses"
		no_bonus_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		parent.add_child(no_bonus_label)

func _format_bonus_value(value) -> String:
	"""Format bonus value for display"""
	if typeof(value) == TYPE_BOOL:
		return "True" if value else "False"
	elif typeof(value) == TYPE_FLOAT:
		return str(int(value * 100)) + "%"
	elif typeof(value) == TYPE_INT:
		return str(value)
	else:
		return str(value)

# ==============================================================================
# UNLOCK BUTTON
# ==============================================================================

func _update_unlock_button(spec: GodSpecialization):
	"""Update unlock button state based on requirements"""
	if not unlock_button or not selected_god or not specialization_manager:
		return

	# Check if already unlocked
	var already_unlocked = selected_god.specialization_path.has(spec.id)
	if already_unlocked:
		unlock_button.text = "Already Unlocked"
		unlock_button.disabled = true
		unlock_button.visible = true
		return

	# Check if can unlock
	var can_unlock = specialization_manager.can_god_unlock_specialization(selected_god, spec.id)

	unlock_button.text = "Unlock Specialization"
	unlock_button.disabled = not can_unlock
	unlock_button.visible = true

func _on_unlock_pressed():
	"""Handle unlock button press"""
	if not selected_god or selected_spec_id == "" or not specialization_manager:
		return

	# Attempt unlock
	var success = specialization_manager.unlock_specialization(selected_god, selected_spec_id)

	if success:
		# Refresh all UI
		_refresh_tree()
		_show_spec_details(selected_spec_id)

		# Show success feedback (optional: could add popup notification)
		print("Specialization unlocked: " + selected_spec_id)
	else:
		# Show error feedback
		print("Failed to unlock specialization: " + selected_spec_id)

# ==============================================================================
# TOOLTIP HOVER
# ==============================================================================

func _on_spec_node_hovered(_spec_id: String, hover_tooltip_text: String):
	"""Handle node hover - show tooltip"""
	if not tooltip_panel or not tooltip_label:
		return

	tooltip_label.text = hover_tooltip_text
	tooltip_panel.visible = true

	# Position tooltip near mouse
	await get_tree().process_frame
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip_panel.position = mouse_pos + Vector2(20, 20)
	tooltip_panel.size = Vector2.ZERO  # Reset size to fit content

func _on_spec_node_unhovered():
	"""Handle node unhover - hide tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_specialization_unlocked(_god_id: String, _spec_id: String):
	"""Handle specialization unlock event"""
	# Refresh UI
	if selected_god:
		_refresh_tree()
		if selected_spec_id != "":
			_show_spec_details(selected_spec_id)

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()
