extends Node3D

@onready var fuego_node = $StaticBody3D/fuego
@onready var light_area = $LightArea  # Necesitas agregar este nodo
@export var is_lit: bool = false  # Si está encendida
@export var light_radius: float = 5.0  # Radio de influencia de luz

var players_in_range = []

func _ready() -> void:
	if fuego_node:
		fuego_node.visible = is_lit
	
	# Configurar área de luz si existe
	if not light_area:
		_create_light_area()
	
	_setup_light_area()

func _create_light_area():
	# Crear área de detección si no existe
	light_area = Area3D.new()
	light_area.name = "LightArea"
	add_child(light_area)
	
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = light_radius
	collision.shape = sphere
	light_area.add_child(collision)

func _setup_light_area():
	if not light_area:
		return
	
	# Conectar señales
	if not light_area.is_connected("body_entered", Callable(self, "_on_light_area_body_entered")):
		light_area.connect("body_entered", Callable(self, "_on_light_area_body_entered"))
	
	if not light_area.is_connected("body_exited", Callable(self, "_on_light_area_body_exited")):
		light_area.connect("body_exited", Callable(self, "_on_light_area_body_exited"))

func mouse_interaction(player_node):
	# Encender/apagar la fogata
	is_lit = not is_lit
	
	if fuego_node:
		fuego_node.visible = is_lit
	
	if is_lit:
		# Actualizar jugadores que ya están en el área
		for player in players_in_range:
			_notify_player_light_status(player, true)
	else:
		# Notificar a jugadores que la luz se apagó
		for player in players_in_range:
			_notify_player_light_status(player, false)

func _on_light_area_body_entered(body: Node3D):
	if body.is_in_group("player") or body.name == "Player":
		if body not in players_in_range:
			players_in_range.append(body)
		
		# Solo notificar si la fogata está encendida
		if is_lit:
			_notify_player_light_status(body, true)

func _on_light_area_body_exited(body: Node3D):
	if body.is_in_group("player") or body.name == "Player":
		if body in players_in_range:
			players_in_range.erase(body)
		
		_notify_player_light_status(body, false)

func _notify_player_light_status(player: Node3D, near_light: bool):
	# Notificar al jugador si está cerca de luz
	if player.has_node("PlayerHUD/hud"):
		var hud = player.get_node("PlayerHUD/hud")
		if hud.has_method("set_near_light"):
			hud.set_near_light(near_light and is_lit)
