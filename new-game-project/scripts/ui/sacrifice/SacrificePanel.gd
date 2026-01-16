# scripts/ui/sacrifice/SacrificePanel.gd
# Clean sacrifice panel for material selection - under 500 lines
class_name SacrificePanel
extends Control

signal sacrifice_requested(target_god: God, material_gods: Array[God])

var target_god_display: Control
var material_grid: GridContainer
var sacrifice_button: Button
var lock_in_button: Button
var xp_bar: ProgressBar
var xp_label: Label
var level_preview_label: Label
var selection_status_label: Label

var current_target_god: God
var selected_materials: Array[God] = []
var locked_in: bool = false

enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false

var sacrifice_manager: SacrificeManager
var collection_manager: CollectionManager

func _ready():
	_initialize_systems()
	_setup_ui()

func _initialize_systems():
	var system_registry = SystemRegistry.get_instance()
	sacrifice_manager = system_registry.get_system("SacrificeManager")
	collection_manager = system_registry.get_system("CollectionManager")

func _setup_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	var title = Label.new()
	title.text = "SELECT GOD TO SACRIFICE"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	_create_target_display(main_vbox)
	_create_xp_preview(main_vbox)
	_create_material_section(main_vbox)
	_create_buttons(main_vbox)

func _create_target_display(parent: Control):
	target_god_display = Panel.new()
	target_god_display.custom_minimum_size = Vector2(300, 80)
	target_god_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.2, 1.0)
	target_god_display.add_theme_stylebox_override("panel", style)
	parent.add_child(target_god_display)

func _create_xp_preview(parent: Control):
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	level_preview_label = Label.new()
	level_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_preview_label.add_theme_font_size_override("font_size", 14)
	container.add_child(level_preview_label)
	
	var hbox = HBoxContainer.new()
	container.add_child(hbox)
	
	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.custom_minimum_size = Vector2(0, 20)
	hbox.add_child(xp_bar)
	
	xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(120, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(xp_label)
	
	selection_status_label = Label.new()
	selection_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_status_label.add_theme_font_size_override("font_size", 10)
	selection_status_label.visible = false
	container.add_child(selection_status_label)

func _create_material_section(parent: Control):
	var section = VBoxContainer.new()
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	
	_create_sorting_controls(section)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	section.add_child(scroll)
	
	material_grid = GridContainer.new()
	material_grid.columns = 5
	material_grid.add_theme_constant_override("h_separation", 8)
	material_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(material_grid)

func _create_sorting_controls(parent: Control):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = "Sort:"
	hbox.add_child(label)
	
	var sorts = [
		{"text": "Pwr", "type": SortType.POWER},
		{"text": "Lvl", "type": SortType.LEVEL}, 
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Elem", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for sort_data in sorts:
		var btn = Button.new()
		btn.text = sort_data.text
		btn.custom_minimum_size = Vector2(35, 20)
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(_on_sort_changed.bind(sort_data.type))
		hbox.add_child(btn)
	
	var dir_btn = Button.new()
	dir_btn.text = "↓" if not sort_ascending else "↑"
	dir_btn.custom_minimum_size = Vector2(20, 20)
	dir_btn.pressed.connect(_on_sort_direction_changed)
	hbox.add_child(dir_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var dupes_btn = Button.new()
	dupes_btn.text = "Dupes"
	dupes_btn.custom_minimum_size = Vector2(40, 20)
	dupes_btn.add_theme_font_size_override("font_size", 9)
	dupes_btn.pressed.connect(_on_select_duplicates_pressed)
	hbox.add_child(dupes_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(35, 20)
	clear_btn.add_theme_font_size_override("font_size", 9)
	clear_btn.pressed.connect(_on_clear_selection_pressed)
	hbox.add_child(clear_btn)

func _create_buttons(parent: Control):
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)
	
	lock_in_button = Button.new()
	lock_in_button.text = "Lock In"
	lock_in_button.custom_minimum_size = Vector2(100, 35)
	lock_in_button.disabled = true
	lock_in_button.pressed.connect(_on_lock_in_pressed)
	hbox.add_child(lock_in_button)
	
	sacrifice_button = Button.new()
	sacrifice_button.text = "SACRIFICE"
	sacrifice_button.custom_minimum_size = Vector2(100, 35)
	sacrifice_button.disabled = true
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.2, 0.2, 1.0)
	sacrifice_button.add_theme_stylebox_override("normal", style)
	hbox.add_child(sacrifice_button)

func initialize_with_god(god: God):
	current_target_god = god
	selected_materials.clear()
	locked_in = false
	_update_all_displays()

func add_material_god(god: God):
	if locked_in or not god or god == current_target_god:
		return
	
	if selected_materials.has(god):
		selected_materials.erase(god)
		_show_feedback("Removed %s" % god.name, Color.YELLOW)
	else:
		selected_materials.append(god)
		_show_feedback("Added %s (%d selected)" % [god.name, selected_materials.size()], Color.GREEN)
	
	_update_all_displays()

func _on_sort_changed(sort_type: SortType):
	current_sort = sort_type
	_update_all_displays()

func _on_sort_direction_changed():
	sort_ascending = !sort_ascending
	_update_all_displays()

func _on_select_duplicates_pressed():
	if locked_in or not collection_manager:
		return
	
	var gods = collection_manager.get_all_gods()
	var by_name = {}
	
	for god in gods:
		if god == current_target_god:
			continue
		if not by_name.has(god.name):
			by_name[god.name] = []
		by_name[god.name].append(god)
	
	var count = 0
	for god_name in by_name:
		var god_list = by_name[god_name]
		if god_list.size() > 1:
			god_list.sort_custom(func(a, b): return a.level > b.level)
			for i in range(1, god_list.size()):
				if not selected_materials.has(god_list[i]):
					selected_materials.append(god_list[i])
					count += 1
	
	_show_feedback("Selected %d duplicates" % count, Color.CYAN)
	_update_all_displays()

func _on_clear_selection_pressed():
	if locked_in:
		return
	
	var count = selected_materials.size()
	selected_materials.clear()
	_show_feedback("Cleared %d gods" % count, Color.ORANGE)
	_update_all_displays()

func _on_lock_in_pressed():
	if selected_materials.size() == 0:
		return
	
	locked_in = true
	lock_in_button.text = "Locked (%d)" % selected_materials.size()
	lock_in_button.disabled = true
	_update_all_displays()

func _on_sacrifice_pressed():
	if not locked_in or selected_materials.size() == 0:
		return
	
	_show_confirmation()

func _update_all_displays():
	_update_target_display()
	_update_xp_bar()
	_populate_material_grid()
	_update_button_states()

func _update_target_display():
	if not target_god_display:
		return
	
	for child in target_god_display.get_children():
		child.queue_free()
	
	if not current_target_god:
		var label = Label.new()
		label.text = "No god selected"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target_god_display.add_child(label)
		return
	
	await get_tree().process_frame
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_god_display.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [current_target_god.name, current_target_god.level]
	vbox.add_child(name_label)
	
	var details_label = Label.new()
	details_label.text = "%s - Power: %d" % [God.tier_to_string(current_target_god.tier), current_target_god.get_power_rating()]
	details_label.add_theme_font_size_override("font_size", 10)
	details_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(details_label)

func _update_xp_bar():
	if not current_target_god or not xp_bar:
		return
	
	var preview_xp = 0
	if selected_materials.size() > 0 and sacrifice_manager:
		var result = sacrifice_manager.calculate_sacrifice_preview(current_target_god, selected_materials)
		preview_xp = result.get("total_xp", 0)
	
	var current_xp = current_target_god.experience
	var xp_to_next = current_target_god.get_experience_to_next_level()
	
	if preview_xp > 0:
		xp_bar.modulate = Color.GREEN
		xp_label.text = "%d XP (+%d)" % [current_xp, preview_xp]
		level_preview_label.text = "Level %d → Preview" % current_target_god.level
	else:
		xp_bar.modulate = Color.WHITE
		xp_label.text = "%d / %d XP" % [current_xp, xp_to_next]
		level_preview_label.text = "Level %d" % current_target_god.level
	
	var progress = float(current_xp) / float(xp_to_next) if xp_to_next > 0 else 1.0
	xp_bar.value = progress * 100

func _populate_material_grid():
	if not material_grid or not collection_manager:
		return
	
	for child in material_grid.get_children():
		child.queue_free()
	
	var gods = collection_manager.get_all_gods()
	var available = []
	
	for god in gods:
		if god == current_target_god:
			continue
		available.append(god)
	
	_sort_gods(available)
	
	for god in available:
		var item = _create_god_item(god)
		material_grid.add_child(item)

func _sort_gods(gods: Array):
	gods.sort_custom(func(a, b):
		var result = false
		match current_sort:
			SortType.POWER: result = a.get_power_rating() > b.get_power_rating()
			SortType.LEVEL: result = a.level > b.level
			SortType.TIER: result = a.tier > b.tier
			SortType.ELEMENT: result = a.element < b.element
			SortType.NAME: result = a.name < b.name
		return result if not sort_ascending else !result
	)

func _create_god_item(god: God) -> Control:
	var item = Panel.new()
	item.custom_minimum_size = Vector2(80, 90)
	
	var style = StyleBoxFlat.new()
	if selected_materials.has(god):
		style.bg_color = Color(0.8, 0.4, 0.2, 0.9)
		style.border_color = Color(1.0, 0.6, 0.3, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	elif locked_in:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	else:
		style.bg_color = _get_tier_color(god.tier)
	
	item.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(vbox)
	
	var image = TextureRect.new()
	image.custom_minimum_size = Vector2(32, 32)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Load god image based on god ID (matching CollectionScreen approach)
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		image.texture = load(sprite_path)
	else:
		print("SacrificePanel: God sprite not found: ", sprite_path)
	
	vbox.add_child(image)
	
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 7)
	level_label.horizontal_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)
	
	if not locked_in:
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(add_material_god.bind(god))
		item.add_child(btn)
	
	return item

func _update_button_states():
	if lock_in_button and sacrifice_button:
		lock_in_button.disabled = selected_materials.size() == 0 or locked_in
		sacrifice_button.disabled = not locked_in or selected_materials.size() == 0

func _show_feedback(message: String, color: Color):
	if not selection_status_label:
		return
	
	selection_status_label.text = message
	selection_status_label.modulate = color
	selection_status_label.visible = true
	
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): 
		if selection_status_label:
			selection_status_label.visible = false
	)

func _show_confirmation():
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Sacrifice"
	dialog.dialog_text = "Sacrifice %d gods to %s?\n\nThis cannot be undone!" % [selected_materials.size(), current_target_god.name]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_perform_sacrifice)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _perform_sacrifice():
	sacrifice_requested.emit(current_target_god, selected_materials)
	selected_materials.clear()
	locked_in = false
	_update_all_displays()

func _get_tier_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.25, 0.25, 0.25, 0.7)
		God.TierType.RARE: return Color(0.2, 0.3, 0.2, 0.7)
		God.TierType.EPIC: return Color(0.3, 0.2, 0.4, 0.7)
		God.TierType.LEGENDARY: return Color(0.4, 0.3, 0.1, 0.7)
		_: return Color(0.2, 0.2, 0.3, 0.7)
