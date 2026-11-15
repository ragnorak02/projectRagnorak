// Additive floor pad for zone exits (ZonePortal): bright rim, soft fill and
// slow chevrons that move toward the exit (-Z in the pad's local space).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.373, 0.890, 0.941, 1.0);
uniform float intensity = 1.0;
uniform vec2 pad_size = vec2(4.0, 4.0);   // metres, for an even rim width
uniform float rim_width = 0.12;           // metres
uniform float fill_alpha = 0.16;
uniform float chevron_speed = 0.6;

void fragment() {
	vec2 p = UV * pad_size;                       // metres from the corner
	vec2 edge = min(p, pad_size - p);
	float rim = 1.0 - smoothstep(0.0, rim_width, min(edge.x, edge.y));
	// Chevrons: a V shape that scrolls toward the far edge (UV.y = 0).
	float cx = abs(UV.x - 0.5) * pad_size.x;
	float v = fract((p.y + cx * 0.6) * 0.8 + TIME * chevron_speed);
	float chev = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.12, 0.3, v));
	float a = rim * 0.9 + fill_alpha + chev * 0.22;
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(a * intensity, 0.0, 1.0);
}
