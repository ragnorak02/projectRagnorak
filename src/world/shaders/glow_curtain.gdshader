// Additive "energy curtain" for zone edges (ZoneBounds) and zone-exit columns
// (ZonePortal). Unshaded, no depth write, both faces: it never hides what is
// behind it and never fights the depth buffer.
//  - A thin bright line along the bottom (the outline you see from far away).
//  - A soft curtain above it that fades out with height, with slow diagonal
//    bands so it reads as a barrier rather than a pane of glass.
//  - use_proximity: the curtain only appears near `player_pos` (ZoneBounds);
//    the ground line stays at `far_line_alpha` everywhere else.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.373, 0.890, 0.941, 1.0);
uniform float intensity = 1.0;
uniform bool use_proximity = false;
uniform vec3 player_pos = vec3(0.0);
uniform float reveal_distance = 7.0;
uniform float far_line_alpha = 0.22;
uniform float curtain_alpha = 0.35;
uniform float line_width = 0.06;   // fraction of the quad height
uniform float band_scale = 1.4;
uniform float band_speed = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// QuadMesh UV.y is 0 at the top and 1 at the bottom.
	float up = 1.0 - UV.y;
	float near = 1.0;
	if (use_proximity) {
		float d = distance(world_pos.xz, player_pos.xz);
		near = 1.0 - smoothstep(1.2, reveal_distance, d);
	}
	float line = 1.0 - smoothstep(0.0, line_width, up);
	float fade = (1.0 - up);
	fade *= fade;
	// Along-edge coordinate: one of x / z is constant on an axis-aligned quad.
	float along = world_pos.x + world_pos.z;
	float bands = 0.55 + 0.45 * smoothstep(0.35, 0.65,
			abs(fract(along * band_scale + up * 1.2 - TIME * band_speed) - 0.5) * 2.0);
	float a = line * mix(far_line_alpha, 0.9, near) + fade * curtain_alpha * bands * near;
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(a * intensity, 0.0, 1.0);
}
