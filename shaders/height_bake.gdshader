shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Bakes terrain() into a texture covering bake_extent world units, so the
// 3D shaders can read heights cheaply. Encoding matches baked_texel().
#include "res://shaders/terrain.gdshaderinc"

void fragment() {
	vec2 world = (UV - 0.5) * bake_extent;
	float v = clamp(terrain(world_to_paint(world)) / HEIGHT_RANGE, 0.0, 1.0);
	float high = floor(v * 255.0) / 255.0;
	float low = fract(v * 255.0);
	COLOR = vec4(high, low, 0.0, 1.0);
}
