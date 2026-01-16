# scripts/ui/screens/SacrificeSelectionScreen.gd
# RULE 1 COMPLIANCE: 500-line limit enforced  
# RULE 2 COMPLIANCE: Single responsibility - sacrifice selection screen UI
# RULE 4 COMPLIANCE: UI layer - display coordination only, no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
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

# UI elements
var xp_bar: ProgressBar = null
var xp_label: Label = null
var level_preview_label: Label = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	
	setup_ui()
	
	# Auto-initialize with target god from SacrificeManager if available
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			var temp_target_god = sacrifice_manager.get_temporary_target_god()
			if temp_target_god:
				initialize_with_god(temp_target_god)

func initialize_with_god(god: God):
	"""Initialize the screen with a target god"""
	target_god = god
	selected_materials.clear()
	locked_in = false
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

func populate_material_grid():
	"""Populate the material selection grid"""
	# Clear existing
	for child in material_grid.get_children():
		child.queue_free()
	
	# Get gods from SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return
		
	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return
	
	var gods = collection_manager.get_all_gods()
	
	# Create god cards (exclude target god)
	for god in gods:
		if god == target_god:
			continue
		
		var card = create_god_card(god)
		material_grid.add_child(card)

func create_god_card(god: God) -> Control:
	"""Create a god card for material selection"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(100, 120)
	
	# Style based on selection
	var style = StyleBoxFlat.new()
	if selected_materials.has(god):
		style.bg_color = Color(0.8, 0.4, 0.2, 0.9)  # Selected
		style.border_color = Color(1.0, 0.6, 0.3, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	else:
		style.bg_color = Color(0.25, 0.25, 0.35, 0.8)
		style.border_color = Color(0.5, 0.5, 0.7, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 5)
	vbox.add_theme_constant_override("margin_right", 5)
	vbox.add_theme_constant_override("margin_top", 5)
	vbox.add_theme_constant_override("margin_bottom", 5)
	card.add_child(vbox)
	
	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(60, 60)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god sprite using path construction
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		var god_texture = load(sprite_path)
		god_image.texture = god_texture
	else:
		# Create placeholder colored rectangle if no sprite exists
		var placeholder = StyleBoxFlat.new()
		placeholder.bg_color = Color(0.5, 0.5, 0.5, 0.8)
		god_image.add_theme_stylebox_override("normal", placeholder)
	
	vbox.add_child(god_image)
	
	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Level info
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Make clickable if not locked
	if not locked_in:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_god_clicked.bind(god))
		card.add_child(button)
	
	return card

func _on_god_clicked(god: God):
	"""Handle god selection"""
	if locked_in:
		return
	
	if selected_materials.has(god):
		selected_materials.erase(god)
	else:
		selected_materials.append(god)
	
	update_all_displays()

func update_all_displays():
	"""Update all UI displays"""
	update_target_display()
	update_xp_bar()
	populate_material_grid()
	update_button_states()

func update_target_display():
	"""Update target god display"""
	if not target_god:
		return
	
	# Clear and rebuild
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
	details_label.text = "%s %s - Power: %d" % [God.tier_to_string(target_god.tier), God.element_to_string(target_god.element), target_god.get_power_rating()]
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.modulate = Color.LIGHT_GRAY
	info_vbox.add_child(details_label)
	
	hbox.add_child(info_vbox)
	
	# God image
	var image_container = VBoxContainer.new()
	image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_container.custom_minimum_size = Vector2(60, 0)
	
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god sprite using path construction
	var sprite_path = "res://assets/gods/" + target_god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		var god_texture = load(sprite_path)
		god_image.texture = god_texture
	
	image_container.add_child(god_image)
	hbox.add_child(image_container)

func update_xp_bar():
	"""Update XP bar display"""
	if not target_god or not xp_bar or not xp_label or not level_preview_label:
		return
	
	var current_level = target_god.level
	var current_xp = target_god.experience
	var max_level = 40
	
	# Calculate preview XP
	var preview_xp = 0
	if selected_materials.size() > 0:
		var system_registry = SystemRegistry.get_instance()
		if system_registry:
			var sacrifice_system = system_registry.get_system("SacrificeSystem")
			if sacrifice_system:
				var result = sacrifice_system.calculate_sacrifice_experience(selected_materials, target_god)
				preview_xp = result.total_xp
	
	if current_level >= max_level:
		xp_bar.value = 100
		xp_bar.modulate = Color.GOLD
		xp_label.text = "MAX LEVEL"
		level_preview_label.text = "Level %d (MAX)" % current_level
		return
	
	# Calculate progress
	var xp_needed_for_next = GodCalculator.get_experience_to_next_level(target_god)
	var xp_progress_in_level = current_xp
	var current_level_progress = float(xp_progress_in_level) / float(xp_needed_for_next)
	
	# Update progress bar
	if preview_xp > 0:
		xp_bar.value = min(100, current_level_progress * 100)
		xp_bar.modulate = Color.GREEN
		xp_label.text = "%d XP (+%d)" % [current_xp, preview_xp]
		level_preview_label.text = "Level %d (Preview: +%d XP)" % [current_level, preview_xp]
	else:
		xp_bar.value = current_level_progress * 100
		xp_bar.modulate = Color.WHITE
		var xp_to_next = xp_needed_for_next
		xp_label.text = "%d / %d XP" % [xp_progress_in_level, xp_to_next]
		level_preview_label.text = "Level %d (%d XP to next)" % [current_level, xp_to_next]

func update_button_states():
	"""Update button states"""
	if selected_materials.size() > 0 and not locked_in:
		lock_in_button.disabled = false
		lock_in_button.text = "Lock In Selection (%d gods)" % selected_materials.size()
	else:
		lock_in_button.disabled = true
		lock_in_button.text = "Lock In Selection"
	
	sacrifice_button.disabled = not locked_in or selected_materials.size() == 0

func _on_lock_in_pressed():
	"""Lock in selection"""
	if selected_materials.size() == 0:
		return
	
	locked_in = true
	lock_in_button.text = "Selection Locked (%d gods)" % selected_materials.size()
	lock_in_button.disabled = true
	
	update_all_displays()

func _on_sacrifice_pressed():
	"""Perform sacrifice"""
	if not locked_in or selected_materials.size() == 0 or not target_god:
		return
	
	# Perform the sacrifice through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return
		
	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return
	
	var sacrifice_manager = system_registry.get_system("SacrificeManager")
	var result = sacrifice_manager.perform_sacrifice(target_god, selected_materials)
	
	if result.success:
		# Show success dialog and go back to main menu
		show_info_dialog("Sacrifice Complete!", "Your god gained %d experience!" % result.xp_gained, true)
	else:
		show_info_dialog("Sacrifice Failed", result.error, false)

func show_info_dialog(title: String, message: String, navigate_back: bool = false):
	"""Show info dialog with optional navigation back to main menu"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.popup_centered()
	
	if navigate_back:
		dialog.confirmed.connect(func(): 
			dialog.queue_free()
			_navigate_back_to_main()
		)
	else:
		dialog.confirmed.connect(func(): dialog.queue_free())

func _navigate_back_to_main():
	"""Navigate back to the main world view"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("worldview")

func _on_back_pressed():
	"""Handle back button - use ScreenManager for proper navigation"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var screen_manager = system_registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("sacrifice")
	
	back_pressed.emit()
