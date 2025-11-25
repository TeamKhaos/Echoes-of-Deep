extends Node

@export var interact_layer = 0b011
@export var MouseRayCast : Node3D
@export var hud : Node # <- asignado desde el editor, no lo toques en código

var can_interact := true
var current_object : Node3D
var already_interacted := false
var last_interactable : Node3D = null



func _process(_delta):
	if hud == null:
		return
	
	# Un solo raycast por frame (más rendimiento y consistencia)
	var interaction_ray = MouseRayCast.calc_3D_interactions(interact_layer, 20)
	
	# Se usan los mismos datos para ambas comprobaciones
	interact(interaction_ray)
	check_if_looking(interaction_ray)


func interact(interaction_ray):
	var new_interactable = null
	
	if interaction_ray:
		var collider = interaction_ray.collider
		if collider.is_in_group("interactable") and can_interact:
			# Prioriza método en el propio collider, o su owner si lo tiene
			if collider.has_method("mouse_interaction"):
				new_interactable = collider
			elif collider.get_owner() and collider.get_owner().has_method("mouse_interaction"):
				new_interactable = collider.get_owner()
	
	# Cambio de objetivo interactuable
	if new_interactable != last_interactable:
		if last_interactable:
			if last_interactable.has_method("set_highlight"):
				last_interactable.set_highlight(false)
			hud.show_interact_prompt(false)
			hud.set_crosshair_interact(false)
		
		if new_interactable:
			if new_interactable.has_method("set_highlight"):
				new_interactable.set_highlight(true)
			hud.set_crosshair_interact(true)
			hud.show_interact_prompt(true)
		
		last_interactable = new_interactable
	
	# Si se presiona el botón de interacción
	if last_interactable and Input.is_action_just_pressed("Interact") and not already_interacted:
		last_interactable.mouse_interaction(get_parent())
		current_object = last_interactable
		already_interacted = true
		leave_interaction()


func leave_interaction():
	current_object = null
	last_interactable = null
	already_interacted = false
	if hud:
		hud.set_crosshair_interact(false)
		hud.show_interact_prompt(false)


func check_if_looking(interaction_ray):
	if not interaction_ray:
		return
	
	var collider = interaction_ray.collider
	if collider.is_in_group("lookable") and collider.has_method("_on_look_event"):
		collider._on_look_event()
