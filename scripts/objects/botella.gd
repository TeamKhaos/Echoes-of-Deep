extends RigidBody3D

@export var item_id: String = "water"
var original_scale: Vector3
@onready var mesh = $Botella/Plane

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
		
		# Guarda el material de brillo o delineado (por ejemplo surface 3)
		outlined_material = mesh_res.surface_get_material(3)

		# Empieza desactivado
		mesh_res.surface_set_material(3, null)



func set_highlight(active: bool):
	var mesh_res = mesh.mesh
	if not mesh_res:
		return
	
	if active:
		mesh_res.surface_set_material(3, outlined_material)
	else:
		mesh_res.surface_set_material(3, null)



func mouse_interaction(player):
	set_highlight(false)
	player.add_to_inventory(item_id)
	var object_marker = player.object_marker
	if object_marker:
		# If the player is already holding an object, destroy it.
		if object_marker.get_child_count() > 0:
			for child in object_marker.get_children():
				child.queue_free()

		# Now, pick up the new object.
		get_parent().remove_child(self)
		object_marker.add_child(self)
		set_held_transform()
		freeze = true


func set_held_transform():
	# Esta función define la apariencia del objeto en la mano del jugador
	transform = Transform3D.IDENTITY
	scale *= 0.4


func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	
	# Re-enable collision so it doesn't fall through the world
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
