class_name CollectionSorter
extends RefCounted

"""
CollectionSorter.gd - Handles sorting UI and logic for god collection
RULE 1: Single responsibility - ONLY handles sorting functionality
Extracted from CollectionScreen.gd to reduce file size and improve maintainability
"""

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)
var sort_buttons: Array = []  # Store references to sort buttons
var direction_button: Button = null  # Store reference to direction button

# Callback for when sort changes
var on_sort_changed_callback: Callable

func setup_sorting_ui(parent_container: VBoxContainer, callback: Callable) -> void:
	"""Setup sorting controls with full functionality"""

	on_sort_changed_callback = callback

	# Don't create if already exists
	if sort_buttons.size() > 0:
		return

	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 10)

	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort by:"
	sort_label.add_theme_font_size_override("font_size", 14)
	sort_container.add_child(sort_label)

	# Create sort buttons
	var button_configs = [
		{"text": "Power", "type": SortType.POWER},
		{"text": "Level", "type": SortType.LEVEL},
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Element", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]

	for button_data in button_configs:
		var sort_button = Button.new()
		sort_button.text = button_data.text
		sort_button.custom_minimum_size = Vector2(90, 30)  # Uniform width for all buttons
		sort_button.pressed.connect(_on_sort_changed.bind(button_data.type))
		sort_buttons.append(sort_button)
		sort_container.add_child(sort_button)

	# Add sort direction button
	direction_button = Button.new()
	direction_button.text = "↓"  # Down arrow for descending
	direction_button.custom_minimum_size = Vector2(30, 30)
	direction_button.pressed.connect(_on_direction_changed)
	sort_container.add_child(direction_button)

	# Insert at the top of the parent container
	parent_container.add_child(sort_container)
	parent_container.move_child(sort_container, 0)

	# Update button styles to show current selection
	_update_sort_button_styles()

func _on_sort_changed(sort_type: SortType) -> void:
	"""Handle sort type change"""
	current_sort = sort_type
	_update_sort_button_styles()
	if on_sort_changed_callback.is_valid():
		on_sort_changed_callback.call()

func _on_direction_changed() -> void:
	"""Handle sort direction change"""
	sort_ascending = not sort_ascending
	if direction_button:
		direction_button.text = "↑" if sort_ascending else "↓"
	if on_sort_changed_callback.is_valid():
		on_sort_changed_callback.call()

func _update_sort_button_styles() -> void:
	"""Update sort button styles to show current selection"""
	var button_configs = [SortType.POWER, SortType.LEVEL, SortType.TIER, SortType.ELEMENT, SortType.NAME]

	for i in range(sort_buttons.size()):
		var button = sort_buttons[i]
		if button_configs[i] == current_sort:
			# Highlight selected button
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.6, 1.0, 0.8)
			button.add_theme_stylebox_override("normal", style)
		else:
			# Remove highlight from unselected buttons
			button.remove_theme_stylebox_override("normal")

func sort_gods(gods: Array, power_rating_func: Callable) -> Array:
	"""Sort gods according to current sort settings"""
	var sorted_gods = gods.duplicate()

	match current_sort:
		SortType.POWER:
			sorted_gods.sort_custom(func(a, b):
				if sort_ascending:
					return power_rating_func.call(a) < power_rating_func.call(b)
				else:
					return power_rating_func.call(a) > power_rating_func.call(b)
			)
		SortType.LEVEL:
			sorted_gods.sort_custom(func(a, b):
				if sort_ascending:
					return a.level < b.level
				else:
					return a.level > b.level
			)
		SortType.TIER:
			sorted_gods.sort_custom(func(a, b):
				if sort_ascending:
					return a.tier < b.tier
				else:
					return a.tier > b.tier
			)
		SortType.ELEMENT:
			sorted_gods.sort_custom(func(a, b):
				if sort_ascending:
					return a.element < b.element
				else:
					return a.element > b.element
			)
		SortType.NAME:
			sorted_gods.sort_custom(func(a, b):
				if sort_ascending:
					return a.name < b.name
				else:
					return a.name > b.name
			)

	return sorted_gods
