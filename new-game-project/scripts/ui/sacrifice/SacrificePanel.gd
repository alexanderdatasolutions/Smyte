# scripts/ui/sacrifice/SacrificePanel.gd
# Single responsibility: Display selected god details and handle sacrifice action
class_name SacrificePanel
extends Node

signal sacrifice_requested(god: God)

var current_god: God
var god_display: Control
var sacrifice_button: Button
var details_label: Label

func create_panel() -> Control:
	var container = VBoxContainer.new()
	container.name = "SacrificePanel"
	container.custom_minimum_size = Vector2(300, 0)
	
	# Title
	var title = Label.new()
	title.text = "Sacrifice God"
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)
	
	# God display area
	god_display = Control.new()
	god_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(god_display)
	
	# Details
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(details_label)
	
	# Sacrifice button
	sacrifice_button = Button.new()
	sacrifice_button.text = "Sacrifice God"
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	container.add_child(sacrifice_button)
	
	return container

func display_god(god: God):
	current_god = god
	_update_display()

func clear_display():
	current_god = null
	_update_display()

func _update_display():
	if not current_god:
		sacrifice_button.disabled = true
		details_label.text = "Select a god to sacrifice"
		_clear_god_display()
		return
	
	sacrifice_button.disabled = false
	_show_god_details()
	_show_god_card()

func _show_god_details():
	var sacrifice_system = SystemRegistry.get_instance().get_system("SacrificeSystem")
	var rewards = sacrifice_system.preview_sacrifice_rewards(current_god.id)
	
	details_label.text = "Sacrificing %s will give you:\n" % current_god.name
	for resource in rewards:
		details_label.text += "• %d %s\n" % [rewards[resource], resource.capitalize()]

func _show_god_card():
	_clear_god_display()
	
	var ui_factory = SystemRegistry.get_instance().get_system("UICardFactory")
	var card = ui_factory.create_god_card(current_god)
	god_display.add_child(card)

func _clear_god_display():
	for child in god_display.get_children():
		child.queue_free()

func _on_sacrifice_pressed():
	if current_god:
		sacrifice_requested.emit(current_god)
