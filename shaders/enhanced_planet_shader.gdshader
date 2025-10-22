shader_type spatial;

// Planet colors and texture
uniform vec4 planet_color_1 : source_color = vec4(0.2, 0.4, 0.6, 1.0);
uniform vec4 planet_color_2 : source_color = vec4(0.1, 0.2, 0.5, 1.0);
uniform vec4 polar_color : source_color = vec4(0.9, 0.9, 0.95, 1.0);
uniform float polar_size : hint_range(0.0, 0.5) = 0.15;

// Atmosphere properties
uniform vec4 atmosphere_color : source_color = vec4(0.5, 0.2, 0.7, 1.0);
uniform float atmosphere_rim_power : hint_range(1.0, 10.0) = 3.0;
uniform float atmosphere_intensity : hint_range(0.0, 5.0) = 1.5;

// Surface features
uniform sampler2D noise_texture;
uniform float noise_scale = 2.0;
uniform float time_scale = 0.1;
uniform bool has_clouds = true;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed = 0.02;

// Craters and surface variation
uniform bool has_craters = true;
uniform float crater_density : hint_range(0.0, 10.0) = 3.0;
uniform float terrain_roughness : hint_range(0.0, 1.0) = 0.6;

varying vec3 normal_interp;
varying vec3 view_dir;
varying vec2 uv_interp;

// Hash function for crater positioning
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// Noise function for terrain
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n = mix(
        mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), f.x),
        mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), f.x), f.y);
    return n * 0.5 + 0.5;
}

// Function to create craters
float crater(vec2 uv, vec2 center, float radius) {
    float dist = distance(uv, center);
    float crater_edge = smoothstep(radius * 0.95, radius, dist);
    float crater_floor = 1.0 - smoothstep(radius * 0.8, radius * 0.95, dist);
    float crater_rim = smoothstep(radius, radius * 1.1, dist);

    // Combine to form crater shape
    return min(1.0, crater_rim) - (1.0 - crater_edge) * 0.5 + crater_floor * 0.2;
}

void vertex() {
    normal_interp = NORMAL;
    view_dir = normalize(VERTEX);
    uv_interp = UV;
}

void fragment() {
    // Base planet colors
    vec2 uv = uv_interp;
    float latitude = asin(view_dir.y) / PI + 0.5; // 0 at south pole, 1 at north pole

    // Create bands and polar regions
    float equator_band = sin(latitude * PI * 10.0) * 0.5 + 0.5;
    float polar_blend = smoothstep(1.0 - polar_size, 1.0, latitude) +
                        smoothstep(polar_size, 0.0, latitude);

    // Base planet color with bands
    vec4 base_color = mix(planet_color_1, planet_color_2, equator_band);
    base_color = mix(base_color, polar_color, polar_blend);

    // Add noise-based terrain
    vec2 noise_uv = uv * noise_scale;
    float terrain_noise = texture(noise_texture, noise_uv).r;
    float terrain_detail = texture(noise_texture, noise_uv * 3.0).r;
    float terrain = mix(terrain_noise, terrain_detail, 0.3);

    // Apply craters if enabled
    if (has_craters) {
        for (int i = 0; i < 5; i++) {
            vec2 crater_pos = hash2(vec2(float(i), 0.5)) * 2.0 - 1.0;
            float crater_radius = 0.05 + hash2(vec2(float(i), 0.8)).x * 0.1;
            float crater_effect = crater(view_dir.xz, crater_pos, crater_radius);
            terrain *= crater_effect;
        }
    }

    // Mix terrain into base color
    vec4 surface_color = mix(base_color, base_color * (terrain * 0.7 + 0.3), terrain_roughness);

    // Add clouds if enabled
    if (has_clouds) {
        vec2 cloud_uv = vec2(
            uv.x + TIME * cloud_speed,
            uv.y + TIME * cloud_speed * 0.7
        ) * noise_scale * 0.5;

        float cloud_noise1 = texture(noise_texture, cloud_uv).r;
        float cloud_noise2 = texture(noise_texture, cloud_uv * 2.0 + 0.5).r;
        float cloud_mask = cloud_noise1 * cloud_noise2;

        // Apply cloud coverage
        float clouds = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.2, cloud_mask);

        // Mix clouds with surface
        surface_color = mix(surface_color, cloud_color, clouds * 0.7);
    }

    // Apply atmospheric rim
    float fresnel = pow(1.0 - dot(normal_interp, view_dir), atmosphere_rim_power);
    vec4 final_color = mix(surface_color, atmosphere_color * atmosphere_intensity, fresnel * 0.7);

    // Output with emissive component
    ALBEDO = final_color.rgb;
    EMISSION = atmosphere_color.rgb * fresnel * atmosphere_intensity * 0.5;

    // Add metallic and roughness variation
    METALLIC = 0.1 + terrain * 0.1;
    ROUGHNESS = 0.7 - terrain * 0.3;
}