extends RigidBody3D

@export var item_id: String = "bandage"

func mouse_interaction(player):
	var object_marker = player.object_marker
	if object_marker:
		get_parent().remove_child(self)
		object_marker.add_child(self)
		transform = Transform3D.IDENTITY
		freeze = true
