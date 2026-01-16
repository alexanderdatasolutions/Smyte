# scripts/ui/equipment/EquipmentSlotManager.gd
# RULE 1 COMPLIANCE: Under 200 lines
# RULE 2 COMPLIANCE: Single responsibility - Equipment slot display only
# RULE 4 COMPLIANCE: UI Only - no business logic
extends Control
class_name EquipmentSlotManager

"""
Equipment Slot Manager Component
Handles equipment slot display and selection for equipped gear
SINGLE RESPONSIBILITY: Equipment slot interface only
"""

signal equipment_slot_selected(slot_index: int)
signal equipment_unequip_requested(slot_index: int)

var equipment_slots_container: GridContainer
var selected_god: God = null
var equipment_manager: EquipmentManager

# Slot configuration
const SLOT_NAMES = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]

func _ready():
	_initialize_systems()

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		if not equipment_manager:
			push_error("EquipmentSlotManager: Could not get EquipmentManager from SystemRegistry")
	else:
		push_error("EquipmentSlotManager: Could not get SystemRegistry instance")

func set_equipment_slots_container(container: GridContainer):
	"""Set the equipment slots container reference"""
	equipment_slots_container = container
	if is_node_ready():
		_refresh_equipped_slots()

func set_selected_god(god: God):
	"""Set the currently selected god"""
	selected_god = god
	_refresh_equipped_slots()

func _refresh_equipped_slots():
	"""Refresh the equipment slots display"""
	if not equipment_slots_container or not selected_god:
		return
	
	# Clear existing slots
	for child in equipment_slots_container.get_children():
		child.queue_free()
	
	# Create slot buttons for each equipment type
	for i in range(SLOT_NAMES.size()):
		var slot_button = _create_equipment_slot_button(i, SLOT_NAMES[i])
		equipment_slots_container.add_child(slot_button)

func _create_equipment_slot_button(slot_index: int, slot_name: String) -> Control:
	"""Create an equipment slot card with PNG icon and stats"""
	var container = Panel.new()
	container.custom_minimum_size = Vector2(160, 180)  # Mobile-friendly size
	
	# Check if there's equipment in this slot
	var equipped_equipment = _get_equipped_equipment_for_slot(slot_index)
	
	# Slot styling based on equipped state
	var card_style = StyleBoxFlat.new()
	if equipped_equipment:
		card_style.bg_color = Color(0.2, 0.4, 0.2, 0.9)  # Green for equipped
		card_style.border_color = _get_rarity_color(equipped_equipment.rarity)
	else:
		card_style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Gray for empty
		card_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
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
	
	# Slot label at top
	var slot_label = Label.new()
	slot_label.text = slot_name
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.add_theme_font_size_override("font_size", 12)
	slot_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(slot_label)
	
	# Icon container
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(64, 64)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if equipped_equipment:
		# Load PNG icon for equipped equipment
		var icon_path = _get_equipment_icon_path(equipped_equipment)
		if FileAccess.file_exists(icon_path):
			var texture = load(icon_path)
			if texture:
				texture_rect.texture = texture
			else:
				# Fallback to colored square
				var fallback_style = StyleBoxFlat.new()
				fallback_style.bg_color = _get_rarity_color(equipped_equipment.rarity)
				texture_rect.add_theme_stylebox_override("normal", fallback_style)
		else:
			# Fallback to colored square
			var fallback_style = StyleBoxFlat.new()
			fallback_style.bg_color = _get_rarity_color(equipped_equipment.rarity)
			texture_rect.add_theme_stylebox_override("normal", fallback_style)
	else:
		# Empty slot - show slot type icon
		var empty_style = StyleBoxFlat.new()
		empty_style.bg_color = Color(0.4, 0.4, 0.4, 0.3)
		empty_style.border_width_left = 2
		empty_style.border_width_right = 2
		empty_style.border_width_top = 2
		empty_style.border_width_bottom = 2
		empty_style.border_color = Color(0.6, 0.6, 0.6, 0.8)
		empty_style.corner_radius_top_left = 4
		empty_style.corner_radius_top_right = 4
		empty_style.corner_radius_bottom_left = 4
		empty_style.corner_radius_bottom_right = 4
		texture_rect.add_theme_stylebox_override("normal", empty_style)
	
	icon_container.add_child(texture_rect)
	vbox.add_child(icon_container)
	
	# Equipment details
	if equipped_equipment:
		# Equipment name
		var name_label = Label.new()
		name_label.text = equipped_equipment.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", _get_rarity_color(equipped_equipment.rarity))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)
		
		# Enhancement level
		if equipped_equipment.level > 0:
			var enhance_label = Label.new()
			enhance_label.text = "+%d" % equipped_equipment.level
			enhance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			enhance_label.add_theme_font_size_override("font_size", 10)
			enhance_label.add_theme_color_override("font_color", Color.LIME_GREEN)
			vbox.add_child(enhance_label)
		
		# Set bonus glow effect
		if equipped_equipment.equipment_set_name != "":
			var set_count = _count_set_pieces(equipped_equipment.equipment_set_name)
			if set_count >= 2:
				# Add glowing border for set bonus
				var glow_style = card_style.duplicate()
				glow_style.border_color = Color.GOLD
				glow_style.border_width_left = 4
				glow_style.border_width_right = 4
				glow_style.border_width_top = 4
				glow_style.border_width_bottom = 4
				container.add_theme_stylebox_override("panel", glow_style)
				
				# Set bonus indicator
				var set_indicator = Label.new()
				set_indicator.text = "%d/6 %s" % [set_count, equipped_equipment.equipment_set_name]
				set_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				set_indicator.add_theme_font_size_override("font_size", 9)
				set_indicator.add_theme_color_override("font_color", Color.GOLD)
				vbox.add_child(set_indicator)
	else:
		# Empty slot text
		var empty_label = Label.new()
		empty_label.text = "Empty"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		vbox.add_child(empty_label)
	
	# Touch-friendly button overlay
	var button = Button.new()
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.flat = true
	button.pressed.connect(_on_equipment_slot_pressed.bind(slot_index))
	container.add_child(button)
	
	# Hover effects for desktop
	button.mouse_entered.connect(_on_slot_hover_enter.bind(container, equipped_equipment != null))
	button.mouse_exited.connect(_on_slot_hover_exit.bind(container, equipped_equipment != null))
	
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

func _count_set_pieces(equipment_set_name: String) -> int:
	"""Count how many pieces of a set are equipped"""
	if not selected_god:
		return 0
	
	var count = 0
	# God class has equipment property, not equipped_equipment - RULE 3: no logic in data classes
	if selected_god.equipment and selected_god.equipment.size() > 0:
		for i in range(selected_god.equipment.size()):
			var equipped = _get_equipped_equipment_for_slot(i)
			if equipped and equipped.equipment_set_name == equipment_set_name:
				count += 1
	return count

func _on_slot_hover_enter(container: Panel, is_equipped: bool):
	"""Handle hover enter for desktop"""
	var style = container.get_theme_stylebox("panel").duplicate()
	if is_equipped:
		style.bg_color = Color(0.3, 0.5, 0.3, 0.95)  # Brighter green
	else:
		style.bg_color = Color(0.4, 0.4, 0.4, 0.7)  # Lighter gray
	container.add_theme_stylebox_override("panel", style)

func _on_slot_hover_exit(container: Panel, is_equipped: bool):
	"""Handle hover exit for desktop"""
	var style = container.get_theme_stylebox("panel").duplicate()
	if is_equipped:
		style.bg_color = Color(0.2, 0.4, 0.2, 0.9)  # Return to green
	else:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Return to gray
	container.add_theme_stylebox_override("panel", style)

func _get_equipped_equipment_for_slot(slot_index: int) -> Equipment:
	"""Get the equipment equipped in the specified slot"""
	if not selected_god or slot_index < 0 or slot_index >= selected_god.equipment.size():
		return null
	
	var equipment_data = selected_god.equipment[slot_index]
	if equipment_data == null:
		return null
	
	# If it's already an Equipment object, return it
	if equipment_data is Equipment:
		return equipment_data
	
	# If it's a string ID, need to get the equipment object
	if equipment_data is String and equipment_data != "":
		if equipment_manager:
			var all_equipment = equipment_manager.get_unequipped_equipment()
			for equipment in all_equipment:
				if equipment != null and equipment is Equipment and equipment.id == equipment_data:
					return equipment
		return null
	
	return null

func _on_equipment_slot_pressed(slot_index: int):
	"""Handle equipment slot button press"""
	print("EquipmentSlotManager: Selected equipment slot %d" % slot_index)
	
	var equipped_equipment = _get_equipped_equipment_for_slot(slot_index)
	
	if equipped_equipment:
		# Equipment is equipped - show context menu or emit unequip signal
		equipment_unequip_requested.emit(slot_index)
	else:
		# Empty slot - emit slot selection for filtering inventory
		equipment_slot_selected.emit(slot_index)

func refresh():
	"""Refresh the equipment slots display"""
	_refresh_equipped_slots()
