extends CanvasLayer

# Referencias a nodos UI
@onready var control = $Control
@onready var animation_player = $AnimationPlayer
@onready var game_over_label = $Control/CenterContainer/VBoxContainer/GameOverLabel
@onready var btn_retry = $Control/CenterContainer/VBoxContainer/BtnRetry
@onready var btn_main_menu = $Control/CenterContainer/VBoxContainer/BtnMainMenu
@onready var btn_quit = $Control/CenterContainer/VBoxContainer/BtnQuit
@onready var fade_overlay = $Control/FadeOverlay
@onready var death_sound = $DeathSound

# Rutas configurables
@export var main_menu_scene: String = "res://scenes/menus/main_menu.tscn"
@export var game_scene: String = ""  # Se auto-detecta la escena actual

var can_interact: bool = false

func _ready():
	# Ocultar todo al inicio
	visible = false
	if control:
		control.modulate.a = 0
	
	# Conectar botones
	if btn_retry:
		btn_retry.pressed.connect(_on_retry_pressed)
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
	
	# Desactivar botones hasta que termine la animación
	_set_buttons_enabled(false)
	
	# Obtener la escena actual si no está configurada
	if game_scene.is_empty():
		game_scene = get_tree().current_scene.scene_file_path
	
	print("✅ GameOver inicializado correctamente")

func show_game_over():
	print("🎮 Mostrando pantalla de Game Over")
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Reproducir sonido de muerte
	if death_sound and death_sound.stream:
		death_sound.play()
	
	# Fade in
	if control:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(control, "modulate:a", 1.0, 1.5)
		tween.tween_callback(_enable_buttons)
	else:
		_enable_buttons()

func _enable_buttons():
	can_interact = true
	_set_buttons_enabled(true)
	btn_retry.grab_focus()

func _set_buttons_enabled(enabled: bool):
	btn_retry.disabled = not enabled
	btn_main_menu.disabled = not enabled
	btn_quit.disabled = not enabled

func _on_retry_pressed():
	if not can_interact:
		return
	
	can_interact = false
	_fade_out_and_reload()

func _on_main_menu_pressed():
	if not can_interact:
		return
	
	can_interact = false
	_fade_out_and_change_scene(main_menu_scene)

func _on_quit_pressed():
	if not can_interact:
		return
	
	get_tree().quit()

func _fade_out_and_reload():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	tween.tween_callback(_reload_scene)

func _fade_out_and_change_scene(scene_path: String):
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): _change_scene(scene_path))

func _reload_scene():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _change_scene(scene_path: String):
	get_tree().paused = false
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("⚠️ La escena no existe: " + scene_path)
		get_tree().reload_current_scene()
