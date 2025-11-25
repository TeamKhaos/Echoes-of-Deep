extends Control

# ===============================
# 🎮 CONFIGURACIÓN DEL MENÚ
# ===============================

# Rutas de escenas
@export_file("*.tscn") var game_scene_path: String = "res://scenes/plataforma.tscn"
@export_file("*.tscn") var demo_scene_path: String = "res://scenes/plataforma.tscn"

# Rutas de logos (configura estas en el Inspector)
@export var developer_logo: Texture2D
@export var gamejam_logo: Texture2D
@export var background_image: Texture2D

# Configuración de audio
@export var menu_music: AudioStream
@export var button_hover_sound: AudioStream
@export var button_click_sound: AudioStream

# Nodos
@onready var credits_panel = $CreditsPanel
@onready var options_panel = $OptionsPanel
@onready var main_menu_container = $CenterContainer
@onready var developer_logo_node = $DeveloperLogo
@onready var gamejam_logo_node = $GameJamLogo
@onready var background_texture = $Background/BackgroundTexture
@onready var music_player = $AudioStreamPlayer

# Sliders de volumen
@onready var master_volume_slider = $OptionsPanel/CenterContainer/VBoxContainer/MasterVolumeSlider
@onready var music_volume_slider = $OptionsPanel/CenterContainer/VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $OptionsPanel/CenterContainer/VBoxContainer/SFXVolumeSlider
@onready var fullscreen_checkbox = $OptionsPanel/CenterContainer/VBoxContainer/FullscreenCheckbox

# Variables
var save_file_path = "user://savegame.save"

# ===============================
# INICIALIZACIÓN
# ===============================

func _ready():
	# Configurar cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Cargar recursos visuales
	_load_visual_resources()
	
	# Cargar configuración guardada
	_load_settings()
	
	# Reproducir música del menú
	if menu_music:
		music_player.stream = menu_music
		music_player.play()
	
	# Configurar hover effects en botones
	_setup_button_effects()
	

func _load_visual_resources():
	# Cargar logo del desarrollador
	if developer_logo and developer_logo_node:
		developer_logo_node.texture = developer_logo
	
	# Cargar logo de game jam
	if gamejam_logo and gamejam_logo_node:
		gamejam_logo_node.texture = gamejam_logo
	
	# Cargar imagen de fondo
	if background_image and background_texture:
		background_texture.texture = background_image
		background_texture.visible = true

func _setup_button_effects():
	# Agregar efectos de hover a todos los botones
	var buttons = get_tree().get_nodes_in_group("menu_buttons")
	for button in buttons:
		if button is Button:
			button.mouse_entered.connect(_on_button_hover.bind(button))

func _on_button_hover(button: Button):
	# Reproducir sonido de hover si está disponible
	if button_hover_sound:
		var audio = AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = button_hover_sound
		audio.volume_db = -10
		audio.play()
		await audio.finished
		audio.queue_free()

# ===============================
# BOTONES DEL MENÚ PRINCIPAL
# ===============================

func _on_button_new_game_pressed():
	_play_button_sound()
	
	# Fade out opcional
	await _fade_transition()
	
	# Cambiar a la escena del juego
	if ResourceLoader.exists(demo_scene_path):
		get_tree().change_scene_to_file(demo_scene_path)
	else:
		print("exit")

func _on_button_load_game_pressed():
	_play_button_sound()
	
	if _save_exists():
		_load_game()


func _on_button_options_pressed():
	_play_button_sound()
	_show_panel(options_panel)

func _on_button_credits_pressed():
	_play_button_sound()
	_show_panel(credits_panel)

func _on_button_quit_pressed():
	_play_button_sound()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

# ===============================
# PANEL DE OPCIONES
# ===============================

func _on_button_back_options_pressed():
	_play_button_sound()
	_hide_panel(options_panel)

func _on_master_volume_changed(value: float):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_save_settings()

func _on_music_volume_changed(value: float):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
	_save_settings()

func _on_sfx_volume_changed(value: float):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)
	_save_settings()

func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

# ===============================
# PANEL DE CRÉDITOS
# ===============================

func _on_button_back_credits_pressed():
	_play_button_sound()
	_hide_panel(credits_panel)

# ===============================
# SISTEMA DE GUARDADO
# ===============================

func _save_exists() -> bool:
	return FileAccess.file_exists(save_file_path)

func _load_game():
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		# Aquí cargarías los datos del jugador
		
		# Cambiar a la escena con los datos cargados
		if ResourceLoader.exists(game_scene_path):
			get_tree().change_scene_to_file(game_scene_path)


func _save_settings():
	var config = ConfigFile.new()
	
	# Guardar volúmenes
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	
	# Guardar pantalla completa
	config.set_value("video", "fullscreen", fullscreen_checkbox.button_pressed)
	
	config.save("user://settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Cargar volúmenes
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
		
		# Cargar pantalla completa
		if config.has_section_key("video", "fullscreen"):
			var is_fullscreen = config.get_value("video", "fullscreen")
			fullscreen_checkbox.button_pressed = is_fullscreen
			_on_fullscreen_toggled(is_fullscreen)

# ===============================
# UTILIDADES
# ===============================

func _show_panel(panel: Control):
	main_menu_container.visible = false
	panel.visible = true
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _hide_panel(panel: Control):
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished
	panel.visible = false
	main_menu_container.visible = true

func _fade_transition():
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0
	add_child(fade)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tween.finished

func _play_button_sound():
	if button_click_sound:
		var audio = AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = button_click_sound
		audio.volume_db = -5
		audio.play()
		await audio.finished
		audio.queue_free()
