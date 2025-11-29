extends Node
class_name ItemAudioController

## 🔊 Controlador simple de sonidos para ítems

# Referencias a los nodos de audio
@onready var pickup_player: AudioStreamPlayer3D = $PickupSound
@onready var drop_player: AudioStreamPlayer3D = $DropSound
@onready var drink_player: AudioStreamPlayer3D = $DrinkSound
@onready var eat_player: AudioStreamPlayer3D = $EatSound

# Rutas de los sonidos (ajusta los nombres según tus archivos)
@export var pickup_sound_path: String = "res://resources/audio/pickup.mp3"
@export var drop_sound_path: String = "res://resources/audio/drop.mp3"
@export var drink_sound_path: String = "res://resources/audio/beber.mp3"
@export var eat_sound_path: String = "res://resources/audio/comer.mp3"

# Configuración de volumen
@export_group("Volume Settings")
@export_range(-20.0, 10.0, 0.5) var volume: float = -5.0
@export_range(0.0, 0.3, 0.05) var pitch_variation: float = 0.1

func _ready():
	_setup_audio_players()

func _setup_audio_players():
	"""Configura y carga los sonidos"""
	
	# Configurar pickup
	if pickup_player:
		pickup_player.volume_db = volume
		pickup_player.max_distance = 20.0
		_load_sound(pickup_player, pickup_sound_path)
	
	# Configurar drop
	if drop_player:
		drop_player.volume_db = volume
		drop_player.max_distance = 25.0
		_load_sound(drop_player, drop_sound_path)
	
	# Configurar drink
	if drink_player:
		drink_player.volume_db = volume
		drink_player.max_distance = 15.0
		_load_sound(drink_player, drink_sound_path)
	
	# Configurar eat
	if eat_player:
		eat_player.volume_db = volume
		eat_player.max_distance = 15.0
		_load_sound(eat_player, eat_sound_path)

func _load_sound(player: AudioStreamPlayer3D, path: String):
	"""Carga un sonido en el player"""
	if ResourceLoader.exists(path):
		player.stream = load(path)
	else:
		push_warning("⚠️ No se encontró: " + path)

func play_pickup_sound():
	"""Reproduce sonido de recoger"""
	_play(pickup_player)

func play_drop_sound():
	"""Reproduce sonido de soltar"""
	_play(drop_player)

func play_drink_sound():
	"""Reproduce sonido de beber"""
	_play(drink_player)

func play_eat_sound():
	"""Reproduce sonido de comer"""
	_play(eat_player)

func _play(player: AudioStreamPlayer3D):
	"""Reproduce un sonido con variación de pitch"""
	if player and player.stream:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
		player.play()
