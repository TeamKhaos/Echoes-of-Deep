extends Node3D
@onready var camera = $".."
@onready var player = $"../../.."


func calc_3D_interactions(mask, lenght):
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var end = camera.project_position(mouse_pos, lenght)
	var ray_params = PhysicsRayQueryParameters3D.create(origin, end)
	ray_params.collide_with_areas = true
	ray_params.collide_with_bodies = true
	ray_params.collision_mask = mask
	ray_params.hit_back_faces = false
	ray_params.hit_from_inside = false
	var ray = get_world_3d().direct_space_state.intersect_ray(ray_params)
	return ray
