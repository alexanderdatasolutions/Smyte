# scripts/ui/screens/GodSpecializationScreen.gd
# RULE 1 COMPLIANCE: Under 500 lines
# RULE 2 COMPLIANCE: Single responsibility - God specialization screen
# RULE 4 COMPLIANCE: UI Only - delegates to SpecializationManager
extends Control
class_name GodSpecializationScreenUI

signal back_pressed

# ==============================================================================
# CONSTANTS
# ==============================================================================
const BG_COLOR := Color(0.08, 0.06, 0.12)
const PANEL_BG := Color(0.12, 0.1, 0.16, 0.95)
const PANEL_BORDER := Color(0.3, 0.25, 0.4, 0.8)
const HEADER_COLOR := Color(0.8, 0.8, 0.9)
const MUTED_COLOR := Color(0.5, 0.5, 0.55)
const SUCCESS_COLOR := Color(0.5, 0.8, 0.5)
const WARNING_COLOR := Color(0.6, 0.4, 0.4)
const GOLD_COLOR := Color(1.0, 0.84, 0.0)

const GOD_CARD_SIZE := Vector2(70, 90)
const LEFT_PANEL_WIDTH := 240
const DETAIL_PANEL_WIDTH := 260

# ==============================================================================
# SYSTEM REFERENCES
# ==============================================================================
var specialization_manager: SpecializationManager
var collection_manager: CollectionManager
var resource_manager: Node

# ==============================================================================
# STATE
# ==============================================================================
var selected_god: God = null
var selected_spec_id: String = ""

# ==============================================================================
# UI REFERENCES
# ==============================================================================
var god_grid: GridContainer
var tree_container: ScrollContainer
var spec_tree: SpecializationTree
var detail_panel: VBoxContainer
var detail_name_label: Label
var detail_desc_label: RichTextLabel
var detail_requirements_label: RichTextLabel
var detail_bonuses_label: RichTextLabel
var unlock_button: Button
var no_god_label: Label
var role_tabs: HBoxContainer

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_fullscreen()
	_initialize_systems()
	_build_ui()
	_setup_unified_header()
	_populate_god_grid()

func _setup_fullscreen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _setup_unified_header() -> void:
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed() -> void:
	if visible:
		_update_header_for_screen()
		_populate_god_grid()

func _update_header_for_screen() -> void:
	var main_ui: Control = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("SPECIALIZATION TREE")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func _initialize_systems() -> void:
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if registry:
		specialization_manager = registry.get_system("SpecializationManager")
		collection_manager = registry.get_system("CollectionManager")
		resource_manager = registry.get_system("ResourceManager")

# ==============================================================================
# UI CONSTRUCTION
# ==============================================================================

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main horizontal layout with header offset
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Left panel: God selector
	_build_god_selector_panel(hbox)

	# Center: Specialization tree
	_build_tree_panel(hbox)

	# Right panel: Selected spec details
	_build_detail_panel(hbox)

func _build_god_selector_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = LEFT_PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_panel_style(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "SELECT GOD"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scrollable god grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	god_grid = GridContainer.new()
	god_grid.columns = 3
	god_grid.add_theme_constant_override("h_separation", 4)
	god_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(god_grid)

func _build_tree_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_panel_style(panel)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Role tabs
	role_tabs = HBoxContainer.new()
	role_tabs.add_theme_constant_override("separation", 4)
	role_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(role_tabs)

	# "No god selected" message
	no_god_label = Label.new()
	no_god_label.text = "Select a god to view specializations"
	no_god_label.add_theme_font_size_override("font_size", 16)
	no_god_label.add_theme_color_override("font_color", MUTED_COLOR)
	no_god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_god_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_god_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(no_god_label)

	# Tree scroll container
	tree_container = ScrollContainer.new()
	tree_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_container.visible = false
	vbox.add_child(tree_container)

	spec_tree = SpecializationTree.new()
	spec_tree.node_selected.connect(_on_spec_node_selected)
	tree_container.add_child(spec_tree)

func _build_detail_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = DETAIL_PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_apply_panel_style(panel)
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	detail_panel = VBoxContainer.new()
	detail_panel.add_theme_constant_override("separation", 8)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_panel)

	# Name
	detail_name_label = Label.new()
	detail_name_label.add_theme_font_size_override("font_size", 16)
	detail_name_label.add_theme_color_override("font_color", HEADER_COLOR)
	detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(detail_name_label)

	detail_panel.add_child(HSeparator.new())

	# Description
	detail_desc_label = RichTextLabel.new()
	detail_desc_label.bbcode_enabled = true
	detail_desc_label.fit_content = true
	detail_desc_label.scroll_active = false
	detail_desc_label.add_theme_font_size_override("normal_font_size", 12)
	detail_panel.add_child(detail_desc_label)

	# Requirements
	detail_requirements_label = RichTextLabel.new()
	detail_requirements_label.bbcode_enabled = true
	detail_requirements_label.fit_content = true
	detail_requirements_label.scroll_active = false
	detail_requirements_label.add_theme_font_size_override("normal_font_size", 11)
	detail_panel.add_child(detail_requirements_label)

	# Bonuses
	detail_bonuses_label = RichTextLabel.new()
	detail_bonuses_label.bbcode_enabled = true
	detail_bonuses_label.fit_content = true
	detail_bonuses_label.scroll_active = false
	detail_bonuses_label.add_theme_font_size_override("normal_font_size", 11)
	detail_panel.add_child(detail_bonuses_label)

	# Unlock button
	unlock_button = Button.new()
	unlock_button.text = "UNLOCK"
	unlock_button.custom_minimum_size.y = 40
	unlock_button.pressed.connect(_on_unlock_pressed)
	unlock_button.visible = false
	detail_panel.add_child(unlock_button)

	_clear_detail_panel()

# ==============================================================================
# GOD GRID
# ==============================================================================

func _populate_god_grid() -> void:
	if not god_grid or not collection_manager:
		return

	for child in god_grid.get_children():
		child.queue_free()

	var gods: Array = collection_manager.get_all_gods()
	for god: God in gods:
		var card := _create_god_card(god)
		god_grid.add_child(card)

func _create_god_card(god: God) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = GOD_CARD_SIZE
	btn.clip_text = true

	# Card content
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = god.name if god.name != "" else god.id
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % god.level
	level_lbl.add_theme_font_size_override("font_size", 8)
	level_lbl.add_theme_color_override("font_color", MUTED_COLOR)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	# Role indicator
	if god.primary_role != "":
		var role_lbl := Label.new()
		role_lbl.text = god.primary_role.capitalize()
		role_lbl.add_theme_font_size_override("font_size", 8)
		role_lbl.add_theme_color_override("font_color", GOLD_COLOR)
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(role_lbl)

	# Highlight if eligible for specialization
	if god.level >= 20 and god.primary_role != "":
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.2, 0.15, 0.9)
		style.border_color = SUCCESS_COLOR
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(_on_god_selected.bind(god))
	return btn

# ==============================================================================
# ROLE TABS
# ==============================================================================

func _update_role_tabs() -> void:
	if not role_tabs:
		return

	for child in role_tabs.get_children():
		child.queue_free()

	if not selected_god or selected_god.primary_role == "":
		return

	var roles := ["fighter", "gatherer", "crafter", "scholar", "support"]
	for role_id: String in roles:
		var btn := Button.new()
		btn.text = role_id.capitalize()
		btn.custom_minimum_size = Vector2(80, 30)
		btn.toggle_mode = true

		if role_id == selected_god.primary_role:
			btn.button_pressed = true

		btn.pressed.connect(_on_role_tab_pressed.bind(role_id))
		role_tabs.add_child(btn)

# ==============================================================================
# TREE DISPLAY
# ==============================================================================

func _show_tree_for_god(god: God, role_id: String = "") -> void:
	if not spec_tree or not specialization_manager:
		return

	var display_role: String = role_id if role_id != "" else god.primary_role
	if display_role == "":
		no_god_label.text = "This god has no role assigned"
		no_god_label.visible = true
		tree_container.visible = false
		return

	no_god_label.visible = false
	tree_container.visible = true
	spec_tree.setup(god, display_role, specialization_manager)

# ==============================================================================
# DETAIL PANEL
# ==============================================================================

func _clear_detail_panel() -> void:
	detail_name_label.text = "Select a specialization"
	detail_desc_label.text = ""
	detail_requirements_label.text = ""
	detail_bonuses_label.text = ""
	unlock_button.visible = false
	selected_spec_id = ""

func _show_spec_details(spec_id: String) -> void:
	if not specialization_manager:
		return

	var spec: GodSpecialization = specialization_manager.get_specialization(spec_id)
	if not spec:
		_clear_detail_panel()
		return

	selected_spec_id = spec_id

	# Name with tier
	detail_name_label.text = spec.get_display_name()

	# Description
	detail_desc_label.text = spec.description if spec.description != "" else "[i]No description[/i]"

	# Requirements
	var req_text := "[color=#aaaacc]Requirements:[/color]\n"
	req_text += "  Level %d" % spec.level_required
	if selected_god:
		var met: bool = selected_god.level >= spec.level_required
		req_text += " [color=%s](%d)[/color]" % ["#88ff88" if met else "#ff8888", selected_god.level]
	req_text += "\n"

	if spec.role_required != "":
		var role_met: bool = selected_god != null and selected_god.primary_role == spec.role_required
		var role_color: String = "#88ff88" if role_met else "#ff8888"
		req_text += "  [color=%s]%s Role[/color]\n" % [role_color, spec.role_required.capitalize()]

	if spec.has_parent():
		req_text += "  Parent: %s\n" % spec.get_parent_id().replace("_", " ").capitalize()

	if not spec.costs.is_empty():
		req_text += "\n[color=#ffff88]Cost:[/color]\n"
		for cost_key: String in spec.costs:
			req_text += "  %s: %d\n" % [cost_key.replace("_", " ").capitalize(), spec.costs[cost_key]]

	detail_requirements_label.text = req_text

	# Bonuses
	var bonus_text := ""
	bonus_text += _format_bonus_section("Stat Bonuses", spec.stat_bonuses)
	bonus_text += _format_bonus_section("Task Bonuses", spec.task_bonuses)
	bonus_text += _format_bonus_section("Resource Bonuses", spec.resource_bonuses)
	bonus_text += _format_bonus_section("Combat Bonuses", spec.combat_bonuses)
	bonus_text += _format_bonus_section("Crafting Bonuses", spec.crafting_bonuses)
	bonus_text += _format_bonus_section("Aura Effects", spec.aura_bonuses)

	if not spec.unlocked_ability_ids.is_empty():
		bonus_text += "[color=#88ccff]Unlocked Abilities:[/color]\n"
		for ability_id: String in spec.unlocked_ability_ids:
			bonus_text += "  %s\n" % ability_id.replace("_", " ").capitalize()

	if bonus_text == "":
		bonus_text = "[color=#888888]No bonuses listed[/color]"

	detail_bonuses_label.text = bonus_text

	# Unlock button visibility
	_update_unlock_button(spec)

func _format_bonus_section(title: String, bonuses: Dictionary) -> String:
	if bonuses.is_empty():
		return ""
	var text := "[color=#88ff88]%s:[/color]\n" % title
	for key: String in bonuses:
		var value = bonuses[key]
		var display_name: String = key.replace("_percent", "").replace("_", " ").capitalize()
		if typeof(value) == TYPE_BOOL:
			text += "  %s\n" % display_name
		else:
			text += "  +%d%% %s\n" % [int(value * 100), display_name]
	return text

func _update_unlock_button(spec: GodSpecialization) -> void:
	if not selected_god or not specialization_manager:
		unlock_button.visible = false
		return

	# Already unlocked?
	if spec.id in selected_god.specialization_path:
		unlock_button.visible = true
		unlock_button.text = "UNLOCKED"
		unlock_button.disabled = true
		return

	# Can unlock?
	if specialization_manager.can_god_unlock_specialization(selected_god, spec.id):
		unlock_button.visible = true
		unlock_button.text = "UNLOCK"
		unlock_button.disabled = false
	else:
		unlock_button.visible = true
		unlock_button.text = "LOCKED"
		unlock_button.disabled = true

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_back_pressed() -> void:
	back_pressed.emit()

func _on_god_selected(god: God) -> void:
	selected_god = god
	_update_role_tabs()
	_show_tree_for_god(god)
	_clear_detail_panel()

func _on_role_tab_pressed(role_id: String) -> void:
	# Update tab toggle states
	for child in role_tabs.get_children():
		if child is Button:
			child.button_pressed = (child.text.to_lower() == role_id)

	if selected_god:
		_show_tree_for_god(selected_god, role_id)
		_clear_detail_panel()

func _on_spec_node_selected(spec_id: String) -> void:
	_show_spec_details(spec_id)

func _on_unlock_pressed() -> void:
	if not selected_god or selected_spec_id == "" or not specialization_manager:
		return

	# TODO: Deduct costs via ResourceManager
	var success: bool = specialization_manager.unlock_specialization(selected_god, selected_spec_id)
	if success:
		# Refresh tree and details
		_show_tree_for_god(selected_god)
		_show_spec_details(selected_spec_id)

# ==============================================================================
# STYLING HELPERS
# ==============================================================================

func _apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
