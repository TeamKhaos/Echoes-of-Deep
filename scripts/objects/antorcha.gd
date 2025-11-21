extends RigidBody3D
@onready var particula: Node3D = $particula
@onready var LIGHT: OmniLight3D = $particula/fuegoprimario/OmniLight3D
@export var item_id: String = "palo" # Changed item_id to "palo"
var original_scale: Vector3
# --- NOTA: Puede que necesites actualizar esta ruta al nodo de tu malla (Mesh) ---
# --- LÓGICA DE ILUMINACIÓN (COMENTADA) ---
@onready var mesh = $Torch
var outlined_material: Material
var base_materials := []

func _ready():
	original_scale = scale

	
	if mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()
	
	var mesh_res = mesh.mesh  # el recurso Mesh interno
	if mesh_res:
		for i in range(mesh_res.get_surface_count()):
			base_materials.append(mesh_res.surface_get_material(i))
		
		outlined_material = mesh_res.surface_get_material(2)
		# Empieza desactivado
		mesh_res.surface_set_material(2, null)

func set_highlight(active: bool):
	print("--- set_highlight llamado con: ", active, " ---")
	
	if not mesh:
		print("ERROR: La variable 'mesh' es nula.")
		return
	print("INFO: 'mesh' es: ", mesh.get_path())

	var mesh_res = mesh.mesh
	if not mesh_res:
		print("ERROR: 'mesh.mesh' (el recurso Mesh) es nulo.")
		return
	print("INFO: Recurso Mesh: ", mesh_res)
	print("INFO: Material de borde: ", outlined_material)
	
	if active:
		print("ACCION: Activando borde en superficie 2.")
		mesh_res.surface_set_material(2, outlined_material)
	else:
		print("ACCION: Desactivando borde en superficie 2.")
		mesh_res.surface_set_material(2, null)
	
	var current_material = mesh_res.surface_get_material(2)
	print("VERIFICACION: Material actual en superficie 2: ", current_material)
	print("-------------------------------------------")
		

func mouse_interaction(player):
	set_highlight(false) # LÓGICA DE ILUMINACIÓN (COMENTADA)
	player.add_to_inventory(item_id)
	var object_marker = player.object_marker
	if object_marker:
		# Si el jugador ya tiene un objeto, lo destruye.
		if object_marker.get_child_count() > 0:
			for child in object_marker.get_children():
				child.queue_free()

		# Ahora, recoge el nuevo objeto.
		get_parent().remove_child(self)
		object_marker.add_child(self)
		transform = Transform3D.IDENTITY
		scale *= 0.4
		# Desactivar colisión para que el RayCast no lo detecte en la mano
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		freeze = true
		particula.visible = true  # 🔥 Activar partícula al recoger


func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	particula.visible = false  # ❌ Desactivar partícula al soltar
	# Reactiva la colisión para que no atraviese el mundo
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
