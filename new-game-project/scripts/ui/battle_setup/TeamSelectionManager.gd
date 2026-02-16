# scripts/ui/battle_setup/TeamSelectionManager.gd
# Unified team selection with stats, bonuses, sorting, and equipment display
class_name TeamSelectionManager
extends Node

signal team_changed(team: Array)
signal battle_start_requested(team: Array)
signal setup_cancelled

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

# UI References (set via initialize or created internally)
var team_slots_container: HBoxContainer = null
var available_gods_grid: GridContainer = null
var start_battle_button: Button = null
var cancel_button: Button = null

# Stats display references
var team_power_label: Label = null
var team_bonuses_container: VBoxContainer = null
var stats_panel: Control = null

# Sorting UI references
var sort_dropdown: OptionButton = null
var sort_direction_btn: Button = null

# Data
var selected_team: Array = []
var team_slots: Array = []
var available_gods: Array = []
var unavailable_gods: Array = []  # Array of {god: God, assignment: String}
var max_team_size: int = 4
var battle_context: Dictionary = {}

# Battle info UI references
var enemy_preview_container: VBoxContainer = null
var rewards_preview_container: VBoxContainer = null

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false

func initialize(slots_container: HBoxContainer, gods_grid: GridContainer, start_btn: Button, cancel_btn: Button):
	"""Initialize with node references from the scene"""
	team_slots_container = slots_container
	available_gods_grid = gods_grid
	start_battle_button = start_btn
	cancel_button = cancel_btn

	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_create_team_slots()
	_load_available_gods()
	_update_team_stats()

func initialize_full(parent_container: Control):
	"""Full initialization - creates all UI elements"""
	_create_full_ui(parent_container)
	_load_available_gods()
	_update_team_stats()

func setup_for_context(context: Dictionary):
	battle_context = context
	_update_ui_for_context()

func _update_ui_for_context():
	match battle_context.get("type", ""):
		"territory":
			_setup_for_territory()
		"dungeon":
			_setup_for_dungeon()
		"pvp":
			_setup_for_pvp()
		"hex_capture":
			_setup_for_hex_capture()
		"tower":
			_setup_for_tower()
		"pvp_territory_attack":
			_setup_for_pvp_territory_attack()
		"pvp_territory_defense":
			_setup_for_pvp_territory_defense()

	# Update enemy and rewards preview
	_update_enemy_preview()
	_update_rewards_preview()

func _setup_for_territory():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_dungeon():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_pvp():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_hex_capture():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_tower():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_pvp_territory_attack():
	max_team_size = 4
	_refresh_team_slots()

func _setup_for_pvp_territory_defense():
	max_team_size = 4
	_refresh_team_slots()

# ============================================================================
# ENEMY & REWARDS PREVIEW
# ============================================================================

func _update_enemy_preview():
	"""Update the enemy preview based on battle context"""
	if not enemy_preview_container:
		return

	# Clear existing
	for child in enemy_preview_container.get_children():
		child.queue_free()

	var enemies: Array = []
	match battle_context.get("type", ""):
		"dungeon":
			enemies = _get_dungeon_enemies()
		"hex_capture":
			enemies = _get_hex_node_defenders()
		"territory":
			enemies = _get_territory_enemies()
		"pvp":
			enemies = _get_pvp_enemies()
		"tower":
			enemies = _get_tower_enemies()
		_:
			enemies = [{"name": "Unknown", "level": 1}]

	if enemies.is_empty():
		var no_enemy: Label = Label.new()
		no_enemy.text = "No enemy info available"
		no_enemy.add_theme_font_size_override("font_size", 10)
		no_enemy.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		enemy_preview_container.add_child(no_enemy)
	else:
		for enemy in enemies.slice(0, 4):  # Show max 4 enemies
			var enemy_row: HBoxContainer = HBoxContainer.new()
			enemy_row.add_theme_constant_override("separation", 8)

			var name_label: Label = Label.new()
			name_label.text = enemy.get("name", "Enemy")
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enemy_row.add_child(name_label)

			var level_label: Label = Label.new()
			level_label.text = "Lv." + str(enemy.get("level", 1))
			level_label.add_theme_font_size_override("font_size", 10)
			level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			enemy_row.add_child(level_label)

			enemy_preview_container.add_child(enemy_row)

func _update_rewards_preview():
	"""Update the rewards preview based on battle context"""
	if not rewards_preview_container:
		return

	# Clear existing
	for child in rewards_preview_container.get_children():
		child.queue_free()

	var rewards: Dictionary = {}
	match battle_context.get("type", ""):
		"dungeon":
			rewards = _get_dungeon_rewards()
		"hex_capture":
			rewards = _get_hex_node_rewards()
		"territory":
			rewards = _get_territory_rewards()
		"tower":
			rewards = _get_tower_rewards()
		_:
			rewards = {"mana": 100}

	if rewards.is_empty():
		var no_rewards: Label = Label.new()
		no_rewards.text = "No reward info available"
		no_rewards.add_theme_font_size_override("font_size", 10)
		no_rewards.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		rewards_preview_container.add_child(no_rewards)
	else:
		for resource_id in rewards:
			var amount = rewards[resource_id]
			var reward_row: HBoxContainer = HBoxContainer.new()
			reward_row.add_theme_constant_override("separation", 8)

			var name_label: Label = Label.new()
			name_label.text = resource_id.capitalize().replace("_", " ")
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reward_row.add_child(name_label)

			var amount_label: Label = Label.new()
			amount_label.text = "x" + _format_number(amount)
			amount_label.add_theme_font_size_override("font_size", 10)
			amount_label.add_theme_color_override("font_color", Color.GOLD)
			reward_row.add_child(amount_label)

			rewards_preview_container.add_child(reward_row)

func _get_dungeon_enemies() -> Array:
	var dungeon_id = battle_context.get("dungeon_id", "")
	var difficulty = battle_context.get("difficulty", "normal")
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	if dungeon_manager and dungeon_manager.has_method("get_dungeon_enemies"):
		return dungeon_manager.get_dungeon_enemies(dungeon_id, difficulty)
	return [{"name": "Dungeon Monster", "level": 5}]

func _get_hex_node_defenders() -> Array:
	var hex_node = battle_context.get("hex_node")
	if not hex_node:
		return []
	var defenders: Array = []
	for defender_name in hex_node.base_defenders:
		defenders.append({"name": defender_name, "level": hex_node.tier * 5})
	return defenders

func _get_territory_enemies() -> Array:
	var territory = battle_context.get("territory")
	var stage = battle_context.get("stage", 1)
	if not territory:
		return []
	return [{"name": "Territory Guardian", "level": stage * 3}]

func _get_pvp_enemies() -> Array:
	var opponent = battle_context.get("opponent", {})
	var team = opponent.get("defense_team", [])
	return team

func _get_tower_enemies() -> Array:
	var floor_num = battle_context.get("floor", 1)
	return [{"name": "Tower Guardian", "level": floor_num * 2}]

func _get_dungeon_rewards() -> Dictionary:
	var dungeon_id = battle_context.get("dungeon_id", "")
	var difficulty = battle_context.get("difficulty", "normal")
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	if dungeon_manager and dungeon_manager.has_method("get_dungeon_rewards"):
		return dungeon_manager.get_dungeon_rewards(dungeon_id, difficulty)
	# Default rewards based on difficulty
	match difficulty:
		"easy": return {"mana": 500, "gold": 100}
		"normal": return {"mana": 1000, "gold": 250}
		"hard": return {"mana": 2000, "gold": 500, "divine_crystals": 5}
		"expert": return {"mana": 5000, "gold": 1000, "divine_crystals": 15}
		_: return {"mana": 500}

func _get_hex_node_rewards() -> Dictionary:
	var hex_node = battle_context.get("hex_node")
	if not hex_node:
		return {}
	# Show what the node produces per hour once captured
	var rewards: Dictionary = {}
	if hex_node.base_production and not hex_node.base_production.is_empty():
		for resource_id in hex_node.base_production:
			rewards[resource_id] = hex_node.base_production[resource_id]
	return rewards

func _get_territory_rewards() -> Dictionary:
	var territory = battle_context.get("territory")
	var stage = battle_context.get("stage", 1)
	if not territory:
		return {}
	return {"mana": 500 * stage, "gold": 100 * stage}

func _get_tower_rewards() -> Dictionary:
	var floor_num = battle_context.get("floor", 1)
	return {"mana": 1000 * floor_num, "divine_crystals": floor_num}

# ============================================================================
# TEAM STATS DISPLAY
# ============================================================================

func create_stats_panel() -> Control:
	"""Create a panel showing team stats, bonuses, and controls"""
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	_style_panel(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Team header with clear button
	var header_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header_row)

	var team_title: Label = Label.new()
	team_title.text = "YOUR TEAM"
	team_title.add_theme_font_size_override("font_size", 14)
	team_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(team_title)

	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(70, 28)
	clear_btn.pressed.connect(_clear_team)
	_style_button(clear_btn)
	header_row.add_child(clear_btn)

	# Team slots container
	team_slots_container = HBoxContainer.new()
	team_slots_container.add_theme_constant_override("separation", 6)
	team_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(team_slots_container)

	# Combat power display
	var power_hbox: HBoxContainer = HBoxContainer.new()
	power_hbox.add_theme_constant_override("separation", 10)
	power_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(power_hbox)

	var power_icon: Label = Label.new()
	power_icon.text = "⚔️"
	power_icon.add_theme_font_size_override("font_size", 18)
	power_hbox.add_child(power_icon)

	var power_title: Label = Label.new()
	power_title.text = "Combat Power:"
	power_title.add_theme_font_size_override("font_size", 13)
	power_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	power_hbox.add_child(power_title)

	team_power_label = Label.new()
	team_power_label.text = "0"
	team_power_label.add_theme_font_size_override("font_size", 18)
	team_power_label.add_theme_color_override("font_color", Color.GOLD)
	power_hbox.add_child(team_power_label)

	# Team bonuses section
	var bonuses_header: Label = Label.new()
	bonuses_header.text = "TEAM BONUSES"
	bonuses_header.add_theme_font_size_override("font_size", 12)
	bonuses_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(bonuses_header)

	team_bonuses_container = VBoxContainer.new()
	team_bonuses_container.add_theme_constant_override("separation", 4)
	vbox.add_child(team_bonuses_container)

	# Equipment summary header
	var equip_header: Label = Label.new()
	equip_header.text = "EQUIPMENT"
	equip_header.add_theme_font_size_override("font_size", 12)
	equip_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(equip_header)

	# Equipment quick view container (shows equipped items per god)
	var equip_container: VBoxContainer = VBoxContainer.new()
	equip_container.name = "EquipmentContainer"
	equip_container.add_theme_constant_override("separation", 4)
	vbox.add_child(equip_container)

	# Separator
	var sep1: HSeparator = HSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	vbox.add_child(sep1)

	# Enemy preview section
	var enemy_header: Label = Label.new()
	enemy_header.text = "ENEMIES"
	enemy_header.add_theme_font_size_override("font_size", 12)
	enemy_header.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	vbox.add_child(enemy_header)

	enemy_preview_container = VBoxContainer.new()
	enemy_preview_container.add_theme_constant_override("separation", 4)
	vbox.add_child(enemy_preview_container)

	# Separator
	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	# Battle rewards section
	var rewards_header: Label = Label.new()
	rewards_header.text = "BATTLE REWARDS"
	rewards_header.add_theme_font_size_override("font_size", 12)
	rewards_header.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
	vbox.add_child(rewards_header)

	rewards_preview_container = VBoxContainer.new()
	rewards_preview_container.add_theme_constant_override("separation", 4)
	vbox.add_child(rewards_preview_container)

	stats_panel = panel
	_create_team_slots()

	return panel

func _update_team_stats():
	"""Update combat power and team bonuses display"""
	if not team_power_label:
		return

	# Calculate and display combat power
	var total_power = TeamStatsCalculator.calculate_team_power(selected_team)
	team_power_label.text = _format_number(total_power)

	# Update bonuses display
	_update_team_bonuses_display()

	# Update equipment display
	_update_equipment_display()

func _update_team_bonuses_display():
	"""Update the team bonuses list"""
	if not team_bonuses_container:
		return

	# Clear existing
	for child in team_bonuses_container.get_children():
		child.queue_free()

	# Get active bonuses
	var bonuses = TeamStatsCalculator.get_team_bonuses(selected_team)

	if bonuses.is_empty():
		var no_bonus: Label = Label.new()
		no_bonus.text = "No active bonuses"
		no_bonus.add_theme_font_size_override("font_size", 11)
		no_bonus.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		team_bonuses_container.add_child(no_bonus)
	else:
		for bonus in bonuses:
			var bonus_row: HBoxContainer = HBoxContainer.new()
			bonus_row.add_theme_constant_override("separation", 6)

			var name_label: Label = Label.new()
			name_label.text = bonus.name
			name_label.add_theme_font_size_override("font_size", 11)
			name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bonus_row.add_child(name_label)

			var desc_label: Label = Label.new()
			desc_label.text = bonus.desc
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			bonus_row.add_child(desc_label)

			team_bonuses_container.add_child(bonus_row)

func _update_equipment_display():
	"""Update the equipment quick view for selected gods"""
	if not stats_panel:
		return

	var equip_container = stats_panel.get_node_or_null("MarginContainer/VBoxContainer/EquipmentContainer")
	if not equip_container:
		return

	# Clear existing
	for child in equip_container.get_children():
		child.queue_free()

	# Check if any gods are selected
	var has_selected: bool = false
	for god in selected_team:
		if god != null:
			has_selected = true
			break

	if not has_selected:
		var no_team: Label = Label.new()
		no_team.text = "Select gods to view equipment"
		no_team.add_theme_font_size_override("font_size", 10)
		no_team.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		equip_container.add_child(no_team)
		return

	# Show equipment for each selected god
	for god in selected_team:
		if god == null:
			continue

		var god_equip: HBoxContainer = HBoxContainer.new()
		god_equip.add_theme_constant_override("separation", 6)

		# God name (abbreviated)
		var name_label: Label = Label.new()
		var display_name = god.name.substr(0, 8) if god.name.length() > 8 else god.name
		name_label.text = display_name
		name_label.custom_minimum_size = Vector2(70, 0)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
		god_equip.add_child(name_label)

		# Equipment slots (show icons or empty)
		var equip_text = _get_equipment_summary(god)
		var equip_label: Label = Label.new()
		equip_label.text = equip_text
		equip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_label.add_theme_font_size_override("font_size", 10)
		if equip_text == "No gear":
			equip_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		else:
			equip_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		god_equip.add_child(equip_label)

		# Edit button - always visible
		var edit_btn: Button = Button.new()
		edit_btn.text = "⚙"
		edit_btn.tooltip_text = "Edit " + god.name + "'s equipment"
		edit_btn.custom_minimum_size = Vector2(28, 24)
		edit_btn.add_theme_font_size_override("font_size", 12)
		edit_btn.pressed.connect(_on_edit_equipment.bind(god))
		_style_button(edit_btn)
		god_equip.add_child(edit_btn)

		equip_container.add_child(god_equip)

func _get_equipment_summary(god: God) -> String:
	"""Get a brief summary of god's equipment"""
	var equipment_manager = SystemRegistry.get_instance().get_system("EquipmentManager")
	if not equipment_manager:
		return "No gear"

	if not equipment_manager.has_method("get_equipped_items"):
		return "No gear"

	var equipped = equipment_manager.get_equipped_items(god.id)
	if equipped == null or equipped.is_empty():
		return "No gear"

	var count = equipped.size()
	if count == 1:
		return "1 item"
	return str(count) + " items"

func _on_edit_equipment(god: God):
	"""Open equipment popup for the god"""
	_show_equipment_popup(god)

func _show_equipment_popup(god: God):
	"""Show inline equipment editing popup"""
	# Create popup overlay
	var popup_overlay: ColorRect = ColorRect.new()
	popup_overlay.name = "EquipmentPopupOverlay"
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100

	# Get the root to add popup
	var root = get_tree().root
	root.add_child(popup_overlay)

	# Close when clicking overlay
	popup_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			popup_overlay.queue_free()
	)

	# Main popup panel
	var popup_panel: PanelContainer = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(500, 450)
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.position = Vector2(-250, -225)
	_style_panel(popup_panel)
	popup_overlay.add_child(popup_panel)

	# Stop clicks on panel from closing
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	popup_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header with god name and close button
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "EQUIPMENT: " + god.name.to_upper()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): popup_overlay.queue_free())
	_style_button(close_btn)
	header.add_child(close_btn)

	# Equipment slots section
	var slots_label: Label = Label.new()
	slots_label.text = "EQUIPPED ITEMS"
	slots_label.add_theme_font_size_override("font_size", 12)
	slots_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(slots_label)

	var slots_grid: GridContainer = GridContainer.new()
	slots_grid.columns = 3
	slots_grid.add_theme_constant_override("h_separation", 10)
	slots_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(slots_grid)

	# Create equipment slot UI (weapon, armor, accessory, etc.)
	var slot_types: Array = ["weapon", "armor", "helmet", "accessory", "ring", "artifact"]
	var equipment_manager = SystemRegistry.get_instance().get_system("EquipmentManager")
	var equipped_items: Dictionary = {}
	if equipment_manager and equipment_manager.has_method("get_equipped_items"):
		equipped_items = equipment_manager.get_equipped_items(god.id)
		if equipped_items == null:
			equipped_items = {}

	for slot_type in slot_types:
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(145, 60)
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
		slot_style.border_color = Color(0.3, 0.25, 0.4, 0.6)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		slots_grid.add_child(slot_panel)

		var slot_vbox: VBoxContainer = VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		slot_panel.add_child(slot_vbox)

		var slot_margin: MarginContainer = MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 8)
		slot_margin.add_theme_constant_override("margin_top", 5)
		slot_margin.add_child(slot_vbox)
		slot_panel.add_child(slot_margin)

		var slot_title: Label = Label.new()
		slot_title.text = slot_type.to_upper()
		slot_title.add_theme_font_size_override("font_size", 9)
		slot_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		slot_vbox.add_child(slot_title)

		var item_name: Label = Label.new()
		if equipped_items.has(slot_type) and equipped_items[slot_type] != null:
			var item = equipped_items[slot_type]
			item_name.text = item.name if item.has("name") else "Unknown"
			item_name.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
		else:
			item_name.text = "Empty"
			item_name.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		item_name.add_theme_font_size_override("font_size", 11)
		slot_vbox.add_child(item_name)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Inventory section
	var inv_label: Label = Label.new()
	inv_label.text = "INVENTORY"
	inv_label.add_theme_font_size_override("font_size", 12)
	inv_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(inv_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var inv_grid: GridContainer = GridContainer.new()
	inv_grid.columns = 4
	inv_grid.add_theme_constant_override("h_separation", 8)
	inv_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(inv_grid)

	# Get inventory items
	var inventory_manager = SystemRegistry.get_instance().get_system("InventoryManager")
	var equipment_items: Array = []
	if inventory_manager and inventory_manager.has_method("get_equipment_items"):
		equipment_items = inventory_manager.get_equipment_items()

	if equipment_items.is_empty():
		var no_items: Label = Label.new()
		no_items.text = "No equipment in inventory"
		no_items.add_theme_font_size_override("font_size", 11)
		no_items.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		inv_grid.add_child(no_items)
	else:
		for item in equipment_items.slice(0, 12):  # Show first 12
			var item_btn: Button = Button.new()
			item_btn.text = item.get("name", "Item")
			item_btn.custom_minimum_size = Vector2(100, 40)
			item_btn.add_theme_font_size_override("font_size", 10)
			item_btn.tooltip_text = "Click to equip"
			item_btn.pressed.connect(func():
				_equip_item_to_god(god, item)
				popup_overlay.queue_free()
				_show_equipment_popup(god)  # Refresh popup
			)
			_style_button(item_btn)
			inv_grid.add_child(item_btn)

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.4, 0.8, 0.4)
		"rare": return Color(0.4, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 0.9)
		"legendary": return Color(1.0, 0.8, 0.2)
		_: return Color(0.7, 0.7, 0.7)

func _equip_item_to_god(god: God, item: Dictionary):
	"""Equip an item to the god"""
	var equipment_manager = SystemRegistry.get_instance().get_system("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("equip_item"):
		equipment_manager.equip_item(god.id, item.get("id", ""), item.get("slot", "weapon"))
	_update_equipment_display()
	_update_team_stats()

# ============================================================================
# SORTING CONTROLS
# ============================================================================

func create_sorting_controls() -> HBoxContainer:
	"""Create sorting controls for the gods grid"""
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var sort_label: Label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	container.add_child(sort_label)

	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(100, 28)
	sort_dropdown.add_item("Power", SortType.POWER)
	sort_dropdown.add_item("Level", SortType.LEVEL)
	sort_dropdown.add_item("Tier", SortType.TIER)
	sort_dropdown.add_item("Element", SortType.ELEMENT)
	sort_dropdown.add_item("Name", SortType.NAME)
	sort_dropdown.selected = 0
	sort_dropdown.item_selected.connect(_on_sort_changed)
	container.add_child(sort_dropdown)

	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▼"
	sort_direction_btn.custom_minimum_size = Vector2(30, 28)
	sort_direction_btn.tooltip_text = "Toggle sort direction"
	sort_direction_btn.pressed.connect(_toggle_sort_direction)
	_style_button(sort_direction_btn)
	container.add_child(sort_direction_btn)

	return container

func _on_sort_changed(index: int):
	current_sort = index as SortType
	_refresh_gods_grid()

func _toggle_sort_direction():
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	_refresh_gods_grid()

func _sort_gods(gods: Array) -> Array:
	"""Sort gods based on current sort settings"""
	var sorted = gods.duplicate()

	match current_sort:
		SortType.POWER:
			sorted.sort_custom(func(a, b):
				var pa = TeamStatsCalculator.calculate_god_power(a)
				var pb = TeamStatsCalculator.calculate_god_power(b)
				return pa < pb if sort_ascending else pa > pb)
		SortType.LEVEL:
			sorted.sort_custom(func(a, b):
				return a.level < b.level if sort_ascending else a.level > b.level)
		SortType.TIER:
			sorted.sort_custom(func(a, b):
				return a.tier < b.tier if sort_ascending else a.tier > b.tier)
		SortType.ELEMENT:
			sorted.sort_custom(func(a, b):
				return a.element < b.element if sort_ascending else a.element > b.element)
		SortType.NAME:
			sorted.sort_custom(func(a, b):
				return a.name < b.name if sort_ascending else a.name > b.name)

	return sorted

# ============================================================================
# TEAM SLOT MANAGEMENT
# ============================================================================

func _create_team_slots():
	if not team_slots_container:
		return

	# Clear existing
	for child in team_slots_container.get_children():
		child.queue_free()

	team_slots.clear()
	selected_team.clear()

	for i in range(max_team_size):
		var slot = _create_team_slot(i)
		team_slots_container.add_child(slot)
		team_slots.append(slot)
		selected_team.append(null)

func _refresh_team_slots():
	for slot in team_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	team_slots.clear()
	selected_team.clear()
	_create_team_slots()
	_load_available_gods()
	_update_team_stats()

func _create_team_slot(index: int) -> Control:
	var slot: Panel = Panel.new()
	slot.name = "TeamSlot_" + str(index)
	slot.custom_minimum_size = Vector2(65, 85)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	style.border_color = Color(0.4, 0.35, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)

	var god_display: Control = Control.new()
	god_display.name = "GodDisplay"
	god_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(god_display)

	# Empty slot indicator
	var empty_label: Label = Label.new()
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_display.add_child(empty_label)

	# Make slot clickable to clear
	slot.gui_input.connect(_on_slot_clicked.bind(index))

	return slot

func _on_slot_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_team[index] != null:
			_clear_slot(index)

func _clear_slot(slot_index: int):
	selected_team[slot_index] = null
	_update_slot_display(slot_index)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _clear_team():
	for i in range(selected_team.size()):
		selected_team[i] = null
		_update_slot_display(i)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _update_slot_display(slot_index: int):
	if slot_index < 0 or slot_index >= team_slots.size():
		return

	var slot = team_slots[slot_index]
	if not slot or not is_instance_valid(slot):
		return

	var god_display = slot.get_node_or_null("VBoxContainer/GodDisplay")
	if not god_display:
		return

	for child in god_display.get_children():
		child.queue_free()

	var god = selected_team[slot_index]
	if god == null:
		var empty_label: Label = Label.new()
		empty_label.text = "+"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		god_display.add_child(empty_label)
	else:
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.setup_god_card(god)
		god_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		god_display.add_child(god_card)

# ============================================================================
# AVAILABLE GODS GRID
# ============================================================================

func _load_available_gods():
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager:
		return

	var all_gods = collection_manager.get_all_gods()

	available_gods.clear()
	unavailable_gods.clear()

	for god in all_gods:
		var assignment = _get_god_assignment(god)
		if assignment.is_empty():
			available_gods.append(god)
		else:
			unavailable_gods.append({"god": god, "assignment": assignment})

	_refresh_gods_grid()

func _refresh_gods_grid():
	if not available_gods_grid:
		return

	for child in available_gods_grid.get_children():
		child.queue_free()

	# Sort the available gods
	var sorted_gods = _sort_gods(available_gods)

	# Add available gods (filter out already selected)
	for god in sorted_gods:
		var already_selected: bool = false
		for selected in selected_team:
			if selected != null and selected.id == god.id:
				already_selected = true
				break

		if not already_selected:
			var card_container = _create_god_card_for_grid(god, "")
			available_gods_grid.add_child(card_container)

	# Add unavailable gods (greyed out with assignment info)
	var sorted_unavailable = unavailable_gods.duplicate()
	sorted_unavailable.sort_custom(func(a, b): return a.god.name < b.god.name)

	for entry in sorted_unavailable:
		var card_container = _create_god_card_for_grid(entry.god, entry.assignment)
		available_gods_grid.add_child(card_container)

func _create_god_card_for_grid(god: God, assignment: String = "") -> Control:
	var is_unavailable = not assignment.is_empty()

	var container: Panel = Panel.new()
	container.custom_minimum_size = Vector2(160, 200)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", style)

	var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
	god_card.setup_god_card(god)
	god_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_mouse_on_children(god_card)
	container.add_child(god_card)

	# Selection overlay (shown when selected)
	var selection_overlay: ColorRect = ColorRect.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_overlay.color = Color(0.2, 0.6, 0.2, 0.3)
	selection_overlay.visible = false
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(selection_overlay)

	# Unavailable overlay (greyed out with assignment info)
	if is_unavailable:
		var unavailable_overlay: ColorRect = ColorRect.new()
		unavailable_overlay.name = "UnavailableOverlay"
		unavailable_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		unavailable_overlay.color = Color(0.1, 0.1, 0.15, 0.7)
		unavailable_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(unavailable_overlay)

		# Assignment label at bottom
		var assignment_label: Label = Label.new()
		assignment_label.text = assignment
		assignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		assignment_label.add_theme_font_size_override("font_size", 10)
		assignment_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		assignment_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		assignment_label.offset_top = -25
		assignment_label.offset_bottom = -5
		assignment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(assignment_label)

		# Tooltip
		container.tooltip_text = god.name + " is assigned to " + assignment + "\nRemove from node to use in battle"
	else:
		# Make clickable only if available
		container.gui_input.connect(_on_god_card_clicked.bind(god, container))

	return container

func _on_god_card_clicked(event: InputEvent, god: God, container: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_god_selected(god)

func _on_god_selected(god: God):
	# Find first empty slot
	for i in range(selected_team.size()):
		if selected_team[i] == null:
			_assign_god_to_slot(god, i)
			break

func _assign_god_to_slot(god: God, slot_index: int):
	selected_team[slot_index] = god
	_update_slot_display(slot_index)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _is_god_available_for_battle(god: God) -> bool:
	return _get_god_assignment(god).is_empty()

func _get_god_assignment(god: God) -> String:
	"""Returns empty string if available, or description of where god is assigned"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return ""

	var controlled_nodes = territory_manager.get_controlled_nodes()
	for node in controlled_nodes:
		if node.garrison.find(god.id) != -1:
			return "Garrison: " + node.name
		if node.assigned_workers.find(god.id) != -1:
			return "Worker: " + node.name

	return ""

func _disable_mouse_on_children(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

# ============================================================================
# BUTTONS & ACTIONS
# ============================================================================

func _on_start_battle_pressed():
	var has_gods: bool = false
	for god in selected_team:
		if god != null:
			has_gods = true
			break

	if not has_gods:
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		if notification_manager:
			notification_manager.show_error("Please select at least one god for battle")
		return

	battle_start_requested.emit(selected_team)

func _on_cancel_pressed():
	setup_cancelled.emit()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _style_panel(panel: PanelContainer):
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false):
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_font_size_override("font_size", 11)

func _create_full_ui(parent: Control):
	"""Create complete UI layout when using initialize_full()"""
	# This creates a complete battle setup UI from scratch
	# Used when the parent scene doesn't have pre-built UI elements

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	parent.add_child(main_vbox)

	# Content area (hbox with stats panel and gods grid)
	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	# Left panel - stats
	var left_panel = create_stats_panel()
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_panel)

	# Right panel - gods grid
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(right_panel)
	content_hbox.add_child(right_panel)

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_panel.add_child(right_margin)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	# Header with sorting
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	right_vbox.add_child(header_row)

	var header: Label = Label.new()
	header.text = "SELECT GODS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var sorting = create_sorting_controls()
	header_row.add_child(sorting)

	# Scrollable gods grid
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	available_gods_grid = GridContainer.new()
	available_gods_grid.columns = 4
	available_gods_grid.add_theme_constant_override("h_separation", 10)
	available_gods_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(available_gods_grid)

	# Bottom buttons panel
	var buttons_panel: PanelContainer = PanelContainer.new()
	buttons_panel.custom_minimum_size = Vector2(0, 60)
	_style_panel(buttons_panel)
	main_vbox.add_child(buttons_panel)

	var buttons_margin: MarginContainer = MarginContainer.new()
	buttons_margin.add_theme_constant_override("margin_left", 20)
	buttons_margin.add_theme_constant_override("margin_right", 20)
	buttons_margin.add_theme_constant_override("margin_top", 10)
	buttons_margin.add_theme_constant_override("margin_bottom", 10)
	buttons_panel.add_child(buttons_margin)

	var buttons_hbox: HBoxContainer = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_margin.add_child(buttons_hbox)

	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.custom_minimum_size = Vector2(120, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_style_button(cancel_button, false)
	buttons_hbox.add_child(cancel_button)

	# Start Battle button
	start_battle_button = Button.new()
	start_battle_button.text = "START BATTLE"
	start_battle_button.custom_minimum_size = Vector2(160, 40)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	_style_button(start_battle_button, true)
	buttons_hbox.add_child(start_battle_button)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_selected_team() -> Array:
	return selected_team.duplicate()

func set_team(team: Array):
	"""Set the team externally (e.g., from saved state)"""
	selected_team = team.duplicate()
	selected_team.resize(max_team_size)
	for i in range(team_slots.size()):
		_update_slot_display(i)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)
