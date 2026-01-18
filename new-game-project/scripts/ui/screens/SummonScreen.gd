# scripts/ui/SummonScreen.gd - Coordinator pattern with ResourceManager integration
extends Control

const _SummonShowcaseClass = preload("res://scripts/ui/summon/SummonShowcase.gd")
const _SummonBannerCardClass = preload("res://scripts/ui/summon/SummonBannerCard.gd")
const _SummonAnimationClass = preload("res://scripts/ui/summon/SummonAnimation.gd")
const _SummonResultOverlayClass = preload("res://scripts/ui/summon/SummonResultOverlay.gd")
const _SummonPopupHelperClass = preload("res://scripts/ui/summon/SummonPopupHelper.gd")
const _SummonHistoryPanelClass = preload("res://scripts/ui/summon/SummonHistoryPanel.gd")

signal back_pressed

@onready var summon_container = $MainContainer/LeftPanel/SummonContainer
@onready var back_button = $BackButton
@onready var showcase_content = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent
@onready var default_message = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent/DefaultMessage

var banner_cards: Array = []
var showcase: SummonShowcase
var summon_animation  # SummonAnimation
var result_overlay  # SummonResultOverlay
var history_panel  # SummonHistoryPanel
var history_button: Button
var selected_element: int = 0
var is_processing_summon: bool = false
var cards_initialized: bool = false
var animations_enabled: bool = true
var pending_summon_results: Array[God] = []
var current_banner_data: Dictionary = {}

func _ready():
	# Ensure fullscreen (needed when parent is Node2D)
	_setup_fullscreen()

	await get_tree().process_frame

	# Safety checks
	if not summon_container or not showcase_content or not default_message:
		return

	# Setup showcase grid
	_setup_showcase_grid()

	# Initialize showcase component
	if showcase_content is GridContainer:
		showcase = _SummonShowcaseClass.new(showcase_content)

	# Initialize summon animation overlay
	_setup_summon_animation()

	# Initialize result overlay
	_setup_result_overlay()

	# Initialize history panel
	_setup_history_panel()

	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_style_back_button()

	# Create history button next to back button
	_create_history_button()

func _notification(what):
	# When screen becomes visible, ensure cards are using new system
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if not cards_initialized and summon_container:
			_connect_summon_signals()
			_create_summon_cards()
			cards_initialized = true
		elif cards_initialized:
			# Refresh cards when returning to screen (resource state may have changed)
			_refresh_all_cards()

func _setup_fullscreen():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(get_viewport().get_visible_rect().size)
	position = Vector2.ZERO

func _setup_summon_animation():
	summon_animation = _SummonAnimationClass.new()
	summon_animation.name = "SummonAnimation"
	summon_animation.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(summon_animation)
	move_child(summon_animation, get_child_count() - 1)
	summon_animation.animation_completed.connect(_on_animation_completed)
	summon_animation.animation_skipped.connect(_on_animation_skipped)
	summon_animation.all_animations_completed.connect(_on_all_animations_completed)

func _setup_result_overlay():
	result_overlay = _SummonResultOverlayClass.new()
	result_overlay.name = "SummonResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(result_overlay)
	move_child(result_overlay, get_child_count() - 1)
	result_overlay.view_collection_pressed.connect(_on_view_collection_pressed)
	result_overlay.summon_again_pressed.connect(_on_summon_again_pressed)
	result_overlay.close_pressed.connect(_on_result_overlay_closed)

func _setup_history_panel():
	history_panel = _SummonHistoryPanelClass.new()
	history_panel.name = "SummonHistoryPanel"
	history_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(history_panel)
	move_child(history_panel, get_child_count() - 1)
	history_panel.close_pressed.connect(_on_history_panel_closed)

func _create_history_button():
	history_button = Button.new()
	history_button.text = "History"
	history_button.position = Vector2(107, 650)
	history_button.size = Vector2(80, 40)
	history_button.pressed.connect(_on_history_button_pressed)
	add_child(history_button)
	_style_history_button()

func _style_history_button():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style.border_color = Color(0.5, 0.4, 0.6, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	history_button.add_theme_stylebox_override("normal", style)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.18, 0.28, 0.98)
	hover.border_color = Color(0.6, 0.5, 0.7, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	history_button.add_theme_stylebox_override("hover", hover)
	history_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	history_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

func _style_back_button():
	if not back_button: return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	_connect_summon_signals()
	_create_summon_cards()
	cards_initialized = true

func _setup_showcase_grid():
	if not showcase_content or showcase_content is GridContainer: return
	var showcase_parent = showcase_content.get_parent()
	if not showcase_parent: return
	var showcase_pos = showcase_content.get_index()
	var showcase_name = showcase_content.name
	var existing_children = []
	for child in showcase_content.get_children():
		existing_children.append(child)
		showcase_content.remove_child(child)
	showcase_content.queue_free()
	var grid = GridContainer.new()
	grid.name = showcase_name
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for child in existing_children: grid.add_child(child)
	showcase_parent.add_child(grid)
	showcase_parent.move_child(grid, showcase_pos)
	showcase_content = grid

func _connect_summon_signals():
	var sm = SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null
	if not sm: return
	if sm.summon_completed.is_connected(_on_god_summoned): sm.summon_completed.disconnect(_on_god_summoned)
	if sm.summon_failed.is_connected(_on_summon_failed): sm.summon_failed.disconnect(_on_summon_failed)
	if sm.multi_summon_completed.is_connected(_on_multi_summon_completed): sm.multi_summon_completed.disconnect(_on_multi_summon_completed)
	sm.summon_completed.connect(_on_god_summoned)
	sm.summon_failed.connect(_on_summon_failed)
	sm.multi_summon_completed.connect(_on_multi_summon_completed)
	_connect_resource_signals()

func _connect_resource_signals():
	var rm = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not rm: return
	if rm.resource_changed.is_connected(_on_resource_changed): rm.resource_changed.disconnect(_on_resource_changed)
	if rm.resource_insufficient.is_connected(_on_resource_insufficient): rm.resource_insufficient.disconnect(_on_resource_insufficient)
	rm.resource_changed.connect(_on_resource_changed)
	rm.resource_insufficient.connect(_on_resource_insufficient)

func _create_summon_cards():
	if not summon_container: return
	if not summon_container is GridContainer: _convert_summon_container_to_grid()
	for child in summon_container.get_children(): child.queue_free()
	banner_cards.clear()
	for banner in _get_banner_configs():
		var card = _SummonBannerCardClass.new()
		card.configure(banner)
		card.set_accent_color(banner.get("color", Color.WHITE))
		card.single_summon_pressed.connect(_on_banner_single_summon.bind(banner))
		card.multi_summon_pressed.connect(_on_banner_multi_summon.bind(banner))
		summon_container.add_child(card)
		banner_cards.append(card)

func _get_banner_configs() -> Array:
	var summon_mgr = _get_summon_system()
	var config = summon_mgr.get_config() if summon_mgr else {}
	var rates_cfg = config.get("summon_configuration", {}).get("rates", {})

	return [
		{
			"id": "basic",
			"title": "BASIC SUMMON",
			"description": "Common Soul Summon\nStandard rates for all gods",
			"banner_type": "default",
			"single_cost": {"common_soul": 1},
			"multi_cost": {"common_soul": 9},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("soul_based_rates", {}).get("common_soul", {"common": 70, "rare": 25, "epic": 4.5, "legendary": 0.5}),
			"color": Color.CYAN,
			"summon_type": "common_soul"
		},
		{
			"id": "premium",
			"title": "PREMIUM SUMMON",
			"description": "Divine Crystal Summon\nHigher legendary rates!",
			"banner_type": "premium",
			"single_cost": {"divine_crystals": 100},
			"multi_cost": {"divine_crystals": 900},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("premium_rates", {}).get("divine_crystals", {"common": 35, "rare": 40, "epic": 20, "legendary": 5}),
			"color": Color.GOLD,
			"summon_type": "divine_crystals"
		},
		{
			"id": "element",
			"title": "ELEMENT SUMMON",
			"description": "Element Soul Summon\n3x weight for matching element",
			"banner_type": "element",
			"single_cost": {"fire_soul": 1},
			"multi_cost": {"fire_soul": 9},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("element_soul_rates", {}).get("fire_soul", {"common": 50, "rare": 35, "epic": 13, "legendary": 2}),
			"color": Color.ORANGE_RED,
			"summon_type": "fire_soul"
		},
		{
			"id": "daily_free",
			"title": "DAILY FREE",
			"description": "One free summon per day\nBasic rates, no cost!",
			"banner_type": "default",
			"single_cost": {},
			"multi_cost": {},
			"multi_count": 0,
			"rates": rates_cfg.get("soul_based_rates", {}).get("common_soul", {"common": 70, "rare": 25, "epic": 4.5, "legendary": 0.5}),
			"color": Color.GREEN,
			"summon_type": "daily_free",
			"is_daily_free": true
		}
	]

func _convert_summon_container_to_grid():
	var parent = summon_container.get_parent()
	if not parent: return
	var pos = summon_container.get_index()
	summon_container.queue_free()
	var grid = GridContainer.new()
	grid.name = "SummonContainer"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	parent.add_child(grid)
	parent.move_child(grid, pos)
	summon_container = grid

func _on_banner_single_summon(_banner_data: Dictionary, banner: Dictionary):
	var ss = _get_summon_system()
	if not ss: _show_error_message("Summon system not available"); return
	_set_cards_enabled(false)
	is_processing_summon = true
	current_banner_data = banner
	pending_summon_results.clear()
	if ss.has_method("clear_duplicate_tracking"): ss.clear_duplicate_tracking()
	var success = false
	if banner.get("is_daily_free", false): success = ss.summon_free_daily()
	elif banner.summon_type == "divine_crystals": success = ss.summon_premium()
	else: success = ss.summon_with_soul(banner.summon_type)
	if not success: _set_cards_enabled(true)

func _on_banner_multi_summon(_banner_data: Dictionary, banner: Dictionary):
	var ss = _get_summon_system()
	if not ss: _show_error_message("Summon system not available"); return
	if banner.multi_count <= 0: _show_error_message("Multi-summon not available"); return
	_set_cards_enabled(false)
	is_processing_summon = true
	current_banner_data = banner
	pending_summon_results.clear()
	if ss.has_method("clear_duplicate_tracking"): ss.clear_duplicate_tracking()
	var success = false
	if banner.summon_type == "divine_crystals": success = ss.multi_summon_premium(banner.multi_count)
	elif ss.has_method("summon_multi_with_soul"): success = ss.summon_multi_with_soul(banner.summon_type, banner.multi_count)
	else:
		for i in range(banner.multi_count):
			success = ss.summon_with_soul(banner.summon_type)
			if not success: break
	if not success: _set_cards_enabled(true)

func _on_back_pressed(): back_pressed.emit()

func _on_god_summoned(god):
	if animations_enabled and summon_animation: summon_animation.queue_summon(god)
	else: _show_god_in_showcase(god); _set_cards_enabled(true); _refresh_all_cards()

func _on_multi_summon_completed(gods: Array):
	if animations_enabled and summon_animation: summon_animation.queue_multi_summon(gods)
	else:
		for god in gods: _show_god_in_showcase(god)
		_set_cards_enabled(true); _refresh_all_cards()

func _on_summon_failed(reason):
	_show_error_message(reason); _set_cards_enabled(true); _refresh_all_cards()

func _on_duplicate_obtained(_god, _existing_count: int): pass

func _on_resource_changed(_resource_id: String, _new_amount: int, _delta: int):
	_refresh_all_cards(); _update_resource_display()

func _on_resource_insufficient(resource_id: String, required: int, available: int):
	var dn = _SummonPopupHelperClass.get_resource_display_name(resource_id)
	_SummonPopupHelperClass.show_insufficient_resources(self, "Not enough %s! Need %d, have %d" % [dn, required, available], resource_id)

func _update_resource_display():
	var rd = get_node_or_null("ResourceDisplay")
	if rd and rd.has_method("_update_this_instance"): rd._update_this_instance()

func _on_animation_completed(god):
	_show_god_in_showcase(god); pending_summon_results.append(god)

func _on_animation_skipped(god):
	_show_god_in_showcase(god); pending_summon_results.append(god)

func _on_all_animations_completed():
	_set_cards_enabled(true); _refresh_all_cards()
	if pending_summon_results.size() > 0 and result_overlay:
		result_overlay.show_results(pending_summon_results, current_banner_data)

func _show_god_in_showcase(god: God):
	if showcase:
		_clear_showcase_invisible_nodes()
		if default_message: default_message.visible = false
		showcase.show_god(god, false)

func _on_view_collection_pressed():
	var sm = SystemRegistry.get_instance().get_system("ScreenManager") if SystemRegistry.get_instance() else null
	if sm and sm.has_method("change_screen"): sm.change_screen("collection")

func _on_summon_again_pressed():
	if current_banner_data.is_empty(): return
	if pending_summon_results.size() > 1: _on_banner_multi_summon(current_banner_data, current_banner_data)
	else: _on_banner_single_summon(current_banner_data, current_banner_data)

func _on_result_overlay_closed(): _refresh_all_cards()
func _on_history_button_pressed():
	if history_panel: history_panel.show_panel()
func _on_history_panel_closed(): pass

func _get_summon_system():
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _set_cards_enabled(enabled: bool):
	for card in banner_cards:
		if card and card.has_method("refresh") and enabled: card.refresh()

func _show_error_message(message: String):
	if not default_message: return
	default_message.visible = true
	default_message.text = message
	default_message.add_theme_color_override("font_color", Color.ORANGE_RED)
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func():
		if default_message:
			default_message.visible = false
			default_message.text = "Select a summon type to begin"
			default_message.remove_theme_color_override("font_color"))

func _clear_showcase_invisible_nodes():
	if showcase: showcase.clear_invisible_nodes()

func _refresh_all_cards():
	for card in banner_cards:
		if card and card.has_method("refresh"): card.refresh()
