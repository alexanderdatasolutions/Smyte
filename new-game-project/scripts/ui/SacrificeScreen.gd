# scripts/ui/SacrificeScreen.gd - Summoners War style sacrifice/power-up system
extends Control

signal back_pressed

@onready var back_button = $BackButton
@onready var god_list = $ContentContainer/LeftPanel/VBox/ScrollContainer/GodList
@onready var sacrifice_panel = $ContentContainer/RightPanel/SacrificePanel

# Sacrifice system state
var selected_target_god: God = null
var selected_material_gods: Array[God] = []
var max_material_gods: int = 6  # Like Summoners War

# UI references
var target_god_display: Control = null
var material_god_slots: Array[Control] = []
var experience_preview_label: Label = null
var sacrifice_button: Button = null
var awaken_button: Button = null
var awakening_requirements_panel: Control = null

func _ready():
	print("SacrificeScreen _ready() called")
	print("back_button: ", back_button)
	print("god_list: ", god_list)  
	print("sacrifice_panel: ", sacrifice_panel)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	
	setup_sacrifice_panel()
	refresh_god_list()

func setup_sacrifice_panel():
	# Safety check
	if not sacrifice_panel:
		print("Error: SacrificePanel node not found!")
		return
		
	# Clear existing UI
	for child in sacrifice_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	sacrifice_panel.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "POWER UP GODS"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# Target god section
	var target_section = create_target_god_section()
	main_vbox.add_child(target_section)
	
	# Material gods section  
	var material_section = create_material_gods_section()
	main_vbox.add_child(material_section)
	
	# Awakening requirements section
	var awakening_section = create_awakening_requirements_section()
	main_vbox.add_child(awakening_section)
	
	# Experience preview
	experience_preview_label = Label.new()
	experience_preview_label.text = "Select gods to see experience gain"
	experience_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_preview_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(experience_preview_label)
	
	# Sacrifice button
	sacrifice_button = Button.new()
	sacrifice_button.text = "POWER UP!"
	sacrifice_button.custom_minimum_size = Vector2(200, 50)
	sacrifice_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	main_vbox.add_child(sacrifice_button)
	
	# Awaken button
	awaken_button = Button.new()
	awaken_button.text = "AWAKEN!"
	awaken_button.custom_minimum_size = Vector2(200, 50)
	awaken_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	awaken_button.disabled = true
	awaken_button.pressed.connect(_on_awaken_pressed)
	
	# Style the awaken button differently
	var awaken_style = StyleBoxFlat.new()
	awaken_style.bg_color = Color(0.8, 0.2, 0.8, 1.0)  # Purple for awakening
	awaken_style.corner_radius_top_left = 8
	awaken_style.corner_radius_top_right = 8
	awaken_style.corner_radius_bottom_left = 8
	awaken_style.corner_radius_bottom_right = 8
	awaken_button.add_theme_stylebox_override("normal", awaken_style)
	
	main_vbox.add_child(awaken_button)

func create_target_god_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Select god to power up:"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	# Target god display slot
	target_god_display = Panel.new()
	target_god_display.custom_minimum_size = Vector2(300, 80)
	target_god_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	target_god_display.add_theme_stylebox_override("panel", style)
	
	var empty_label = Label.new()
	empty_label.text = "Click a god from the left to select"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_label.modulate = Color.GRAY
	target_god_display.add_child(empty_label)
	
	vbox.add_child(target_god_display)
	return vbox

func create_material_gods_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Select material gods (food):"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	# Grid of material slots (2x3 like Summoners War)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	for i in range(max_material_gods):
		var slot = create_material_slot(i)
		material_god_slots.append(slot)
		grid.add_child(slot)
	
	vbox.add_child(grid)
	return vbox

func create_awakening_requirements_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Awakening Requirements:"
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	# Awakening requirements panel
	awakening_requirements_panel = Panel.new()
	awakening_requirements_panel.custom_minimum_size = Vector2(300, 120)
	awakening_requirements_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	awakening_requirements_panel.visible = false  # Hidden until target god selected
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.4, 0.8, 1.0)  # Purple border for awakening
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	awakening_requirements_panel.add_theme_stylebox_override("panel", style)
	
	vbox.add_child(awakening_requirements_panel)
	return vbox

func create_material_slot(slot_index: int) -> Control:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(90, 70)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	slot.add_theme_stylebox_override("panel", style)
	
	var empty_label = Label.new()
	empty_label.text = "+"
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty_label.modulate = Color.GRAY
	slot.add_child(empty_label)
	
	# Make clickable to remove material gods
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_material_slot_clicked.bind(slot_index))
	slot.add_child(button)
	
	return slot

func refresh_god_list():
	if not god_list:
		print("Error: GodList node not found!")
		return
		
	# Clear existing gods
	for child in god_list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if not GameManager or not GameManager.player_data:
		print("Error: GameManager or player_data not available!")
		return
	
	# Add all player gods
	for god in GameManager.player_data.gods:
		var god_item = create_god_list_item(god)
		god_list.add_child(god_item)

func create_god_list_item(god: God) -> Control:
	var item = Panel.new()
	item.custom_minimum_size = Vector2(280, 60)
	
	# Different style for selected gods
	var style = StyleBoxFlat.new()
	if god == selected_target_god:
		style.bg_color = Color(0.2, 0.4, 0.8, 0.8)  # Blue for target
	elif selected_material_gods.has(god):
		style.bg_color = Color(0.8, 0.4, 0.2, 0.8)  # Orange for material
	else:
		style.bg_color = Color(0.2, 0.2, 0.3, 0.8)  # Normal
	
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	item.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	item.add_child(hbox)
	
	# Add margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	item.add_child(margin)
	margin.add_child(hbox)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [god.name, god.level]
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)
	
	var details_label = Label.new()
	details_label.text = "%s %s - Power: %d" % [god.get_tier_name(), god.get_element_name(), god.get_power_rating()]
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.modulate = Color.LIGHT_GRAY
	info_vbox.add_child(details_label)
	
	hbox.add_child(info_vbox)
	
	# XP to next level
	var xp_label = Label.new()
	var xp_needed = god.get_experience_to_next_level() - god.experience
	if god.level >= 30:
		xp_label.text = "MAX"
		xp_label.modulate = Color.GOLD
	else:
		xp_label.text = "%d XP" % xp_needed
		xp_label.modulate = Color.CYAN
	xp_label.custom_minimum_size = Vector2(60, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(xp_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_clicked.bind(god))
	item.add_child(button)
	
	return item

func _on_god_clicked(god: God):
	# Determine what to do based on current selection
	if selected_target_god == null:
		# No target selected yet - make this the target
		set_target_god(god)
	elif selected_target_god == god:
		# Clicking target god - deselect it
		set_target_god(null)
	elif selected_material_gods.has(god):
		# Already a material - remove it
		selected_material_gods.erase(god)
		update_ui()
	elif selected_material_gods.size() < max_material_gods and god != selected_target_god:
		# Add as material god
		selected_material_gods.append(god)
		update_ui()
	else:
		# Max materials reached or trying to add target as material
		print("Cannot add more material gods or target god cannot be material")

func set_target_god(god: God):
	selected_target_god = god
	update_target_display()
	update_awakening_requirements_display()
	update_ui()

func update_target_display():
	if not target_god_display:
		return
		
	# Clear existing content
	for child in target_god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if selected_target_god == null:
		var empty_label = Label.new()
		empty_label.text = "Click a god from the left to select"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_label.modulate = Color.GRAY
		target_god_display.add_child(empty_label)
	else:
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 10)
		
		# Add margin
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		target_god_display.add_child(margin)
		margin.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = "%s (Level %d)" % [selected_target_god.name, selected_target_god.level]
		name_label.add_theme_font_size_override("font_size", 16)
		info_vbox.add_child(name_label)
		
		var details_label = Label.new()
		details_label.text = "%s %s - Power: %d" % [
			selected_target_god.get_tier_name(), 
			selected_target_god.get_element_name(), 
			selected_target_god.get_power_rating()
		]
		details_label.modulate = Color.LIGHT_GRAY
		info_vbox.add_child(details_label)
		
		hbox.add_child(info_vbox)
		
		# XP info
		var xp_vbox = VBoxContainer.new()
		var current_xp_label = Label.new()
		current_xp_label.text = "XP: %d" % selected_target_god.experience
		xp_vbox.add_child(current_xp_label)
		
		if selected_target_god.level < 30:
			var xp_needed_label = Label.new()
			var xp_needed = selected_target_god.get_experience_to_next_level() - selected_target_god.experience
			xp_needed_label.text = "Need: %d" % xp_needed
			xp_needed_label.modulate = Color.YELLOW
			xp_vbox.add_child(xp_needed_label)
		else:
			var max_label = Label.new()
			max_label.text = "MAX LEVEL"
			max_label.modulate = Color.GOLD
			xp_vbox.add_child(max_label)
		
		hbox.add_child(xp_vbox)

func update_awakening_requirements_display():
	if not awakening_requirements_panel or not GameManager or not GameManager.awakening_system:
		return
	
	# Clear existing content
	for child in awakening_requirements_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if selected_target_god == null:
		awakening_requirements_panel.visible = false
		return
	
	# Check if god can be awakened
	var awakening_check = GameManager.awakening_system.can_awaken_god(selected_target_god)
	if not awakening_check.awakened_god_id:
		awakening_requirements_panel.visible = false
		return
	
	awakening_requirements_panel.visible = true
	
	# Create content
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	awakening_requirements_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# Level requirements
	var level_label = Label.new()
	if selected_target_god.level >= 30:
		level_label.text = "✓ Level 30+ (Currently %d)" % selected_target_god.level
		level_label.modulate = Color.GREEN
	else:
		level_label.text = "✗ Level 30+ (Currently %d)" % selected_target_god.level
		level_label.modulate = Color.RED
	level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(level_label)
	
	# Material requirements
	var materials_needed = GameManager.awakening_system.get_awakening_materials_cost(selected_target_god)
	var materials_check = GameManager.awakening_system.check_awakening_materials(materials_needed, GameManager.player_data)
	
	for material_type in materials_needed.keys():
		var needed = materials_needed[material_type]
		var current = GameManager.awakening_system.get_player_material_amount(material_type, GameManager.player_data)
		
		var material_label = Label.new()
		var material_name = format_material_name(material_type)
		
		if current >= needed:
			material_label.text = "✓ %s: %d/%d" % [material_name, current, needed]
			material_label.modulate = Color.GREEN
		else:
			material_label.text = "✗ %s: %d/%d" % [material_name, current, needed]
			material_label.modulate = Color.RED
		
		material_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(material_label)
	
	# Overall status
	var status_label = Label.new()
	if awakening_check.can_awaken and materials_check.can_afford:
		status_label.text = "✨ Ready to Awaken! ✨"
		status_label.modulate = Color.GOLD
	else:
		status_label.text = "Requirements not met"
		status_label.modulate = Color.ORANGE
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

func format_material_name(material_type: String) -> String:
	"""Convert material type to display name"""
	match material_type:
		"awakening_stones":
			return "Awakening Stones"
		"divine_crystals":
			return "Divine Crystals"
		"light_powder_high":
			return "Light Powder (High)"
		"fire_powder_high":
			return "Fire Powder (High)"
		"water_powder_high":
			return "Water Powder (High)"
		"earth_powder_high":
			return "Earth Powder (High)"
		"lightning_powder_high":
			return "Lightning Powder (High)"
		"dark_powder_high":
			return "Dark Powder (High)"
		"greek_relics":
			return "Greek Relics"
		"norse_relics":
			return "Norse Relics"
		"egyptian_relics":
			return "Egyptian Relics"
		"hindu_relics":
			return "Hindu Relics"
		"celtic_relics":
			return "Celtic Relics"
		"japanese_relics":
			return "Japanese Relics"
		"aztec_relics":
			return "Aztec Relics"
		_:
			# Fallback: capitalize and replace underscores
			return material_type.replace("_", " ").capitalize()

func update_material_display():
	for i in range(material_god_slots.size()):
		var slot = material_god_slots[i]
		
		# Clear existing content
		for child in slot.get_children():
			child.queue_free()
		
		await get_tree().process_frame
		
		if i < selected_material_gods.size():
			# Show material god
			var god = selected_material_gods[i]
			var vbox = VBoxContainer.new()
			vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			var margin = MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin.add_theme_constant_override("margin_left", 5)
			margin.add_theme_constant_override("margin_right", 5)
			margin.add_theme_constant_override("margin_top", 5)
			margin.add_theme_constant_override("margin_bottom", 5)
			slot.add_child(margin)
			margin.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = god.name
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(name_label)
			
			var level_label = Label.new()
			level_label.text = "Lv.%d" % god.level
			level_label.add_theme_font_size_override("font_size", 9)
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_label.modulate = Color.LIGHT_GRAY
			vbox.add_child(level_label)
			
			# Make clickable to remove
			var button = Button.new()
			button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.flat = true
			button.pressed.connect(_on_material_slot_clicked.bind(i))
			slot.add_child(button)
		else:
			# Show empty slot
			var empty_label = Label.new()
			empty_label.text = "+"
			empty_label.add_theme_font_size_override("font_size", 24)
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			empty_label.modulate = Color.GRAY
			slot.add_child(empty_label)
			
			var button = Button.new()
			button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.flat = true
			button.pressed.connect(_on_material_slot_clicked.bind(i))
			slot.add_child(button)

func _on_material_slot_clicked(slot_index: int):
	if slot_index < selected_material_gods.size():
		# Remove material god from this slot
		selected_material_gods.remove_at(slot_index)
		update_ui()
	# If empty slot clicked, user needs to select from god list

func update_ui():
	refresh_god_list()
	update_material_display()
	update_awakening_requirements_display()
	update_experience_preview()
	update_sacrifice_button()
	update_awaken_button()

func update_experience_preview():
	if not experience_preview_label:
		return
		
	if selected_target_god == null or selected_material_gods.is_empty():
		experience_preview_label.text = "Select target and material gods to see experience gain"
		experience_preview_label.modulate = Color.GRAY
		return
	
	# Use SacrificeSystem for preview
	if GameManager and GameManager.sacrifice_system:
		var preview_text = GameManager.sacrifice_system.get_sacrifice_preview_text(selected_target_god, selected_material_gods)
		experience_preview_label.text = preview_text
		experience_preview_label.modulate = Color.GREEN
	else:
		experience_preview_label.text = "Sacrifice system not available"
		experience_preview_label.modulate = Color.RED

# OLD FUNCTIONS - COMMENTED OUT TO FORCE USE OF NEW SACRIFICE SYSTEM
# func calculate_total_experience_gain() -> int:
	var total_xp = 0
	
	for material_god in selected_material_gods:
		var base_xp = get_god_sacrifice_value(material_god)
		
		# Bonuses like Summoners War
		var bonus_multiplier = 1.0
		
		# Same god bonus (3x XP)
		if material_god.id == selected_target_god.id:
			bonus_multiplier = 3.0
		# Same element bonus (1.5x XP)
		elif material_god.element == selected_target_god.element:
			bonus_multiplier = 1.5
		
		total_xp += int(base_xp * bonus_multiplier)
	
	return total_xp

func get_god_sacrifice_value(god: God) -> int:
	# Base XP based on level and tier
	var base_xp = god.level * 50  # 50 XP per level
	
	# Tier multiplier
	match god.tier:
		God.TierType.COMMON:
			base_xp += 100
		God.TierType.RARE:
			base_xp += 300
		God.TierType.EPIC:
			base_xp += 600
		God.TierType.LEGENDARY:
			base_xp += 1000
	
	return base_xp

func calculate_levels_gained(xp_gain: int) -> int:
	if not selected_target_god:
		return 0
	
	var current_level = selected_target_god.level
	var current_xp = selected_target_god.experience
	var remaining_xp = xp_gain
	var levels_gained = 0
	
	while remaining_xp > 0 and current_level < 30:
		var xp_needed = (current_level + levels_gained + 1) * 100 - current_xp
		if remaining_xp >= xp_needed:
			remaining_xp -= xp_needed
			levels_gained += 1
			current_xp = 0  # Reset XP for next level calculation
		else:
			break
	
	return levels_gained

func update_sacrifice_button():
	if not sacrifice_button:
		return
		
	# Use SacrificeSystem for validation
	if GameManager and GameManager.sacrifice_system:
		var validation = GameManager.sacrifice_system.validate_sacrifice(selected_target_god, selected_material_gods)
		sacrifice_button.disabled = not validation.can_sacrifice
		
		if not validation.can_sacrifice and validation.errors.size() > 0:
			sacrifice_button.tooltip_text = validation.errors[0]
		else:
			sacrifice_button.tooltip_text = ""
	else:
		sacrifice_button.disabled = true

func _on_sacrifice_pressed():
	if not selected_target_god or selected_material_gods.is_empty():
		return
	
	# Show confirmation dialog with sacrifice details
	if GameManager and GameManager.sacrifice_system:
		var sacrifice_result = GameManager.sacrifice_system.calculate_sacrifice_experience(selected_material_gods, selected_target_god)
		var levels_gained = GameManager.sacrifice_system.calculate_levels_gained(selected_target_god, sacrifice_result.total_xp)
		
		var dialog_text = "Sacrifice %d gods to give %s:\n• %d Experience\n• +%d Levels\n\nMaterial gods will be consumed!" % [
			selected_material_gods.size(),
			selected_target_god.name,
			sacrifice_result.total_xp,
			levels_gained
		]
		
		show_confirmation_dialog("Confirm Sacrifice", dialog_text, perform_sacrifice)
	else:
		perform_sacrifice()  # Fallback to direct sacrifice

func perform_sacrifice():
	if not selected_target_god or selected_material_gods.is_empty() or not GameManager:
		return
	
	# Use SacrificeSystem to perform the sacrifice
	if GameManager.sacrifice_system:
		var success = GameManager.sacrifice_system.perform_sacrifice(selected_target_god, selected_material_gods, GameManager.player_data)
		if success:
			# Clear selection and refresh
			selected_material_gods.clear()
			set_target_god(null)
		else:
			print("Sacrifice failed!")
	else:
		print("Sacrifice system not available!")

func _on_back_pressed():
	back_pressed.emit()

func update_awaken_button():
	if not awaken_button or not GameManager or not GameManager.awakening_system:
		return
	
	if not selected_target_god:
		awaken_button.disabled = true
		awaken_button.text = "AWAKEN!"
		return
	
	# Check if this god can be awakened
	var awakening_check = GameManager.awakening_system.can_awaken_god(selected_target_god)
	if awakening_check.can_awaken:
		# Check materials
		var materials_needed = GameManager.awakening_system.get_awakening_materials_cost(selected_target_god)
		var materials_check = GameManager.awakening_system.check_awakening_materials(materials_needed, GameManager.player_data)
		
		if materials_check.can_afford:
			awaken_button.disabled = false
			awaken_button.text = "AWAKEN!"
		else:
			awaken_button.disabled = true
			awaken_button.text = "AWAKEN! (No Materials)"
	else:
		awaken_button.disabled = true
		if selected_target_god.is_awakened:
			awaken_button.text = "ALREADY AWAKENED"
		else:
			awaken_button.text = "AWAKEN! (Requirements not met)"

func _on_awaken_pressed():
	if not selected_target_god or not GameManager or not GameManager.awakening_system:
		return
	
	# Show awakening confirmation dialog
	show_awakening_dialog()

func show_awakening_dialog():
	var awakening_check = GameManager.awakening_system.can_awaken_god(selected_target_god)
	if not awakening_check.can_awaken:
		show_info_dialog("Cannot Awaken", awakening_check.missing_requirements[0] if awakening_check.missing_requirements.size() > 0 else "Unknown error")
		return
	
	var materials_needed = GameManager.awakening_system.get_awakening_materials_cost(selected_target_god)
	var materials_check = GameManager.awakening_system.check_awakening_materials(materials_needed, GameManager.player_data)
	
	if not materials_check.can_afford:
		var missing_text = "Missing materials:\n"
		for missing in materials_check.missing_materials:
			missing_text += "• %s: %d (need %d more)\n" % [missing.type.replace("_", " ").capitalize(), missing.current, missing.missing]
		show_info_dialog("Insufficient Materials", missing_text)
		return
	
	# Show confirmation with materials cost
	var cost_text = "Awaken %s?\n\nCost:\n" % selected_target_god.name
	for material_type in materials_needed.keys():
		var amount = materials_needed[material_type]
		cost_text += "• %s: %d\n" % [material_type.replace("_", " ").capitalize(), amount]
	
	show_confirmation_dialog("Confirm Awakening", cost_text, perform_awakening)

func show_info_dialog(title: String, message: String):
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_confirmation_dialog(title: String, message: String, callback: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(callback)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func perform_awakening():
	if not GameManager or not GameManager.awakening_system:
		return
	
	var success = GameManager.awakening_system.attempt_awakening(selected_target_god, GameManager.player_data)
	if success:
		show_info_dialog("Awakening Successful!", "%s has been awakened!" % selected_target_god.name)
		# Clear selection since the god object has been replaced
		selected_target_god = null
		update_ui()
	else:
		show_info_dialog("Awakening Failed", "Something went wrong during the awakening process.")
