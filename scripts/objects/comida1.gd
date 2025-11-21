
extends RigidBody3D

@export var item_id: String = "food"
# 🍗 Propiedades de consumo
@export var hunger_restore: float = 30.0  # Cuánto hambre restaura
@export var health_restore: float = 15.0   # Cuánta vida restaura si hambre está al máximo
@export var is_consumable: bool = true     # Si se puede consumir

var original_scale: Vector3

# --- LÓGICA DE ILUMINACIÓN (COMENTADA) ---
@onready var mesh = $Cylinder
var outlined_material: Material
var base_materials := []

func _ready():
	original_scale = scale
	print("✅ Agua inicializada - consumible:", is_consumable)
	
	if mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()
	
	var mesh_res = mesh.mesh  # el recurso Mesh interno
	if mesh_res:
		for i in range(mesh_res.get_surface_count()):
			base_materials.append(mesh_res.surface_get_material(i))
		
		# Guarda el material de brillo o delineado (por ejemplo surface 3)
		outlined_material = mesh_res.surface_get_material(3)
		# Empieza desactivado
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
	# set_highlight(false) # LÓGICA DE ILUMINACIÓN (COMENTADA)
	player.add_to_inventory(item_id)
	
	var object_marker = player.object_marker
	if object_marker:
		# Si el jugador ya tiene un objeto, lo destruye.
		if object_marker.get_child_count() > 0:
			for child in object_marker.get_children():
				child.queue_free()
		
		# Ahora, recoge el nuevo objeto.
		get_parent().remove_child(self)
		object_marker.add_child(self)
		set_held_transform()
		freeze = true

func set_held_transform():
	# Esta función define la apariencia del objeto en la mano del jugador
	transform = Transform3D.IDENTITY
	scale *= 0.4
	rotation.z = deg_to_rad(-90)

func drop(drop_transform: Transform3D):
	var root_node = get_tree().get_root()
	get_parent().remove_child(self)
	root_node.add_child(self)
	global_transform = drop_transform
	scale = original_scale
	freeze = false
	
	# Reactiva la colisión para que no atraviese el mundo
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	apply_central_impulse(-global_transform.basis.z.normalized() * 2)

# ===============================
# 🍗 SISTEMA DE CONSUMO
# ===============================

func consume(player) -> bool:
	print("🍽️ consume() llamado en comida")
	
	if not is_consumable:
		print("⚠️ Este ítem no se puede consumir")
		return false
	
	if not player or not player.has_node("PlayerHUD/hud"):
		print("❌ No se encontró el HUD del jugador")
		print("   Player existe:", player != null)
		if player:
			print("   Nodos del player:", player.get_children())
		return false
	
	var hud = player.get_node("PlayerHUD/hud")
	if not hud:
		print("❌ HUD no encontrado")
		return false
	
	print("✅ HUD encontrado")
	
	# Obtener valores actuales
	var current_hunger = hud.hunger_value
	var hunger_max = hud.hunger_max
	
	print("🍗 Consumiendo comida...")
	print("   Hambre actual: ", current_hunger, "/", hunger_max)
	
	# Calcular desbordamiento de hambre
	var new_hunger = current_hunger + hunger_restore
	var hunger_overflow = max(0, new_hunger - hunger_max)
	
	# Restaurar hambre
	hud.restore_hunger(hunger_restore)
	print("   +", hunger_restore, " hambre restaurada")
	
	# Si el hambre estaba al máximo o se llenó completamente, restaurar vida
	if current_hunger >= hunger_max or new_hunger >= hunger_max:
		if hud.has_method("restore_health"):
			hud.restore_health(health_restore)
			print("   +", health_restore, " vida restaurada (hambre estaba llena)")
		else:
			print("   ⚠️ HUD no tiene método restore_health()")
	
	# Eliminar el objeto del mundo
	print("🗑️ Eliminando comida del mundo")
	queue_free()
	return true

# Función auxiliar para obtener info del ítem (útil para el inventario)
func get_item_info() -> Dictionary:
	return {
		"id": item_id,
		"name": "Comida",
		"hunger_restore": hunger_restore,
		"health_restore": health_restore,
		"is_consumable": is_consumable
	}
