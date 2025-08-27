# scripts/ui/sacrifice/AwakeningPanel.gd
# Single responsibility: Display selected god awakening details and handle awakening
class_name AwakeningPanel
extends Node

signal awakening_requested(god: God)

var current_god: God
var god_display: Control
var awakening_button: Button
var materials_display: Control
var requirements_label: Label

func create_panel() -> Control:
	var container = VBoxContainer.new()
	container.name = "AwakeningPanel"
	container.custom_minimum_size = Vector2(300, 0)
	
	# Title
	var title = Label.new()
	title.text = "Awaken God"
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)
	
	# God display area
	god_display = Control.new()
	god_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(god_display)
	
	# Requirements
	requirements_label = Label.new()
	requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(requirements_label)
	
	# Materials display
	materials_display = VBoxContainer.new()
	container.add_child(materials_display)
	
	# Awakening button
	awakening_button = Button.new()
	awakening_button.text = "Awaken God"
	awakening_button.disabled = true
	awakening_button.pressed.connect(_on_awakening_pressed)
	container.add_child(awakening_button)
	
	return container

func display_god(god: God):
	current_god = god
	_update_display()

func clear_display():
	current_god = null
	_update_display()

func _update_display():
	if not current_god:
		awakening_button.disabled = true
		requirements_label.text = "Select a god to awaken"
		_clear_displays()
		return
	
	_show_god_card()
	_show_requirements()
	_update_button_state()

func _show_god_card():
	_clear_god_display()
	
	var ui_factory = SystemRegistry.get_instance().get_system("UICardFactory")
	var card = ui_factory.create_god_card(current_god)
	god_display.add_child(card)

func _show_requirements():
	var awakening_system = SystemRegistry.get_instance().get_system("AwakeningSystem")
	var requirements = awakening_system.get_awakening_requirements(current_god.id)
	
	requirements_label.text = "Requirements to awaken %s:\n" % current_god.name
	
	_clear_materials_display()
	for material in requirements:
		var material_item = _create_material_requirement_item(material, requirements[material])
		materials_display.add_child(material_item)

func _create_material_requirement_item(material_id: String, required_amount: int) -> Control:
	var item = HBoxContainer.new()
	
	var icon = TextureRect.new()  # Would load material icon
	item.add_child(icon)
	
	var label = Label.new()
	var inventory_manager = SystemRegistry.get_instance().get_system("InventoryManager")
	var current_amount = inventory_manager.get_item_count(material_id)
	
	label.text = "%s: %d/%d" % [material_id.capitalize(), current_amount, required_amount]
	if current_amount >= required_amount:
		label.modulate = Color.GREEN
	else:
		label.modulate = Color.RED
	
	item.add_child(label)
	return item

func _update_button_state():
	var awakening_system = SystemRegistry.get_instance().get_system("AwakeningSystem")
	var can_awaken = awakening_system.can_awaken_god(current_god.id)
	awakening_button.disabled = not can_awaken

func _clear_displays():
	_clear_god_display()
	_clear_materials_display()

func _clear_god_display():
	for child in god_display.get_children():
		child.queue_free()

func _clear_materials_display():
	for child in materials_display.get_children():
		child.queue_free()

func _on_awakening_pressed():
	if current_god:
		awakening_requested.emit(current_god)
