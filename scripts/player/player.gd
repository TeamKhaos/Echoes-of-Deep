extends CharacterBody3D
#
@onready var Pivote = $Pivot
@onready var Camera = $Pivot/Camera3D
@onready var MouseRayCast = $Pivot/Camera3D/MouseRayCast
@onready var collision_shape = $CollisionShape3D
@onready var player_hud = $PlayerHUD
@onready var voice_controller = $Voice
@onready var hud = $PlayerHUD/hud
@onready var object_marker = $Pivot/Camera3D/ObjectMarker
# --- INVENTARIO GLOOT ---
@onready var inventory_scene = preload("res://scenes/player/inventario.tscn")
var inventory_instance: Node = null

#FLAGS
var can_move : bool = true
var on_debug := false
var is_crouching : bool = false

#MOVE
var max_speed = 5
var crouch_speed = 1.0
var acceleration = 0.5
var desaceleration = 0.5
var can_footstep : bool = true
var gravity = 25 #25

#CROUCH
var standing_height = 2.0
var crouching_height = 1.0

#STAIRS
const MAX_STEP_HEIGHT = 0.2
var _snaped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

func _ready():
	# --- Instanciar inventario de Gloot ---
	inventory_instance = inventory_scene.instantiate()
	if inventory_instance is Control:
		get_tree().get_root().call_deferred("add_child", inventory_instance)
		inventory_instance.visible = false
	else:
		call_deferred("add_child", inventory_instance)
	# ✅ Ahora que ya existe, asignarlo al HUD
	var inv_node = inventory_instance.get_node_or_null("Inventory") 
	
	#funcion items
	var items = inv_node.get_items()
	print("🔹 Total de ítems en inventario: funcion de player ", items)
	#funcion items
	
	hud.set_inventory(inv_node)
	# --- Resto de tu configuración ---
	GLOBAL.PlayerRef = self
	Camera.current = true
	can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GLOBAL.update_hud.emit()
	#Allow Player to move and capture mouse to game window
	can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	#Update and Connect Player UI
	GLOBAL.update_hud.emit()

	


func _physics_process(delta):
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	crouch()
	move(delta, get_input())

func _process(_delta):
	#Change to an action in Project -> Project Settings -> Input Map
	if Input.is_action_just_pressed("Microphone"):
		voice_controller.toggle_microphone()

	if Input.is_action_just_pressed("Drop"):
		if object_marker.get_child_count() > 0:
			var held_item = object_marker.get_child(0)
			if held_item.has_method("drop"):
				if "item_id" in held_item:
					remove_from_inventory(held_item.item_id)
				held_item.drop(object_marker.global_transform)

	if Input.is_action_just_pressed("Inventory"):
		if inventory_instance and inventory_instance is Control:
			inventory_instance.visible = !inventory_instance.visible

			can_move = not inventory_instance.visible
			Pivote.cameraLock = inventory_instance.visible

			# --- Mostrar u ocultar el mouse ---
			if inventory_instance.visible:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				# 🔻 Ocultar el HUD mientras el inventario esté abierto
				if player_hud:
					player_hud.visible = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				# 🔺 Mostrar el HUD nuevamente
				if player_hud:
					player_hud.visible = true



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

func crouch():
	if Input.is_action_pressed("Crouch"):
		is_crouching = true
		max_speed = crouch_speed
		collision_shape.shape.height = crouching_height
		Pivote.position.y = lerp(Pivote.position.y, 1.2, 0.1)
	else:
		is_crouching = false
		max_speed = 2
		collision_shape.shape.height = standing_height
		Pivote.position.y = lerp(Pivote.position.y, 1.6, 0.1)

func get_input():
	var input = Vector3()
	if can_move:
		if Input.is_action_pressed("Up"):
			input.z += 1
		if Input.is_action_pressed("Down"):
			input.z -= 1
		if Input.is_action_pressed("Left"):
			input.x += 1
		if Input.is_action_pressed("Right"):
			input.x -= 1
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

		
func add_to_inventory(item_id: String):
	if not inventory_instance:
		print("⚠️ Inventario no instanciado")
		return

	var inv_node = inventory_instance.get_node_or_null("Inventory")
	if not inv_node:
		print("⚠️ No se encontró el nodo InventoryPlayer dentro del inventario")
		return

	var protoset = load("res://resources/json/inventario.json")
	if not protoset:
		print("⚠️ No se pudo cargar el protoset de ítems")
		return

	var new_item := InventoryItem.new(protoset, item_id)

	if inv_node.has_method("add_item"):
		var success = inv_node.add_item(new_item)
		if success:
			print("📦 Añadido al inventario:", item_id)
			# 🔹 Actualizar HUD solo después de añadir el ítem
			if hud:
				hud.set_inventory(inv_node)
				print("🖼️ HUD actualizado tras añadir:", item_id)
		else:
			print("⚠️ No se pudo añadir el ítem (inventario lleno o inválido)")
	else:
		print("⚠️ El nodo InventoryPlayer no tiene el método add_item()")


func remove_from_inventory(item_id: String):
	if not inventory_instance:
		print("⚠️ Inventario no instanciado")
		return

	var inv_node = inventory_instance.get_node_or_null("Inventory")
	if not inv_node:
		print("⚠️ No se encontró el nodo InventoryPlayer dentro del inventario")
		return

	if inv_node.has_method("get_items") and inv_node.has_method("remove_item"):
		var items = inv_node.get_items()
		for item in items:
			if "_prototype" in item and item._prototype != null and "_id" in item._prototype and item._prototype._id == item_id:
				inv_node.remove_item(item)
				print("📦 Removido del inventario:", item_id)
				if hud:
					hud.set_inventory(inv_node)
					print("🖼️ HUD actualizado tras remover:", item_id)
				return # Exit after removing the first match
		print("⚠️ No se encontró el ítem con id:", item_id, " en el inventario")
	else:
		print("⚠️ El nodo InventoryPlayer no tiene los métodos get_items() o remove_item()")
