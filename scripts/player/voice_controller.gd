extends Node3D

@onready var mic_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var reverb_area: Area3D = $AudioStreamPlayer3D/Area3D

var in_reverb_zone := false

func _ready():
	var mic_stream = AudioStreamMicrophone.new()
	mic_player.stream = mic_stream
	mic_player.unit_size = 2.0
	mic_player.stop()
	print("🎤 Dispositivo de entrada actual:", AudioServer.input_device)
	# Conectar detección de zonas
	reverb_area.connect("area_entered", Callable(self, "_on_area_entered"))
	reverb_area.connect("area_exited", Callable(self, "_on_area_exited"))

func toggle_microphone():
	if mic_player.playing:
		mic_player.stop()
	else:
		mic_player.play()

func _on_area_entered(area: Area3D):
	if area.is_in_group("reverb_zone"):
		print("🎤 area de reverb")
		
		in_reverb_zone = true
		var bus_index = AudioServer.get_bus_index("VoiceBus")
		AudioServer.set_bus_effect_enabled(bus_index, 0, true)  # Activar reverb


func _on_area_exited(area: Area3D):
	if area.is_in_group("reverb_zone"):
		print("🎤 area de reverb salida")
		in_reverb_zone = false
		var bus_index = AudioServer.get_bus_index("VoiceBus")
		AudioServer.set_bus_effect_enabled(bus_index, 0, false)  # Desactivar reverb
