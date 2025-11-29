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

# 🎯 Sistema de proyectiles de voz en 2D
@export_group("Voice Projectiles")
@export var enable_voice_projectiles := true
@export var projectile_speed: float = 300.0  # Píxeles por segundo
@export var projectile_lifetime: float = 2.0
@export var spawn_interval: float = 0.2
@export var projectile_start_size: float = 40.0
@export var projectile_max_size: float = 150.0
@export var projectile_color: Color = Color(1.0, 0.3, 0.3, 0.8)

var canvas_layer: CanvasLayer = null
var active_projectiles_2d: Array = []
var spawn_timer: float = 0.0

# Clase para proyectil 2D
class VoiceProjectile2D:
	var control: Control
	var age: float = 0.0
	var lifetime: float
	var start_size: float
	var max_size: float
	var speed: float
	var velocity: Vector2
	var color: Color
	
	func _init(ctrl: Control, _lifetime: float, _start: float, _max: float, _speed: float, vel: Vector2, col: Color):
		control = ctrl
		lifetime = _lifetime
		start_size = _start
		max_size = _max
		speed = _speed
		velocity = vel
		color = col
	
	func update(delta: float) -> bool:
		age += delta
		
		if age >= lifetime:
			return false
		
		var progress = age / lifetime
		
		# Expandir tamaño
		var current_size = lerp(start_size, max_size, progress)
		control.custom_minimum_size = Vector2(current_size, current_size)
		control.size = Vector2(current_size, current_size)
		
		# Mover
		control.position += velocity * delta
		
		# Fade out
		var alpha = 1.0 - progress
		control.modulate = Color(color.r, color.g, color.b, alpha * color.a)
		
		control.queue_redraw()
		return true
	
	func destroy():
		if control:
			control.queue_free()

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
	
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectCapture:
			capture_effect = effect
			AudioServer.set_bus_effect_enabled(bus_index, i, true)
			break
	
	reverb_area.connect("area_entered", Callable(self, "_on_area_entered"))
	reverb_area.connect("area_exited", Callable(self, "_on_area_exited"))
	
	_find_shader_material()
	
	# 🎯 Setup proyectiles 2D
	if enable_voice_projectiles:
		_setup_projectile_2d_system()

func _process(delta):
	_process_voice_detection(delta)
	
	# 🌊 Actualizar sonar
	if speaking:
		current_sonar_radius += sonar_expansion_speed * delta
		if current_sonar_radius > max_sonar_radius:
			current_sonar_radius = 0.0
	else:
		current_sonar_radius = lerp(current_sonar_radius, 0.0, sonar_fade_speed * delta)
	
	_update_sonar_shader()
	
	# 🎯 Actualizar proyectiles
	if enable_voice_projectiles:
		_update_projectile_2d_system(delta)

# =============================================================
# 🎯 SISTEMA DE PROYECTILES 2D
# =============================================================
func _setup_projectile_2d_system():
	# Buscar el PlayerHUD existente
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("❌ No se encontró el jugador")
		return
	
	var player_hud = player.get_node_or_null("PlayerHUD")
	if player_hud and player_hud is CanvasLayer:
		canvas_layer = player_hud
	else:
		# Crear nuevo CanvasLayer
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "VoiceProjectilesLayer"
		canvas_layer.layer = 100  # Encima de todo
		player.add_child(canvas_layer)
	

func _update_projectile_2d_system(delta):
	if not canvas_layer:
		return
	
	# Spawn nuevos proyectiles
	if speaking:
		spawn_timer += delta
		
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_spawn_projectile_2d()
	
	# Actualizar existentes
	var dead = []
	for i in range(active_projectiles_2d.size()):
		if not active_projectiles_2d[i].update(delta):
			dead.append(i)
	
	# Eliminar muertos
	for i in range(dead.size() - 1, -1, -1):
		var idx = dead[i]
		active_projectiles_2d[idx].destroy()
		active_projectiles_2d.remove_at(idx)

func _spawn_projectile_2d():
	# Crear Control que dibuja un círculo
	var circle = Control.new()
	circle.custom_minimum_size = Vector2(projectile_start_size, projectile_start_size)
	circle.size = Vector2(projectile_start_size, projectile_start_size)
	
	# Posición inicial (centro de la pantalla = boca)
	var viewport_size = get_viewport().get_visible_rect().size
	circle.position = viewport_size / 2.0 - Vector2(projectile_start_size, projectile_start_size) / 2.0
	
	# Dirección aleatoria hacia afuera
	var angle = randf() * TAU
	var velocity = Vector2(cos(angle), sin(angle)) * projectile_speed
	
	# Conectar el draw
	circle.draw.connect(_draw_circle.bind(circle))
	
	canvas_layer.add_child(circle)
	
	var projectile = VoiceProjectile2D.new(
		circle,
		projectile_lifetime,
		projectile_start_size,
		projectile_max_size,
		projectile_speed,
		velocity,
		projectile_color
	)
	
	active_projectiles_2d.append(projectile)

func _draw_circle(control: Control):
	var radius = control.size.x / 2.0
	var center = control.size / 2.0
	
	# Dibujar círculo relleno
	control.draw_circle(center, radius, projectile_color)
	
	# Dibujar borde brillante
	var ring_width = max(3.0, radius * 0.15)
	for i in range(int(ring_width)):
		var t = float(i) / ring_width
		var ring_radius = radius - i
		var ring_alpha = (1.0 - t) * projectile_color.a
		var ring_color = Color(projectile_color.r, projectile_color.g, projectile_color.b, ring_alpha)
		control.draw_arc(center, ring_radius, 0, TAU, 32, ring_color, 1.0)

# =============================================================
# 🔊 SISTEMA DE DETECCIÓN DE VOZ
# =============================================================
func _process_voice_detection(delta):
	if not mic_player.playing:
		_set_speaking(false)
		return
	
	if not capture_effect or capture_effect.get_frames_available() == 0:
		return
	
	var buffer = capture_effect.get_buffer(capture_effect.get_frames_available())
	var sum := 0.0
	for sample in buffer:
		sum += sample.length()
	var average = sum / buffer.size()
	
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
		spawn_timer = spawn_interval

# =============================================================
# 🎯 SHADER SONAR
# =============================================================
func _find_shader_material():
	var sonar_mesh = get_tree().get_first_node_in_group("sonar_shader")
	if sonar_mesh and sonar_mesh is MeshInstance3D:
		shader_material = sonar_mesh.get_active_material(0)

func _update_sonar_shader():
	if not shader_material:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var camera = player.get_node_or_null("Pivot/Camera3D")
	if not camera:
		return
	
	shader_material.set_shader_parameter("sonar_world_position", player.global_position)
	shader_material.set_shader_parameter("sonar_radius", current_sonar_radius)
	shader_material.set_shader_parameter("sonar_active", speaking)
	
	var projection = camera.get_camera_projection()
	shader_material.set_shader_parameter("inv_projection_matrix", projection.inverse())
	
	var view = camera.get_camera_transform().affine_inverse()
	shader_material.set_shader_parameter("inv_view_matrix", view.inverse())
	
	shader_material.set_shader_parameter("camera_near", camera.near)
	shader_material.set_shader_parameter("camera_far", camera.far)

# =============================================================
# 🔘 CONTROL
# =============================================================
func toggle_microphone():
	if mic_player.playing:
		mic_player.stop()
		emit_signal("microphone_toggled", false)
		_set_speaking(false)
		_clear_projectiles()
	else:
		mic_player.play()
		emit_signal("microphone_toggled", true)
		current_sonar_radius = 0.0

func _clear_projectiles():
	for p in active_projectiles_2d:
		p.destroy()
	active_projectiles_2d.clear()

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

func is_active() -> bool:
	return mic_player.playing

func is_speaking() -> bool:
	return speaking

func get_sonar_radius() -> float:
	return current_sonar_radius
