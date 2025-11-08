extends RigidBody3D

@export var item_id: String = "palo" # Changed item_id to "palo"
var original_scale: Vector3
# --- NOTA: Puede que necesites actualizar esta ruta al nodo de tu malla (Mesh) ---
@onready var mesh = $MeshInstance3D 

# --- LÓGICA DE ILUMINACIÓN (COMENTADA) ---
# var outlined_material: Material
# var base_materials := []

func _ready():
	original_scale = scale

	# --- LÓGICA DE ILUMINACIÓN (COMENTADA) ---
	# if mesh.mesh:
	# 	mesh.mesh = mesh.mesh.duplicate()
	# 
	# var mesh_res = mesh.mesh
	# 
	# if mesh_res:
	# 	for i in range(mesh_res.get_surface_count()):
	# 		base_materials.append(mesh_res.surface_get_material(i))
	# 	
	# 	# Esto asume que el material de resaltado está en un índice de superficie específico
	# 	outlined_material = mesh_res.surface_get_material(1) # Ajusta el índice si es necesario
	# 
	# 	# Empezar con el resaltado desactivado
	# 	mesh_res.surface_set_material(1, null) # Ajusta el índice si es necesario


# --- LÓGICA DE ILUMINACIÓN (COMENTADA) ---
# func set_highlight(active: bool):
# 	var mesh_res = mesh.mesh
# 	if not mesh_res:
# 		return
# 	
# 	if active:
# 		mesh_res.surface_set_material(1, outlined_material) # Ajusta el índice si es necesario
# 	else:
# 		mesh_res.surface_set_material(1, null) # Ajusta el índice si es necesario


func mouse_interaction(player):
	# set_highlight(false) # LÓGICA DE ILUMINACIÓN (COMENTADA)
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
		freeze = true


func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	
	# Reactiva la colisión para que no atraviese el mundo
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
