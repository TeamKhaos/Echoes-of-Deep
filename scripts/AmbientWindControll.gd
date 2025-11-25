extends Node3D
class_name AmbientWindController

## 🌬️ Controlador de viento ambiental que cambia según el estado del jugador

# Referencias a los nodos de audio
@onready var wind_strong: AudioStreamPlayer3D = $WindStrong
@onready var wind_soft: AudioStreamPlayer3D = $WindSoft

# Referencia al jugador
@export var player: CharacterBody3D

# Configuración de volumen
@export_group("Volume Settings")
@export_range(-40.0, 0.0, 0.5) var strong_wind_max_volume: float = -8.0
@export_range(-40.0, 0.0, 0.5) var soft_wind_max_volume: float = -12.0
@export_range(-80.0, -40.0, 1.0) var min_volume: float = -60.0

# Configuración de transición
@export_group("Transition Settings")
@export_range(0.1, 5.0, 0.1) var fade_duration: float = 1.5
@export_range(0.0, 2.0, 0.1) var idle_detection_delay: float = 0.3

# Variables de estado
var is_player_moving: bool = false
var idle_timer: float = 0.0
var current_fade_tween: Tween = null

func _ready():
	# Buscar el jugador automáticamente si no está asignado
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			push_error("⚠️ No se encontró el jugador. Asegúrate de que tenga el grupo 'player'")
			return
	
	# Configurar los AudioStreamPlayer3D
	_setup_audio_players()
	
	# Iniciar con viento fuerte (jugador quieto)
	wind_strong.volume_db = strong_wind_max_volume
	wind_soft.volume_db = min_volume
	
	# Iniciar reproducción en loop
	wind_strong.play()
	wind_soft.play()
	
	print("🌬️ Sistema de viento ambiental iniciado")

func _setup_audio_players():
	# Configurar viento fuerte
	if wind_strong:
		wind_strong.max_distance = 50.0
		wind_strong.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		wind_strong.unit_size = 10.0
		
		# Cargar audio si existe
		var strong_path = "res://resources/audio/viento_fuerte.mp3"
		var strong_stream = null
		if ResourceLoader.exists(strong_path):
			strong_stream = load(strong_path)
		elif ResourceLoader.exists("res://resources/audio/viento_fuerte.ogg"):
			strong_stream = load("res://resources/audio/viento_fuerte.ogg")
		elif ResourceLoader.exists("res://resources/audio/viento_fuerte.wav"):
			strong_stream = load("res://resources/audio/viento_fuerte.wav")
		
		# Configurar loop en el stream
		if strong_stream:
			if strong_stream is AudioStreamMP3:
				strong_stream.loop = true
			elif strong_stream is AudioStreamOggVorbis:
				strong_stream.loop = true
			elif strong_stream is AudioStreamWAV:
				strong_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wind_strong.stream = strong_stream
	
	# Configurar viento suave
	if wind_soft:
		wind_soft.max_distance = 50.0
		wind_soft.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		wind_soft.unit_size = 10.0
		
		# Cargar audio si existe
		var soft_path = "res://resources/audio/viento_suave.mp3"
		var soft_stream = null
		if ResourceLoader.exists(soft_path):
			soft_stream = load(soft_path)
		elif ResourceLoader.exists("res://resources/audio/viento_suave.ogg"):
			soft_stream = load("res://resources/audio/viento_suave.ogg")
		elif ResourceLoader.exists("res://resources/audio/viento_suave.wav"):
			soft_stream = load("res://resources/audio/viento_suave.wav")
		
		# Configurar loop en el stream
		if soft_stream:
			if soft_stream is AudioStreamMP3:
				soft_stream.loop = true
			elif soft_stream is AudioStreamOggVorbis:
				soft_stream.loop = true
			elif soft_stream is AudioStreamWAV:
				soft_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wind_soft.stream = soft_stream

func _process(delta):
	if not player:
		return
	
	# Detectar si el jugador se está moviendo
	var player_velocity = player.velocity
	var horizontal_speed = Vector2(player_velocity.x, player_velocity.z).length()
	
	# Determinar estado de movimiento con un pequeño umbral
	var is_currently_moving = horizontal_speed > 0.1
	
	# Sistema de detección con delay para evitar cambios bruscos
	if is_currently_moving:
		idle_timer = 0.0
		if not is_player_moving:
			is_player_moving = true
			_transition_to_soft_wind()
	else:
		idle_timer += delta
		if idle_timer >= idle_detection_delay and is_player_moving:
			is_player_moving = false
			_transition_to_strong_wind()

func _transition_to_soft_wind():
	"""Transición suave al viento suave (jugador caminando)"""
	print("🌬️ Transición a viento suave (caminando)")
	_create_fade_transition(wind_strong, strong_wind_max_volume, min_volume, 
						   wind_soft, min_volume, soft_wind_max_volume)

func _transition_to_strong_wind():
	"""Transición suave al viento fuerte (jugador quieto)"""
	print("🌬️ Transición a viento fuerte (quieto)")
	_create_fade_transition(wind_soft, soft_wind_max_volume, min_volume,
						   wind_strong, min_volume, strong_wind_max_volume)

func _create_fade_transition(fade_out_player: AudioStreamPlayer3D, start_vol_out: float, end_vol_out: float,
							 fade_in_player: AudioStreamPlayer3D, start_vol_in: float, end_vol_in: float):
	"""Crea una transición de fade entre dos fuentes de audio"""
	
	# Cancelar tween anterior si existe
	if current_fade_tween and current_fade_tween.is_valid():
		current_fade_tween.kill()
	
	# Crear nuevo tween
	current_fade_tween = create_tween()
	current_fade_tween.set_parallel(true)
	current_fade_tween.set_trans(Tween.TRANS_SINE)
	current_fade_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Fade out del audio actual
	current_fade_tween.tween_property(fade_out_player, "volume_db", 
									  end_vol_out, fade_duration)
	
	# Fade in del nuevo audio
	current_fade_tween.tween_property(fade_in_player, "volume_db", 
									  end_vol_in, fade_duration)

func set_wind_enabled(enabled: bool):
	"""Activar o desactivar el sistema de viento"""
	if enabled:
		wind_strong.stream_paused = false
		wind_soft.stream_paused = false
	else:
		wind_strong.stream_paused = true
		wind_soft.stream_paused = true

func stop_all_wind():
	"""Detener completamente todos los vientos"""
	wind_strong.stop()
	wind_soft.stop()
