# scripts/ui/summon/SummonAnimation.gd
# RULE 1: UI component - handles summon animation sequence display
# RULE 2: Single responsibility - only animation/visual feedback
class_name SummonAnimation
extends Control

signal animation_completed(god: God)
signal animation_skipped(god: God)
signal all_animations_completed()

# Preload sound manager
const _SummonSoundManagerClass = preload("res://scripts/ui/summon/SummonSoundManager.gd")

# Animation states
enum AnimState { IDLE, PORTAL_GLOW, RARITY_REVEAL, GOD_REVEAL, COMPLETE }

# UI Components
var portal_ring: Control
var portal_glow: ColorRect
var rarity_burst: ColorRect
var god_portrait_container: Control
var god_portrait: TextureRect
var god_name_label: Label
var god_tier_label: Label
var god_stats_label: Label
var skip_button: Button
var backdrop: ColorRect
var particle_container: Control
var sound_manager  # SummonSoundManager

# Animation state
var current_state: AnimState = AnimState.IDLE
var current_god: God = null
var animation_queue: Array[God] = []
var is_animating: bool = false
var skip_requested: bool = false
var original_position: Vector2 = Vector2.ZERO

# Timing constants (seconds)
const PORTAL_GLOW_DURATION: float = 0.8
const RARITY_REVEAL_DURATION: float = 0.6
const GOD_REVEAL_DURATION: float = 0.7
const DISPLAY_DURATION: float = 1.5

# Particle and shake settings
const LEGENDARY_PARTICLE_COUNT: int = 24
const EPIC_PARTICLE_COUNT: int = 12
const SHAKE_DURATION: float = 0.4
const SHAKE_INTENSITY: float = 8.0

# Rarity colors
const RARITY_COLORS: Dictionary = {
	"common": Color(0.85, 0.85, 0.85, 1.0),      # White/gray
	"rare": Color(0.3, 0.5, 1.0, 1.0),            # Blue
	"epic": Color(0.6, 0.2, 0.8, 1.0),            # Purple
	"legendary": Color(1.0, 0.84, 0.0, 1.0)       # Gold
}

func _ready():
	_setup_ui()
	_setup_sound_manager()
	visible = false

func _setup_sound_manager():
	sound_manager = _SummonSoundManagerClass.new()
	sound_manager.name = "SummonSoundManager"
	add_child(sound_manager)

func _setup_ui():
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.85)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center_container = Control.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_CENTER)
	center_container.custom_minimum_size = Vector2(400, 500)
	center_container.position = Vector2(-200, -250)
	add_child(center_container)

	portal_ring = _create_portal_ring()
	portal_ring.position = Vector2(100, 100)
	center_container.add_child(portal_ring)

	portal_glow = _create_color_rect("PortalGlow", Vector2(180, 180), Vector2(110, 110), Color(0.5, 0.4, 0.8, 0.0))
	center_container.add_child(portal_glow)

	rarity_burst = _create_color_rect("RarityBurst", Vector2(300, 300), Vector2(50, 50), Color(1.0, 1.0, 1.0, 0.0))
	center_container.add_child(rarity_burst)

	god_portrait_container = Control.new()
	god_portrait_container.name = "GodPortraitContainer"
	god_portrait_container.custom_minimum_size = Vector2(200, 200)
	god_portrait_container.position = Vector2(100, 80)
	god_portrait_container.modulate.a = 0.0
	center_container.add_child(god_portrait_container)

	god_portrait = TextureRect.new()
	god_portrait.name = "GodPortrait"
	god_portrait.custom_minimum_size = Vector2(180, 180)
	god_portrait.size = Vector2(180, 180)
	god_portrait.position = Vector2(10, 10)
	god_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	god_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_portrait_container.add_child(god_portrait)

	# God name label
	god_name_label = Label.new()
	god_name_label.name = "GodName"
	god_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_name_label.position = Vector2(50, 320)
	god_name_label.custom_minimum_size = Vector2(300, 40)
	god_name_label.add_theme_font_size_override("font_size", 24)
	god_name_label.add_theme_color_override("font_color", Color.WHITE)
	god_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	god_name_label.add_theme_constant_override("outline_size", 3)
	god_name_label.modulate.a = 0.0
	center_container.add_child(god_name_label)

	# God tier label
	god_tier_label = Label.new()
	god_tier_label.name = "GodTier"
	god_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_tier_label.position = Vector2(50, 365)
	god_tier_label.custom_minimum_size = Vector2(300, 30)
	god_tier_label.add_theme_font_size_override("font_size", 16)
	god_tier_label.add_theme_color_override("font_outline_color", Color.BLACK)
	god_tier_label.add_theme_constant_override("outline_size", 2)
	god_tier_label.modulate.a = 0.0
	center_container.add_child(god_tier_label)

	# God stats label
	god_stats_label = Label.new()
	god_stats_label.name = "GodStats"
	god_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_stats_label.position = Vector2(50, 400)
	god_stats_label.custom_minimum_size = Vector2(300, 30)
	god_stats_label.add_theme_font_size_override("font_size", 12)
	god_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	god_stats_label.modulate.a = 0.0
	center_container.add_child(god_stats_label)

	# Skip button
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip >"
	skip_button.custom_minimum_size = Vector2(100, 40)
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position = Vector2(-120, -60)
	skip_button.pressed.connect(_on_skip_pressed)
	_style_skip_button()
	add_child(skip_button)

	# Make click anywhere skip
	backdrop.gui_input.connect(_on_backdrop_input)

	# Particle container for legendary effects
	particle_container = Control.new()
	particle_container.name = "ParticleContainer"
	particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particle_container)

func _create_color_rect(rect_name: String, rect_size: Vector2, rect_pos: Vector2, rect_color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.name = rect_name
	rect.custom_minimum_size = rect_size
	rect.size = rect_size
	rect.position = rect_pos
	rect.color = rect_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _create_portal_ring() -> Control:
	var ring = Control.new()
	ring.name = "PortalRing"
	ring.custom_minimum_size = Vector2(200, 200)

	# Create ring visuals using ColorRects as segments
	var ring_color = Color(0.6, 0.5, 0.9, 0.8)
	var ring_radius = 90  # Distance from center
	var segments = 32

	for i in range(segments):
		var angle = (i * TAU) / segments
		var segment = ColorRect.new()
		segment.custom_minimum_size = Vector2(8, 20)
		segment.size = Vector2(8, 20)
		segment.color = ring_color
		segment.position = Vector2(
			100 + cos(angle) * ring_radius - 4,
			100 + sin(angle) * ring_radius - 10
		)
		segment.rotation = angle + PI/2
		segment.pivot_offset = Vector2(4, 10)
		ring.add_child(segment)

	return ring

func _style_skip_button():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.25, 0.9)
	style.border_color = Color(0.5, 0.45, 0.6, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	skip_button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.3, 0.25, 0.35, 0.95)
	hover.border_color = Color(0.6, 0.55, 0.7, 1.0)
	skip_button.add_theme_stylebox_override("hover", hover)

	skip_button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	skip_button.add_theme_font_size_override("font_size", 14)

## Queue a god for animated reveal
func queue_summon(god: God):
	animation_queue.append(god)
	if not is_animating:
		_process_next_animation()

## Queue multiple gods for animated reveal (10-pull)
func queue_multi_summon(gods: Array):
	for god in gods:
		if god is God:
			animation_queue.append(god)
	if not is_animating:
		_process_next_animation()

## Play animation for a single god immediately
func play_summon_animation(god: God):
	queue_summon(god)

func _process_next_animation():
	if animation_queue.is_empty():
		is_animating = false
		visible = false
		all_animations_completed.emit()
		return

	is_animating = true
	skip_requested = false
	current_god = animation_queue.pop_front()
	visible = true

	_reset_animation_state()
	_start_portal_glow()

func _reset_animation_state():
	current_state = AnimState.IDLE
	portal_glow.color.a = 0.0
	rarity_burst.color.a = 0.0
	god_portrait_container.modulate.a = 0.0
	god_portrait_container.scale = Vector2(0.5, 0.5)
	god_name_label.modulate.a = 0.0
	god_tier_label.modulate.a = 0.0
	god_stats_label.modulate.a = 0.0

	# Reset portal ring rotation
	if portal_ring:
		portal_ring.rotation = 0.0

func _start_portal_glow():
	current_state = AnimState.PORTAL_GLOW

	var tier_string = God.tier_to_string(current_god.tier).to_lower()
	var glow_color = RARITY_COLORS.get(tier_string, RARITY_COLORS.common)

	# Play portal activation sound
	if sound_manager:
		sound_manager.play_portal_sound(tier_string)

	# Animate portal ring spinning (set_loops on Tween, not PropertyTweener)
	var ring_tween = create_tween()
	ring_tween.set_loops(0)  # Infinite loops
	ring_tween.tween_property(portal_ring, "rotation", TAU, PORTAL_GLOW_DURATION * 2)

	# Animate portal glow
	var tween = create_tween()
	tween.set_parallel(true)

	# Pulse the glow
	portal_glow.color = glow_color
	portal_glow.color.a = 0.0
	tween.tween_property(portal_glow, "color:a", 0.8, PORTAL_GLOW_DURATION * 0.5)
	tween.tween_property(portal_glow, "scale", Vector2(1.2, 1.2), PORTAL_GLOW_DURATION).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_ELASTIC)

	tween.chain().tween_callback(_start_rarity_reveal)

func _start_rarity_reveal():
	if skip_requested:
		_skip_to_end()
		return

	current_state = AnimState.RARITY_REVEAL

	var tier_string = God.tier_to_string(current_god.tier).to_lower()
	var burst_color = RARITY_COLORS.get(tier_string, RARITY_COLORS.common)

	# Spawn particles for epic/legendary
	if tier_string == "legendary":
		_spawn_particles(burst_color, LEGENDARY_PARTICLE_COUNT)
		_apply_screen_shake()
		if sound_manager:
			sound_manager.play_legendary_fanfare()
	elif tier_string == "epic":
		_spawn_particles(burst_color, EPIC_PARTICLE_COUNT)

	# Flash burst effect
	rarity_burst.color = burst_color
	rarity_burst.color.a = 0.0
	rarity_burst.scale = Vector2(0.5, 0.5)
	rarity_burst.pivot_offset = rarity_burst.size / 2

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(rarity_burst, "color:a", 1.0, RARITY_REVEAL_DURATION * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(rarity_burst, "scale", Vector2(1.5, 1.5), RARITY_REVEAL_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	tween.chain().tween_property(rarity_burst, "color:a", 0.0, RARITY_REVEAL_DURATION * 0.3)
	tween.chain().tween_callback(_start_god_reveal)

func _start_god_reveal():
	if skip_requested:
		_skip_to_end()
		return

	current_state = AnimState.GOD_REVEAL

	# Play reveal sound
	var tier_string = God.tier_to_string(current_god.tier).to_lower()
	if sound_manager:
		sound_manager.play_reveal_sound(tier_string)

	# Setup god info
	_setup_god_display()

	# Animate portrait
	god_portrait_container.pivot_offset = Vector2(100, 100)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(god_portrait_container, "modulate:a", 1.0, GOD_REVEAL_DURATION * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(god_portrait_container, "scale", Vector2(1.0, 1.0), GOD_REVEAL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Staggered text reveals
	tween.chain().tween_property(god_name_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(god_tier_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(god_stats_label, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC)

	# Display timer
	tween.chain().tween_interval(DISPLAY_DURATION)
	tween.chain().tween_callback(_complete_animation)

func _setup_god_display():
	# Load portrait if available
	var sprite_path = "res://assets/gods/" + current_god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		god_portrait.texture = load(sprite_path)
	else:
		god_portrait.texture = null

	# Set god name
	god_name_label.text = current_god.name

	# Set tier and element
	var tier_string = God.tier_to_string(current_god.tier).to_upper()
	var element_string = God.element_to_string(current_god.element).to_upper()
	god_tier_label.text = tier_string + " " + element_string
	god_tier_label.add_theme_color_override("font_color", RARITY_COLORS.get(tier_string.to_lower(), Color.WHITE))

	# Set stats
	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator") if SystemRegistry.get_instance() else null
	var hp: int
	var atk: int
	var def: int
	var spd: int
	if stat_calc:
		var stats = stat_calc.calculate_god_total_stats(current_god)
		hp = stats.hp
		atk = stats.attack
		def = stats.defense
		spd = stats.speed
	else:
		hp = current_god.base_hp
		atk = current_god.base_attack
		def = current_god.base_defense
		spd = current_god.base_speed
	god_stats_label.text = "HP: %d | ATK: %d | DEF: %d | SPD: %d" % [hp, atk, def, spd]

func _complete_animation():
	current_state = AnimState.COMPLETE
	animation_completed.emit(current_god)

	# Small delay before next animation
	await get_tree().create_timer(0.2).timeout
	_process_next_animation()

func _skip_to_end():
	# Immediately show the god without remaining animations
	_setup_god_display()
	god_portrait_container.modulate.a = 1.0
	god_portrait_container.scale = Vector2(1.0, 1.0)
	god_name_label.modulate.a = 1.0
	god_tier_label.modulate.a = 1.0
	god_stats_label.modulate.a = 1.0
	portal_glow.color.a = 0.0
	rarity_burst.color.a = 0.0

	animation_skipped.emit(current_god)

	# Brief display before next
	await get_tree().create_timer(0.5).timeout
	_process_next_animation()

func _on_skip_pressed():
	skip_requested = true
	if current_state != AnimState.COMPLETE and current_state != AnimState.IDLE:
		_skip_to_end()

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_skip_pressed()

## Skip all remaining animations
func skip_all():
	animation_queue.clear()
	skip_requested = true
	if current_state != AnimState.IDLE:
		_skip_to_end()

## Check if animations are in progress
func is_playing() -> bool:
	return is_animating

## Get count of queued animations
func get_queue_count() -> int:
	return animation_queue.size()

## Spawn celebration particles for epic/legendary summons
func _spawn_particles(color: Color, count: int):
	if not particle_container:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size / 2

	for i in range(count):
		var particle = ColorRect.new()
		particle.custom_minimum_size = Vector2(8, 8)
		particle.size = Vector2(8, 8)
		particle.color = color

		# Start from center
		particle.position = center - Vector2(4, 4)

		# Random direction
		var angle = randf() * TAU
		var speed = randf_range(300.0, 600.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * speed

		particle_container.add_child(particle)

		# Animate particle flying outward and fading
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", center + target_offset, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 1.2).set_delay(0.3)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 1.2)

		# Cleanup after animation
		tween.chain().tween_callback(particle.queue_free)

## Apply screen shake effect for legendary reveals
func _apply_screen_shake():
	original_position = position
	var shake_tween = create_tween()

	# Multiple shake iterations
	var iterations = 8
	for i in range(iterations):
		var intensity = SHAKE_INTENSITY * (1.0 - float(i) / iterations)
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(self, "position", original_position + offset, SHAKE_DURATION / iterations)

	# Return to original position
	shake_tween.tween_property(self, "position", original_position, 0.05)

## Clear all particles
func _clear_particles():
	if particle_container:
		for child in particle_container.get_children():
			child.queue_free()
