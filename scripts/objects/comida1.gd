extends RigidBody3D

@export var item_id: String = "food"
var original_scale: Vector3

func _ready():
	original_scale = scale

func mouse_interaction(player):
	player.add_to_inventory(item_id)
	var object_marker = player.object_marker
	if object_marker:
		get_parent().remove_child(self)
		object_marker.add_child(self)
		transform = Transform3D.IDENTITY
		scale *= 0.5
		# Rotar 90 grados en Y

		rotation.z = deg_to_rad(-90)
		freeze = true

func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	# Aplicar impulso hacia adelante
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)
