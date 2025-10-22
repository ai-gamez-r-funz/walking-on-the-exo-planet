// res://shaders/scannable_outline.gdshader
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

// Outline configuration
uniform vec4 outline_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.1) = 0.02;
uniform float outline_intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool show_outline = true;

// Scan effect
uniform float scan_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scan_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float scan_speed : hint_range(0.0, 10.0) = 2.0;

void vertex() {
	if (show_outline) {
		// Expand vertices along normals for outline effect
		VERTEX += NORMAL * outline_width;
	}
}

void fragment() {
	// Base outline
	vec3 final_color = outline_color.rgb * outline_intensity;
	float final_alpha = outline_color.a;
	
	// Add scan wave effect if scanning
	if (scan_progress > 0.0) {
		// Create vertical scanning wave
		float wave = sin((UV.y - scan_progress) * 20.0 + TIME * scan_speed) * 0.5 + 0.5;
		final_color = mix(final_color, scan_color.rgb, wave * scan_progress);
		final_alpha = max(final_alpha, wave * scan_progress);
	}
	
	ALBEDO = final_color;
	ALPHA = final_alpha * float(show_outline);
}