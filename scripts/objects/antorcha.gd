extends RigidBody3D

@onready var particula: Node3D = $particula
@onready var LIGHT: OmniLight3D = $particula/fuegoprimario/OmniLight3D
@export var item_id: String = "palo"
var original_scale: Vector3

@onready var mesh = $Torch
var outlined_material: Material
var base_materials := []

func _ready():
	original_scale = scale
	
	if mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()
	
	var mesh_res = mesh.mesh
	if mesh_res:
		for i in range(mesh_res.get_surface_count()):
			base_materials.append(mesh_res.surface_get_material(i))
		
		outlined_material = mesh_res.surface_get_material(2)
		mesh_res.surface_set_material(2, null)

func set_highlight(active: bool):
	if not mesh:
		return
	
	var mesh_res = mesh.mesh
	if not mesh_res:
		return
	
	if active:
		mesh_res.surface_set_material(2, outlined_material)
	else:
		mesh_res.surface_set_material(2, null)

func mouse_interaction(player):
	set_highlight(false)
	player.add_to_inventory(item_id)
	var object_marker = player.object_marker
	if object_marker:
		if object_marker.get_child_count() > 0:
			for child in object_marker.get_children():
				child.queue_free()
		
		get_parent().remove_child(self)
		object_marker.add_child(self)
		transform = Transform3D.IDENTITY
		scale *= 0.4
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, false)
		freeze = true
		particula.visible = true

func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	particula.visible = false
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
