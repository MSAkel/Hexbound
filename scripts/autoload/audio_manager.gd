extends Node

# Audio bus indices matching default_bus_layout (Master, Music, SFX).
const MUSIC_BUS = 1
const SFX_BUS = 2

# Audio players
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8

var current_music: AudioStream
var music_volume: float = 0.20
var sfx_volume: float = 0.35

# Crossfade settings
const CROSSFADE_DURATION = 1.0
var crossfade_tween: Tween
var _crossfade_generation: int = 0
# Per-player fade tweens so a reused SFX slot can cancel an in-flight fade.
var _sfx_fade_tweens: Dictionary = {}

func _ready() -> void:
	# Initialize audio players
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Create pool of SFX players (also used for former UI sounds)
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
	# Load saved volume settings
	load_volume_settings()


func _kill_crossfade_tween() -> void:
	if crossfade_tween != null and crossfade_tween.is_valid():
		crossfade_tween.kill()
	crossfade_tween = null


# Play music with optional crossfade
func play_music(music: AudioStream, fade: bool = true) -> void:
	if current_music == music and music_player.playing:
		return

	current_music = music
	_crossfade_generation += 1
	var generation := _crossfade_generation
	_kill_crossfade_tween()

	if fade and music_player.playing:
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(music_player, "volume_db", -80.0, CROSSFADE_DURATION)
		await crossfade_tween.finished
		if generation != _crossfade_generation:
			return

		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()

		crossfade_tween = create_tween()
		crossfade_tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), CROSSFADE_DURATION)
	else:
		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()

# Play a sound effect. Optional fade_out_after starts a volume fade after that many seconds.
func play_sfx(sfx: AudioStream, fade_out_after: float = -1.0, fade_out_duration: float = 0.0) -> void:
	var player := get_available_sfx_player()
	if player == null:
		return
	_kill_sfx_fade(player)
	player.stream = sfx
	player.volume_db = linear_to_db(sfx_volume)
	player.play()
	if fade_out_after >= 0.0 and fade_out_duration > 0.0:
		_fade_out_sfx(player, fade_out_after, fade_out_duration)


## Fades an SFX player to silence, then stops it so the pool slot is free.
func _fade_out_sfx(player: AudioStreamPlayer, fade_out_after: float, fade_out_duration: float) -> void:
	var tween := create_tween()
	_sfx_fade_tweens[player] = tween
	if fade_out_after > 0.0:
		tween.tween_interval(fade_out_after)
	tween.tween_property(player, "volume_db", -80.0, fade_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		player.stop()
		player.volume_db = linear_to_db(sfx_volume)
		_sfx_fade_tweens.erase(player)
	)


func _kill_sfx_fade(player: AudioStreamPlayer) -> void:
	if not _sfx_fade_tweens.has(player):
		return
	var tween: Tween = _sfx_fade_tweens[player]
	if tween != null and tween.is_valid():
		tween.kill()
	_sfx_fade_tweens.erase(player)
	player.volume_db = linear_to_db(sfx_volume)

# Get an available SFX player from the pool
func get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0] # Return first player if all are busy

# Set music volume (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(music_volume))
	GameSettings.set_music_volume(music_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in sfx_players:
		if _sfx_fade_tweens.has(player):
			continue
		player.volume_db = linear_to_db(sfx_volume)
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(sfx_volume))
	GameSettings.set_sfx_volume(sfx_volume)


func save_volume_settings() -> void:
	GameSettings.set_music_volume(music_volume)
	GameSettings.set_sfx_volume(sfx_volume)


func load_volume_settings() -> void:
	GameSettings.ensure_loaded()
	music_volume = GameSettings.music_volume
	sfx_volume = GameSettings.sfx_volume
	music_player.volume_db = linear_to_db(music_volume)
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(music_volume))
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume)
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(sfx_volume))

# Stop all audio
func stop_all() -> void:
	music_player.stop()
	for player in sfx_players:
		player.stop()

# Pause all audio
func pause_all() -> void:
	music_player.stream_paused = true
	for player in sfx_players:
		player.stream_paused = true

# Resume all audio
func resume_all() -> void:
	music_player.stream_paused = false
	for player in sfx_players:
		player.stream_paused = false
