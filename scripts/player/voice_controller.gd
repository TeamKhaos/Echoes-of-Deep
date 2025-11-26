extends Node3D
signal microphone_toggled(active: bool)
signal voice_detected(is_speaking: bool)  # 🆕 Nueva señal

@onready var mic_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var reverb_area: Area3D = $AudioStreamPlayer3D/Area3D

var in_reverb_zone := false
var bus_index: int = -1

# 🔊 Sistema de detección de voz (VOX)
var capture_effect: AudioEffectCapture
var speaking := false
@export var voice_threshold := 0.005     # 🔧 MÁS SENSIBLE (era 0.02)
@export var voice_release_time := 0.2   # Tiempo que tarda en apagarse el estado de "hablando"
var release_timer := 0.0

# 🌊 Variables para el efecto de expansión del sonar
@export var sonar_expansion_speed: float = 20.0  # Velocidad de expansión en unidades 3D
@export var max_sonar_radius: float = 50.0      # Radio máximo del sonar
@export var sonar_fade_speed: float = 1.5       # Velocidad de desvanecimiento

var current_sonar_radius: float = 0.0
var shader_material: ShaderMaterial = null

func _ready():
	var mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.unit_size = 2.0
	mic_player.bus = "VoiceBus"
	mic_player.stop()
	
	# Esperar un frame para que el AudioServer esté completamente inicializado
	await get_tree().process_frame
	
	bus_index = AudioServer.get_bus_index("VoiceBus")
	
	if bus_index == -1:
		push_error("❌ No se encontró el bus 'VoiceBus'")
		push_error("   Crea un bus llamado 'VoiceBus' en Audio → Audio Bus Layout")
		return
	
	# 🔍 Buscar el AudioEffectCapture
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	print("📊 Efectos en VoiceBus: ", effect_count)
	
	if effect_count == 0:
		push_error("❌ VoiceBus no tiene ningún efecto")
		push_error("   Añade un AudioEffectCapture en Audio → Audio Bus Layout → VoiceBus → Añadir Efecto")
		return
	
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		var effect_name = effect.get_class() if effect else "null"
		print("  - Efecto [", i, "]: ", effect_name)
		
		if effect is AudioEffectCapture:
			capture_effect = effect
			AudioServer.set_bus_effect_enabled(bus_index, i, true)
			print("✅ AudioEffectCapture encontrado en índice ", i)
			print("✅ Buffer Length: ", capture_effect.buffer_length, "s")
			break
	
	if not capture_effect:
		push_error("❌ No se encontró AudioEffectCapture en VoiceBus")
		push_error("   SOLUCIÓN:")
		push_error("   1. Ve a Audio → Audio Bus Layout (abajo)")
		push_error("   2. Selecciona 'VoiceBus'")
		push_error("   3. Haz clic en 'Añadir Efecto'")
		push_error("   4. Busca y añade 'AudioEffectCapture'")
		push_error("   5. Asegúrate de que esté ACTIVO (checkbox marcado)")
	
	reverb_area.connect("area_entered", Callable(self, "_on_area_entered"))
	reverb_area.connect("area_exited", Callable(self, "_on_area_exited"))
	
	# 🎯 Buscar el material del shader al inicio
	_find_shader_material()

func _process(delta):
	# 🔊 Procesar detección de voz primero
	_process_voice_detection(delta)
	
	# 🌊 Actualizar expansión del sonar basado en si se está hablando
	if speaking:
		current_sonar_radius += sonar_expansion_speed * delta
		if current_sonar_radius > max_sonar_radius:
			current_sonar_radius = 0.0  # Reiniciar para pulsos continuos
	else:
		current_sonar_radius = lerp(current_sonar_radius, 0.0, sonar_fade_speed * delta)
	
	# 🎯 Actualizar shader cada frame
	_update_sonar_shader()

# =============================================================
# 🔊 SISTEMA DE DETECCIÓN DE VOZ (VOX)
# =============================================================
func _process_voice_detection(delta):
	# No detectar si el micrófono está apagado
	if not mic_player.playing:
		_set_speaking(false)
		return
	
	# Verificar si hay datos de audio disponibles
	if not capture_effect:
		print("⚠️ capture_effect es null")
		return
		
	if capture_effect.get_frames_available() == 0:
		return
	
	# Obtener el buffer de audio capturado
	var buffer = capture_effect.get_buffer(capture_effect.get_frames_available())
	
	# Calcular el volumen promedio
	var sum := 0.0
	for sample in buffer:
		sum += sample.length()
	var average = sum / buffer.size()
	
	# 📊 Debug: Mostrar volumen detectado
	if Engine.get_frames_drawn() % 30 == 0:  # Cada medio segundo aprox
		print("🎤 Volumen: %.4f (threshold: %.4f)" % [average, voice_threshold])
	
	# Determinar si se está hablando
	if average > voice_threshold:
		_set_speaking(true)
		release_timer = voice_release_time
	else:
		release_timer -= delta
		if release_timer <= 0:
			_set_speaking(false)

func _set_speaking(state: bool):
	if speaking == state:
		return
	
	speaking = state
	emit_signal("voice_detected", speaking)
	
	# Debug opcional
	if speaking:
		print("🎤 Hablando detectado")
	else:
		print("🔇 Silencio detectado")

# =============================================================
# 🎯 SISTEMA DE SHADER
# =============================================================
# 🔍 Busca el material del shader (llama esto una vez al inicio)
func _find_shader_material():
	var sonar_mesh = get_tree().get_first_node_in_group("sonar_shader")
	if sonar_mesh and sonar_mesh is MeshInstance3D:
		shader_material = sonar_mesh.get_active_material(0)
		if shader_material and shader_material is ShaderMaterial:
			print("✅ Shader material encontrado")
		else:
			push_warning("⚠️ No se encontró ShaderMaterial en sonar_shader")
	else:
		push_warning("⚠️ No se encontró nodo en grupo 'sonar_shader'")

# 🎯 Actualiza los parámetros del shader con datos 3D
func _update_sonar_shader():
	if not shader_material:
		return
	
	# Obtener el jugador y la cámara
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var camera = player.get_node_or_null("Pivot/Camera3D")
	if not camera or not (camera is Camera3D):
		return
	
	# 🌍 Enviar posición 3D del jugador al shader
	shader_material.set_shader_parameter("sonar_world_position", player.global_position)
	shader_material.set_shader_parameter("sonar_radius", current_sonar_radius)
	shader_material.set_shader_parameter("sonar_active", speaking)  # 🆕 Usar 'speaking' en vez de 'mic_player.playing'
	
	# 📐 Enviar matrices de proyección para reconstruir posiciones 3D
	var projection = camera.get_camera_projection()
	var inv_projection = projection.inverse()
	shader_material.set_shader_parameter("inv_projection_matrix", inv_projection)
	
	var view_transform = camera.get_camera_transform()
	var view = view_transform.affine_inverse()
	var inv_view = view.inverse()
	shader_material.set_shader_parameter("inv_view_matrix", inv_view)
	
	# Enviar parámetros de la cámara
	shader_material.set_shader_parameter("camera_near", camera.near)
	shader_material.set_shader_parameter("camera_far", camera.far)

# =============================================================
# 🔘 CONTROL DEL MICRÓFONO
# =============================================================
# Alterna el micrófono entre encendido/apagado
func toggle_microphone():
	if mic_player.playing:
		mic_player.stop()
		emit_signal("microphone_toggled", false)
		_set_speaking(false)  # 🆕 Resetear estado de voz
	else:
		mic_player.play()
		emit_signal("microphone_toggled", true)
		current_sonar_radius = 0.0  # Reiniciar desde cero

# =============================================================
# 🎵 SISTEMA DE REVERB
# =============================================================
func _on_area_entered(area: Area3D):
	if area.is_in_group("reverb_zone"):
		in_reverb_zone = true
		_update_reverb()

func _on_area_exited(area: Area3D):
	if area.is_in_group("reverb_zone"):
		in_reverb_zone = false
		_update_reverb()

func _update_reverb():
	if bus_index == -1:
		return
	
	var should_enable = in_reverb_zone and mic_player.playing
	AudioServer.set_bus_effect_enabled(bus_index, 0, should_enable)

# =============================================================
# 📊 MÉTODOS DE UTILIDAD
# =============================================================
func is_active() -> bool:
	return mic_player.playing

func is_speaking() -> bool:
	return speaking

func get_sonar_radius() -> float:
	return current_sonar_radius
