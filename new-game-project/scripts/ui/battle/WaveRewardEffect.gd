# scripts/ui/battle/WaveRewardEffect.gd
# RULE 2: Single responsibility - Wave clear reward particle effects only
# RULE 4: No logic in UI - Display-only effects
class_name WaveRewardEffect
extends Control

"""
WaveRewardEffect - Displays animated resource particles when a wave is completed.
Mana orbs and crystal sparkles fly toward the resource display in the UI.
"""

# Particle configuration
const PARTICLE_COUNT_MANA := 5
const PARTICLE_COUNT_CRYSTAL := 3
const PARTICLE_SIZE := 12.0
const PARTICLE_FLIGHT_TIME := 0.8
const PARTICLE_SPAWN_SPREAD := 100.0
const PARTICLE_STAGGER_DELAY := 0.05

# Colors for particle types
const MANA_COLOR := Color(0.4, 0.6, 1.0, 1.0)  # Blue
const CRYSTAL_COLOR := Color(0.9, 0.5, 0.9, 1.0)  # Purple/pink

# Effect complete signal
signal effect_completed()

# Internal state
var _active_particles: Array = []
var _particles_remaining: int = 0
var _target_position: Vector2 = Vector2.ZERO

func _ready():
	# Start hidden
	visible = false

func play_wave_reward(spawn_position: Vector2, target_pos: Vector2, mana_count: int = 5, crystal_count: int = 3):
	"""
	Play the wave reward particle effect.
	spawn_position: Where particles originate (center of battle area)
	target_pos: Where particles fly to (resource display position)
	mana_count: Number of mana orb particles
	crystal_count: Number of crystal particles
	"""
	_target_position = target_pos
	_particles_remaining = mana_count + crystal_count

	visible = true

	# Spawn mana particles
	for i in range(mana_count):
		var offset = Vector2(
			randf_range(-PARTICLE_SPAWN_SPREAD, PARTICLE_SPAWN_SPREAD),
			randf_range(-PARTICLE_SPAWN_SPREAD, PARTICLE_SPAWN_SPREAD)
		)
		var start_pos = spawn_position + offset
		_spawn_particle(start_pos, target_pos, MANA_COLOR, "mana", i * PARTICLE_STAGGER_DELAY)

	# Spawn crystal particles (slightly delayed after mana)
	var crystal_delay = mana_count * PARTICLE_STAGGER_DELAY + 0.1
	for i in range(crystal_count):
		var offset = Vector2(
			randf_range(-PARTICLE_SPAWN_SPREAD, PARTICLE_SPAWN_SPREAD),
			randf_range(-PARTICLE_SPAWN_SPREAD, PARTICLE_SPAWN_SPREAD)
		)
		var start_pos = spawn_position + offset
		_spawn_particle(start_pos, target_pos + Vector2(50, 0), CRYSTAL_COLOR, "crystal", crystal_delay + i * PARTICLE_STAGGER_DELAY)

func _spawn_particle(start_pos: Vector2, end_pos: Vector2, color: Color, type: String, delay: float):
	"""Create and animate a single particle"""
	var particle = _create_particle_node(color, type)
	add_child(particle)
	_active_particles.append(particle)

	# Set initial position and scale
	particle.position = start_pos
	particle.scale = Vector2(0.3, 0.3)
	particle.modulate = Color(color.r, color.g, color.b, 0.0)

	# Create animation tween
	var tween = create_tween()

	# Delay start
	if delay > 0:
		tween.tween_interval(delay)

	# Fade in and scale up quickly
	tween.set_parallel(true)
	tween.tween_property(particle, "modulate:a", 1.0, 0.15)
	tween.tween_property(particle, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Calculate curved path using bezier-like movement
	var mid_point = _calculate_arc_midpoint(start_pos, end_pos)

	# Arc movement phase
	tween.chain()
	tween.set_parallel(true)

	# Move to midpoint with easing
	tween.tween_property(particle, "position", mid_point, PARTICLE_FLIGHT_TIME * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Continue to target
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(particle, "position", end_pos, PARTICLE_FLIGHT_TIME * 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Scale down and fade out at the end
	tween.tween_property(particle, "scale", Vector2(0.5, 0.5), PARTICLE_FLIGHT_TIME * 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(particle, "modulate:a", 0.0, PARTICLE_FLIGHT_TIME * 0.3).set_delay(PARTICLE_FLIGHT_TIME * 0.3)

	# Cleanup when done
	tween.chain()
	tween.tween_callback(_on_particle_completed.bind(particle))

func _calculate_arc_midpoint(start: Vector2, end: Vector2) -> Vector2:
	"""Calculate a midpoint for curved particle path"""
	var mid = (start + end) / 2.0
	var direction = (end - start).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)

	# Arc upward (negative Y in Godot)
	var arc_height = randf_range(50.0, 100.0)
	return mid + perpendicular * arc_height * sign(randf_range(-1.0, 1.0)) + Vector2(0, -arc_height)

func _create_particle_node(color: Color, type: String) -> Control:
	"""Create a visual particle node"""
	var container = Control.new()
	container.name = "Particle_" + type

	# Main particle shape (glowing circle)
	var particle = ColorRect.new()
	particle.size = Vector2(PARTICLE_SIZE, PARTICLE_SIZE)
	particle.position = Vector2(-PARTICLE_SIZE / 2, -PARTICLE_SIZE / 2)
	particle.color = color

	# Create rounded corners (simulate circle)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(PARTICLE_SIZE / 2)
	style.corner_radius_top_right = int(PARTICLE_SIZE / 2)
	style.corner_radius_bottom_left = int(PARTICLE_SIZE / 2)
	style.corner_radius_bottom_right = int(PARTICLE_SIZE / 2)
	particle.add_theme_stylebox_override("panel", style)

	container.add_child(particle)

	# Add glow effect (larger faded circle behind)
	var glow = ColorRect.new()
	var glow_size = PARTICLE_SIZE * 2.0
	glow.size = Vector2(glow_size, glow_size)
	glow.position = Vector2(-glow_size / 2, -glow_size / 2)
	glow.color = Color(color.r, color.g, color.b, 0.3)

	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color(color.r, color.g, color.b, 0.3)
	glow_style.corner_radius_top_left = int(glow_size / 2)
	glow_style.corner_radius_top_right = int(glow_size / 2)
	glow_style.corner_radius_bottom_left = int(glow_size / 2)
	glow_style.corner_radius_bottom_right = int(glow_size / 2)
	glow.add_theme_stylebox_override("panel", glow_style)

	container.add_child(glow)
	glow.z_index = -1  # Behind the main particle

	# Add symbol for type identification
	var symbol = Label.new()
	symbol.text = "+" if type == "mana" else "*"
	symbol.add_theme_font_size_override("font_size", 10)
	symbol.add_theme_color_override("font_color", Color.WHITE)
	symbol.position = Vector2(-4, -8)
	container.add_child(symbol)

	return container

func _on_particle_completed(particle: Control):
	"""Handle particle animation completion"""
	if particle and is_instance_valid(particle):
		_active_particles.erase(particle)
		particle.queue_free()

	_particles_remaining -= 1

	if _particles_remaining <= 0:
		_finish_effect()

func _finish_effect():
	"""Complete the effect and clean up"""
	visible = false
	_active_particles.clear()
	effect_completed.emit()

func stop():
	"""Force stop all particles"""
	for particle in _active_particles:
		if particle and is_instance_valid(particle):
			particle.queue_free()
	_active_particles.clear()
	_particles_remaining = 0
	visible = false
