extends CharacterBody3D

@onready var Pivote = $Pivot
@onready var Camera = $Pivot/Camera3D
@onready var MouseRayCast = $Pivot/Camera3D/MouseRayCast
@onready var collision_shape = $CollisionShape3D
@onready var player_hud = $PlayerHUD
@onready var voice_controller = $Voice
@onready var voiceparticle = $VoiceWave

@onready var hud = $PlayerHUD/hud
@onready var object_marker = $Pivot/Camera3D/ObjectMarker

# 👟 Sistema de pasos
@onready var footsteps_player = $FootstepsPlayer
@onready var footsteps_timer = $FootstepsTimer

# ⏸️ Menú de pausa
@onready var pause_menu = $PauseMenu

# --- INVENTARIO GLOOT ---
@onready var inventory_scene = preload("res://scenes/player/inventario.tscn")
var inventory_instance: Node = null

#---VIDA----
@export var max_health: int = 100
var current_health: int = 100

#FLAGS
var can_move : bool = true
var on_debug := false
var is_crouching : bool = false

#MOVE
var max_speed = 5
var crouch_speed = 1.0
var acceleration = 0.5
var desaceleration = 0.5
var gravity = 25

#CROUCH
var standing_height = 2.0
var crouching_height = 1.0

#STAIRS
const MAX_STEP_HEIGHT = 0.2
var _snaped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF

# 👟 Variables de control de pasos
var can_footstep: bool = true
var is_moving: bool = false

# Configuración de pasos
@export_group("Footsteps Settings")
@export var footstep_sound: AudioStream
@export var base_footstep_interval: float = 0.45
@export var crouch_footstep_interval: float = 0.65
@export var footstep_volume_db: float = -10.0
@export var pitch_variation: float = 0.15

func _ready():
	# --- Instanciar inventario de Gloot ---
	inventory_instance = inventory_scene.instantiate()
	if inventory_instance is Control:
		get_tree().get_root().call_deferred("add_child", inventory_instance)
		inventory_instance.visible = false
	else:
		call_deferred("add_child", inventory_instance)
	
	var inv_node = inventory_instance.get_node_or_null("Inventory") 
	var items = inv_node.get_items()
	print("🔹 Total de ítems en inventario: funcion de player ", items)
	
	hud.set_inventory(inv_node)
	voice_controller.microphone_toggled.connect(hud._on_microphone_toggled)
	
	# --- Resto de tu configuración ---
	GLOBAL.PlayerRef = self
	Camera.current = true
	can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GLOBAL.update_hud.emit()
	
	# 👟 Configurar sistema de pasos
	_setup_footsteps()

func _setup_footsteps():
	if footsteps_player:
		footsteps_player.volume_db = footstep_volume_db
		footsteps_player.max_distance = 15.0
		footsteps_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		footsteps_player.unit_size = 1.0
		
	if footsteps_timer:
		footsteps_timer.one_shot = true
		footsteps_timer.wait_time = base_footstep_interval
		if not footsteps_timer.is_connected("timeout", Callable(self, "_on_footsteps_timer_timeout")):
			footsteps_timer.connect("timeout", Callable(self, "_on_footsteps_timer_timeout"))
	
	

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

	if object_marker.get_child_count() > 0:
		print("DEBUG: Object marker has children. Clearing held item.")
		for child in object_marker.get_children():
			child.queue_free()
	else:
		print("DEBUG: Object marker is empty. No item in hand.")

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

	print("DEBUG: Instantiating new item.")
	var new_item_instance = item_scene.instantiate()
	object_marker.add_child(new_item_instance)
	print("DEBUG: New item instantiated and added to object marker.")

	print("DEBUG: Configuring new item's state.")
	if new_item_instance.has_method("set_held_transform"):
		new_item_instance.set_held_transform()
	else:
		new_item_instance.transform = Transform3D.IDENTITY
		new_item_instance.scale *= 0.4
	
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

func _input(event):
	# ⏸️ DETECCIÓN DE PAUSA CON ESC
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if pause_menu:
				if not pause_menu.is_paused:
					pause_menu.pause_game()
				else:
					pause_menu.resume_game()
			get_viewport().set_input_as_handled()

func _process(_delta):
	# ⏸️ No procesar inputs si el juego está pausado
	if pause_menu and pause_menu.is_paused:
		return
	
	if Input.is_action_just_pressed("inventory1H"):
		equip_item_from_slot(0)
	if Input.is_action_just_pressed("inventory2H"):
		equip_item_from_slot(1)
	
	if Input.is_action_just_pressed("Microphone"):
		voice_controller.toggle_microphone()
	
	if voice_controller.is_active():
		voiceparticle.visible = true
	else:
		voiceparticle.visible = false
	
	if Input.is_key_pressed(KEY_R):
		_try_consume_held_item()
	
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

			if inventory_instance.visible:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				if player_hud:
					player_hud.visible = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				if player_hud:
					player_hud.visible = true

func _try_consume_held_item():
	if not object_marker:
		return
	
	if object_marker.get_child_count() == 0:
		print("⚠️ No tienes nada en la mano para consumir")
		return
	
	var held_item = object_marker.get_child(0)
	
	if not held_item.has_method("consume"):
		print("⚠️ Este ítem NO tiene el método consume()")
		return
	
	if "is_consumable" in held_item:
		if not held_item.is_consumable:
			print("⚠️ Este ítem no es consumible")
			return
	
	var success = held_item.consume(self)
	
	if success:
		print("✅ Ítem consumido exitosamente")
		if "item_id" in held_item:
			remove_from_inventory(held_item.item_id)





func is_surface_too_step(normal : Vector3):
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

func move(delta, input):
	var impulse = Vector3(
		transform.basis.x.x * input.x + transform.basis.z.x * input.z,
		0,
		transform.basis.x.z * input.x + transform.basis.z.z * input.z
	).normalized() * max_speed
	
	velocity.y -= gravity * delta
	
	# 👟 Detectar movimiento
	is_moving = (input.x != 0 or input.z != 0) and is_on_floor()
	
	if is_moving:
		_play_footsteps()
		velocity.x = lerp(velocity.x, impulse.x, acceleration)
		velocity.z = lerp(velocity.z, impulse.z, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, desaceleration)
		velocity.z = lerp(velocity.z, 0.0, desaceleration)
	

	move_and_slide()
		

func _play_footsteps():
	if not can_footstep or not footsteps_player:
		return
	
	if not footsteps_player.stream and footstep_sound:
		footsteps_player.stream = footstep_sound
	elif not footsteps_player.stream:
		var default_path = "res://resources/audio/pasos.mp3"
		if ResourceLoader.exists(default_path):
			footsteps_player.stream = load(default_path)
		else:
			return
	
	footsteps_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	
	var speed_factor = velocity.length() / max_speed
	footsteps_player.volume_db = footstep_volume_db + (speed_factor * 3.0)
	
	footsteps_player.play()
	can_footstep = false
	
	var interval = crouch_footstep_interval if is_crouching else base_footstep_interval
	interval = interval / max(speed_factor, 0.5)
	
	footsteps_timer.wait_time = interval
	footsteps_timer.start()

func _on_footsteps_timer_timeout():
	can_footstep = true

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

func desactivate():
	can_move = false
	Pivote.cameraLock = true

func activate():
	can_move = true
	Pivote.cameraLock = false

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
				return
		print("⚠️ No se encontró el ítem con id:", item_id, " en el inventario")
	else:
		print("⚠️ El nodo InventoryPlayer no tiene los métodos get_items() o remove_item()")

func take_damage(amount: int):
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = clamp(current_health, 0, max_health)
	update_health_bar()

func update_health_bar():
	if hud and hud.has_method("set_health"):
		hud.set_health(current_health)

func die():
	print("💀 El jugador ha muerto")
