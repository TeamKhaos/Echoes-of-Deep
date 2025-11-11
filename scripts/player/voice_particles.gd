extends Node3D

@onready var particles: GPUParticles3D = $VoiceParticles
@onready var voice_controller: Node3D = $"../../../Voice"

func _ready():
	# Conectamos al evento del controlador
	if voice_controller.has_signal("microphone_toggled"):
		voice_controller.connect("microphone_toggled", Callable(self, "_on_microphone_toggled"))

func _on_microphone_toggled(active: bool):
	particles.emitting = active
	if active:
		print("💨 Partículas activadas por voz")
	else:
		print("💨 Partículas desactivadas por voz")

func _process(delta: float) -> void:
	if particles.emitting:
		var camera = get_parent()
		if camera and camera is Camera3D:
			var dir = -camera.global_transform.basis.z.normalized()
			update_emission(dir)


func update_emission(direction: Vector3): 
	if not particles.emitting:
		particles.emitting = true 
	var material := particles.process_material 
	if material is ParticleProcessMaterial: 
		material.direction = direction.normalized() 
		material.spread = 0.0 # recto 
		material.gravity = Vector3.ZERO # evita que caigan 
		material.initial_velocity_min = 10 # más fuerza inicial 
		material.initial_velocity_max = 10 # más fuerza inicial 
		material.angle_min = 0.0 
		material.angle_max = 0.0 
		material.angular_velocity_min = 0.0 
		material.angular_velocity_max = 0.0

func stop_emission():
	if particles.emitting:
		particles.emitting = false
