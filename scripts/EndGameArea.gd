extends Area3D
# Script para detectar cuando el jugador llega al final del juego

@export_file("*.ogv") var cinematic_video_path: String = "res://resources/video/Ending.ogv"
@export var main_menu_scene_path: String = "res://scenes/main_menu.tscn"

# Referencias a las pantallas
var white_flash_scene = preload("res://scenes/WhiteFlash.tscn")
var end_credits_scene = preload("res://scenes/EndCredits.tscn")

var player_in_area: bool = false
var game_ended: bool = false

func _ready():
	# Conectar señales del área
	body_entered.connect(_on_body_entered)
	
	# Configurar el CollisionShape3D
	# Asegurarse de que está en la capa correcta para detectar al jugador
	collision_layer = 0  # No colisiona con nada
	collision_mask = 1   # Solo detecta capa 1 (jugador)
	
	print("✅ Zona final configurada")

func _on_body_entered(body):
	print("🔍 Cuerpo detectado: ", body.name)
	
	# Prevenir activación múltiple
	if game_ended:
		print("⚠️ Juego ya terminado, ignorando...")
		return
	
	# Verificar que sea el jugador
	if body.name == "Player" or body.is_in_group("player"):
		print("🏁 ¡Jugador ha llegado al final!")
		game_ended = true
		_trigger_end_sequence(body)
	else:
		print("❌ No es el jugador, es: ", body.name)

func _trigger_end_sequence(player):
	# Desactivar controles del jugador
	if player.has_method("desactivate"):
		player.desactivate()
	
	# Iniciar secuencia: Destello -> Video -> Créditos -> Main Menu
	await _show_white_flash()
	await _play_cinematic()
	await _show_end_credits()
	_return_to_main_menu()

# ⚡ Destello blanco
func _show_white_flash():
	print("⚡ Mostrando destello blanco...")
	
	var flash_instance = white_flash_scene.instantiate()
	get_tree().current_scene.add_child(flash_instance)
	
	# Esperar a que termine el destello (1 segundo)
	await get_tree().create_timer(1.0).timeout

# 🎬 Reproducir cinemática
func _play_cinematic():
	print("🎬 Reproduciendo cinemática final...")
	
	# Verificar que el archivo existe
	if not ResourceLoader.exists(cinematic_video_path):
		push_error("⚠️ No se encontró el video en: " + cinematic_video_path)
		print("⚠️ Saltando cinemática...")
		await get_tree().create_timer(0.5).timeout
		return
	
	# Crear contenedor de video (Control node para UI)
	var video_container = Control.new()
	video_container.anchor_left = 0
	video_container.anchor_top = 0
	video_container.anchor_right = 1
	video_container.anchor_bottom = 1
	video_container.z_index = 99
	
	# Crear VideoStreamPlayer
	var video_player = VideoStreamPlayer.new()
	video_player.stream = load(cinematic_video_path)
	
	# Configuración para pantalla completa
	video_player.anchor_left = 0
	video_player.anchor_top = 0
	video_player.anchor_right = 1
	video_player.anchor_bottom = 1
	video_player.expand = true
	
	# Configurar audio
	video_player.volume_db = 0
	video_player.autoplay = false
	
	# Añadir al árbol
	video_container.add_child(video_player)
	get_tree().root.add_child(video_container)
	
	# Pequeña pausa para que se inicialice
	await get_tree().create_timer(0.1).timeout
	
	# Reproducir video
	video_player.play()
	print("▶️ Video reproduciéndose...")
	
	# Esperar a que termine el video
	await video_player.finished
	
	print("✅ Cinemática finalizada")
	video_container.queue_free()

# 📜 Mostrar pantalla de créditos
func _show_end_credits():
	print("📜 Mostrando créditos finales...")
	
	var credits_instance = end_credits_scene.instantiate()
	get_tree().current_scene.add_child(credits_instance)
	
	# Esperar 5 segundos (o lo que dure tu pantalla de créditos)
	await get_tree().create_timer(5.0).timeout
	
	credits_instance.queue_free()

# 🔙 Volver al menú principal
func _return_to_main_menu():
	print("🔙 Volviendo al menú principal...")
	
	# Pequeña pausa antes de cambiar escena
	await get_tree().create_timer(0.5).timeout
	
	# Cambiar a la escena del menú principal
	if ResourceLoader.exists(main_menu_scene_path):
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		push_error("⚠️ No se encontró el menú principal en: " + main_menu_scene_path)
		get_tree().quit()
