# scripts/ui/screens/SacrificeSelectionScreen.gd
# RULE 1 COMPLIANCE: 500-line limit enforced  
# RULE 2 COMPLIANCE: Single responsibility - coordinate sacrifice selection UI components
# RULE 4 COMPLIANCE: UI layer - display coordination only, no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control

signal back_pressed

# Preload component classes
const SacrificeTargetDisplayManager = preload("res://scripts/ui/components/SacrificeTargetDisplayManager.gd")
const SacrificeMaterialManager = preload("res://scripts/ui/components/SacrificeMaterialManager.gd")
const SacrificeConfirmationManager = preload("res://scripts/ui/components/SacrificeConfirmationManager.gd")

# Component managers for focused responsibilities
var target_display_manager: SacrificeTargetDisplayManager
var material_manager: SacrificeMaterialManager
var confirmation_manager: SacrificeConfirmationManager

# UI references - match original structure to preserve functionality
@onready var back_button = $MainContainer/TopBar/BackButton
@onready var target_god_display = $MainContainer/SacrificeContent/TargetGodSection/TargetGodDisplay
@onready var xp_bar_container = $MainContainer/SacrificeContent/XPBarSection/XPBarContainer
@onready var material_grid = $MainContainer/SacrificeContent/MaterialSection/ScrollContainer/MaterialGrid
@onready var material_section = $MainContainer/SacrificeContent/MaterialSection
@onready var lock_in_button = $MainContainer/SacrificeContent/ButtonSection/LockInButton
@onready var sacrifice_button = $MainContainer/SacrificeContent/ButtonSection/SacrificeButton

# Current state
var current_target_god: God = null
var max_materials: int = 6  # Can be changed - Summoners War default

func _ready():
	"""Initialize the sacrifice selection screen"""
	print("SacrificeSelectionScreen: Initializing")
	setup_component_managers()
	connect_signals()
	setup_initial_ui_state()

func setup_component_managers():
	"""Initialize component managers - RULE 2: Focused responsibilities"""
	# Create target display manager
	target_display_manager = SacrificeTargetDisplayManager.new()
	add_child(target_display_manager)
	target_display_manager.initialize(target_god_display, xp_bar_container)
	
	# Create material manager
	material_manager = SacrificeMaterialManager.new()
	add_child(material_manager)
	material_manager.initialize(material_grid, material_section)
	material_manager.set_max_materials(max_materials)
	
	# Create confirmation manager
	confirmation_manager = SacrificeConfirmationManager.new()
	add_child(confirmation_manager)
	confirmation_manager.initialize(self)

func connect_signals():
	"""Connect all component signals"""
	# Back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Action buttons
	if lock_in_button:
		lock_in_button.pressed.connect(_on_lock_in_pressed)
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	
	# Component signals
	if material_manager:
		material_manager.materials_selection_changed.connect(_on_materials_changed)
		material_manager.selection_locked_in.connect(_on_selection_locked_in)
		material_manager.selection_cleared.connect(_on_selection_cleared)
	
	if target_display_manager:
		target_display_manager.target_display_updated.connect(_on_target_display_updated)
		target_display_manager.xp_preview_changed.connect(_on_xp_preview_changed)
	
	if confirmation_manager:
		confirmation_manager.sacrifice_confirmed.connect(_on_sacrifice_confirmed)
		confirmation_manager.sacrifice_cancelled.connect(_on_sacrifice_cancelled)
		confirmation_manager.sacrifice_completed.connect(_on_sacrifice_completed)
	
	print("SacrificeSelectionScreen: Signals connected")

func setup_initial_ui_state():
	"""Setup initial button states and UI"""
	if sacrifice_button:
		sacrifice_button.disabled = true
	
	if lock_in_button:
		lock_in_button.disabled = true
		lock_in_button.text = "Lock In Selection"

func initialize_with_god(god: God):
	"""Initialize the screen with a target god - RULE 4: UI coordination only"""
	if not god:
		print("SacrificeSelectionScreen: No god provided")
		return
	
	current_target_god = god
	print("SacrificeSelectionScreen: Initialized with target god: ", god.name)
	
	# Delegate to component managers
	if target_display_manager:
		target_display_manager.set_target_god(god)
	
	if material_manager:
		material_manager.refresh_material_grid()
	
	update_button_states()

func set_max_materials(count: int):
	"""Change the maximum number of materials allowed"""
	max_materials = max(1, min(count, 12))  # Clamp between 1 and 12
	
	if material_manager:
		material_manager.set_max_materials(max_materials)

# === EVENT HANDLERS ===

func _on_back_pressed():
	"""Handle back button press"""
	print("SacrificeSelectionScreen: Back button pressed")
	back_pressed.emit()

func _on_materials_changed(selected_materials: Array):
	"""Handle material selection changes"""
	print("SacrificeSelectionScreen: Materials changed - %d selected" % selected_materials.size())
	
	# Update XP preview
	if target_display_manager:
		target_display_manager.preview_sacrifice_result(selected_materials)
	
	update_button_states()

func _on_selection_locked_in(materials: Array):
	"""Handle selection lock-in"""
	print("SacrificeSelectionScreen: Selection locked in with %d materials" % materials.size())
	update_button_states()

func _on_selection_cleared():
	"""Handle selection clearing"""
	print("SacrificeSelectionScreen: Selection cleared")
	
	# Update XP preview to show no gain
	if target_display_manager:
		target_display_manager.preview_sacrifice_result([])
	
	update_button_states()

func _on_target_display_updated():
	"""Handle target display updates"""
	print("SacrificeSelectionScreen: Target display updated")

func _on_xp_preview_changed(preview_xp: int, levels_gained: int):
	"""Handle XP preview changes"""
	print("SacrificeSelectionScreen: XP preview - %d XP, %d levels" % [preview_xp, levels_gained])

func _on_lock_in_pressed():
	"""Handle lock in button press"""
	print("SacrificeSelectionScreen: Lock in button pressed")
	
	if material_manager:
		var success = material_manager.lock_in_selection()
		if success:
			update_button_states()

func _on_sacrifice_pressed():
	"""Handle sacrifice button press"""
	print("SacrificeSelectionScreen: Sacrifice button pressed")
	
	if not current_target_god or not material_manager:
		return
	
	var selected_materials = material_manager.get_selected_materials()
	if selected_materials.is_empty():
		return
	
	# Show confirmation through confirmation manager
	if confirmation_manager:
		confirmation_manager.show_sacrifice_confirmation(current_target_god, selected_materials)

func _on_sacrifice_confirmed(_target_god: God, _materials: Array):
	"""Handle sacrifice confirmation"""
	print("SacrificeSelectionScreen: Sacrifice confirmed")

func _on_sacrifice_cancelled():
	"""Handle sacrifice cancellation"""
	print("SacrificeSelectionScreen: Sacrifice cancelled")

func _on_sacrifice_completed(success: bool, _result_data: Dictionary):
	"""Handle sacrifice completion"""
	print("SacrificeSelectionScreen: Sacrifice completed - Success: %s" % success)
	
	if success:
		# Reset state after successful sacrifice
		reset_screen_state()

func update_button_states():
	"""Update button enabled/disabled states - RULE 4: UI state management"""
	if not material_manager:
		return
	
	var selected_materials = material_manager.get_selected_materials()
	var is_locked_in = material_manager.is_locked_in()
	
	# Lock in button
	if lock_in_button:
		if selected_materials.size() > 0 and not is_locked_in:
			lock_in_button.disabled = false
			lock_in_button.text = "Lock In Selection (%d gods)" % selected_materials.size()
		else:
			lock_in_button.disabled = true
			if is_locked_in:
				lock_in_button.text = "Selection Locked (%d gods)" % selected_materials.size()
			else:
				lock_in_button.text = "Lock In Selection"
	
	# Sacrifice button
	if sacrifice_button:
		sacrifice_button.disabled = not (is_locked_in and selected_materials.size() > 0)

func reset_screen_state():
	"""Reset screen state after successful sacrifice"""
	print("SacrificeSelectionScreen: Resetting screen state")
	
	# Unlock material manager
	if material_manager:
		material_manager.unlock_selection()
		material_manager.clear_selection()
	
	# Update target display with current (now improved) god
	if target_display_manager and current_target_god:
		target_display_manager.set_target_god(current_target_god)
	
	update_button_states()

# === PUBLIC API ===

func get_current_target_god() -> God:
	"""Get the current target god"""
	return current_target_god

func get_selected_materials() -> Array:
	"""Get currently selected materials"""
	if material_manager:
		return material_manager.get_selected_materials()
	return []

func is_selection_locked_in() -> bool:
	"""Check if selection is locked in"""
	if material_manager:
		return material_manager.is_locked_in()
	return false

# === CLEANUP ===

func _exit_tree():
	"""Clean up when screen is removed"""
	print("SacrificeSelectionScreen: Cleaning up")
	
	# Component managers are children and will be automatically freed
	# Just ensure any remaining connections are cleared
	if material_manager:
		if material_manager.materials_selection_changed.is_connected(_on_materials_changed):
			material_manager.materials_selection_changed.disconnect(_on_materials_changed)
		if material_manager.selection_locked_in.is_connected(_on_selection_locked_in):
			material_manager.selection_locked_in.disconnect(_on_selection_locked_in)
		if material_manager.selection_cleared.is_connected(_on_selection_cleared):
			material_manager.selection_cleared.disconnect(_on_selection_cleared)
	
	if target_display_manager:
		if target_display_manager.target_display_updated.is_connected(_on_target_display_updated):
			target_display_manager.target_display_updated.disconnect(_on_target_display_updated)
		if target_display_manager.xp_preview_changed.is_connected(_on_xp_preview_changed):
			target_display_manager.xp_preview_changed.disconnect(_on_xp_preview_changed)
	
	if confirmation_manager:
		if confirmation_manager.sacrifice_confirmed.is_connected(_on_sacrifice_confirmed):
			confirmation_manager.sacrifice_confirmed.disconnect(_on_sacrifice_confirmed)
		if confirmation_manager.sacrifice_cancelled.is_connected(_on_sacrifice_cancelled):
			confirmation_manager.sacrifice_cancelled.disconnect(_on_sacrifice_cancelled)
		if confirmation_manager.sacrifice_completed.is_connected(_on_sacrifice_completed):
			confirmation_manager.sacrifice_completed.disconnect(_on_sacrifice_completed)
