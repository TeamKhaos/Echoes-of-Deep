extends CanvasLayer

# ===============================
# ⏸️ MENÚ DE PAUSA
# ===============================

# Configuración
@export_file("*.tscn") var main_menu_path: String = "res://scenes/main_menu.tscn"
@export var pause_key: Key = KEY_ESCAPE

# Nodos principales
@onready var pause_panel = $CenterContainer/PausePanel
@onready var confirm_dialog = $ConfirmDialog
@onready var options_panel = $OptionsPanel
@onready var animation_player = $AnimationPlayer

# Nodos de opciones
@onready var master_volume_slider = $OptionsPanel/CenterContainer/OptionsContainer/MarginContainer/VBoxContainer/MasterVolumeSlider
@onready var music_volume_slider = $OptionsPanel/CenterContainer/OptionsContainer/MarginContainer/VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $OptionsPanel/CenterContainer/OptionsContainer/MarginContainer/VBoxContainer/SFXVolumeSlider

# Estado
var is_paused: bool = false

# ===============================
# INICIALIZACIÓN
# ===============================

func _ready():
	# Ocultar todo al inicio
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Cargar configuración
	_load_settings()
	

func _input(event):
	# Detectar tecla de pausa
	if event is InputEventKey:
		if event.pressed and event.keycode == pause_key:
			if not is_paused:
				pause_game()
			else:
				resume_game()

# ===============================
# CONTROL DE PAUSA
# ===============================

func pause_game():
	if is_paused:
		return
	
	is_paused = true
	visible = true
	
	# Pausar el juego
	get_tree().paused = true
	
	# Mostrar cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Animación de entrada
	animation_player.play("show")
	
	# Asegurar que los paneles secundarios estén ocultos
	confirm_dialog.visible = false
	options_panel.visible = false
	

func resume_game():
	if not is_paused:
		return
	
	# Animación de salida
	animation_player.play("hide")
	await animation_player.animation_finished
	
	is_paused = false
	visible = false
	
	# Despausar el juego
	get_tree().paused = false
	
	# Ocultar cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	

# ===============================
# BOTONES DEL MENÚ PRINCIPAL
# ===============================

func _on_button_resume_pressed():
	resume_game()

func _on_button_options_pressed():
	_show_panel(options_panel)

func _on_button_main_menu_pressed():
	_show_confirm_dialog()

# ===============================
# DIÁLOGO DE CONFIRMACIÓN
# ===============================

func _show_confirm_dialog():
	confirm_dialog.visible = true
	confirm_dialog.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(confirm_dialog, "modulate:a", 1.0, 0.2)

func _hide_confirm_dialog():
	var tween = create_tween()
	tween.tween_property(confirm_dialog, "modulate:a", 0.0, 0.2)
	await tween.finished
	confirm_dialog.visible = false

func _on_button_cancel_pressed():
	_hide_confirm_dialog()

func _on_button_confirm_pressed():
	
	# Fade out
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0
	add_child(fade)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Despausar antes de cambiar de escena
	get_tree().paused = false
	
	# Cambiar al menú principal
	get_tree().change_scene_to_file(main_menu_path)

# ===============================
# PANEL DE OPCIONES
# ===============================

func _on_button_back_options_pressed():
	_hide_panel(options_panel)

func _on_master_volume_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index != -1:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, db)
	_save_settings()

func _on_music_volume_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Music")
	if bus_index != -1:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, db)
	_save_settings()

func _on_sfx_volume_changed(value: float):
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index != -1:
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_index, db)
	_save_settings()

# ===============================
# GESTIÓN DE PANELES
# ===============================

func _show_panel(panel: Control):
	panel.visible = true
	panel.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _hide_panel(panel: Control):
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished
	panel.visible = false

# ===============================
# SISTEMA DE CONFIGURACIÓN
# ===============================

func _save_settings():
	var config = ConfigFile.new()
	
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	
	config.save("user://settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		if config.has_section_key("audio", "master_volume"):
			var master_vol = config.get_value("audio", "master_volume")
			master_volume_slider.value = master_vol
			_on_master_volume_changed(master_vol)
		
		if config.has_section_key("audio", "music_volume"):
			var music_vol = config.get_value("audio", "music_volume")
			music_volume_slider.value = music_vol
			_on_music_volume_changed(music_vol)
		
		if config.has_section_key("audio", "sfx_volume"):
			var sfx_vol = config.get_value("audio", "sfx_volume")
			sfx_volume_slider.value = sfx_vol
			_on_sfx_volume_changed(sfx_vol)

# ===============================
# API PÚBLICA
# ===============================

# Llamar desde otros scripts si es necesario
func toggle_pause():
	if is_paused:
		resume_game()
	else:
		pause_game()
