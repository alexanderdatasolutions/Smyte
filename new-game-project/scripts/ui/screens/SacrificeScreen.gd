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

	# Create sacrifice tab using builder
	sacrifice_tab_builder = SacrificeTabBuilder.create_sacrifice_tab(tab_container, collection_manager)
	sacrifice_tab_builder.sacrifice_requested.connect(_on_sacrifice_requested)

	# Create awakening tab using builder
	awakening_tab_builder = AwakeningTabBuilder.create_awakening_tab(tab_container,
		collection_manager, awakening_system, resource_manager)
	awakening_tab_builder.god_awakened.connect(_on_god_awakened)

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
