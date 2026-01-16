# scripts/ui/sacrifice/SacrificeGodList.gd
# God list for sacrifice with target/material selection support
class_name SacrificeGodList
extends Control

signal god_selected(god: God)
signal god_double_clicked(god: God)  # For material selection

var god_grid: GridContainer
var scroll_container: ScrollContainer
var sort_controls: Control
var current_target_god: God

# System references
var sacrifice_manager: SacrificeManager
var collection_manager: CollectionManager

func _ready():
	_initialize_systems()
	_setup_ui()

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	sacrifice_manager = system_registry.get_system("SacrificeManager")
	collection_manager = system_registry.get_system("CollectionManager")

func _setup_ui():
	"""Setup the god list UI"""
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 10)
	add_child(container)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Select Gods"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title_label)
	
	# Add sorting controls
	sort_controls = _create_sort_controls()
	container.add_child(sort_controls)
	
	# Add scrollable god grid
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll_container)
	
	god_grid = GridContainer.new()
	god_grid.columns = 4
	god_grid.add_theme_constant_override("h_separation", 8)
	god_grid.add_theme_constant_override("v_separation", 8)
	scroll_container.add_child(god_grid)
	
	refresh_god_list()

func refresh_god_list():
	"""Refresh the god list"""
	_clear_grid()
	_populate_gods()

func _clear_grid():
	"""Clear the god grid"""
	if not god_grid:
		return
	for child in god_grid.get_children():
		child.queue_free()

func _populate_gods():
	"""Populate the god grid with available gods"""
	if not sacrifice_manager:
		print("SacrificeGodList: SacrificeManager not available")
		return
	
	var available_gods = sacrifice_manager.get_available_sacrifice_gods()
	
	if available_gods.is_empty():
		var no_gods_label = Label.new()
		no_gods_label.text = "No gods available for sacrifice"
		no_gods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_gods_label.modulate = Color.GRAY
		god_grid.add_child(no_gods_label)
		return
	
	for god in available_gods:
		var god_card = _create_god_card(god)
		god_grid.add_child(god_card)

func _create_god_card(god: God) -> Control:
	"""Create a god card with selection support"""
	var card = UICardFactory.create_god_card(god)
	
	# Style the card based on whether it's the current target
	_style_god_card(card, god)
	
	# Make it selectable - single click for target selection
	var button = card.get_node("SelectButton")
	if button:
		button.pressed.connect(_on_god_card_selected.bind(god))
		
		# Add right-click or ctrl-click for material selection
		button.gui_input.connect(_on_god_card_input.bind(god))
	
	return card

func _style_god_card(card: Control, god: God):
	"""Style the god card based on its selection state"""
	if not card:
		return
		
	# Find the main panel to style
	var panel = card.get_node("Panel") if card.has_node("Panel") else card
	
	if god == current_target_god:
		# Highlight target god
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.6, 0.3, 0.8)  # Green for target
		style.border_color = Color(0.5, 1.0, 0.5, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		panel.add_theme_stylebox_override("panel", style)

func _on_god_card_selected(god: God):
	"""Handle god card single-click - select as target"""
	current_target_god = god
	god_selected.emit(god)
	# Refresh to update styling
	refresh_god_list()

func _on_god_card_input(event: InputEvent, god: God):
	"""Handle god card input events"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT or (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.ctrl_pressed):
				# Right-click or Ctrl+Left-click to add as material
				_on_god_card_double_clicked(god)

func _on_god_card_double_clicked(god: God):
	"""Handle god card material addition"""
	god_double_clicked.emit(god)

func _create_sort_controls() -> Control:
	"""Create sorting controls"""
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	controls.add_child(sort_label)
	
	# Sort dropdown
	var sort_option = OptionButton.new()
	sort_option.add_item("Power")
	sort_option.add_item("Level") 
	sort_option.add_item("Tier")
	sort_option.add_item("Element")
	sort_option.add_item("Name")
	sort_option.item_selected.connect(_on_sort_changed)
	controls.add_child(sort_option)
	
	# Sort direction button
	var direction_btn = Button.new()
	direction_btn.text = "↓ Desc"
	direction_btn.pressed.connect(_on_sort_direction_changed)
	controls.add_child(direction_btn)
	
	return controls

func _on_sort_changed(_index: int):
	"""Handle sort type change"""
	refresh_god_list()  # For now, just refresh. Later add actual sorting

func _on_sort_direction_changed():
	"""Handle sort direction change"""
	refresh_god_list()  # For now, just refresh. Later add actual sorting
