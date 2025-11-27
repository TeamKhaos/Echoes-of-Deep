shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

// 🎤 Parámetros de las ondas de voz
uniform vec3 mouth_position = vec3(0.0, 0.0, 0.0);
uniform float wave_radius : hint_range(0.0, 20.0) = 0.0;
uniform bool is_speaking = false;

// 🎨 Apariencia de las ondas
uniform vec4 wave_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float wave_thickness : hint_range(0.05, 2.0) = 0.4;
uniform float wave_intensity : hint_range(0.0, 5.0) = 2.5;
uniform float inner_glow : hint_range(0.0, 2.0) = 0.8;

// 🌊 Múltiples ondas
uniform int num_waves : hint_range(1, 5) = 3;
uniform float wave_spacing : hint_range(1.0, 10.0) = 3.0;

// ✨ Animación
uniform float pulse_frequency : hint_range(0.5, 10.0) = 3.0;
uniform float distortion_amount : hint_range(0.0, 0.5) = 0.1;

void vertex() {
	// Hacer que el mesh siempre mire a la cámara (billboard)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(1.0, 0.0, 0.0, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);
}

void fragment() {
	if (!is_speaking || wave_radius <= 0.0) {
		ALPHA = 0.0;
		return;
	}
	
	// 📍 Calcular distancia desde el centro del billboard
	vec2 uv_centered = UV - 0.5;
	float dist_from_center = length(uv_centered);
	
	// 🌀 Añadir distorsión sutil para hacer las ondas más orgánicas
	float angle = atan(uv_centered.y, uv_centered.x);
	float distortion = sin(angle * 4.0 + TIME * 2.0) * distortion_amount;
	dist_from_center += distortion * dist_from_center;
	
	// Normalizar distancia al tamaño del wave_radius
	float normalized_dist = dist_from_center * 20.0;
	
	float total_alpha = 0.0;
	float total_brightness = 0.0;
	
	// 🌊 Crear múltiples ondas concéntricas
	for (int i = 0; i < num_waves; i++) {
		float wave_offset = float(i) * wave_spacing;
		float current_radius = wave_radius - wave_offset;
		
		if (current_radius <= 0.0) continue;
		
		// Calcular distancia a esta onda
		float dist_to_wave = abs(normalized_dist - current_radius);
		
		// Crear el borde brillante de la onda
		float edge_sharpness = 2.0 / wave_thickness;
		float edge = exp(-dist_to_wave * edge_sharpness);
		
		// Añadir glow interno
		float glow = exp(-dist_to_wave * 0.5) * inner_glow;
		
		// ✨ Pulso animado
		float pulse_phase = current_radius * 0.3 + TIME * pulse_frequency;
		float pulse = sin(pulse_phase) * 0.3 + 0.7;
		
		// 📉 Fade out con la distancia
		float lifetime_fade = 1.0 - (wave_offset / (wave_spacing * float(num_waves)));
		lifetime_fade = smoothstep(0.0, 1.0, lifetime_fade);
		
		// 🎯 Fade out en los bordes del círculo
		float outer_fade = 1.0 - smoothstep(0.4, 0.5, dist_from_center);
		
		// Combinar efectos
		float wave_contribution = (edge + glow) * pulse * lifetime_fade * outer_fade;
		total_alpha += wave_contribution;
		total_brightness += edge * pulse * lifetime_fade;
	}
	
	// 🎨 Aplicar color final
	total_alpha = clamp(total_alpha, 0.0, 1.0);
	total_brightness = clamp(total_brightness, 0.0, 1.0);
	
	// Colorear con más intensidad en el centro de las ondas
	vec3 final_color = wave_color.rgb * (1.0 + total_brightness);
	
	ALBEDO = final_color;
	ALPHA = total_alpha * wave_color.a;
	EMISSION = final_color * wave_intensity * total_brightness;
	
	// ✨ Añadir un resplandor extra en el centro
	float center_glow = exp(-normalized_dist * 0.5) * 0.3;
	EMISSION += wave_color.rgb * center_glow * wave_intensity;
}