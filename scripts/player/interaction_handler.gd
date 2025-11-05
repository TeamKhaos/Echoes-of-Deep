extends Node

@export var interact_layer = 0b011
@export var MouseRayCast : Node3D
@export var hud : Node # <- asignado desde el editor, no lo toques en código

var can_interact := true
var current_object
var already_interacted := false
var last_interactable = null

func _ready():
	if hud == null:
		push_warning("⚠️ HUD no asignado en el Inspector. Arrastra el nodo HUD aquí.")
	else:
		print("✅ HUD asignado correctamente:", hud.name)

func _process(_delta):
	if hud == null:
		return # si no está asignado, no intenta usarlo

	interact()
	check_if_looking()


func interact():
	var interaction_ray = MouseRayCast.calc_3D_interactions(interact_layer, 3)
	if interaction_ray:
		var collider = interaction_ray.collider

		if collider.is_in_group("interactable") and can_interact:
			# Si cambiamos de objeto, actualizamos HUD
			if last_interactable != collider:
				hud.set_crosshair_interact(true)
				hud.show_interact_prompt(true)
				last_interactable = collider

			# Si presionamos E
			if Input.is_action_just_pressed("Interact"):
				collider.mouse_interaction(get_parent())
				current_object = collider
				already_interacted = true
				leave_interaction() # 👈 limpia todo correctamente
		else:
			# Si dejamos de apuntar o perdemos el objeto
			if last_interactable != null:
				hud.show_interact_prompt(false)
				hud.set_crosshair_interact(false)
				last_interactable = null
	else:
		# Si el rayo no golpea nada
		if last_interactable != null:
			hud.show_interact_prompt(false)
			hud.set_crosshair_interact(false)
			last_interactable = null


func leave_interaction():
	current_object = null
	last_interactable = null
	if hud:
		hud.set_crosshair_interact(false)
		hud.show_interact_prompt(false)


func check_if_looking():
	var interaction_ray = MouseRayCast.calc_3D_interactions(0b011, 20)
	if interaction_ray:
		var collider = interaction_ray.collider
		if collider.is_in_group("lookable"):
			collider._on_look_event()
