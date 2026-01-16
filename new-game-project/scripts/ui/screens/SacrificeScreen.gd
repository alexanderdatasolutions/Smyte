# scripts/ui/screens/SacrificeScreen.gd
# Main sacrifice screen coordinator - delegates to tab builders
extends Control

signal back_pressed

const SacrificeTabBuilder = preload("res://scripts/ui/sacrifice/SacrificeTabBuilder.gd")
const AwakeningTabBuilder = preload("res://scripts/ui/sacrifice/AwakeningTabBuilder.gd")

@onready var back_button = $BackButton
@onready var tab_container = $ContentContainer/TabContainer

# Tab builders
var sacrifice_tab_builder: SacrificeTabBuilder = null
var awakening_tab_builder: AwakeningTabBuilder = null

# System references
var collection_manager: CollectionManager
var awakening_system: AwakeningSystem
var resource_manager: ResourceManager

func _ready():
	"""Initialize the sacrifice screen"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return

	awakening_system = system_registry.get_system("AwakeningSystem")
	if not awakening_system:
		return

	resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return

	setup_tabbed_interface()
	
func setup_tabbed_interface():
	"""Create the tabbed interface using builder components"""
	if not tab_container:
		return

	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	# Style tabs to show active state indicator
	_style_tab_container()

	# Create sacrifice tab using builder
	sacrifice_tab_builder = SacrificeTabBuilder.create_sacrifice_tab(tab_container, collection_manager)
	sacrifice_tab_builder.sacrifice_requested.connect(_on_sacrifice_requested)

	# Create awakening tab using builder
	awakening_tab_builder = AwakeningTabBuilder.create_awakening_tab(tab_container,
		collection_manager, awakening_system, resource_manager)
	awakening_tab_builder.god_awakened.connect(_on_god_awakened)

func _style_tab_container():
	"""Add visual indicator for active tab"""
	if not tab_container:
		return

	# Create StyleBoxFlat for selected tab
	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = Color(0.3, 0.3, 0.35, 0.8)  # Slightly lighter
	tab_selected.border_color = Color(0.6, 0.8, 1.0)  # Light blue underline
	tab_selected.set_border_width_all(0)
	tab_selected.border_width_bottom = 3  # Underline effect

	# Create StyleBoxFlat for unselected tabs
	var tab_unselected = StyleBoxFlat.new()
	tab_unselected.bg_color = Color(0.2, 0.2, 0.25, 0.6)  # Darker
	tab_unselected.set_border_width_all(0)

	# Create StyleBoxFlat for hover state
	var tab_hover = StyleBoxFlat.new()
	tab_hover.bg_color = Color(0.25, 0.25, 0.3, 0.7)  # Medium brightness
	tab_hover.set_border_width_all(0)

	# Apply styles
	tab_container.add_theme_stylebox_override("tab_selected", tab_selected)
	tab_container.add_theme_stylebox_override("tab_unselected", tab_unselected)
	tab_container.add_theme_stylebox_override("tab_hovered", tab_hover)
	tab_container.add_theme_font_size_override("font_size", 16)  # Increase tab text to 16px
	tab_container.add_theme_constant_override("h_separation", 12)  # Add 12px horizontal spacing between tabs

func _on_sacrifice_requested(god: God):
	"""Handle sacrifice request from sacrifice tab"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			sacrifice_manager.set_temporary_target_god(god)

		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("sacrifice_selection")

func _on_god_awakened(_god: God):
	"""Handle god awakened from awakening tab"""
	# Refresh sacrifice tab in case awakened god affects sacrifice options
	if sacrifice_tab_builder:
		sacrifice_tab_builder.refresh_god_list()

func _on_back_pressed():
	"""Handle back button"""
	back_pressed.emit()
