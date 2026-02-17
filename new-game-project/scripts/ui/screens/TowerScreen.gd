# scripts/ui/screens/TowerScreen.gd
# Infinite Tower UI Screen - Uses TeamSelectionManager for unified team selection
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - Tower UI and navigation
extends Control

signal back_pressed

const TeamSelectionManagerScript = preload("res://scripts/ui/battle_setup/TeamSelectionManager.gd")
const TowerInfoSectionScript = preload("res://scripts/ui/tower/TowerInfoSection.gd")

# System references
var tower_manager: TowerManager
var battle_coordinator: Node
var screen_manager: Node

# Team selection manager
var team_manager: Node

func _ready():
	_init_systems()
	_create_ui()
	_setup_header()
	_connect_signals()
	call_deferred("_apply_fullscreen_size")

func _setup_header():
	"""Configure the unified GameHeader via MainUIOverlay"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("INFINITE TOWER")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	"""Update when this screen becomes visible"""
	if visible:
		_setup_header()
		_check_intro_tutorial()
		_refresh_tower_info()
		_update_start_button_text()

func _check_intro_tutorial() -> void:
	"""Check if intro tutorial should be shown for this screen."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return
	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if tutorial_orch and not tutorial_orch.is_tutorial_completed("tower_intro"):
		tutorial_orch.start_tutorial("tower_intro")

func _apply_fullscreen_size():
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	size = viewport_size
	position = Vector2.ZERO

func _init_systems():
	var registry = SystemRegistry.get_instance()
	if registry:
		tower_manager = registry.get_system("TowerManager")
		battle_coordinator = registry.get_system("BattleCoordinator")
		screen_manager = registry.get_system("ScreenManager")

func _create_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container with margins (leave space for header)
	var main_container: MarginContainer = MarginContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 55)
	main_container.add_theme_constant_override("margin_bottom", 10)
	add_child(main_container)

	# Initialize TeamSelectionManager
	team_manager = TeamSelectionManagerScript.new()
	add_child(team_manager)

	# Create tower info section to inject
	var tower_info: Control = TowerInfoSectionScript.create(tower_manager)
	team_manager.inject_top_section(tower_info)

	# Hide enemy/rewards previews (tower shows its own info in TowerInfoSection)
	team_manager.hide_section("enemies")
	team_manager.hide_section("rewards")

	# Set custom confirm button for tower
	_update_start_button_text()

	# Build the full UI
	team_manager.initialize_full(main_container)

	# Connect team manager signals
	team_manager.team_changed.connect(_on_team_changed)
	team_manager.setup_cancelled.connect(_on_back_pressed)

func _refresh_tower_info() -> void:
	"""Refresh the tower info section when visibility changes"""
	# Recreate tower info section with updated data
	if team_manager and tower_manager:
		var tower_info: Control = TowerInfoSectionScript.create(tower_manager)
		team_manager.inject_top_section(tower_info)

func _update_start_button_text() -> void:
	"""Update the start button text based on tower state"""
	if not tower_manager or not team_manager:
		return

	var text: String
	if tower_manager.is_run_active():
		text = "CONTINUE CLIMB"
	else:
		text = "START CLIMB"

	team_manager.set_confirm_button(text, _on_tower_start)

func _on_team_changed(_team: Array) -> void:
	"""Handle team changes - update button text if needed"""
	_update_start_button_text()

func _on_tower_start(team: Array) -> void:
	"""Start or continue the tower climb"""
	if team.is_empty():
		var has_gods: bool = false
		for god in team:
			if god != null:
				has_gods = true
				break
		if not has_gods:
			_show_message("Select at least 1 god!")
			return

	if not tower_manager:
		return

	if not tower_manager.is_run_active():
		tower_manager.start_tower_run(team)

	if battle_coordinator:
		var config: BattleConfig = tower_manager.create_tower_battle_config()
		battle_coordinator.current_battle_config = config
		if not battle_coordinator.battle_ended.is_connected(_on_battle_ended):
			battle_coordinator.battle_ended.connect(_on_battle_ended)
		battle_coordinator.start_battle(config)
		if screen_manager:
			screen_manager.change_screen("battle")

func _connect_signals():
	if tower_manager:
		if not tower_manager.floor_completed.is_connected(_on_floor_completed):
			tower_manager.floor_completed.connect(_on_floor_completed)
		if not tower_manager.tower_run_ended.is_connected(_on_run_ended):
			tower_manager.tower_run_ended.connect(_on_run_ended)

func _on_battle_ended(result: BattleResult) -> void:
	if not tower_manager or not tower_manager.is_run_active():
		return

	# Save HP state from battle before advancing
	if battle_coordinator and battle_coordinator.battle_state:
		tower_manager.save_team_hp_from_battle(battle_coordinator.battle_state)

	if result.victory:
		tower_manager.complete_current_floor()
		tower_manager.advance_to_next_floor()
		_refresh_tower_info()
		_update_start_button_text()
		# Auto-continue after 1 second
		get_tree().create_timer(1.0).timeout.connect(func():
			if tower_manager.is_run_active():
				var current_team: Array = team_manager.get_selected_team() if team_manager else []
				_on_tower_start(current_team)
		)
	else:
		# Defeat - end the run
		tower_manager.end_tower_run(false)

func _on_floor_completed(_floor_num: int, _rewards: Dictionary):
	_refresh_tower_info()
	_update_start_button_text()

func _on_run_ended(final_floor: int, is_new_record: bool, total_rewards: Dictionary):
	# Navigate back to tower screen first
	if screen_manager:
		screen_manager.change_screen("tower")

	_refresh_tower_info()
	_update_start_button_text()

	# Show result popup after a short delay
	get_tree().create_timer(0.3).timeout.connect(func():
		_show_run_result(final_floor, is_new_record, total_rewards)
	)

func _show_run_result(final_floor: int, is_new_record: bool, total_rewards: Dictionary):
	var popup: PanelContainer = PanelContainer.new()
	popup.z_index = 100
	_style_panel(popup)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "NEW RECORD!" if is_new_record else "RUN ENDED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.GOLD if is_new_record else Color.WHITE)
	vbox.add_child(title)

	# Floor reached
	var floor_text: Label = Label.new()
	floor_text.text = "Reached Floor %d" % final_floor
	floor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_text.add_theme_font_size_override("font_size", 18)
	vbox.add_child(floor_text)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Rewards section
	if not total_rewards.is_empty():
		var rewards_title: Label = Label.new()
		rewards_title.text = "TOTAL LOOT EARNED"
		rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rewards_title.add_theme_font_size_override("font_size", 14)
		rewards_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		vbox.add_child(rewards_title)

		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(300, 150)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(scroll)

		var rewards_grid: GridContainer = GridContainer.new()
		rewards_grid.columns = 2
		rewards_grid.add_theme_constant_override("h_separation", 20)
		rewards_grid.add_theme_constant_override("v_separation", 5)
		scroll.add_child(rewards_grid)

		var sorted_rewards: Array = _sort_rewards_for_display(total_rewards)
		for item: Dictionary in sorted_rewards:
			var name_label: Label = Label.new()
			name_label.text = _get_resource_display_name(item.id)
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.add_theme_color_override("font_color", _get_resource_color(item.id))
			rewards_grid.add_child(name_label)

			var amount_label: Label = Label.new()
			amount_label.text = "x%s" % _format_number(item.amount)
			amount_label.add_theme_font_size_override("font_size", 12)
			amount_label.add_theme_color_override("font_color", Color.WHITE)
			amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rewards_grid.add_child(amount_label)
	else:
		var no_loot: Label = Label.new()
		no_loot.text = "No loot earned (defeated on floor 1)"
		no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_loot.add_theme_font_size_override("font_size", 12)
		no_loot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		vbox.add_child(no_loot)

	# Close button
	var close_btn: Button = Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(func(): popup.queue_free())
	_style_button(close_btn)
	vbox.add_child(close_btn)

	add_child(popup)
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	popup.position = (viewport_size - popup.size) / 2

func _sort_rewards_for_display(rewards: Dictionary) -> Array:
	"""Sort rewards into display order: currencies, souls, materials"""
	var currency_order: Array = ["mana", "gold", "divine_crystals"]
	var soul_order: Array = ["common_soul", "rare_soul", "epic_soul", "legendary_soul"]

	var sorted: Array = []
	for currency: String in currency_order:
		if rewards.has(currency):
			sorted.append({"id": currency, "amount": rewards[currency]})

	for soul: String in soul_order:
		if rewards.has(soul):
			sorted.append({"id": soul, "amount": rewards[soul]})

	for key: String in rewards:
		if key not in currency_order and key not in soul_order:
			sorted.append({"id": key, "amount": rewards[key]})

	return sorted

func _get_resource_display_name(resource_id: String) -> String:
	"""Get a display-friendly name for a resource"""
	var names: Dictionary = {
		"mana": "Mana",
		"gold": "Gold",
		"divine_crystals": "Divine Crystals",
		"common_soul": "Common Soul",
		"rare_soul": "Rare Soul",
		"epic_soul": "Epic Soul",
		"legendary_soul": "Legendary Soul",
		"awakening_essence": "Awakening Essence",
		"divine_essence": "Divine Essence",
		"ore": "Ore",
		"wood": "Wood",
		"herbs": "Herbs",
		"refined_metal": "Refined Metal",
		"fine_ore": "Fine Ore",
		"steel_ingot": "Steel Ingot",
		"arcane_ore": "Arcane Ore",
		"prometheum": "Prometheum",
		"monster_parts": "Monster Parts",
		"beast_scales": "Beast Scales",
		"elemental_cores": "Elemental Cores",
		"basic_flame": "Basic Flame",
		"forging_flame": "Forging Flame",
		"divine_flame": "Divine Flame",
		"eternal_flame": "Eternal Flame",
		"socket_crystal": "Socket Crystal",
		"astral_shard": "Astral Shard",
		"divine_metal": "Divine Metal",
		"ascension_crystal": "Ascension Crystal"
	}
	if resource_id.ends_with("_powder"):
		var element: String = resource_id.replace("_powder", "").capitalize()
		return element + " Powder"
	return names.get(resource_id, resource_id.capitalize().replace("_", " "))

func _get_resource_color(resource_id: String) -> Color:
	"""Get color for resource display"""
	if resource_id == "mana":
		return Color(0.4, 0.6, 1.0)
	elif resource_id == "gold":
		return Color.GOLD
	elif resource_id == "divine_crystals":
		return Color(0.8, 0.5, 1.0)
	elif resource_id.ends_with("_soul"):
		match resource_id:
			"common_soul": return Color(0.7, 0.7, 0.7)
			"rare_soul": return Color(0.3, 0.7, 1.0)
			"epic_soul": return Color(0.8, 0.4, 1.0)
			"legendary_soul": return Color(1.0, 0.8, 0.2)
	elif resource_id.ends_with("_powder"):
		if "fire" in resource_id: return Color(1.0, 0.4, 0.3)
		if "water" in resource_id: return Color(0.3, 0.6, 1.0)
		if "earth" in resource_id: return Color(0.6, 0.4, 0.2)
		if "lightning" in resource_id: return Color(1.0, 1.0, 0.3)
		if "light" in resource_id: return Color(1.0, 1.0, 0.8)
		if "dark" in resource_id: return Color(0.5, 0.3, 0.7)
	elif resource_id.ends_with("_flame"):
		return Color(1.0, 0.6, 0.2)
	elif "essence" in resource_id:
		return Color(0.6, 0.9, 0.6)
	return Color(0.8, 0.8, 0.85)

func _format_number(num: int) -> String:
	"""Format large numbers with K/M suffix"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _on_back_pressed():
	back_pressed.emit()
	if screen_manager:
		screen_manager.change_screen("worldview")

func _show_message(text: String):
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.z_index = 100
	add_child(label)
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2((viewport_size.x - label.size.x) / 2, viewport_size.y / 2)
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _style_panel(panel: PanelContainer):
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button):
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)
	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_font_size_override("font_size", 14)
