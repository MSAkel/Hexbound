extends Node

# Audio bus names and indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2
const UI_BUS = 3

# Default volume levels (in decibels)
const DEFAULT_MUSIC_VOLUME = -6.0  # -6 dB for music
const DEFAULT_SFX_VOLUME = 0.0     # 0 dB for sound effects
const DEFAULT_UI_VOLUME = -3.0     # -3 dB for UI sounds

func _ready() -> void:
	setup_audio_buses()

func setup_audio_buses() -> void:
	var audio_server = AudioServer
	
	# Create buses if they don't exist
	if audio_server.bus_count <= MUSIC_BUS:
		audio_server.add_bus()
	if audio_server.bus_count <= SFX_BUS:
		audio_server.add_bus()
	if audio_server.bus_count <= UI_BUS:
		audio_server.add_bus()
	
	# Set bus names
	audio_server.set_bus_name(MUSIC_BUS, "Music")
	audio_server.set_bus_name(SFX_BUS, "SFX")
	audio_server.set_bus_name(UI_BUS, "UI")
	
	# Set default volumes
	audio_server.set_bus_volume_db(MUSIC_BUS, DEFAULT_MUSIC_VOLUME)
	audio_server.set_bus_volume_db(SFX_BUS, DEFAULT_SFX_VOLUME)
	audio_server.set_bus_volume_db(UI_BUS, DEFAULT_UI_VOLUME)
	
	# Set bus sends (all buses send to master)
	audio_server.set_bus_send(MUSIC_BUS, "Master")
	audio_server.set_bus_send(SFX_BUS, "Master")
	audio_server.set_bus_send(UI_BUS, "Master")
	
	# Enable all buses
	audio_server.set_bus_mute(MUSIC_BUS, false)
	audio_server.set_bus_mute(SFX_BUS, false)
	audio_server.set_bus_mute(UI_BUS, false) 