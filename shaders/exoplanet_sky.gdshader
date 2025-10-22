shader_type sky;

// Sky colors and atmosphere properties
uniform vec3 sky_top_color: source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 sky_horizon_color: source_color = vec3(0.5, 0.7, 0.8);
uniform vec3 sky_bottom_color: source_color = vec3(0.2, 0.3, 0.5);
uniform float sky_horizon_blend: hint_range(0.0, 1.0) = 0.1;
uniform float sky_curve: hint_range(0.0, 10.0) = 1.5;

// Sun properties
uniform vec3 sun_color: source_color = vec3(1.5, 1.2, 0.8);
uniform vec3 second_sun_color: source_color = vec3(1.0, 0.5, 0.3);
uniform float sun_size: hint_range(0.01, 1.0) = 0.2;
uniform float sun_blur: hint_range(0.0, 10.0) = 0.5;
uniform vec3 sun_direction = vec3(0.0, 0.1, -1.0);
uniform vec3 second_sun_direction = vec3(0.5, 0.05, -0.8);
uniform float second_sun_size: hint_range(0.01, 0.5) = 0.1;

// Cloud properties
uniform sampler2D cloud_noise_texture;
uniform float cloud_coverage: hint_range(0.0, 1.0) = 0.5;
uniform float cloud_thickness: hint_range(0.0, 10.0) = 2.0;
uniform vec3 cloud_color1: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_color2: source_color = vec3(0.8, 0.8, 0.9);
uniform float cloud_speed: hint_range(0.0, 0.1) = 0.003;

// Aurora properties
uniform bool enable_aurora = true;
uniform vec3 aurora_color1: source_color = vec3(0.1, 0.6, 0.3);
uniform vec3 aurora_color2: source_color = vec3(0.2, 0.2, 0.8);
uniform float aurora_intensity: hint_range(0.0, 2.0) = 1.0;
uniform float aurora_speed: hint_range(0.0, 2.0) = 0.5;

// Stars
uniform bool enable_stars = true;
uniform float star_intensity: hint_range(0.0, 1.0) = 0.3;

// Hash function for procedural noise
vec3 hash(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
             dot(p, vec3(269.5, 183.3, 246.1)),
             dot(p, vec3(113.5, 271.9, 124.6)));
    return fract(sin(p) * 43758.5453123);
}

// Simplex noise-based functions for clouds and aurora
float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    float n = p.x + p.y * 157.0 + 113.0 * p.z;
    return mix(mix(mix(hash(p + vec3(0.0, 0.0, 0.0)).x,
                       hash(p + vec3(1.0, 0.0, 0.0)).x, f.x),
                   mix(hash(p + vec3(0.0, 1.0, 0.0)).x,
                       hash(p + vec3(1.0, 1.0, 0.0)).x, f.x), f.y),
               mix(mix(hash(p + vec3(0.0, 0.0, 1.0)).x,
                       hash(p + vec3(1.0, 0.0, 1.0)).x, f.x),
                   mix(hash(p + vec3(0.0, 1.0, 1.0)).x,
                       hash(p + vec3(1.0, 1.0, 1.0)).x, f.x), f.y), f.z);
}

// Function to create sun disk with blur
float sun_disk(vec3 dir, vec3 sun_pos, float size, float blur) {
    float sun_dot = max(0.0, dot(dir, normalize(sun_pos)));
    float sun_factor = smoothstep(1.0 - size - blur, 1.0 - size, sun_dot);
    return sun_factor;
}

// Function to create clouds
vec4 create_clouds(vec3 dir, float time) {
    // Only calculate clouds if we're looking somewhat upward
    if (dir.y < 0.01) {
        return vec4(0.0);
    }

    // Project direction onto a plane
    vec2 cloud_uv = dir.xz / (dir.y * 2.0);

    // Sample cloud noise with movement
    vec2 cloud_movement = vec2(time * cloud_speed, time * cloud_speed * 0.5);
    float noise_sample1 = texture(cloud_noise_texture, cloud_uv * 0.5 + cloud_movement).r;
    float noise_sample2 = texture(cloud_noise_texture, cloud_uv * 1.0 - cloud_movement * 0.8).r;

    // Combine noise for varied cloud density
    float cloud_density = noise_sample1 * noise_sample2;

    // Apply cloud coverage threshold and shape
    float cloud_factor = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.1, cloud_density);
    cloud_factor *= pow(dir.y, cloud_thickness); // Thicker near horizon

    // Mix cloud colors based on height and density
    vec3 cloud_color = mix(cloud_color2, cloud_color1, cloud_density);

    return vec4(cloud_color, cloud_factor);
}

// Function to create aurora effect
vec3 create_aurora(vec3 dir, float time) {
    if (!enable_aurora || dir.y < 0.0) {
        return vec3(0.0);
    }

    // Aurora appears in the upper hemisphere
    float height_factor = smoothstep(0.0, 0.6, dir.y);

    // Create waves using noise
    vec3 aurora_pos = vec3(dir.xz * 2.0, time * aurora_speed);
    float wave1 = noise(aurora_pos * 2.0);
    float wave2 = noise(aurora_pos * 4.0 + 1.5);

    // Combine waves and create curtain effect
    float wave = wave1 * wave2;
    float curtain = pow(wave, 5.0) * 10.0;

    // Intensity varies with position
    float intensity = curtain * height_factor * aurora_intensity;

    // Color gradient based on height
    vec3 aurora = mix(aurora_color1, aurora_color2, wave) * intensity;

    return aurora * smoothstep(0.0, 0.2, intensity);
}

// Function to generate stars
vec3 create_stars(vec3 dir) {
    if (!enable_stars || dir.y < 0.0) {
        return vec3(0.0);
    }

    // Create stars using noise
    vec3 star_pos = dir * 100.0;
    vec3 star_hash = hash(floor(star_pos));
    float star = pow(star_hash.x, 20.0) * star_intensity;

    // Make stars twinkle slightly
    star *= 0.8 + 0.2 * sin(TIME * 3.0 + star_hash.y * 10.0);

    // Star color varies slightly
    vec3 star_color = mix(vec3(0.8, 0.8, 1.0), vec3(1.0, 0.8, 0.8), star_hash.z);

    return star * star_color;
}

void sky() {
    // Get view direction
    vec3 dir = normalize(EYEDIR);

    // Calculate base sky gradient
    float horizon_blend = pow(1.0 - abs(dir.y), sky_curve) * sky_horizon_blend;
    vec3 sky_gradient;

    if (dir.y > 0.0) {
        // Above horizon
        sky_gradient = mix(sky_horizon_color, sky_top_color, pow(dir.y, sky_curve));
    } else {
        // Below horizon (ground reflection)
        sky_gradient = mix(sky_horizon_color, sky_bottom_color, pow(abs(dir.y), sky_curve));
    }

    // Add suns
    float sun1 = sun_disk(dir, sun_direction, sun_size, sun_blur);
    float sun2 = sun_disk(dir, second_sun_direction, second_sun_size, sun_blur * 1.5);

    vec3 sun_contribution = sun1 * sun_color + sun2 * second_sun_color;

    // Add clouds
    vec4 clouds = create_clouds(dir, TIME);

    // Add aurora
    vec3 aurora = create_aurora(dir, TIME);

    // Add stars (visible through cloud gaps and at night)
    vec3 stars = create_stars(dir) * (1.0 - clouds.a) * (1.0 - sun1 * 0.8) * (1.0 - sun2 * 0.8);

    // Combine all elements
    vec3 final_color = sky_gradient;
    final_color += sun_contribution;
    final_color = mix(final_color, clouds.rgb, clouds.a);
    final_color += aurora;
    final_color += stars;

    // Output final color
    COLOR = final_color;
}