extends Node3D
signal microphone_toggled(active: bool)
signal voice_detected(is_speaking: bool)

@onready var mic_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var reverb_area: Area3D = $AudioStreamPlayer3D/Area3D

var in_reverb_zone := false
var bus_index: int = -1

# 🔊 Sistema de detección de voz (VOX)
var capture_effect: AudioEffectCapture
var speaking := false
@export var voice_threshold := 0.005
@export var voice_release_time := 0.2
var release_timer := 0.0

# 🌊 Variables para el efecto de expansión del sonar
@export var sonar_expansion_speed: float = 20.0
@export var max_sonar_radius: float = 50.0
@export var sonar_fade_speed: float = 1.5

var current_sonar_radius: float = 0.0
var shader_material: ShaderMaterial = null

# ✨ Sistema de ondas de voz desde la boca
@export_group("Voice Waves from Mouth")
@export var enable_voice_waves := true
@export var wave_expansion_speed: float = 8.0
@export var max_wave_radius: float = 15.0
@export var wave_color: Color = Color(0.3, 0.9, 1.0, 1.0)
@export var wave_thickness: float = 0.4
@export var wave_intensity: float = 2.5
@export var num_waves: int = 3
@export var wave_spacing: float = 3.0
@export var mouth_offset: Vector3 = Vector3(0, 0, -0.3)  # Offset desde la cámara

var current_wave_radius: float = 0.0
var wave_material: ShaderMaterial = null
var wave_mesh: MeshInstance3D = null

func _ready():
	var mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.unit_size = 2.0
	mic_player.bus = "VoiceBus"
	mic_player.stop()
	
	await get_tree().process_frame
	
	bus_index = AudioServer.get_bus_index("VoiceBus")
	
	if bus_index == -1:
		push_error("❌ No se encontró el bus 'VoiceBus'")
		return
	
	var effect_count = AudioServer.get_bus_effect_count(bus_index)
	print("📊 Efectos en VoiceBus: ", effect_count)
	
	if effect_count == 0:
		push_error("❌ VoiceBus no tiene ningún efecto")
		return
	
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectCapture:
			capture_effect = effect
			AudioServer.set_bus_effect_enabled(bus_index, i, true)
			print("✅ AudioEffectCapture encontrado en índice ", i)
			break
	
	if not capture_effect:
		push_error("❌ No se encontró AudioEffectCapture en VoiceBus")
	
	reverb_area.connect("area_entered", Callable(self, "_on_area_entered"))
	reverb_area.connect("area_exited", Callable(self, "_on_area_exited"))
	
	_find_shader_material()
	
	# ✨ Inicializar ondas de voz
	if enable_voice_waves:
		_setup_voice_waves()

func _process(delta):
	_process_voice_detection(delta)
	
	# 🌊 Actualizar sonar original
	if speaking:
		current_sonar_radius += sonar_expansion_speed * delta
		if current_sonar_radius > max_sonar_radius:
			current_sonar_radius = 0.0
	else:
		current_sonar_radius = lerp(current_sonar_radius, 0.0, sonar_fade_speed * delta)
	
	_update_sonar_shader()
	
	# ✨ Actualizar ondas de voz
	if enable_voice_waves:
		_update_voice_waves(delta)

# =============================================================
# ✨ SISTEMA DE ONDAS DE VOZ DESDE LA BOCA
# =============================================================
func _setup_voice_waves():
	print("🌊 Iniciando setup de ondas de voz...")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("❌ No se encontró el jugador en grupo 'player'")
		return
	print("✅ Jugador encontrado: ", player.name)
	
	var camera = player.get_node_or_null("Pivot/Camera3D")
	if not camera:
		push_error("❌ No se encontró la cámara en Pivot/Camera3D")
		return
	print("✅ Cámara encontrada: ", camera.name)
	
	# Buscar o crear el mesh de ondas en la cámara
	wave_mesh = camera.get_node_or_null("VoiceWavesMesh")
	
	if not wave_mesh:
		print("🔨 Creando VoiceWavesMesh...")
		# Crear un quad billboard frente a la cámara
		wave_mesh = MeshInstance3D.new()
		wave_mesh.name = "VoiceWavesMesh"
		camera.add_child(wave_mesh)
		
		# Crear mesh circular (quad) MÁS GRANDE
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = Vector2(5.0, 5.0)  # Más grande para verlo mejor
		wave_mesh.mesh = quad_mesh
		
		# Posicionar frente a la cámara (donde está la boca)
		wave_mesh.position = mouth_offset
		
		print("✅ Mesh de ondas creado")
		print("   Posición: ", wave_mesh.position)
		print("   Tamaño: 5.0x5.0")
	else:
		print("✅ VoiceWavesMesh ya existe")
	
	# CRÍTICO: Asegurar que el mesh sea visible
	wave_mesh.visible = true
	
	# Cargar el shader
	print("📂 Cargando shader desde res://shaders/voice_waves.gdshader")
	var shader = load("res://shaders/voice_waves.gdshader")
	if not shader:
		push_error("❌ No se pudo cargar voice_waves.gdshader")
		push_error("   Ruta: res://shaders/voice_waves.gdshader")
		push_error("   ¿Existe el archivo? ¿Está bien guardado?")
		wave_mesh.queue_free()
		enable_voice_waves = false
		return
	print("✅ Shader cargado exitosamente")
	
	# Crear y configurar material
	wave_material = ShaderMaterial.new()
	wave_material.shader = shader
	wave_mesh.set_surface_override_material(0, wave_material)
	print("✅ Material aplicado al mesh")
	
	# Configurar parámetros iniciales
	wave_material.set_shader_parameter("wave_color", wave_color)
	wave_material.set_shader_parameter("wave_thickness", wave_thickness)
	wave_material.set_shader_parameter("wave_intensity", wave_intensity)
	wave_material.set_shader_parameter("num_waves", num_waves)
	wave_material.set_shader_parameter("wave_spacing", wave_spacing)
	wave_material.set_shader_parameter("is_speaking", false)
	wave_material.set_shader_parameter("wave_radius", 0.0)
	
	# Configurar rendering
	wave_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	wave_mesh.layers = 1  # Asegurar que esté en la capa visible
	
	print("✅ Parámetros configurados:")
	print("   Color: ", wave_color)
	print("   Intensidad: ", wave_intensity)
	print("   Ondas: ", num_waves)
	print("✅ Sistema de ondas de voz COMPLETAMENTE configurado")

func _update_voice_waves(delta):
	if not wave_material or not wave_mesh:
		if Engine.get_frames_drawn() % 120 == 0:
			print("⚠️ Wave material o mesh es null")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var camera = player.get_node_or_null("Pivot/Camera3D")
	if not camera:
		return
	
	# 🌊 Expandir ondas cuando se está hablando
	if speaking:
		current_wave_radius += wave_expansion_speed * delta
		if current_wave_radius > max_wave_radius:
			current_wave_radius = 0.0
			if enable_voice_waves:
				print("🔄 Onda reiniciada - Nueva onda comenzando")
	else:
		# Desvanecer ondas suavemente cuando deja de hablar
		current_wave_radius = lerp(current_wave_radius, 0.0, 3.0 * delta)
	
	# 📍 Calcular posición de la boca en el mundo
	var mouth_world_pos = camera.global_position + camera.global_transform.basis * mouth_offset
	
	# Actualizar parámetros del shader
	wave_material.set_shader_parameter("mouth_position", mouth_world_pos)
	wave_material.set_shader_parameter("wave_radius", current_wave_radius)
	wave_material.set_shader_parameter("is_speaking", speaking)
	
	# Debug periódico
	if speaking and Engine.get_frames_drawn() % 60 == 0:
		print("🌊 Radio: %.2f / %.2f | Mesh visible: %s" % [current_wave_radius, max_wave_radius, wave_mesh.visible])

# =============================================================
# 🔊 SISTEMA DE DETECCIÓN DE VOZ (VOX)
# =============================================================
func _process_voice_detection(delta):
	if not mic_player.playing:
		_set_speaking(false)
		return
	
	if not capture_effect:
		return
		
	if capture_effect.get_frames_available() == 0:
		return
	
	var buffer = capture_effect.get_buffer(capture_effect.get_frames_available())
	
	var sum := 0.0
	for sample in buffer:
		sum += sample.length()
	var average = sum / buffer.size()
	
	if Engine.get_frames_drawn() % 30 == 0:
		print("🎤 Volumen: %.4f (threshold: %.4f)" % [average, voice_threshold])
	
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
	
	if speaking:
		print("🎤 💬 Hablando detectado - Ondas activadas desde la boca")
	else:
		print("🔇 Silencio detectado")

# =============================================================
# 🎯 SISTEMA DE SHADER (SONAR ORIGINAL)
# =============================================================
func _find_shader_material():
	var sonar_mesh = get_tree().get_first_node_in_group("sonar_shader")
	if sonar_mesh and sonar_mesh is MeshInstance3D:
		shader_material = sonar_mesh.get_active_material(0)
		if shader_material and shader_material is ShaderMaterial:
			print("✅ Shader material del sonar encontrado")
		else:
			push_warning("⚠️ SonarMesh no tiene ShaderMaterial")
	else:
		push_warning("⚠️ No se encontró nodo en grupo 'sonar_shader'")

func _update_sonar_shader():
	if not shader_material:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var camera = player.get_node_or_null("Pivot/Camera3D")
	if not camera or not (camera is Camera3D):
		return
	
	shader_material.set_shader_parameter("sonar_world_position", player.global_position)
	shader_material.set_shader_parameter("sonar_radius", current_sonar_radius)
	shader_material.set_shader_parameter("sonar_active", speaking)
	
	var projection = camera.get_camera_projection()
	var inv_projection = projection.inverse()
	shader_material.set_shader_parameter("inv_projection_matrix", inv_projection)
	
	var view_transform = camera.get_camera_transform()
	var view = view_transform.affine_inverse()
	var inv_view = view.inverse()
	shader_material.set_shader_parameter("inv_view_matrix", inv_view)
	
	shader_material.set_shader_parameter("camera_near", camera.near)
	shader_material.set_shader_parameter("camera_far", camera.far)

# =============================================================
# 🔘 CONTROL DEL MICRÓFONO
# =============================================================
func toggle_microphone():
	if mic_player.playing:
		mic_player.stop()
		emit_signal("microphone_toggled", false)
		_set_speaking(false)
	else:
		mic_player.play()
		emit_signal("microphone_toggled", true)
		current_sonar_radius = 0.0
		current_wave_radius = 0.0

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

func get_wave_radius() -> float:
	return current_wave_radius

# 🎨 Métodos para ajustar parámetros en runtime
func set_wave_color(color: Color):
	wave_color = color
	if wave_material:
		wave_material.set_shader_parameter("wave_color", color)

func set_wave_intensity(intensity: float):
	wave_intensity = intensity
	if wave_material:
		wave_material.set_shader_parameter("wave_intensity", intensity)
