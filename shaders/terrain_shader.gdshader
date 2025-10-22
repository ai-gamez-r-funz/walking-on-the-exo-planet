shader_type spatial;

// Base terrain parameters
uniform float terrain_height_min;
uniform float terrain_height_max;
uniform vec3 primary_color : source_color;
uniform int feature_type;

// Feature-specific parameters
uniform vec2 feature_center;
uniform float feature_radius;
uniform vec2 river_start;
uniform vec2 river_end;
uniform float river_width;
uniform float feature_angle;
uniform float feature_length;
uniform float feature_width;

// Noise parameters for detail
uniform int noise_seed;
uniform float noise_frequency;

// Constants matching the FEATURE_TYPES in GDScript
const int FEATURE_NONE = 0;
const int FEATURE_MOUNTAIN = 1;
const int FEATURE_CRATER = 2;
const int FEATURE_RIVERBED = 3;
const int FEATURE_CREVICE = 4;

// Helper functions
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth interpolation
    vec2 u = smoothstep(0.0, 1.0, f);

    // Mix 4 corners percentages
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    // Get world position
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Base color from primary color
    vec3 color = primary_color;

    // Height-based coloring
    float height_factor = smoothstep(terrain_height_min, terrain_height_max, world_pos.y);

    // Add some variety with noise
    float detail_noise = noise(world_pos.xz * noise_frequency * 5.0);

    // Default terrain - height-based coloring
    if (feature_type == FEATURE_NONE) {
        // Grass/dirt blend
        vec3 low_ground = vec3(0.5, 0.4, 0.3); // More dirt/sand
        vec3 high_ground = vec3(0.3, 0.7, 0.2); // More grass
        color = mix(low_ground, high_ground, height_factor);

        // Add noise variation
        color = mix(color, color * 0.8, detail_noise * 0.3);
    }
    // Mountain feature
    else if (feature_type == FEATURE_MOUNTAIN) {
        vec2 to_center = vec2(world_pos.x, world_pos.z) - feature_center;
        float dist = length(to_center);

        if (dist < feature_radius) {
            float mountain_factor = 1.0 - dist / feature_radius;

            // Rocky color for mountains
            vec3 rock_color = vec3(0.5, 0.45, 0.4);
            vec3 snow_color = vec3(0.95, 0.95, 0.95);

            // More snow at higher elevations
            float snow_threshold = 0.7;
            if (height_factor > snow_threshold && mountain_factor > 0.5) {
                color = mix(rock_color, snow_color, (height_factor - snow_threshold) / (1.0 - snow_threshold));
            } else {
                color = rock_color;
            }

            // Add rock detail with noise
            color = mix(color, color * 0.8, detail_noise * 0.5);
        }
    }
    // Crater feature
    else if (feature_type == FEATURE_CRATER) {
        vec2 to_center = vec2(world_pos.x, world_pos.z) - feature_center;
        float dist = length(to_center);

        if (dist < feature_radius) {
            float crater_factor = dist / feature_radius;

            // Darker in the center, lighter at rim
            if (crater_factor > 0.8) {
                // Crater rim color
                color = vec3(0.6, 0.55, 0.5);
            } else {
                // Crater bowl color
                vec3 crater_color = vec3(0.3, 0.25, 0.2);
                color = mix(crater_color, primary_color, crater_factor);
            }
        }
    }
    // Riverbed feature
    else if (feature_type == FEATURE_RIVERBED) {
        // Calculate distance to river line segment
        vec2 river_dir = normalize(river_end - river_start);
        vec2 to_point = vec2(world_pos.x, world_pos.z) - river_start;
        float along_river = dot(to_point, river_dir);

        // Clamp to river segment
        along_river = clamp(along_river, 0.0, length(river_end - river_start));

        // Find closest point on river
        vec2 closest_point = river_start + river_dir * along_river;
        float dist = length(vec2(world_pos.x, world_pos.z) - closest_point);

        if (dist < river_width) {
            float water_factor = 1.0 - dist / river_width;
            water_factor = smoothstep(0.0, 1.0, water_factor);

            // Blue water in middle, sandy edges
            vec3 water_color = vec3(0.2, 0.4, 0.8);
            vec3 shore_color = vec3(0.8, 0.7, 0.5);

            if (water_factor > 0.7) {
                color = mix(shore_color, water_color, (water_factor - 0.7) / 0.3);
            } else {
                color = shore_color;
            }
        }
    }
    // Crevice feature
    else if (feature_type == FEATURE_CREVICE) {
        // Calculate distance to crevice line
        vec2 crevice_dir = vec2(cos(feature_angle), sin(feature_angle));
        vec2 to_point = vec2(world_pos.x, world_pos.z) - feature_center;
        float along_crevice = dot(to_point, crevice_dir);

        // Only within crevice length
        if (abs(along_crevice) < feature_length * 0.5) {
            // Distance perpendicular to crevice
            vec2 projected = feature_center + crevice_dir * along_crevice;
            float perp_dist = length(vec2(world_pos.x, world_pos.z) - projected);

            if (perp_dist < feature_width) {
                // Dark rocky color for crevices
                vec3 crevice_color = vec3(0.2, 0.2, 0.25);
                float blend = 1.0 - perp_dist / feature_width;
                blend = smoothstep(0.0, 1.0, blend);
                color = mix(primary_color, crevice_color, blend);
            }
        }
    }

    // Assign final colors
    ALBEDO = color;

    // Material properties
    METALLIC = 0.0;
    ROUGHNESS = 0.8 + detail_noise * 0.2;

    // Add slight emission for water in riverbeds
    if (feature_type == FEATURE_RIVERBED) {
        vec2 river_dir = normalize(river_end - river_start);
        vec2 to_point = vec2(world_pos.x, world_pos.z) - river_start;
        float along_river = dot(to_point, river_dir);
        along_river = clamp(along_river, 0.0, length(river_end - river_start));
        vec2 closest_point = river_start + river_dir * along_river;
        float dist = length(vec2(world_pos.x, world_pos.z) - closest_point);

        if (dist < river_width * 0.6) {
            float water_glow = 1.0 - dist / (river_width * 0.6);
            water_glow = smoothstep(0.0, 1.0, water_glow) * 0.1;
            EMISSION = vec3(0.1, 0.3, 0.4) * water_glow;
        }
    }
}