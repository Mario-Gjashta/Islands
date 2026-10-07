shader_type spatial;
render_mode specular_disabled, cull_back;

// Tree canopies are scattered over every hex as candidates; each one reads
// the terrain under it and decides whether it grows, so the jungle spreads
// and recedes on its own as land rises and sinks.
#include "res://shaders/terrain.gdshaderinc"

uniform vec3 leaf_light_color = vec3(0.40, 0.60, 0.25);
uniform vec3 leaf_dark_color = vec3(0.16, 0.36, 0.17);

varying float tint;
varying float shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 p = world_to_paint(origin.xz);
	float h = baked_height(origin.xz);
	float flatness = baked_normal(origin.xz, 0.15 * hex_size).y;
	float chance = hash(origin.xz * 3.17 + 0.5);
	// Patchy groves rather than an even carpet.
	float density = tree_density(h - sea_level, flatness) * (0.6 + 0.8 * fbm(p * 0.008));
	float grow = smoothstep(chance, chance + 0.12, density);
	float size = (0.55 + 0.6 * hash(origin.xz * 7.3)) * grow;
	VERTEX *= size;
	VERTEX.y += surface_y(h) - 0.04;
	tint = hash(origin.xz * 1.9);
	// Lower parts of each canopy sit in their own shadow.
	shade = smoothstep(-0.05, 0.2, VERTEX.y - surface_y(h));
}

void fragment() {
	vec3 leaf = mix(leaf_dark_color, leaf_light_color, tint * 0.8 + 0.1);
	leaf *= 0.82 + 0.22 * shade;
	ALBEDO = srgb_to_linear(leaf);
	ROUGHNESS = 1.0;
}
