shader_type canvas_item;

// Parámetros de control
uniform float sanity_level : hint_range(0.0, 1.0) = 1.0;
uniform float time_value = 0.0;

// Efecto de glitch
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Desaturación
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;

// Viñeta
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vignette_color = vec3(0.0, 0.0, 0.0);

// Distorsión de barril
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.0;

// Aberración cromática
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.0;

// Ruido/grain
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.0;

// ============================================
// FUNCIONES AUXILIARES
// ============================================

// Generador de ruido pseudo-aleatorio
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

// Ruido animado
float noise(vec2 uv, float time) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = random(i + time);
    float b = random(i + vec2(1.0, 0.0) + time);
    float c = random(i + vec2(0.0, 1.0) + time);
    float d = random(i + vec2(1.0, 1.0) + time);
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Efecto de glitch con líneas horizontales
vec2 glitch_distortion(vec2 uv, float time) {
    float line = floor(uv.y * 50.0 + time * 10.0);
    float glitch_amount = random(vec2(line, time)) * glitch_intensity;
    
    if (random(vec2(line, time * 0.1)) > 0.95) {
        uv.x += (random(vec2(line, time)) - 0.5) * glitch_amount * 0.1;
    }
    
    return uv;
}

// Distorsión de barril
vec2 barrel_distort(vec2 uv, float amount) {
    vec2 center = vec2(0.5, 0.5);
    vec2 delta = uv - center;
    float dist = length(delta);
    float factor = 1.0 + amount * dist * dist;
    return center + delta * factor;
}

// Desaturación de color
vec3 desaturate(vec3 color, float amount) {
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(color, vec3(gray), amount);
}

// Viñeta
float vignette(vec2 uv, float strength) {
    vec2 center = uv - vec2(0.5);
    float dist = length(center);
    return 1.0 - smoothstep(0.3, 0.8, dist) * strength;
}

// ============================================
// FRAGMENT SHADER
// ============================================

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. DISTORSIÓN DE BARRIL (cuando cordura < 0.5)
    if (sanity_level < 0.5) {
        uv = barrel_distort(uv, barrel_distortion);
    }
    
    // 2. EFECTO GLITCH (cuando cordura < 0.3)
    if (sanity_level < 0.3 && glitch_intensity > 0.0) {
        uv = glitch_distortion(uv, time_value);
        
        // Bloques de glitch aleatorios
        float block_noise = noise(uv * 10.0, time_value * 5.0);
        if (block_noise > 0.8) {
            uv.x += (random(vec2(floor(uv.y * 20.0), time_value)) - 0.5) * 0.05;
        }
    }
    
    // 3. ABERRACIÓN CROMÁTICA (cuando cordura < 0.4)
    vec3 color;
    if (sanity_level < 0.4 && chromatic_aberration > 0.0) {
        float r = texture(screen_texture, uv + vec2(chromatic_aberration, 0.0)).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, uv - vec2(chromatic_aberration, 0.0)).b;
        color = vec3(r, g, b);
    } else {
        color = texture(screen_texture, uv).rgb;
    }
    
    // 4. DESATURACIÓN PROGRESIVA
    color = desaturate(color, desaturation);
    
    // 5. RUIDO/GRAIN (cuando cordura < 0.3)
    if (sanity_level < 0.3 && noise_intensity > 0.0) {
        float grain = noise(uv * 200.0, time_value * 10.0);
        color += (grain - 0.5) * noise_intensity * 0.2;
    }
    
    // 6. VIÑETA
    float vig = vignette(uv, vignette_strength);
    color = mix(vignette_color, color, vig);
    
    // 7. PARPADEO ALEATORIO (cuando cordura < 0.2)
    if (sanity_level < 0.2) {
        float flicker = noise(vec2(time_value * 5.0), time_value);
        if (flicker > 0.95) {
            color *= 0.5 + random(vec2(time_value)) * 0.5;
        }
    }
    
    COLOR = vec4(color, 1.0);
}