extends RigidBody3D

@export var item_id: String = "bandage"

func mouse_interaction(player):
	var object_marker = player.get_node("ObjectMarker")
	if object_marker:
		global_transform = object_marker.global_transform
		freeze = true
