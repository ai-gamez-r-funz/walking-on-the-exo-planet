shader_type spatial;
render_mode blend_add, unshaded;

uniform vec4 grid_color : source_color = vec4(0.5, 1.0, 1.0, 0.8);
uniform float grid_scale : hint_range(0.1, 10.0) = 1.0;
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;

void fragment() {
    vec2 uv = UV * grid_scale;
    
    // Create grid lines
    float grid_x = step(1.0 - line_thickness, fract(uv.x));
    float grid_y = step(1.0 - line_thickness, fract(uv.y));
    float grid = max(grid_x, grid_y);
    
    ALBEDO = grid_color.rgb;
    ALPHA = grid_color.a * grid;
    EMISSION = grid_color.rgb * 2.0;
}