# scripts/ui/components/SacrificeMaterialManager.gd
# Single responsibility: Handle material selection, sorting, and god grid management
class_name SacrificeMaterialManager extends Node

# Material selection signals
signal materials_selection_changed(selected_materials: Array)
signal selection_locked_in(materials: Array)
signal selection_cleared

# UI references
var material_grid: Control
var material_section: Control

# Selection state
var selected_materials: Array = []  # Array[God]
var locked_in: bool = false
var max_materials: int = 6  # Can be changed

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)

# Scroll position preservation
var scroll_position: Vector2 = Vector2.ZERO

func initialize(grid_container: Control, section_container: Control):
	"""Initialize with the material grid and section containers"""
	material_grid = grid_container
	material_section = section_container
	setup_sorting_ui()
	print("SacrificeMaterialManager: Initialized")

func set_max_materials(count: int):
	"""Change the maximum number of materials allowed"""
	max_materials = max(1, min(count, 12))  # Clamp between 1 and 12
	
	# If we have too many selected, trim the list
	while selected_materials.size() > max_materials:
		selected_materials.pop_back()
	
	refresh_material_grid()

func get_selected_materials() -> Array:
	"""Get currently selected materials"""
	return selected_materials.duplicate()

func is_locked_in() -> bool:
	"""Check if selection is locked in"""
	return locked_in

func lock_in_selection():
	"""Lock in the current selection"""
	if selected_materials.size() == 0:
		return false
	
	locked_in = true
	refresh_material_grid()  # Refresh to show locked state
	selection_locked_in.emit(selected_materials.duplicate())
	return true

func unlock_selection():
	"""Unlock the selection for changes"""
	locked_in = false
	refresh_material_grid()

func clear_selection():
	"""Clear all selected materials"""
	if locked_in:
		return false
	
	var cleared_count = selected_materials.size()
	selected_materials.clear()
	
	if cleared_count > 0:
		refresh_material_grid()
		materials_selection_changed.emit(selected_materials.duplicate())
		selection_cleared.emit()
	
	return true

func setup_sorting_ui():
	"""Add sorting controls to the material selection area - RULE 4: UI creation only"""
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
			style.bg_color = Color.CYAN
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
	
	# Insert sorting controls at the top
	material_section.add_child(sort_container)
	material_section.move_child(sort_container, 0)

func refresh_material_grid():
	"""Refresh the material selection grid - RULE 5: Use SystemRegistry"""
	if not material_grid:
		return
	
	# Save scroll position
	preserve_scroll_position()
	
	# Clear existing
	for child in material_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Load gods through SystemRegistry
	load_available_gods()
	
	# Restore scroll position
	restore_scroll_position()

func preserve_scroll_position():
	"""Save current scroll position"""
	var scroll_container = material_grid.get_parent()
	if scroll_container is ScrollContainer:
		scroll_position.y = scroll_container.get_v_scroll()

func restore_scroll_position():
	"""Restore saved scroll position"""
	await get_tree().process_frame
	var scroll_container = material_grid.get_parent()
	if scroll_container is ScrollContainer:
		scroll_container.set_v_scroll(int(scroll_position.y))

func load_available_gods():
	"""Load available gods through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		show_loading_placeholder("SystemRegistry not available")
		return
	
	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		show_loading_placeholder("CollectionManager not found")
		return
	
	# Get available gods for sacrifice
	var available_gods = collection_manager.get_all_gods()
	
	# Filter gods (e.g., remove max level gods, equipped gods)
	available_gods = filter_available_gods(available_gods)
	
	# Sort gods based on current sort settings
	sort_gods(available_gods)
	
	# Create god cards in batches for smooth performance
	load_gods_in_batches(available_gods)

func show_loading_placeholder(message: String):
	"""Show placeholder while loading"""
	if material_grid:
		var placeholder_label = Label.new()
		placeholder_label.text = message
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		material_grid.add_child(placeholder_label)

func filter_available_gods(gods: Array) -> Array:
	"""Filter gods that can be used as sacrifice materials"""
	var filtered_gods = []
	
	for god in gods:
		# Skip gods that shouldn't be sacrificed
		if can_use_as_material(god):
			filtered_gods.append(god)
	
	return filtered_gods

func can_use_as_material(god: God) -> bool:
	"""Check if god can be used as sacrifice material"""
	# Add filtering logic here
	# For example: not equipped, not in defense team, not max level if preserving, etc.
	
	# Basic example - don't sacrifice max level gods
	if god.level >= 40:
		return false
	
	return true

func sort_gods(gods: Array):
	"""Sort gods array based on current sort settings"""
	gods.sort_custom(func(a: God, b: God):
		var result = false
		match current_sort:
			SortType.POWER:
				result = a.get_power_rating() < b.get_power_rating()
			SortType.LEVEL:
				result = a.level < b.level
			SortType.TIER:
				result = int(a.tier) < int(b.tier)
			SortType.ELEMENT:
				result = God.element_to_string(a.element) < God.element_to_string(b.element)
			SortType.NAME:
				result = a.name < b.name
		
		# Apply sort direction
		return result if not sort_ascending else !result
	)

func load_gods_in_batches(gods: Array):
	"""Load gods in batches for smooth performance"""
	var batch_size = 8  # Reasonable batch size for sacrifice selection
	var batch_state = {"current_batch": 0}  # Use dictionary for reference
	
	var batch_timer = Timer.new()
	batch_timer.wait_time = 0.016  # ~60 FPS (16ms per frame)
	batch_timer.timeout.connect(func():
		var start_idx = batch_state.current_batch * batch_size
		var end_idx = min(start_idx + batch_size, gods.size())
		
		# Load this batch
		for i in range(start_idx, end_idx):
			var god = gods[i]
			var god_card = create_god_selection_card(god)
			material_grid.add_child(god_card)
		
		batch_state.current_batch += 1
		
		# Check if we're done
		if end_idx >= gods.size():
			batch_timer.queue_free()
	)
	
	add_child(batch_timer)
	batch_timer.start()

func create_god_selection_card(god: God) -> Control:
	"""Create a compact selection card for god - RULE 4: UI creation only"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(120, 140)
	
	# Style based on selection state
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
	
	# Add content
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
	
	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	
	vbox.add_child(god_image)
	
	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Sacrifice XP value
	var sacrifice_value = calculate_sacrifice_value(god)
	var value_label = Label.new()
	value_label.text = "XP:%d" % sacrifice_value
	value_label.add_theme_font_size_override("font_size", 9)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(value_label)
	
	# Make clickable if not locked
	if not locked_in:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_god_clicked.bind(god))
		item.add_child(button)
	
	return item

func calculate_sacrifice_value(god: God) -> int:
	"""Calculate XP value for sacrifice - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			return sacrifice_manager.get_god_sacrifice_value(god)
	
	# Fallback calculation
	return god.level * 100 + int(god.tier) * 200

# === EVENT HANDLERS ===

func _on_god_clicked(god: God):
	"""Handle god selection click"""
	if locked_in:
		return
	
	if selected_materials.has(god):
		# Remove from selection
		selected_materials.erase(god)
	else:
		# Add to selection
		selected_materials.append(god)
	
	# Refresh only this card's styling
	refresh_material_grid()
	materials_selection_changed.emit(selected_materials.duplicate())

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	setup_sorting_ui()  # Refresh UI to show new selection
	refresh_material_grid()

func _on_sort_direction_changed():
	"""Toggle sort direction"""
	sort_ascending = !sort_ascending
	setup_sorting_ui()  # Refresh direction arrow
	refresh_material_grid()

func _on_select_duplicates_pressed():
	"""Select all duplicate gods (leaving 1 copy of each)"""
	if locked_in:
		return
	
	# This would need CollectionManager to identify duplicates
	print("SacrificeMaterialManager: Select duplicates feature needs CollectionManager implementation")

func _on_clear_selection_pressed():
	"""Clear all selected materials"""
	clear_selection()

# === UTILITY FUNCTIONS ===

func get_subtle_tier_color(tier: God.TierType) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		God.TierType.COMMON: return Color(0.25, 0.25, 0.25, 0.7)
		God.TierType.RARE: return Color(0.2, 0.3, 0.2, 0.7)
		God.TierType.EPIC: return Color(0.3, 0.2, 0.4, 0.7)
		God.TierType.LEGENDARY: return Color(0.4, 0.3, 0.1, 0.7)
		_: return Color(0.2, 0.2, 0.2, 0.7)

func get_tier_border_color(tier: God.TierType) -> Color:
	"""Get border colors for tiers"""
	match tier:
		God.TierType.COMMON: return Color(0.5, 0.5, 0.5, 0.8)
		God.TierType.RARE: return Color(0.4, 0.8, 0.4, 1.0)
		God.TierType.EPIC: return Color(0.7, 0.4, 1.0, 1.0)
		God.TierType.LEGENDARY: return Color(1.0, 0.8, 0.2, 1.0)
		_: return Color(0.6, 0.6, 0.6, 0.8)

func get_tier_short_name(tier: God.TierType) -> String:
	"""Get short tier names for compact display"""
	match tier:
		God.TierType.COMMON: return "★"
		God.TierType.RARE: return "★★"
		God.TierType.EPIC: return "★★★"
		God.TierType.LEGENDARY: return "★★★★"
		_: return "?"
