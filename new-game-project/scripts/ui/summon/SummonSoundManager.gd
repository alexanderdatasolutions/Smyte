# scripts/ui/summon/SummonSoundManager.gd
# RULE 1: UI helper - manages sound effects for summon system
# RULE 2: Single responsibility - audio playback only
class_name SummonSoundManager
extends Node

# Audio players for different sound categories
var button_player: AudioStreamPlayer
var portal_player: AudioStreamPlayer
var reveal_player: AudioStreamPlayer
var fanfare_player: AudioStreamPlayer

# Sound configuration - paths for future audio files
const SOUND_PATHS = {
	"button_click": "res://assets/audio/ui/button_click.wav",
	"portal_common": "res://assets/audio/summon/portal_common.wav",
	"portal_rare": "res://assets/audio/summon/portal_rare.wav",
	"portal_epic": "res://assets/audio/summon/portal_epic.wav",
	"portal_legendary": "res://assets/audio/summon/portal_legendary.wav",
	"reveal_common": "res://assets/audio/summon/reveal_common.wav",
	"reveal_rare": "res://assets/audio/summon/reveal_rare.wav",
	"reveal_epic": "res://assets/audio/summon/reveal_epic.wav",
	"reveal_legendary": "res://assets/audio/summon/reveal_legendary.wav",
	"fanfare_legendary": "res://assets/audio/summon/fanfare_legendary.wav"
}

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 1.0

# Sound enabled flag
var sounds_enabled: bool = true

func _ready():
	_setup_audio_players()

func _setup_audio_players():
	# Button click player
	button_player = AudioStreamPlayer.new()
	button_player.name = "ButtonPlayer"
	button_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(button_player)

	# Portal activation player
	portal_player = AudioStreamPlayer.new()
	portal_player.name = "PortalPlayer"
	portal_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(portal_player)

	# God reveal player
	reveal_player = AudioStreamPlayer.new()
	reveal_player.name = "RevealPlayer"
	reveal_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(reveal_player)

	# Fanfare player (for legendary)
	fanfare_player = AudioStreamPlayer.new()
	fanfare_player.name = "FanfarePlayer"
	fanfare_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(fanfare_player)

## Play button click sound
func play_button_click():
	if not sounds_enabled:
		return
	_play_sound(button_player, SOUND_PATHS.button_click, -5.0)

## Play portal activation sound based on rarity
func play_portal_sound(rarity: String):
	if not sounds_enabled:
		return
	var sound_key = "portal_" + rarity.to_lower()
	var sound_path = SOUND_PATHS.get(sound_key, SOUND_PATHS.portal_common)
	var volume = _get_volume_for_rarity(rarity)
	_play_sound(portal_player, sound_path, volume)

## Play god reveal sound based on rarity
func play_reveal_sound(rarity: String):
	if not sounds_enabled:
		return
	var sound_key = "reveal_" + rarity.to_lower()
	var sound_path = SOUND_PATHS.get(sound_key, SOUND_PATHS.reveal_common)
	var volume = _get_volume_for_rarity(rarity)
	_play_sound(reveal_player, sound_path, volume)

## Play legendary fanfare (extra celebration)
func play_legendary_fanfare():
	if not sounds_enabled:
		return
	_play_sound(fanfare_player, SOUND_PATHS.fanfare_legendary, 0.0)

func _get_volume_for_rarity(rarity: String) -> float:
	# Rarity-based volume (louder = more exciting)
	match rarity.to_lower():
		"legendary":
			return 0.0  # Full volume
		"epic":
			return -3.0
		"rare":
			return -6.0
		_:
			return -9.0  # Common is quieter

func _play_sound(player: AudioStreamPlayer, sound_path: String, volume_db: float):
	if not player:
		return

	# Check if audio file exists
	if ResourceLoader.exists(sound_path):
		var stream = load(sound_path)
		if stream:
			player.stream = stream
			player.volume_db = volume_db + (20.0 * log(sfx_volume * master_volume) / log(10.0)) if sfx_volume * master_volume > 0 else -80.0
			player.play()
	else:
		# Audio file not found - this is expected until audio assets are added
		# We can emit a debug signal or just silently continue
		pass

## Stop all sounds
func stop_all():
	if button_player and button_player.playing:
		button_player.stop()
	if portal_player and portal_player.playing:
		portal_player.stop()
	if reveal_player and reveal_player.playing:
		reveal_player.stop()
	if fanfare_player and fanfare_player.playing:
		fanfare_player.stop()

## Enable/disable sounds
func set_sounds_enabled(enabled: bool):
	sounds_enabled = enabled
	if not enabled:
		stop_all()

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float):
	master_volume = clampf(volume, 0.0, 1.0)

## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float):
	sfx_volume = clampf(volume, 0.0, 1.0)
