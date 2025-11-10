extends Node3D

@onready var fuego_node = $StaticBody3D/fuego # Assuming "fuego" is a direct child Node3D

func _ready() -> void:
	if fuego_node:
		fuego_node.visible = false

func mouse_interaction(player_node):
	# Toggle the visibility of the fuego node
	if fuego_node:
		fuego_node.visible = not fuego_node.visible
