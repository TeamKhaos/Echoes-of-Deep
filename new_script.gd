extends CharacterBody3D

# --- NODOS ---
@onready var Pivote = $Pivot
@onready var Camera = $Pivot/Camera3D
@onready var MouseRayCast = $Pivot/Camera3D/MouseRayCast
@onready var PlayerSpotLight : SpotLight3D = $"../PlayerSpotLight3D"


# --- FLAGS ---
var can_move : bool = true
var can_jump : bool = true
var is_jumping : bool = false
var on_debug := false

# --- MOVE ---
var max_speed = 2
var sprint_speed = 2.5
var acceleration = 0.5
var desaceleration = 0.5
var can_footstep : bool = true

# --- JUMP ---
var max_height = 0.7
var jump_strength : float = 2
var reference_jump_height : float
var gravity = 25 #25

# --- STAIRS ---
const MAX_STEP_HEIGHT = 0.2
var _snaped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF


func _ready():
	# --- Instanciar inventario de Gloot ---
	inventory_instance = inventory_scene.instantiate()
	
	# Si es UI, lo agregamos al root para que esté siempre visible
	if inventory_instance is Control:
		get_tree().get_root().add_child(inventory_instance)
		inventory_instance.visible = false  # Oculto al inicio
	else:
		add_child(inventory_instance)
	
	print("Inventario instanciado:", inventory_instance.name)


func _physics_process(delta):
	if is_on_floor(): 
		_last_frame_was_on_floor = Engine.get_physics_frames()
	sprint()
	move(delta, get_input())
	flashlight_delay()


func _process(_delta):
	# Mostrar u ocultar inventario con tecla I
	if Input.is_action_just_pressed("inventario"):
		if inventory_instance and inventory_instance is Control:
			inventory_instance.visible = !inventory_instance.visible

			# Bloquear movimiento y cámara al abrir inventario
			can_move = not inventory_instance.visible
			Pivote.cameraLock = not inventory_instance.visible


# --- FUNCIONES DE MOVIMIENTO ---
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	%StairsBelowRaycast.force_raycast_update()
	var floor_below : bool = %StairsBelowRaycast.is_colliding() and not is_surface_too_step(%StairsBelowRaycast.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() == _last_frame_was_on_floor
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snaped_to_stairs_last_frame) and floor_below:
		var body_test_result = KinematicCollision3D.new()
		if self.test_move(self.global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			var translate_y = body_test_result.get_travel().y
			var tween : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "position", position + Vector3(0, translate_y, 0), 0.05)
			apply_floor_snap()
			did_snap = true
	_snaped_to_stairs_last_frame = did_snap


func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snaped_to_stairs_last_frame: return false
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") and down_check_result.get_collider().is_in_group("climbeable"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsRaycast.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%StairsRaycast.force_raycast_update()
		if %StairsRaycast.is_colliding() and not is_surface_too_step(%StairsRaycast.get_collision_normal()):
			var tween : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "global_position", step_pos_with_clearance.origin + down_check_result.get_travel(), 0.1)
			apply_floor_snap()
			_snaped_to_stairs_last_frame = true
			return true
	return false


func is_surface_too_step(normal : Vector3):
	return normal.angle_to(Vector3.UP) > self.floor_max_angle


func _run_body_test_motion(from: Transform3D, motion : Vector3, result = null):
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)


func flashlight_delay():
	var tween2 : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween2.tween_property(PlayerSpotLight, "global_transform", Camera.global_transform, 0.24)


func move(delta, input):
	var impulse = Vector3(
		transform.basis.x.x * input.x + transform.basis.z.x * input.z,
		0,
		transform.basis.x.z * input.x + transform.basis.z.z * input.z
		).normalized() * max_speed
	velocity.y -= gravity * delta
	if input.x != 0 or input.z != 0:
		play_footsteps()
		velocity.x = lerp(velocity.x, impulse.x, acceleration)
		velocity.z = lerp(velocity.z, impulse.z, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, desaceleration)
		velocity.z = lerp(velocity.z, 0.0, desaceleration)
	
	if not _snap_up_stairs_check(delta):
		move_and_slide()
		_snap_down_to_stairs_check()


func sprint():
	if(Input.is_action_pressed("Shift")):
		max_speed = sprint_speed
	else :
		max_speed = 2


func get_input():
	var input = Vector3()
	if can_move:
		if Input.is_action_pressed("W"):
			input.z += 1
		if Input.is_action_pressed("S"):
			input.z -= 1
		if Input.is_action_pressed("A"):
			input.x += 1
		if Input.is_action_pressed("D"):
			input.x -= 1
		if Input.is_action_pressed("Space"):
			input.y += 1
		if Input.is_action_pressed("Shift"):
			input.y -= 1
	return input


func play_footsteps():
	if can_footstep:
		var sound : String
		var creaking : String
		if $CheckFloorMaterialRay.get_collider() != null:
			if $CheckFloorMaterialRay.get_collider().is_in_group("wood"):
				$FootstepsPlayer.bus = "HighReverb"
				sound = "res://assets/audio/fx/footsteps/wood/" + str(randi() % 3 + 1) + ".mp3"
				creaking = "res://assets/audio/fx/footsteps/wood/c" + str(randi() % 3 + 1) + ".mp3"
				if((randi() % 10 + 1) == 3):
					$"FootstepsPlayer(creaking)".stream = load(creaking)
					$"FootstepsPlayer(creaking)".play()
			elif $CheckFloorMaterialRay.get_collider().is_in_group("grass"):
				$FootstepsPlayer.bus = "Master"
				sound = "res://assets/audio/fx/footsteps/grass/1.mp3"
				$FootstepsPlayer.pitch_scale = randf_range(0.7, 1)
			else:
				return
		else:
			return
		$FootstepsPlayer.stream = load(sound)
		$FootstepsPlayer.play()
		can_footstep = false
		$FootstepsTimer.start()


func desactivate():
	can_move = false
	Pivote.cameraLock = true


func activate():
	can_move = true
	Pivote.cameraLock = false


func _on_footsteps_timer_timeout():
	can_footstep = true


func _on_area_3d_body_entered(body: Node3D) -> void:
	if(body.is_in_group("player")):
		$"../AudioStreamPlayer3D".play()
		$"../Area3D".queue_free()


# --- AGREGAR ÍTEMS AL INVENTARIO ---
func add_to_inventory(item_id: String):
	if inventory_instance:
		var item_proto = preload("res://piedra.tres")  # ejemplo de ítem Gloot
		var inv_node = inventory_instance.get_node("Inventory") if inventory_instance.has_node("Inventory") else null
		if inv_node and inv_node.has_method("get_inventory"):
			inv_node.get_inventory().add_item(item_proto)
			print("🪨 Item agregado:", item_id)
