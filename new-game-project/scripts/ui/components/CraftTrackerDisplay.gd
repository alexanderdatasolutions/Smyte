# scripts/ui/components/CraftTrackerDisplay.gd
# Handles crafting tracker section: blacksmith list, craft progress, popup, and craft rewards
extends RefCounted

signal craft_collected(task_data: Dictionary)
signal navigate_to_crafting_requested

const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)

var _craft_section: VBoxContainer = null
var _craft_list: VBoxContainer = null
var _craft_button: Button = null
var _craft_popup: Control = null
var _current_craft_node: HexNode = null
var _crafting_screen_manager: CraftingScreenManager = null
var _recipes_data: Dictionary = {}
var _buildings_data: Dictionary = {}
var _equipment_config: Dictionary = {}
var _widget: PanelContainer = null  # Parent widget for tree access

func initialize(content_container: VBoxContainer, widget: PanelContainer) -> void:
	_widget = widget
	_load_buildings_data()
	_load_recipes_data()
	_load_equipment_config()
	_create_craft_section(content_container)

func _load_buildings_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Variant = json.get_data()
			if data is Dictionary:
				_buildings_data = data.get("buildings", {})
		file.close()

func _load_recipes_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Variant = json.get_data()
			if data is Dictionary:
				_recipes_data = data
		file.close()

func _load_equipment_config() -> void:
	var file: FileAccess = FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data: Variant = json.get_data()
			if data is Dictionary:
				_equipment_config = data
		file.close()

func _get_crafting_building_types() -> Array:
	var forge_cfg: Dictionary = _equipment_config.get("forge_config", {})
	var types: Array = forge_cfg.get("crafting_building_types", ["blacksmith", "weapon_forge", "armor_forge", "divine_forge"])
	return types

func get_refiner_conversions(_hex_grid_manager: Variant, player_nodes: Array) -> Array:
	var conversions: Array = []
	for node: HexNode in player_nodes:
		if not node.placed_building:
			continue

		var building: Dictionary = _buildings_data.get(node.placed_building, {})
		var consumes: Dictionary = building.get("consumes", {})
		var production: Dictionary = building.get("production", {})

		if not consumes.is_empty() and not production.is_empty():
			conversions.append({
				"name": building.get("name", node.placed_building),
				"consumes": consumes,
				"produces": production,
				"node_name": node.name
			})
	return conversions

# ==============================================================================
# CRAFT SECTION UI
# ==============================================================================

func _create_craft_section(content_container: VBoxContainer) -> void:
	_craft_section = VBoxContainer.new()
	_craft_section.add_theme_constant_override("separation", 4)
	content_container.add_child(_craft_section)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_craft_section.add_child(header)

	var icon: Label = Label.new()
	icon.text = "⚒️"
	icon.add_theme_font_size_override("font_size", 14)
	header.add_child(icon)

	var title: Label = Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_craft_button = Button.new()
	_craft_button.text = "Blacksmith"
	_craft_button.pressed.connect(_on_craft_button_pressed)
	_style_button(_craft_button, false)
	header.add_child(_craft_button)

	var no_crafts: HBoxContainer = HBoxContainer.new()
	no_crafts.name = "NoCrafts"
	_craft_section.add_child(no_crafts)

	var no_label: Label = Label.new()
	no_label.text = "No active crafts"
	no_label.add_theme_font_size_override("font_size", 11)
	no_label.add_theme_color_override("font_color", COLOR_MUTED)
	no_crafts.add_child(no_label)

	_craft_list = VBoxContainer.new()
	_craft_list.name = "CraftList"
	_craft_list.add_theme_constant_override("separation", 4)
	_craft_section.add_child(_craft_list)

# ==============================================================================
# CRAFT DISPLAY UPDATE
# ==============================================================================

func update_craft_display(hex_grid_manager: Variant) -> void:
	_craft_section.visible = true

	if not hex_grid_manager:
		_show_no_blacksmiths_state()
		return

	var blacksmith_nodes: Array = _get_player_blacksmith_nodes(hex_grid_manager)

	if blacksmith_nodes.is_empty():
		_show_no_blacksmiths_state()
		return

	_show_blacksmith_list(blacksmith_nodes, hex_grid_manager)

func _get_player_blacksmith_nodes(hex_grid_manager: Variant) -> Array:
	var nodes: Array = []
	var crafting_types: Array = _get_crafting_building_types()

	var all_nodes: Array = []
	if hex_grid_manager.has_method("get_nodes_by_controller"):
		all_nodes = hex_grid_manager.get_nodes_by_controller("player")
	elif hex_grid_manager.has_method("get_all_nodes"):
		all_nodes = hex_grid_manager.get_all_nodes()

	for node: HexNode in all_nodes:
		if not node.is_controlled_by_player():
			continue
		var building: String = node.placed_building if node.placed_building else ""
		if building in crafting_types:
			nodes.append(node)

	return nodes

func _show_no_blacksmiths_state() -> void:
	var no_crafts: HBoxContainer = _craft_section.get_node_or_null("NoCrafts") as HBoxContainer
	if no_crafts:
		no_crafts.visible = true
		for child: Node in no_crafts.get_children():
			if child is Label:
				(child as Label).text = "No blacksmiths owned"
	_craft_list.visible = false
	if _craft_button:
		_craft_button.visible = false

func _show_blacksmith_list(blacksmith_nodes: Array, hex_grid_manager: Variant) -> void:
	var no_crafts: HBoxContainer = _craft_section.get_node_or_null("NoCrafts") as HBoxContainer
	if no_crafts:
		no_crafts.visible = false
	_craft_list.visible = true
	if _craft_button:
		_craft_button.visible = false

	for child: Node in _craft_list.get_children():
		child.queue_free()

	var current_time: int = int(Time.get_unix_time_from_system())
	var count: int = 0

	for node: HexNode in blacksmith_nodes:
		if count >= 4:
			break

		var active_crafts_for_node: Array = []
		if hex_grid_manager.has_method("get_active_crafts_for_node"):
			active_crafts_for_node = hex_grid_manager.get_active_crafts_for_node(node.id)

		if active_crafts_for_node.is_empty():
			var item: HBoxContainer = _create_idle_blacksmith_item(node)
			_craft_list.add_child(item)
		else:
			var craft_data: Dictionary = active_crafts_for_node[0]
			var item: HBoxContainer = _create_craft_progress_item(craft_data, current_time, node.name)
			_craft_list.add_child(item)

		count += 1

	if blacksmith_nodes.size() > 4:
		var more: Label = Label.new()
		more.text = "+%d more smithies..." % (blacksmith_nodes.size() - 4)
		more.add_theme_font_size_override("font_size", 10)
		more.add_theme_color_override("font_color", COLOR_MUTED)
		_craft_list.add_child(more)

# ==============================================================================
# BLACKSMITH ITEMS
# ==============================================================================

func _create_idle_blacksmith_item(node: HexNode) -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)

	var node_name: String = node.name if node.name.length() <= 16 else node.name.substr(0, 14) + ".."
	var name_label: Label = Label.new()
	name_label.text = "⚒️ " + node_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.custom_minimum_size.x = 120
	item.add_child(name_label)

	var status_label: Label = Label.new()
	status_label.text = "Idle"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", COLOR_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(status_label)

	var craft_btn: Button = Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(50, 18)
	craft_btn.pressed.connect(_on_open_craft_for_node.bind(node))
	_style_small_button(craft_btn)
	item.add_child(craft_btn)

	return item

func _create_craft_progress_item(craft_data: Dictionary, current_time: int, node_name: String = "") -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)

	var task_data: Dictionary = craft_data.get("task_data", {})
	var task_name: String = task_data.get("name", "Crafting...")
	var start_time: int = craft_data.get("start_time", current_time)
	var end_time: int = craft_data.get("end_time", current_time + 60)

	var total_duration: int = end_time - start_time
	var elapsed: int = current_time - start_time
	var progress: float = clampf(float(elapsed) / float(total_duration), 0.0, 1.0)
	var remaining: int = maxi(0, end_time - current_time)
	var is_complete: bool = progress >= 1.0

	var display_name: String = node_name if node_name != "" else task_name
	if display_name.length() > 14:
		display_name = display_name.substr(0, 12) + ".."

	var node_label: Label = Label.new()
	node_label.text = "⚒️ " + display_name
	node_label.add_theme_font_size_override("font_size", 10)
	node_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	node_label.custom_minimum_size.x = 100
	item.add_child(node_label)

	var progress_container: Panel = Panel.new()
	progress_container.custom_minimum_size = Vector2(80, 14)
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var prog_style: StyleBoxFlat = StyleBoxFlat.new()
	prog_style.bg_color = Color(0.15, 0.15, 0.18)
	prog_style.set_corner_radius_all(3)
	progress_container.add_theme_stylebox_override("panel", prog_style)
	item.add_child(progress_container)

	var fill: ColorRect = ColorRect.new()
	fill.color = Color(0.3, 0.7, 0.4) if is_complete else Color(0.5, 0.4, 0.25)
	fill.anchor_right = progress
	fill.anchor_bottom = 1.0
	fill.offset_left = 1
	fill.offset_top = 1
	fill.offset_bottom = -1
	progress_container.add_child(fill)

	var status_label: Label = Label.new()
	if is_complete:
		status_label.text = "✓ Ready!"
		status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		status_label.text = _format_duration(remaining)
		status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size.x = 55
	item.add_child(status_label)

	if is_complete:
		var collect_btn: Button = Button.new()
		collect_btn.text = "Collect"
		collect_btn.custom_minimum_size = Vector2(50, 18)
		collect_btn.pressed.connect(_on_collect_craft.bind(craft_data))

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		btn_style.set_corner_radius_all(3)
		collect_btn.add_theme_stylebox_override("normal", btn_style)
		collect_btn.add_theme_font_size_override("font_size", 9)
		collect_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		item.add_child(collect_btn)

	return item

# ==============================================================================
# CRAFT POPUP
# ==============================================================================

func _on_open_craft_for_node(node: HexNode) -> void:
	_current_craft_node = node
	_show_craft_popup(node)

func _show_craft_popup(node: HexNode) -> void:
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null

	var available_recipes: Array = _get_available_recipes_for_node(node)
	if available_recipes.is_empty():
		return

	var hex_grid_manager: Variant = _get_system("HexGridManager")
	var resource_manager: Variant = _get_system("ResourceManager")

	_crafting_screen_manager = CraftingScreenManager.new()
	_crafting_screen_manager.craft_started.connect(_on_craft_started_from_screen)
	_crafting_screen_manager.popup_closed.connect(_on_crafting_screen_closed)

	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return
	var parent_node: Node = scene_tree.root.get_node_or_null("Main")
	if not parent_node:
		parent_node = scene_tree.root

	_crafting_screen_manager.show_crafting_screen(node, available_recipes, hex_grid_manager, resource_manager, parent_node)

func _get_available_recipes_for_node(node: HexNode) -> Array:
	var available: Array = []
	var max_tier: int = node.tier

	for recipe_id: String in _recipes_data.keys():
		if recipe_id.begins_with("_"):
			continue

		var recipe: Variant = _recipes_data[recipe_id]
		if not recipe is Dictionary:
			continue

		var recipe_tier: int = (recipe as Dictionary).get("tier", (recipe as Dictionary).get("territory_tier_requirement", 1))
		if recipe_tier > max_tier:
			continue

		var recipe_with_id: Dictionary = (recipe as Dictionary).duplicate()
		recipe_with_id["id"] = recipe_id
		available.append(recipe_with_id)

	return available

func _on_craft_started_from_screen(_node: HexNode, task_id: String) -> void:
	var hex_grid_manager: Variant = _get_system("HexGridManager")
	if hex_grid_manager:
		update_craft_display(hex_grid_manager)
	var task_data: Dictionary = _recipes_data.get(task_id, {})
	var _task_name: String = task_data.get("name", task_id)

func _on_crafting_screen_closed() -> void:
	_crafting_screen_manager = null
	_current_craft_node = null
	var hex_grid_manager: Variant = _get_system("HexGridManager")
	if hex_grid_manager:
		update_craft_display(hex_grid_manager)

func _close_craft_popup() -> void:
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null
	_current_craft_node = null
	_crafting_screen_manager = null

# ==============================================================================
# CRAFT COLLECTION & REWARDS
# ==============================================================================

func _on_collect_craft(craft_data: Dictionary) -> void:
	var task_data: Dictionary = craft_data.get("task_data", {})
	var task_id: String = craft_data.get("task_id", "")
	var node_id: String = craft_data.get("node_id", "")

	_award_craft_rewards(task_data)

	var hex_grid_manager: Variant = _get_system("HexGridManager")
	if hex_grid_manager:
		hex_grid_manager.complete_craft(node_id, task_id)

	craft_collected.emit(task_data)
	update_craft_display(hex_grid_manager)
	_show_craft_collected_feedback(task_data)

func _award_craft_rewards(task_data: Dictionary) -> void:
	if task_data.has("equipment_type"):
		_award_equipment_craft(task_data)
		return

	var resource_manager: Variant = _get_system("ResourceManager")
	if not resource_manager:
		return

	var resources: Dictionary = task_data.get("output", task_data.get("resource_rewards", {}))
	for resource_id: String in resources.keys():
		var amount: int = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

func _award_equipment_craft(task_data: Dictionary) -> void:
	var registry: Variant = _get_system_registry()
	if not registry:
		push_error("[CraftTrackerDisplay] Cannot award equipment - SystemRegistry not available")
		return

	var equipment_type: String = task_data.get("equipment_type", "weapon")
	var rarity: String = task_data.get("rarity", "common")
	var recipe_id: String = task_data.get("id", "crafted_item")
	var equipment_set: String = task_data.get("equipment_set", "")
	var base_stats: Dictionary = task_data.get("base_stats", {})
	var item_name: String = task_data.get("name", "Crafted Equipment")

	var equipment: Equipment = Equipment.create_from_dungeon("crafted_" + recipe_id, equipment_type.to_lower(), rarity.to_lower(), 1)
	if not equipment:
		push_error("[CraftTrackerDisplay] Failed to create equipment from recipe: %s" % recipe_id)
		return

	equipment.name = item_name
	if equipment_set != "":
		equipment.equipment_set_type = equipment_set
		equipment.equipment_set_name = equipment_set.capitalize()

	for stat_name: String in base_stats:
		equipment.add_stat_bonus(stat_name, base_stats[stat_name])

	var equipment_manager: Variant = registry.get_system("EquipmentManager")
	if equipment_manager:
		equipment_manager.add_equipment_to_inventory(equipment)
	else:
		push_error("[CraftTrackerDisplay] EquipmentManager not found")

	var collection_manager: Variant = registry.get_system("CollectionManager")
	if collection_manager:
		collection_manager.add_equipment(equipment)
	else:
		push_error("[CraftTrackerDisplay] CollectionManager not found")

	var event_bus: Variant = registry.get_system("EventBus")
	if event_bus:
		event_bus.save_requested.emit()

func _show_craft_collected_feedback(task_data: Dictionary) -> void:
	if not _craft_button:
		return
	var task_name: String = task_data.get("name", "Item")
	var original: Color = _craft_button.modulate

	if not _widget or not is_instance_valid(_widget):
		return

	_craft_button.modulate = Color(0.5, 1.0, 0.5, 1.0)
	_craft_button.text = "✓ " + (task_name.substr(0, 8) if task_name.length() > 8 else task_name)

	var tween: Tween = _widget.create_tween()
	if tween:
		tween.tween_property(_craft_button, "modulate", original, 0.4)
		tween.tween_callback(func() -> void: _craft_button.text = "Blacksmith")

# ==============================================================================
# CRAFT BUTTON (NAVIGATE TO TERRITORY)
# ==============================================================================

func _on_craft_button_pressed() -> void:
	navigate_to_crafting_requested.emit()

	var hex_grid_manager: Variant = _get_system("HexGridManager")
	if not hex_grid_manager:
		return

	var crafting_types: Array = _get_crafting_building_types()
	var player_smithy: HexNode = null

	for building_type: String in crafting_types:
		if hex_grid_manager.has_method("get_nodes_by_building"):
			var nodes: Array = hex_grid_manager.get_nodes_by_building(building_type)
			for node: HexNode in nodes:
				if node.is_controlled_by_player():
					player_smithy = node
					break
		if player_smithy:
			break

	if not player_smithy:
		return

	var screen_manager: Variant = _get_system("ScreenManager")
	if not screen_manager:
		return

	var smithy_id: String = player_smithy.id
	if not screen_manager.screen_transition_completed.is_connected(_on_territory_screen_ready):
		screen_manager.screen_transition_completed.connect(_on_territory_screen_ready.bind(smithy_id), CONNECT_ONE_SHOT)

	screen_manager.change_screen("territory")

func _on_territory_screen_ready(screen_name: String, smithy_id: String) -> void:
	if screen_name != "territory" and screen_name != "hex_territory":
		return

	var screen_manager: Variant = _get_system("ScreenManager")
	if not screen_manager:
		return

	var territory_screen: Variant = screen_manager.get_current_screen()
	if territory_screen and territory_screen.has_method("navigate_to_node"):
		territory_screen.call_deferred("navigate_to_node", smithy_id, true)

# ==============================================================================
# STYLING HELPERS
# ==============================================================================

func _style_button(button: Button, primary: bool = false) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		style.border_color = Color(0.5, 0.8, 0.5, 0.8)
	else:
		style.bg_color = Color(0.5, 0.35, 0.2, 0.9)
		style.border_color = Color(0.7, 0.5, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))

func _style_small_button(button: Button) -> void:
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.5, 0.35, 0.2, 0.9)
	btn_style.border_color = Color(0.7, 0.5, 0.3, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", btn_style)

	var hover_style: StyleBoxFlat = btn_style.duplicate()
	hover_style.bg_color = Color(0.6, 0.45, 0.3, 0.9)
	button.add_theme_stylebox_override("hover", hover_style)

	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))

# ==============================================================================
# UTILITY
# ==============================================================================

func _format_duration(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		@warning_ignore("integer_division")
		var mins: int = seconds / 60
		var secs: int = seconds % 60
		return "%dm %ds" % [mins, secs]
	else:
		@warning_ignore("integer_division")
		var hours: int = seconds / 3600
		@warning_ignore("integer_division")
		var mins: int = (seconds % 3600) / 60
		return "%dh %dm" % [hours, mins]

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _get_system(system_name: String) -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system(system_name)
	return null
