class_name TerritoryCardBuilder
extends Node

# Single responsibility: Build enhanced territory cards with magical design
# Following prompt.prompt.md RULE 2: Single Responsibility

const TerritoryUIStyler = preload("res://scripts/ui/territory/TerritoryUIStyler.gd")

static func create_enhanced_territory_card(territory_id: String, territory_data: Dictionary) -> Control:
	"""Create FULL-FEATURED territory card matching old_territory_role_screen.gd functionality"""
	
	# Main card container with enhanced styling
	var card_panel = _create_enhanced_card_panel(territory_data)
	
	# Main vertical layout with proper margins
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	card_panel.add_child(margin_container)
	margin_container.add_child(main_vbox)
	
	# HEADER ROW - Territory name, tier, element, status badges
	var header_row = _create_enhanced_territory_header(territory_id, territory_data)
	main_vbox.add_child(header_row)
	
	# STAGE PROGRESS - Visual progress bar with stage indicators
	var progress_section = _create_stage_progress_with_indicators(territory_data)
	main_vbox.add_child(progress_section)
	
	# MAIN CONTENT SECTIONS - 4 detailed sections side by side
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 12)
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)
	
	# 1. RESOURCE PRODUCTION SECTION - Detailed production rates
	var production_content = _create_detailed_resource_production(territory_data)
	var production_box = TerritoryUIStyler.create_section_box("📊 Resources", production_content, Color(0.2, 0.7, 0.9, 1), 240)
	content_hbox.add_child(production_box)
	
	# 2. GOD ROLE ASSIGNMENTS SECTION - Detailed god assignments
	var roles_content = _create_detailed_role_assignments(territory_data)
	var roles_box = TerritoryUIStyler.create_section_box("⚔️ Gods", roles_content, Color(0.8, 0.4, 0.9, 1), 220)
	content_hbox.add_child(roles_box)
	
	# 3. COMBAT & FARMING SECTION - Stage selection and combat
	var combat_content = _create_combat_farming_section(territory_data)
	var combat_box = TerritoryUIStyler.create_section_box("⚔️ Combat", combat_content, Color(0.9, 0.6, 0.2, 1), 200)
	content_hbox.add_child(combat_box)
	
	# 4. UPGRADES & POWER SECTION - Territory upgrades
	var upgrade_content = _create_upgrade_power_section(territory_data)
	var upgrade_box = TerritoryUIStyler.create_section_box("⬆️ Upgrades", upgrade_content, Color(0.2, 0.9, 0.4, 1), 200)
	content_hbox.add_child(upgrade_box)
	
	return card_panel

static func _create_enhanced_card_panel(territory_data: Dictionary) -> Panel:
	"""Create enhanced card panel with tier-based styling and status effects"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 320)  # Larger for detailed content
	
	var tier = territory_data.get("tier", 1)
	var territory_id = territory_data.get("id", "")
	
	# Check territory status
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var is_controlled = false
	var current_stage = 0
	var max_stages = territory_data.get("stages", 10)
	
	if territory_manager:
		if territory_manager.has_method("is_territory_controlled"):
			is_controlled = territory_manager.is_territory_controlled(territory_id)
		if territory_manager.has_method("get_territory_stage"):
			current_stage = territory_manager.get_territory_stage(territory_id)
	
	var style = StyleBoxFlat.new()
	
	# Base color based on tier
	match tier:
		1: style.bg_color = Color(0.15, 0.2, 0.25, 0.95)   # Blue tint
		2: style.bg_color = Color(0.2, 0.15, 0.25, 0.95)   # Purple tint  
		3: style.bg_color = Color(0.25, 0.15, 0.15, 0.95)  # Red tint
		_: style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	
	# Border based on control status with enhanced effects
	style.border_width_left = 3
	style.border_width_top = 2
	style.border_width_right = 3
	style.border_width_bottom = 2
	
	if is_controlled:
		style.border_color = Color(0.2, 0.8, 0.2, 1)  # Green for controlled
		style.shadow_color = Color(0.2, 0.8, 0.2, 0.3)  # Green glow
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 0)
	elif current_stage >= max_stages:
		style.border_color = Color(0.8, 0.8, 0.2, 1)  # Yellow for cleared
	elif current_stage > 0:
		style.border_color = Color(0.8, 0.4, 0.2, 1)  # Orange for in progress
	else:
		style.border_color = Color(0.4, 0.4, 0.5, 1)  # Gray for locked
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func _create_enhanced_territory_header(territory_id: String, territory_data: Dictionary) -> Control:
	"""Create enhanced territory header with name, tier, element, status badges"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	
	# Territory icon based on element
	var icon_label = Label.new()
	icon_label.text = _get_element_icon(territory_data.get("element", "neutral"))
	icon_label.add_theme_font_size_override("font_size", 24)
	header.add_child(icon_label)
	
	# Name and tier container
	var name_container = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = territory_data.get("name", territory_id.capitalize().replace("_", " "))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_container.add_child(name_label)
	
	var tier_label = Label.new()
	var tier = territory_data.get("tier", 1)
	var element = territory_data.get("element", "neutral")
	tier_label.text = "Tier %d • %s" % [tier, element.capitalize()]
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color.GRAY)
	name_container.add_child(tier_label)
	
	header.add_child(name_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Status badges
	var badges = HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	
	var territory_id_clean = territory_data.get("id", territory_id)
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var is_controlled = false
	var current_stage = 0
	var max_stages = territory_data.get("stages", 10)
	
	if territory_manager:
		if territory_manager.has_method("is_territory_controlled"):
			is_controlled = territory_manager.is_territory_controlled(territory_id_clean)
		if territory_manager.has_method("get_territory_stage"):
			current_stage = territory_manager.get_territory_stage(territory_id_clean)
	
	if is_controlled:
		badges.add_child(_create_badge("CONTROLLED", Color.GREEN))
	elif current_stage >= max_stages:
		badges.add_child(_create_badge("READY TO CLAIM", Color.YELLOW))
	elif current_stage > 0:
		badges.add_child(_create_badge("IN PROGRESS", Color.ORANGE))
	else:
		badges.add_child(_create_badge("AVAILABLE", Color.GRAY))
	
	header.add_child(badges)
	return header

static func _create_stage_progress_with_indicators(territory_data: Dictionary) -> Control:
	"""Create enhanced stage progress with visual indicators and selectors"""
	var progress_container = VBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 4)
	
	var territory_id = territory_data.get("id", "")
	var max_stages = territory_data.get("stages", 10)
	var current_stage = 0
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("get_territory_stage"):
		current_stage = territory_manager.get_territory_stage(territory_id)
	
	# Progress label
	var progress_label = Label.new()
	progress_label.text = "Stage Progress: %d/%d" % [current_stage, max_stages]
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_container.add_child(progress_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.max_value = max_stages
	progress_bar.value = current_stage
	progress_bar.show_percentage = false
	
	# Style the progress bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.1, 0.1, 0.1, 1)
	bar_style.corner_radius_top_left = 3
	bar_style.corner_radius_top_right = 3
	bar_style.corner_radius_bottom_right = 3
	bar_style.corner_radius_bottom_left = 3
	progress_bar.add_theme_stylebox_override("background", bar_style)
	
	var fill_style = StyleBoxFlat.new()
	if current_stage >= max_stages:
		fill_style.bg_color = Color(0.2, 0.8, 0.2, 1)  # Green when complete
	else:
		fill_style.bg_color = Color(0.8, 0.4, 0.2, 1)  # Orange in progress
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_right = 3
	fill_style.corner_radius_bottom_left = 3
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	progress_container.add_child(progress_bar)
	
	# Stage indicators (dots)
	var stage_indicators = HBoxContainer.new()
	stage_indicators.add_theme_constant_override("separation", 2)
	
	for i in range(max_stages):
		var indicator = _create_stage_indicator(i + 1, i < current_stage, i + 1 == max_stages)
		stage_indicators.add_child(indicator)
	
	progress_container.add_child(stage_indicators)
	return progress_container

static func _create_stage_indicator(_stage_num: int, is_complete: bool, is_boss: bool) -> Panel:
	"""Create individual stage indicator dot"""
	var indicator = Panel.new()
	indicator.custom_minimum_size = Vector2(8, 8)
	
	var style = StyleBoxFlat.new()
	if is_complete:
		style.bg_color = Color.GREEN if not is_boss else Color.GOLD
	else:
		style.bg_color = Color(0.3, 0.3, 0.3, 1)
	
	if is_boss:
		# Make boss indicator larger
		indicator.custom_minimum_size = Vector2(12, 12)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
	else:
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
	
	indicator.add_theme_stylebox_override("panel", style)
	return indicator

static func _create_detailed_resource_production(territory_data: Dictionary) -> Control:
	"""Create detailed resource production section with hourly rates"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 3)
	
	var territory_id = territory_data.get("id", "")
	var is_controlled = false
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_controlled = territory_manager.is_territory_controlled(territory_id)
	
	if is_controlled:
		# Show actual production with god bonuses
		var tier = territory_data.get("tier", 1)
		var base_mana = tier * 1000
		var base_crystals = tier * 5
		
		# Add resource lines with proper formatting
		var mana_line = _create_enhanced_resource_line("⚡", "Mana", base_mana, Color.CYAN)
		section.add_child(mana_line)
		
		var crystal_line = _create_enhanced_resource_line("💎", "Crystals", base_crystals, Color.MAGENTA)
		section.add_child(crystal_line)
		
		var materials_line = _create_enhanced_resource_line("🔧", "Materials", tier * 10, Color.GREEN)
		section.add_child(materials_line)
		
		# Production efficiency indicator
		var efficiency_label = Label.new()
		efficiency_label.text = "Efficiency: 100%"  # TODO: Calculate based on god bonuses
		efficiency_label.add_theme_font_size_override("font_size", 8)
		efficiency_label.add_theme_color_override("font_color", Color.YELLOW)
		section.add_child(efficiency_label)
	else:
		# Show potential production
		var potential_label = Label.new()
		potential_label.text = "Potential Production:"
		potential_label.add_theme_font_size_override("font_size", 9)
		potential_label.add_theme_color_override("font_color", Color.GRAY)
		section.add_child(potential_label)
		
		var tier = territory_data.get("tier", 1)
		var potential_mana = _create_enhanced_resource_line("⚡", "Mana", tier * 1000, Color(0.5, 0.7, 0.9, 1))
		section.add_child(potential_mana)
		
		var unlock_hint = Label.new()
		unlock_hint.text = "Capture to unlock!"
		unlock_hint.add_theme_font_size_override("font_size", 8)
		unlock_hint.add_theme_color_override("font_color", Color.ORANGE)
		section.add_child(unlock_hint)
	
	return section

static func _create_detailed_role_assignments(territory_data: Dictionary) -> Control:
	"""Create detailed god role assignments section"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	
	var territory_id = territory_data.get("id", "")
	var is_controlled = false
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_controlled = territory_manager.is_territory_controlled(territory_id)
	
	if is_controlled:
		# Show role assignments with god details
		var roles = [
			{"name": "Defender", "icon": "🛡️", "color": Color.RED},
			{"name": "Gatherer", "icon": "⛏️", "color": Color.GREEN}, 
			{"name": "Crafter", "icon": "🔨", "color": Color.BLUE}
		]
		
		for role_data in roles:
			var role_line = _create_detailed_role_line(role_data, territory_data)
			section.add_child(role_line)
		
		# Management button
		var manage_btn = Button.new()
		manage_btn.text = "👥 Manage Roles"
		manage_btn.add_theme_font_size_override("font_size", 9)
		manage_btn.custom_minimum_size = Vector2(0, 20)
		section.add_child(manage_btn)
	else:
		var unlock_label = Label.new()
		unlock_label.text = "Capture territory to\nassign gods to roles"
		unlock_label.add_theme_font_size_override("font_size", 9)
		unlock_label.add_theme_color_override("font_color", Color.GRAY)
		unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_child(unlock_label)
	
	return section

static func _create_detailed_role_line(role_data: Dictionary, _territory_data: Dictionary) -> HBoxContainer:
	"""Create detailed role assignment line with god info"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	
	var icon_label = Label.new()
	icon_label.text = role_data.get("icon", "")
	icon_label.add_theme_font_size_override("font_size", 10)
	line.add_child(icon_label)
	
	var role_label = Label.new()
	role_label.text = role_data.get("name", "")
	role_label.add_theme_font_size_override("font_size", 9)
	role_label.custom_minimum_size.x = 50
	line.add_child(role_label)
	
	var assigned_label = Label.new()
	assigned_label.text = "0/1"  # TODO: Get actual assignments
	assigned_label.add_theme_font_size_override("font_size", 9)
	assigned_label.add_theme_color_override("font_color", role_data.get("color", Color.WHITE))
	line.add_child(assigned_label)
	
	return line

static func _create_combat_farming_section(territory_data: Dictionary) -> Control:
	"""Create combat and farming section with stage selection"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	
	var territory_id = territory_data.get("id", "")
	var current_stage = 0
	var max_stages = territory_data.get("stages", 10)
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("get_territory_stage"):
		current_stage = territory_manager.get_territory_stage(territory_id)
	
	# Stage selector
	var stage_selector = HBoxContainer.new()
	stage_selector.add_theme_constant_override("separation", 3)
	
	var prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(20, 20)
	prev_btn.add_theme_font_size_override("font_size", 8)
	stage_selector.add_child(prev_btn)
	
	var stage_label = Label.new()
	var selected_stage = min(current_stage + 1, max_stages)  # Next stage to attack
	stage_label.text = "Stage %d" % selected_stage
	stage_label.add_theme_font_size_override("font_size", 10)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_selector.add_child(stage_label)
	
	var next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(20, 20)
	next_btn.add_theme_font_size_override("font_size", 8)
	stage_selector.add_child(next_btn)
	
	section.add_child(stage_selector)
	
	# Power requirement
	var power_req = _calculate_power_requirement(territory_data, selected_stage)
	var power_label = Label.new()
	power_label.text = "Power: %d" % power_req
	power_label.add_theme_font_size_override("font_size", 9)
	power_label.add_theme_color_override("font_color", Color.ORANGE)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(power_label)
	
	# Attack button
	var attack_btn = Button.new()
	if current_stage >= max_stages:
		attack_btn.text = "⚔️ Farm"
		attack_btn.modulate = Color.GREEN
	else:
		attack_btn.text = "⚔️ Attack"
		attack_btn.modulate = Color.RED
	
	attack_btn.add_theme_font_size_override("font_size", 10)
	attack_btn.custom_minimum_size = Vector2(0, 25)
	section.add_child(attack_btn)
	
	return section

static func _create_upgrade_power_section(territory_data: Dictionary) -> Control:
	"""Create upgrades and power section"""
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	
	var territory_id = territory_data.get("id", "")
	var is_controlled = false
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_controlled = territory_manager.is_territory_controlled(territory_id)
	
	if is_controlled:
		# Show upgrade options
		var upgrades_label = Label.new()
		upgrades_label.text = "Territory Upgrades:"
		upgrades_label.add_theme_font_size_override("font_size", 9)
		upgrades_label.add_theme_color_override("font_color", Color.YELLOW)
		section.add_child(upgrades_label)
		
		# Production boost upgrade
		var prod_upgrade = _create_upgrade_line("📈 Production", "Lv 0", Color.GREEN)
		section.add_child(prod_upgrade)
		
		# Defense upgrade
		var def_upgrade = _create_upgrade_line("🛡️ Defense", "Lv 0", Color.RED)
		section.add_child(def_upgrade)
		
		# Capacity upgrade
		var cap_upgrade = _create_upgrade_line("📦 Capacity", "Lv 0", Color.BLUE)
		section.add_child(cap_upgrade)
	else:
		# Show power requirements
		var power_req_label = Label.new()
		power_req_label.text = "Power Requirements:"
		power_req_label.add_theme_font_size_override("font_size", 9)
		power_req_label.add_theme_color_override("font_color", Color.GRAY)
		section.add_child(power_req_label)
		
		var tier = territory_data.get("tier", 1)
		var req_power = tier * 1000
		var power_line = Label.new()
		power_line.text = "⚡ %d Power" % req_power
		power_line.add_theme_font_size_override("font_size", 9)
		power_line.add_theme_color_override("font_color", Color.ORANGE)
		section.add_child(power_line)
	
	return section

static func _create_upgrade_line(upgrade_name: String, level: String, color: Color) -> HBoxContainer:
	"""Create upgrade line display"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	
	var name_label = Label.new()
	name_label.text = upgrade_name
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = level
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.add_theme_color_override("font_color", color)
	line.add_child(level_label)
	
	return line

# UTILITY METHODS

static func _get_element_icon(element: String) -> String:
	"""Get icon for element type"""
	match element.to_lower():
		"fire": return "🔥"
		"water": return "💧"
		"earth": return "🌍"
		"lightning": return "⚡"
		"light": return "✨"
		"dark": return "🌙"
		_: return "🔮"

static func _create_badge(text: String, color: Color) -> Panel:
	"""Create styled badge panel"""
	var badge_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	badge_panel.add_theme_stylebox_override("panel", style)
	badge_panel.custom_minimum_size = Vector2(80, 20)
	
	var badge_label = Label.new()
	badge_label.text = text
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.add_theme_color_override("font_color", color)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	badge_panel.add_child(badge_label)
	
	return badge_panel

static func _calculate_power_requirement(territory_data: Dictionary, stage: int) -> int:
	"""Calculate power requirement for territory stage"""
	var base_power = territory_data.get("tier", 1) * 1000
	var stage_multiplier = 1.0 + (stage * 0.2)
	return int(base_power * stage_multiplier)

# Update the resource line method to match new signature
static func _create_enhanced_resource_line(icon: String, resource_name: String, amount: int, color: Color) -> HBoxContainer:
	"""Create enhanced resource display line with name and hourly rate"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 9)
	line.add_child(icon_label)
	
	var name_label = Label.new()
	name_label.text = resource_name
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.custom_minimum_size = Vector2(60, 0)
	line.add_child(name_label)
	
	var amount_label = Label.new()
	amount_label.text = "+%s/hr" % _format_number(amount)
	amount_label.add_theme_font_size_override("font_size", 8)
	amount_label.add_theme_color_override("font_color", color)
	line.add_child(amount_label)
	
	return line

static func _format_number(num: int) -> String:
	"""Format large numbers for display"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

static func _create_territory_header(territory_id: String, territory_data: Dictionary) -> Control:
	"""Create territory header with name, tier, element badges"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	
	# Territory name
	var name_label = Label.new()
	name_label.text = territory_data.get("name", territory_id.capitalize().replace("_", " "))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(name_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Element badge
	var element = territory_data.get("element", "neutral")
	var element_color = TerritoryUIStyler.get_element_color(element)
	var element_badge = TerritoryUIStyler.create_badge(element.capitalize(), element_color)
	header.add_child(element_badge)
	
	# Tier badge
	var tier = territory_data.get("tier", 1)
	var tier_color = TerritoryUIStyler.get_tier_accent_color(tier)
	var tier_badge = TerritoryUIStyler.create_badge("T%d" % tier, tier_color)
	header.add_child(tier_badge)
	
	return header

static func _create_stage_progress_section(territory_data: Dictionary) -> Control:
	"""Create stage progress section with visual progress bar"""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	
	# Get progress from TerritoryManager via SystemRegistry
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var current_stage = 0
	var max_stages = territory_data.get("stages", 10)
	
	if territory_manager and territory_manager.has_method("get_territory_stage"):
		current_stage = territory_manager.get_territory_stage(territory_data.get("id", ""))
	
	# Stage progress bar
	var stage_color = Color(0.3, 0.8, 0.3, 1) if current_stage >= max_stages else Color(0.8, 0.6, 0.2, 1)
	var progress_bar = TerritoryUIStyler.create_progress_bar_styled(current_stage, max_stages, stage_color)
	content.add_child(progress_bar)
	
	# Status text
	var status_text = Label.new()
	if current_stage >= max_stages:
		status_text.text = "🏆 CAPTURED"
		status_text.add_theme_color_override("font_color", Color.GREEN)
	elif current_stage > 0:
		status_text.text = "⚔️ Stage %d/%d" % [current_stage, max_stages]
		status_text.add_theme_color_override("font_color", Color.YELLOW)
	else:
		status_text.text = "🔒 Not Started"
		status_text.add_theme_color_override("font_color", Color.GRAY)
	
	status_text.add_theme_font_size_override("font_size", 10)
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_text)
	
	return TerritoryUIStyler.create_section_box("Progress", content, Color(0.8, 0.6, 0.2, 1), 120)

static func _create_production_section(territory_data: Dictionary) -> Control:
	"""Create resource production section with rates"""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	
	# Get production from TerritoryProductionManager
	var production_manager = SystemRegistry.get_instance().get_system("TerritoryProductionManager") 
	var territory_id = territory_data.get("id", "")
	var is_captured = false
	
	# Check if territory is captured
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_captured = territory_manager.is_territory_controlled(territory_id)
	
	if is_captured and production_manager:
		# Show actual production rates
		var base_rate = territory_data.get("tier", 1) * 1000
		var mana_line = _create_resource_line("⚡", base_rate, Color.CYAN)
		content.add_child(mana_line)
		
		var crystal_rate = territory_data.get("tier", 1) * 5
		var crystal_line = _create_resource_line("💎", crystal_rate, Color.MAGENTA)
		content.add_child(crystal_line)
	else:
		# Show potential production
		var potential_label = Label.new()
		potential_label.text = "Capture to unlock\nproduction!"
		potential_label.add_theme_font_size_override("font_size", 9)
		potential_label.add_theme_color_override("font_color", Color.GRAY)
		potential_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(potential_label)
	
	return TerritoryUIStyler.create_section_box("Production", content, Color(0.2, 0.8, 0.2, 1), 100)

static func _create_resource_line(icon: String, amount: int, color: Color) -> HBoxContainer:
	"""Create resource display line with icon and amount"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 10)
	line.add_child(icon_label)
	
	var amount_label = Label.new()
	amount_label.text = str(amount) + "/hr"
	amount_label.add_theme_font_size_override("font_size", 9)
	amount_label.add_theme_color_override("font_color", color)
	line.add_child(amount_label)
	
	return line

static func _create_roles_section(territory_data: Dictionary) -> Control:
	"""Create god role assignments section"""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	
	var territory_id = territory_data.get("id", "")
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	
	# Check if territory is captured to show roles
	var is_captured = false
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_captured = territory_manager.is_territory_controlled(territory_id)
	
	if is_captured:
		# Show role slots with assignments
		var roles = ["Defender", "Gatherer", "Crafter"]
		for role in roles:
			var role_line = _create_role_line(role, territory_data)
			content.add_child(role_line)
	else:
		var unlock_label = Label.new()
		unlock_label.text = "Capture territory\nto assign gods"
		unlock_label.add_theme_font_size_override("font_size", 9)
		unlock_label.add_theme_color_override("font_color", Color.GRAY)
		unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(unlock_label)
	
	return TerritoryUIStyler.create_section_box("God Roles", content, Color(0.6, 0.2, 0.8, 1), 120)

static func _create_role_line(role: String, _territory_data: Dictionary) -> HBoxContainer:
	"""Create role assignment line"""
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	
	var role_label = Label.new()
	role_label.text = role + ":"
	role_label.add_theme_font_size_override("font_size", 9)
	role_label.custom_minimum_size.x = 60
	line.add_child(role_label)
	
	var assigned_label = Label.new()
	assigned_label.text = "0/1"  # TODO: Get actual assignments from TerritoryManager
	assigned_label.add_theme_font_size_override("font_size", 9)
	assigned_label.add_theme_color_override("font_color", Color.YELLOW)
	line.add_child(assigned_label)
	
	return line

static func _create_action_buttons(territory_id: String, _territory_data: Dictionary) -> Control:
	"""Create action buttons for territory"""
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 5)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Check territory status
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var is_captured = false
	if territory_manager and territory_manager.has_method("is_territory_controlled"):
		is_captured = territory_manager.is_territory_controlled(territory_id)
	
	if is_captured:
		# Collect resources button
		var collect_btn = Button.new()
		collect_btn.text = "💰 Collect"
		collect_btn.add_theme_font_size_override("font_size", 10)
		collect_btn.custom_minimum_size = Vector2(70, 25)
		button_row.add_child(collect_btn)
		
		# Manage roles button
		var manage_btn = Button.new()
		manage_btn.text = "👥 Manage"
		manage_btn.add_theme_font_size_override("font_size", 10)
		manage_btn.custom_minimum_size = Vector2(70, 25)
		button_row.add_child(manage_btn)
	else:
		# Attack/Continue button
		var attack_btn = Button.new()
		attack_btn.text = "⚔️ Attack"
		attack_btn.add_theme_font_size_override("font_size", 10)
		attack_btn.custom_minimum_size = Vector2(80, 25)
		
		# Style attack button
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.8, 0.2, 0.2, 0.9)
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		attack_btn.add_theme_stylebox_override("normal", btn_style)
		
		button_row.add_child(attack_btn)
	
	return button_row
