# scripts/ui/equipment/EquipmentInventoryManager.gd
# RULE 1 COMPLIANCE: Under 200 lines
# RULE 2 COMPLIANCE: Single responsibility - Equipment inventory display only
# RULE 4 COMPLIANCE: UI Only - no business logic
extends Control
class_name EquipmentInventoryUI

"""
Equipment Inventory Manager Component
Handles equipment inventory grid display and filtering
SINGLE RESPONSIBILITY: Equipment inventory interface only
"""

signal equipment_selected(equipment: Equipment)

@onready var inventory_grid: GridContainer
var equipment_manager: EquipmentManager
var selected_god: God = null
var selected_slot: int = -1

func _ready():
	_initialize_systems()

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		if not equipment_manager:
			push_error("EquipmentInventoryManager: Could not get EquipmentManager from SystemRegistry")
	else:
		push_error("EquipmentInventoryManager: Could not get SystemRegistry instance")

func set_inventory_grid(grid: GridContainer):
	"""Set the inventory grid reference"""
	inventory_grid = grid
	if is_node_ready():
		refresh_equipment_inventory()

func set_selected_god(god: God):
	"""Set the currently selected god"""
	selected_god = god
	refresh_equipment_inventory()

func set_selected_slot(slot: int):
	"""Set the selected equipment slot for filtering"""
	selected_slot = slot
	refresh_equipment_inventory()

func refresh_equipment_inventory():
	"""Refresh equipment inventory display"""
	if not inventory_grid or not equipment_manager or not selected_god:
		return
	
	print("EquipmentInventoryManager: _refresh_equipment_inventory called")
	
	# Clear existing children
	for child in inventory_grid.get_children():
		if child.name != "test_label":  # Keep debug label
			child.queue_free()
	
	# Get unequipped equipment
	var unequipped = equipment_manager.get_unequipped_equipment()
	print("EquipmentInventoryManager: Got %d unequipped equipment pieces" % unequipped.size())
	
	# Filter by selected slot if applicable
	var filtered_equipment = unequipped
	if selected_slot >= 0:
		filtered_equipment = unequipped.filter(func(eq): return eq.slot == selected_slot)
		print("EquipmentInventoryManager: After slot filter: %d equipment pieces" % filtered_equipment.size())
	
	# Create buttons for filtered equipment
	for equipment in filtered_equipment:
		print("EquipmentInventoryManager: Creating button for %s" % equipment.name)
		var button = _create_equipment_button(equipment)
		inventory_grid.add_child(button)

func _create_equipment_button(equipment: Equipment) -> Control:
	"""Create equipment card with PNG icon, stats, and set bonus indicators"""
	print("EquipmentInventoryManager: _create_equipment_button called for %s" % equipment.name)
	
	# Main container panel
	var container = Panel.new()
	container.custom_minimum_size = Vector2(180, 200)  # Larger for mobile
	
	# Modern card styling
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)  # Dark semi-transparent
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = _get_rarity_color(equipment.rarity)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	container.add_theme_stylebox_override("panel", card_style)
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 4)
	container.add_child(vbox)
	
	# PNG Icon
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(100, 100)
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(80, 80)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load PNG icon
	var icon_path = _get_equipment_icon_path(equipment)
	if FileAccess.file_exists(icon_path):
		var texture = load(icon_path)
		if texture:
			texture_rect.texture = texture
			print("EquipmentInventoryManager: Loaded PNG icon: %s" % icon_path)
		else:
			print("EquipmentInventoryManager: Failed to load PNG: %s" % icon_path)
	else:
		print("EquipmentInventoryManager: PNG file not found: %s" % icon_path)
		# Fallback colored rectangle
		var fallback_style = StyleBoxFlat.new()
		fallback_style.bg_color = _get_rarity_color(equipment.rarity)
		texture_rect.add_theme_stylebox_override("normal", fallback_style)
	
	icon_container.add_child(texture_rect)
	vbox.add_child(icon_container)
	
	# Equipment name
	var name_label = Label.new()
	name_label.text = equipment.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _get_rarity_color(equipment.rarity))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Main stat display
	var stat_label = Label.new()
	stat_label.text = "%s +%d" % [equipment.main_stat_type.capitalize(), equipment.main_stat_value]
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_font_size_override("font_size", 12)
	stat_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(stat_label)
	
	# Set bonus indicator
	if equipment.equipment_set_name != "":
		var set_label = Label.new()
		set_label.text = "Set: %s" % equipment.equipment_set_name
		set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_label.add_theme_font_size_override("font_size", 10)
		set_label.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(set_label)
	
	# Enhancement level indicator
	if equipment.level > 0:
		var enhance_label = Label.new()
		enhance_label.text = "+%d" % equipment.level
		enhance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enhance_label.add_theme_font_size_override("font_size", 12)
		enhance_label.add_theme_color_override("font_color", Color.GREEN)
		vbox.add_child(enhance_label)
	
	# Touch-friendly button overlay
	var button = Button.new()
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.flat = true  # Invisible button for touch
	button.pressed.connect(_on_equipment_button_pressed.bind(equipment))
	container.add_child(button)
	
	# Hover effect for desktop
	button.mouse_entered.connect(_on_equipment_hover_enter.bind(container))
	button.mouse_exited.connect(_on_equipment_hover_exit.bind(container))
	
	print("EquipmentInventoryManager: Created equipment card for %s" % equipment.name)
	return container

func _get_equipment_icon_path(equipment: Equipment) -> String:
	"""Get the PNG icon path for equipment"""
	# Check if equipment has explicit icon path
	if equipment.has_method("get_icon_path") and equipment.get_icon_path() != "":
		return equipment.get_icon_path()
	
	# Generate path based on equipment ID or name
	var clean_name = equipment.id.to_lower().replace(" ", "_")
	return "res://assets/equipment/%s.png" % clean_name

func _get_rarity_color(rarity: Equipment.Rarity) -> Color:
	"""Get color for equipment rarity"""
	match rarity:
		Equipment.Rarity.COMMON:
			return Color.WHITE
		Equipment.Rarity.RARE:
			return Color.CYAN
		Equipment.Rarity.EPIC:
			return Color.MAGENTA
		Equipment.Rarity.LEGENDARY:
			return Color.GOLD
		Equipment.Rarity.MYTHIC:
			return Color.RED
		_:
			return Color.GRAY

func _on_equipment_hover_enter(container: Panel):
	"""Handle hover enter for desktop"""
	var style = container.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(0.25, 0.25, 0.35, 0.95)  # Lighter on hover
	container.add_theme_stylebox_override("panel", style)

func _on_equipment_hover_exit(container: Panel):
	"""Handle hover exit for desktop"""
	var style = container.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)  # Return to normal
	container.add_theme_stylebox_override("panel", style)

func _on_equipment_button_pressed(equipment: Equipment):
	"""Handle equipment button press"""
	print("EquipmentInventoryManager: Equipment button pressed for %s" % equipment.name)
	equipment_selected.emit(equipment)

func clear_inventory():
	"""Clear all inventory buttons"""
	if not inventory_grid:
		return
		
	for child in inventory_grid.get_children():
		if child.name != "test_label":  # Keep debug label
			child.queue_free()
