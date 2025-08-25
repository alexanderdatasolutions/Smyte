extends Control

signal back_pressed

# UI References - Scene nodes
@onready var back_button = $MainContainer/TopBar/BackButton
@onready var god_grid = $MainContainer/ContentContainer/LeftPanel/GodScrollContainer/VBoxContainer/GodGrid
@onready var inventory_grid = $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryContainer/InventoryScroll/InventoryGrid
@onready var stats_content = $MainContainer/ContentContainer/CenterRightSplit/RightPanel/StatsContainer/StatsScroll/StatsContent

# God sort buttons
@onready var god_sort_buttons = {
	"level": $MainContainer/ContentContainer/LeftPanel/GodSortContainer/LevelSortButton,
	"tier": $MainContainer/ContentContainer/LeftPanel/GodSortContainer/TierSortButton,
	"name": $MainContainer/ContentContainer/LeftPanel/GodSortContainer/NameSortButton,
	"power": $MainContainer/ContentContainer/LeftPanel/GodSortContainer/PowerSortButton
}

# Filter buttons
@onready var filter_buttons = {
	"all": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/AllButton,
	"weapon": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/WeaponButton,
	"armor": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/ArmorButton,
	"helm": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/HelmButton,
	"boots": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/BootsButton,
	"amulet": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/AmuletButton,
	"ring": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/RingButton
}

# Sort buttons
@onready var sort_buttons = {
	"type": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/TypeSortButton,
	"rarity": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/RaritySortButton,
	"level": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/LevelSortButton,
	"set": $MainContainer/ContentContainer/CenterRightSplit/CenterPanel/InventoryHeader/FilterContainer/SetSortButton
}

# Equipment slots (in equipment.json slot order)
@onready var equipment_slots = [
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot1,  # Slot 1 - Weapon
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot2,  # Slot 2 - Armor  
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot3,  # Slot 3 - Helm
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot4,  # Slot 4 - Boots
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot5,  # Slot 5 - Amulet
	$MainContainer/ContentContainer/CenterRightSplit/RightPanel/EquippedContainer/SlotsContainer/SlotGrid/Slot6   # Slot 6 - Ring
]

# Slot type mapping (index to equipment type) - matches equipment.json slots
const SLOT_TYPES = [
	Equipment.EquipmentType.WEAPON,  # Slot 1 (index 0)
	Equipment.EquipmentType.ARMOR,   # Slot 2 (index 1) 
	Equipment.EquipmentType.HELM,    # Slot 3 (index 2)
	Equipment.EquipmentType.BOOTS,   # Slot 4 (index 3)
	Equipment.EquipmentType.AMULET,  # Slot 5 (index 4)
	Equipment.EquipmentType.RING     # Slot 6 (index 5)
]

# State
var equipment_manager: EquipmentManager
var selected_god: God
var current_filter: String = "all"
var current_sort: String = "type"
var sort_ascending: bool = false

# God sorting
var current_god_sort: String = "level"
var god_sort_ascending: bool = false

func _ready():
	# Get equipment manager
	if GameManager and GameManager.equipment_manager:
		equipment_manager = GameManager.equipment_manager
		equipment_manager.equipment_equipped.connect(_on_equipment_equipped)
		equipment_manager.equipment_unequipped.connect(_on_equipment_unequipped)
		
		# Create test equipment if needed
		if equipment_manager.equipment_inventory.size() == 0:
			create_test_equipment()
	
	# Connect UI signals
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Connect god sort buttons
	for key in god_sort_buttons:
		god_sort_buttons[key].pressed.connect(_on_god_sort_changed.bind(key))
	
	# Connect filter buttons
	for key in filter_buttons:
		filter_buttons[key].pressed.connect(_on_filter_changed.bind(key))
	
	# Connect sort buttons
	for key in sort_buttons:
		sort_buttons[key].pressed.connect(_on_sort_changed.bind(key))
	
	# Connect equipment slot buttons
	for i in range(equipment_slots.size()):
		var slot = equipment_slots[i]
		var button = slot.get_node("Button")
		button.pressed.connect(_on_slot_clicked.bind(i))
	
	# Initial UI setup
	refresh_all()

func refresh_all():
	"""Refresh all UI elements"""
	refresh_god_grid()
	refresh_inventory()
	refresh_equipped_slots()
	refresh_stats()

func refresh_god_grid():
	"""Populate the god selection grid"""
	# Clear existing
	for child in god_grid.get_children():
		child.queue_free()
	
	if not GameManager or not GameManager.player_data:
		return
	
	# Get and sort gods
	var gods = GameManager.player_data.gods.duplicate()
	sort_gods(gods)
	
	# Add god cards
	for god in gods:
		var card = create_god_card(god)
		god_grid.add_child(card)

func sort_gods(god_list: Array):
	"""Sort god list based on current sort criteria"""
	god_list.sort_custom(func(a, b):
		var result = false
		match current_god_sort:
			"level":
				if a.level != b.level:
					result = a.level > b.level  # Higher level first
				else:
					result = a.tier > b.tier  # Then by tier
			"tier":
				if a.tier != b.tier:
					result = a.tier > b.tier  # Higher tier first
				else:
					result = a.level > b.level  # Then by level
			"name":
				result = a.name < b.name  # Alphabetical
			"power":
				var power_a = a.get_power_rating()
				var power_b = b.get_power_rating()
				if power_a != power_b:
					result = power_a > power_b  # Higher power first
				else:
					result = a.level > b.level  # Then by level
		
		return result if not god_sort_ascending else !result
	)

func create_god_card(god: God) -> Panel:
	"""Create a compact god selection card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(110, 140)
	
	# Style based on tier
	var style = StyleBoxFlat.new()
	style.bg_color = get_tier_bg_color(god.tier)
	style.border_color = get_tier_color(god.tier)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	
	if selected_god and selected_god.id == god.id:
		style.border_color = Color.YELLOW
		style.set_border_width_all(3)
	
	card.add_theme_stylebox_override("panel", style)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	margin.add_child(content)
	
	# God image
	var image = TextureRect.new()
	image.custom_minimum_size = Vector2(50, 50)
	image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture = god.get_sprite()
	if texture:
		image.texture = texture
	content.add_child(image)
	
	# Name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)
	
	# Level
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	content.add_child(level_label)
	
	# Equipped indicator
	var equipped_count = 0
	for equip in god.equipped_runes:
		if equip != null:
			equipped_count += 1
	
	if equipped_count > 0:
		var equipped_label = Label.new()
		equipped_label.text = "⚙ %d/6" % equipped_count
		equipped_label.add_theme_font_size_override("font_size", 9)
		equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipped_label.modulate = Color.GOLD
		content.add_child(equipped_label)
	
	# Button
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_selected.bind(god))
	card.add_child(button)
	
	return card

func refresh_inventory():
	"""Refresh the equipment inventory grid"""
	# Clear existing
	for child in inventory_grid.get_children():
		child.queue_free()
	
	if not equipment_manager:
		return
	
	# Get filtered and sorted equipment
	var equipment_list = get_filtered_equipment()
	sort_equipment(equipment_list)
	
	# Create cards
	for equipment in equipment_list:
		var card = create_equipment_card(equipment)
		inventory_grid.add_child(card)

func get_filtered_equipment() -> Array:
	"""Get equipment list based on current filter"""
	var filtered = []
	
	for equipment in equipment_manager.equipment_inventory:
		if current_filter == "all":
			filtered.append(equipment)
		elif matches_filter(equipment):
			filtered.append(equipment)
	
	return filtered

func matches_filter(equipment: Equipment) -> bool:
	"""Check if equipment matches current filter"""
	match current_filter:
		"weapon": return equipment.type == Equipment.EquipmentType.WEAPON
		"armor": return equipment.type == Equipment.EquipmentType.ARMOR
		"helm": return equipment.type == Equipment.EquipmentType.HELM
		"boots": return equipment.type == Equipment.EquipmentType.BOOTS
		"amulet": return equipment.type == Equipment.EquipmentType.AMULET
		"ring": return equipment.type == Equipment.EquipmentType.RING
		_: return true

func sort_equipment(equipment_list: Array):
	"""Sort equipment list based on current sort"""
	equipment_list.sort_custom(func(a, b):
		var result = false
		match current_sort:
			"type":
				result = a.type < b.type
			"rarity":
				result = a.rarity > b.rarity  # Higher rarity first
			"level":
				result = a.level > b.level  # Higher level first
			"set":
				result = a.equipment_set_type < b.equipment_set_type
		
		return result if not sort_ascending else !result
	)

func create_equipment_card(equipment: Equipment) -> Panel:
	"""Create an equipment inventory card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(110, 150)
	
	# Style based on rarity
	var style = StyleBoxFlat.new()
	style.bg_color = get_rarity_bg_color(equipment.rarity)
	style.border_color = equipment.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)
	
	# Margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	margin.add_child(content)
	
	# Type icon
	var type_label = Label.new()
	type_label.text = get_equipment_icon(equipment.type)
	type_label.add_theme_font_size_override("font_size", 24)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.modulate = equipment.get_rarity_color()
	content.add_child(type_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = equipment.name.substr(0, 12) if equipment.name.length() > 12 else equipment.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)
	
	# Enhancement level
	if equipment.level > 0:
		var level_label = Label.new()
		level_label.text = "+%d" % equipment.level
		level_label.add_theme_font_size_override("font_size", 14)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.modulate = Color.CYAN
		content.add_child(level_label)
	
	# Main stat
	var stat_label = RichTextLabel.new()
	stat_label.custom_minimum_size = Vector2(0, 35)
	stat_label.bbcode_enabled = true
	stat_label.fit_content = true
	stat_label.text = "[center][b]%s[/b]\n[color=lime]+%d[/color][/center]" % [
		get_stat_short_name(equipment.main_stat_type),
		equipment.main_stat_value
	]
	content.add_child(stat_label)
	
	# Set name
	if equipment.equipment_set_name != "":
		var set_label = Label.new()
		set_label.text = equipment.equipment_set_name
		set_label.add_theme_font_size_override("font_size", 8)
		set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_label.modulate = Color.GOLD
		content.add_child(set_label)
	
	# Button
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_equipment_clicked.bind(equipment))
	card.add_child(button)
	
	return card

func refresh_equipped_slots():
	"""Refresh the equipped equipment slots display"""
	if not selected_god:
		# Reset all slots to empty
		for i in range(equipment_slots.size()):
			update_slot_display(i, null)
		return
	
	# Update each slot based on equipped items
	for i in range(equipment_slots.size()):
		var equipped = selected_god.equipped_runes[i] if i < selected_god.equipped_runes.size() else null
		update_slot_display(i, equipped)

func update_slot_display(slot_index: int, equipment: Equipment):
	"""Update a single equipment slot display"""
	var slot = equipment_slots[slot_index]
	var icon_label = slot.get_node("Icon")
	
	# Update style
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	
	if equipment:
		# Equipped - show rarity color
		style.bg_color = get_rarity_bg_color(equipment.rarity)
		style.border_color = equipment.get_rarity_color()
		style.set_border_width_all(3)
		
		# Update icon
		icon_label.text = get_equipment_icon(equipment.type)
		icon_label.modulate = equipment.get_rarity_color()
		
		# Add level indicator if enhanced
		if equipment.level > 0:
			icon_label.text += "\n+%d" % equipment.level
			icon_label.add_theme_font_size_override("font_size", 18)
		else:
			icon_label.add_theme_font_size_override("font_size", 24)
	else:
		# Empty slot
		style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		style.border_color = Color(0.3, 0.3, 0.3)
		style.set_border_width_all(2)
		
		# Show slot type icon
		icon_label.text = get_equipment_icon(SLOT_TYPES[slot_index])
		icon_label.modulate = Color(0.4, 0.4, 0.4)
		icon_label.add_theme_font_size_override("font_size", 24)
	
	slot.add_theme_stylebox_override("panel", style)

func refresh_stats():
	"""Refresh the stats display"""
	# Clear existing
	for child in stats_content.get_children():
		child.queue_free()
	
	if not selected_god:
		var label = Label.new()
		label.text = "Select a god to view stats"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color.GRAY
		stats_content.add_child(label)
		return
	
	# Create stats display
	var stats_text = RichTextLabel.new()
	stats_text.bbcode_enabled = true
	stats_text.fit_content = true
	stats_text.custom_minimum_size = Vector2(0, 400)
	
	# Build stats text
	var text = "[center][b][font_size=18]%s[/font_size][/b]\nLevel %d[/center]\n\n" % [selected_god.name, selected_god.level]
	
	# Base stats
	text += "[b]BASE STATS[/b]\n"
	text += "HP: %d\n" % selected_god.get_current_hp()
	text += "ATK: %d\n" % selected_god.get_current_attack()
	text += "DEF: %d\n" % selected_god.get_current_defense()
	text += "SPD: %d\n\n" % selected_god.get_current_speed()
	
	# Advanced stats
	text += "[b]COMBAT STATS[/b]\n"
	text += "Crit Rate: [color=yellow]%d%%[/color]\n" % selected_god.get_current_crit_rate()
	text += "Crit DMG: [color=orange]%d%%[/color]\n" % selected_god.get_current_crit_damage()
	text += "Accuracy: [color=cyan]%d%%[/color]\n" % selected_god.get_current_accuracy()
	text += "Resistance: [color=purple]%d%%[/color]\n\n" % selected_god.get_current_resistance()
	
	# Equipment summary
	var equipped_count = 0
	for equip in selected_god.equipped_runes:
		if equip != null:
			equipped_count += 1
	
	text += "[b]EQUIPMENT[/b]\n"
	text += "Equipped: [color=cyan]%d/6[/color]\n\n" % equipped_count
	
	# Set bonuses
	if equipment_manager:
		var set_bonuses = equipment_manager.get_equipped_set_bonuses(selected_god)
		if set_bonuses.size() > 0:
			text += "[b][color=gold]SET BONUSES[/color][/b]\n"
			for bonus_type in set_bonuses:
				if bonus_type != "special_effects":
					text += "%s: [color=lime]+%d[/color]\n" % [bonus_type.capitalize(), set_bonuses[bonus_type]]
	
	stats_text.text = text
	stats_content.add_child(stats_text)

# Event handlers

func _on_back_button_pressed():
	back_pressed.emit()

func _on_god_selected(god: God):
	selected_god = god
	refresh_all()

func _on_god_sort_changed(sort_type: String):
	"""Handle god sort button clicks"""
	if current_god_sort == sort_type:
		god_sort_ascending = !god_sort_ascending
	else:
		current_god_sort = sort_type
		god_sort_ascending = false
	
	refresh_god_grid()

func _on_filter_changed(filter_type: String):
	# Update toggle states
	for key in filter_buttons:
		filter_buttons[key].button_pressed = (key == filter_type)
	
	current_filter = filter_type
	refresh_inventory()

func _on_sort_changed(sort_type: String):
	if current_sort == sort_type:
		sort_ascending = !sort_ascending
	else:
		current_sort = sort_type
		sort_ascending = false
	
	refresh_inventory()

func _on_equipment_clicked(equipment: Equipment):
	"""Handle equipment click - equip to selected god"""
	if not selected_god:
		show_message("Please select a god first")
		return
	
	# Check if this equipment type can be equipped to the corresponding slot
	var slot_index = get_slot_for_equipment_type(equipment.type)
	if slot_index == -1:
		show_message("Invalid equipment type")
		return
	
	# Equip the item
	equipment_manager.equip_equipment(selected_god, equipment)

func _on_slot_clicked(slot_index: int):
	"""Handle slot click - unequip if occupied"""
	if not selected_god:
		return
	
	var equipped = selected_god.equipped_runes[slot_index] if slot_index < selected_god.equipped_runes.size() else null
	if equipped:
		equipment_manager.unequip_equipment(selected_god, slot_index)

func _on_equipment_equipped(_god: God, _equipment: Equipment, _slot: int):
	refresh_all()

func _on_equipment_unequipped(_god: God, _slot: int):
	refresh_all()

# Helper functions

func get_slot_for_equipment_type(type: Equipment.EquipmentType) -> int:
	"""Get the slot index for an equipment type"""
	for i in range(SLOT_TYPES.size()):
		if SLOT_TYPES[i] == type:
			return i
	return -1

func get_tier_bg_color(tier: int) -> Color:
	match tier:
		0: return Color(0.2, 0.2, 0.2, 0.8)
		1: return Color(0.15, 0.25, 0.15, 0.8)
		2: return Color(0.25, 0.15, 0.35, 0.8)
		3: return Color(0.35, 0.25, 0.1, 0.8)
		_: return Color(0.2, 0.2, 0.2, 0.8)

func get_tier_color(tier: int) -> Color:
	match tier:
		0: return Color.GRAY
		1: return Color.GREEN
		2: return Color.MEDIUM_PURPLE
		3: return Color.GOLD
		_: return Color.WHITE

func get_rarity_bg_color(rarity: Equipment.Rarity) -> Color:
	match rarity:
		Equipment.Rarity.COMMON: return Color(0.2, 0.2, 0.2, 0.8)
		Equipment.Rarity.RARE: return Color(0.1, 0.25, 0.1, 0.8)
		Equipment.Rarity.EPIC: return Color(0.2, 0.1, 0.35, 0.8)
		Equipment.Rarity.LEGENDARY: return Color(0.35, 0.2, 0.0, 0.8)
		Equipment.Rarity.MYTHIC: return Color(0.35, 0.0, 0.2, 0.8)
		_: return Color(0.2, 0.2, 0.2, 0.8)

func get_equipment_icon(type: Equipment.EquipmentType) -> String:
	match type:
		Equipment.EquipmentType.WEAPON: return "⚔"
		Equipment.EquipmentType.ARMOR: return "🛡"
		Equipment.EquipmentType.HELM: return "🪖"
		Equipment.EquipmentType.BOOTS: return "👢"
		Equipment.EquipmentType.AMULET: return "🔮"
		Equipment.EquipmentType.RING: return "💍"
		_: return "?"

func get_stat_short_name(stat_type: String) -> String:
	match stat_type:
		"attack": return "ATK"
		"defense": return "DEF"
		"hp": return "HP"
		"speed": return "SPD"
		"critical_rate": return "CR"
		"critical_damage": return "CD"
		"accuracy": return "ACC"
		"resistance": return "RES"
		_: return stat_type.to_upper().substr(0, 3)

func show_message(text: String):
	"""Show a temporary message"""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()

func create_test_equipment():
	"""Create test equipment for development"""
	if not equipment_manager:
		return
	
	var test_data = [
		{"type": "weapon", "rarity": "legendary", "level": 12},
		{"type": "armor", "rarity": "epic", "level": 8},
		{"type": "helm", "rarity": "rare", "level": 5},
		{"type": "boots", "rarity": "epic", "level": 10},
		{"type": "amulet", "rarity": "legendary", "level": 15},
		{"type": "ring", "rarity": "mythic", "level": 9},
		{"type": "weapon", "rarity": "common", "level": 0},
		{"type": "armor", "rarity": "rare", "level": 3},
		{"type": "ring", "rarity": "epic", "level": 6}
	]
	
	for data in test_data:
		var equipment = Equipment.create_test_equipment(
			data.type,
			data.rarity,
			data.level
		)
		if equipment:
			equipment_manager.add_equipment_to_inventory(equipment)
	
	print("Created %d test equipment items" % test_data.size())
