extends RigidBody3D

@export var item_id: String = "water"
var original_scale: Vector3
@onready var mesh = $Botella/Plane

var outlined_material: Material
var base_materials := []

func _ready():
	original_scale = scale

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
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
