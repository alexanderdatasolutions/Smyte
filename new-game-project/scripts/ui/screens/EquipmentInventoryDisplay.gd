# scripts/ui/screens/EquipmentInventoryDisplay.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - Equipment inventory display only
# RULE 4 COMPLIANCE: UI Only - no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control
class_name EquipmentInventoryDisplay

"""
Equipment Inventory Display Component
Handles equipment inventory visualization and selection
Pure UI component for equipment inventory management
"""

signal equipment_selected(equipment: Equipment)
signal equip_requested()

# UI References
var inventory_grid: GridContainer
var info_panel: VBoxContainer
var equipment_preview_panel: VBoxContainer

# Selected state
var selected_equipment: Equipment = null
var filter_slot_type: int = -1  # Filter by equipment slot type

# Systems - accessed through SystemRegistry (RULE 5)
var equipment_manager: EquipmentManager

func _ready():
	"""Initialize inventory display"""
	_initialize_systems()
	_setup_info_panel()

func _initialize_systems():
	"""Get system references through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		
		if not equipment_manager:
			push_error("EquipmentInventoryDisplay: Could not get EquipmentManager from SystemRegistry")
	else:
		push_error("EquipmentInventoryDisplay: Could not get SystemRegistry instance")

func _setup_info_panel():
	"""Setup equipment info panel"""
	# Create info panel for equipment details
	info_panel = VBoxContainer.new()
	info_panel.name = "EquipmentInfoPanel"
	info_panel.custom_minimum_size = Vector2(200, 300)
	add_child(info_panel)
	
	# Move it to the top
	move_child(info_panel, 0)

func set_slot_filter(slot_type: int):
	"""Set filter to show only equipment for specific slot"""
	filter_slot_type = slot_type
	refresh_inventory()

func clear_slot_filter():
	"""Clear slot filter to show all equipment"""
	filter_slot_type = -1
	refresh_inventory()

func refresh_inventory():
	"""Refresh equipment inventory display - RULE 4: UI display only"""
	if not inventory_grid or not equipment_manager:
		return
	
	# Clear existing inventory
	for child in inventory_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get equipment from inventory
	var all_equipment = equipment_manager.get_unequipped_equipment()
	var display_equipment = []
	
	# Filter by slot type if specified
	if filter_slot_type != -1:
		for equipment in all_equipment:
			if equipment and get_slot_for_equipment_type(equipment.type) == filter_slot_type:
				display_equipment.append(equipment)
	else:
		display_equipment = all_equipment.duplicate()
	
	# Create equipment buttons
	for equipment in display_equipment:
		if equipment != null:
			create_equipment_button(equipment)
	
	# Ensure proper sizing
	if inventory_grid:
		var scroll_container = inventory_grid.get_parent()
		if scroll_container and scroll_container.size.y <= 0:
			scroll_container.custom_minimum_size = Vector2(280, 300)

func create_equipment_button(equipment: Equipment):
	"""Create equipment button - RULE 4: UI creation only"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 140)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Try to load PNG icon first
	var icon_path = "res://assets/equipment/" + equipment.id + ".png"
	var texture = load(icon_path) as Texture2D
	
	if texture:
		button.icon = texture
	else:
		# Fallback to text-based display
		button.text = equipment.name
	
	# Set up god card style with proper rarity colors
	var rarity_color = get_rarity_color(equipment.rarity)
	var subtle_color = get_subtle_rarity_color(equipment.rarity)
	
	# Main style (normal state)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = subtle_color
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = rarity_color
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	button.add_theme_stylebox_override("normal", style_box)
	
	# Hover style (brighter)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(subtle_color.r * 1.5, subtle_color.g * 1.5, subtle_color.b * 1.5)
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = rarity_color
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Selection style (if this equipment is selected)
	if equipment == selected_equipment:
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(rarity_color.r * 0.3, rarity_color.g * 0.3, rarity_color.b * 0.3)
		selected_style.border_width_left = 4
		selected_style.border_width_right = 4
		selected_style.border_width_top = 4
		selected_style.border_width_bottom = 4
		selected_style.border_color = Color.CYAN
		selected_style.corner_radius_top_left = 8
		selected_style.corner_radius_top_right = 8
		selected_style.corner_radius_bottom_left = 8
		selected_style.corner_radius_bottom_right = 8
		
		button.add_theme_stylebox_override("normal", selected_style)
	
	# Create info overlay (bottom section with text)
	var info_container = VBoxContainer.new()
	info_container.position = Vector2(5, 95)
	info_container.size = Vector2(110, 40)
	info_container.add_theme_constant_override("separation", 1)
	
	# Equipment name (shortened if needed)
	var name_label = Label.new()
	name_label.text = equipment.name
	if equipment.name.length() > 12:
		name_label.text = equipment.name.substr(0, 10) + "..."
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = rarity_color
	info_container.add_child(name_label)
	
	# Type and level info
	var type_label = Label.new()
	type_label.text = "%s +%d" % [get_equipment_type_name(equipment.type), equipment.enhancement_level]
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.modulate = Color(0.9, 0.9, 0.9)
	info_container.add_child(type_label)
	
	# Rarity stars
	var stars_label = Label.new()
	stars_label.text = get_rarity_stars(equipment.rarity)
	stars_label.add_theme_font_size_override("font_size", 12)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.modulate = rarity_color
	info_container.add_child(stars_label)
	
	button.add_child(info_container)
	
	# Connect button press
	button.pressed.connect(_on_equipment_button_pressed.bind(equipment))
	
	inventory_grid.add_child(button)

func _on_equipment_button_pressed(equipment: Equipment):
	"""Handle equipment selection"""
	selected_equipment = equipment
	equipment_selected.emit(equipment)
	show_equipment_details(equipment)
	refresh_inventory()  # Refresh to show selection state

func show_equipment_details(equipment: Equipment):
	"""Display equipment details in info panel - RULE 4: UI display only"""
	if not info_panel:
		return
	
	# Clear existing info
	for child in info_panel.get_children():
		child.queue_free()
	
	# Equipment name and stars
	var name_label = Label.new()
	name_label.text = equipment.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = get_rarity_color(equipment.rarity)
	info_panel.add_child(name_label)
	
	var stars_label = Label.new()
	stars_label.text = get_rarity_stars(equipment.rarity) + " " + get_rarity_name(equipment.rarity)
	stars_label.add_theme_font_size_override("font_size", 12)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.modulate = get_rarity_color(equipment.rarity)
	info_panel.add_child(stars_label)
	
	# Type and level info
	var type_label = Label.new()
	type_label.text = "Level %d %s (+%d)" % [equipment.level, get_equipment_type_name(equipment.type), equipment.enhancement_level]
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_panel.add_child(type_label)
	
	# Main stat
	if not equipment.main_stat_type.is_empty():
		var main_stat_label = Label.new()
		main_stat_label.text = "Main: %s +%d" % [equipment.main_stat_type, equipment.main_stat_value]
		main_stat_label.add_theme_font_size_override("font_size", 12)
		main_stat_label.modulate = Color.GOLD
		info_panel.add_child(main_stat_label)
	
	# Substats
	if not equipment.substats.is_empty():
		var substats_label = Label.new()
		substats_label.text = "Substats:"
		substats_label.add_theme_font_size_override("font_size", 11)
		substats_label.modulate = Color(0.8, 0.8, 0.8)
		info_panel.add_child(substats_label)
		
		for substat in equipment.substats:
			var substat_label = Label.new()
			substat_label.text = "  %s: +%s" % [substat.type, str(substat.value)]
			substat_label.add_theme_font_size_override("font_size", 10)
			info_panel.add_child(substat_label)
	
	# Equipment set info
	if not equipment.equipment_set_name.is_empty():
		var set_label = Label.new()
		set_label.text = "Set: " + equipment.equipment_set_name
		set_label.add_theme_font_size_override("font_size", 11)
		set_label.modulate = Color.CYAN
		info_panel.add_child(set_label)
	
	# Equip button
	var equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.custom_minimum_size = Vector2(100, 30)
	equip_button.pressed.connect(_on_equip_button_pressed)
	info_panel.add_child(equip_button)

func _on_equip_button_pressed():
	"""Handle equip button press"""
	if selected_equipment:
		equip_requested.emit()

func get_slot_for_equipment_type(type: Equipment.EquipmentType) -> int:
	"""Get slot index for equipment type - RULE 4: UI helper"""
	match type:
		Equipment.EquipmentType.WEAPON: return 0
		Equipment.EquipmentType.ARMOR: return 1
		Equipment.EquipmentType.HELM: return 2
		Equipment.EquipmentType.BOOTS: return 3
		Equipment.EquipmentType.AMULET: return 4
		Equipment.EquipmentType.RING: return 5
		_: return -1

func get_equipment_type_name(type: Equipment.EquipmentType) -> String:
	"""Get equipment type display name - RULE 4: UI helper"""
	match type:
		Equipment.EquipmentType.WEAPON: return "Weapon"
		Equipment.EquipmentType.ARMOR: return "Armor"
		Equipment.EquipmentType.HELM: return "Helmet"
		Equipment.EquipmentType.BOOTS: return "Boots"
		Equipment.EquipmentType.AMULET: return "Amulet"
		Equipment.EquipmentType.RING: return "Ring"
		_: return "Unknown"

func get_rarity_color(rarity: Equipment.Rarity) -> Color:
	"""Get rarity color - RULE 4: UI helper"""
	match rarity:
		Equipment.Rarity.COMMON: return Color(0.6, 0.6, 0.6, 1.0)
		Equipment.Rarity.RARE: return Color(0.2, 0.8, 0.2, 1.0)
		Equipment.Rarity.EPIC: return Color(0.5, 0.3, 0.8, 1.0)
		Equipment.Rarity.LEGENDARY: return Color(0.9, 0.7, 0.1, 1.0)
		_: return Color.WHITE

func get_subtle_rarity_color(rarity: Equipment.Rarity) -> Color:
	"""Get subtle background color for equipment rarity"""
	match rarity:
		Equipment.Rarity.COMMON: return Color(0.2, 0.2, 0.2, 0.8)
		Equipment.Rarity.RARE: return Color(0.1, 0.25, 0.1, 0.8)
		Equipment.Rarity.EPIC: return Color(0.2, 0.1, 0.3, 0.8)
		Equipment.Rarity.LEGENDARY: return Color(0.3, 0.25, 0.05, 0.8)
		_: return Color(0.15, 0.15, 0.15, 0.8)

func get_rarity_stars(rarity: Equipment.Rarity) -> String:
	"""Get star display for equipment rarity"""
	match rarity:
		Equipment.Rarity.COMMON: return "⭐"
		Equipment.Rarity.RARE: return "⭐⭐"
		Equipment.Rarity.EPIC: return "⭐⭐⭐"
		Equipment.Rarity.LEGENDARY: return "⭐⭐⭐⭐"
		_: return "⭐"

func get_rarity_name(rarity: Equipment.Rarity) -> String:
	"""Get display name for equipment rarity"""
	match rarity:
		Equipment.Rarity.COMMON: return "Common"
		Equipment.Rarity.RARE: return "Rare"
		Equipment.Rarity.EPIC: return "Epic"
		Equipment.Rarity.LEGENDARY: return "Legendary"
		_: return "Unknown"

# Compatibility methods for EquipmentScreen integration
func set_inventory_grid(grid: GridContainer):
	"""Set the inventory grid reference"""
	inventory_grid = grid
	if is_node_ready():
		refresh_inventory()

func set_selected_god(_god: God):
	"""Set currently selected god - for context"""
	# This display doesn't need the god reference directly
	# But we can refresh inventory when god changes
	refresh_inventory()

func set_selected_slot(slot_index: int):
	"""Set selected slot for filtering compatible equipment"""
	set_slot_filter(slot_index)

func refresh_equipment_inventory():
	"""Refresh the equipment inventory display"""
	refresh_inventory()
