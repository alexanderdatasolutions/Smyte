# scripts/ui/screens/LeaderboardScreen.gd
# Global leaderboard display screen with category groups
extends Control
class_name LeaderboardScreen

# ==============================================================================
# COLORS (from UI_DESIGN_PATTERNS.md)
# ==============================================================================
const BG_COLOR := Color(0.08, 0.06, 0.12)
const PANEL_BG := Color(0.12, 0.1, 0.16, 0.95)
const PANEL_BORDER := Color(0.3, 0.25, 0.4, 0.8)
const TEXT_HEADER := Color(0.8, 0.8, 0.9)
const TEXT_NORMAL := Color(0.7, 0.7, 0.8)
const TEXT_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_GOLD := Color(1.0, 0.84, 0.0)
const COLOR_SILVER := Color(0.75, 0.75, 0.8)
const COLOR_BRONZE := Color(0.8, 0.5, 0.2)
const COLOR_SELF := Color(0.2, 0.35, 0.15, 0.6)
const COLOR_CATEGORY_BG := Color(0.1, 0.08, 0.14, 0.9)
const COLOR_CATEGORY_ACTIVE := Color(0.15, 0.2, 0.3, 0.95)

# Layout constants
const MARGIN := 20
const TOP_MARGIN := 60
const BOTTOM_MARGIN := 20
const HEADER_HEIGHT := 50
const SIDEBAR_WIDTH := 280
const SPACING := 10

# ==============================================================================
# CATEGORY DEFINITIONS - Organized groups for easy expansion
# ==============================================================================
const CATEGORY_GROUPS := {
	"collection": {
		"name": "📚 Collection",
		"metrics": [
			["total_power", "Total Power"],
			["highest_team_power", "Highest Team Power"],
			["highest_god_power", "Highest God Power"],
			["highest_god_level", "Highest God Level"],
			["gods_collected", "Gods Collected"],
			["unique_gods_collected", "Unique Gods"],
			["legendary_gods", "Legendary Gods"],
			["epic_gods", "Epic Gods"],
			["max_level_gods", "Max Level Gods"],
			["legendary_gods_obtained", "Legendary Summons (Total)"],
			["epic_gods_obtained", "Epic Summons (Total)"]
		]
	},
	"combat": {
		"name": "⚔️ Combat",
		"metrics": [
			["battles_won", "Battles Won"],
			["total_battles", "Total Battles"],
			["perfect_victories", "Perfect Victories"],
			["longest_win_streak", "Longest Win Streak"],
			["total_enemies_killed", "Enemies Killed"],
			["dungeons_cleared", "Dungeons Cleared"],
			["tower_best_floor", "Tower Best Floor"],
			["tower_floors_cleared", "Tower Floors Cleared"],
			["arena_elo", "Arena Rating"]
		]
	},
	"territory": {
		"name": "🏰 Territory",
		"metrics": [
			["territories_owned", "Territories Owned"],
			["territory_conquests", "Territory Conquests"],
			["buildings_placed", "Buildings Placed"],
			["total_building_levels", "Building Levels"],
			["highest_building_level", "Highest Building"]
		]
	},
	"economy": {
		"name": "💰 Economy",
		"metrics": [
			["equipment_crafted", "Equipment Crafted"],
			["total_summons", "Total Summons"],
			["legendary_summons", "Legendary Summons"],
			["epic_summons", "Epic Summons"],
			["gods_sacrificed", "Gods Sacrificed"],
			["gold_balance", "Gold Balance"],
			["mana_balance", "Mana Balance"],
			["crystals_balance", "Crystals Balance"]
		]
	}
}

# ==============================================================================
# STATE
# ==============================================================================
var _data_sync: LeaderboardDataSync = null
var _current_category: String = "total_power"
var _current_group: String = "collection"
var _expanded_groups: Dictionary = {"collection": true, "combat": true}

# UI References
var _metric_buttons: Dictionary = {}
var _group_containers: Dictionary = {}
var _list_container: VBoxContainer = null
var _loading_label: Label = null
var _rank_label: Label = null
var _score_label: Label = null
var _category_title: Label = null
var _ui_built: bool = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_data_sync()
	call_deferred("_ensure_ui_built")

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_update_header_for_screen()
		if _ui_built:
			call_deferred("_refresh_leaderboard")
		else:
			call_deferred("_ensure_ui_built")

func _update_header_for_screen() -> void:
	var main_ui: Node = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("GLOBAL LEADERBOARDS")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func _ensure_ui_built() -> void:
	if _ui_built:
		return
	await get_tree().process_frame
	if not _ui_built and is_inside_tree():
		_build_ui()
		_ui_built = true

func _setup_data_sync() -> void:
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		_data_sync = registry.get_system("LeaderboardDataSync")
	if not _data_sync:
		_data_sync = LeaderboardDataSync.new()
		add_child(_data_sync)
	if not _data_sync.leaderboard_fetched.is_connected(_on_leaderboard_fetched):
		_data_sync.leaderboard_fetched.connect(_on_leaderboard_fetched)

# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0:
		viewport_size = Vector2(1280, 720)

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = viewport_size

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Main content area (sidebar + leaderboard)
	# TOP_MARGIN accounts for MainUIOverlay's header
	var content_top := TOP_MARGIN + SPACING
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", SPACING)
	add_child(main_hbox)
	main_hbox.anchor_left = 0
	main_hbox.anchor_right = 1
	main_hbox.anchor_top = 0
	main_hbox.anchor_bottom = 1
	main_hbox.offset_left = MARGIN
	main_hbox.offset_right = -MARGIN
	main_hbox.offset_top = content_top
	main_hbox.offset_bottom = -BOTTOM_MARGIN

	# Left sidebar - category groups
	var sidebar := _create_sidebar()
	sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0)
	main_hbox.add_child(sidebar)

	# Right panel - leaderboard content
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", SPACING)
	main_hbox.add_child(content_vbox)

	# Content panel with list
	var content := _create_content_panel()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(content)

	# Footer - your rank
	var footer := _create_footer()
	content_vbox.add_child(footer)

	_refresh_leaderboard()

func _create_sidebar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Sidebar"
	_style_panel(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Create category groups
	for group_id in CATEGORY_GROUPS:
		var group_data: Dictionary = CATEGORY_GROUPS[group_id]
		var group_container := _create_category_group(group_id, group_data)
		vbox.add_child(group_container)
		_group_containers[group_id] = group_container

	return panel

func _create_category_group(group_id: String, group_data: Dictionary) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Group header (clickable to expand/collapse)
	var header_btn := Button.new()
	header_btn.text = group_data["name"]
	header_btn.custom_minimum_size = Vector2(0, 40)
	header_btn.pressed.connect(_on_group_toggled.bind(group_id))
	_style_group_header(header_btn, _expanded_groups.get(group_id, false))
	container.add_child(header_btn)

	# Metrics container (shown when expanded)
	var metrics_container := VBoxContainer.new()
	metrics_container.name = "Metrics"
	metrics_container.add_theme_constant_override("separation", 2)
	metrics_container.visible = _expanded_groups.get(group_id, false)
	container.add_child(metrics_container)

	# Add metric buttons
	var metrics: Array = group_data["metrics"]
	for metric_data in metrics:
		var metric_id: String = metric_data[0]
		var metric_name: String = metric_data[1]

		var btn := Button.new()
		btn.text = "  " + metric_name  # Indent for hierarchy
		btn.custom_minimum_size = Vector2(0, 35)
		btn.pressed.connect(_on_metric_selected.bind(metric_id, group_id))
		_style_metric_button(btn, metric_id == _current_category)
		metrics_container.add_child(btn)
		_metric_buttons[metric_id] = btn

	return container

func _create_content_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ContentPanel"
	_style_panel(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Category title
	_category_title = Label.new()
	_category_title.text = _get_metric_display_name(_current_category)
	_category_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_title.add_theme_font_size_override("font_size", 20)
	_category_title.add_theme_color_override("font_color", COLOR_GOLD)
	_category_title.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_category_title)

	# Column headers
	var headers := _create_column_headers()
	vbox.add_child(headers)

	# Separator
	var sep := ColorRect.new()
	sep.color = PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	_loading_label = Label.new()
	_loading_label.text = "Loading..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.add_theme_color_override("font_color", TEXT_MUTED)
	_loading_label.custom_minimum_size = Vector2(0, 100)
	list_vbox.add_child(_loading_label)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	list_vbox.add_child(_list_container)

	return panel

func _create_column_headers() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 35)

	var rank_lbl := Label.new()
	rank_lbl.text = "RANK"
	rank_lbl.custom_minimum_size = Vector2(80, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 13)
	rank_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	hbox.add_child(rank_lbl)

	var player_lbl := Label.new()
	player_lbl.text = "PLAYER"
	player_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_lbl.add_theme_font_size_override("font_size", 13)
	player_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	hbox.add_child(player_lbl)

	var score_lbl := Label.new()
	score_lbl.text = "SCORE"
	score_lbl.custom_minimum_size = Vector2(120, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 13)
	score_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	hbox.add_child(score_lbl)

	return hbox

func _create_footer() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "FooterPanel"
	panel.custom_minimum_size = Vector2(0, 55)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.1, 0.95)
	style.border_color = COLOR_GOLD * 0.6
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Your rank
	var rank_section := HBoxContainer.new()
	rank_section.add_theme_constant_override("separation", 8)
	hbox.add_child(rank_section)

	var rank_title := Label.new()
	rank_title.text = "YOUR RANK:"
	rank_title.add_theme_font_size_override("font_size", 14)
	rank_title.add_theme_color_override("font_color", TEXT_NORMAL)
	rank_section.add_child(rank_title)

	_rank_label = Label.new()
	_rank_label.text = "--"
	_rank_label.add_theme_font_size_override("font_size", 20)
	_rank_label.add_theme_color_override("font_color", COLOR_GOLD)
	rank_section.add_child(_rank_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Your score
	var score_section := HBoxContainer.new()
	score_section.add_theme_constant_override("separation", 8)
	hbox.add_child(score_section)

	var score_title := Label.new()
	score_title.text = "YOUR SCORE:"
	score_title.add_theme_font_size_override("font_size", 14)
	score_title.add_theme_color_override("font_color", TEXT_NORMAL)
	score_section.add_child(score_title)

	_score_label = Label.new()
	_score_label.text = "--"
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", COLOR_GOLD)
	score_section.add_child(_score_label)

	return panel

# ==============================================================================
# STYLING
# ==============================================================================

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _style_button(btn: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", TEXT_HEADER)

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

func _style_group_header(btn: Button, expanded: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CATEGORY_BG if not expanded else COLOR_CATEGORY_ACTIVE
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", TEXT_HEADER)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

func _style_metric_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.2, 0.3, 0.45, 0.95)
		style.border_color = COLOR_GOLD
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.08, 0.06, 0.1, 0.6)
		style.border_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 15
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", COLOR_GOLD if active else TEXT_NORMAL)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)

# ==============================================================================
# DATA & DISPLAY
# ==============================================================================

func _get_metric_display_name(metric_id: String) -> String:
	for group_id in CATEGORY_GROUPS:
		var metrics: Array = CATEGORY_GROUPS[group_id]["metrics"]
		for metric_data in metrics:
			if metric_data[0] == metric_id:
				return metric_data[1]
	return metric_id.capitalize()

func _refresh_leaderboard() -> void:
	if not _loading_label or not _data_sync:
		return
	_loading_label.visible = true
	_clear_list()
	if _category_title:
		_category_title.text = _get_metric_display_name(_current_category)
	_data_sync.fetch_leaderboard(_current_category, true)

func _on_leaderboard_fetched(category: String, entries: Array) -> void:
	if category != _current_category:
		return
	if _loading_label:
		_loading_label.visible = false
	_clear_list()
	_populate_list(entries)
	_update_footer(entries)

func _clear_list() -> void:
	if not _list_container:
		return
	for child in _list_container.get_children():
		child.queue_free()

func _populate_list(entries: Array) -> void:
	if not _list_container:
		return

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "No players ranked yet!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", TEXT_MUTED)
		empty.custom_minimum_size = Vector2(0, 100)
		_list_container.add_child(empty)
		return

	var user_id: String = _data_sync.get_user_id() if _data_sync else ""

	for entry: Dictionary in entries:
		var is_self: bool = entry.get("user_id", "") == user_id
		var row := _create_entry_row(entry, is_self)
		_list_container.add_child(row)

func _create_entry_row(entry: Dictionary, is_self: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 45)

	var rank: int = entry.get("rank", 0)

	var style := StyleBoxFlat.new()
	if is_self:
		style.bg_color = COLOR_SELF
	elif rank == 1:
		style.bg_color = Color(0.25, 0.22, 0.08, 0.4)
	elif rank == 2:
		style.bg_color = Color(0.18, 0.18, 0.2, 0.35)
	elif rank == 3:
		style.bg_color = Color(0.22, 0.14, 0.08, 0.35)
	elif rank % 2 == 0:
		style.bg_color = Color(0.08, 0.06, 0.1, 0.4)
	else:
		style.bg_color = Color(0.1, 0.08, 0.12, 0.3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Rank with medal
	var rank_box := HBoxContainer.new()
	rank_box.custom_minimum_size = Vector2(80, 0)
	rank_box.add_theme_constant_override("separation", 6)
	hbox.add_child(rank_box)

	var medal := Label.new()
	match rank:
		1: medal.text = "🥇"
		2: medal.text = "🥈"
		3: medal.text = "🥉"
		_: medal.text = ""
	medal.add_theme_font_size_override("font_size", 18)
	rank_box.add_child(medal)

	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.add_theme_font_size_override("font_size", 16)
	match rank:
		1: rank_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		2: rank_lbl.add_theme_color_override("font_color", COLOR_SILVER)
		3: rank_lbl.add_theme_color_override("font_color", COLOR_BRONZE)
		_: rank_lbl.add_theme_color_override("font_color", TEXT_NORMAL)
	rank_box.add_child(rank_lbl)

	# Player name
	var name_lbl := Label.new()
	var display_name: String = entry.get("display_name", "Player")
	if display_name.is_empty():
		display_name = "Player"
	if is_self:
		display_name += " (You)"
	name_lbl.text = display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", COLOR_GOLD if is_self else TEXT_HEADER)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(name_lbl)

	# Score
	var score_lbl := Label.new()
	score_lbl.text = _format_number(entry.get("value", 0))
	score_lbl.custom_minimum_size = Vector2(120, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	hbox.add_child(score_lbl)

	return panel

func _update_footer(entries: Array) -> void:
	if not _rank_label or not _score_label:
		return

	var user_id: String = _data_sync.get_user_id() if _data_sync else ""
	var found := false

	for entry: Dictionary in entries:
		if entry.get("user_id", "") == user_id:
			_rank_label.text = "#%d" % entry.get("rank", 0)
			_score_label.text = _format_number(entry.get("value", 0))
			found = true
			break

	if not found:
		_rank_label.text = "Unranked"
		_score_label.text = "--"

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_group_toggled(group_id: String) -> void:
	_expanded_groups[group_id] = not _expanded_groups.get(group_id, false)

	# Update visibility and styling
	var container: VBoxContainer = _group_containers.get(group_id)
	if container:
		var header_btn: Button = container.get_child(0)
		var metrics_container: VBoxContainer = container.get_node_or_null("Metrics")

		if header_btn:
			_style_group_header(header_btn, _expanded_groups[group_id])
		if metrics_container:
			metrics_container.visible = _expanded_groups[group_id]

func _on_metric_selected(metric_id: String, group_id: String) -> void:
	if metric_id == _current_category:
		return

	# Update button styles
	for mid in _metric_buttons:
		var btn: Button = _metric_buttons[mid]
		_style_metric_button(btn, mid == metric_id)

	_current_category = metric_id
	_current_group = group_id
	_refresh_leaderboard()

func _on_back_pressed() -> void:
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		var screen_manager: Variant = registry.get_system("ScreenManager")
		if screen_manager and screen_manager.has_method("go_back"):
			screen_manager.go_back()
			return
	visible = false
