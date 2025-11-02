extends Node
@export var interact_layer = 0b011
@export var MouseRayCast : Node3D
@onready var Cursor = get_tree().get_first_node_in_group("cursor")
#FLAGS
var can_interact := true
var current_object
var already_interacted := false

func _process(_delta):
	interact()
	check_if_looking()

func interact():
	var interaction_ray = MouseRayCast.calc_3D_interactions(interact_layer, 3)
	if interaction_ray:
		var collider = interaction_ray.collider
		if collider.is_in_group("interactable") and can_interact:
				collider.mouse_interaction()
				if current_object != collider: leave_interaction() #In case we see at other collider
				current_object = collider
				already_interacted = true
		elif already_interacted:
			leave_interaction()
	elif already_interacted:
		leave_interaction()

func leave_interaction():
	Cursor.decrese_cursor()
	if current_object != null and current_object.is_in_group("interactable"):
		current_object.on_mouse_exited()
	current_object = null
	already_interacted = false


func check_if_looking():
	var interaction_ray = MouseRayCast.calc_3D_interactions(0b011, 20)
	if interaction_ray:
		var collider = interaction_ray.collider
		if collider.is_in_group("lookable"):
				collider._on_look_event()
