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
	# Si está activo, hacer que sigan la dirección de la cámara
	if particles.emitting:
		var camera = get_parent()
		if camera and camera is Camera3D:
			global_transform.basis = Basis.looking_at(global_transform.origin + camera.global_transform.basis.z, Vector3.UP)


func update_emission(direction: Vector3):
	# Habilita emisión si no está activa
	if not particles.emitting:
		particles.emitting = true

	# Ajusta dirección para que salga frente a la cámara
	particles.process_material.direction = direction.normalized()

func stop_emission():
	if particles.emitting:
		particles.emitting = false
