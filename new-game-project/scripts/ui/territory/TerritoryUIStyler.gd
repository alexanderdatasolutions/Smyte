class_name TerritoryUIStyler
extends Node

# Single responsibility: Create beautiful styled UI elements for territories
# Following prompt.prompt.md RULE 2: Single Responsibility

static func create_styled_territory_panel(territory) -> Panel:
	"""Create beautifully styled territory panel with tier-based colors"""
	var panel = Panel.new()
	
	# Tier-based styling
	var tier_colors = {
		1: Color(0.2, 0.3, 0.4, 0.95),  # Blue tint for tier 1
		2: Color(0.3, 0.2, 0.4, 0.95),  # Purple tint for tier 2  
		3: Color(0.4, 0.2, 0.2, 0.95)   # Red tint for tier 3
	}
	
	var style = StyleBoxFlat.new()
	style.bg_color = tier_colors.get(territory.get("tier", 1), tier_colors[1])
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2, 1)
	
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 200)
	
	return panel

static func create_section_box(title: String, content: Control, accent_color: Color, min_width: int = 200) -> Panel:
	"""Create styled section container with title and accent color"""
	var section = Panel.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_top = 2
	style.border_color = accent_color
	
	section.add_theme_stylebox_override("panel", style)
	section.custom_minimum_size = Vector2(min_width, 80)
	
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("margin_left", 8)
	container.add_theme_constant_override("margin_right", 8)
	container.add_theme_constant_override("margin_top", 4)
	container.add_theme_constant_override("margin_bottom", 8)
	
	# Title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", accent_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title_label)
	
	# Content
	container.add_child(content)
	section.add_child(container)
	
	return section

static func create_badge(text: String, color: Color) -> Panel:
	"""Create small colored badge"""
	var badge = Panel.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	badge.add_theme_stylebox_override("panel", style)
	badge.custom_minimum_size = Vector2(50, 20)
	
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	badge.add_child(label)
	return badge

static func create_progress_bar_styled(current: int, maximum: int, color: Color) -> Control:
	"""Create beautiful styled progress bar"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(150, 20)
	
	# Background
	var bg = Panel.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)
	
	# Progress fill
	var progress = Panel.new()
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = color
	progress_style.corner_radius_top_left = 10
	progress_style.corner_radius_top_right = 10
	progress_style.corner_radius_bottom_left = 10
	progress_style.corner_radius_bottom_right = 10
	progress.add_theme_stylebox_override("panel", progress_style)
	
	var progress_ratio = float(current) / float(maximum) if maximum > 0 else 0.0
	progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress.anchor_right = progress_ratio
	container.add_child(progress)
	
	# Progress text
	var label = Label.new()
	label.text = "%d/%d" % [current, maximum]
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(label)
	
	return container

static func create_header_style() -> StyleBox:
	"""Create styled header background"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2, 1)
	return style

static func get_element_color(element: String) -> Color:
	"""Get color for element types"""
	match element:
		"fire": return Color(1.0, 0.3, 0.2, 1)
		"water": return Color(0.2, 0.6, 1.0, 1)
		"earth": return Color(0.4, 0.8, 0.2, 1)
		"lightning": return Color(1.0, 1.0, 0.3, 1)
		"light": return Color(1.0, 1.0, 0.8, 1)
		"dark": return Color(0.6, 0.2, 0.8, 1)
		_: return Color(0.7, 0.7, 0.7, 1)

static func get_tier_accent_color(tier: int) -> Color:
	"""Get accent color for territory tiers"""
	match tier:
		1: return Color(0.4, 0.7, 1.0, 1)    # Blue for tier 1
		2: return Color(0.8, 0.4, 1.0, 1)    # Purple for tier 2
		3: return Color(1.0, 0.4, 0.4, 1)    # Red for tier 3
		_: return Color(0.7, 0.7, 0.7, 1)    # Gray fallback
