shader_type spatial;
render_mode specular_disabled, cull_back;

// Trees are scattered over every hex as candidates; each one reads the
// terrain under it and decides whether it grows, so forests spread and
// recede on their own as land rises and sinks.
#include "res://shaders/terrain.gdshaderinc"

uniform vec3 leaf_low_color = vec3(0.50, 0.64, 0.34);
uniform vec3 leaf_high_color = vec3(0.32, 0.48, 0.36);
uniform vec3 trunk_color = vec3(0.42, 0.32, 0.24);

varying float foliage;
varying float tint;
varying float altitude;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 p = world_to_paint(origin.xz);
	float h = baked_height(origin.xz);
	float lift = h - sea_level;
	float chance = hash(origin.xz * 3.17 + 0.5);
	// Patchy woods rather than an even carpet.
	float density = tree_density(lift) * (0.55 + 0.9 * fbm(p * 0.008));
	float grow = smoothstep(chance, chance + 0.12, density);
	float size = (0.9 + 0.6 * hash(origin.xz * 7.3)) * grow;
	// Broad, rounded trees low down; slim conifers near the tree line.
	altitude = smoothstep(1.3, 3.4, lift);
	float width = mix(1.35, 0.8, altitude);
	VERTEX.xz *= size * width;
	VERTEX.y *= size * mix(0.85, 1.2, altitude);
	VERTEX.y += surface_y(h) - 0.03;
	foliage = COLOR.r;
	tint = hash(origin.xz * 1.9);
}

void fragment() {
	vec3 leaf = mix(leaf_low_color, leaf_high_color, altitude);
	leaf *= 0.85 + 0.3 * tint;
	ALBEDO = srgb_to_linear(mix(trunk_color, leaf, foliage));
	ROUGHNESS = 1.0;
}
