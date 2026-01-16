# scripts/ui/sacrifice/AwakeningPanel.gd
# Awakening details panel - following modular pattern like SacrificePanel
class_name AwakeningPanel
extends Control

signal awakening_requested(god: God)

# UI Components
var target_god_display: Control
var requirements_container: Control
var materials_display: Control
var awakening_button: Button

# State
var current_target_god: God

# System references
var sacrifice_manager: SacrificeManager
var awakening_system: AwakeningSystem

func _ready():
	_initialize_systems()
	_setup_ui()

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	sacrifice_manager = system_registry.get_system("SacrificeManager")
	awakening_system = system_registry.get_system("AwakeningSystem")

func _setup_ui():
	"""Setup the awakening panel UI"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Awaken Gods"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)
	
	# Target god display
	_create_target_god_display(main_vbox)
	
	# Requirements section
	_create_requirements_section(main_vbox)
	
	# Materials display
	_create_materials_display(main_vbox)
	
	# Awakening button
	_create_awakening_button(main_vbox)

func _create_target_god_display(parent: Control):
	"""Create the target god display area"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	
	var label = Label.new()
	label.text = "Selected God:"
	label.add_theme_font_size_override("font_size", 16)
	section.add_child(label)
	
	target_god_display = Panel.new()
	target_god_display.custom_minimum_size = Vector2(280, 100)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.2, 0.4, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.6, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	target_god_display.add_theme_stylebox_override("panel", style)
	
	section.add_child(target_god_display)

func _create_requirements_section(parent: Control):
	"""Create the requirements display section"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	
	var label = Label.new()
	label.text = "Requirements:"
	label.add_theme_font_size_override("font_size", 16)
	section.add_child(label)
	
	requirements_container = VBoxContainer.new()
	requirements_container.add_theme_constant_override("separation", 5)
	section.add_child(requirements_container)

func _create_materials_display(parent: Control):
	"""Create materials display section"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	
	var label = Label.new()
	label.text = "Required Materials:"
	label.add_theme_font_size_override("font_size", 16)
	section.add_child(label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	section.add_child(scroll)
	
	materials_display = VBoxContainer.new()
	materials_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	materials_display.add_theme_constant_override("separation", 5)
	scroll.add_child(materials_display)

func _create_awakening_button(parent: Control):
	"""Create the awakening button"""
	awakening_button = Button.new()
	awakening_button.text = "AWAKEN GOD"
	awakening_button.custom_minimum_size = Vector2(250, 50)
	awakening_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	awakening_button.disabled = true
	awakening_button.pressed.connect(_on_awakening_pressed)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.6, 0.3, 0.8, 0.9)
	button_style.border_color = Color(1.0, 0.5, 1.0, 1.0)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	awakening_button.add_theme_stylebox_override("normal", button_style)
	
	parent.add_child(awakening_button)

# === PUBLIC INTERFACE ===

func set_target_god(god: God):
	"""Set the target god for awakening"""
	current_target_god = god
	_update_target_display()
	_update_requirements()
	_update_materials_display()
	_update_button_state()

func refresh_display():
	"""Refresh the entire display"""
	_update_target_display()
	_update_requirements()
	_update_materials_display()
	_update_button_state()

# === PRIVATE METHODS ===

func _update_target_display():
	"""Update the target god display"""
	# Clear existing content
	for child in target_god_display.get_children():
		child.queue_free()
	
	if not current_target_god:
		var no_selection_label = Label.new()
		no_selection_label.text = "Select a god from the list to awaken"
		no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_selection_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		no_selection_label.modulate = Color.GRAY
		target_god_display.add_child(no_selection_label)
		return
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	target_god_display.add_child(hbox)
	
	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(64, 64)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var god_texture = current_target_god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	hbox.add_child(god_image)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = current_target_god.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.ORANGE)
	info_vbox.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = "Level %d" % current_target_god.level
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.modulate = Color.CYAN
	info_vbox.add_child(level_label)
	
	var details_label = Label.new()
	details_label.text = "%s %s" % [current_target_god.get_tier_name(), current_target_god.get_element_name()]
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.modulate = Color.LIGHT_GRAY
	info_vbox.add_child(details_label)

func _update_requirements():
	"""Update the requirements display"""
	# Clear existing requirements
	for child in requirements_container.get_children():
		child.queue_free()
	
	if not current_target_god:
		var no_god_label = Label.new()
		no_god_label.text = "Select a god to see awakening requirements"
		no_god_label.modulate = Color.GRAY
		requirements_container.add_child(no_god_label)
		return
	
	if not sacrifice_manager:
		var error_label = Label.new()
		error_label.text = "SacrificeManager not available"
		error_label.modulate = Color.RED
		requirements_container.add_child(error_label)
		return
	
	# Get requirements
	var requirements = sacrifice_manager.get_awakening_requirements(current_target_god)
	
	# Basic requirements
	var level_req = Label.new()
	level_req.text = "• Level 40 (Max Level): %s" % ("✓" if current_target_god.level >= 40 else "✗")
	level_req.modulate = Color.GREEN if current_target_god.level >= 40 else Color.RED
	requirements_container.add_child(level_req)
	
	var tier_req = Label.new()
	var tier_ok = current_target_god.tier >= 4  # Assuming Epic/Legendary is tier 4+
	tier_req.text = "• Epic/Legendary Tier: %s" % ("✓" if tier_ok else "✗")
	tier_req.modulate = Color.GREEN if tier_ok else Color.RED
	requirements_container.add_child(tier_req)
	
	# Can awaken status
	var can_awaken_label = Label.new()
	if requirements.can_awaken:
		can_awaken_label.text = "✓ Ready for Awakening!"
		can_awaken_label.modulate = Color.GREEN
	else:
		can_awaken_label.text = "✗ Requirements not met:"
		can_awaken_label.modulate = Color.RED
		
		for requirement in requirements.get("missing_requirements", []):
			var missing_label = Label.new()
			missing_label.text = "  - %s" % requirement
			missing_label.modulate = Color.ORANGE
			requirements_container.add_child(missing_label)
	
	requirements_container.add_child(can_awaken_label)

func _update_materials_display():
	"""Update the materials display"""
	# Clear existing materials
	for child in materials_display.get_children():
		child.queue_free()
	
	if not current_target_god:
		var no_god_label = Label.new()
		no_god_label.text = "Select a god to see required materials"
		no_god_label.modulate = Color.GRAY
		no_god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_display.add_child(no_god_label)
		return
	
	if not sacrifice_manager:
		var error_label = Label.new()
		error_label.text = "SacrificeManager not available"
		error_label.modulate = Color.RED
		materials_display.add_child(error_label)
		return
	
	# Get materials cost
	var materials = sacrifice_manager.get_awakening_materials_cost(current_target_god)
	
	if materials.is_empty():
		var no_materials_label = Label.new()
		no_materials_label.text = "No additional materials required"
		no_materials_label.modulate = Color.GREEN
		no_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_display.add_child(no_materials_label)
		return
	
	# Check materials availability
	var materials_check = sacrifice_manager.check_awakening_materials(materials)
	
	# Display each material requirement
	for material_type in materials:
		var needed_amount = materials[material_type]
		var material_item = _create_material_requirement_item(material_type, needed_amount, materials_check)
		materials_display.add_child(material_item)

func _create_material_requirement_item(material_type: String, needed_amount: int, materials_check: Dictionary) -> Control:
	"""Create a material requirement item display"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(0, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.25, 0.8)
	style.border_color = Color(0.4, 0.4, 0.6, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	item.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	item.add_child(hbox)
	
	# Material name
	var name_label = Label.new()
	name_label.text = _format_material_name(material_type)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	# Amount needed
	var amount_label = Label.new()
	amount_label.text = "Need: %d" % needed_amount
	amount_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(amount_label)
	
	# Status indicator
	var status_label = Label.new()
	var has_enough = materials_check.get("has_materials", false)
	status_label.text = "✓" if has_enough else "✗"
	status_label.modulate = Color.GREEN if has_enough else Color.RED
	hbox.add_child(status_label)
	
	return item

func _format_material_name(material_type: String) -> String:
	"""Format material name for display"""
	# Convert snake_case to Title Case
	return material_type.replace("_", " ").capitalize()

func _update_button_state():
	"""Update the awakening button state"""
	var can_awaken = false
	
	if current_target_god and sacrifice_manager:
		var requirements = sacrifice_manager.get_awakening_requirements(current_target_god)
		can_awaken = requirements.can_awaken
	
	awakening_button.disabled = not can_awaken
	
	if can_awaken:
		awakening_button.text = "AWAKEN %s" % (current_target_god.name if current_target_god else "GOD")
	else:
		awakening_button.text = "AWAKEN GOD"

# === SIGNAL HANDLERS ===

func _on_awakening_pressed():
	"""Handle awakening button pressed"""
	if current_target_god:
		awakening_requested.emit(current_target_god)
