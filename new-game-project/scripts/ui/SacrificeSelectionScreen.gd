# scripts/ui/SacrificeSelectionScreen.gd - Dedicated sacrifice selection screen like Summoners War
extends Control

signal back_pressed

# Node references
@onready var back_button = $MainContainer/TopBar/BackButton
@onready var target_god_display = $MainContainer/SacrificeContent/TargetGodSection/TargetGodDisplay
@onready var xp_bar_container = $MainContainer/SacrificeContent/XPBarSection/XPBarContainer
@onready var material_grid = $MainContainer/SacrificeContent/MaterialSection/ScrollContainer/MaterialGrid
@onready var lock_in_button = $MainContainer/SacrificeContent/ButtonSection/LockInButton
@onready var sacrifice_button = $MainContainer/SacrificeContent/ButtonSection/SacrificeButton

# State
var target_god: God = null
var selected_materials: Array[God] = []
var locked_in: bool = false
var max_materials: int = 6  # Can be changed - Summoners War default

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)

# UI elements
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_preview_label: Label = null
var selection_status_label: Label = null

# Scroll position preservation
var scroll_position: Vector2 = Vector2.ZERO

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	
	setup_ui()
	setup_sorting_ui()

func initialize_with_god(god: God):
	"""Initialize the screen with a target god"""
	target_god = god
	selected_materials.clear()
	locked_in = false
	update_all_displays()

func set_max_materials(count: int):
	"""Change the maximum number of materials allowed"""
	max_materials = max(1, min(count, 12))  # Clamp between 1 and 12
	# If we have too many selected, trim the list
	while selected_materials.size() > max_materials:
		selected_materials.pop_back()
	update_all_displays()

func setup_ui():
	setup_xp_bar()
	setup_target_display()
	sacrifice_button.disabled = true
	update_button_states()

func setup_xp_bar():
	"""Create the XP bar display"""
	# Clear existing
	for child in xp_bar_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	xp_bar_container.add_child(vbox)
	
	# Level preview label
	level_preview_label = Label.new()
	level_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_preview_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(level_preview_label)
	
	# XP bar
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)
	
	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 25)
	hbox.add_child(xp_bar)
	
	# XP text label
	xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(150, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(xp_label)
	
	# Selection status feedback
	selection_status_label = Label.new()
	selection_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_status_label.add_theme_font_size_override("font_size", 12)
	selection_status_label.visible = false
	vbox.add_child(selection_status_label)

func setup_target_display():
	"""Setup target god display"""
	# Clear existing
	for child in target_god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
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

func setup_sorting_ui():
	"""Add sorting controls to the material selection area"""
	# Find the material section
	var material_section = $MainContainer/SacrificeContent/MaterialSection
	if not material_section:
		return
	
	# Remove existing sorting UI if any
	for child in material_section.get_children():
		if child.name == "SortingContainer":
			child.queue_free()
	
	await get_tree().process_frame
	
	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.name = "SortingContainer"
	sort_container.add_theme_constant_override("separation", 5)
	
	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_container.add_child(sort_label)
	
	# Create compact sort buttons
	var sort_buttons = [
		{"text": "Pwr", "type": SortType.POWER},
		{"text": "Lvl", "type": SortType.LEVEL}, 
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Elem", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for button_data in sort_buttons:
		var sort_button = Button.new()
		sort_button.text = button_data.text
		sort_button.custom_minimum_size = Vector2(35, 25)
		sort_button.add_theme_font_size_override("font_size", 10)
		sort_button.pressed.connect(_on_sort_changed.bind(button_data.type))
		
		# Highlight current sort
		if button_data.type == current_sort:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			sort_button.add_theme_stylebox_override("normal", style)
		
		sort_container.add_child(sort_button)
	
	# Add sort direction button
	var direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(25, 25)
	direction_button.add_theme_font_size_override("font_size", 12)
	direction_button.pressed.connect(_on_sort_direction_changed)
	sort_container.add_child(direction_button)
	
	# Add a spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_container.add_child(spacer)
	
	# Add "Select Duplicates" button
	var duplicates_button = Button.new()
	duplicates_button.text = "Dupes"
	duplicates_button.custom_minimum_size = Vector2(50, 25)
	duplicates_button.add_theme_font_size_override("font_size", 10)
	duplicates_button.pressed.connect(_on_select_duplicates_pressed)
	
	# Style the duplicates button
	var dupes_style = StyleBoxFlat.new()
	dupes_style.bg_color = Color(0.6, 0.3, 0.8, 0.8)  # Purple color
	dupes_style.corner_radius_top_left = 4
	dupes_style.corner_radius_top_right = 4
	dupes_style.corner_radius_bottom_left = 4
	dupes_style.corner_radius_bottom_right = 4
	duplicates_button.add_theme_stylebox_override("normal", dupes_style)
	sort_container.add_child(duplicates_button)
	
	# Add "Clear All" button
	var clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size = Vector2(45, 25)
	clear_button.add_theme_font_size_override("font_size", 10)
	clear_button.pressed.connect(_on_clear_selection_pressed)
	
	# Style the clear button
	var clear_style = StyleBoxFlat.new()
	clear_style.bg_color = Color(0.8, 0.3, 0.3, 0.8)  # Red color
	clear_style.corner_radius_top_left = 4
	clear_style.corner_radius_top_right = 4
	clear_style.corner_radius_bottom_left = 4
	clear_style.corner_radius_bottom_right = 4
	clear_button.add_theme_stylebox_override("normal", clear_style)
	sort_container.add_child(clear_button)
	
	# Insert sorting controls before MaterialLabel
	var _material_label = material_section.get_child(0)  # Should be MaterialLabel
	material_section.add_child(sort_container)
	material_section.move_child(sort_container, 0)  # Move to top

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	update_all_displays()

func _on_sort_direction_changed():
	"""Toggle sort direction"""
	sort_ascending = !sort_ascending
	update_all_displays()

func _on_select_duplicates_pressed():
	"""Select all duplicate gods (leaving 1 copy of each god name)"""
	if locked_in or not GameManager or not GameManager.player_data:
		return
	
	# Group gods by name (excluding target god)
	var gods_by_name = {}
	for god in GameManager.player_data.gods:
		if god == target_god:
			continue  # Skip the target god
		
		if not gods_by_name.has(god.name):
			gods_by_name[god.name] = []
		gods_by_name[god.name].append(god)
	
	# For each god name that has duplicates, select all but the first one
	var duplicates_selected = 0
	for god_name in gods_by_name:
		var gods_with_this_name = gods_by_name[god_name]
		
		# Only process if there are actually duplicates (more than 1)
		if gods_with_this_name.size() > 1:
			# Sort by level/power to keep the best one (optional - keeps highest level)
			gods_with_this_name.sort_custom(func(a, b): return a.level > b.level)
			
			# Select all except the first one (keep the highest level one)
			for i in range(1, gods_with_this_name.size()):
				var duplicate_god = gods_with_this_name[i]
				if not selected_materials.has(duplicate_god):
					selected_materials.append(duplicate_god)
					duplicates_selected += 1
	
	if duplicates_selected > 0:
		show_selection_feedback("Selected %d duplicate gods (keeping 1 of each)" % duplicates_selected, Color.CYAN)
	else:
		show_selection_feedback("No duplicates found", Color.YELLOW)
	
	update_all_displays()

func _on_clear_selection_pressed():
	"""Clear all selected materials"""
	if locked_in:
		return
	
	var cleared_count = selected_materials.size()
	selected_materials.clear()
	
	if cleared_count > 0:
		show_selection_feedback("Cleared %d selected gods" % cleared_count, Color.ORANGE)
	else:
		show_selection_feedback("No gods to clear", Color.GRAY)
	
	update_all_displays()

func sort_gods(gods: Array):
	"""Sort gods array based on current sort settings"""
	gods.sort_custom(func(a, b):
		var result = false
		match current_sort:
			SortType.POWER:
				result = a.get_power_rating() > b.get_power_rating()
			SortType.LEVEL:
				result = a.level > b.level
			SortType.TIER:
				result = a.tier > b.tier
			SortType.ELEMENT:
				result = a.element < b.element  # Sort by element enum value
			SortType.NAME:
				result = a.name < b.name
		
		# Apply sort direction
		return result if not sort_ascending else !result
	)

func populate_material_grid():
	"""Populate the material selection grid"""
	# Save scroll position
	var scroll_container = material_grid.get_parent()
	if scroll_container is ScrollContainer:
		scroll_position.y = scroll_container.get_v_scroll()
	
	# Clear existing
	for child in material_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if not GameManager or not GameManager.player_data:
		return
	
	# Get and sort gods (exclude the target)
	var gods = []
	for god in GameManager.player_data.gods:
		if god == target_god:
			continue
		gods.append(god)
	
	# Sort the gods
	sort_gods(gods)
	
	# Add sorted gods to grid
	for god in gods:
		var god_item = create_god_grid_item(god)
		material_grid.add_child(god_item)
	
	# Restore scroll position after content is added
	await get_tree().process_frame
	if scroll_container is ScrollContainer:
		scroll_container.set_v_scroll(int(scroll_position.y))

func create_god_grid_item(god: God) -> Control:
	"""Create a compact grid item for god selection with essential sacrifice info"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(120, 140)
	
	# Style based on selection state with subtle colors
	var style = StyleBoxFlat.new()
	if selected_materials.has(god):
		style.bg_color = Color(0.8, 0.4, 0.2, 0.9)  # Orange for selected
		style.border_color = Color(1.0, 0.6, 0.3, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	elif locked_in:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Gray when locked
		style.border_color = Color(0.5, 0.5, 0.5, 0.8)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	else:
		style.bg_color = get_subtle_tier_color(god.tier)
		style.border_color = get_tier_border_color(god.tier)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	item.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	item.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	# God image (compact)
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god image using the new sprite function
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	
	vbox.add_child(god_image)
	
	# God name (compact)
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier (SW style)
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Sacrifice value (important for XP calculations)
	var sacrifice_value = 0
	if GameManager and GameManager.sacrifice_system:
		sacrifice_value = GameManager.sacrifice_system.get_god_base_sacrifice_value(god)
	
	var value_label = Label.new()
	value_label.text = "XP:%d" % sacrifice_value
	value_label.add_theme_font_size_override("font_size", 9)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(value_label)
	
	# Make clickable (only if not locked in)
	if not locked_in:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_god_clicked.bind(god))
		item.add_child(button)
	
	return item

func get_subtle_tier_color(tier: God.TierType) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		God.TierType.COMMON:
			return Color(0.25, 0.25, 0.25, 0.7)  # Dark gray
		God.TierType.RARE:
			return Color(0.2, 0.3, 0.2, 0.7)     # Dark green
		God.TierType.EPIC:
			return Color(0.3, 0.2, 0.4, 0.7)     # Dark purple
		God.TierType.LEGENDARY:
			return Color(0.4, 0.3, 0.1, 0.7)     # Dark gold
		_:
			return Color(0.2, 0.2, 0.3, 0.7)

func get_tier_border_color(tier: God.TierType) -> Color:
	"""Get border colors for tiers"""
	match tier:
		God.TierType.COMMON:
			return Color(0.5, 0.5, 0.5, 0.8)     # Gray
		God.TierType.RARE:
			return Color(0.4, 0.8, 0.4, 1.0)     # Green
		God.TierType.EPIC:
			return Color(0.7, 0.4, 1.0, 1.0)     # Purple
		God.TierType.LEGENDARY:
			return Color(1.0, 0.8, 0.2, 1.0)     # Gold
		_:
			return Color(0.6, 0.6, 0.6, 0.8)

func get_tier_short_name(tier: God.TierType) -> String:
	"""Get short tier names for compact display"""
	match tier:
		God.TierType.COMMON: return "★"      # COMMON
		God.TierType.RARE: return "★★"       # RARE  
		God.TierType.EPIC: return "★★★"      # EPIC
		God.TierType.LEGENDARY: return "★★★★" # LEGENDARY
		_: return "?"

func get_tier_color(tier: God.TierType) -> Color:
	"""Get background color based on god tier"""
	match tier:
		God.TierType.COMMON:
			return Color(0.3, 0.3, 0.3, 0.6)  # Gray
		God.TierType.RARE:
			return Color(0.2, 0.4, 0.2, 0.6)  # Green
		God.TierType.EPIC:
			return Color(0.3, 0.2, 0.5, 0.6)  # Purple
		God.TierType.LEGENDARY:
			return Color(0.5, 0.4, 0.1, 0.6)  # Gold
		_: return "?"

func _on_god_clicked(god: God):
	"""Handle god selection for materials"""
	if locked_in:
		return
	
	if selected_materials.has(god):
		# Remove from selection
		selected_materials.erase(god)
		show_selection_feedback("Removed %s from materials" % god.name, Color.YELLOW)
	else:
		# Add to selection - no limit!
		selected_materials.append(god)
		show_selection_feedback("Added %s to materials (%d selected)" % [god.name, selected_materials.size()], Color.GREEN)
	
	update_all_displays()

func show_selection_feedback(message: String, color: Color):
	"""Show temporary feedback message"""
	if not selection_status_label:
		return
	
	selection_status_label.text = message
	selection_status_label.modulate = color
	selection_status_label.visible = true
	
	# Hide after 2 seconds using correct Godot 4 tween syntax
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): 
		if selection_status_label:
			selection_status_label.visible = false
	)

func update_all_displays():
	"""Update all UI displays"""
	update_target_display()
	update_xp_bar()
	populate_material_grid()
	update_button_states()

func update_target_display():
	"""Update the target god display with image"""
	if not target_god:
		return
	
	# Clear existing
	for child in target_god_display.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	target_god_display.add_child(hbox)
	
	# Add margins
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(left_margin)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [target_god.name, target_god.level]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	var details_label = Label.new()
	details_label.text = "%s %s - Power: %d" % [target_god.get_tier_name(), target_god.get_element_name(), target_god.get_power_rating()]
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.modulate = Color.LIGHT_GRAY
	info_vbox.add_child(details_label)
	
	hbox.add_child(info_vbox)
	
	# God image on the right
	var image_container = VBoxContainer.new()
	image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_container.custom_minimum_size = Vector2(60, 0)
	
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god image using the new sprite function
	var god_texture = target_god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	
	image_container.add_child(god_image)
	hbox.add_child(image_container)

func update_xp_bar():
	"""Update the XP bar with current + preview XP"""
	if not target_god or not xp_bar or not xp_label or not level_preview_label:
		return
	
	var current_level = target_god.level
	var current_xp = target_god.experience
	var max_level = 40  # Updated to level 40
	
	# Calculate preview XP if materials selected
	var preview_xp = 0
	if selected_materials.size() > 0 and GameManager and GameManager.sacrifice_system:
		var sacrifice_result = GameManager.sacrifice_system.calculate_sacrifice_experience(selected_materials, target_god)
		preview_xp = sacrifice_result.total_xp
	
	if current_level >= max_level:
		# Max level
		xp_bar.value = 100
		xp_bar.modulate = Color.GOLD
		xp_label.text = "MAX LEVEL"
		level_preview_label.text = "Level %d (MAX)" % current_level
		return
	
	# Calculate XP needed for current level using SW scaling
	var xp_needed_for_next = target_god.get_experience_to_next_level()
	
	# Calculate progress within current level - simplified for now
	var xp_progress_in_level = current_xp
	
	# Calculate what happens with preview XP
	var levels_gained = 0
	if preview_xp > 0 and GameManager and GameManager.sacrifice_system:
		levels_gained = GameManager.sacrifice_system.calculate_levels_gained(target_god, preview_xp)
	
	# Update progress bar
	var current_level_progress = float(xp_progress_in_level) / float(xp_needed_for_next)
	if preview_xp > 0:
		# Show preview with green color
		xp_bar.value = min(100, current_level_progress * 100)
		xp_bar.modulate = Color.GREEN
	else:
		# Show current progress
		xp_bar.value = current_level_progress * 100
		xp_bar.modulate = Color.WHITE
	
	# Update text labels
	if preview_xp > 0:
		var final_level = min(current_level + levels_gained, max_level)
		xp_label.text = "%d XP (+%d)" % [current_xp, preview_xp]
		if levels_gained > 0:
			level_preview_label.text = "Level %d → %d (+%d)" % [current_level, final_level, levels_gained]
		else:
			level_preview_label.text = "Level %d (XP gained, no level up)" % current_level
	else:
		var xp_to_next = xp_needed_for_next
		xp_label.text = "%d / %d XP" % [xp_progress_in_level, xp_to_next]
		level_preview_label.text = "Level %d (%d XP to next)" % [current_level, xp_to_next]

func update_button_states():
	"""Update button enabled/disabled states"""
	if selected_materials.size() > 0 and not locked_in:
		lock_in_button.disabled = false
		lock_in_button.text = "Lock In Selection (%d gods)" % selected_materials.size()
	else:
		lock_in_button.disabled = true
		lock_in_button.text = "Lock In Selection"
	
	sacrifice_button.disabled = not locked_in or selected_materials.size() == 0

func _on_lock_in_pressed():
	"""Lock in the current selection"""
	if selected_materials.size() == 0:
		return
	
	locked_in = true
	lock_in_button.text = "Selection Locked (%d gods)" % selected_materials.size()
	lock_in_button.disabled = true
	
	# Refresh grid to show locked state
	populate_material_grid()
	update_button_states()

func _on_sacrifice_pressed():
	"""Perform the sacrifice operation"""
	if not locked_in or selected_materials.size() == 0 or not target_god:
		return
	
	# Show confirmation dialog
	show_sacrifice_confirmation()

func show_sacrifice_confirmation():
	"""Show confirmation dialog for sacrifice"""
	if not GameManager or not GameManager.sacrifice_system:
		return
	
	var sacrifice_result = GameManager.sacrifice_system.calculate_sacrifice_experience(selected_materials, target_god)
	var levels_gained = GameManager.sacrifice_system.calculate_levels_gained(target_god, sacrifice_result.total_xp)
	
	var dialog_text = "Sacrifice to %s?\n\n" % target_god.name
	dialog_text += "Materials: %d gods\n" % selected_materials.size()
	dialog_text += "XP Gain: %d\n" % sacrifice_result.total_xp
	dialog_text += "Level Gain: +%d levels\n\n" % levels_gained
	dialog_text += "This action cannot be undone!"
	
	show_confirmation_dialog("Confirm Sacrifice", dialog_text, perform_sacrifice)

func perform_sacrifice():
	"""Actually perform the sacrifice"""
	if not GameManager or not GameManager.sacrifice_system:
		return
	
	var success = GameManager.sacrifice_system.perform_sacrifice(target_god, selected_materials, GameManager.player_data)
	if success:
		# Reset state
		selected_materials.clear()
		locked_in = false
		
		# Update displays
		update_all_displays()
		
		# Show success message
		show_info_dialog("Sacrifice Complete!", "Your god has been powered up successfully!")
	else:
		show_info_dialog("Sacrifice Failed", "Failed to sacrifice to your god. Please try again.")

func show_info_dialog(title: String, message: String):
	"""Show an info dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_confirmation_dialog(title: String, message: String, callback: Callable):
	"""Show a confirmation dialog"""
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(callback)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()
