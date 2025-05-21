extends Node

# Audio bus indices (matching audio_bus_setup.gd)
const MUSIC_BUS = 1
const SFX_BUS = 2
const UI_BUS = 3

# Audio players
var music_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8

# Current music track
var current_music: AudioStream
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 1.0

# Crossfade settings
const CROSSFADE_DURATION = 1.0
var crossfade_tween: Tween

func _ready() -> void:
	# Initialize audio players
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)
	
	# Create pool of SFX players
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
	# Load saved volume settings
	load_volume_settings()

# Play music with optional crossfade
func play_music(music: AudioStream, fade: bool = true) -> void:
	if current_music == music and music_player.playing:
		return
		
	current_music = music
	
	if fade and music_player.playing:
		# Start crossfade
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(music_player, "volume_db", -80.0, CROSSFADE_DURATION)
		await crossfade_tween.finished
		
		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()
		
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), CROSSFADE_DURATION)
	else:
		music_player.stream = music
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()

# Play a sound effect
func play_sfx(sfx: AudioStream) -> void:
	# Find an available player
	var player = get_available_sfx_player()
	if player:
		player.stream = sfx
		player.volume_db = linear_to_db(sfx_volume)
		player.play()

# Play a UI sound
func play_ui_sound(sound: AudioStream) -> void:
	ui_player.stream = sound
	ui_player.volume_db = linear_to_db(ui_volume)
	ui_player.play()

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
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(volume))
	save_volume_settings()

# Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume)
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(volume))
	save_volume_settings()

# Set UI volume (0.0 to 1.0)
func set_ui_volume(volume: float) -> void:
	ui_volume = clamp(volume, 0.0, 1.0)
	ui_player.volume_db = linear_to_db(ui_volume)
	AudioServer.set_bus_volume_db(UI_BUS, linear_to_db(volume))
	save_volume_settings()

# Save volume settings
func save_volume_settings() -> void:
	var settings = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume
	}
	var save_file = FileAccess.open("user://audio_settings.save", FileAccess.WRITE)
	save_file.store_var(settings)

# Load volume settings
func load_volume_settings() -> void:
	if FileAccess.file_exists("user://audio_settings.save"):
		var save_file = FileAccess.open("user://audio_settings.save", FileAccess.READ)
		var settings = save_file.get_var()
		
		if settings is Dictionary:
			music_volume = settings.get("music_volume", 1.0)
			sfx_volume = settings.get("sfx_volume", 1.0)
			ui_volume = settings.get("ui_volume", 1.0)
			
			# Apply loaded settings
			set_music_volume(music_volume)
			set_sfx_volume(sfx_volume)
			set_ui_volume(ui_volume)

# Stop all audio
func stop_all() -> void:
	music_player.stop()
	ui_player.stop()
	for player in sfx_players:
		player.stop()

# Pause all audio
func pause_all() -> void:
	music_player.stream_paused = true
	ui_player.stream_paused = true
	for player in sfx_players:
		player.stream_paused = true

# Resume all audio
func resume_all() -> void:
	music_player.stream_paused = false
	ui_player.stream_paused = false
	for player in sfx_players:
		player.stream_paused = false
