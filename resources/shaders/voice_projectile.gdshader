shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// 🎨 Parámetros del círculo
uniform vec4 circle_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform float circle_thickness : hint_range(0.01, 0.3) = 0.1;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float inner_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

// ⏱️ Control de vida
uniform float lifetime : hint_range(0.0, 1.0) = 1.0;  // 0 = recién nacido, 1 = muriendo

void vertex() {
	// Billboard: siempre mira a la cámara
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(1.0, 0.0, 0.0, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);
}

void fragment() {
	// Calcular distancia desde el centro
	vec2 uv_centered = UV - 0.5;
	float dist = length(uv_centered);
	
	// Crear el anillo circular
	float ring_edge = 1.0 - smoothstep(0.5 - circle_thickness, 0.5, dist);
	float ring_inner = smoothstep(0.5 - circle_thickness * 2.0, 0.5 - circle_thickness, dist);
	float ring = ring_edge * ring_inner;
	
	// Crear el relleno interno con alpha
	float fill = 1.0 - smoothstep(0.0, 0.5 - circle_thickness, dist);
	
	// Pulso animado
	float pulse = sin(TIME * pulse_speed) * 0.2 + 0.8;
	
	// Fade out basado en el lifetime
	float life_fade = 1.0 - lifetime;
	
	// Combinar efectos
	float total_alpha = (ring * pulse + fill * inner_alpha) * life_fade;
	
	// Color final con glow
	vec3 final_color = circle_color.rgb * (1.0 + ring * glow_intensity);
	
	ALBEDO = final_color;
	ALPHA = total_alpha * circle_color.a;
	EMISSION = final_color * ring * glow_intensity * life_fade;
}