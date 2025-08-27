# scripts/ui/components/SacrificeConfirmationManager.gd
# Single responsibility: Handle sacrifice confirmation and execution
class_name SacrificeConfirmationManager extends Node

# Confirmation signals
signal sacrifice_confirmed(target_god: God, materials: Array)
signal sacrifice_cancelled
signal sacrifice_completed(success: bool, result_data: Dictionary)

var parent_screen: Control

func initialize(screen_parent: Control):
	"""Initialize with parent screen for dialog management"""
	parent_screen = screen_parent
	print("SacrificeConfirmationManager: Initialized")

func show_sacrifice_confirmation(target_god: God, selected_materials: Array):
	"""Show confirmation dialog for sacrifice - RULE 4: UI display only"""
	if not target_god or selected_materials.is_empty():
		print("SacrificeConfirmationManager: Invalid sacrifice data")
		return
	
	# Calculate sacrifice preview through SystemRegistry - RULE 5 compliance
	var sacrifice_preview = calculate_sacrifice_preview(target_god, selected_materials)
	
	# Create confirmation dialog
	var dialog_text = build_confirmation_text(target_god, selected_materials, sacrifice_preview)
	show_confirmation_dialog("Confirm Sacrifice", dialog_text, 
		func(): _perform_sacrifice(target_god, selected_materials))

func calculate_sacrifice_preview(target_god: God, materials: Array) -> Dictionary:
	"""Calculate sacrifice preview through SystemRegistry - RULE 5 compliance"""
	var preview_data = {
		"total_xp": 0,
		"levels_gained": 0,
		"final_level": target_god.level,
		"materials_count": materials.size()
	}
	
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var sacrifice_manager = system_registry.get_system("SacrificeManager")
		if sacrifice_manager:
			preview_data.total_xp = sacrifice_manager.calculate_sacrifice_xp(materials)
			preview_data.levels_gained = sacrifice_manager.calculate_levels_gained(target_god, preview_data.total_xp)
			preview_data.final_level = min(target_god.level + preview_data.levels_gained, 40)
		else:
			print("SacrificeConfirmationManager: SacrificeManager not found in SystemRegistry")
	
	return preview_data

func build_confirmation_text(target_god: God, materials: Array, preview: Dictionary) -> String:
	"""Build confirmation dialog text with sacrifice details"""
	var dialog_text = "Sacrifice to %s?\n\n" % target_god.name
	dialog_text += "Materials: %d gods\n" % materials.size()
	dialog_text += "XP Gain: %d\n" % preview.total_xp
	
	if preview.levels_gained > 0:
		dialog_text += "Level: %d → %d (+%d levels)\n\n" % [
			target_god.level, 
			preview.final_level, 
			preview.levels_gained
		]
	else:
		dialog_text += "XP gained, but no level up\n\n"
	
	dialog_text += "This action cannot be undone!\n\n"
	dialog_text += "Continue with sacrifice?"
	
	return dialog_text

func show_confirmation_dialog(title: String, message: String, confirm_callback: Callable):
	"""Show a styled confirmation dialog"""
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 14)
	
	# Style the dialog
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	panel_style.border_color = Color.CYAN
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	# Add to parent screen
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	# Center and show
	dialog.popup_centered(Vector2(400, 300))
	
	# Connect signals
	dialog.confirmed.connect(confirm_callback)
	dialog.confirmed.connect(func(): 
		sacrifice_confirmed.emit(null, [])  # Will be set by actual callback
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): 
		sacrifice_cancelled.emit()
		dialog.queue_free()
	)

func _perform_sacrifice(target_god: God, materials: Array):
	"""Actually perform the sacrifice through SystemRegistry - RULE 5 compliance"""
	print("SacrificeConfirmationManager: Performing sacrifice for %s with %d materials" % [target_god.name, materials.size()])
	
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		show_error_dialog("System Error", "SystemRegistry not available. Cannot perform sacrifice.")
		sacrifice_completed.emit(false, {})
		return
	
	var sacrifice_manager = system_registry.get_system("SacrificeManager")
	if not sacrifice_manager:
		show_error_dialog("System Error", "SacrificeManager not found. Cannot perform sacrifice.")
		sacrifice_completed.emit(false, {})
		return
	
	# Perform the sacrifice
	var success = sacrifice_manager.perform_sacrifice(target_god, materials)
	
	if success:
		# Get result data for feedback
		var result_data = {
			"target_god": target_god,
			"materials_count": materials.size(),
			"success": true
		}
		
		show_success_dialog("Sacrifice Complete!", "Your god has been powered up successfully!")
		sacrifice_completed.emit(true, result_data)
	else:
		show_error_dialog("Sacrifice Failed", "The sacrifice could not be completed. Please try again.")
		sacrifice_completed.emit(false, {})

func show_success_dialog(title: String, message: String):
	"""Show a success dialog with green styling"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	
	# Green success styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.2, 0.1, 0.95)
	panel_style.border_color = Color.GREEN
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	# Add to parent
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_error_dialog(title: String, message: String):
	"""Show an error dialog with red styling"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	
	# Red error styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.1, 0.1, 0.95)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	# Add to parent
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func show_info_dialog(title: String, message: String):
	"""Show a general info dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.add_theme_font_size_override("font_size", 16)
	
	# Standard info styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	panel_style.border_color = Color.CYAN
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	# Add to parent
	if parent_screen:
		parent_screen.add_child(dialog)
	else:
		add_child(dialog)
	
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
