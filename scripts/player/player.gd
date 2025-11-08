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

	


func equip_item_from_slot(slot_index: int):
	print("--- equip_item_from_slot called for slot: ", slot_index, " ---")
	var inv_node = inventory_instance.get_node_or_null("Inventory")
	if not inv_node:
		print("DEBUG: ⚠️ Inventory node not found.")
		return
	print("DEBUG: Inventory node found.")

	var items = inv_node.get_items()
	if slot_index >= items.size():
		print("DEBUG: ⚠️ Slot ", slot_index, " is empty or out of bounds. Items in inventory: ", items.size())
		return
	print("DEBUG: Item found in slot ", slot_index, ". Total items: ", items.size())

	var item_to_equip_from_inventory = items[slot_index]
	var item_id_to_equip = ""
	if item_to_equip_from_inventory and item_to_equip_from_inventory.has_method("get_prototype"):
		item_id_to_equip = item_to_equip_from_inventory.get_prototype().get("_id")
	print("DEBUG: Item to equip ID: ", item_id_to_equip)

	# 1. If an item is already in hand, just remove it.
	if object_marker.get_child_count() > 0:
		print("DEBUG: Object marker has children. Clearing held item.")
		for child in object_marker.get_children():
			child.queue_free()
	else:
		print("DEBUG: Object marker is empty. No item in hand.")

	# 2. Get item data from inventory and prepare to instantiate
	var proto = item_to_equip_from_inventory.get_prototype()
	if not proto or not proto.has_method("get"):
		print("DEBUG: ⚠️ Item prototype not found or missing 'get' method.")
		return
	print("DEBUG: Item prototype found.")

	var props = proto.get("_properties")
	if typeof(props) != TYPE_DICTIONARY or not props.has("scene"):
		print("DEBUG: ⚠️ Item prototype is missing 'scene' property for item: ", item_id_to_equip)
		return
	print("DEBUG: Item properties and 'scene' property found.")

	var scene_path = props["scene"]
	print("DEBUG: Scene path for item: ", scene_path)
	var item_scene = load(scene_path)
	if not item_scene:
		print("DEBUG: ⚠️ Failed to load item scene: ", scene_path)
		return
	print("DEBUG: Item scene loaded successfully.")

	# 3. Instantiate the new item and place it in the player's hand.
	print("DEBUG: Instantiating new item.")
	var new_item_instance = item_scene.instantiate()
	object_marker.add_child(new_item_instance)
	print("DEBUG: New item instantiated and added to object marker.")

	# 4. Configure the item's state
	print("DEBUG: Configuring new item's state.")
	# Let the item set its own held transform, or use a default
	if new_item_instance.has_method("set_held_transform"):
		new_item_instance.set_held_transform()
	else:
		new_item_instance.transform = Transform3D.IDENTITY
		new_item_instance.scale *= 0.4
	
	# More robustly disable physics
	if new_item_instance is RigidBody3D:
		new_item_instance.freeze = true
		new_item_instance.set_collision_layer_value(1, false)
		new_item_instance.set_collision_mask_value(1, false)
		print("DEBUG: Item is RigidBody3D. Freeze set and collision disabled.")
	
	print("DEBUG: New item state configured. --- End equip_item_from_slot ---")


func _physics_process(delta):
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()
	crouch()
	move(delta, get_input())

func _process(_delta):
	if Input.is_action_just_pressed("inventory1H"):
		equip_item_from_slot(0)
	if Input.is_action_just_pressed("inventory2H"):
		equip_item_from_slot(1)

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
