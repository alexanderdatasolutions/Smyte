# scripts/ui/SummonScreen.gd
extends Control

signal back_pressed

@onready var summon_container = $MainContainer/LeftPanel/SummonContainer
@onready var back_button = $BackButton
@onready var showcase_content = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent
@onready var default_message = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent/DefaultMessage

# Summon buttons (created dynamically)
var basic_button: Button
var premium_button: Button
var element_button: Button
var crystal_button: Button
var daily_free_button: Button
var basic_10x_button: Button
var premium_10x_button: Button

# Current selected element for element summons
var selected_element: int = 0  # Fire by default

# Animation nodes
var tween: Tween
var current_summons: Array = []
var is_processing_summon: bool = false  # Prevent duplicate summon processing

func _ready():
	# Wait a frame to ensure all nodes are fully initialized
	await get_tree().process_frame
	
	# Add safety checks for all node references
	if not summon_container:
		return
	if not showcase_content:
		return
	if not default_message:
		return
		
	# Convert showcase_content to GridContainer for 2-column layout
	setup_showcase_grid()
	
	# Configure showcase content spacing
	if showcase_content:
		showcase_content.add_theme_constant_override("separation", 5)  # Minimal spacing between god cards
	
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Connect to SummonManager through SystemRegistry
	var summon_manager = SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null
	if summon_manager:
		# Connect to summon system signals
		if summon_manager.summon_completed.is_connected(_on_god_summoned):
			summon_manager.summon_completed.disconnect(_on_god_summoned)
		if summon_manager.summon_failed.is_connected(_on_summon_failed):
			summon_manager.summon_failed.disconnect(_on_summon_failed)
		if summon_manager.multi_summon_completed.is_connected(_on_multi_summon_completed):
			summon_manager.multi_summon_completed.disconnect(_on_multi_summon_completed)
			
		# Now connect
		summon_manager.summon_completed.connect(_on_god_summoned)
		summon_manager.summon_failed.connect(_on_summon_failed)
		summon_manager.multi_summon_completed.connect(_on_multi_summon_completed)

	# Create summon cards in grid layout
	create_summon_cards()

func setup_showcase_grid():
	# Convert showcase_content from VBoxContainer to GridContainer for 2-column layout
	if not showcase_content:
		return
		
	if showcase_content is GridContainer:
		return
		
	var showcase_parent = showcase_content.get_parent()
	if not showcase_parent:
		return
		
	var showcase_pos = showcase_content.get_index()
	var showcase_name = showcase_content.name
	
	# Store any existing children (like default message)
	var existing_children = []
	for child in showcase_content.get_children():
		existing_children.append(child)
		showcase_content.remove_child(child)  # Don't queue_free, just move
	
	# Remove old container
	showcase_content.queue_free()
	
	# Create new GridContainer with 2 columns for left-right, top-bottom layout
	var grid = GridContainer.new()
	grid.name = showcase_name
	grid.columns = 2  # 2 columns: top-left, top-right, bottom-left, bottom-right, etc.
	grid.add_theme_constant_override("h_separation", 10)  # Horizontal spacing
	grid.add_theme_constant_override("v_separation", 10)  # Vertical spacing
	
	# Add to parent at same position
	showcase_parent.add_child(grid)
	showcase_parent.move_child(grid, showcase_pos)
	
	# Re-add existing children
	for child in existing_children:
		if child and is_instance_valid(child):
			grid.add_child(child)
	
	# Update reference
	showcase_content = grid

func create_summon_cards():
	# Add safety check
	if not summon_container:
		return

	# Convert summon_container to GridContainer if it isn't already
	if not summon_container is GridContainer:
		var parent = summon_container.get_parent()
		if not parent:
			return
			
		var pos = summon_container.get_index()
		summon_container.queue_free()
		
		# Create new GridContainer with enhanced styling
		var grid = GridContainer.new()
		grid.name = "SummonContainer"
		grid.columns = 3  # 3 columns for nice layout
		grid.add_theme_constant_override("h_separation", 15)
		grid.add_theme_constant_override("v_separation", 15)
		
		# Add subtle background to the grid
		var grid_style = StyleBoxFlat.new()
		grid_style.bg_color = Color.BLACK
		grid_style.bg_color.a = 0.1
		grid_style.corner_radius_top_left = 8
		grid_style.corner_radius_top_right = 8
		grid_style.corner_radius_bottom_left = 8
		grid_style.corner_radius_bottom_right = 8
		grid_style.border_width_left = 1
		grid_style.border_width_top = 1
		grid_style.border_width_right = 1
		grid_style.border_width_bottom = 1
		grid_style.border_color = Color.GRAY
		grid_style.border_color.a = 0.3
		grid.add_theme_stylebox_override("panel", grid_style)
		
		parent.add_child(grid)
		parent.move_child(grid, pos)
		summon_container = grid
	
	# Create Basic Summon Card
	basic_button = create_summon_card(
		"BASIC SUMMON", 
		"Common Soul Summon\nBetter than prayers!",
		"1 Common Soul", 
		Color.CYAN
	)
	if basic_button and summon_container:
		basic_button.pressed.connect(_on_basic_summon_pressed)
		summon_container.add_child(basic_button)
	
	# Create Basic 10x Summon Card
	basic_10x_button = create_summon_card(
		"BASIC 10x SUMMON", 
		"10 Gods Guaranteed\n1 Rare or Better!",
		"9 Common Souls\n(10% OFF!)", 
		Color.CYAN
	)
	if basic_10x_button and summon_container:
		basic_10x_button.pressed.connect(_on_basic_10x_summon_pressed)
		summon_container.add_child(basic_10x_button)
	
	# Create Premium Summon Card
	premium_button = create_summon_card(
		"PREMIUM SUMMON", 
		"Premium Crystal Summon\nHigher Rates!",
		"50 Divine Crystals", 
		Color.GOLD
	)
	if premium_button and summon_container:
		premium_button.pressed.connect(_on_premium_summon_pressed)
		summon_container.add_child(premium_button)
	
	# Create Premium 10x Summon Card
	premium_10x_button = create_summon_card(
		"PREMIUM 10x SUMMON", 
		"10 Premium Gods\n1 Epic or Better!",
		"450 Divine Crystals\n(10% OFF!)", 
		Color.GOLD
	)
	if premium_10x_button and summon_container:
		premium_10x_button.pressed.connect(_on_premium_10x_summon_pressed)
		summon_container.add_child(premium_10x_button)
	
	# Create Element Summon Card
	element_button = create_summon_card(
		"ELEMENT SUMMON", 
		"Element Soul Summon\nTargeted Element!",
		"1 Element Soul", 
		Color.ORANGE_RED
	)
	if element_button and summon_container:
		element_button.pressed.connect(_on_element_summon_pressed)
		summon_container.add_child(element_button)
	
	# Create Crystal Summon Card (Premium Currency)
	crystal_button = create_summon_card(
		"CRYSTAL SUMMON", 
		"Premium Currency\nHigher Legendary Rates!",
		"100 Divine Crystals", 
		Color.DEEP_PINK
	)
	if crystal_button and summon_container:
		crystal_button.pressed.connect(_on_crystal_summon_pressed)
		summon_container.add_child(crystal_button)
	
	# Create Daily Free Summon Card
	daily_free_button = create_summon_card(
		"DAILY FREE SUMMON", 
		"One per day\nBasic rates, no cost!",
		"FREE!", 
		Color.GREEN
	)
	if daily_free_button and summon_container:
		daily_free_button.pressed.connect(_on_daily_free_summon_pressed)
		summon_container.add_child(daily_free_button)
	
	# Create Element Focus Card (fills grid nicely)
	var focus_button = create_summon_card(
		"ELEMENT FOCUS", 
		"Choose your element\nfor targeted summons",
		"Select Below", 
		Color.PURPLE
	)
	if focus_button and summon_container:
		focus_button.pressed.connect(_on_element_focus_pressed)
		summon_container.add_child(focus_button)
	
	# Update daily free button availability
	update_daily_free_availability()

func create_summon_card(title: String, description: String, cost: String, color: Color) -> Button:
	# Create the main summon button
	var button = Button.new()
	button.custom_minimum_size = Vector2(180, 120)
	button.flat = false  # IMPORTANT: Set to false to show background styling
	button.text = ""  # Remove built-in text - we'll use custom labels for better control

	# Create a simple, very visible background first
	var simple_style = StyleBoxFlat.new()
	simple_style.bg_color = color
	simple_style.bg_color.a = 0.8  # Semi-transparent but visible
	simple_style.corner_radius_top_left = 8
	simple_style.corner_radius_top_right = 8
	simple_style.corner_radius_bottom_left = 8
	simple_style.corner_radius_bottom_right = 8
	simple_style.border_width_left = 2
	simple_style.border_width_top = 2
	simple_style.border_width_right = 2
	simple_style.border_width_bottom = 2
	simple_style.border_color = Color.WHITE

	# Apply the simple style immediately
	button.add_theme_stylebox_override("normal", simple_style)
	button.add_theme_color_override("font_color", Color.WHITE)

	# Create a container for custom content layout
	var content_container = VBoxContainer.new()
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.offset_left = 8
	content_container.offset_top = 8
	content_container.offset_right = -8
	content_container.offset_bottom = -8
	content_container.add_theme_constant_override("separation", 4)

	# Add title label (main summon type)
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 1)
	content_container.add_child(title_label)

	# Add cost label
	var cost_label = Label.new()
	cost_label.text = cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color.WHITE)
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(cost_label)

	# Add spacer to push description to bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(spacer)

	# Add description label at bottom (smaller, subtle text)
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_SHRINK_END
	content_container.add_child(desc_label)

	# Add container to button
	button.add_child(content_container)

	# Apply enhanced styling
	style_summon_button(button, color, title)

	return button

func style_summon_button(button: Button, color: Color, _summon_type: String = ""):
	# Create styled button background with gradient and texture
	var normal_style = StyleBoxFlat.new()
	
	# Main background with stronger color visibility
	normal_style.bg_color = color.darkened(0.2)  # Less darkening for visibility
	normal_style.bg_color.a = 0.9  # Higher alpha for visibility
	
	# Add gradient by using different corner colors
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	
	# Enhanced border with stronger visibility
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = color.lightened(0.3)  # Brighter border
	
	# Add shadow effect
	normal_style.shadow_color = Color.BLACK
	normal_style.shadow_color.a = 0.4  # More visible shadow
	normal_style.shadow_size = 6
	normal_style.shadow_offset = Vector2(3, 3)
	
	# Add subtle texture using border blend
	normal_style.border_blend = true
	normal_style.anti_aliasing = true
	
	# Hover style with enhanced glow effect
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)  # Brighter hover
	hover_style.bg_color.a = 1.0  # Fully opaque
	
	# Enhanced glow on hover
	hover_style.corner_radius_top_left = 12
	hover_style.corner_radius_top_right = 12
	hover_style.corner_radius_bottom_left = 12
	hover_style.corner_radius_bottom_right = 12
	
	# Glowing border effect
	hover_style.border_width_left = 4
	hover_style.border_width_top = 4
	hover_style.border_width_right = 4
	hover_style.border_width_bottom = 4
	hover_style.border_color = Color.WHITE  # White border for strong visibility
	
	# Enhanced glow shadow
	hover_style.shadow_color = color.lightened(0.5)
	hover_style.shadow_color.a = 0.8  # Strong glow
	hover_style.shadow_size = 12
	hover_style.shadow_offset = Vector2(0, 0)  # Center glow
	
	hover_style.border_blend = true
	hover_style.anti_aliasing = true
	
	# Pressed style with inset effect
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.2)
	pressed_style.bg_color.a = 1.0
	
	# Slightly smaller radius for pressed effect
	pressed_style.corner_radius_top_left = 10
	pressed_style.corner_radius_top_right = 10
	pressed_style.corner_radius_bottom_left = 10
	pressed_style.corner_radius_bottom_right = 10
	
	# Inset border effect
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = color.darkened(0.3)
	
	# Inward shadow for pressed effect
	pressed_style.shadow_color = Color.BLACK
	pressed_style.shadow_color.a = 0.5
	pressed_style.shadow_size = 2
	pressed_style.shadow_offset = Vector2(1, 1)
	
	pressed_style.border_blend = true
	pressed_style.anti_aliasing = true
	
	# Apply styles
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Enhanced text styling with outline
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)
	
	# Add special effects based on summon type
	add_special_effects(button, color, _summon_type)
	
	# Add hover animations
	button.mouse_entered.connect(_on_button_hover.bind(button, color))
	button.mouse_exited.connect(_on_button_unhover.bind(button))

func add_special_effects(button: Button, color: Color, summon_type: String):
	# Add particle or glow effects based on summon type
	match summon_type.to_upper():
		"PREMIUM SUMMON", "PREMIUM 10X SUMMON":
			# Add golden shimmer effect
			add_shimmer_effect(button, Color.GOLD)
		"CRYSTAL SUMMON":
			# Add crystal sparkle effect
			add_sparkle_effect(button, Color.DEEP_PINK)
		"DAILY FREE SUMMON":
			# Add gentle pulse effect
			add_pulse_effect(button, Color.GREEN)
		"ELEMENT SUMMON", "ELEMENT FOCUS":
			# Add elemental swirl effect
			add_swirl_effect(button, color)

func add_shimmer_effect(button: Button, shimmer_color: Color):
	# Create a subtle shimmer animation
	var shimmer_tween = create_tween()
	shimmer_tween.set_loops()
	
	# This could be enhanced with actual particle systems or shader effects
	# For now, we'll use a subtle color pulse
	shimmer_tween.tween_method(
		func(alpha: float): 
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(shimmer_color, alpha * 0.2),
		0.0, 1.0, 2.0
	)
	shimmer_tween.tween_method(
		func(alpha: float): 
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(shimmer_color, alpha * 0.2),
		1.0, 0.0, 2.0
	)

func add_sparkle_effect(button: Button, sparkle_color: Color):
	# Create sparkle effect
	var sparkle_tween = create_tween()
	sparkle_tween.set_loops()
	
	sparkle_tween.tween_method(
		func(alpha: float):
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(sparkle_color, alpha * 0.15),
		0.0, 1.0, 1.5
	)
	sparkle_tween.tween_method(
		func(alpha: float):
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(sparkle_color, alpha * 0.15),
		1.0, 0.0, 1.5
	)

func add_pulse_effect(button: Button, _pulse_color: Color):
	# Gentle breathing effect
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	pulse_tween.tween_property(button, "scale", Vector2(1.02, 1.02), 3.0)
	pulse_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 3.0)

func add_swirl_effect(button: Button, swirl_color: Color):
	# Elemental swirl effect
	var swirl_tween = create_tween()
	swirl_tween.set_loops()
	
	swirl_tween.tween_method(
		func(alpha: float):
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(swirl_color.lightened(0.3), alpha * 0.1),
		0.0, 1.0, 2.5
	)
	swirl_tween.tween_method(
		func(alpha: float):
			if button and is_instance_valid(button):
				button.modulate = Color.WHITE.lerp(swirl_color.lightened(0.3), alpha * 0.1),
		1.0, 0.0, 2.5
	)

func _on_button_hover(button: Button, color: Color):
	# Scale up slightly on hover with color enhancement
	var button_hover_tween = create_tween()
	button_hover_tween.parallel().tween_property(button, "scale", Vector2(1.08, 1.08), 0.15)
	button_hover_tween.parallel().tween_property(button, "modulate", Color.WHITE.lerp(color.lightened(0.2), 0.3), 0.15)

func _on_button_unhover(button: Button):
	# Scale back down and reset color
	var unhover_tween = create_tween()
	unhover_tween.parallel().tween_property(button, "scale", Vector2(1.0, 1.0), 0.12)
	unhover_tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.12)

func get_summon_system():
	"""Helper function to get SummonManager from SystemRegistry"""
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _on_basic_summon_pressed():
	var summon_system = get_summon_system()
	if summon_system:
		# Disable buttons during summon
		set_buttons_enabled(false)
		
		var success = summon_system.summon_with_soul("common_soul")
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")

func _on_premium_summon_pressed():
	var summon_system = get_summon_system()
	if summon_system:
		# Disable buttons during summon
		set_buttons_enabled(false)
		
		var success = summon_system.summon_premium()
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")

func set_buttons_enabled(enabled: bool):
	if basic_button:
		basic_button.disabled = !enabled
	if premium_button:
		premium_button.disabled = !enabled
	if element_button:
		element_button.disabled = !enabled
	if crystal_button:
		crystal_button.disabled = !enabled
	if basic_10x_button:
		basic_10x_button.disabled = !enabled
	if premium_10x_button:
		premium_10x_button.disabled = !enabled
	# Don't disable daily free button here - it has its own logic
	if daily_free_button and enabled:
		update_daily_free_availability()

func show_error_message(message: String):
	# Create temporary error message
	var error_label = Label.new()
	error_label.text = "❌ " + message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 16)
	error_label.add_theme_color_override("font_color", Color.RED)
	
	if showcase_content and is_instance_valid(showcase_content):
		showcase_content.add_child(error_label)

		# Remove error after 3 seconds
		await get_tree().create_timer(3.0).timeout
		if error_label and is_instance_valid(error_label):
			error_label.queue_free()

func _on_back_pressed():
	back_pressed.emit()

# Signal handlers - modular response to game state changes
func _on_god_summoned(god):
	# Prevent duplicate processing of the same summon
	if is_processing_summon:
		return
		
	is_processing_summon = true
	
	# Remove default message completely (not just hide it)
	if default_message and is_instance_valid(default_message):
		default_message.queue_free()
		default_message = null
		# Wait a frame for the node to be properly removed
		await get_tree().process_frame
	
	# Clear any invisible or problematic nodes from showcase_content
	clear_showcase_invisible_nodes()
	await get_tree().process_frame  # Wait for cleanup
	
	# Create animated showcase for the summoned god
	create_god_showcase(god)
	
	# Re-enable buttons
	set_buttons_enabled(true)
	
	# Reset processing flag
	is_processing_summon = false

func clear_showcase_invisible_nodes():
	# Remove any invisible or problematic nodes that might be causing spacing issues
	if not showcase_content:
		return
		
	var children_to_remove = []
	
	for child in showcase_content.get_children():
		# Skip if it's the default message (handled separately)
		if child == default_message:
			continue
			
		# Check for various problematic node types
		var should_remove = false
		
		# Remove invisible nodes
		if not child.visible:
			should_remove = true
		# Remove very small/zero-sized nodes that might be spacers
		elif child.size.x <= 1 or child.size.y <= 1:
			should_remove = true
		# Remove empty Control nodes (potential spacers)
		elif child.get_class() == "Control" and child.get_child_count() == 0:
			should_remove = true
		# Remove any node that isn't a Button (our god cards should be buttons)
		elif not child is Button:
			should_remove = true
			
		if should_remove:
			children_to_remove.append(child)
	
	# Remove problematic nodes
	for child in children_to_remove:
		child.queue_free()

func create_god_showcase(god: God):
	# Create a button-style god card similar to summon buttons
	var god_button = Button.new()
	god_button.custom_minimum_size = Vector2(200, 280)  # Taller for god display
	god_button.flat = false  # Show background styling
	god_button.disabled = true  # Make it non-clickable (just for display)
	
	# IMPORTANT: Set size flags to prevent VBoxContainer from expanding this button
	god_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Get tier color for styling
	var tier_color = get_tier_color(god.tier)
	
	# Apply the same styling as summon buttons
	var god_style = StyleBoxFlat.new()
	god_style.bg_color = tier_color.darkened(0.2)
	god_style.bg_color.a = 0.9
	god_style.corner_radius_top_left = 12
	god_style.corner_radius_top_right = 12
	god_style.corner_radius_bottom_left = 12
	god_style.corner_radius_bottom_right = 12
	god_style.border_width_left = 3
	god_style.border_width_top = 3
	god_style.border_width_right = 3
	god_style.border_width_bottom = 3
	god_style.border_color = tier_color.lightened(0.3)
	god_style.shadow_color = Color.BLACK
	god_style.shadow_color.a = 0.4
	god_style.shadow_size = 6
	god_style.shadow_offset = Vector2(3, 3)
	god_style.border_blend = true
	god_style.anti_aliasing = true
	
	# Apply styling
	god_button.add_theme_stylebox_override("normal", god_style)
	god_button.add_theme_stylebox_override("disabled", god_style)  # Same style when disabled
	god_button.add_theme_color_override("font_color", Color.WHITE)
	
	# Create content container inside the button
	var content_container = VBoxContainer.new()
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.offset_left = 10
	content_container.offset_top = 10
	content_container.offset_right = -10
	content_container.offset_bottom = -10
	content_container.add_theme_constant_override("separation", 5)
	
	# Summon announcement
	var announcement = Label.new()
	announcement.text = "✨ NEW GOD SUMMONED! ✨"
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement.add_theme_font_size_override("font_size", 12)
	announcement.add_theme_color_override("font_color", Color.YELLOW)
	content_container.add_child(announcement)
	
	# God image
	var image_container = TextureRect.new()
	image_container.custom_minimum_size = Vector2(120, 120)
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Load god image using the same pattern as CollectionScreen
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	var god_texture = null
	if ResourceLoader.exists(sprite_path):
		god_texture = load(sprite_path)
	
	if god_texture:
		image_container.texture = god_texture
	else:
		# Fallback colored rectangle with same styling
		var placeholder = ColorRect.new()
		placeholder.color = tier_color.lightened(0.2)
		placeholder.custom_minimum_size = Vector2(120, 120)
		content_container.add_child(placeholder)
		image_container = null
	
	if image_container:
		content_container.add_child(image_container)
	
	# God name with tier styling
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(name_label)
	
	# Tier display
	var tier_label = Label.new()
	tier_label.text = "⭐ %s %s ⭐" % [God.tier_to_string(god.tier).to_upper(), God.element_to_string(god.element).to_upper()]
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", get_tier_text_color(god.tier))
	tier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(tier_label)
	
	# Stats preview
	var stats_label = Label.new()
	
	# Get current stats through EquipmentStatCalculator (RULE 3 compliance)
	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator")
	var hp: int
	var attack: int
	var defense: int
	var speed: int
	if stat_calc:
		var total_stats = stat_calc.calculate_god_total_stats(god)
		hp = total_stats.hp
		attack = total_stats.attack
		defense = total_stats.defense
		speed = total_stats.speed
	else:
		hp = god.base_hp
		attack = god.base_attack
		defense = god.base_defense
		speed = god.base_speed
	
	stats_label.text = "HP: %d | ATK: %d | DEF: %d | SPD: %d" % [hp, attack, defense, speed]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(stats_label)
	
	# Add content container to button
	god_button.add_child(content_container)
	
	# Add to current summons array
	current_summons.append(god_button)
	
	# Keep only last 15 summons (increased to accommodate 10x summons + some history)
	if current_summons.size() > 15:
		var old_card = current_summons[0]
		current_summons.remove_at(0)
		if old_card and is_instance_valid(old_card):
			old_card.queue_free()
	
	# Add to showcase with entrance animation
	if showcase_content:
		showcase_content.add_child(god_button)
		
		# Skip animation for multi-summons to show all cards instantly
		if is_processing_summon:
			animate_card_entrance(god_button)
		else:
			# For multi-summons, show instantly without animation
			god_button.modulate.a = 1.0
			god_button.scale = Vector2(1.0, 1.0)
func animate_card_entrance(card: Control):
	# Start card invisible and scaled down
	card.modulate.a = 0.0
	card.scale = Vector2(0.5, 0.5)
	
	# Create tween for entrance animation
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in and scale up
	tween.tween_property(card, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Subtle bounce effect
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1).set_delay(0.5)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.6)

func get_tier_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color.GRAY
		1:  # RARE
			return Color.BLUE
		2:  # EPIC
			return Color.PURPLE
		3:  # LEGENDARY
			return Color.GOLD
		_:
			return Color.WHITE

func get_tier_text_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color.WHITE
		1:  # RARE
			return Color.CYAN
		2:  # EPIC
			return Color.MAGENTA
		3:  # LEGENDARY
			return Color.YELLOW
		_:
			return Color.WHITE


func _on_summon_failed(reason):
	show_error_message(reason)

# New summon button handlers
func _on_basic_10x_summon_pressed():
	set_buttons_enabled(false)
	var summon_system = get_summon_system()
	if summon_system:
		var success = summon_system.multi_summon_premium()
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")
		set_buttons_enabled(true)

func _on_premium_10x_summon_pressed():
	set_buttons_enabled(false)
	var summon_system = get_summon_system()
	if summon_system:
		var success = summon_system.multi_summon_premium()
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")
		set_buttons_enabled(true)

func _on_element_summon_pressed():
	set_buttons_enabled(false)
	var summon_system = get_summon_system()
	if summon_system:
		var element_names = ["fire", "water", "earth", "lightning", "light", "dark"]
		var element = element_names[selected_element % element_names.size()]
		var success = summon_system.summon_with_soul(element)
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")
		set_buttons_enabled(true)

func _on_element_focus_pressed():
	# Cycle through elements for element summons
	selected_element = (selected_element + 1) % 6  # 6 elements: fire, water, earth, lightning, light, dark

func _on_crystal_summon_pressed():
	set_buttons_enabled(false)
	var summon_system = get_summon_system()
	if summon_system:
		var success = summon_system.summon_premium()  # Using premium summon for crystals
		if not success:
			set_buttons_enabled(true)
	else:
		show_error_message("SummonSystem not available")
		set_buttons_enabled(true)

func _on_daily_free_summon_pressed():
	set_buttons_enabled(false)
	var summon_system = get_summon_system()
	if summon_system:
		var success = summon_system.summon_free_daily()
		if not success:
			set_buttons_enabled(true)
		else:
			update_daily_free_availability()
	else:
		show_error_message("SummonSystem not available")
		set_buttons_enabled(true)

func update_daily_free_availability():
	if daily_free_button:
		var summon_system = get_summon_system()
		if summon_system:
			var can_use = summon_system.can_use_daily_free_summon()
			daily_free_button.disabled = not can_use
			if not can_use:
				daily_free_button.text = "USED TODAY"
			else:
				daily_free_button.text = "DAILY FREE SUMMON\nFREE!"
			daily_free_button.text = "SUMMON FREE!"

# Handler for multi-summon results (connect this to the new signal)
func _on_multi_summon_completed(gods: Array):
	
	# Remove default message
	if default_message and is_instance_valid(default_message):
		default_message.queue_free()
		default_message = null
	
	# Show all gods instantly - no delays!
	for god in gods:
		create_god_showcase(god)
	
	# Re-enable buttons immediately
	set_buttons_enabled(true)

# Handler for duplicate god notifications
func _on_duplicate_obtained(_god, _existing_count: int):
	# Could show a special UI notification here for duplicates
	pass
