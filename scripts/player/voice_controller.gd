extends Node3D

signal microphone_toggled(active: bool)

@onready var mic_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var reverb_area: Area3D = $AudioStreamPlayer3D/Area3D

var in_reverb_zone := false
var bus_index: int = -1

func _ready():
	var mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.unit_size = 2.0
	mic_player.bus = "VoiceBus"
	mic_player.stop()
	
	# Obtener índice del bus una sola vez
	bus_index = AudioServer.get_bus_index("VoiceBus")
	
	# 🔹 IMPORTANTE: Desactivar el reverb al inicio
	if bus_index != -1:
		AudioServer.set_bus_effect_enabled(bus_index, 0, false)
	
	# Conectar detección de zonas de reverb
	reverb_area.connect("area_entered", Callable(self, "_on_area_entered"))
	reverb_area.connect("area_exited", Callable(self, "_on_area_exited"))

# 🔹 Alterna el micrófono entre encendido/apagado
func toggle_microphone():
	if mic_player.playing:
		mic_player.stop()
		emit_signal("microphone_toggled", false)
	else:
		mic_player.play()
		emit_signal("microphone_toggled", true)

# 🔹 Detecta entrada a zona de reverb
func _on_area_entered(area: Area3D):
	if area.is_in_group("reverb_zone"):
		in_reverb_zone = true
		_update_reverb()

# 🔹 Detecta salida de zona de reverb
func _on_area_exited(area: Area3D):
	if area.is_in_group("reverb_zone"):
		in_reverb_zone = false
		_update_reverb()

# 🔹 Actualiza el estado del reverb basado en la zona
func _update_reverb():
	if bus_index == -1:
		return
	
	# Solo activar reverb si está en la zona Y el micrófono está activo
	var should_enable = in_reverb_zone and mic_player.playing
	AudioServer.set_bus_effect_enabled(bus_index, 0, should_enable)

# 🔹 Permite consultar desde fuera si el micrófono está activo
func is_active() -> bool:
	return mic_player.playing
