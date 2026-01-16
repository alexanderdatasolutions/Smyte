# scripts/ui/components/SacrificeTargetDisplayManager.gd
# Single responsibility: Display sacrifice target god info and XP preview
class_name SacrificeTargetDisplayManager extends Node

# Target display signals
signal target_display_updated
signal xp_preview_changed(preview_xp: int, levels_gained: int)

var target_god_container: Control
var xp_bar_container: Control
var current_target_god: God

# XP bar UI elements
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_preview_label: Label = null

func initialize(target_container: Control, xp_container: Control):
	"""Initialize with the target display containers"""
	target_god_container = target_container
	xp_bar_container = xp_container
	print("SacrificeTargetDisplayManager: Initialized")

func set_target_god(god: God):
	"""Set the target god for sacrifice - FOLLOWING RULE 4: UI display only"""
	current_target_god = god
	setup_target_display()
	setup_xp_bar()
	update_displays_with_no_preview()

func preview_sacrifice_result(selected_materials: Array):
	"""Preview XP gain from selected materials - RULE 4: UI calculations only"""
	if not current_target_god:
		return
	
	# Calculate preview XP through SystemRegistry - RULE 5 compliance
	var preview_xp = 0
	var levels_gained = 0
	
	if selected_materials.size() > 0:
		var system_registry = SystemRegistry.get_instance()
		if system_registry:
			var sacrifice_manager = system_registry.get_system("SacrificeManager")
			if sacrifice_manager:
				preview_xp = sacrifice_manager.calculate_sacrifice_xp(selected_materials)
				levels_gained = sacrifice_manager.calculate_levels_gained(current_target_god, preview_xp)
			else:
				print("SacrificeTargetDisplayManager: SacrificeManager not found in SystemRegistry")
	
	update_xp_bar_with_preview(preview_xp, levels_gained)
	xp_preview_changed.emit(preview_xp, levels_gained)

func setup_target_display():
	"""Setup target god display with image and info"""
	if not current_target_god or not target_god_container:
		return
	
	# Clear existing
	for child in target_god_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create styled panel
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
	target_god_container.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	target_god_container.add_child(hbox)
	
	# Add margins
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(left_margin)
	
	# God info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [current_target_god.name, current_target_god.level]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	var details_label = Label.new()
	details_label.text = "%s %s - Power: %d" % [
		God.tier_to_string(current_target_god.tier), 
		God.element_to_string(current_target_god.element), 
		current_target_god.get_power_rating()
	]
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
	
	# Load god image based on god ID (matching CollectionScreen approach)
	var sprite_path = "res://assets/gods/" + current_target_god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		god_image.texture = load(sprite_path)
	else:
		print("SacrificeTargetDisplayManager: God sprite not found: ", sprite_path)
	
	image_container.add_child(god_image)
	hbox.add_child(image_container)
	
	target_display_updated.emit()

func setup_xp_bar():
	"""Create the XP bar display with progress visualization"""
	if not xp_bar_container:
		return
	
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
	
	# XP bar with text
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

func update_displays_with_no_preview():
	"""Update displays showing current state with no preview"""
	update_xp_bar_with_preview(0, 0)

func update_xp_bar_with_preview(preview_xp: int, levels_gained: int):
	"""Update XP bar with current + preview XP - RULE 4: UI calculations only"""
	if not current_target_god or not xp_bar or not xp_label or not level_preview_label:
		return
	
	var current_level = current_target_god.level
	var current_xp = current_target_god.experience
	var max_level = 40  # Updated to level 40 like SW
	
	if current_level >= max_level:
		# Max level display
		xp_bar.value = 100
		xp_bar.modulate = Color.GOLD
		xp_label.text = "MAX LEVEL"
		level_preview_label.text = "Level %d (MAX)" % current_level
		return
	
	# Calculate XP needed for current level using god's method
	var xp_needed_for_next = current_target_god.get_experience_to_next_level()
	var xp_progress_in_level = current_xp
	
	# Calculate current progress percentage
	var current_level_progress = float(xp_progress_in_level) / float(xp_needed_for_next)
	
	# Update progress bar appearance
	if preview_xp > 0:
		# Show preview with green color indicating gain
		xp_bar.value = min(100, current_level_progress * 100)
		xp_bar.modulate = Color.GREEN
		
		# Update text labels with preview
		var final_level = min(current_level + levels_gained, max_level)
		xp_label.text = "%d XP (+%d)" % [current_xp, preview_xp]
		
		if levels_gained > 0:
			level_preview_label.text = "Level %d → %d (+%d)" % [current_level, final_level, levels_gained]
		else:
			level_preview_label.text = "Level %d (XP gained, no level up)" % current_level
	else:
		# Show current progress with normal color
		xp_bar.value = current_level_progress * 100
		xp_bar.modulate = Color.WHITE
		
		# Update text labels without preview
		var xp_to_next = xp_needed_for_next
		xp_label.text = "%d / %d XP" % [xp_progress_in_level, xp_to_next]
		level_preview_label.text = "Level %d (%d XP to next)" % [current_level, xp_to_next]

func get_current_target_god() -> God:
	"""Get the current target god"""
	return current_target_god

func clear_displays():
	"""Clear all displays"""
	if target_god_container:
		for child in target_god_container.get_children():
			child.queue_free()
	
	if xp_bar_container:
		for child in xp_bar_container.get_children():
			child.queue_free()
	
	current_target_god = null
