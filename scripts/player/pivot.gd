extends Node3D

var mouse_delta = Vector2()
var min_look_angle : float = -75
var max_look_angle : float = 80
var cameraLock : bool = false
@onready var player = $".."
@onready var camera = $Camera3D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if !cameraLock:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.rotate_y(deg_to_rad(-event.relative.x * GLOBAL.look_sensitivity))
			rotate_x(deg_to_rad(event.relative.y * GLOBAL.look_sensitivity))
			rotation_degrees.x = clamp(rotation_degrees.x, -89, 89)
	if event.is_action_pressed("right_click"):
		var tween : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "fov", 40, 0.3)
	if event.is_action_released("right_click"):
		var tween : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "fov", 60, 0.3)
