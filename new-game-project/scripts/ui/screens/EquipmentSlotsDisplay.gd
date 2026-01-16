# scripts/ui/screens/EquipmentSlotsDisplay.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - Equipment slots display only
# RULE 4 COMPLIANCE: UI Only - no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control
class_name EquipmentSlotsDisplay

"""
Equipment Slots Display Component
Handles equipment slot visualization and interaction
Pure UI component for equipment slot management
"""

signal equipment_slot_selected(slot_index: int)

# UI References
@onready var equipment_slots_container = $EquipmentSlotsGrid

# Selected state
var selected_god: God = null
var selected_equipment_slot: int = -1

# Systems - accessed through SystemRegistry (RULE 5)
var equipment_manager: EquipmentManager

func _ready():
	"""Initialize equipment slots display"""
	_initialize_systems()

func _initialize_systems():
	"""Get system references through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		
		if not equipment_manager:
			push_error("EquipmentSlotsDisplay: Could not get EquipmentManager from SystemRegistry")
	else:
		push_error("EquipmentSlotsDisplay: Could not get SystemRegistry instance")

func set_selected_god(god: God):
	"""Set the currently selected god"""
	selected_god = god
	refresh_equipped_slots()

func refresh_equipped_slots():
	"""Refresh equipment slots display - RULE 4: UI display only"""
	if not selected_god or not equipment_slots_container or not equipment_manager:
		return
	
	# Clear existing slots
	for child in equipment_slots_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Equipment slot names
	var slot_names = ["Weapon", "Helmet", "Armor", "Boots", "Accessory 1", "Accessory 2"]
	
	# Create equipment slot buttons
	for i in range(6):
		var slot_button = create_equipment_slot_button(i, slot_names[i])
		equipment_slots_container.add_child(slot_button)

func create_equipment_slot_button(slot_index: int, slot_name: String) -> Button:
	"""Create equipment slot button - RULE 4: UI creation only"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 120)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Get equipped equipment
	var equipped_equipment = get_equipped_equipment_for_slot(slot_index)
	
	if equipped_equipment:
		# Equipment is equipped
		var rarity_color = get_rarity_color(equipped_equipment.rarity)
		var subtle_color = get_subtle_rarity_color(equipped_equipment.rarity)
		
		# Try to load PNG icon
		var icon_path = "res://assets/equipment/" + equipped_equipment.icon_path + ".png"
		var texture = load(icon_path) as Texture2D
		
		if texture:
			button.icon = texture
		else:
			# Fallback to text-based display
			button.text = equipped_equipment.name
		
		# Set colors - modulate affects the entire button appearance
		# Use a subtle background tint instead
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = subtle_color
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = rarity_color
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_left = 4
		style_box.corner_radius_bottom_right = 4
		
		button.add_theme_stylebox_override("normal", style_box)
		
		# Create hover style
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(subtle_color.r * 1.2, subtle_color.g * 1.2, subtle_color.b * 1.2)
		hover_style.border_width_left = 3
		hover_style.border_width_right = 3
		hover_style.border_width_top = 3
		hover_style.border_width_bottom = 3
		hover_style.border_color = rarity_color
		hover_style.corner_radius_top_left = 4
		hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_left = 4
		hover_style.corner_radius_bottom_right = 4
		
		button.add_theme_stylebox_override("hover", hover_style)
		
		# Equipment info label
		var info_label = Label.new()
		info_label.text = "%s\n+%d %s" % [
			equipped_equipment.name,
			equipped_equipment.enhancement_level,
			get_rarity_stars(equipped_equipment.rarity)
		]
		info_label.add_theme_font_size_override("font_size", 9)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		info_label.position = Vector2(5, 80)
		info_label.size = Vector2(90, 35)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_child(info_label)
		
		# Show as equipped with special background
		button.modulate = Color.WHITE  # Keep icon/text normal
		
	else:
		# Empty slot
		var slot_color = get_equipment_type_color(slot_index)
		button.text = slot_name
		button.modulate = Color(0.6, 0.6, 0.6)  # Dimmed appearance
		
		# Empty slot style
		var empty_style = StyleBoxFlat.new()
		empty_style.bg_color = Color(0.2, 0.2, 0.2, 0.3)
		empty_style.border_width_left = 2
		empty_style.border_width_right = 2
		empty_style.border_width_top = 2
		empty_style.border_width_bottom = 2
		empty_style.border_color = slot_color
		empty_style.corner_radius_top_left = 4
		empty_style.corner_radius_top_right = 4
		empty_style.corner_radius_bottom_left = 4
		empty_style.corner_radius_bottom_right = 4
		
		button.add_theme_stylebox_override("normal", empty_style)
	
	# Connect signal
	button.pressed.connect(_on_equipment_slot_pressed.bind(slot_index))
	
	# Visual selection state
	if slot_index == selected_equipment_slot:
		# Add selection highlight
		var selected_style = button.get_theme_stylebox("normal").duplicate()
		if selected_style is StyleBoxFlat:
			selected_style.border_color = Color.CYAN
			selected_style.border_width_left = 4
			selected_style.border_width_right = 4
			selected_style.border_width_top = 4
			selected_style.border_width_bottom = 4
		button.add_theme_stylebox_override("normal", selected_style)
	
	return button

func get_equipped_equipment_for_slot(slot_index: int) -> Equipment:
	"""Get equipped equipment for slot - RULE 5: system call only"""
	if not selected_god or not selected_god.equipment:
		return null
	
	if slot_index >= selected_god.equipment.size():
		return null
		
	return selected_god.equipment[slot_index]

func _on_equipment_slot_pressed(slot_index: int):
	"""Handle equipment slot selection"""
	selected_equipment_slot = slot_index
	equipment_slot_selected.emit(slot_index)
	# Refresh to show selection state
	refresh_equipped_slots()

func get_rarity_color(rarity: Equipment.Rarity) -> Color:
	"""Get rarity color - RULE 4: UI helper"""
	match rarity:
		Equipment.Rarity.COMMON: return Color.WHITE
		Equipment.Rarity.RARE: return Color.GREEN
		Equipment.Rarity.EPIC: return Color.PURPLE
		Equipment.Rarity.LEGENDARY: return Color.GOLD
		_: return Color.WHITE

func get_subtle_rarity_color(rarity: Equipment.Rarity) -> Color:
	"""Get subtle rarity background color - RULE 4: UI helper"""
	match rarity:
		Equipment.Rarity.COMMON: return Color(0.3, 0.3, 0.3, 0.2)
		Equipment.Rarity.RARE: return Color(0.2, 0.4, 0.2, 0.2)
		Equipment.Rarity.EPIC: return Color(0.4, 0.2, 0.4, 0.2)
		Equipment.Rarity.LEGENDARY: return Color(0.4, 0.4, 0.2, 0.2)
		_: return Color(0.3, 0.3, 0.3, 0.2)

func get_rarity_stars(rarity: Equipment.Rarity) -> String:
	"""Get rarity star representation - RULE 4: UI helper"""
	match rarity:
		Equipment.Rarity.COMMON: return "⭐"
		Equipment.Rarity.RARE: return "⭐⭐"
		Equipment.Rarity.EPIC: return "⭐⭐⭐"
		Equipment.Rarity.LEGENDARY: return "⭐⭐⭐⭐"
		_: return "⭐"

func get_equipment_type_color(slot_index: int) -> Color:
	"""Get color for equipment type - RULE 4: UI helper"""
	match slot_index:
		0: return Color.RED      # Weapon
		1: return Color.ORANGE   # Helmet
		2: return Color.BLUE     # Armor
		3: return Color.GREEN    # Boots
		4, 5: return Color.PURPLE # Accessories
		_: return Color.WHITE
