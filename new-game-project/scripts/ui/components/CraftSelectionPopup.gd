# scripts/ui/components/CraftSelectionPopup.gd
# Shared crafting recipe selection popup - used by TerritoryOverviewScreen, ProductionSummaryWidget, etc.
extends Control
class_name CraftSelectionPopup

signal craft_started(task: Dictionary, node: HexNode)
signal popup_closed()

var _current_node: HexNode = null
var _tasks_data: Dictionary = {}
var _panel: PanelContainer = null
var _recipes_grid: GridContainer = null
var _category_dropdown: OptionButton = null
var _current_category: String = "equipment"  # "equipment" or "processing"

# System references (obtained from SystemRegistry)
var _resource_manager: Variant = null
var _hex_grid_manager: Variant = null

func _init() -> void:
	_load_tasks_data()
	_init_systems()

func _init_systems() -> void:
	"""Initialize system references from SystemRegistry"""
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")
		_hex_grid_manager = registry.get_system("HexGridManager")

func _load_tasks_data() -> void:
	"""Load crafting recipes from JSON - recipes are at top level (flat structure)"""
	var file := FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if not file:
		push_warning("CraftSelectionPopup: Could not load crafting_recipes.json")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		push_warning("CraftSelectionPopup: Failed to parse crafting_recipes.json")
		return

	var data: Variant = json.get_data()
	if not data is Dictionary:
		return

	# Load recipes from flattened structure (recipes at top level)
	_tasks_data = {}
	for recipe_id: String in data.keys():
		# Skip metadata and comment keys
		if recipe_id.begins_with("_"):
			continue
		var recipe: Variant = data[recipe_id]
		if recipe is Dictionary:
			_tasks_data[recipe_id] = recipe

func show_for_node(node: HexNode) -> void:
	"""Show the crafting popup for a specific forge node"""
	_current_node = node
	# Defer UI build until we're in the tree and can access viewport
	call_deferred("_build_ui")

func _build_ui() -> void:
	"""Build the popup UI"""
	if not _current_node:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Setup self
	name = "CraftSelectionPopup"
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = viewport_size

	# Dark background
	var bg_overlay: ColorRect = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.size = viewport_size
	bg_overlay.color = Color(0, 0, 0, 0.7)
	bg_overlay.gui_input.connect(_on_bg_clicked)
	add_child(bg_overlay)

	# Panel
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_width: float = minf(viewport_size.x * 0.85, 700)
	var panel_height: float = minf(viewport_size.y * 0.75, 500)
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.98)
	panel_style.border_color = Color(0.6, 0.45, 0.3, 1)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 15
	panel_style.content_margin_bottom = 15
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Content
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	var title: Label = Label.new()
	title.text = "⚒️ %s FORGE RECIPES" % _current_node.name.to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(close_popup)
	var close_style: StyleBoxFlat = StyleBoxFlat.new()
	close_style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_font_size_override("font_size", 18)
	header.add_child(close_btn)

	# Tier info + Category dropdown row
	var tier_row: HBoxContainer = HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 15)
	content.add_child(tier_row)

	var tier_label: Label = Label.new()
	tier_label.text = "Tier %d Forge" % _current_node.tier
	tier_label.add_theme_font_size_override("font_size", 12)
	tier_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	tier_row.add_child(tier_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_row.add_child(spacer)

	# Category label
	var cat_label: Label = Label.new()
	cat_label.text = "Category:"
	cat_label.add_theme_font_size_override("font_size", 12)
	cat_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	tier_row.add_child(cat_label)

	# Category dropdown
	_category_dropdown = OptionButton.new()
	_category_dropdown.add_item("Equipment", 0)
	_category_dropdown.add_item("Processing", 1)
	_category_dropdown.custom_minimum_size = Vector2(120, 30)
	_category_dropdown.item_selected.connect(_on_category_changed)
	var dd_style: StyleBoxFlat = StyleBoxFlat.new()
	dd_style.bg_color = Color(0.15, 0.13, 0.2, 1)
	dd_style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	dd_style.set_border_width_all(1)
	dd_style.set_corner_radius_all(4)
	_category_dropdown.add_theme_stylebox_override("normal", dd_style)
	tier_row.add_child(_category_dropdown)

	# Separator
	var sep: HSeparator = HSeparator.new()
	content.add_child(sep)

	# Scroll container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	# Grid container with 3 columns for recipe cards
	_recipes_grid = CraftingUIUtils.create_recipe_grid(3)
	scroll.add_child(_recipes_grid)

	# Populate recipes for current category
	_populate_recipes()

func _populate_recipes() -> void:
	"""Populate the recipes grid based on current category"""
	if not _recipes_grid or not _current_node:
		return

	# Clear existing cards
	for child in _recipes_grid.get_children():
		child.queue_free()

	var available_tasks: Array = _get_available_tasks_for_forge(_current_node.tier)

	# Add recipe cards
	for task in available_tasks:
		var costs: Dictionary = CraftingUIUtils.get_recipe_costs(task)
		var can_afford: bool = _can_afford_craft(costs)
		var is_conversion: bool = CraftingUIUtils.is_conversion_recipe(task)

		var craft_callback: Callable = func(t: Dictionary, _auto_repeat: bool): _on_start_craft(t)

		var card: Control = CraftingUIUtils.create_recipe_card(
			task,
			can_afford,
			craft_callback,
			is_conversion,
			_resource_manager
		)
		_recipes_grid.add_child(card)

func _on_category_changed(index: int) -> void:
	"""Handle category dropdown selection change"""
	match index:
		0:
			_current_category = "equipment"
		1:
			_current_category = "processing"
	_populate_recipes()

func _get_available_tasks_for_forge(tier: int) -> Array:
	"""Get crafting recipes available for a forge at the given tier, filtered by category"""
	var available: Array = []

	for recipe_id: String in _tasks_data.keys():
		var recipe: Dictionary = _tasks_data[recipe_id]

		# Filter by category
		var recipe_category: String = recipe.get("category", "equipment")
		if recipe_category != _current_category:
			continue

		# Check if this recipe can be crafted at a forge
		var territory_type: String = recipe.get("territory_type_requirement", "")

		# Skip recipes that specifically require shrine (not forge)
		if territory_type == "shrine":
			continue

		# Get tier requirement (default to 1 if not specified)
		var required_tier: int = recipe.get("territory_tier_requirement", 1)
		var territory_required: bool = recipe.get("territory_required", false)

		# If territory is not required, can craft at any forge (tier 1+)
		# Processing recipes never require territory
		if not territory_required or recipe_category == "processing":
			required_tier = recipe.get("tier", 1)

		# Check if tier is sufficient
		if tier >= required_tier:
			var task_copy: Dictionary = recipe.duplicate()
			task_copy["id"] = recipe_id
			available.append(task_copy)

	return available

func _can_afford_craft(costs: Dictionary) -> bool:
	"""Check if player can afford the craft costs"""
	if costs.is_empty():
		return true
	if not _resource_manager:
		return true
	return _resource_manager.can_afford(costs)

func _on_bg_clicked(event: InputEvent) -> void:
	"""Handle click on popup background"""
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func close_popup() -> void:
	"""Close the crafting popup"""
	popup_closed.emit()
	queue_free()

func _on_start_craft(task: Dictionary) -> void:
	"""Handle starting a craft task"""
	if not _current_node:
		return

	var task_id: String = task.get("id", "")
	if task_id.is_empty():
		return

	# Check and spend resources
	var costs: Dictionary = task.get("materials", task.get("resource_costs", {}))
	if not costs.is_empty():
		if not _resource_manager:
			return
		if not _resource_manager.can_afford(costs):
			return
		if not _resource_manager.spend_resources(costs):
			return

	# Start the craft
	var success: bool = false
	if _hex_grid_manager and _hex_grid_manager.has_method("start_craft"):
		success = _hex_grid_manager.start_craft(_current_node.id, task_id, task)

	if not success:
		# Refund resources
		if _resource_manager:
			for resource_id: String in costs:
				_resource_manager.add_resource(resource_id, costs[resource_id])
		_show_error_feedback("Forge busy or no worker assigned")
		return

	craft_started.emit(task, _current_node)
	_show_success_feedback(task)
	close_popup()

func _show_error_feedback(message: String) -> void:
	"""Show error feedback"""
	var feedback: PanelContainer = PanelContainer.new()
	feedback.z_index = 150

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.15, 0.15, 0.95)
	style.border_color = Color(0.8, 0.3, 0.3, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "❌ " + message
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	feedback.add_child(label)

	add_child(feedback)
	feedback.position = Vector2(size.x / 2 - 150, 100)

	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

func _show_success_feedback(task: Dictionary) -> void:
	"""Show feedback when craft starts"""
	var task_name: String = task.get("name", "Recipe")
	var duration: int = task.get("base_duration_seconds", 0)
	var duration_text: String = CraftingUIUtils.format_duration(duration)

	var feedback: PanelContainer = PanelContainer.new()
	feedback.z_index = 150

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.3, 0.95)
	style.border_color = Color(0.4, 0.7, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	feedback.add_theme_stylebox_override("panel", style)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	feedback.add_child(content)

	var title_label: Label = Label.new()
	title_label.text = "⚒️ Crafting Started!"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var task_label: Label = Label.new()
	task_label.text = task_name
	task_label.add_theme_font_size_override("font_size", 14)
	task_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(task_label)

	var time_label: Label = Label.new()
	time_label.text = "Completes in: %s" % duration_text
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(time_label)

	# Add to main scene
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(feedback)
	else:
		get_tree().root.add_child(feedback)

	# Position at center of screen
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feedback.custom_minimum_size = Vector2(300, 100)

	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)
