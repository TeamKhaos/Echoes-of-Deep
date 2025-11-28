shader_type spatial;
render_mode unshaded, fog_disabled;
// --- Ajuste de Oscuridad ---
// 1.0 hará que toda la escena se vuelva completamente negra.
uniform float global_darkness : hint_range(0.0, 1.0, 0.01) = 1.0; 
uniform sampler2D screen_texture: hint_screen_texture, filter_linear;
// --- VERTEX ---
void vertex() {
    // Este shader es un efecto de pantalla completa.
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
// --- FRAGMENT ---
void fragment() {
    vec2 uv = SCREEN_UV;

    // 1. Obtener el color de la escena renderizada (incluyendo la cueva).
    vec3 original_color = texture(screen_texture, uv).rgb;
    // 2. Aplicar Oscurecimiento Global.
    // mix(ColorOriginal, NegroPuro, Intensidad)
    // Con global_darkness = 1.0, el color final será vec3(0.0) (negro).
    vec3 final_color = mix(original_color, vec3(0.0), global_darkness);
    ALBEDO = final_color;
} 