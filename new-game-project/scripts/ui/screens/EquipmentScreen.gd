# scripts/ui/screens/EquipmentScreen.gd
# RULE 1 COMPLIANCE: Under 500 lines - Component Coordinator
# RULE 2 COMPLIANCE: Single responsibility - Equipment screen coordination
# RULE 4 COMPLIANCE: UI Only - Coordinates split UI components
extends Control
class_name EquipmentScreenUI

"""
Equipment Screen Coordinator
Coordinates the split equipment UI components to maintain RULE 1 compliance
Uses existing components: EquipmentGodSelector, EquipmentSlotManager, EquipmentInventoryUI, EquipmentStatsDisplay
NO BUSINESS LOGIC - pure component coordination
"""

signal back_pressed

var selected_god: God = null
var equipment_manager: EquipmentManager
var collection_manager: CollectionManager

# Split UI Component References
var god_selector: EquipmentGodSelector
var slot_manager: EquipmentSlotManager
var inventory_manager: EquipmentInventoryDisplay
var stats_display: EquipmentStatsDisplay

# UI References from scene - Core Layout
@onready var back_button = $BackButton
@onready var main_container = $MainContainer

# UI References - Component containers
@onready var god_selection_panel = $MainContainer/LeftPanel/GodContainer
@onready var god_grid = $MainContainer/LeftPanel/GodContainer/ScrollContainer/GodGrid
@onready var selected_god_panel = $MainContainer/CenterPanel/SelectedGodPanel
@onready var god_name_label = $MainContainer/CenterPanel/SelectedGodPanel/VBox/GodNameLabel
@onready var god_stats_container = $MainContainer/CenterPanel/SelectedGodPanel/VBox/StatsContainer
@onready var equipment_slots_container = $MainContainer/CenterPanel/SelectedGodPanel/VBox/EquipmentContainer/EquipmentSlotsGrid
@onready var equipment_panel = $MainContainer/RightPanel/InventoryPanel
@onready var inventory_grid = $MainContainer/RightPanel/InventoryPanel/VBox/ScrollContainer/InventoryGrid

func _ready():
	_setup_fullscreen()
	_initialize_systems()
	_initialize_components()
	_connect_signals()
	_style_center_panel()
	_style_back_button()

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _style_back_button():
	"""Style the back button to match dark fantasy theme"""
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

func _initialize_systems():
	"""Initialize system references - RULE 5: SystemRegistry only"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		collection_manager = system_registry.get_system("CollectionManager")
		
		if not equipment_manager:
			push_error("EquipmentScreen: Could not get EquipmentManager from SystemRegistry")
		if not collection_manager:
			push_error("EquipmentScreen: Could not get CollectionManager from SystemRegistry")
	else:
		push_error("EquipmentScreen: Could not get SystemRegistry instance")

func _initialize_components():
	"""Initialize and configure split UI components"""
	# Create and setup God Selector component
	god_selector = EquipmentGodSelector.new()
	god_selector.name = "GodSelector"
	god_selection_panel.add_child(god_selector)
	god_selector.set_god_grid(god_grid)
	
	# Create and setup Slot Manager component
	slot_manager = EquipmentSlotManager.new()
	slot_manager.name = "SlotManager"
	selected_god_panel.add_child(slot_manager)
	slot_manager.set_equipment_slots_container(equipment_slots_container)
	
	# Create and setup Inventory Manager component
	inventory_manager = EquipmentInventoryDisplay.new()
	inventory_manager.name = "InventoryManager"
	equipment_panel.add_child(inventory_manager)
	inventory_manager.set_inventory_grid(inventory_grid)
	
	# Create and setup Stats Display component
	stats_display = EquipmentStatsDisplay.new()
	stats_display.name = "StatsDisplay"
	selected_god_panel.add_child(stats_display)
	stats_display.set_ui_references(god_name_label, god_stats_container)

func _connect_signals():
	"""Connect component signals"""
	# Back button
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# God selector signals
	if god_selector:
		god_selector.god_selected.connect(_on_god_selected)
	
	# Slot manager signals
	if slot_manager:
		slot_manager.equipment_slot_selected.connect(_on_equipment_slot_selected)
		slot_manager.equipment_unequip_requested.connect(_on_equipment_unequip_requested)
	
	# Inventory manager signals
	if inventory_manager:
		inventory_manager.equipment_selected.connect(_on_equipment_selected)

# Signal Handlers - Component coordination only
func _on_god_selected(god: God):
	"""Handle god selection from god selector component"""
	selected_god = god
	
	# Update all components with new god selection
	if slot_manager:
		slot_manager.set_selected_god(god)
	if inventory_manager:
		inventory_manager.set_selected_god(god)
	if stats_display:
		stats_display.set_selected_god(god)

func _on_equipment_slot_selected(slot_index: int):
	"""Handle equipment slot selection from slot manager"""
	# Filter inventory to show compatible equipment
	if inventory_manager:
		inventory_manager.set_selected_slot(slot_index)

func _on_equipment_unequip_requested(slot_index: int):
	"""Handle unequip request from slot manager"""
	if not selected_god or not equipment_manager:
		return

	# Unequip using equipment manager
	var success = equipment_manager.unequip_equipment_from_god(selected_god, slot_index)
	if success:
		_refresh_all_components()

func _on_equipment_selected(equipment: Equipment):
	"""Handle equipment selection from inventory manager"""
	if not selected_god or not equipment_manager:
		return

	# Equip using equipment manager - use correct method name and slot parameter
	var equipment_slot = equipment.slot - 1  # Convert from 1-indexed slot to 0-indexed array
	var success = equipment_manager.equip_equipment_to_god(selected_god, equipment, equipment_slot)
	if success:
		_refresh_all_components()

func _on_back_button_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func _refresh_all_components():
	"""Refresh all UI components after equipment changes"""
	if slot_manager:
		slot_manager.refresh()
	if inventory_manager:
		inventory_manager.refresh_equipment_inventory()
	if stats_display and selected_god:
		stats_display.set_selected_god(selected_god)

# Public interface for external systems
func refresh_display():
	"""Refresh the entire display - called by external systems"""
	_refresh_all_components()

func set_selected_god(god: God):
	"""Set selected god externally"""
	if god_selector:
		god_selector.select_god(god)

func _style_center_panel():
	"""Apply lighter background styling to center panel"""
	if selected_god_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.28, 0.28, 0.32)  # Lighter than default dark panel
		panel_style.set_border_width_all(1)
		panel_style.border_color = Color(0.4, 0.4, 0.45)
		selected_god_panel.add_theme_stylebox_override("panel", panel_style)
