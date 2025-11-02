extends StaticBody3D

@export var item_id: String = "piedra"

func mouse_interaction(player):
	print("✅ Recogiste:", item_id)
	player.add_to_inventory(item_id)
	queue_free()
