extends RigidBody3D

@export var item_id: String = "water"

# 💧 Propiedades de consumo
@export var hunger_restore: float = 10.0
@export var health_restore: float = 5.0
@export var is_consumable: bool = true

var original_scale: Vector3
@onready var mesh = $Botella/Plane
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
		
		outlined_material = mesh_res.surface_get_material(3)
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
		if object_marker.get_child_count() > 0:
			for child in object_marker.get_children():
				child.queue_free()
		
		get_parent().remove_child(self)
		object_marker.add_child(self)
		set_held_transform()
		freeze = true

func set_held_transform():
	transform = Transform3D.IDENTITY
	scale *= 0.4

func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)

# ===============================
# 💧 SISTEMA DE CONSUMO
# ===============================
func consume(player) -> bool:
	if not is_consumable:
		return false
	
	if not player or not player.has_node("PlayerHUD/hud"):
		return false
	
	var hud = player.get_node("PlayerHUD/hud")
	if not hud:
		return false
	
	var current_hunger = hud.hunger_value
	var hunger_max = hud.hunger_max
	
	var new_hunger = current_hunger + hunger_restore
	
	hud.restore_hunger(hunger_restore)
	
	if current_hunger >= hunger_max or new_hunger >= hunger_max:
		if hud.has_method("restore_health"):
			hud.restore_health(health_restore)
	
	queue_free()
	return true

func get_item_info() -> Dictionary:
	return {
		"id": item_id,
		"name": "Agua",
		"hunger_restore": hunger_restore,
		"health_restore": health_restore,
		"is_consumable": is_consumable
	}
