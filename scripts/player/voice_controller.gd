extends Node3D

signal microphone_toggled(active: bool)

@onready var mic_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var reverb_area: Area3D = $AudioStreamPlayer3D/Area3D

var in_reverb_zone := false

func _ready():
	var mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.unit_size = 2.0
	mic_player.bus = "VoiceBus"
	mic_player.stop()


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
		var bus_index = AudioServer.get_bus_index("VoiceBus")
		AudioServer.set_bus_effect_enabled(bus_index, 0, true)

# 🔹 Detecta salida de zona de reverb
func _on_area_exited(area: Area3D):
	if area.is_in_group("reverb_zone"):
		in_reverb_zone = false
		var bus_index = AudioServer.get_bus_index("VoiceBus")
		AudioServer.set_bus_effect_enabled(bus_index, 0, false)

# 🔹 Permite consultar desde fuera si el micrófono está activo
func is_active() -> bool:
	return mic_player.playing
