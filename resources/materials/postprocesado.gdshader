shader_type spatial;
render_mode unshaded, fog_disabled;

// --- Ajustes generales ---
uniform float color_profundidad : hint_range(1.0, 64.0) = 16.0;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear;
uniform sampler2D depth_texture: hint_depth_texture, filter_nearest;

// Parámetros PS1
uniform float dither_amount : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float brightness_threshold : hint_range(0.5, 3.0, 0.1) = 1.2;
uniform bool preserve_bright_pixels = true;
uniform float shadow_brightness : hint_range(0.0, 0.5, 0.05) = 0.15;

// Parámetros Outline
uniform float outline_thickness : hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float outline_threshold : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_intensity : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform bool use_depth_outline = true;
uniform bool use_normal_outline = true;
uniform float depth_sensitivity : hint_range(1.0, 100.0, 1.0) = 40.0;

// 🌊 Parámetros del sonar 3D
uniform bool sonar_mode = false;
uniform float sonar_radius = 0.0;
uniform bool sonar_active = false;
uniform vec3 sonar_world_position = vec3(0.0, 0.0, 0.0);
uniform float sonar_width : hint_range(1.0, 20.0) = 5.0;
uniform float sonar_falloff : hint_range(0.1, 5.0) = 2.0;

// Parámetros de proyección
uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;
uniform float camera_near = 0.05;
uniform float camera_far = 4000.0;

// --- VERTEX ---
void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Bayer 8x8
float get_bayer_8x8(ivec2 uv) {
    const float bayer8[64] = float[](
        0.0, 32.0, 8.0, 40.0, 2.0, 34.0, 10.0, 42.0,
        48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
        12.0, 44.0, 4.0, 36.0, 14.0, 46.0, 6.0, 38.0,
        60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
        3.0, 35.0, 11.0, 43.0, 1.0, 33.0, 9.0, 41.0,
        51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
        15.0, 47.0, 7.0, 39.0, 13.0, 45.0, 5.0, 37.0,
        63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0
    );
    int index = (int(uv.y) % 8) * 8 + (int(uv.x) % 8);
    return (bayer8[index] / 64.0) - 0.5;
}

// Reconstruir posición 3D desde profundidad
vec3 reconstruct_world_position(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view_pos = inv_projection_matrix * ndc;
    view_pos /= view_pos.w;
    vec4 world_pos = inv_view_matrix * view_pos;
    return world_pos.xyz;
}

// --- DETECCIÓN DE BORDES NORMAL ---
float detect_sonar_edges(vec2 uv, vec2 pixel_size) {
    float offset = outline_thickness;
    vec3 tl = texture(screen_texture, uv + vec2(-pixel_size.x, pixel_size.y) * offset).rgb;
    vec3 t  = texture(screen_texture, uv + vec2(0.0, pixel_size.y) * offset).rgb;
    vec3 tr = texture(screen_texture, uv + vec2(pixel_size.x, pixel_size.y) * offset).rgb;
    vec3 l  = texture(screen_texture, uv + vec2(-pixel_size.x, 0.0) * offset).rgb;
    vec3 r  = texture(screen_texture, uv + vec2(pixel_size.x, 0.0) * offset).rgb;
    vec3 bl = texture(screen_texture, uv + vec2(-pixel_size.x, -pixel_size.y) * offset).rgb;
    vec3 b  = texture(screen_texture, uv + vec2(0.0, -pixel_size.y) * offset).rgb;
    vec3 br = texture(screen_texture, uv + vec2(pixel_size.x, -pixel_size.y) * offset).rgb;

    vec3 w = vec3(0.299, 0.587, 0.114);
    float tl_lum = dot(tl, w); float t_lum = dot(t, w); float tr_lum = dot(tr, w);
    float l_lum = dot(l, w);  float r_lum = dot(r, w);
    float bl_lum = dot(bl, w); float b_lum = dot(b, w); float br_lum = dot(br, w);

    float gx = -tl_lum - 2.0 * l_lum - bl_lum + tr_lum + 2.0 * r_lum + br_lum;
    float gy = -tl_lum - 2.0 * t_lum - tr_lum + bl_lum + 2.0 * b_lum + br_lum;

    return sqrt(gx * gx + gy * gy);
}

// --- DETECCIÓN DE BORDES POR PROFUNDIDAD ---
float detect_depth_outline(vec2 uv, vec2 pixel_size) {
    float offset = outline_thickness;
    float tl = texture(depth_texture, uv + vec2(-pixel_size.x, pixel_size.y) * offset).r;
    float tr = texture(depth_texture, uv + vec2(pixel_size.x, pixel_size.y) * offset).r;
    float bl = texture(depth_texture, uv + vec2(-pixel_size.x, -pixel_size.y) * offset).r;
    float br = texture(depth_texture, uv + vec2(pixel_size.x, -pixel_size.y) * offset).r;
    float t  = texture(depth_texture, uv + vec2(0.0, pixel_size.y) * offset).r;
    float b  = texture(depth_texture, uv + vec2(0.0, -pixel_size.y) * offset).r;
    float l  = texture(depth_texture, uv + vec2(-pixel_size.x, 0.0) * offset).r;
    float r  = texture(depth_texture, uv + vec2(pixel_size.x, 0.0) * offset).r;

    float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
    float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;

    return sqrt(gx * gx + gy * gy) * depth_sensitivity;
}

// 🌊 Calcula el efecto de anillo del sonar en 3D
float calculate_sonar_ring_3d(vec2 uv) {
    if (!sonar_active || sonar_radius <= 0.0) {
        return 0.0;
    }
    float depth = texture(depth_texture, uv).r;
    vec3 world_pos = reconstruct_world_position(uv, depth);
    float dist_3d = distance(world_pos, sonar_world_position);
    float ring_distance = abs(dist_3d - sonar_radius);
    float ring = 1.0 - smoothstep(0.0, sonar_width, ring_distance);
    ring = pow(ring, sonar_falloff);
    return ring;
}

// 🎯 Calcula si un pixel ha sido "revelado" por el sonar
float calculate_sonar_reveal(vec2 uv) {
    if (!sonar_active || sonar_radius <= 0.0) {
        return 0.0;
    }
    float depth = texture(depth_texture, uv).r;
    vec3 world_pos = reconstruct_world_position(uv, depth);
    float dist_3d = distance(world_pos, sonar_world_position);
    return smoothstep(sonar_radius + sonar_width, sonar_radius - 2.0, dist_3d);
}

// --- FRAGMENT ---
void fragment() {
    vec2 res = VIEWPORT_SIZE;
    vec2 pixel_size = 1.0 / res;
    vec2 uv = floor(SCREEN_UV * res) / res;

    vec3 original_color = texture(screen_texture, uv).rgb;

    // 1. Calcular bordes
    float edge_strength = 0.0;
    if (use_normal_outline) {
        edge_strength = max(edge_strength, detect_sonar_edges(uv, pixel_size));
    }
    if (use_depth_outline) {
        edge_strength = max(edge_strength, detect_depth_outline(uv, pixel_size));
    }
    edge_strength = smoothstep(outline_threshold, outline_threshold + 0.05, edge_strength);
    edge_strength *= outline_intensity;
    edge_strength = clamp(edge_strength, 0.0, 1.0);

    // 🌊 2. Calcular anillo y revelación del sonar
    float sonar_ring = calculate_sonar_ring_3d(SCREEN_UV);
    float sonar_reveal = calculate_sonar_reveal(SCREEN_UV);

    vec3 final_color;

    // --- MODO SONAR: NEGRO + LÍNEAS REVELADAS + ANILLO ---
    if (sonar_mode) {
        float line = pow(edge_strength, 0.6);
        float visible_line = line * sonar_reveal;
        float combined = max(visible_line, sonar_ring * 0.8);
        final_color = vec3(combined);
    }
    else {
        // MODO NORMAL con sonar
        float dither = get_bayer_8x8(ivec2(uv * res));
        float depth = max(color_profundidad, 1.0);

        vec3 dithered = original_color + (dither / depth) * dither_amount;
        vec3 quantized = round(dithered * depth) / depth;
        vec3 ps1_color = max(quantized, vec3(shadow_brightness * 0.5));
        vec3 outlined = mix(ps1_color, outline_color.rgb, edge_strength);
        vec3 darkened = mix(vec3(0.0), outlined, sonar_reveal);

        vec3 sonar_color = vec3(0.0, 1.0, 0.8);
        final_color = mix(darkened, sonar_color, sonar_ring * 0.6);
    }

    ALBEDO = final_color;
}