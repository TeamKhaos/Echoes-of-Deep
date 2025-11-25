shader_type spatial;
render_mode unshaded, fog_disabled;

global uniform vec2 resolucion;
global uniform float color_profundidad;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear;
uniform sampler2D depth_texture: hint_depth_texture, filter_nearest;

uniform float dither_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float edge_threshold : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float edge_softness : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float brightness_threshold : hint_range(0.5, 3.0, 0.1) = 1.2;
uniform bool use_edge_detection = true;
uniform bool preserve_bright_pixels = true;

// Matriz de Bayer 4x4 para dithering
const mat4 bayer_matrix = (1.0 / 16.0) * mat4(
    vec4(0.0, 8.0, 2.0, 10.0),
    vec4(12.0, 4.0, 14.0, 6.0),
    vec4(3.0, 11.0, 1.0, 9.0),
    vec4(15.0, 7.0, 13.0, 5.0)
) - 0.5;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Función para detectar bordes usando luminancia
float detect_edges(vec2 uv, vec2 pixel_size) {
	vec3 center = texture(screen_texture, uv).rgb;
	float center_lum = dot(center, vec3(0.299, 0.587, 0.114));
	
	vec3 tl = texture(screen_texture, uv + vec2(-pixel_size.x, pixel_size.y)).rgb;
	vec3 t  = texture(screen_texture, uv + vec2(0.0, pixel_size.y)).rgb;
	vec3 tr = texture(screen_texture, uv + vec2(pixel_size.x, pixel_size.y)).rgb;
	vec3 l  = texture(screen_texture, uv + vec2(-pixel_size.x, 0.0)).rgb;
	vec3 r  = texture(screen_texture, uv + vec2(pixel_size.x, 0.0)).rgb;
	vec3 bl = texture(screen_texture, uv + vec2(-pixel_size.x, -pixel_size.y)).rgb;
	vec3 b  = texture(screen_texture, uv + vec2(0.0, -pixel_size.y)).rgb;
	vec3 br = texture(screen_texture, uv + vec2(pixel_size.x, -pixel_size.y)).rgb;
	
	float tl_lum = dot(tl, vec3(0.299, 0.587, 0.114));
	float t_lum  = dot(t, vec3(0.299, 0.587, 0.114));
	float tr_lum = dot(tr, vec3(0.299, 0.587, 0.114));
	float l_lum  = dot(l, vec3(0.299, 0.587, 0.114));
	float r_lum  = dot(r, vec3(0.299, 0.587, 0.114));
	float bl_lum = dot(bl, vec3(0.299, 0.587, 0.114));
	float b_lum  = dot(b, vec3(0.299, 0.587, 0.114));
	float br_lum = dot(br, vec3(0.299, 0.587, 0.114));
	
	float gx = -tl_lum - 2.0 * l_lum - bl_lum + tr_lum + 2.0 * r_lum + br_lum;
	float gy = -tl_lum - 2.0 * t_lum - tr_lum + bl_lum + 2.0 * b_lum + br_lum;
	
	return sqrt(gx * gx + gy * gy);
}

// Detección de bordes usando profundidad
float detect_depth_edges(vec2 uv, vec2 pixel_size) {
	float center_depth = texture(depth_texture, uv).r;
	
	float tl = texture(depth_texture, uv + vec2(-pixel_size.x, pixel_size.y)).r;
	float tr = texture(depth_texture, uv + vec2(pixel_size.x, pixel_size.y)).r;
	float bl = texture(depth_texture, uv + vec2(-pixel_size.x, -pixel_size.y)).r;
	float br = texture(depth_texture, uv + vec2(pixel_size.x, -pixel_size.y)).r;
	
	float gx = abs(tl - tr) + abs(bl - br);
	float gy = abs(tl - bl) + abs(tr - br);
	
	return sqrt(gx * gx + gy * gy);
}

void fragment() {
	vec2 pixel_size = 1.0 / resolucion;
	vec2 uv = floor(SCREEN_UV * resolucion) / resolucion;
	ivec2 int_uv = ivec2(uv * resolucion);
	
	// Muestreo múltiple para capturar mejor partículas pequeñas
	vec3 color_center = texture(screen_texture, uv).rgb;
	vec3 color_offset1 = texture(screen_texture, uv + pixel_size * 0.25).rgb;
	vec3 color_offset2 = texture(screen_texture, uv + pixel_size * 0.5).rgb;
	vec3 color_offset3 = texture(screen_texture, uv + pixel_size * 0.75).rgb;
	
	// Tomar el valor máximo para preservar píxeles brillantes
	vec3 color = max(max(color_center, color_offset1), max(color_offset2, color_offset3));
	
	// Calcular brillo del pixel
	float brightness = max(max(color.r, color.g), color.b);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	
	// Detectar si es un pixel brillante (fuego, chispas, partículas emisivas)
	bool is_bright = preserve_bright_pixels && (brightness > brightness_threshold || luma > brightness_threshold * 0.7);
	
	vec3 final_color;
	
	// Para píxeles brillantes, aplicar procesamiento mínimo
	if (is_bright) {
		// Dithering muy reducido para partículas
		float particle_dither = dither_amount * 0.2;
		float dither_value = bayer_matrix[int_uv.x % 4][int_uv.y % 4];
		vec3 dithered_color = color + dither_value / color_profundidad * particle_dither;
		vec3 quantized_color = round(dithered_color * color_profundidad) / color_profundidad;
		
		// Mezclar más con el original para preservar la intensidad
		final_color = mix(quantized_color, color, 0.4);
	} else {
		// Detección de bordes combinada (solo para píxeles normales)
		float edge_strength = 0.0;
		if (use_edge_detection) {
			float color_edge = detect_edges(uv, pixel_size);
			float depth_edge = detect_depth_edges(uv, pixel_size);
			edge_strength = max(color_edge, depth_edge * 10.0);
			edge_strength = smoothstep(edge_threshold, edge_threshold + edge_softness, edge_strength);
		}
		
		// Aplicar dithering con menor intensidad en los bordes
		float adaptive_dither = dither_amount * (1.0 - edge_strength * 0.7);
		
		// Dithering con Bayer matrix
		float dither_value = bayer_matrix[int_uv.x % 4][int_uv.y % 4];
		vec3 dithered_color = color + dither_value / color_profundidad * adaptive_dither;
		
		// Cuantización de color
		vec3 quantized_color = round(dithered_color * color_profundidad) / color_profundidad;
		
		// En los bordes fuertes, mezclar un poco con el color original para suavizar
		final_color = mix(quantized_color, color, edge_strength * 0.2);
	}
	
	ALBEDO = final_color;
}